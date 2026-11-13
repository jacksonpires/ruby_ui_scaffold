---
type: Decision
title: Top-level require pulls in phlex-rails, literal and lucide-rails
description: lib/ruby_ui_scaffold.rb explicitly requires its dependencies so their Railties fire under Bundler.require; removing them breaks generated views and the seed command.
resource: ../../lib/ruby_ui_scaffold.rb
tags: [rails-internals, phlex]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T12:00:00Z
sources:
  - id: main
    title: lib/ruby_ui_scaffold.rb
    resource: ../../lib/ruby_ui_scaffold.rb
---

# Decision

`require "phlex-rails"`, `"literal"` and `"lucide-rails"` at the top level, and
the Railtie only `if defined?(Rails::Railtie)`.[^main]

# Why

`Bundler.require` only requires gems listed in the host Gemfile, not transitive
dependencies. Without these explicit requires, helpers such as `lucide_icon`
aren't registered, generators like `phlex:install` / `ruby_ui:component` aren't
discoverable, and generated views and the [Seed command](/seeding/seed-command.md)
crash at runtime.[^main]

Note the contrast with [Lazy generator loading](/architecture/lazy-generator-loading.md):
dependency gems are required eagerly, our own **generator classes** must not be.
