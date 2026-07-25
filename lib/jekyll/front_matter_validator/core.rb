# frozen_string_literal: true
require "yaml"
require "date"

module Jekyll
  module FrontMatterValidator
    # Slug regex: lowercase, no accents, no spaces, only letters/digits
    # separated by hyphens. E.g. "my-cool-post" passes, "My Post!" doesn't.
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

    # Builds a nested type tree from dot-notation keys.
    # E.g. { "cover.author.name" => "string" } becomes
    #   { "cover" => { "type" => "hash", "keys" => { "author" => { "type" => "hash", "keys" => { "name" => "string" } } } } }
    def build_nested_type_tree(types)
      tree = {}
      (types || {}).each do |key, type_def|
        next if key.include?(".")
        tree[key] = type_def
      end

      (types || {}).each do |key, type_def|
        next unless key.include?(".")
        parts = key.split(".")
        current = tree

        parts[0...-1].each do |part|
          current[part] ||= { "type" => "hash", "keys" => {} }
          current[part]["keys"] ||= {}
          current = current[part]["keys"]
        end

        current[parts.last] = type_def
      end

      tree
    end

    # Deep merges two type definitions. Explicit (second arg) wins on conflicts.
    def deep_merge_types(base, override)
      result = base.dup
      override.each do |key, over_val|
        base_val = result[key]
        if base_val.is_a?(Hash) && base_val["type"] == "hash" && over_val.is_a?(Hash) && over_val["type"] == "hash"
          merged_keys = deep_merge_types(base_val["keys"] || {}, over_val["keys"] || {})
          result[key] = { "type" => "hash", "keys" => merged_keys }
        else
          result[key] = over_val
        end
      end
      result
    end

    # Converts any string into a slug: strips accents, downcases,
    # replaces non-[a-z0-9] with hyphens, and trims leading/trailing hyphens.
    # E.g. "Coffee with Sugar!" -> "coffee-with-sugar"
    def slugify(str)
      str.to_s.unicode_normalize(:nfd)
         .gsub(/[^\x00-\x7F]/, "")
         .downcase
         .gsub(/[^a-z0-9]+/, "-")
         .gsub(/\A-+|-+\z/, "")
    end

    # Finds which rule set applies to a relative path based on
    # `front_matter_schema.collections.*.path` in _config.yml,
    # falling back to `front_matter_schema.defaults` when nothing matches.
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

    # Validates required fields, types (including slug, nested hashes), and enums.
    def validate(fm, rules, file:)
      issues = []
      fm ||= {}

      Array(rules["required"]).each do |field|
        value = fm[field.to_s]
        issues << Issue.new(file, field, "required field missing", :error) if value.nil? || value == ""
      end

      nested_types = build_nested_type_tree(rules["types"])

      nested_types.each do |field, type_def|
        next unless fm.key?(field.to_s)
        value = fm[field.to_s]
        issues.concat(validate_type(field, value, type_def, file, nested_types))
      end

      (rules["enum"] || {}).each do |field, allowed|
        next unless fm.key?(field.to_s)
        value = fm[field.to_s]
        next if Array(allowed).include?(value)

        issues << Issue.new(file, field, "value #{value.inspect} not in allowed list #{allowed}", :error)
      end

      issues
    end

    # Validates a single field value against its type definition.
    # Recursively validates nested hash keys.
    def validate_type(field, value, type_def, file, nested_types)
      issues = []

      if type_def.is_a?(Hash) && type_def["type"] == "hash"
        checker = TYPE_CHECKS["hash"]
        unless checker.call(value)
          issues << Issue.new(file, field, "expected type 'hash', got #{value.inspect}", :error)
          return issues
        end

        if type_def["keys"]
          type_def["keys"].each do |key, sub_type|
            sub_field = "#{field}.#{key}"
            if value.key?(key.to_s) || value.key?(key.to_sym)
              sub_value = value[key.to_s] || value[key.to_sym]
              issues.concat(validate_type(sub_field, sub_value, sub_type, file, nested_types))
            end
          end
        end
      else
        type_str = type_def.to_s
        checker = TYPE_CHECKS[type_str]
        return issues unless checker
        return issues if checker.call(value)

        hint = type_str == "slug" ? " (expected a slug-like value, e.g. 'my-slug', no spaces/uppercase)" : ""
        issues << Issue.new(file, field, "expected type '#{type_str}'#{hint}, got #{value.inspect}", :error)
      end

      issues
    end

    # Checks whether a matching asset file exists on disk for the value of
    # a given field. Two configuration styles in `assets:`:
    #
    #   assets:
    #     cover_image:
    #       dir: assets/images
    #       extensions: [jpg, jpeg, png, webp]
    #       slugify: true     # optional: normalizes the value before building the name
    #
    # or, for more flexible paths (e.g. per-item subdirectories):
    #
    #   assets:
    #     cover_image:
    #       pattern: "assets/posts/{value}/cover.*"
    #       slugify: true
    #
    # `project_root` is the base directory from which `dir`/`pattern` are
    # resolved (site.source in Jekyll, repo root in the standalone script).
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

        issues << Issue.new(file, field, "no matching asset found at '#{expected}'", :error)
      end

      issues
    end

    # Runs validate + validate_assets in one pass, used by both sides
    # (Jekyll plugin and standalone script).
    def validate_all(fm, rules, file:, project_root: Dir.pwd)
      validate(fm, rules, file: file) + validate_assets(fm, rules, file: file, project_root: project_root)
    end

    # Reads the raw YAML front matter block from a file on disk.
    # Returns [hash_or_nil, error_message_or_nil].
    # hash == nil and error == nil means "no front matter".
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
