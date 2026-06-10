# frozen_string_literal: true

require "securerandom"
require "date"
require "faker"

module RubyUiScaffold
  # Produces a single attribute value for a given ActiveRecord column,
  # using an inference chain: belongs_to FK → enum → inclusion validator →
  # name-based heuristic → type-based fallback.
  #
  # Faker is a runtime dependency of this gem, so realistic fake data
  # (names, emails, addresses, etc.) is always available.
  #
  # @example Build a full attribute hash for a model
  #   attrs = RubyUiScaffold::ValueGenerator.attributes_for(User)
  #   User.new(attrs)
  class ValueGenerator
    SKIPPED_COLUMN_SUFFIXES = %w[_count].freeze
    SKIPPED_COLUMN_NAMES = %w[id created_at updated_at].freeze

    class << self
      # @param model_class [Class] an ActiveRecord::Base subclass
      # @return [Hash{String => Object}] attributes safe to assign via Model.new
      def attributes_for(model_class)
        seedable_columns(model_class).each_with_object({}) do |column, hash|
          hash[column.name] = new(column, model_class).call
        end
      end

      def seedable_columns(model_class)
        inheritance_column = model_class.inheritance_column
        polymorphic_types = polymorphic_type_columns(model_class)

        model_class.columns.reject do |c|
          SKIPPED_COLUMN_NAMES.include?(c.name) ||
            SKIPPED_COLUMN_SUFFIXES.any? { |s| c.name.end_with?(s) } ||
            c.name == inheritance_column ||
            polymorphic_types.include?(c.name)
        end
      end

      private

      def polymorphic_type_columns(model_class)
        model_class.reflect_on_all_associations(:belongs_to).filter_map do |a|
          "#{a.name}_type" if a.options[:polymorphic]
        end
      end
    end

    def initialize(column, model_class)
      @column = column
      @model_class = model_class
    end

    def call
      belongs_to_value ||
        enum_value ||
        inclusion_value ||
        numericality_value ||
        name_based_value ||
        type_based_value
    end

    private

    # --- inference layers ---

    def belongs_to_value
      assoc = @model_class.reflect_on_all_associations(:belongs_to)
                          .find { |a| !a.options[:polymorphic] && a.foreign_key == @column.name }
      return nil unless assoc

      ids = assoc.klass.unscoped.ids
      return ids.sample if ids.any?

      raise SeederError,
        "#{@model_class} belongs_to :#{assoc.name} but no #{assoc.klass} records exist. " \
        "Run `rails ruby_ui_scaffold:seed #{assoc.klass} --count 10` first."
    end

    def enum_value
      enum = (@model_class.defined_enums || {})[@column.name]
      enum&.keys&.sample
    end

    def inclusion_value
      v = @model_class.validators_on(@column.name).find do |x|
        x.is_a?(ActiveModel::Validations::InclusionValidator)
      end
      return nil unless v

      list = v.options[:in] || v.options[:within]
      return nil unless list.respond_to?(:to_a)

      list.to_a.sample
    end

    def numericality_value
      return nil unless %i[integer bigint float decimal].include?(@column.type)

      v = @model_class.validators_on(@column.name).find do |x|
        x.is_a?(ActiveModel::Validations::NumericalityValidator)
      end
      return nil unless v

      opts = v.options
      min = opts[:greater_than_or_equal_to] || (opts[:greater_than] && opts[:greater_than] + 1) || 1
      max = opts[:less_than_or_equal_to] || (opts[:less_than] && opts[:less_than] - 1) || (min + 1000)

      if @column.type == :integer || @column.type == :bigint
        rand(min.to_i..max.to_i)
      else
        rand(min.to_f..max.to_f).round(2)
      end
    end

    def name_based_value
      case @column.name
      when "email", /_email\z/                          then ::Faker::Internet.unique.email
      when "first_name"                                  then ::Faker::Name.first_name
      when "last_name"                                   then ::Faker::Name.last_name
      when "name", "full_name"                           then ::Faker::Name.name
      when "username", "login", "handle"                 then ::Faker::Internet.unique.username
      when "phone", "phone_number", /_phone\z/           then ::Faker::PhoneNumber.cell_phone
      when "address", "street", "street_address"         then ::Faker::Address.street_address
      when "city"                                        then ::Faker::Address.city
      when "state", "province"                           then ::Faker::Address.state
      when "country"                                     then ::Faker::Address.country
      when "zip", "zipcode", "postal_code"               then ::Faker::Address.zip
      when "url", "website", "homepage"                  then ::Faker::Internet.url
      when "title"                                       then ::Faker::Lorem.sentence(word_count: 4)
      when "body", "content", "description", "bio",
           "summary", "notes"                            then ::Faker::Lorem.paragraph(sentence_count: 3)
      when "company", "company_name"                     then ::Faker::Company.name
      when "slug"                                        then ::Faker::Internet.unique.slug
      when "uuid"                                        then SecureRandom.uuid
      when "birthdate", "birthday", "dob", "date_of_birth" then ::Faker::Date.birthday(min_age: 18, max_age: 80)
      when "age"                                         then rand(18..80)
      when "color"                                       then ::Faker::Color.color_name
      when "latitude"                                    then ::Faker::Address.latitude.to_f
      when "longitude"                                   then ::Faker::Address.longitude.to_f
      when "price", "amount"                             then (rand * 1000).round(2)
      when "quantity", "qty"                             then rand(1..100)
      when /\Apassword(_digest)?\z/
        # let model's has_secure_password handle this; assign a literal password
        "password123"
      end
    end

    def type_based_value
      case @column.type
      when :string                  then ::Faker::Lorem.word.capitalize
      when :text                    then ::Faker::Lorem.paragraph(sentence_count: 3)
      when :integer                 then rand(1..1000)
      when :bigint                  then rand(1..1_000_000)
      when :float, :decimal         then (rand * 1000).round(2)
      when :boolean                 then [true, false].sample
      when :date                    then ::Faker::Date.between(from: Date.today - 365, to: Date.today)
      when :datetime, :timestamp    then ::Faker::Time.between(from: Time.now - (60 * 60 * 24 * 365), to: Time.now)
      when :time                    then Time.now
      when :json, :jsonb            then {}
      when :uuid                    then SecureRandom.uuid
      end
    end
  end
end
