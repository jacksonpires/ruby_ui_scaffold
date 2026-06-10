# frozen_string_literal: true

require "test_helper"
require "active_record"
require "stringio"

# Integration tests for Seeder using sqlite in-memory. Defines minimal
# AR models inline, runs the seeder against them, asserts records were
# created with sensible attribute values.
class SeederTest < Minitest::Test
  def self.setup_schema!
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
    ActiveRecord::Schema.verbose = false
    ActiveRecord::Schema.define do
      create_table :buddies do |t|
        t.string :name, null: false
        t.date :birthdate
        t.integer :age
        t.text :bio
        t.boolean :active
        t.string :email
        t.string :role
        t.timestamps
      end

      create_table :authors do |t|
        t.string :name, null: false
        t.timestamps
      end

      create_table :posts do |t|
        t.string :title, null: false
        t.text :body
        t.references :author, foreign_key: true
        t.timestamps
      end
    end
  end

  setup_schema!

  class Buddy < ActiveRecord::Base
    validates :name, presence: true
  end

  class Author < ActiveRecord::Base
    validates :name, presence: true
  end

  class Post < ActiveRecord::Base
    belongs_to :author
    validates :title, presence: true
  end

  class BuddyWithEnum < ActiveRecord::Base
    self.table_name = "buddies"
    enum :role, { admin: "admin", member: "member", guest: "guest" }
  end

  class BuddyWithInclusion < ActiveRecord::Base
    self.table_name = "buddies"
    validates :role, inclusion: { in: %w[ admin member guest ] }
  end

  class BuddyWithRange < ActiveRecord::Base
    self.table_name = "buddies"
    validates :age, numericality: { greater_than_or_equal_to: 21, less_than_or_equal_to: 30 }, allow_nil: true
  end

  def setup
    # FK order: delete children before parents
    Post.delete_all
    Author.delete_all
    Buddy.delete_all
  end

  def io
    @io ||= StringIO.new
  end

  # ---- happy path ----

  def test_creates_n_records
    count = RubyUiScaffold::Seeder.new(Buddy, count: 10, io: io).run
    assert_equal 10, count
    assert_equal 10, Buddy.count
    assert Buddy.all.all? { |b| b.name.present? }
  end

  def test_progress_reported_every_10
    RubyUiScaffold::Seeder.new(Buddy, count: 25, io: io).run
    assert_match(/\[10\/25\]/, io.string)
    assert_match(/\[20\/25\]/, io.string)
    assert_match(/\[25\/25\]/, io.string)
  end

  def test_final_summary_printed
    RubyUiScaffold::Seeder.new(Buddy, count: 3, io: io).run
    assert_match(/Created 3 of 3 SeederTest::Buddy records/, io.string)
  end

  # ---- inference logic on real AR models ----

  def test_enum_column_picks_from_enum_keys
    RubyUiScaffold::Seeder.new(BuddyWithEnum, count: 20, io: io).run
    roles = BuddyWithEnum.pluck(:role).uniq
    assert roles.all? { |r| %w[ admin member guest ].include?(r) }, "Got: #{roles.inspect}"
  end

  def test_inclusion_validator_picks_from_list
    # Force inclusion validator to limit role to admin/member/guest
    RubyUiScaffold::Seeder.new(BuddyWithInclusion, count: 10, io: io).run
    roles = BuddyWithInclusion.pluck(:role).uniq
    assert roles.all? { |r| %w[ admin member guest ].include?(r) }, "Got: #{roles.inspect}"
  end

  def test_numericality_validator_respects_range
    RubyUiScaffold::Seeder.new(BuddyWithRange, count: 20, io: io).run
    ages = BuddyWithRange.pluck(:age).compact
    assert ages.any?, "Should have generated some ages"
    assert ages.all? { |a| a.between?(21, 30) }, "Got: #{ages.inspect}"
  end

  # ---- belongs_to ----

  def test_belongs_to_assigns_existing_record
    Author.create!(name: "Existing")
    RubyUiScaffold::Seeder.new(Post, count: 5, io: io).run
    assert_equal 5, Post.count
    assert Post.all.all? { |p| p.author.present? }
  end

  def test_belongs_to_aborts_when_no_parent_records
    error = assert_raises(RubyUiScaffold::SeederError) do
      RubyUiScaffold::Seeder.new(Post, count: 5, io: io).run
    end
    assert_match(/requires .*Author records first/, error.message)
  end

  # ---- options ----

  def test_reset_clears_existing_records
    3.times { Buddy.create!(name: "Pre-existing #{_1}") }
    assert_equal 3, Buddy.count

    RubyUiScaffold::Seeder.new(Buddy, count: 5, reset: true, io: io).run
    assert_equal 5, Buddy.count
    refute Buddy.exists?(name: "Pre-existing 0")
  end

  def test_dry_run_does_not_persist
    count = RubyUiScaffold::Seeder.new(Buddy, count: 5, dry_run: true, io: io).run
    assert_equal 0, count
    assert_equal 0, Buddy.count
    assert_match(/Dry run/, io.string)
    assert_match(/name:/, io.string)
  end

  # ---- name-based inference smoke test ----

  def test_name_based_email_returns_email_string
    RubyUiScaffold::Seeder.new(Buddy, count: 5, io: io).run
    Buddy.pluck(:email).compact.each do |email|
      assert_match(/@/, email, "Expected email-like string, got #{email.inspect}")
    end
  end
end
