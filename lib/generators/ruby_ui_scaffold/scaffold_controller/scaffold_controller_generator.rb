# frozen_string_literal: true

require "rails/generators"
require "rails/generators/rails/scaffold_controller/scaffold_controller_generator"
require "ruby_ui_scaffold/attribute_helpers"

module RubyUiScaffold
  module Generators
    # Inherits Rails' ScaffoldControllerGenerator but:
    #   (1) Overrides its controller template (controller.rb.tt) to render
    #       Phlex view classes instead of ERB partials.
    #   (2) Redirects the template_engine hook to `ruby_ui_scaffold:scaffold`
    #       so our Phlex view generator runs (instead of erb:scaffold).
    class ScaffoldControllerGenerator < ::Rails::Generators::ScaffoldControllerGenerator
      include ::RubyUiScaffold::AttributeHelpers

      source_root File.expand_path("templates", __dir__)

      class_option :phlex_layout, type: :string, default: nil, banner: "LayoutClass",
        desc: "Emit `layout false` so generated views can wrap themselves in a Phlex layout class"
      class_option :datatable, type: :boolean, default: false,
        desc: "Emit the DataTable-aware controller variant (params parsing + scope building for search/sort/pagination)"
      # Declared only so the option passes cleanly down the hook chain to the
      # views generator (which actually acts on it); the controller ignores it.
      class_option :skip_install, type: :boolean, default: false,
        desc: "Don't auto-run `ruby_ui_scaffold:install` when phlex/ruby_ui aren't detected — only warn"

      remove_hook_for :template_engine
      hook_for :template_engine, as: :scaffold, default: "ruby_ui_scaffold" do |template_engine|
        invoke template_engine unless options.api?
      end

      # Pick the right controller template based on --datatable. Default is
      # the simple controller (Model.all + render Index.new(models:)). With
      # --datatable, emit the variant with SORTABLE_COLUMNS + params parsing +
      # scope building.
      def create_controller_files
        source = options[:datatable] ? "controller_data_table.rb" : "controller.rb"
        template source, File.join("app/controllers", controller_class_path, "#{controller_file_name}_controller.rb")
      end
    end
  end
end
