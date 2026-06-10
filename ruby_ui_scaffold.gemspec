# frozen_string_literal: true

require_relative "lib/ruby_ui_scaffold/version"

Gem::Specification.new do |spec|
  spec.name = "ruby_ui_scaffold"
  spec.version = RubyUiScaffold::VERSION
  spec.authors = ["Jackson Pires"]
  spec.email = ["jackson@linkana.com"]

  spec.summary = "Rails scaffold generator that outputs Phlex views built with ruby_ui components."
  spec.description = "Provides `rails g ruby_ui_scaffold` — a drop-in replacement for `rails g scaffold` " \
                     "that generates model, controller, routes, tests, and Phlex view classes wired " \
                     "to ruby_ui components (Input, Textarea, Checkbox, Button, Table, FormField, etc.)."
  spec.homepage = "https://github.com/jacksonpires/ruby_ui_scaffold"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir[
    "lib/**/*",
    "README.md",
    "LICENSE.txt",
    "CHANGELOG.md"
  ].reject { |f| File.directory?(f) }

  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.require_paths = ["lib"]

  spec.add_dependency "railties", ">= 7.1"
  spec.add_dependency "phlex-rails", ">= 2.0"
  spec.add_dependency "literal", ">= 1.0"
  spec.add_dependency "faker", ">= 2.0"
  spec.add_dependency "lucide-rails", ">= 0.7"

  spec.add_development_dependency "rails", ">= 7.1"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "sqlite3", ">= 2.0"
end
