---
type: Decision
title: Lazy generator loading — Railtie sets defaults only, entry file eager-requires sub-generators
description: The Railtie must never require generator classes (it would freeze Rails' :orm hook to false), while the entry generator must require its sub-generators (Rails loads only the first matching file).
tags: [rails-internals, generators, regression]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T12:00:00Z
sources:
  - id: railtie
    title: Railtie
    resource: ../../lib/ruby_ui_scaffold/railtie.rb
  - id: entry
    title: RubyUiScaffoldGenerator (require block)
    resource: ../../lib/generators/ruby_ui_scaffold/ruby_ui_scaffold_generator.rb
  - id: railtie-test
    title: test/railtie_test.rb
    resource: ../../test/railtie_test.rb
  - id: changelog
    title: CHANGELOG 0.1.1 — Fixed
    resource: https://github.com/jacksonpires/ruby_ui_scaffold/blob/main/CHANGELOG.md
---

# Decision

Two rules that look contradictory but are both load-bearing:

1. **`Railtie#generators` only sets an option default** —
   `Rails::Generators.options[:ruby_ui_scaffold][:template_engine] = "ruby_ui_scaffold"` —
   and requires **no** generator class.[^railtie]
2. **The entry generator file eagerly requires** the controller and views
   sub-generators.[^entry]

# Why rule 1

Rails runs every railtie's `generators` block *before*
`Rails::Generators.configure!`. `hook_for` / `class_option` freeze defaults at
class-definition time, so requiring our generators there loads Rails'
`ScaffoldGenerator → ModelGenerator` early and freezes `:orm` as `false`. Result:
`rails g ruby_ui_scaffold` — and even plain `rails g model` in any app with the
gem bundled — silently generates no model or migration.[^railtie] This shipped
in 0.1.0 and was fixed in 0.1.1.[^changelog]

# Why rule 2

Rails' hook lookup requires only the **first** existing candidate file. For the
views hook that is the entry file itself, so without the eager require
`scaffold/scaffold_generator.rb` never loads and Rails prints
`ruby_ui_scaffold [not found]`.[^entry] This is safe because the entry file is
itself loaded lazily, after `configure!`.

# Guard

`test/railtie_test.rb` boots a minimal app **in a subprocess** through the real
`load_generators` path and asserts `ModelGenerator`'s `:orm` default and the
resolved scaffold class.[^railtie-test] It cannot run in-process because
`test_helper` already loads every generator — see
[Test harness](/testing/test-harness.md).
