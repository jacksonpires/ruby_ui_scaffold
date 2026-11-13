---
type: Component
title: Controller generator (ScaffoldControllerGenerator)
description: Subclass of Rails' scaffold_controller that renders Phlex view classes instead of ERB and redirects the template_engine hook to the gem's views generator.
resource: ../../lib/generators/ruby_ui_scaffold/scaffold_controller/scaffold_controller_generator.rb
tags: [generators, datatable]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T12:00:00Z
sources:
  - id: controller
    title: scaffold_controller_generator.rb
    resource: ../../lib/generators/ruby_ui_scaffold/scaffold_controller/scaffold_controller_generator.rb
  - id: dt-template
    title: controller_data_table.rb.tt
    resource: ../../lib/generators/ruby_ui_scaffold/scaffold_controller/templates/controller_data_table.rb.tt
---

# Overview

Overrides `create_controller_files` to pick `controller.rb.tt` or
`controller_data_table.rb.tt` by `--datatable`, and re-hooks
`template_engine` with `as: :scaffold, default: "ruby_ui_scaffold"` (skipped
when `--api`).[^controller] It requires the views generator directly so a
standalone `rails g ruby_ui_scaffold:scaffold_controller` also resolves the
hook — the same first-match lookup issue described in
[Lazy generator loading](/architecture/lazy-generator-loading.md).

# Generated controller shape

- Actions render `::Views::<Resource>::Index.new(...)` etc. — fully qualified to
  avoid clashing with ERB siblings ([View conventions](/views/view-conventions.md)).
- `--phlex_layout` emits `layout false`.
- Failed create/update render the New/Edit view with
  `ActionDispatch::Constants::UNPROCESSABLE_CONTENT`, and `set_*` uses
  `params.expect` — both Rails 8-era APIs inherited from the Rails template.[^dt-template]

The DataTable variant's query building is described in
[Index variants](/views/index-variants.md). Which columns participate comes from
[Attribute helpers](/runtime/attribute-helpers.md).
