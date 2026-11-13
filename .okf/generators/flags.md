---
type: Reference
title: Generator flags
description: What each `rails g ruby_ui_scaffold` flag changes in the generated output and where it is implemented.
tags: [flags, datatable, generators]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T12:00:00Z
sources:
  - id: readme
    title: README — Optional flags
    resource: https://github.com/jacksonpires/ruby_ui_scaffold/blob/main/README.md
  - id: entry
    title: class_option declarations
    resource: ../../lib/generators/ruby_ui_scaffold/ruby_ui_scaffold_generator.rb
---

# Flags

| Flag | Effect | Details |
|---|---|---|
| `--datatable` | Index uses ruby_ui `DataTable` (search, per-page, sortable headers, pagination); controller gains `SORTABLE_COLUMNS` + param parsing + scope building | [Index variants](/views/index-variants.md) |
| `--literal` | Views use Literal `prop` macros instead of `def initialize`; injects `extend Literal::Properties` into `Components::Base` | [View conventions](/views/view-conventions.md) |
| `--phlex_layout=Class` | Each `view_template` wraps its body in `render(Class) do ... end`; controller gets `layout false` | [View conventions](/views/view-conventions.md) |
| `--skip-install` | Never auto-run the installer or component install — only warn | [Auto-install](/generators/auto-install.md) |
| `--skip-model` | Skip the `:orm` hook; implies `--force` | [Skip-model](/generators/skip-model.md) |

Declared on the entry generator;[^entry] the README is the authoritative user-facing spec for these;[^readme] how they
travel between generators is in [Option propagation](/architecture/option-propagation.md).
