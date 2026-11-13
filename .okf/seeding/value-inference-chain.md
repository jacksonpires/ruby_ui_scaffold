---
type: Component
title: Value inference chain
description: How ValueGenerator picks a fake value per column — belongs_to FK, enum, inclusion validator, numericality validator, column-name heuristic, then type fallback.
resource: ../../lib/ruby_ui_scaffold/value_generator.rb
tags: [seeding]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T12:00:00Z
sources:
  - id: vg
    title: value_generator.rb
    resource: ../../lib/ruby_ui_scaffold/value_generator.rb
  - id: readme
    title: README — Seed command
    resource: https://github.com/jacksonpires/ruby_ui_scaffold/blob/main/README.md
---

# Chain (first non-nil wins)

1. **belongs_to FK** — random existing parent id; raises `SeederError` if none.
2. **enum** — random enum key.
3. **inclusion validator** — sample from `in:`/`within:`.
4. **numericality validator** — random within the declared bounds (integer/bigint/float/decimal only).
5. **column-name heuristic** — Faker by name (`email`, `*_email`, `first_name`, `city`, `slug`, `price`, …).
6. **type fallback** — Faker/random by SQL type.[^vg]

Validations are consulted *before* name heuristics so seeded rows pass the
model's own rules. The full heuristic table is in the README — keep both in
sync.[^readme]

# Skipped columns

`id`, `created_at`, `updated_at`, `*_count` (counter caches), the STI
inheritance column, and polymorphic `*_type` columns.[^vg]

# Gotchas

- `password` / `password_digest` get the literal `"password123"`, relying on
  `has_secure_password` to hash it.
- `Faker::...unique` is used for email/username/slug; long runs can exhaust
  uniqueness, which surfaces as retries in [Seeder](/seeding/seeder.md).
- The class doc comment in `value_generator.rb` omits the numericality step; the `call` chain (and CLAUDE.md) include it.
