# frozen_string_literal: true

module RubyUiScaffold
  class Railtie < ::Rails::Railtie
    # The `generators` block runs only when Rails actually needs generators
    # (i.e. on `rails g`), not at app boot — important because
    # Rails::Generators isn't loaded at boot.
    generators do
      # IMPORTANT: set option defaults BEFORE requiring the generator
      # classes. `class_option(...)` (called by `hook_for`) freezes the
      # default at class-definition time via `default_value_for_option`,
      # which reads from Rails::Generators.options.
      #
      # We only need to override template_engine — the scaffold_controller
      # default falls back to :scaffold_controller (Rails-wide), which
      # combined with our base_name routes correctly to ours.
      ::Rails::Generators.options[:ruby_ui_scaffold] ||= {}
      ::Rails::Generators.options[:ruby_ui_scaffold][:template_engine] = "ruby_ui_scaffold"

      require "generators/ruby_ui_scaffold/ruby_ui_scaffold_generator"
      require "generators/ruby_ui_scaffold/scaffold_controller/scaffold_controller_generator"
      require "generators/ruby_ui_scaffold/scaffold/scaffold_generator"
    end
  end
end
