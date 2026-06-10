# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`ruby_ui_scaffold` is a Ruby gem (Rails plugin) that provides `rails g ruby_ui_scaffold` — a drop-in replacement for `rails g scaffold` that emits **Phlex view classes wired to [ruby_ui](https://github.com/ruby-ui/ruby_ui) components** instead of ERB. It also ships a `rails ruby_ui_scaffold:seed` command that populates models with realistic fake data via Faker. Ruby >= 3.1, Rails >= 7.1.

This repo is the gem source, not a host Rails app. There is no `bin/rails` here; the generator/command behavior is exercised through Rails' generator test harness against a temp destination.

## Commands

```bash
bundle install              # install deps (uses mise; Ruby pinned in .ruby-version / mise.toml)
rake test                   # run the full test suite (the default rake task)
rake                        # same as `rake test`

# Run a single test file
ruby -Itest -Ilib test/generators/scaffold_generator_test.rb

# Run a single test by name
ruby -Itest -Ilib test/generators/scaffold_generator_test.rb -n test_creates_view_files
```

Tests use Minitest. Generator tests subclass `Rails::Generators::TestCase`, write into `test/tmp/`, and assert on generated file contents with `assert_file` + regex. `test/tmp/` holds the last run's output and is regenerated each run — don't treat it as source.

## Architecture

### The generator chain (the core trick)

A single `rails g ruby_ui_scaffold User ...` fans out through three cooperating generators that mirror — and selectively override — Rails' own scaffold pipeline. Understanding the hook redirection is essential before touching any generator:

1. **`RubyUiScaffoldGenerator`** (`lib/generators/ruby_ui_scaffold/ruby_ui_scaffold_generator.rb`) — subclasses Rails' `ScaffoldGenerator`, inheriting model/migration/route/test/helper generation for free. It does three critical things:
   - Forces `namespace "ruby_ui_scaffold"` (flat, not the auto-derived nested `ruby_ui_scaffold:ruby_ui_scaffold`). The nested form would shadow `find_by_namespace` lookups for our `:scaffold` and `:scaffold_controller` sub-generators and cause silent recursion.
   - Redirects the `scaffold_controller` hook to our subclass via `hook_for :scaffold_controller, as: :scaffold_controller`.
   - `--skip-model`: skips the inherited `:orm` hook (model + migration + model test + fixtures) for re-runs, by overriding the Thor-generated command `_invoke_from_option_orm` to no-op (leaving `options[:orm]` intact, so orm helpers and controller-hook propagation are unaffected). It also implies `--force` (set in `initialize` via `self.options = options.merge(force: true)`) because a re-run otherwise aborts on the controller's class-collision check, and the intent is to overwrite the regenerated files. Model = user's code (never touched); controller/views = regenerated.

2. **`ScaffoldControllerGenerator`** (`.../scaffold_controller/`) — subclasses Rails' controller generator, overrides its template to render Phlex view classes (`render ::Views::Users::Index.new(...)`) instead of ERB, and redirects the `template_engine` hook to `as: :scaffold` so **our** views generator runs instead of `erb:scaffold`.

3. **`ScaffoldGenerator`** (`.../scaffold/`) — the "template engine." Emits the Phlex view classes (`index`, `show`, `new`, `edit`, `form`) under the `Views::` namespace, runs preflight warnings, and injects required Phlex helpers into `app/components/base.rb`.

`Railtie#generators` (`lib/ruby_ui_scaffold/railtie.rb`) sets `Rails::Generators.options[:ruby_ui_scaffold][:template_engine] = "ruby_ui_scaffold"` **before** requiring the generator classes — `hook_for`/`class_option` freeze option defaults at class-definition time, so order matters.

When editing any generator, the three `class_option` declarations (`--datatable`, `--literal`, `--phlex_layout`) must stay in sync across all three generators, since options propagate down the hook chain.

### Templates

`.tt` files under `lib/generators/ruby_ui_scaffold/{scaffold,scaffold_controller}/templates/` are ERB (Thor) templates producing Phlex `.rb` source. The index and controller each have two variants selected at generation time:
- `index.rb.tt` / `controller.rb.tt` — plain ruby_ui `Table`, controller does `Model.all`.
- `index_data_table.rb.tt` / `controller_data_table.rb.tt` — `DataTable` (search + sort + pagination), controller bakes in `SORTABLE_COLUMNS`, param parsing, and scope building. Selected by `--datatable`.

`--literal` toggles whether generated views use Literal's `prop` macros vs. explicit `def initialize`/`@ivar`. `--phlex_layout=ClassName` wraps each `view_template` in `render(ClassName) do ... end` and emits `layout false`.

### Runtime library (`lib/ruby_ui_scaffold/`)

- **`field_type_mapper.rb`** — maps a `Rails::Generators::GeneratedAttribute` to a ruby_ui input component, returned as a **Ruby code snippet string** for interpolation into templates (not a runtime object). Handles password/file/reference dispatch before falling through to a type `case`. The caller (`ScaffoldGenerator#ruby_ui_input_for`) is responsible for re-indenting multi-line snippets.
- **`attribute_helpers.rb`** — shared module (included by both controller + views generators) deciding which attributes are sortable, searchable, and which are `belongs_to` references (for eager loading + friendly labels).
- **`component_resolver.rb`** — pure logic (unit-testable like `field_type_mapper`) mapping a scaffold's attributes + `--datatable` to the set of ruby_ui component generator names it references. `BASE` is the always-used shell set (installed by `:install`); `call(attributes:, datatable:)` returns `BASE` plus column/flag conditionals. Lists only **direct** references — `ruby_ui:component` resolves transitive deps itself (per ruby_ui's `dependencies.yml`: `date_picker`→`calendar`+`popover`, `data_table`→`table`+`native_select`+…), so we don't enumerate them.
- **`component_installer.rb`** — shared module (mixed into both install + scaffold generators) with `component_installed?(name)` and `uninstalled_components(names)`. The skip-if-present guard is **load-bearing**: `ruby_ui:component` copies files without `--force`, so re-installing a present component prompts interactively and would hang a non-interactive subprocess.
- **`seeder.rb`** + **`value_generator.rb`** — the `seed` command's engine. `Seeder` orchestrates N record creations with preflight checks (parent records must exist for required `belongs_to`), per-record retries (`MAX_RETRIES = 3`), and a summary. `ValueGenerator` resolves each column's fake value via an inference chain: belongs_to FK → enum → inclusion validation → numericality → column-name heuristic → type fallback.

### The `install` generator and `seed` command

- **`InstallGenerator`** (`.../install/`) is a one-shot, fully idempotent installer that runs `phlex:install`, `ruby_ui:install`, then installs the `ComponentResolver::BASE` component set (the always-used scaffold shell). It deliberately does **not** run `ruby_ui:component:all` — column/flag-specific components are installed on demand by the scaffold generator (see below), so apps only carry what they use. It shells out via `run_rails_generator!` (not Thor's `generate`) because Thor's `abort_on_failure` doesn't reliably propagate exit codes from the inner Rails command. Also injects Tailwind `@source` directives so Tailwind v4 scans `.rb` view/component files. `ensure_ruby_ui_gem` runs first: since `ruby_ui` is a GitHub-distributed gem (can't be a gemspec dependency), when it isn't loadable the installer **adds it to the Gemfile and runs `bundle install`** rather than aborting. This works even when the install is itself a subprocess of the scaffold generator — the later `run_rails_generator!` steps spawn fresh subprocesses that boot with the updated bundle, so they see `ruby_ui` even though the current process never loaded it. `phlex-rails` (a declared runtime dependency) keeps the abort-with-instructions behavior, since auto-editing our own dependency would be odd.
- **On-demand components**: after writing the views, `ScaffoldGenerator#install_required_components` shells out `ruby_ui:component NAME` for each component from `ComponentResolver.call(...)` not already present. Gated identically to the auto-install (`--skip-install` or no app `bin/rails` → skip). Failure is **non-fatal** (warn and continue — the views already exist), unlike the installer's abort-on-failure, so one missing component doesn't tear down the scaffold run.
- **`SeedCommand`** (`lib/rails/commands/ruby_ui_scaffold/seed_command.rb`) is a `Rails::Command::Base` (not a generator) — registered by file-path convention, invoked as `rails ruby_ui_scaffold:seed MODEL`.

### Why the top-level require pulls in transitive Railties

`lib/ruby_ui_scaffold.rb` explicitly `require`s `phlex-rails`, `literal`, and `lucide-rails`. This is deliberate: under `Bundler.require` those gems' Railties must fire so their helpers (`lucide_icon`, Faker) register in the host app and their generators (`ruby_ui:component`, etc.) become discoverable. Removing these requires breaks generated views and the seed command at runtime.

## Conventions

- `# frozen_string_literal: true` at the top of every Ruby file.
- Generated Phlex views always live under the `Views::` module (matching `phlex:install`'s convention); controllers reference them fully-qualified (`::Views::...`) to avoid clashing with ERB siblings in `app/views/`.
- `ScaffoldGenerator#preflight_checks` **auto-runs the idempotent `ruby_ui_scaffold:install`** (shelled out via `bin/rails generate`) when phlex/ruby_ui aren't detected, so generated views work out of the box. It falls back to a non-blocking **warning** (never aborts) when opted out via `--skip-install` or when there's no app `bin/rails` to drive it (e.g. the generator test harness). The shell-out — rather than in-process `invoke` — is deliberate: the installer calls `exit(1)` on unrecoverable errors, which a subprocess contains instead of tearing down the scaffold run.
- The `README.md` is the authoritative user-facing spec for generated output (type→component mapping, seed heuristics, flag behavior). When changing generated output, keep README tables in sync.
