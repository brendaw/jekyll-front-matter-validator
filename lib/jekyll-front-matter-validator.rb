# frozen_string_literal: true

require_relative "jekyll/front_matter_validator/version"
require_relative "jekyll/front_matter_validator/core"
require_relative "jekyll/front_matter_validator/jekyll_hook" if defined?(Jekyll::Hooks)
