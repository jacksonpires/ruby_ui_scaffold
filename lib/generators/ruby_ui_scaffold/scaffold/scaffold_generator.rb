# frozen_string_literal: true

require "rails/generators/named_base"
require "rails/generators/resource_helpers"
require "ruby_ui_scaffold/field_type_mapper"
require "ruby_ui_scaffold/attribute_helpers"
require "ruby_ui_scaffold/component_resolver"
require "ruby_ui_scaffold/component_installer"

module RubyUiScaffold
  module Generators
    # The "template engine" — generates the Phlex view classes
    # for index, show, new, edit, and a shared form under the
    # `Views::` namespace (matches the convention installed by
    # `phlex:install`, which creates `Views::Base` and wires the
    # `app/views/` autoloader).
    #
    # Invoked indirectly via `ruby_ui_scaffold:scaffold_controller`,
    # which sets template_engine default to `ruby_ui_scaffold`.
    class ScaffoldGenerator < ::Rails::Generators::NamedBase
      include ::Rails::Generators::ResourceHelpers
      include ::RubyUiScaffold::AttributeHelpers
      include ::RubyUiScaffold::ComponentInstaller

      source_root File.expand_path("templates", __dir__)

      argument :attributes, type: :array, default: [], banner: "field:type field:type"

      class_option :api, type: :boolean, default: false
      class_option :force_plural, type: :boolean, default: false
      class_option :phlex_layout, type: :string, default: nil, banner: "LayoutClass",
        desc: "Wrap each generated view in `render(LayoutClass) do ... end`"
      class_option :datatable, type: :boolean, default: false,
        desc: "Emit the DataTable index variant (search + sort + pagination) instead of a plain Table"
      class_option :literal, type: :boolean, default: false,
        desc: "Use Literal's `prop` macros instead of `def initialize` (https://literal.fun)"
      class_option :skip_install, type: :boolean, default: false,
        desc: "Don't auto-run `ruby_ui_scaffold:install` when phlex/ruby_ui aren't detected — only warn"

      # Generator action — runs before view files are written. The generated
      # views need phlex (`Views::Base`) and ruby_ui (`RubyUI` mixed into
      # `Components::Base`); without them, requests 500 at runtime. When either
      # is missing we auto-run the idempotent `ruby_ui_scaffold:install` so the
      # scaffold works out of the box. Falls back to a non-blocking warning when
      # auto-install isn't possible (no app `bin/rails`) or is opted out with
      # `--skip-install`.
      def preflight_checks
        return if behavior == :revoke

        ensure_phlex_and_ruby_ui_installed
      end

      def create_view_files
        empty_directory File.join("app/views", controller_file_path)

        # Index has two flavors: plain Table (default) or DataTable (--datatable).
        # Both compile down to `app/views/<resource>/index.rb`.
        index_template = options[:datatable] ? "index_data_table.rb.tt" : "index.rb.tt"
        template index_template, File.join("app/views", controller_file_path, "index.rb")

        %w[show new edit form].each do |view|
          template "#{view}.rb.tt", File.join("app/views", controller_file_path, "#{view}.rb")
        end
      end

      # Inject the Phlex helpers the scaffold-generated views rely on into
      # `Components::Base`. `phlex:install` / `ruby_ui:install` create the
      # file but only include `Phlex::Rails::Helpers::Routes` + RubyUI — the
      # scaffold also needs `form_with`, `link_to`, `button_to`, `request`
      # (for the form's "Back" link), and `lucide_icon`. When `--literal` is
      # passed, also `extend
      # Literal::Properties` so the generated views' `prop` macros resolve.
      # Each line is added only if missing, so re-running is safe.
      def inject_scaffold_helpers_into_components_base
        return if behavior == :revoke

        components_base = File.join(destination_root, "app/components/base.rb")
        return unless File.exist?(components_base)

        contents = File.read(components_base)

        helpers = []
        helpers << "  extend Literal::Properties" if options[:literal] && !contents.include?("Literal::Properties")
        helpers << "  include Phlex::Rails::Helpers::FormWith" unless contents.include?("Phlex::Rails::Helpers::FormWith")
        helpers << "  include Phlex::Rails::Helpers::LinkTo" unless contents.include?("Phlex::Rails::Helpers::LinkTo")
        helpers << "  include Phlex::Rails::Helpers::ButtonTo" unless contents.include?("Phlex::Rails::Helpers::ButtonTo")
        helpers << "  include Phlex::Rails::Helpers::Request" unless contents.include?("Phlex::Rails::Helpers::Request")
        helpers << "  register_output_helper :lucide_icon" unless contents.include?("register_output_helper :lucide_icon")

        return if helpers.empty?

        inject_into_file components_base, after: /class Components::Base.*\n/ do
          helpers.join("\n") + "\n"
        end
      end

      # Install the ruby_ui components THIS scaffold references, on demand,
      # after the views are written. The BASE set is already installed by
      # `ruby_ui_scaffold:install`; here we add the column/flag-specific ones
      # (badge, checkbox, textarea, combobox, select, date_picker, data_table)
      # — but request the full set and skip whatever's already present, so it
      # works whether or not `:install` ran first. Non-blocking: a component
      # that fails to install just warns (the view files already exist). Gated
      # like the auto-install: skipped on --skip-install or when there's no app
      # `bin/rails` to drive `ruby_ui:component` (e.g. the test harness).
      def install_required_components
        return if behavior == :revoke
        return if options[:skip_install] || !app_bin_rails?

        needed = ::RubyUiScaffold::ComponentResolver.call(
          attributes: attributes, datatable: options[:datatable]
        )
        missing = uninstalled_components(needed)
        return if missing.empty?

        say "\n  → Installing #{missing.size} ruby_ui component(s) this scaffold uses", :cyan
        missing.each do |component|
          say "      • #{component}", :cyan
          install_ruby_ui_component(component)
        end
      end

      private

      # Shell out to `ruby_ui:component NAME` in a clean process (which boots
      # with the current bundle and resolves the component's transitive deps).
      # Warn-and-continue on failure — unlike the installer's abort, the views
      # are already written, so a single missing component shouldn't tear down
      # the run.
      def install_ruby_ui_component(component)
        ok = in_root { system("bin/rails", "generate", "ruby_ui:component", component) }
        return if ok

        say "  ⚠️  Couldn't install ruby_ui component `#{component}`.", :yellow
        say "     Run `bin/rails g ruby_ui:component #{component}` manually.", :yellow
      end

      # Auto-run `ruby_ui_scaffold:install` when phlex/ruby_ui aren't set up.
      # The installer is idempotent, so it's safe even if one of the two is
      # already present. Falls back to a warning when opted out or when there's
      # no app `bin/rails` to drive the installer (e.g. the generator test
      # harness, or a non-standard app layout).
      def ensure_phlex_and_ruby_ui_installed
        return if phlex_installed? && ruby_ui_installed?

        if options[:skip_install] || !app_bin_rails?
          warn_missing_setup
          return
        end

        missing = []
        missing << "phlex" unless phlex_installed?
        missing << "ruby_ui" unless ruby_ui_installed?
        say "\n  → #{missing.join(" + ")} not detected — running `ruby_ui_scaffold:install` first.", :cyan
        say "    (idempotent; pass --skip-install to only warn instead)\n", :cyan

        run_install!
      end

      # Shell out to the installer in a clean process. We don't `invoke` it
      # in-process because the installer calls `exit(1)` on unrecoverable
      # errors (e.g. the ruby_ui gem isn't bundled) — a subprocess keeps that
      # from tearing down the scaffold run.
      def run_install!
        installed = in_root { system("bin/rails", "generate", "ruby_ui_scaffold:install") }
        return if installed && phlex_installed? && ruby_ui_installed?

        say "\n  ⚠️  Auto-install didn't finish the setup. Generating the scaffold files", :yellow
        say "     anyway — run `bin/rails g ruby_ui_scaffold:install` and resolve the", :yellow
        say "     error above before booting the app.\n", :yellow
      end

      def warn_missing_setup
        check_phlex_install
        check_ruby_ui_install
      end

      # Warn (don't abort) if `phlex:install` hasn't been run. Without it,
      # `Views::Base` doesn't exist and the autoloader isn't wired to resolve
      # `Views::<Resource>::Index` from `app/views/<resource>/index.rb`.
      def check_phlex_install
        return if phlex_installed?

        say "\n  ⚠️  phlex doesn't look installed (missing app/views/base.rb).", :yellow
        say "     Before requests will succeed, run:\n", :yellow
        say "         bin/rails g phlex:install\n", :cyan
      end

      # Warn (don't abort) if ruby_ui doesn't look installed. The generated
      # views use components like `Table`, `Link`, `DropdownMenu` etc., which
      # are mixed into Components::Base by `rails g ruby_ui:install`; without
      # it, requests 500 with NoMethodError on the first component call.
      def check_ruby_ui_install
        return if ruby_ui_installed?

        say "\n  ⚠️  ruby_ui doesn't look installed (missing app/components/base.rb or RubyUI mixin).", :yellow
        say "     Before requests will succeed, run:\n", :yellow
        say "         bin/rails g ruby_ui:install\n", :cyan
      end

      def phlex_installed?
        File.exist?(File.join(destination_root, "app/views/base.rb"))
      end

      def ruby_ui_installed?
        components_base = File.join(destination_root, "app/components/base.rb")
        File.exist?(components_base) && File.read(components_base).include?("RubyUI")
      end

      # Whether there's an app `bin/rails` we can shell out to. Absent in the
      # generator test harness (temp destination) and in any non-standard
      # layout — in those cases we warn instead of attempting auto-install.
      def app_bin_rails?
        File.exist?(File.join(destination_root, "bin/rails"))
      end

      # Called from form.rb.tt to emit the ruby_ui input snippet for a given
      # attribute. Handles multi-line snippets by indenting subsequent lines
      # to match the caller's column.
      def ruby_ui_input_for(attribute, indent: 6)
        snippet = RubyUiScaffold::FieldTypeMapper.render(attribute, model_var: singular_table_name)
        pad = " " * indent
        lines = snippet.split("\n", -1)
        return lines.first if lines.length == 1

        ([lines.first] + lines[1..].map { |line| pad + line }).join("\n")
      end

      # Phlex view class namespace, e.g. "Users" or "Admin::Users".
      def view_namespace
        controller_class_name
      end

      # First-level segment for the link helper, e.g. "users" -> "user_path".
      def show_path_helper(record_var)
        "#{singular_route_name}_url(#{record_var})"
      end

      def index_path_helper
        "#{plural_route_name}_url"
      end

      def new_path_helper
        "new_#{singular_route_name}_url"
      end

      def edit_path_helper(record_var)
        "edit_#{singular_route_name}_url(#{record_var})"
      end
    end
  end
end
