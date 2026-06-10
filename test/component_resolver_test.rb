# frozen_string_literal: true

require "test_helper"

class ComponentResolverTest < Minitest::Test
  def attrs(*specs)
    specs.map { |s| Rails::Generators::GeneratedAttribute.parse(s) }
  end

  def resolve(specs, datatable: false)
    RubyUiScaffold::ComponentResolver.call(attributes: attrs(*specs), datatable: datatable)
  end

  def test_base_set_with_no_attributes
    assert_equal RubyUiScaffold::ComponentResolver::BASE.sort, resolve([])
  end

  def test_base_includes_the_scaffold_shell_components
    %w[table link button card typography dropdown_menu alert_dialog form input].each do |c|
      assert_includes RubyUiScaffold::ComponentResolver::BASE, c
    end
  end

  def test_boolean_adds_badge_and_checkbox
    out = resolve(["admin:boolean"])
    assert_includes out, "badge"
    assert_includes out, "checkbox"
  end

  def test_text_adds_textarea
    assert_includes resolve(["bio:text"]), "textarea"
  end

  def test_reference_adds_combobox_and_select
    out = resolve(["author:references"])
    assert_includes out, "combobox"
    assert_includes out, "select"
  end

  def test_polymorphic_reference_adds_no_select_components
    out = resolve(["commentable:references{polymorphic}"])
    refute_includes out, "combobox"
    refute_includes out, "select"
    # Polymorphic falls back to a plain number Input (already in BASE)
    assert_equal RubyUiScaffold::ComponentResolver::BASE.sort, out
  end

  def test_date_adds_date_picker
    assert_includes resolve(["birthday:date"]), "date_picker"
  end

  def test_datatable_flag_adds_data_table
    assert_includes resolve([], datatable: true), "data_table"
    refute_includes resolve([]), "data_table"
  end

  def test_plain_types_add_nothing_beyond_base
    # string/integer/float/decimal/time/datetime/password/attachment → Input (base)
    out = resolve(["name:string", "age:integer", "price:decimal", "opens_at:time",
      "published_at:datetime", "password:digest", "avatar:attachment"])
    assert_equal RubyUiScaffold::ComponentResolver::BASE.sort, out
  end

  def test_result_is_sorted_and_deduped
    out = resolve(["a:boolean", "b:boolean", "c:string"])
    assert_equal out, out.uniq.sort
    # Two booleans don't duplicate badge/checkbox
    assert_equal 1, out.count("badge")
    assert_equal 1, out.count("checkbox")
  end

  def test_combined_attributes_and_flag
    out = resolve(["name:string", "admin:boolean", "bio:text", "author:references", "born:date"],
      datatable: true)
    %w[badge checkbox textarea combobox select date_picker data_table].each do |c|
      assert_includes out, c
    end
    RubyUiScaffold::ComponentResolver::BASE.each { |c| assert_includes out, c }
  end
end
