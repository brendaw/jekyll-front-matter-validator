# frozen_string_literal: true

require_relative "lib/jekyll/front_matter_validator/version"

Gem::Specification.new do |spec|
  spec.name        = "jekyll-front-matter-validator"
  spec.version     = Jekyll::FrontMatterValidator::VERSION
  spec.authors     = ["William Brendaw"]
  spec.email       = ["william@brendaw.net"]

  spec.summary     = "Valida front matter do Jekyll: obrigatórios, tipos, slugs e assets correspondentes."
  spec.description = "Plugin Jekyll + CLI que valida front matter (campos obrigatórios, tipos, enums, " \
                      "formato de slug e existência de assets correspondentes) no build, no serve e " \
                      "como hook de pre-commit do git."
  spec.homepage    = "https://github.com/brendaw/jekyll-front-matter-validator"
  spec.license     = "MIT"

  spec.required_ruby_version = ">= 2.7"

  spec.files         = Dir["lib/**/*.rb", "exe/*", "README.md", "CHANGELOG.md"]
  spec.executables   = ["fmv-validate"]
  spec.bindir        = "exe"
  spec.require_paths = ["lib"]

  spec.add_dependency "jekyll", ">= 3.5", "< 5.0"

  spec.metadata["homepage_uri"] = spec.homepage
end
