---
type: Component
title: Install generator
description: Idempotent one-shot installer — ensures the ruby_ui gem, runs phlex:install and ruby_ui:install, installs the BASE component set and adds Tailwind @source directives.
resource: ../../lib/generators/ruby_ui_scaffold/install/install_generator.rb
tags: [install, ruby_ui, phlex, generators]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T12:00:00Z
sources:
  - id: install
    title: install_generator.rb
    resource: ../../lib/generators/ruby_ui_scaffold/install/install_generator.rb
---

# Steps

1. `check_phlex_rails_gem` — abort with instructions if `phlex-rails` isn't bundled.
2. `ensure_ruby_ui_gem` — if `ruby_ui` can't be required, add
   `gem "ruby_ui", "~> 1.6", require: false` to the Gemfile (unless an entry
   exists) and `bundle install` — see [ruby_ui gem ownership](/generators/ruby-ui-gem-ownership.md).
3. `install_phlex` / `install_ruby_ui` — skipped when already present.
4. `install_base_components` — `ComponentResolver::BASE` minus what's present
   ([Component resolution](/runtime/component-resolution.md)).
5. `inject_tailwind_sources` — adds `@source "../../views/**/*.rb"` and
   `../../components/**/*.rb` to `app/assets/tailwind/application.css`.[^install]

# Non-obvious choices

- **Shells out via `run_rails_generator!`, not Thor's `generate`.** Thor's
  `abort_on_failure` doesn't reliably propagate exit codes from the inner Rails
  command (e.g. Bundler bootstrap errors), so one bad step would cascade into
  dozens of identical failures. The helper checks `system`'s result and
  `exit(1)`s.[^install]
- **Subprocesses see a gem this process never loaded.** After step 2 edits the
  Gemfile, each later `bin/rails generate` boots fresh with the new bundle —
  which is why the auto-add works even when the installer itself runs as a
  subprocess of the scaffold.[^install]
- **Tailwind v4 doesn't scan `.rb`** by default, so classes used only in Phlex
  views would be purged and render with no effect.[^install]
- Deliberately does **not** run `ruby_ui:component:all`.
