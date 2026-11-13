---
type: Pitfall
title: Option propagation down the hook chain
description: Sub-generators receive options by Thor re-parsing the original init args, so flags must be declared where they are read and mutations of `options` never propagate.
tags: [generators, rails-internals, flags]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T15:00:00Z
sources:
  - id: entry
    title: RubyUiScaffoldGenerator#initialize
    resource: ../../lib/generators/ruby_ui_scaffold/ruby_ui_scaffold_generator.rb
  - id: controller
    title: ScaffoldControllerGenerator class_options
    resource: ../../lib/generators/ruby_ui_scaffold/scaffold_controller/scaffold_controller_generator.rb
  - id: views
    title: ScaffoldGenerator class_options
    resource: ../../lib/generators/ruby_ui_scaffold/scaffold/scaffold_generator.rb
---

# Overview

When a hook fires, Thor invokes the sub-generator by **re-parsing the original
init options** stored in `@_initializer` (`Thor::Invocation#_parse_initialization_options`).
Two consequences:

- A flag only has a value in a generator that declares it as a `class_option`.
- Mutating `options` after parse in a parent never reaches the children. That is
  why `--skip-model` injects `--force` into the **raw** args in `initialize`
  ([Skip-model](/generators/skip-model.md)).[^entry]

# Current declarations

| Flag | Entry | Controller | Views | Read by |
|---|---|---|---|---|
| `--datatable` | yes | yes | yes | controller + views |
| `--phlex_layout` | yes | yes | yes | controller (`layout false`) + views |
| `--literal` | yes | **no** | yes | views only |
| `--skip_install` | yes | yes (pass-through only) | yes | views |
| `--skip_model` | yes | no | no | entry only |

Sources: [^entry] [^controller] [^views]

# Rule

**Declare a flag on every generator that reads it, and on the entry generator so
the CLI accepts it.** `--literal` is not declared on the controller generator and
still works, because the views generator re-parses the raw args itself.
Adding it to the controller would be harmless and keep
`rails g ruby_ui_scaffold:scaffold_controller --help` honest.

See [Generator flags](/generators/flags.md) for what each flag does.
