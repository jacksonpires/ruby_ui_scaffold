# frozen_string_literal: true

require "ruby_ui_scaffold/value_generator"

module RubyUiScaffold
  class SeederError < StandardError; end

  # Orchestrates seeding N records for a given ActiveRecord model.
  # Delegates per-attribute value generation to ValueGenerator.
  #
  # @example
  #   seeder = RubyUiScaffold::Seeder.new(Buddy, count: 50)
  #   seeder.run  # => prints progress, returns count of created records
  class Seeder
    MAX_RETRIES = 3
    PROGRESS_EVERY = 10

    def initialize(model_class, count:, reset: false, dry_run: false, io: $stdout)
      @model_class = model_class
      @count = count
      @reset = reset
      @dry_run = dry_run
      @io = io
      @created = 0
      @failed = 0
      @errors = []
    end

    def run
      return dry_run! if @dry_run

      preflight!
      reset_table! if @reset

      started = Time.now
      @io.puts "Seeding #{@count} #{@model_class} records..."

      @count.times do |i|
        record = attempt_create
        if record
          @created += 1
          report_progress(i + 1, record)
        else
          @failed += 1
        end
      end

      report_summary(Time.now - started)
      @created
    end

    private

    def attempt_create
      MAX_RETRIES.times do
        attrs = ValueGenerator.attributes_for(@model_class)
        record = @model_class.new(attrs)
        return record if record.save

        @errors << record.errors.full_messages.join(", ")
      end
      nil
    end

    def preflight!
      @model_class.reflect_on_all_associations(:belongs_to).each do |assoc|
        next if assoc.options[:polymorphic]
        next if assoc.options[:optional]
        next if assoc.klass.unscoped.exists?

        raise SeederError,
          "#{@model_class} requires #{assoc.klass} records first. " \
          "Run `rails ruby_ui_scaffold:seed #{assoc.klass} --count 10` first."
      end
    end

    def reset_table!
      @io.puts "Resetting #{@model_class}.destroy_all..."
      @model_class.destroy_all
    end

    def dry_run!
      sample = ValueGenerator.attributes_for(@model_class)
      @io.puts "Dry run — would create #{@model_class} with attributes:"
      sample.each { |k, v| @io.puts "  #{k}: #{v.inspect}" }
      0
    end

    def report_progress(idx, record)
      return unless (idx % PROGRESS_EVERY).zero? || idx == @count

      label = display_label(record)
      @io.puts "  [#{idx}/#{@count}] last: #{@model_class}(id: #{record.id}, #{label})"
    end

    def display_label(record)
      %i[name title display_name email].each do |attr|
        next unless record.respond_to?(attr)

        value = record.public_send(attr)
        return "#{attr}: #{value.inspect}" if value.present?
      end
      "id: #{record.id}"
    end

    def report_summary(elapsed)
      @io.puts
      @io.puts "Created #{@created} of #{@count} #{@model_class} records in #{elapsed.round(2)}s."
      return if @failed.zero?

      @io.puts "Skipped: #{@failed}. First validation errors:"
      @errors.uniq.first(3).each { |e| @io.puts "  - #{e}" }
    end
  end
end
