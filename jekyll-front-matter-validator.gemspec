# frozen_string_literal: true

require_relative "lib/jekyll/front_matter_validator/version"

Gem::Specification.new do |spec|
  spec.name        = "jekyll-front-matter-validator"
  spec.version     = Jekyll::FrontMatterValidator::VERSION
  spec.authors     = ["William Brendaw"]
  spec.email       = ["william@brendaw.net"]

  spec.summary     = "Validates Jekyll front matter: required fields, types, slugs, and matching assets."
  spec.description = "Jekyll plugin + CLI that validates front matter (required fields, types, enums, " \
                      "slug format, and matching assets) on build, serve, and as a git pre-commit hook."
  spec.homepage    = "https://github.com/brendaw/jekyll-front-matter-validator"
  spec.license     = "MIT"

  spec.required_ruby_version = ">= 2.7"

  spec.files         = Dir["lib/**/*.rb", "exe/*", "README.md", "CHANGELOG.md"]
  spec.executables   = ["fmv-validate"]
  spec.bindir        = "exe"
  spec.require_paths = ["lib"]

  spec.add_dependency "jekyll", ">= 3.5", "< 5.0"

  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rubocop", "~> 1.50"

  spec.metadata["homepage_uri"] = spec.homepage
end
