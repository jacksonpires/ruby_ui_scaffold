# frozen_string_literal: true

module RubyUiScaffold
  class Railtie < ::Rails::Railtie
    # The `generators` block runs only when Rails actually needs generators
    # (i.e. on `rails g`), not at app boot — important because
    # Rails::Generators isn't loaded at boot.
    generators do
      # Only set option defaults here — do NOT require any generator class.
      #
      # Rails runs every railtie's `generators` block BEFORE
      # `Rails::Generators.configure!(app.config.generators)` (see
      # Rails::Engine#load_generators). `hook_for`/`class_option` freeze their
      # defaults at class-definition time, so requiring our generators here
      # would also load Rails' ScaffoldGenerator → ModelGenerator early, and
      # their `:orm` hook would freeze as `false` (the pre-configure default)
      # instead of `:active_record` — silently skipping the model + migration
      # for `rails g ruby_ui_scaffold` AND plain `rails g model`.
      #
      # Our generator classes are instead loaded lazily by Rails' namespace
      # lookup (`generators/ruby_ui_scaffold/...`), after configure! has run,
      # and they read this template_engine default at that point. The
      # scaffold_controller default falls back to :scaffold_controller
      # (Rails-wide), which combined with our base_name routes to ours.
      ::Rails::Generators.options[:ruby_ui_scaffold] ||= {}
      ::Rails::Generators.options[:ruby_ui_scaffold][:template_engine] = "ruby_ui_scaffold"
    end
  end
end
