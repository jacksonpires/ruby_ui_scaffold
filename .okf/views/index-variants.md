---
type: Component
title: Index variants — Table vs DataTable
description: The default index is a plain ruby_ui Table over Model.all; --datatable switches both index view and controller to search, sort and manual pagination.
tags: [datatable, ruby_ui]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T12:00:00Z
sources:
  - id: dt-ctrl
    title: controller_data_table.rb.tt
    resource: ../../lib/generators/ruby_ui_scaffold/scaffold_controller/templates/controller_data_table.rb.tt
  - id: dt-view
    title: index_data_table.rb.tt
    resource: ../../lib/generators/ruby_ui_scaffold/scaffold/templates/index_data_table.rb.tt
  - id: readme
    title: README — --datatable / Index features
    resource: https://github.com/jacksonpires/ruby_ui_scaffold/blob/main/README.md
---

# Default (`index.rb.tt` + `controller.rb.tt`)

Plain `Table`; controller does `Model.all` (+ `.includes` for references); the
view takes one `<plural>:` kwarg. No toolbar, no pagination.

# `--datatable` (`index_data_table.rb.tt` + `controller_data_table.rb.tt`)

Controller, all values allowlisted or clamped:[^dt-ctrl]

- `SORTABLE_COLUMNS` baked from [Attribute helpers](/runtime/attribute-helpers.md);
  `params[:sort]` ignored unless listed, `direction` ∈ asc/desc.
- `per_page` clamped to 1..100 (default 10); `page` ≥ 1.
- Search: `LOWER(col) LIKE :q` OR-ed over string columns, bound parameter.
- Manual `limit`/`offset` + `total_count` — **no pagy/kaminari dependency**.

View: `DataTableToolbar` (search + per-page), `DataTableSortHead` on sortable
columns, `DataTablePaginationBar`.[^dt-view] Search UI renders only if a string
column exists.[^readme]

Selected by the [Controller generator](/generators/controller-generator.md) and
[Views generator](/generators/views-generator.md) independently, both from
`--datatable` — which is why that flag must reach both
([Option propagation](/architecture/option-propagation.md)).
