---
type: Component
title: Views generator (ScaffoldGenerator — the template engine)
description: Emits the Phlex view classes, auto-installs phlex/ruby_ui when missing, injects required helpers into Components::Base and installs the ruby_ui components the scaffold uses.
resource: ../../lib/generators/ruby_ui_scaffold/scaffold/scaffold_generator.rb
tags: [generators, phlex, ruby_ui, install]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T12:00:00Z
sources:
  - id: views
    title: scaffold_generator.rb
    resource: ../../lib/generators/ruby_ui_scaffold/scaffold/scaffold_generator.rb
---

# Steps, in order

| Thor action | What it does |
|---|---|
| `preflight_checks` | If `app/views/base.rb` (phlex) or `RubyUI` in `app/components/base.rb` is missing, shell out to `ruby_ui_scaffold:install`; else warn — see [Auto-install](/generators/auto-install.md) |
| `create_view_files` | `index` (Table or DataTable variant), `show`, `new`, `edit`, `form` under `app/views/<resource>/` |
| `inject_scaffold_helpers_into_components_base` | Adds missing `FormWith`, `LinkTo`, `ButtonTo`, `Request` helpers, `register_output_helper :lucide_icon`, and `extend Literal::Properties` under `--literal` |
| `install_required_components` | `ruby_ui:component NAME` for each missing component — see [Component resolution](/runtime/component-resolution.md) |

All actions are no-ops on `behavior == :revoke` (`rails destroy`).[^views]

# Why the helper injection exists

`phlex:install` / `ruby_ui:install` create `Components::Base` with only
`Routes` + `RubyUI`. The scaffold's views additionally call `form_with`,
`link_to`, `button_to`, `request` (the form's Back link uses the referer) and
`lucide_icon`; without the injection they raise at render time. Each line is
guarded by a `contents.include?` check, so re-runs are idempotent.[^views]

# Form inputs

`form.rb.tt` calls `ruby_ui_input_for(attribute, indent:)`, which delegates to
[Field type mapper](/runtime/field-type-mapper.md) and re-indents multi-line
snippets to the template's column.
