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

    # Runs automatically on `jekyll build` AND `jekyll serve`, because
    # serve triggers the same build pipeline (and again on each
    # regeneration when --watch detects changes).
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
        Jekyll.logger.error "FrontMatterValidator:", "#{all_issues.size} issue(s) found in front matter"
        all_issues.each { |i| Jekyll.logger.error "  ", i.to_s }

        if fail_on_error
          warn "\e[31mBuild failed: invalid front matter in #{all_issues.map(&:file).uniq.size} file(s).\e[0m"
          $stderr.flush
          exit!(1)
        end
      else
        Jekyll.logger.info "FrontMatterValidator:", "front matter OK \u2714"
      end
    end
  end
end
