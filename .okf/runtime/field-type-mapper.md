---
type: Component
title: Field type mapper
description: Maps a GeneratedAttribute to a ruby_ui form input, returned as a Ruby source snippet string for interpolation into form.rb.tt.
resource: ../../lib/ruby_ui_scaffold/field_type_mapper.rb
tags: [ruby_ui, phlex, forms]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T12:00:00Z
sources:
  - id: mapper
    title: field_type_mapper.rb
    resource: ../../lib/ruby_ui_scaffold/field_type_mapper.rb
  - id: changelog
    title: CHANGELOG 0.1.1 — Fixed
    resource: https://github.com/jacksonpires/ruby_ui_scaffold/blob/main/CHANGELOG.md
  - id: readme
    title: README — Type → ruby_ui component mapping
    resource: https://github.com/jacksonpires/ruby_ui_scaffold/blob/main/README.md
---

# Contract

`FieldTypeMapper.render(attribute, model_var:)` returns **source code**, not an
object. Multi-line snippets come back with no leading indentation; the caller
(`ruby_ui_input_for` in the [Views generator](/generators/views-generator.md))
re-indents them.[^mapper] The full type → component table lives in the README;[^readme]
keep it in sync when changing output.

# Dispatch order

password_digest → attachment(s) → reference → `case type`. Order matters: a
`password_digest` or attachment must be caught before the type fallback.[^mapper]

# Non-obvious mappings

- **decimal** → value is `&.to_s`: Phlex 2 raises `Phlex::ArgumentError` on
  `BigDecimal` attribute values; ActiveSupport makes `BigDecimal#to_s` plain
  notation. Shipped as a crash in 0.1.0, fixed in 0.1.1.[^changelog]
- **time / datetime** → `strftime` into the HTML5 input formats.
- **date** → ruby_ui `DatePicker` with `selected_date:` and `label: nil` (the form
  already emits `FormFieldLabel`).[^mapper]
- **boolean** → hidden `"0"` input + `Checkbox` value `"1"`, the Rails convention
  so unchecking submits.
- **password** → value always `""` (never echo the digest).
- **references** → `Select` below `COMBOBOX_THRESHOLD` (100, a per-form constant in
  `form.rb.tt`), searchable `Combobox` above it. Combobox's Stimulus controller
  syncs its trigger label from the checked radio on connect; **Select's does
  not**, so the current label is rendered inline and the item marked with
  `aria_selected`.[^mapper] Labels fall back `name` → `title` → `display_name` →
  `"<Class> <id>"`.
- **polymorphic reference** → plain number `Input` with a TODO comment.

Which components these imply is in [Component resolution](/runtime/component-resolution.md).
