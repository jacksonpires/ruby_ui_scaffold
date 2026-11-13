---
type: Decision
title: ruby_ui is owned by the host app's Gemfile
description: ruby_ui is not a gemspec dependency; the installer adds it from RubyGems (~> 1.6, require false) when missing instead of aborting, while phlex-rails stays a declared dependency.
tags: [install, ruby_ui, compatibility]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T12:00:00Z
sources:
  - id: install
    title: InstallGenerator#ensure_ruby_ui_gem
    resource: ../../lib/generators/ruby_ui_scaffold/install/install_generator.rb
  - id: changelog
    title: CHANGELOG 0.1.1 — Changed
    resource: https://github.com/jacksonpires/ruby_ui_scaffold/blob/main/CHANGELOG.md
---

# Decision

`ruby_ui` is left to the host app's Gemfile so the app controls its version and
group, as ruby_ui's own docs recommend. When it isn't loadable, the installer
writes `gem "ruby_ui", "~> 1.6", require: false` and runs `bundle install`
rather than aborting.[^install]

# Details

- `~> 1.6`: 1.6 is the oldest ruby_ui release the generated views and component
  set were verified against.[^install] Since 0.1.1 it comes from RubyGems rather
  than tracking GitHub `main`; existing GitHub entries in a Gemfile are detected
  (regex on `gem "ruby_ui"`) and left alone.[^changelog]
- `require: false` means the gem may not be loaded yet, so
  `ruby_ui_loadable?` tries `require "ruby_ui"` before concluding it's absent.[^install]
- Asymmetry on purpose: `phlex-rails` is the gem's **own** runtime dependency, so
  the installer aborts with instructions instead of editing the Gemfile —
  auto-editing our own dependency would be odd.

Part of the [Install generator](/generators/install-generator.md).
