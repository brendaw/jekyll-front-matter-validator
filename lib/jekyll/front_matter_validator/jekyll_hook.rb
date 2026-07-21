# frozen_string_literal: true

module Jekyll
  module FrontMatterValidator
    def self.documents_for(site)
      docs = site.pages.dup
      docs += site.posts.docs
      site.collections.each_value { |c| docs += c.docs }
      docs
    end

    def self.relative_path_for(doc, site)
      if doc.respond_to?(:relative_path)
        doc.relative_path.to_s.sub(%r{\A/}, "")
      else
        doc.path.to_s.sub("#{site.source}/", "")
      end
    end

    # Roda automaticamente em `jekyll build` E `jekyll serve`, porque o
    # serve dispara o mesmo pipeline de build (e de novo a cada regeneração
    # quando o --watch detecta mudanças).
    Jekyll::Hooks.register :site, :pre_render do |site|
      schema = site.config["front_matter_schema"]
      next if schema.nil? || schema.empty?

      fail_on_error = schema.fetch("fail_build_on_error", true)
      all_issues = []

      Jekyll::FrontMatterValidator.documents_for(site).each do |doc|
        rel_path = Jekyll::FrontMatterValidator.relative_path_for(doc, site)
        rules = Jekyll::FrontMatterValidator.rules_for(rel_path, schema)
        next unless Jekyll::FrontMatterValidator.has_rules?(rules)

        all_issues.concat(
          Jekyll::FrontMatterValidator.validate_all(doc.data, rules, file: rel_path, project_root: site.source)
        )
      end

      if all_issues.any?
        Jekyll.logger.error "FrontMatterValidator:", "#{all_issues.size} problema(s) encontrado(s) no front matter"
        all_issues.each { |i| Jekyll.logger.error "  ", i.to_s }

        if fail_on_error
          raise Jekyll::Errors::FatalException,
                "Build interrompido: front matter inválido em #{all_issues.map(&:file).uniq.size} arquivo(s)."
        end
      else
        Jekyll.logger.info "FrontMatterValidator:", "front matter ok \u2714"
      end
    end
  end
end
