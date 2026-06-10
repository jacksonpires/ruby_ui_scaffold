# frozen_string_literal: true

require "rails/generators/base"
require "ruby_ui_scaffold/component_resolver"
require "ruby_ui_scaffold/component_installer"

module RubyUiScaffold
  module Generators
    # One-shot installer that wires up the prerequisites every scaffold needs
    # on a fresh Rails app: the ruby_ui gem, phlex, ruby_ui, and the BASE set
    # of components every generated scaffold uses (index/show/form shell).
    #
    # Column/flag-specific components (badge, checkbox, textarea, combobox,
    # select, date_picker, data_table) are NOT installed here — the scaffold
    # generator installs those on demand, so apps only carry what they use.
    #
    # Invoked as: `bin/rails g ruby_ui_scaffold:install`
    #
    # Every step is idempotent — re-running the installer is safe and only
    # touches what's actually missing.
    class InstallGenerator < ::Rails::Generators::Base
      include ::RubyUiScaffold::ComponentInstaller

      desc "Install the ruby_ui gem, phlex, ruby_ui, and the base scaffold components."

      def check_phlex_rails_gem
        return if Gem.loaded_specs.key?("phlex-rails")

        say "\n  ❌  The `phlex-rails` gem isn't bundled in this app.", :red
        say "      ruby_ui_scaffold declares it as a runtime dependency — running", :red
        say "      `bundle install` should pull it in. If you've excluded it via", :red
        say "      Bundler groups, add it back and retry:\n", :red
        say %(          gem "phlex-rails"), :cyan
        say "          bundle install"
        say "          bin/rails g ruby_ui_scaffold:install\n", :cyan
        exit(1)
      end

      # Ensure the `ruby_ui` gem is available. Unlike `phlex-rails` (a declared
      # runtime dependency of this gem), `ruby_ui` is distributed via GitHub and
      # can't be a gemspec dependency — so on a fresh app it usually isn't
      # bundled yet. Rather than abort, add it to the Gemfile and `bundle
      # install` automatically, then let the rest of the installer proceed:
      # the subsequent `ruby_ui:install` / `ruby_ui:component` steps run in
      # subprocesses (via run_rails_generator!) that boot with the freshly
      # updated bundle, so they find the gem even though THIS process didn't
      # load it. Idempotent — skips the Gemfile edit when an entry already
      # exists, and does nothing at all once the gem loads.
      def ensure_ruby_ui_gem
        return if ruby_ui_loadable?

        gemfile = File.join(destination_root, "Gemfile")
        abort_ruby_ui_unavailable! unless File.exist?(gemfile)

        if File.read(gemfile).match?(/^\s*gem\s+["']ruby_ui["']/)
          say "\n  → ruby_ui is in the Gemfile but not bundled yet — running `bundle install`.", :cyan
        else
          say "\n  → ruby_ui gem not found — adding it to your Gemfile.", :cyan
          gem "ruby_ui", github: "ruby-ui/ruby_ui", branch: "main", require: false
        end

        run_bundle_install!
      end

      def install_phlex
        if File.exist?(File.join(destination_root, "app/views/base.rb"))
          say "  ✓ phlex already installed (app/views/base.rb exists)", :green
          return
        end

        say "\n  → Running `phlex:install`", :cyan
        run_rails_generator!("phlex:install")
      end

      def install_ruby_ui
        components_base = File.join(destination_root, "app/components/base.rb")
        if File.exist?(components_base) && File.read(components_base).include?("RubyUI")
          say "  ✓ ruby_ui already installed (Components::Base includes RubyUI)", :green
          return
        end

        say "\n  → Running `ruby_ui:install`", :cyan
        run_rails_generator!("ruby_ui:install")
      end

      # Install the BASE components every scaffold uses (the index/show/form
      # shell), so a bare `:install` leaves the ground ready. We deliberately
      # don't run `ruby_ui:component:all` — column/flag-specific components are
      # installed on demand by the scaffold generator. `ruby_ui:component`
      # resolves transitive dependencies itself (e.g. alert_dialog → button),
      # so the BASE list only names what the scaffold references directly.
      def install_base_components
        missing = uninstalled_components(::RubyUiScaffold::ComponentResolver::BASE)

        if missing.empty?
          say "  ✓ Base scaffold components already installed", :green
          return
        end

        say "\n  → Installing #{missing.size} base component(s) every scaffold uses", :cyan
        missing.each do |component|
          say "      • #{component}", :cyan
          run_rails_generator!("ruby_ui:component", component)
        end
      end

      # Tailwind v4 auto-detection misses `.rb` files by default, so the
      # Phlex view + component class names never make it into the compiled
      # stylesheet — meaning `mx-auto`, `max-w-prose`, etc. render with no
      # effect. Inject explicit `@source` directives so Tailwind scans
      # `app/views/**/*.rb` and `app/components/**/*.rb`. Idempotent.
      def inject_tailwind_sources
        css_path = File.join(destination_root, "app/assets/tailwind/application.css")
        return unless File.exist?(css_path)

        contents = File.read(css_path)
        sources_to_add = []
        sources_to_add << %(@source "../../views/**/*.rb";) unless contents.include?("../../views/**/*.rb")
        sources_to_add << %(@source "../../components/**/*.rb";) unless contents.include?("../../components/**/*.rb")
        return if sources_to_add.empty?

        say "\n  → Adding Tailwind @source directives for Phlex views/components", :cyan
        inject_into_file css_path, after: /@import "tailwindcss";\n/ do
          "\n" + sources_to_add.join("\n") + "\n"
        end
      end

      def done
        say "\n  ✅ ruby_ui_scaffold install complete.", :green
        say "\n     Generate your first scaffold:\n", :cyan
        say "         bin/rails g ruby_ui_scaffold MyModel name:string\n", :cyan
      end

      private

      # No Gemfile to add ruby_ui to — fall back to the manual instructions.
      def abort_ruby_ui_unavailable!
        say "\n  ❌  The `ruby_ui` gem isn't available and no Gemfile was found to add it to.", :red
        say "      Add it to your Gemfile, then bundle and retry:\n", :red
        say %(          gem "ruby_ui", github: "ruby-ui/ruby_ui", branch: "main", require: false), :cyan
        say "          bundle install"
        say "          bin/rails g ruby_ui_scaffold:install\n", :cyan
        exit(1)
      end

      def run_bundle_install!
        say_status :run, "bundle install", :cyan
        success = in_root { system("bundle", "install") }
        return if success

        say "\n  ❌  `bundle install` failed after adding ruby_ui to the Gemfile.", :red
        say "      Resolve the error above, then re-run `bin/rails g ruby_ui_scaffold:install` —", :red
        say "      it's idempotent, so anything already installed stays installed.", :yellow
        exit(1)
      end

      # ruby_ui ships with `require: false` in the recommended Gemfile entry,
      # so it may not be autoloaded yet — try requiring it before giving up.
      def ruby_ui_loadable?
        return true if defined?(::RubyUI)

        require "ruby_ui"
        true
      rescue LoadError
        false
      end

      # Shell-out to `bin/rails generate NAME [ARGS...]` and abort if the
      # subprocess exits non-zero. We don't use Thor's `generate` action
      # because its `abort_on_failure` doesn't reliably propagate when the
      # failure originates inside the inner Rails command (e.g. Bundler
      # bootstrap errors swallow the exit code). Without explicit checks,
      # one bad step would silently cascade into dozens of follow-up
      # failures with the same root cause.
      def run_rails_generator!(name, *args)
        cmd = ["bin/rails", "generate", name, *args].compact
        say_status :run, cmd.join(" "), :cyan
        success = in_root { system(*cmd) }
        return if success

        say "\n  ❌  `#{cmd.join(" ")}` failed (exit #{$?.exitstatus}).", :red
        say "      Aborting ruby_ui_scaffold:install. Fix the error above and retry —", :red
        say "      every step is idempotent, so what's already installed stays installed.", :yellow
        exit(1)
      end
    end
  end
end
