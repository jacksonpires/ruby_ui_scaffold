# frozen_string_literal: true

module RubyUiScaffold
  # Resolves which ruby_ui components a scaffold references, given its
  # attributes and options. Only DIRECT references are listed — the
  # `ruby_ui:component NAME` generator resolves transitive dependencies
  # itself (e.g. `date_picker` pulls `calendar` + `popover` + `input`;
  # `data_table` pulls `table`, `checkbox`, `native_select`, `pagination`,
  # `dropdown_menu`, `input`, `button`). See ruby_ui's `dependencies.yml`.
  #
  # @example
  #   RubyUiScaffold::ComponentResolver.call(attributes: attrs, datatable: false)
  #   # => ["alert_dialog", "badge", "button", ...]
  module ComponentResolver
    # Components every generated scaffold uses, regardless of columns/flags.
    # The install generator pre-installs these so a bare `:install` leaves the
    # ground ready; the scaffold then adds the column/flag-specific ones.
    #
    #   index  → table, link, button, dropdown_menu, alert_dialog
    #   show   → card, typography (Text), link, button
    #   form   → form (FormField*), input, button
    BASE = %w[
      table
      link
      button
      card
      typography
      dropdown_menu
      alert_dialog
      form
      input
    ].freeze

    module_function

    # The full set of ruby_ui component generator names a scaffold with these
    # attributes/options references — BASE plus the column/flag conditionals.
    # Returns a sorted, de-duplicated array.
    def call(attributes:, datatable: false)
      components = BASE.dup
      components << "data_table" if datatable

      attributes.each do |attribute|
        components.concat(components_for_attribute(attribute))
      end

      components.uniq.sort
    end

    # Conditional components a single attribute pulls in:
    #   boolean   → Badge (index/show) + Checkbox (form)
    #   text      → Textarea (form)
    #   reference → Combobox + Select (form) — polymorphic falls back to a
    #               plain number Input, so it adds nothing
    #   date      → DatePicker (form)
    # Everything else (string/integer/float/decimal/time/datetime/password/
    # attachment/polymorphic reference) maps to the base `input`.
    def components_for_attribute(attribute)
      return %w[combobox select] if reference?(attribute)

      case attribute.type
      when :boolean then %w[badge checkbox]
      when :text    then %w[textarea]
      when :date    then %w[date_picker]
      else               []
      end
    end

    def reference?(attribute)
      attribute.respond_to?(:reference?) && attribute.reference? &&
        !(attribute.respond_to?(:polymorphic?) && attribute.polymorphic?)
    end
  end
end
