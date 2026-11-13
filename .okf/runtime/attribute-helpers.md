---
type: Component
title: Attribute helpers
description: Shared mixin deciding which scaffold attributes are sortable, searchable, and eager-loadable belongs_to references.
resource: ../../lib/ruby_ui_scaffold/attribute_helpers.rb
tags: [datatable, generators]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T12:00:00Z
sources:
  - id: helpers
    title: attribute_helpers.rb
    resource: ../../lib/ruby_ui_scaffold/attribute_helpers.rb
---

# Rules

| Helper | Includes | Excludes | Used for |
|---|---|---|---|
| `sortable_columns` | everything else | text, rich_text, json/jsonb, binary, attachments, password_digest | `SORTABLE_COLUMNS` allowlist, sortable headers |
| `searchable_columns` | `:string` only | password_digest | `LOWER(col) LIKE :q` search; search box only rendered if non-empty |
| `reference_associations` | non-polymorphic `references` | polymorphic | `scope.includes(...)` and friendly labels in index/show |

Mixed into both the [Controller generator](/generators/controller-generator.md)
and the [Views generator](/generators/views-generator.md) so controller and view
agree on the same column sets.[^helpers] The controller-side query is described
in [Index variants](/views/index-variants.md).
