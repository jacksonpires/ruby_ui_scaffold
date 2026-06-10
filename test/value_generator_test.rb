# frozen_string_literal: true

require "test_helper"

# Tests ValueGenerator with mock columns (no real ActiveRecord schema).
# Inference chain logic (belongs_to/enum/inclusion/numericality) is
# exercised in seeder_test.rb against real AR models.
class ValueGeneratorTest < Minitest::Test
  Column = Struct.new(:name, :type)

  # Minimal model_class mock — no associations, no enums, no validators.
  class FakeModel
    def self.reflect_on_all_associations(_)
      []
    end

    def self.defined_enums
      {}
    end

    def self.validators_on(_)
      []
    end

    def self.inheritance_column
      "type"
    end
  end

  def gen(name, type)
    RubyUiScaffold::ValueGenerator.new(Column.new(name.to_s, type), FakeModel).call
  end

  # ---- type-based fallbacks ----

  def test_integer_returns_integer_in_default_range
    v = gen("count", :integer)
    assert_kind_of Integer, v
    assert v.between?(1, 1000)
  end

  def test_bigint_returns_integer
    v = gen("big_value", :bigint)
    assert_kind_of Integer, v
  end

  def test_float_returns_float
    v = gen("ratio", :float)
    assert_kind_of Float, v
  end

  def test_decimal_returns_float
    v = gen("rating", :decimal)
    assert_kind_of Float, v
  end

  def test_boolean_returns_true_or_false
    v = gen("active", :boolean)
    assert_includes [ true, false ], v
  end

  def test_date_returns_date
    v = gen("scheduled_on", :date)
    assert_kind_of Date, v
  end

  def test_datetime_returns_time
    v = gen("published_at", :datetime)
    assert_kind_of Time, v
  end

  def test_string_fallback_returns_string
    v = gen("token", :string)
    assert_kind_of String, v
    refute v.empty?
  end

  def test_text_fallback_returns_string
    v = gen("notes_blob", :text)
    assert_kind_of String, v
    refute v.empty?
  end

  def test_json_returns_hash
    assert_equal({}, gen("metadata", :json))
    assert_equal({}, gen("metadata", :jsonb))
  end

  def test_uuid_returns_uuid_string
    v = gen("token", :uuid)
    assert_match(/\A[0-9a-f-]{36}\z/, v)
  end

  # ---- name-based heuristics ----

  def test_email_column_returns_email_string
    v = gen("email", :string)
    assert_match(/@/, v)
  end

  def test_phone_column_returns_phone_like_string
    v = gen("phone", :string)
    assert_kind_of String, v
    assert v.length > 5
  end

  def test_age_column_returns_realistic_age
    v = gen("age", :integer)
    assert_kind_of Integer, v
    assert v.between?(18, 80)
  end

  def test_birthdate_column_returns_date
    v = gen("birthdate", :date)
    assert_kind_of Date, v
  end

  def test_url_column_returns_url_like_string
    v = gen("website", :string)
    assert_kind_of String, v
    assert_match(/\A(https?:\/\/|\/)/, v)
  end

  def test_password_column_returns_default_password
    v = gen("password", :string)
    assert_equal "password123", v
  end

  def test_password_digest_returns_default_password
    v = gen("password_digest", :string)
    assert_equal "password123", v
  end

  # ---- skipping logic ----

  def test_attributes_for_skips_id_and_timestamps
    columns = [
      Column.new("id", :integer),
      Column.new("name", :string),
      Column.new("created_at", :datetime),
      Column.new("updated_at", :datetime)
    ]
    # Stub a model that returns these columns
    klass = Class.new do
      define_singleton_method(:columns) { columns }
      define_singleton_method(:inheritance_column) { "type" }
      define_singleton_method(:reflect_on_all_associations) { |_| [] }
      define_singleton_method(:defined_enums) { {} }
      define_singleton_method(:validators_on) { |_| [] }
    end

    attrs = RubyUiScaffold::ValueGenerator.attributes_for(klass)
    assert_equal %w[name], attrs.keys
  end

  def test_attributes_for_skips_counter_cache_columns
    columns = [
      Column.new("name", :string),
      Column.new("comments_count", :integer)
    ]
    klass = Class.new do
      define_singleton_method(:columns) { columns }
      define_singleton_method(:inheritance_column) { "type" }
      define_singleton_method(:reflect_on_all_associations) { |_| [] }
      define_singleton_method(:defined_enums) { {} }
      define_singleton_method(:validators_on) { |_| [] }
    end

    attrs = RubyUiScaffold::ValueGenerator.attributes_for(klass)
    assert_equal %w[name], attrs.keys
  end
end
