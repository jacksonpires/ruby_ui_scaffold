---
type: Component
title: Entry generator (RubyUiScaffoldGenerator)
description: The `rails g ruby_ui_scaffold` entry point — subclasses Rails' ScaffoldGenerator, forces a flat namespace, redirects the controller hook and owns the CLI flags.
resource: ../../lib/generators/ruby_ui_scaffold/ruby_ui_scaffold_generator.rb
tags: [generators, flags]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T12:00:00Z
sources:
  - id: entry
    title: ruby_ui_scaffold_generator.rb
    resource: ../../lib/generators/ruby_ui_scaffold/ruby_ui_scaffold_generator.rb
---

# Responsibilities

- Inherits model/migration/route/test/helper generation from
  `Rails::Generators::ScaffoldGenerator`.[^entry]
- `namespace "ruby_ui_scaffold"` — see [Flat namespace](/architecture/flat-namespace.md).
- `remove_hook_for :scaffold_controller` + `hook_for :scaffold_controller, as:
  :scaffold_controller, required: true` — hands off to the
  [Controller generator](/generators/controller-generator.md).[^entry]
- Declares every user-facing flag ([Generator flags](/generators/flags.md)).
- Eager-requires its sub-generators — see
  [Lazy generator loading](/architecture/lazy-generator-loading.md).
- Implements `--skip-model` by overriding the Thor-generated
  `_invoke_from_option_orm` — see [Skip-model](/generators/skip-model.md).

Its position in the pipeline is drawn in [Generator chain](/architecture/generator-chain.md).
