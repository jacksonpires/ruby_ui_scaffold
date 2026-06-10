# frozen_string_literal: true

require "rails/command"

module Rails
  module Command
    module RubyUiScaffold
      # `rails ruby_ui_scaffold:seed MODEL [--count N] [--reset] [--dry-run]`
      class SeedCommand < ::Rails::Command::Base
        DEFAULT_COUNT = 10

        desc "seed MODEL", "Seed records for MODEL with smart fake data (use --count to control how many)"

        class_option :count, type: :numeric, aliases: "-c", default: DEFAULT_COUNT,
          desc: "Number of records to create"
        class_option :reset, type: :boolean, default: false,
          desc: "Destroy all existing records before seeding"
        class_option :dry_run, type: :boolean, default: false,
          desc: "Print one sample attribute hash without saving"

        def perform(model_name = nil)
          unless model_name
            say_error "Missing MODEL argument. Usage: rails ruby_ui_scaffold:seed MODEL [--count N]"
            exit 1
          end

          boot_application!
          require "ruby_ui_scaffold/seeder"
          run_seed(model_name)
        end

        private

        def run_seed(model_name)
          klass = resolve_model(model_name)

          ::RubyUiScaffold::Seeder.new(
            klass,
            count: options[:count].to_i,
            reset: options[:reset],
            dry_run: options[:dry_run]
          ).run
        rescue ::RubyUiScaffold::SeederError => e
          say_error e.message
          exit 1
        end

        def resolve_model(name)
          klass = name.constantize
          unless klass < ::ActiveRecord::Base
            say_error "#{name} is not an ActiveRecord model."
            exit 1
          end
          klass
        rescue NameError
          say_error "Model '#{name}' not found. Did you typo or forget to add a `belongs_to`?"
          exit 1
        end
      end
    end
  end
end
