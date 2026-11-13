---
type: Component
title: Seeder
description: Orchestrates N record creations with a required-parent preflight, up to 3 retries per record, progress output and a summary of validation failures.
resource: ../../lib/ruby_ui_scaffold/seeder.rb
tags: [seeding]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T12:00:00Z
sources:
  - id: seeder
    title: seeder.rb
    resource: ../../lib/ruby_ui_scaffold/seeder.rb
---

# Behavior

- **Preflight**: every required (non-optional, non-polymorphic) `belongs_to`
  target must already have rows, otherwise `SeederError` tells you to seed the
  parent first. Seed order is the user's job (parents before children).[^seeder]
- **Retries**: each record gets `MAX_RETRIES = 3` fresh attribute sets before it
  counts as skipped; this absorbs uniqueness collisions and random validation
  misses without failing the run.[^seeder]
- **Output**: progress every 10 records, labelled by `name`/`title`/`display_name`/`email`;
  the summary prints the first 3 distinct validation errors.

Values come from the [Value inference chain](/seeding/value-inference-chain.md);
invoked by the [Seed command](/seeding/seed-command.md).
