# frozen_string_literal: true

require "test_helper"

class FieldTypeMapperTest < Minitest::Test
  def attr(name, type)
    Rails::Generators::GeneratedAttribute.parse("#{name}:#{type}")
  end

  def render(name, type)
    RubyUiScaffold::FieldTypeMapper.render(attr(name, type), model_var: "user")
  end

  def test_string_renders_text_input
    out = render("name", "string")
    assert_equal %{Input(type: "text", id: "user_name", name: "user[name]", value: @user.name)}, out
  end

  def test_text_renders_textarea
    out = render("bio", "text")
    assert_match(/\ATextarea\(rows: 4, id: "user_bio", name: "user\[bio\]"\) do\n/, out)
    assert_match(/  @user\.bio\.to_s\nend\z/, out)
  end

  def test_integer_renders_number_step_1
    out = render("age", "integer")
    assert_equal %{Input(type: "number", id: "user_age", name: "user[age]", value: @user.age, step: 1)}, out
  end

  def test_decimal_renders_number_step_any
    out = render("price", "decimal")
    assert_equal %{Input(type: "number", id: "user_price", name: "user[price]", value: @user.price, step: "any")}, out
  end

  def test_boolean_renders_hidden_plus_checkbox
    out = render("admin", "boolean")
    assert_match(/\Ainput\(type: "hidden", name: "user\[admin\]", value: "0"\)\n/, out)
    assert_match(/Checkbox\(id: "user_admin", name: "user\[admin\]", value: "1", checked: !!@user\.admin\)\z/, out)
  end

  def test_date_renders_date_picker
    out = render("birthday", "date")
    assert_equal %{DatePicker(id: "user_birthday", name: "user[birthday]", selected_date: @user.birthday, label: nil)}, out
  end

  def test_datetime_renders_datetime_local_input
    out = render("published_at", "datetime")
    expected = %{Input(type: "datetime-local", id: "user_published_at", name: "user[published_at]", value: @user.published_at&.strftime("%Y-%m-%dT%H:%M"))}
    assert_equal expected, out
  end

  def test_time_renders_time_input
    out = render("opens_at", "time")
    expected = %{Input(type: "time", id: "user_opens_at", name: "user[opens_at]", value: @user.opens_at&.strftime("%H:%M"))}
    assert_equal expected, out
  end

  def test_password_digest_renders_password_input
    a = Rails::Generators::GeneratedAttribute.parse("password:digest")
    out = RubyUiScaffold::FieldTypeMapper.render(a, model_var: "user")
    assert_equal %{Input(type: "password", id: "user_password", name: "user[password]", value: "")}, out
  end

  def test_references_emits_combobox_or_select_based_on_threshold
    a = Rails::Generators::GeneratedAttribute.parse("author:references")
    out = RubyUiScaffold::FieldTypeMapper.render(a, model_var: "post")
    # Conditional on parent's record count
    assert_match(/\Aif Author\.count > COMBOBOX_THRESHOLD\n/, out)
    # Combobox branch — searchable for large lists
    assert_match(/Combobox do/, out)
    assert_match(/ComboboxTrigger\(placeholder: "Select Author"\)/, out)
    assert_match(/ComboboxSearchInput\(placeholder: "Search Author\.\.\."\)/, out)
    assert_match(/ComboboxRadio\(value: record\.id\.to_s, name: "post\[author_id\]", checked: record\.id == @post\.author_id\)/, out)
    # Select branch — plain dropdown for small lists
    assert_match(/Select do/, out)
    assert_match(/SelectInput\(name: "post\[author_id\]", value: @post\.author_id\)/, out)
    # Trigger renders the current value's label via block (not just placeholder)
    assert_match(/current_author_label/, out)
    assert_match(/SelectValue\(placeholder: "Select Author"\) \{ current_author_label \}/, out)
    # Each item carries aria_selected so the matching one is highlighted on render
    assert_match(/SelectItem\(value: record\.id\.to_s, aria_selected: \(record\.id == @post\.author_id\)\.to_s\)/, out)
    # Label fallback chain available in both branches
    assert_match(/record\.try\(:name\) \|\| record\.try\(:title\)/, out)
  end

  def test_polymorphic_references_falls_back_to_input_with_todo
    a = Rails::Generators::GeneratedAttribute.parse("commentable:references{polymorphic}")
    out = RubyUiScaffold::FieldTypeMapper.render(a, model_var: "comment")
    assert_match(/# TODO: polymorphic association/, out)
    assert_match(/Input\(type: "number"/, out)
  end

  def test_attachment_renders_single_file_input
    a = Rails::Generators::GeneratedAttribute.parse("avatar:attachment")
    out = RubyUiScaffold::FieldTypeMapper.render(a, model_var: "user")
    assert_equal %{Input(type: "file", id: "user_avatar", name: "user[avatar]")}, out
  end

  def test_attachments_renders_multiple_file_input
    a = Rails::Generators::GeneratedAttribute.parse("photos:attachments")
    out = RubyUiScaffold::FieldTypeMapper.render(a, model_var: "user")
    assert_equal %{Input(type: "file", id: "user_photos", name: "user[photos][]", multiple: true)}, out
  end

  def test_unknown_type_falls_back_to_text
    a = Rails::Generators::GeneratedAttribute.parse("token:string")
    out = RubyUiScaffold::FieldTypeMapper.render(a, model_var: "session")
    assert_equal %{Input(type: "text", id: "session_token", name: "session[token]", value: @session.token)}, out
  end
end
