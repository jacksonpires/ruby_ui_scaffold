# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-06-09

### Added

- **Lucide icons on the action buttons.** The index "New" link gets a `plus`
  icon, the show "Edit" link a `pencil`, and the form's submit a `plus`
  (create) / `check` (update). Each button gets `gap-2` for spacing and the
  icon `size-4`, since ruby_ui's Button/Link don't auto-size or space SVGs.
  Reuses the already-registered `lucide_icon` helper — no new dependency.
- **"Back" link in the new/edit form.** The shared form now renders a `Back`
  link next to the submit button, pointing at `request.referer` and falling
  back to the index path when there's no referer. Requires `request` in the
  views, so the post-scaffold injection now also adds
  `include Phlex::Rails::Helpers::Request` to `Components::Base` (idempotent).
- **`--skip-model` flag** for the scaffold generator — skips model/migration/
  model-test/fixtures generation (the whole `:orm` hook) and only
  (re)generates the controller, views, and route. Intended for re-runs
  against an existing model: refresh the views after a template change, or
  add `--datatable`, without Rails creating a duplicate migration or
  clobbering the model. Implies `--force` (overwrites the regenerated files
  and bypasses the class-collision check, which a re-run would otherwise
  abort on). The model is never touched — put custom code there; the
  controller/views are treated as regenerable.
- **Installer generator** — `bin/rails g ruby_ui_scaffold:install` automates
  the first-time setup on a fresh Rails app. Runs `phlex:install`,
  `ruby_ui:install`, `ruby_ui:component:all`, and backfills the 12
  components the scaffold uses but that `:component:all` currently misses
  (`link`, `table`, `alert_dialog`, `badge`, `select`, `combobox`,
  `checkbox`, `textarea`, `data_table`, `native_select`, `calendar`,
  `date_picker`). Every step is idempotent — re-running only touches what's
  missing.
- **Automatic `ruby_ui` gem bootstrap** — when the `ruby_ui` gem isn't
  loadable, the installer now adds
  `gem "ruby_ui", github: "ruby-ui/ruby_ui", branch: "main", require: false`
  to the Gemfile and runs `bundle install`, instead of aborting with manual
  instructions. Idempotent: skips the Gemfile edit when an entry already
  exists, and does nothing once the gem loads. Works even when the install
  runs as a subprocess of the scaffold generator — the later sub-generator
  steps spawn fresh subprocesses that boot with the updated bundle.
  `phlex-rails` (a declared runtime dependency) keeps the abort-with-
  instructions behavior. No-op when no Gemfile is present.
- **Auto-install on scaffold** — `bin/rails g ruby_ui_scaffold ...` now
  auto-runs the idempotent `ruby_ui_scaffold:install` when phlex/ruby_ui
  aren't detected, so generated views work out of the box. Falls back to a
  non-blocking warning when there's no app `bin/rails` to drive it, or when
  opted out with the new `--skip-install` flag.
- **`--literal` flag** for the scaffold generator — emits Phlex views using
  [`literal`](https://literal.fun)'s `prop` macros instead of explicit
  `def initialize` + `@ivar` assignments. Less boilerplate per view;
  runtime type-checking included. On first use, also injects
  `extend Literal::Properties` into `app/components/base.rb` (idempotent).
  Combines with `--datatable` — the DataTable index gets the full typed
  prop set (`_Any` collection, `Integer` pagination, `_Nilable(String)`
  search/sort/direction). Controllers don't change: `render Views::*.new(...)`
  still works since Literal generates a compatible `initialize`. `literal
  (>= 1.0)` is now a runtime dependency.
- `phlex-rails (>= 2.0)` is now a declared runtime dependency, so Bundler
  pulls it in automatically. `lib/ruby_ui_scaffold.rb` requires it eagerly
  to ensure phlex-rails' railtie fires under `Bundler.require`, which is
  what makes `bin/rails g phlex:install` discoverable.

### Changed

- **Components are now installed on demand instead of all upfront.** The
  installer no longer runs `ruby_ui:component:all` + a `MISSING_COMPONENTS`
  backfill; it installs only the `ComponentResolver::BASE` shell every
  scaffold uses (`table`, `link`, `button`, `card`, `typography`,
  `dropdown_menu`, `alert_dialog`, `form`, `input`). Each `rails g
  ruby_ui_scaffold` then installs just the column/flag-specific components
  that scaffold references — `badge`/`checkbox` (boolean), `textarea`
  (text), `combobox`/`select` (references), `date_picker` (date),
  `data_table` (`--datatable`) — right after writing the views, skipping any
  already present. Net result: apps carry only the components they use, and
  total component installs are always ≤ the old install-everything approach.
  New `ComponentResolver` (pure mapping logic) and `ComponentInstaller`
  (shared install/skip helpers) modules back this. `--skip-install` opts out
  of on-demand installs too. Relies on `ruby_ui:component` resolving
  transitive dependencies (it does, via ruby_ui's `dependencies.yml`).
- `date` columns now render the ruby_ui `DatePicker` (a Popover + Calendar
  over a submittable input) instead of a native `Input(type: "date")`. The
  generated form passes the record's date straight to `selected_date:` (the
  component derives the input's ISO `yyyy-MM-dd` value from it) and
  `label: nil` to avoid duplicating the form's `FormFieldLabel`. `datetime`
  and `time` columns are unchanged (still native inputs — `DatePicker` has
  no time component). The installer's component backfill now includes
  `calendar` and `date_picker` to cover the new dependency.
- The post-scaffold `Components::Base` injection now adds four more Phlex
  helpers in addition to `lucide_icon` — `Phlex::Rails::Helpers::FormWith`,
  `LinkTo`, `ButtonTo`, and `Request`. They're required by the
  scaffold-generated views (`form_with`, `link_to`, `button_to`, and
  `request.referer` for the form's Back link) but aren't included by
  `phlex:install` / `ruby_ui:install` by default. Each line is added only
  if absent, so re-running is safe.
- The installer now invokes sub-generators via `system` (instead of Thor's
  `generate` action) and aborts with a clear message on the first
  subprocess failure. Thor's `abort_on_failure` doesn't reliably propagate
  when the failure originates inside a nested Rails command (e.g. Bundler
  bootstrap errors swallow the exit code). Without this, one bad step would
  cascade into dozens of follow-up failures with the same root cause —
  drowning the actual error in noise.
- The installer now injects `@source "../../views/**/*.rb"` and
  `@source "../../components/**/*.rb"` into `app/assets/tailwind/application.css`.
  Tailwind v4's automatic content detection skips `.rb` files, so without
  this every Phlex class name (`mx-auto`, `max-w-3xl`, `max-w-prose`, etc.)
  would silently fail to compile — making the scaffold's centered layout
  render as left-aligned and unstyled. Idempotent; skipped if the file
  isn't present (non-Tailwind setups).
- Form and Card layouts now use `w-full max-w-prose mx-auto` so they're
  visually centered within the wrapper instead of sitting at the left edge.
- The outer `h-dvh overflow-y-auto` wrapper on every scaffolded view
  (index, show, new, edit) now also has `w-full`. Without it, when the
  host layout's container uses `display: flex` (common pattern: e.g.
  `<main class="container mx-auto flex">...</main>`), the wrapper becomes
  a flex item and shrinks to its content width — collapsing the
  `mx-auto max-w-3xl` inner wrapper from 768px down to ~256px and making
  the whole page render left-aligned instead of centered. `w-full` forces
  the flex item to fill the parent regardless of flex/block context.

## [0.1.0] - 2026-05-22

First public-ready release. Pre-1.0 — the API may still evolve before the
first stable cut.

### Added

#### Scaffold generator (`rails g ruby_ui_scaffold MODEL field:type ...`)

- Inherits the full Rails scaffold pipeline (model, migration, resource route,
  helper, tests) and replaces the controller + view layer with Phlex classes
  wired to [ruby_ui](https://github.com/ruby-ui/ruby_ui) components.
- Three internal generators:
  - `RubyUiScaffold::Generators::RubyUiScaffoldGenerator` — entry point,
    namespaced flat as `ruby_ui_scaffold` (not `ruby_ui_scaffold:ruby_ui_scaffold`)
    to avoid `find_by_namespace` shadowing.
  - `RubyUiScaffold::Generators::ScaffoldControllerGenerator` — overrides
    Rails' scaffold_controller template to render Phlex view classes via
    `render ::Views::ModelName::Index.new(...)`.
  - `RubyUiScaffold::Generators::ScaffoldGenerator` — the "template engine"
    that emits the Phlex view files.
- Generated views live under the `Views::` module
  (e.g. `Views::Buddies::Index < Views::Base`), matching the convention
  installed by `phlex:install`. No bespoke initializer or autoload_paths
  tweak required — `phlex:install` already wires `app/views/` as the
  `Views::` namespace root in `config/initializers/phlex.rb`.
- On first run, `register_output_helper :lucide_icon` is injected into
  `app/components/base.rb` (created by `phlex:install` / `ruby_ui:install`)
  so the index dropdown trigger works out of the box. The injection is
  idempotent — re-running the generator never duplicates the line.
- Field-type → ruby_ui component mapping (`RubyUiScaffold::FieldTypeMapper`),
  covering `string`, `text`, `integer`, `float`, `decimal`, `boolean`, `date`,
  `time`, `datetime`/`timestamp`, `password_digest`, `attachment(s)`,
  `references`/`belongs_to`. Date/datetime values are formatted via `iso8601`
  / `strftime` so the HTML5 inputs accept them.

#### Index view: plain `Table` (default) or `DataTable` (`--datatable`)

- Default index is a plain ruby_ui `Table` with header + body. Controller's
  `index` is the bare minimum (`Model.all` plus `.includes(:assoc)` when
  `belongs_to` is present); the view takes a single `models:` kwarg.
- Pass `--datatable` to opt into the full ruby_ui `DataTable` instead — adds
  `DataTableToolbar` (`DataTableSearch` + `DataTablePerPageSelect`),
  `DataTableSortHead` for sortable columns, and `DataTablePaginationBar` +
  `DataTablePagination` (manual `page`/`per_page`/`total_count` adapter —
  no pagy/kaminari dependency). The controller is upgraded with
  `SORTABLE_COLUMNS` allowlist, `params[:search]` LIKE clause across
  string columns, `params[:sort]`/`[:direction]` allowlist, and
  `params[:page]`/`[:per_page]` clamp.
- Wrapped in `Table(class: "table-fixed")` so column widths stay equal
  and the table never overflows its container. Text and reference cells
  are wrapped in `div(class: "truncate", title: value)` — long content
  is clipped with an ellipsis and revealed on hover, eliminating
  horizontal scroll. The action column is locked to `w-16` (with
  `whitespace-nowrap`) so the `•••` dropdown trigger is always visible.
- Search is rendered only when at least one `:string` column exists.
- Sortable columns exclude `:text`, `:rich_text`, `:json`/`:jsonb`, `:binary`,
  and attachments. Non-sortable columns render as plain `TableHead`.
- The actions column is a `DropdownMenu` (`options: { strategy: "fixed" }`)
  triggered by a Lucide `more-horizontal` icon (`lucide_icon("more-horizontal",
  class: "size-5 cursor-pointer text-muted-foreground hover:text-foreground")`)
  — matches Linkana's production pattern (no extra `<span>` wrapper so the
  `data-action="click->ruby-ui--dropdown-menu#toggle"` reliably fires).
  Menu items: Show, Edit, Separator, Delete.
- The entire view_template body is wrapped in
  `div(class: "h-dvh overflow-y-auto")` so vertical scrolling works
  regardless of how the host layout handles overflow — critical for
  dashboards that ship with `body { overflow: hidden }` (e.g. Linkana)
  where natural page scroll is suppressed in favor of inner-scroll
  containers.

#### `--phlex-layout` flag

- `--phlex-layout=ClassName` makes every generated view wrap its
  `view_template` body in `render(ClassName) do ... end` and emits
  `layout false` in the controller. Use this when your app has a
  Phlex layout class (with `include Phlex::Rails::Layout`) that's
  responsible for the full HTML shell (including the `<script>`
  tags). Without it, scaffolded pages would inherit the default
  Rails layout — which in dual-layout apps (one ERB layout for
  guest pages, one Phlex layout for the dashboard) can mean
  loading the wrong JS bundle and breaking Stimulus controllers
  on the page.

#### Destroy confirmation — ruby_ui `AlertDialog` (no JS confirm)

- The Delete dropdown item is **always** wrapped in a ruby_ui
  `AlertDialog` with Title + Description + Cancel + Delete form
  (submitted via `form_with(method: :delete)`). No JS browser
  `confirm()` dialog — the confirmation lives inside the dropdown.
- The trigger inside the AlertDialog is a `DropdownMenuItem(href: nil)`
  styled with `text-destructive`, matching Linkana's production pattern.

#### Centered, max-width layout

- Index: `mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-8` (wide for tables).
- Show / New / Edit: `mx-auto max-w-3xl ...` (focused on a single record /
  form).

#### Real controller behavior (not just shell)

- Generated controller's `index` action:
  - `SORTABLE_COLUMNS` allowlist baked at generator time.
  - `params[:per_page]` clamped to `[1, MAX_PER_PAGE = 100]`, defaulting to
    `DEFAULT_PER_PAGE = 10`.
  - Case-insensitive `LOWER(col) LIKE :q` search across string columns (works
    on PostgreSQL **and** SQLite).
  - `scope.includes(:assoc)` auto-added when the model has non-polymorphic
    `belongs_to` references — avoids N+1 on the index.
  - `render ::Views::Model::Index.new(...)` with all pagination/search/sort kwargs.

#### `belongs_to` / `references` first-class support

- Forms switch dynamically between a searchable ruby_ui `Combobox`
  (when the parent table has more than `COMBOBOX_THRESHOLD = 100`
  records) and a plain `Select` (below the threshold) — no
  `Input(type: "number")` placeholder. The threshold is baked as a
  per-form class constant so users can tune per-resource.
- Both branches share the same option-label fallback chain:
  `record.try(:name) → :title → :display_name → "Class #id"`,
  so it works with any parent model out of the box.
- Index and Show display the friendly assoc label
  (`book.author&.try(:name) || ...`) instead of the raw foreign key.
- Polymorphic references (`commentable:references{polymorphic}`) fall back
  to `Input(type: "number")` + TODO comment.

### Added

#### Seed command (`rails ruby_ui_scaffold:seed MODEL [COUNT]`)

- Implemented as a `Rails::Command::Base` subclass at
  `lib/rails/commands/ruby_ui_scaffold/seed_command.rb` — auto-discovered
  via Rails' `$LOAD_PATH`-based command lookup. Native flag syntax
  (`rails ruby_ui_scaffold:seed Buddy --count 50`), no rake bracket
  workarounds.
- Three options:
  - `--count N` / `-c N` — number of records to create (defaults to 10
    when omitted).
  - `--reset` — `Model.destroy_all` before seeding.
  - `--dry-run` — print one sample attribute hash without persisting.
- Output: per-10-record progress line + final summary with elapsed time,
  created/skipped counts, and first 3 unique validation errors.

#### Inference chain (`RubyUiScaffold::ValueGenerator`)

For each column, the value comes from the first source that matches:

1. **`belongs_to` foreign key** — samples an existing parent record's id
   (`Parent.unscoped.ids.sample`).
2. **`ActiveRecord::Enum`** — samples a key from `Model.defined_enums[col]`.
3. **`validates :col, inclusion: { in: [...] }`** — samples from the list.
4. **`validates :col, numericality: { greater_than: X, less_than: Y }`** —
   respects the range.
5. **Column name heuristics** — `email`, `first_name`, `last_name`, `name`,
   `username`, `phone`, `address`, `city`, `state`, `country`, `zip`,
   `url`, `title`, `body`/`content`/`description`/`bio`/`summary`/`notes`,
   `company`, `slug`, `uuid`, `birthdate`/`birthday`/`dob`/`date_of_birth`,
   `age`, `color`, `latitude`/`longitude`, `price`/`amount`, `quantity`/`qty`,
   `password`/`password_digest`. With Faker installed these yield realistic
   values; without, sensible `SecureRandom`-based fallbacks.
6. **Column type fallback** — `:integer`, `:bigint`, `:float`/`:decimal`,
   `:boolean`, `:date`, `:datetime`/`:timestamp`, `:time`, `:json`/`:jsonb`,
   `:uuid`, `:string`, `:text`.

#### Seeder orchestration (`RubyUiScaffold::Seeder`)

- Preflight check: aborts with a helpful message if a `belongs_to` parent
  has no records (`"Post requires Author records first. Run …"`).
- Per-record retry on validation failure (up to 3 attempts with newly
  generated attributes).
- Skips columns automatically: `id`, `created_at`, `updated_at`, `*_count`
  (counter caches), STI `inheritance_column`, and polymorphic `*_type`
  columns.
- `Faker` is a **runtime dependency** of the gem, so realistic fake data
  (names, emails, addresses, paragraphs) is always available — no extra
  setup needed.

### Dependencies

- Runtime: `railties >= 7.1`, `faker >= 2.0`, `lucide-rails >= 0.7`
- Development (tests): `rails >= 7.1`, `minitest ~> 5.0`, `rake ~> 13.0`,
  `sqlite3 >= 2.0`

`lucide_icon` is registered as a Phlex output helper on `Components::Base`
(`register_output_helper :lucide_icon`, injected on first scaffold), so
it's callable from any scaffold-generated view. The injection is a no-op
if your `Components::Base` already declares it.

### Tests

68 runs, 442 assertions, 0 failures. Coverage:

- `FieldTypeMapper` — every type mapping plus Select (references) and
  polymorphic fallback.
- `ValueGenerator` — type-based fallbacks (no Faker required) and the
  full name-based heuristic catalog via mock columns.
- `Seeder` — happy path, retry on validations, enums, inclusion,
  numericality range, `belongs_to` preflight, `--reset`, `--dry-run`,
  using a real `sqlite3` in-memory connection with inline AR models.
- Scaffold generator — full template surface: DataTable structure,
  centered layout, DropdownMenu trigger, AlertDialog destroy, references →
  Combobox/Select switch in form, references → friendly label in
  index/show, `--phlex-layout` wrapping.

### Internal notes

- Rails::Generators option propagation: the railtie sets
  `Rails::Generators.options[:ruby_ui_scaffold][:template_engine] =
  "ruby_ui_scaffold"` **before** loading generator classes, because
  `class_option` defaults are frozen at class-definition time.
- The entry generator's namespace is overridden to flat `"ruby_ui_scaffold"`
  (not `"ruby_ui_scaffold:ruby_ui_scaffold"`) to avoid `find_by_namespace`
  shadowing of the sub-generators when hooks fire.

[Unreleased]: https://github.com/jacksonpires/ruby_ui_scaffold/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/jacksonpires/ruby_ui_scaffold/releases/tag/v0.1.0
