# frozen_string_literal: true
require "yaml"
require "date"

module Jekyll
  module FrontMatterValidator
    # Regex de slug: minúsculo, sem acento, sem espaço, só letras/números
    # separados por hífen. Ex.: "meu-post-legal" passa, "Meu Post!" não.
    SLUG_REGEX = /\A[a-z0-9]+(-[a-z0-9]+)*\z/.freeze

    TYPE_CHECKS = {
      "string"  => ->(v) { v.is_a?(String) },
      "integer" => ->(v) { v.is_a?(Integer) },
      "float"   => ->(v) { v.is_a?(Numeric) },
      "boolean" => ->(v) { v == true || v == false },
      "array"   => ->(v) { v.is_a?(Array) },
      "hash"    => ->(v) { v.is_a?(Hash) },
      "date"    => ->(v) { v.is_a?(Date) || v.is_a?(Time) || (v.is_a?(String) && v =~ /\A\d{4}-\d{2}-\d{2}/) },
      "slug"    => ->(v) { v.is_a?(String) && v.match?(SLUG_REGEX) }
    }.freeze

    Issue = Struct.new(:file, :field, :message, :level) do
      def to_s
        "[#{level.to_s.upcase}] #{file} -> #{field}: #{message}"
      end
    end

    module_function

    # Converte uma string qualquer em slug: remove acentos, baixa a caixa,
    # troca tudo que não é [a-z0-9] por hífen e tira hífens nas pontas.
    # Ex.: "Café com Açúcar!" -> "cafe-com-acucar"
    def slugify(str)
      str.to_s.unicode_normalize(:nfd)
         .gsub(/[^\x00-\x7F]/, "")
         .downcase
         .gsub(/[^a-z0-9]+/, "-")
         .gsub(/\A-+|-+\z/, "")
    end

    # Descobre qual conjunto de regras se aplica a um caminho relativo,
    # com base em `front_matter_schema.collections.*.path` no _config.yml,
    # caindo para `front_matter_schema.defaults` se nada bater.
    def rules_for(relative_path, schema)
      (schema["collections"] || {}).each_value do |rules|
        dir = rules["path"]
        next unless dir
        dir = dir.to_s.sub(%r{\A/}, "").sub(%r{/\z}, "")
        return merge_defaults(rules, schema) if relative_path.start_with?("#{dir}/")
      end
      merge_defaults(schema["defaults"] || {}, schema)
    end

    def merge_defaults(rules, schema)
      defaults = schema["defaults"] || {}
      {
        "required" => (defaults["required"] || []) | (rules["required"] || []),
        "types"    => (defaults["types"] || {}).merge(rules["types"] || {}),
        "enum"     => (defaults["enum"] || {}).merge(rules["enum"] || {}),
        "assets"   => (defaults["assets"] || {}).merge(rules["assets"] || {})
      }
    end

    # Valida obrigatoriedade, tipo (incluindo slug) e enum.
    def validate(fm, rules, file:)
      issues = []
      fm ||= {}

      Array(rules["required"]).each do |field|
        value = fm[field.to_s]
        issues << Issue.new(file, field, "campo obrigatório ausente", :error) if value.nil? || value == ""
      end

      (rules["types"] || {}).each do |field, type|
        next unless fm.key?(field.to_s)
        value = fm[field.to_s]
        checker = TYPE_CHECKS[type.to_s]
        next unless checker
        next if checker.call(value)

        hint = type.to_s == "slug" ? " (esperado algo como 'meu-slug-sem-acento', sem espaço/maiúscula)" : ""
        issues << Issue.new(file, field, "esperado tipo '#{type}'#{hint}, recebido #{value.inspect}", :error)
      end

      (rules["enum"] || {}).each do |field, allowed|
        next unless fm.key?(field.to_s)
        value = fm[field.to_s]
        next if Array(allowed).include?(value)

        issues << Issue.new(file, field, "valor #{value.inspect} fora da lista permitida #{allowed}", :error)
      end

      issues
    end

    # Confere se existe um arquivo de asset correspondente ao valor do
    # campo. Duas formas de configurar em `assets:`:
    #
    #   assets:
    #     cover_image:
    #       dir: assets/images
    #       extensions: [jpg, jpeg, png, webp]
    #       slugify: true     # opcional: normaliza o valor antes de montar o nome
    #
    # ou, para caminhos mais flexíveis (ex.: subpasta por item):
    #
    #   assets:
    #     cover_image:
    #       pattern: "assets/posts/{value}/cover.*"
    #       slugify: true
    #
    # `project_root` é a raiz a partir da qual `dir`/`pattern` são resolvidos
    # (site.source no Jekyll, raiz do repo no script standalone).
    def validate_assets(fm, rules, file:, project_root:)
      issues = []

      (rules["assets"] || {}).each do |field, cfg|
        raw = fm[field.to_s]
        next if raw.nil? || raw.to_s.strip.empty?

        value = cfg["slugify"] ? slugify(raw.to_s) : raw.to_s

        if cfg["pattern"]
          rel_pattern = cfg["pattern"].to_s.gsub("{value}", value)
          found = Dir.glob(File.join(project_root, rel_pattern)).any?
          expected = rel_pattern
        else
          dir = cfg["dir"] || "."
          exts = Array(cfg["extensions"])
          exts = ["*"] if exts.empty?
          found = exts.any? { |ext| Dir.glob(File.join(project_root, dir, "#{value}.#{ext}")).any? }
          expected = File.join(dir, "#{value}.{#{exts.join(',')}}")
        end

        next if found

        issues << Issue.new(file, field, "nenhum asset encontrado em '#{expected}'", :error)
      end

      issues
    end

    # Roda validate + validate_assets de uma vez, forma que os dois lados
    # (plugin Jekyll e script standalone) usam.
    def validate_all(fm, rules, file:, project_root: Dir.pwd)
      validate(fm, rules, file: file) + validate_assets(fm, rules, file: file, project_root: project_root)
    end

    # Lê o bloco de front matter YAML bruto de um arquivo em disco.
    # Retorna [hash_ou_nil, mensagem_de_erro_ou_nil].
    # hash == nil e erro == nil significa "não tem front matter".
    def read_front_matter(path)
      content = File.read(path, encoding: "utf-8")
      match = content.match(/\A---\s*\n(.*?\n?)^---\s*$\n?/m)
      return [nil, nil] unless match

      begin
        data = YAML.safe_load(match[1], permitted_classes: [Date, Time], aliases: true)
        [data || {}, nil]
      rescue Psych::SyntaxError => e
        [nil, e.message]
      end
    end

    def load_schema(config_path)
      return {} unless File.exist?(config_path)
      config = YAML.safe_load(File.read(config_path)) || {}
      config["front_matter_schema"] || {}
    end

    def has_rules?(rules)
      %w[required types enum assets].any? { |k| !rules[k].to_a.empty? }
    end
  end
end
