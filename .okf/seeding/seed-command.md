---
type: Component
title: Seed command
description: "`rails ruby_ui_scaffold:seed MODEL [--count N] [--reset] [--dry-run]` — a Rails::Command (not a generator) that fills a model with realistic fake records."
resource: ../../lib/rails/commands/ruby_ui_scaffold/seed_command.rb
tags: [seeding]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T12:00:00Z
sources:
  - id: cmd
    title: seed_command.rb
    resource: ../../lib/rails/commands/ruby_ui_scaffold/seed_command.rb
---

# Overview

A `Rails::Command::Base` discovered by **file-path convention**
(`lib/rails/commands/ruby_ui_scaffold/seed_command.rb` → `ruby_ui_scaffold:seed`),
so there is no registration code to look for.[^cmd]

| Option | Default | Effect |
|---|---|---|
| `--count`, `-c` | 10 | records to create |
| `--reset` | false | `destroy_all` first |
| `--dry-run` | false | print one sample attribute hash, save nothing |

It boots the app, constantizes MODEL, rejects non-ActiveRecord classes and turns
`SeederError` into a message + exit 1.[^cmd] The work is done by
[Seeder](/seeding/seeder.md) and [Value inference chain](/seeding/value-inference-chain.md).
