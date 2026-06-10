# frozen_string_literal: true

require "rails/generators"
require "rails/generators/rails/scaffold/scaffold_generator"

module RubyUiScaffold
  module Generators
    # Entry point: `rails g ruby_ui_scaffold User name:string ...`
    #
    # Inherits the full scaffold pipeline from Rails (model, migration,
    # resource route, tests, helper), but redirects the scaffold_controller
    # hook to our subclass — which in turn redirects the template_engine
    # hook to our Phlex views generator.
    class RubyUiScaffoldGenerator < ::Rails::Generators::ScaffoldGenerator
      # Override the auto-derived namespace ("ruby_ui_scaffold:ruby_ui_scaffold")
      # to flat "ruby_ui_scaffold". This is critical because find_by_namespace
      # iterates lookups in order — leaving the namespace at the nested form
      # would cause `ruby_ui_scaffold:ruby_ui_scaffold` to shadow lookups for
      # `ruby_ui_scaffold:scaffold` (our views generator) and `ruby_ui_scaffold:
      # scaffold_controller` (our controller generator), creating silent
      # recursion when those hooks fire.
      namespace "ruby_ui_scaffold"

      # Redirect scaffold_controller hook to our subclass. `as: :scaffold_controller`
      # makes the find_by_namespace lookup resolve `ruby_ui_scaffold:scaffold_controller`
      # (via its name:context form) instead of `ruby_ui_scaffold:ruby_ui_scaffold`.
      remove_hook_for :scaffold_controller
      hook_for :scaffold_controller, as: :scaffold_controller, required: true

      # Wrap each generated view_template in `render(<ClassName>) do ... end`
      # and emit `layout false` in the controller. Use when your app has a
      # Phlex layout class (with `include Phlex::Rails::Layout`) that you
      # want every scaffolded page to render inside.
      class_option :phlex_layout, type: :string, default: nil, banner: "LayoutClass",
        desc: "Wrap each generated view in `render(LayoutClass) do ... end` and skip the default Rails layout"

      # When true, the index uses ruby_ui's `DataTable` (search, per-page,
      # sortable headers, manual pagination) and the controller bakes in the
      # params parsing + scope building. Default: plain `Table` (no toolbar,
      # no pagination — controller just does Model.all).
      class_option :datatable, type: :boolean, default: false,
        desc: "Generate the index using ruby_ui DataTable (search + sort + pagination) instead of a plain Table"

      # When true, the generated Phlex views use Literal's `prop` macros
      # instead of explicit `def initialize` + `@ivar` assignments. Less
      # boilerplate per view; runtime type-checking included. Also injects
      # `extend Literal::Properties` into `app/components/base.rb` on first
      # use (idempotent).
      class_option :literal, type: :boolean, default: false,
        desc: "Use Literal's `prop` macros instead of explicit `def initialize` blocks (https://literal.fun)"

      # By default, generating a scaffold auto-runs the idempotent
      # `ruby_ui_scaffold:install` when phlex/ruby_ui aren't detected yet, so
      # the generated views work out of the box. Pass --skip-install to only
      # print a warning instead (the pre-auto-install behavior).
      class_option :skip_install, type: :boolean, default: false,
        desc: "Don't auto-run `ruby_ui_scaffold:install` when phlex/ruby_ui aren't detected — only warn"

      # Skip model/migration/model-test/fixtures generation (the whole `:orm`
      # hook), regenerating only the controller, views, helper, and route.
      # Intended for RE-RUNS against a model that already exists — e.g. to
      # refresh the views after a template change, or to add `--datatable`
      # without Rails creating a duplicate migration or clobbering the model.
      #
      # Implies `--force`: a re-run otherwise aborts on the controller's class
      # collision check (the controller is already defined), and the point is
      # to overwrite the regenerated files without per-file prompts. The model
      # is never touched (its hook is skipped), so custom model code is safe —
      # the mental model is "model = your code, controller/views = generated".
      class_option :skip_model, type: :boolean, default: false,
        desc: "Skip model/migration/fixtures and only regenerate controller/views/routes (implies --force; for re-runs)"

      # --skip-model implies --force: a re-run otherwise aborts on the
      # controller's class-collision check (the controller already exists), and
      # the intent is to overwrite the regenerated controller/views. We inject
      # "--force" into the RAW options before Thor parses them — not by mutating
      # `options` afterward — because the controller/views sub-generators are
      # invoked by re-parsing the original init options stored in Thor's
      # `@_initializer` (see Thor::Invocation#_parse_initialization_options). A
      # post-parse mutation of `options` never reaches them; a real flag does.
      def initialize(args, local_options = {}, config = {})
        local_options = imply_force(local_options) if skip_model_requested?(local_options)
        super
      end

      # Command for the inherited `:orm` hook (model + migration + model test +
      # fixtures). Thor generates it as `_invoke_from_option_orm`; we override
      # it to no-op under --skip-model while leaving `options[:orm]` intact, so
      # orm helpers and option propagation to the controller are unaffected.
      def _invoke_from_option_orm
        return if options[:skip_model]

        super
      end

      private

      # Detect --skip-model from the raw init options, which may be the CLI
      # option-string array (the usual `rails g` path) or a pre-parsed hash
      # (programmatic instantiation / tests).
      def skip_model_requested?(local_options)
        if local_options.is_a?(Array)
          local_options.include?("--skip-model") || local_options.include?("--skip_model")
        else
          !!(local_options[:skip_model] || local_options["skip_model"])
        end
      end

      # Add force to the raw options (array or hash) without duplicating it.
      def imply_force(local_options)
        if local_options.is_a?(Array)
          local_options.include?("--force") ? local_options : local_options + ["--force"]
        else
          local_options.merge(force: true)
        end
      end
    end
  end
end
