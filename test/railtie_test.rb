# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "rbconfig"

# Regression test for the Railtie's `generators` block.
#
# Rails boots generators as: run every railtie's `generators` block, THEN
# `Rails::Generators.configure!(app.config.generators)` (see
# Rails::Engine#load_generators). `hook_for` freezes option defaults at
# class-definition time, so if our block requires Rails' scaffold generator
# classes, `ModelGenerator`'s `:orm` hook freezes as `false` (the pre-configure
# default) instead of `:active_record` — and `rails g ruby_ui_scaffold` (and
# even plain `rails g model`) silently skips the model + migration.
#
# This can't run in-process: test_helper already loads every generator class,
# which is exactly the state we need to avoid. So it boots a minimal app in a
# subprocess, through the real `load_generators` path.
class RailtieTest < Minitest::Test
  LIB = File.expand_path("../lib", __dir__)

  SCRIPT = <<~'RUBY'
    require "rails"
    require "active_record/railtie"
    require "action_controller/railtie"
    require "ruby_ui_scaffold"

    class RailtieTestApp < Rails::Application
      config.eager_load = false
      config.logger = Logger.new(nil)
      config.secret_key_base = "x" * 64
    end

    Rails.application.load_generators

    model = Rails::Generators.find_by_namespace("model")
    scaffold = Rails::Generators.find_by_namespace("ruby_ui_scaffold")
    puts "model_orm=#{model.class_options[:orm].default.inspect}"
    puts "scaffold_class=#{scaffold}"
    puts "scaffold_orm=#{scaffold.class_options[:orm].default.inspect}"
    # Resolve the sub-generators exactly as the hook chain does at runtime
    # (hook_for → prepare_for_invocation → find_by_namespace(value, base, as)),
    # not by a direct namespace lookup: Rails requires only the first existing
    # candidate file, which is what broke lazily-loaded hook targets before.
    resolve = ->(klass, hook) { klass.send(:prepare_for_invocation, hook, klass.class_options[hook].default) }
    controller = resolve.(scaffold, :scaffold_controller)
    views = resolve.(controller, :template_engine)
    puts "controller_class=#{controller}"
    puts "views_class=#{views}"
    puts "template_engine=#{controller.class_options[:template_engine].default.inspect}"
  RUBY

  def boot_generators
    out, err, status = Open3.capture3(RbConfig.ruby, "-rbundler/setup", "-I", LIB, "-e", SCRIPT)
    assert status.success?, "subprocess failed:\n#{err}"
    out.lines.to_h { |line| line.chomp.split("=", 2) }
  end

  def test_generators_block_does_not_freeze_orm_before_configure
    result = boot_generators

    assert_equal ":active_record", result["model_orm"],
      "Plain `rails g model` lost its ORM — the Railtie loaded Rails' generator classes before configure!"
    assert_equal "RubyUiScaffold::Generators::RubyUiScaffoldGenerator", result["scaffold_class"]
    assert_equal ":active_record", result["scaffold_orm"],
      "`rails g ruby_ui_scaffold` would skip the model + migration"
    # The hook chain still resolves to our (lazily loaded) sub-generators.
    assert_equal "RubyUiScaffold::Generators::ScaffoldControllerGenerator", result["controller_class"]
    assert_equal "RubyUiScaffold::Generators::ScaffoldGenerator", result["views_class"]
    assert_equal '"ruby_ui_scaffold"', result["template_engine"]
  end
end
