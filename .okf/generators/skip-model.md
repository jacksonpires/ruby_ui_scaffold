---
type: Decision
title: --skip-model re-runs regenerate controller and views only, implying --force
description: --skip-model no-ops the inherited :orm hook and injects --force into the raw CLI args, so a re-run overwrites controller/views without touching the user's model.
tags: [generators, flags, rails-internals]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T15:00:00Z
sources:
  - id: entry
    title: RubyUiScaffoldGenerator#initialize / _invoke_from_option_orm
    resource: ../../lib/generators/ruby_ui_scaffold/ruby_ui_scaffold_generator.rb
  - id: readme
    title: README — --skip-model
    resource: https://github.com/jacksonpires/ruby_ui_scaffold/blob/main/README.md
---

# Mental model

**Model = your code (never touched); controller/views = generated (overwritten).**
Use it to refresh views after a template change or to switch to
`--datatable` without a duplicate migration.[^readme]

# Mechanism

- Overrides the Thor-generated `_invoke_from_option_orm` to return early. This
  skips model, migration, model test and fixtures while leaving `options[:orm]`
  intact, so ORM helpers and controller-hook propagation still work.[^entry]
- Implies `--force`, because a re-run otherwise aborts on the controller's
  class-collision check. It is injected into the **raw** init args in
  `initialize` (array or hash form), not by mutating `options` afterwards —
  sub-generators re-parse the raw args and would never see a post-parse
  mutation ([Option propagation](/architecture/option-propagation.md)).[^entry]

