# frozen_string_literal: true

module RubyUiScaffold
  # Maps a Rails::Generators::GeneratedAttribute to a ruby_ui input
  # component, emitted as a Ruby code snippet for interpolation into
  # a Phlex view template.
  #
  # Multi-line snippets are returned with newline separators and NO
  # leading indentation; the caller is responsible for indenting
  # subsequent lines to match its context. The generator wraps this
  # via `ruby_ui_input_for(attribute, indent:)`.
  #
  # @example
  #   RubyUiScaffold::FieldTypeMapper.render(attribute, model_var: "user")
  #   # => 'Input(type: "text", id: "user_name", name: "user[name]", value: @user.name)'
  class FieldTypeMapper
    def self.render(attribute, model_var:)
      new(attribute, model_var).render
    end

    def initialize(attribute, model_var)
      @attr = attribute
      @model_var = model_var.to_s
    end

    def render
      return password_input if @attr.respond_to?(:password_digest?) && @attr.password_digest?
      return file_input     if @attr.respond_to?(:attachment?) && (@attr.attachment? || @attr.attachments?)
      return reference_input if @attr.respond_to?(:reference?) && @attr.reference?

      type_input
    end

    private

    def type_input
      case @attr.type
      when :text                    then textarea
      when :boolean                 then checkbox
      when :integer                 then input("number", step: 1)
      when :float, :decimal         then input("number", step: "any")
      when :date                    then date_picker
      when :time                    then input("time", value_suffix: %q{&.strftime("%H:%M")})
      when :datetime, :timestamp    then input("datetime-local", value_suffix: %q{&.strftime("%Y-%m-%dT%H:%M")})
      else                               input("text")
      end
    end

    def id_attr
      "#{@model_var}_#{@attr.column_name}"
    end

    def name_attr
      "#{@model_var}[#{@attr.column_name}]"
    end

    def value_ref
      "@#{@model_var}.#{@attr.column_name}"
    end

    def input(type, step: nil, value_suffix: nil)
      value_expr = value_suffix ? "#{value_ref}#{value_suffix}" : value_ref
      step_part = step ? %Q{, step: #{step.is_a?(String) ? %Q{"#{step}"} : step}} : ""
      %Q{Input(type: "#{type}", id: "#{id_attr}", name: "#{name_attr}", value: #{value_expr}#{step_part})}
    end

    # ruby_ui DatePicker renders its own submittable <input> internally (name/
    # value), wrapped in a Popover + Calendar. We pass the Date straight to
    # `selected_date:` — the component derives the input's string value via
    # `selected_date.to_s`, which is already ISO (yyyy-MM-dd), matching its
    # default `date_format`. `label: nil` suppresses the component's built-in
    # label, since the form template already emits a FormFieldLabel.
    def date_picker
      %Q{DatePicker(id: "#{id_attr}", name: "#{name_attr}", selected_date: #{value_ref}, label: nil)}
    end

    def textarea
      <<~RUBY.chomp
        Textarea(rows: 4, id: "#{id_attr}", name: "#{name_attr}") do
          #{value_ref}.to_s
        end
      RUBY
    end

    def checkbox
      <<~RUBY.chomp
        input(type: "hidden", name: "#{name_attr}", value: "0")
        Checkbox(id: "#{id_attr}", name: "#{name_attr}", value: "1", checked: !!#{value_ref})
      RUBY
    end

    def password_input
      %Q{Input(type: "password", id: "#{id_attr}", name: "#{name_attr}", value: "")}
    end

    def file_input
      if @attr.attachments?
        %Q{Input(type: "file", id: "#{id_attr}", name: "#{@model_var}[#{@attr.column_name}][]", multiple: true)}
      else
        %Q{Input(type: "file", id: "#{id_attr}", name: "#{name_attr}")}
      end
    end

    def reference_input
      if @attr.respond_to?(:polymorphic?) && @attr.polymorphic?
        return polymorphic_reference_input
      end

      target_class = @attr.name.to_s.classify
      assoc_name = @attr.name
      <<~RUBY.chomp
        if #{target_class}.count > COMBOBOX_THRESHOLD
          # Searchable Combobox for large parent lists
          # The Combobox controller auto-syncs trigger text from the checked
          # radio on connect (`updateTriggerContent`), so we only need to mark
          # the current selection via `checked:`.
          Combobox do
            ComboboxTrigger(placeholder: "Select #{target_class}")
            ComboboxPopover do
              ComboboxSearchInput(placeholder: "Search #{target_class}...")
              ComboboxList do
                #{target_class}.all.each do |record|
                  ComboboxItem do
                    ComboboxRadio(value: record.id.to_s, name: "#{name_attr}", checked: record.id == #{value_ref})
                    span { (record.try(:name) || record.try(:title) || record.try(:display_name) || "#{target_class} \#{record.id}").to_s }
                  end
                end
              end
            end
          end
        else
          # Plain Select for small lists. Unlike Combobox, the Select controller
          # does NOT auto-sync the trigger label from the hidden input on connect,
          # so we render the current selection's label inline (via block on
          # SelectValue) and mark the matching SelectItem with aria_selected.
          current_#{assoc_name}_label = if @#{@model_var}.#{assoc_name}
            assoc = @#{@model_var}.#{assoc_name}
            (assoc.try(:name) || assoc.try(:title) || assoc.try(:display_name) || "#{target_class} \#{assoc.id}").to_s
          end
          Select do
            SelectInput(name: "#{name_attr}", value: #{value_ref})
            SelectTrigger do
              SelectValue(placeholder: "Select #{target_class}") { current_#{assoc_name}_label }
            end
            SelectContent do
              #{target_class}.all.each do |record|
                SelectItem(value: record.id.to_s, aria_selected: (record.id == #{value_ref}).to_s) do
                  (record.try(:name) || record.try(:title) || record.try(:display_name) || "#{target_class} \#{record.id}").to_s
                end
              end
            end
          end
        end
      RUBY
    end

    def polymorphic_reference_input
      <<~RUBY.chomp
        # TODO: polymorphic association — fill in target type and id manually
        Input(type: "number", id: "#{id_attr}", name: "#{name_attr}", value: #{value_ref})
      RUBY
    end
  end
end
