---
type: Project
title: ruby_ui_scaffold
description: Rails plugin gem providing a drop-in replacement for `rails g scaffold` that emits Phlex views wired to ruby_ui components, plus a Faker-based seed command.
resource: https://github.com/jacksonpires/ruby_ui_scaffold
tags: [phlex, ruby_ui, compatibility]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T12:00:00Z
sources:
  - id: readme
    title: README.md (authoritative user-facing spec)
    resource: https://github.com/jacksonpires/ruby_ui_scaffold/blob/main/README.md
  - id: gemspec
    title: ruby_ui_scaffold.gemspec
    resource: ../ruby_ui_scaffold.gemspec
  - id: changelog
    title: CHANGELOG.md
    resource: https://github.com/jacksonpires/ruby_ui_scaffold/blob/main/CHANGELOG.md
---

# Overview

`ruby_ui_scaffold` gives a Rails app two entry points:

| Entry point | Kind | Concept |
|---|---|---|
| `rails g ruby_ui_scaffold MODEL field:type ...` | generator chain | [Generator chain](/architecture/generator-chain.md) |
| `rails g ruby_ui_scaffold:install` | one-shot installer | [Install generator](/generators/install-generator.md) |
| `rails ruby_ui_scaffold:seed MODEL` | Rails command (not a generator) | [Seed command](/seeding/seed-command.md) |

The scaffold inherits the whole Rails scaffold pipeline (model, migration, route,
tests, helper) and replaces only the controller and view layer with Phlex
classes under `Views::`.[^readme] The repo is the gem source, not a host app:
there is no `bin/rails`, and behavior is exercised through Rails' generator
test harness — see [Test harness](/testing/test-harness.md).

# Dependencies

Runtime dependencies are `railties >= 7.1`, `phlex-rails >= 2.0`, `literal`,
`faker` and `lucide-rails`; Ruby `>= 3.2`.[^gemspec] `ruby_ui` is deliberately
**not** a gemspec dependency — the host app owns it, and the installer adds it to
the Gemfile on demand ([decision](/generators/ruby-ui-gem-ownership.md)). The
top-level require pulls the transitive Railties in on purpose
([decision](/runtime/transitive-railtie-requires.md)).

Ruby 3.2 is the floor because Phlex 2.x already needs it; 0.1.1 raised it from
3.1, which could not actually install.[^changelog] The supported Ruby × Rails
matrix is enforced by CI ([Test harness](/testing/test-harness.md)).

# Where truth lives

- Generated-output spec (type → component table, seed heuristics, flags): README.[^readme]
- Release history: CHANGELOG (Keep a Changelog, SemVer, pre-1.0).[^changelog]
- *Why* things are shaped the way they are: this bundle.
