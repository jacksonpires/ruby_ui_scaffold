# frozen_string_literal: true

require "test_helper"

# Tests the install generator (`ruby_ui_scaffold:install`).
#
# We do NOT exercise the real `phlex:install` / `ruby_ui:install` / `ruby_ui:component`
# generators here — those require ruby_ui to be loaded and would touch the
# destination in ways outside this gem's surface. Instead, we prepend a module
# onto InstallGenerator that captures `run_rails_generator!` calls into a
# thread-local list (and returns success so the installer continues).
module RubyUiScaffoldInstallGenerateCapture
  def run_rails_generator!(name, *args)
    Thread.current[:invoked_generators] ||= []
    Thread.current[:invoked_generators] << [name, args]
    nil
  end

  # Let a test force ruby_ui to look "not bundled" so the gem-bootstrap path
  # (`ensure_ruby_ui_gem`) runs, even though setup defines ::RubyUI globally.
  def ruby_ui_loadable?
    return false if Thread.current[:force_ruby_ui_unloadable]

    super
  end

  # Capture the bundle step instead of actually shelling out to `bundle
  # install` (which would hit the network for the GitHub gem).
  def run_bundle_install!
    Thread.current[:bundle_installed] = true
  end
end
RubyUiScaffold::Generators::InstallGenerator.prepend(RubyUiScaffoldInstallGenerateCapture)

class InstallGeneratorTest < Rails::Generators::TestCase
  tests RubyUiScaffold::Generators::InstallGenerator

  destination File.expand_path("../tmp", __dir__)
  setup :prepare_destination
  setup :stub_ruby_ui_loadable
  setup :stub_phlex_rails_loaded_spec
  setup :reset_capture

  def test_invokes_phlex_install_when_views_base_missing
    run_generator

    assert_invoked "phlex:install"
  end

  def test_skips_phlex_install_when_views_base_present
    write(<<~RUBY, to: "app/views/base.rb")
      class Views::Base < Components::Base
      end
    RUBY

    run_generator

    refute_invoked "phlex:install"
  end

  def test_invokes_ruby_ui_install_when_components_base_missing
    run_generator

    assert_invoked "ruby_ui:install"
  end

  def test_skips_ruby_ui_install_when_components_base_already_includes_ruby_ui
    write(<<~RUBY, to: "app/components/base.rb")
      class Components::Base < Phlex::HTML
        include RubyUI
      end
    RUBY

    run_generator

    refute_invoked "ruby_ui:install"
  end

  def test_invokes_ruby_ui_install_when_components_base_present_but_missing_ruby_ui_mixin
    write(<<~RUBY, to: "app/components/base.rb")
      class Components::Base < Phlex::HTML
      end
    RUBY

    run_generator

    assert_invoked "ruby_ui:install"
  end

  def test_never_invokes_component_all
    # The installer no longer installs every component upfront — base set only.
    run_generator

    refute_invoked "ruby_ui:component:all"
  end

  def test_invokes_each_base_component_when_none_installed
    run_generator

    RubyUiScaffold::ComponentResolver::BASE.each do |component|
      assert(
        @invoked_generators.any? { |name, args| name == "ruby_ui:component" && args == [component] },
        "Expected base component `ruby_ui:component #{component}` to be invoked"
      )
    end
  end

  def test_does_not_install_conditional_components
    # badge/checkbox/textarea/combobox/select/date_picker/data_table are the
    # scaffold's on-demand concern — the installer must NOT install them.
    run_generator

    invoked_names = @invoked_generators.select { |n, _| n == "ruby_ui:component" }.map { |_, a| a.first }
    %w[badge checkbox textarea combobox select date_picker data_table].each do |conditional|
      refute_includes invoked_names, conditional
    end
  end

  def test_skips_base_components_that_already_exist_as_directories
    write_dir("app/components/ruby_ui/link")
    write_dir("app/components/ruby_ui/table")

    run_generator

    component_calls = @invoked_generators.select { |name, _| name == "ruby_ui:component" }
    invoked_names = component_calls.map { |_, args| args.first }
    refute_includes invoked_names, "link"
    refute_includes invoked_names, "table"
    # The rest of the base set should still be invoked
    assert_includes invoked_names, "alert_dialog"
  end

  def test_skips_base_components_that_already_exist_as_files
    write("# noop\n", to: "app/components/ruby_ui/link.rb")

    run_generator

    component_calls = @invoked_generators.select { |name, _| name == "ruby_ui:component" }
    invoked_names = component_calls.map { |_, args| args.first }
    refute_includes invoked_names, "link"
  end

  def test_injects_tailwind_sources_when_application_css_present
    write(<<~CSS, to: "app/assets/tailwind/application.css")
      @import "tailwindcss";

      @custom-variant dark (&:is(.dark *));
    CSS

    run_generator

    contents = File.read(File.join(destination_root, "app/assets/tailwind/application.css"))
    assert_match(%r{@source "\.\./\.\./views/\*\*/\*\.rb"}, contents)
    assert_match(%r{@source "\.\./\.\./components/\*\*/\*\.rb"}, contents)
  end

  def test_tailwind_sources_injection_is_idempotent
    write(<<~CSS, to: "app/assets/tailwind/application.css")
      @import "tailwindcss";

      @source "../../views/**/*.rb";
      @source "../../components/**/*.rb";
    CSS

    run_generator

    contents = File.read(File.join(destination_root, "app/assets/tailwind/application.css"))
    assert_equal 1, contents.scan(%r{@source "\.\./\.\./views/\*\*/\*\.rb"}).count
    assert_equal 1, contents.scan(%r{@source "\.\./\.\./components/\*\*/\*\.rb"}).count
  end

  def test_does_not_fail_when_application_css_is_absent
    # Older apps or non-Tailwind setups won't have this file. The action
    # should silently skip rather than crash.
    refute File.exist?(File.join(destination_root, "app/assets/tailwind/application.css"))

    run_generator
    # No exception = pass
  end

  # ---- ruby_ui gem bootstrap (ensure_ruby_ui_gem) ----

  def test_adds_ruby_ui_to_gemfile_and_bundles_when_not_loadable
    Thread.current[:force_ruby_ui_unloadable] = true
    write(<<~RUBY, to: "Gemfile")
      source "https://rubygems.org"
      gem "rails"
    RUBY

    run_generator

    gemfile = File.read(File.join(destination_root, "Gemfile"))
    assert_match(%r{gem ["']ruby_ui["'].*github: ["']ruby-ui/ruby_ui["']}, gemfile)
    assert Thread.current[:bundle_installed], "Expected `bundle install` to run"
    # After bootstrapping the gem, the installer still proceeds to ruby_ui:install
    assert_invoked "ruby_ui:install"
  end

  def test_does_not_duplicate_ruby_ui_gem_when_already_in_gemfile
    Thread.current[:force_ruby_ui_unloadable] = true
    write(<<~RUBY, to: "Gemfile")
      source "https://rubygems.org"
      gem "ruby_ui", github: "ruby-ui/ruby_ui", branch: "main", require: false
    RUBY

    run_generator

    gemfile = File.read(File.join(destination_root, "Gemfile"))
    assert_equal 1, gemfile.scan(/gem ["']ruby_ui["']/).count
    # Still bundles (the entry exists but the gem wasn't loadable yet)
    assert Thread.current[:bundle_installed], "Expected `bundle install` to run"
  end

  def test_does_not_touch_gemfile_when_ruby_ui_already_loadable
    # Default setup makes ruby_ui loadable — the bootstrap path must be skipped.
    write(<<~RUBY, to: "Gemfile")
      source "https://rubygems.org"
      gem "rails"
    RUBY

    run_generator

    gemfile = File.read(File.join(destination_root, "Gemfile"))
    refute_match(/ruby_ui/, gemfile)
    refute Thread.current[:bundle_installed], "Should not bundle when ruby_ui is already loadable"
  end

  def test_base_components_list_is_not_empty
    # Catch regressions where the base set gets accidentally cleared.
    assert RubyUiScaffold::ComponentResolver::BASE.any?
    assert_includes RubyUiScaffold::ComponentResolver::BASE, "table"
    assert_includes RubyUiScaffold::ComponentResolver::BASE, "alert_dialog"
    assert_includes RubyUiScaffold::ComponentResolver::BASE, "form"
  end

  private

  def write(content, to:)
    full = File.join(destination_root, to)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, content)
  end

  def write_dir(path)
    FileUtils.mkdir_p(File.join(destination_root, path))
  end

  # `defined?(::RubyUI)` is false in the test process (we don't load ruby_ui).
  # The installer's preflight tries `require "ruby_ui"` as a fallback — stub
  # that path to succeed so the rest of the generator runs.
  def stub_ruby_ui_loadable
    @ruby_ui_was_defined = Object.const_defined?(:RubyUI)
    Object.const_set(:RubyUI, Module.new) unless @ruby_ui_was_defined
  end

  # The installer aborts if `phlex-rails` isn't in the bundle. We don't bundle
  # it in the gem's own test process, so stub the loaded-specs lookup.
  def stub_phlex_rails_loaded_spec
    @stub_phlex = !Gem.loaded_specs.key?("phlex-rails")
    Gem.loaded_specs["phlex-rails"] = Gem::Specification.new("phlex-rails", "2.0.0") if @stub_phlex
  end

  def teardown
    Object.send(:remove_const, :RubyUI) if !@ruby_ui_was_defined && Object.const_defined?(:RubyUI)
    Gem.loaded_specs.delete("phlex-rails") if @stub_phlex
  end

  # Reset the capture array before each test so assertions only see the
  # current run's invocations.
  def reset_capture
    Thread.current[:invoked_generators] = []
    Thread.current[:force_ruby_ui_unloadable] = false
    Thread.current[:bundle_installed] = false
    @invoked_generators = Thread.current[:invoked_generators]
  end

  def assert_invoked(name)
    assert(
      @invoked_generators.any? { |n, _| n == name },
      "Expected `#{name}` to be invoked. Invoked: #{@invoked_generators.inspect}"
    )
  end

  def refute_invoked(name)
    refute(
      @invoked_generators.any? { |n, _| n == name },
      "Expected `#{name}` NOT to be invoked. Invoked: #{@invoked_generators.inspect}"
    )
  end
end
