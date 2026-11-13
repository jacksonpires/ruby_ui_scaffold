---
type: Decision
title: Flat `ruby_ui_scaffold` namespace for the entry generator
description: The entry generator forces namespace "ruby_ui_scaffold" because the auto-derived nested form shadows the sub-generator lookups and causes silent recursion.
tags: [generators, rails-internals]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T12:00:00Z
sources:
  - id: entry
    title: RubyUiScaffoldGenerator
    resource: ../../lib/generators/ruby_ui_scaffold/ruby_ui_scaffold_generator.rb
---

# Decision

`RubyUiScaffoldGenerator` declares `namespace "ruby_ui_scaffold"` explicitly.[^entry]

# Why

Rails would auto-derive `ruby_ui_scaffold:ruby_ui_scaffold` from the file path.
`find_by_namespace` tries candidate names in order, and that nested name would
match first when the hooks look up `ruby_ui_scaffold:scaffold` and
`ruby_ui_scaffold:scaffold_controller` — the entry generator would invoke
itself instead of the sub-generator, recursing **silently**.[^entry]

The same reason explains `as: :scaffold_controller` on the controller hook in the
[Generator chain](/architecture/generator-chain.md): it steers lookup to the
`name:context` form.

# Consequences

Do not remove or rename the `namespace` call. A regression shows up as the
scaffold never reaching the controller/views, not as an error.
