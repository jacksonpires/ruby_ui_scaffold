# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "rails"
require "rails/generators"
require "rails/generators/test_case"
require "rails/generators/generated_attribute"
require "rails/generators/rails/scaffold/scaffold_generator"
require "rails/generators/rails/scaffold_controller/scaffold_controller_generator"

require "ruby_ui_scaffold"

require "generators/ruby_ui_scaffold/ruby_ui_scaffold_generator"
require "generators/ruby_ui_scaffold/scaffold_controller/scaffold_controller_generator"
require "generators/ruby_ui_scaffold/scaffold/scaffold_generator"
require "generators/ruby_ui_scaffold/install/install_generator"

require "minitest/autorun"
