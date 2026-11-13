---
type: Decision
title: Scaffold auto-runs the installer in a subprocess
description: When phlex or ruby_ui isn't detected, the views generator shells out to `bin/rails g ruby_ui_scaffold:install` instead of invoking it in-process, and degrades to a warning when it can't.
tags: [install, generators]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T12:00:00Z
sources:
  - id: views
    title: ScaffoldGenerator#ensure_phlex_and_ruby_ui_installed / run_install!
    resource: ../../lib/generators/ruby_ui_scaffold/scaffold/scaffold_generator.rb
---

# Decision

`preflight_checks` in the [Views generator](/generators/views-generator.md)
runs the idempotent [Install generator](/generators/install-generator.md) via
`system("bin/rails", "generate", "ruby_ui_scaffold:install")`.[^views]

# Why a subprocess

The installer calls `exit(1)` on unrecoverable errors. In-process `invoke`
would let that tear down the whole scaffold run; a subprocess contains it, and
the scaffold continues writing files with a yellow warning.[^views]

# When it only warns (never aborts)

- `--skip-install` is passed, or
- there is no app `bin/rails` to drive it — notably the generator test harness,
  which writes into `test/tmp/`.

The same gate (`--skip-install` / no `bin/rails`) applies to on-demand
component install ([Component resolution](/runtime/component-resolution.md)),
which is why generator tests never shell out.[^views]
