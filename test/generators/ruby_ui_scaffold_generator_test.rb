# frozen_string_literal: true

require "test_helper"
require "rails/generators/active_record"

# Tests the entry generator (`ruby_ui_scaffold`) — specifically the --skip-model
# behavior. The rest of the chain (controller/views/route) is covered by the
# dedicated scaffold_controller/scaffold generator tests.
class RubyUiScaffoldGeneratorTest < Rails::Generators::TestCase
  tests RubyUiScaffold::Generators::RubyUiScaffoldGenerator

  destination File.expand_path("../tmp", __dir__)
  setup :prepare_destination

  def generator_class
    RubyUiScaffold::Generators::RubyUiScaffoldGenerator
  end

  def test_skip_model_option_is_declared_and_defaults_off
    assert generator_class.class_options.key?(:skip_model)
    refute generator_class.class_options[:skip_model].default
  end

  def test_skip_model_implies_force
    gen = generator_class.new(["User", "name:string"], { "skip_model" => true })
    assert gen.options.force?, "Expected --skip-model to imply --force"
  end

  def test_without_skip_model_does_not_force
    gen = generator_class.new(["User", "name:string"], {})
    refute gen.options.force?
  end

  # The real `rails g` path passes options as a CLI string array, not a hash.
  def test_skip_model_via_cli_array_implies_force
    gen = generator_class.new(["User", "name:string"], ["--skip-model"])
    assert gen.options.force?, "Expected --skip-model (array form) to imply --force"
    assert gen.options[:skip_model]
  end

  # The fix's crux: sub-generators (scaffold_controller/views) re-parse the
  # options stored in Thor's @_initializer, so --force must live there to
  # propagate and bypass the controller's collision check on a re-run.
  def test_skip_model_force_is_stored_for_subgenerator_propagation
    gen = generator_class.new(["User", "name:string"], ["--skip-model"])
    stored_options = gen.instance_variable_get(:@_initializer)[1]
    assert_includes stored_options, "--force"
  end

  # The orm hook (model + migration + model test + fixtures) runs by default
  # and is skipped under --skip-model. We assert on the model file as the
  # signal: the rest of the chain (controller/views/route) is driven by the
  # scaffold_controller hook, which only fully runs inside a booted app — it's
  # covered by the views generator test + dummy-app end-to-end, not here.
  def test_generates_model_by_default
    run_generator ["User", "name:string", "--orm=active_record"]

    assert_file "app/models/user.rb"
  end

  def test_skip_model_skips_the_orm_hook
    run_generator ["User", "name:string", "--orm=active_record", "--skip-model"]

    assert_no_file "app/models/user.rb"
  end
end
