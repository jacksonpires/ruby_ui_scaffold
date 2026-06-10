# frozen_string_literal: true

require "ruby_ui_scaffold/version"
require "ruby_ui_scaffold/field_type_mapper"
require "ruby_ui_scaffold/attribute_helpers"
require "ruby_ui_scaffold/component_resolver"
require "ruby_ui_scaffold/component_installer"
require "ruby_ui_scaffold/value_generator"
require "ruby_ui_scaffold/seeder"

# Make sure transitive deps' Railties fire when the gem is loaded via
# Bundler.require. Without these, the helpers (lucide_icon, Faker) aren't
# registered in the host app, the `phlex:install` / `ruby_ui:component`
# generators aren't discoverable, and the generated views/seed command crash.
require "phlex-rails"
require "literal"
require "lucide-rails"

require "ruby_ui_scaffold/railtie" if defined?(Rails::Railtie)

module RubyUiScaffold
end
