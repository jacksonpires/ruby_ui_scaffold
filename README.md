# ruby_ui_scaffold

Rails scaffold generator that outputs **Phlex views built with [ruby_ui](https://github.com/ruby-ui/ruby_ui) components**, plus a smart `seed` command to populate models with fake data.

Drop-in alternative to `rails g scaffold` — generates model, migration, controller, routes, tests, and Phlex view classes wired to ruby_ui components.

## Requirements

- Rails 7.1+
- Tailwind CSS (any Rails Tailwind setup — `tailwindcss-rails` is fine)

## Disclaimer

`ruby_ui_scaffold` is a development-only generator built on the [`ruby_ui`](https://github.com/ruby-ui/ruby_ui) component library — you add both to your app. [`faker`](https://github.com/faker-ruby/faker) and [`lucide-rails`](https://github.com/heyvito/lucide-rails) come along automatically as runtime dependencies of `ruby_ui_scaffold` — `faker` powers the `seed` command, and `lucide-rails` renders the icons in the generated views (the index action menu plus the New / Edit / Create / Update buttons).

> **If you later remove `ruby_ui_scaffold`**, add `gem "lucide-rails"` to your Gemfile (default group) yourself. The generated views you keep still call `lucide_icon`, and `ruby_ui` doesn't depend on `lucide-rails` — so dropping the scaffold gem would otherwise take `lucide-rails` with it and break the icons. (`faker` only matters if you still run the `seed` command.)

---

## First-time setup

On a fresh Rails app, add **both** gems to your `Gemfile` — `ruby_ui` (the component library, used at runtime) and `ruby_ui_scaffold` (the generator, development only):

```ruby
# Gemfile
gem "ruby_ui", github: "ruby-ui/ruby_ui", branch: "main", require: false

group :development do
  gem "ruby_ui_scaffold"
end
```

Then bundle and run the installer:

```bash
$ bundle install
$ bin/rails g ruby_ui_scaffold:install
```

That's it. The installer wires up phlex, ruby_ui, and the base scaffold components — it's fully idempotent, so re-running it only touches what's actually missing.

> **Convenience fallbacks** (so a missed step never blocks you):
>
> - If you skip the `ruby_ui` line above, the installer adds it to your `Gemfile` and runs `bundle install` for you.
> - If you jump straight to `bin/rails g ruby_ui_scaffold ...` without running the installer, the first scaffold auto-runs `ruby_ui_scaffold:install` before writing the views (pass [`--skip-install`](#--skip-install) to only warn instead).
>
> Doing the explicit setup above just keeps things predictable.

<details>
<summary>What the installer does</summary>

0. **ruby_ui gem bootstrap** — if `ruby_ui` isn't loadable, adds `gem "ruby_ui", github: "ruby-ui/ruby_ui", branch: "main", require: false` to the Gemfile (unless an entry already exists) and runs `bundle install`. Skipped entirely once the gem loads.
1. **`phlex:install`** — creates `app/views/base.rb` (`Views::Base`), `app/components/base.rb` (`Components::Base`), and `config/initializers/phlex.rb` (wires the `Views::` autoloader). Skipped if `app/views/base.rb` already exists.
2. **`ruby_ui:install`** — mixes `include RubyUI` into `Components::Base`, adds `config/initializers/ruby_ui.rb`, and the Tailwind preset. Skipped if `Components::Base` already includes RubyUI.
3. **Base components** — installs the components every scaffold's shell uses regardless of columns/flags: `table`, `link`, `button`, `card`, `typography`, `dropdown_menu`, `alert_dialog`, `form`, `input`. Each is skipped if already present. The installer does **not** run `ruby_ui:component:all` — column/flag-specific components are installed on demand (see below).

On the first scaffold generation, `register_output_helper :lucide_icon` is also injected into `Components::Base` (idempotent), so the index dropdown trigger renders out of the box.

**On-demand components.** Instead of installing every ruby*ui component upfront, each `rails g ruby_ui_scaffold ...` installs just the components \_that scaffold* references, right after writing the view files — skipping anything already present. So an app only carries the components it actually uses:

| Column / flag | Installed on demand                                            |
| ------------- | -------------------------------------------------------------- |
| `boolean`     | `badge`, `checkbox`                                            |
| `text`        | `textarea`                                                     |
| `references`  | `combobox`, `select`                                           |
| `date`        | `date_picker` (pulls `calendar` + `popover`)                   |
| `--datatable` | `data_table` (pulls `table`, `native_select`, `pagination`, …) |

`ruby_ui:component` resolves transitive dependencies itself, so installing `date_picker`/`data_table` brings their sub-components along automatically. Pass `--skip-install` to opt out of all automatic installation.

</details>

## Quick start

```bash
# 1. Generate a CRUD scaffold for any model
$ bin/rails g ruby_ui_scaffold Buddy name:string email:string admin:boolean bio:text birthday:date
$ bin/rails db:migrate

# 2. Seed it with 50 fake records
$ bin/rails ruby_ui_scaffold:seed Buddy --count 50

# 3. Open /buddies in your browser
```

![RubyUI Scaffold](/docs/ruby_ui_scaffold-01.png)

That's it. You get:

- `BuddiesController` with full CRUD wired
- Index: plain ruby_ui `Table` with header + body. Pass [`--datatable`](#--datatable) for the full DataTable (search + per-page + sort + pagination).
- Phlex views (`app/views/buddies/{index,show,new,edit,form}.rb`)
- New/Edit form: submit button plus a `Back` link (returns to `request.referer`, falling back to the index)
- Lucide icons on the action buttons — `plus` (New), `pencil` (Edit), and `plus`/`check` on the form's Create/Update submit
- Action column: `DropdownMenu` (Lucide `more-horizontal` trigger) with Show / Edit / Delete
- Delete confirmation via ruby_ui `AlertDialog` (no JS browser confirm)
- Cells truncate with hover-to-see-full
- Realistic fake data via Faker (real names, emails, dates, paragraphs)

---

## `belongs_to` (1×N) — Books + Authors walkthrough

Generate the parent first, then the child with `:references`:

```bash
$ bin/rails g ruby_ui_scaffold Author name:string bio:text
$ bin/rails g ruby_ui_scaffold Book title:string pages:integer published:boolean author:references
$ bin/rails db:migrate

# Seed parent first — Book requires Author records to exist
$ bin/rails ruby_ui_scaffold:seed Author --count 10
$ bin/rails ruby_ui_scaffold:seed Book --count 25
```

What you get automatically:

- **Form** — switches between `Combobox` (searchable, when the parent table has more than `COMBOBOX_THRESHOLD = 100` records) and `Select` (for smaller lists). Both are populated from `Author.all` with a label fallback: `record.try(:name) → :title → :display_name → "Author #id"`. On edit, the current value is pre-selected.
- **Index** and **Show** — display the friendly assoc label (`book.author&.try(:name) || ...`) instead of the raw foreign key.
- **Controller** — auto-eager-loads via `scope.includes(:author)` to avoid N+1 on the index.
- **Preflight** — seeding `Book` before any `Author` exists aborts with a clear message:

  ```
  ERROR: Book requires Author records first. Run `rails ruby_ui_scaffold:seed Author --count 10` first.
  ```

### Snippet of the generated form for `author:references`

```ruby
# app/views/books/form.rb
class Views::Books::Form < Views::Base
  COMBOBOX_THRESHOLD = 100   # tune per-form

  def view_template
    form_with(...) do |form|
      FormField do
        FormFieldLabel(for: "book_author_id") { "Author" }

        if Author.count > COMBOBOX_THRESHOLD
          Combobox do
            ComboboxTrigger(placeholder: "Select Author")
            ComboboxPopover do
              ComboboxSearchInput(placeholder: "Search Author...")
              ComboboxList do
                Author.all.each do |record|
                  ComboboxItem do
                    ComboboxRadio(value: record.id.to_s, name: "book[author_id]", checked: record.id == @book.author_id)
                    span { (record.try(:name) || record.try(:title) || record.try(:display_name) || "Author #{record.id}").to_s }
                  end
                end
              end
            end
          end
        else
          current_author_label = if @book.author
            assoc = @book.author
            (assoc.try(:name) || assoc.try(:title) || assoc.try(:display_name) || "Author #{assoc.id}").to_s
          end
          Select do
            SelectInput(name: "book[author_id]", value: @book.author_id)
            SelectTrigger { SelectValue(placeholder: "Select Author") { current_author_label } }
            SelectContent do
              Author.all.each do |record|
                SelectItem(value: record.id.to_s, aria_selected: (record.id == @book.author_id).to_s) do
                  (record.try(:name) || record.try(:title) || record.try(:display_name) || "Author #{record.id}").to_s
                end
              end
            end
          end
        end

        FormFieldError { @book.errors.messages_for(:author_id).to_sentence }
      end
    end
  end
end
```

**Trade-off**: each form render does one `Author.count` query per `belongs_to` field. Fine for typical scaffold use; tune `COMBOBOX_THRESHOLD` (or memoize at the controller level) if it becomes a hot path.

**Polymorphic associations** (`commentable:references{polymorphic}`) fall back to a plain integer input with a TODO comment — populate the `*_type` and `*_id` manually for now.

---

## Optional flags

| Flag                                                       | What it does                                                                                                                                                                                                                                    |
| ---------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--datatable`                                              | Wrap the index in ruby_ui `DataTable` — adds search input, per-page select, sortable headers, and manual pagination. The controller is upgraded with `SORTABLE_COLUMNS` allowlist, params parsing, and scope building.                          |
| `--literal`                                                | Emit views using [`literal`](https://literal.fun)'s `prop` macros instead of `def initialize` + `@ivar` assignments. Idempotently injects `extend Literal::Properties` into `app/components/base.rb` on first use. Combines with `--datatable`. |
| `--phlex-layout=ClassName`                                 | Wrap every view in `render(ClassName) do ... end` + emit `layout false` in the controller. Use when your app has a Phlex layout (with `include Phlex::Rails::Layout`) instead of the default `application.html.erb`.                            |
| `--skip-install`                                           | Don't auto-run `ruby_ui_scaffold:install` when phlex/ruby_ui aren't detected — only print a warning (the pre-auto-install behavior).                                                                                                            |
| `--skip-model`                                             | Skip model/migration/fixtures generation and only (re)generate the controller, views, and route. For re-runs against an existing model. Implies `--force` (overwrites generated files, bypasses the collision check).                           |
| `--skip-routes`, `--no-test-framework`, `--no-helper`, ... | All standard `rails g scaffold` flags work — inherited from `Rails::Generators::ScaffoldGenerator`.                                                                                                                                             |

### `--datatable`

```bash
$ bin/rails g ruby_ui_scaffold Buddy name:string email:string birthday:date --datatable
```

![RubyUI Scaffold](/docs/ruby_ui_scaffold-02.png)

Generates an index built around `DataTable`:

```ruby
# app/views/buddies/index.rb (excerpt with --datatable)
DataTable(id: "buddies_data_table") do
  DataTableToolbar do
    DataTableSearch(path: buddies_path, frame_id: "buddies_data_table", value: @search, ...)
    DataTablePerPageSelect(path: buddies_path, ..., value: @per_page)
  end

  Table(class: "table-fixed") do
    TableHeader do
      TableRow do
        DataTableSortHead(label: "Name", column_key: "name", sort: @sort, direction: @direction, ...)
        DataTableSortHead(label: "Email", column_key: "email", ...)
        ...
      end
    end
    TableBody do
      @buddies.each do |buddy|
        TableRow do
          # truncated cells + action DropdownMenu (same as default)
        end
      end
    end
  end

  DataTablePaginationBar do
    Text(...) { "Showing #{...} of #{@total_count}" }
    DataTablePagination(page: @page, per_page: @per_page, total_count: @total_count, ...)
  end
end
```

And the controller gains:

```ruby
# app/controllers/buddies_controller.rb (with --datatable)
SORTABLE_COLUMNS = %w[name email birthday].freeze
DEFAULT_PER_PAGE = 10
MAX_PER_PAGE = 100

def index
  @per_page = clamp_per_page(params[:per_page])
  @page = [params[:page].to_i, 1].max
  @search = params[:search].to_s
  @sort = params[:sort] if SORTABLE_COLUMNS.include?(params[:sort])
  @direction = %w[asc desc].include?(params[:direction]) ? params[:direction] : "asc"

  scope = Buddy.all
  # ... eager loading + LIKE search + order + limit/offset ...

  @total_count = scope.count
  @buddies = scope.limit(@per_page).offset(@per_page * (@page - 1))

  render ::Views::Buddies::Index.new(buddies:, page:, per_page:, total_count:, search:, sort:, direction:)
end
```

Without `--datatable`, the controller's `index` is the bare minimum (`Buddy.all` plus `.includes` when there are `belongs_to` references) and the view receives a single `buddies:` kwarg. Use the flag when you need a list larger than ~50 rows to be navigable; skip it for tiny CRUDs.

### `--literal`

```bash
$ bin/rails g ruby_ui_scaffold Buddy name:string species:string --literal
```

Generated views use [`literal`](https://literal.fun)'s `prop` macros — same behavior, less boilerplate, runtime type checking:

```ruby
# app/views/buddies/show.rb (with --literal)
class Views::Buddies::Show < Views::Base
  prop :buddy, Buddy

  def view_template
    # @buddy is available — Literal generates the initialize + ivar
  end
end

# app/views/buddies/form.rb
class Views::Buddies::Form < Views::Base
  prop :buddy, Buddy
  prop :url, String
  prop :method, String
  # ...
end
```

Combines with `--datatable` — the DataTable index gets the full typed prop set:

```ruby
# app/views/buddies/index.rb (with --datatable --literal)
class Views::Buddies::Index < Views::Base
  prop :buddies, _Any
  prop :page, Integer
  prop :per_page, Integer
  prop :total_count, Integer
  prop :search, _Nilable(String), default: nil
  prop :sort, _Nilable(String), default: nil
  prop :direction, _Nilable(String), default: nil
  # ...
end
```

First scaffold with `--literal` injects `extend Literal::Properties` into `app/components/base.rb` (idempotent — re-runs don't duplicate it). Controllers don't change: `render Views::Buddies::Show.new(buddy: @buddy)` still works since Literal generates a compatible `initialize`.

The `literal` gem ships as a runtime dependency of `ruby_ui_scaffold`, so Bundler pulls it in automatically — no extra setup.

> **If you later remove `ruby_ui_scaffold`**, add `gem "literal"` to your Gemfile (default group) yourself. Views generated with `--literal` keep using its `prop` macros at runtime, and nothing else pulls `literal` in — so dropping the scaffold gem would otherwise break those views.

### `--phlex-layout=ApplicationLayout`

```bash
$ bin/rails g ruby_ui_scaffold Buddy name:string --phlex-layout=ApplicationLayout
```

Generates:

```ruby
# app/controllers/buddies_controller.rb
class BuddiesController < ApplicationController
  layout false   # skip Rails' default layout
  # ...
end

# app/views/buddies/index.rb (and show/new/edit)
def view_template
  render(ApplicationLayout) do
    # ... all the view content ...
  end
end
```

Use this when your app has **two layouts** (e.g. one ERB layout for guest pages, one Phlex layout for the authenticated dashboard with Stimulus controllers). Without `--phlex-layout`, scaffolded pages would inherit the default Rails layout — which might load the wrong JS bundle and break Stimulus controllers.

### `--skip-install`

By default, the scaffold generator checks for phlex (`app/views/base.rb`) and ruby_ui (`RubyUI` mixed into `app/components/base.rb`) before writing views. If either is missing, it auto-runs `ruby_ui_scaffold:install` first (idempotent) so the generated views work out of the box:

```bash
$ bin/rails g ruby_ui_scaffold Buddy name:string
  → phlex + ruby_ui not detected — running `ruby_ui_scaffold:install` first.
    (idempotent; pass --skip-install to only warn instead)
  ...
```

Pass `--skip-install` to suppress that and only print a warning instead:

```bash
$ bin/rails g ruby_ui_scaffold Buddy name:string --skip-install
```

Auto-install only fires when there's an app `bin/rails` to drive it; if the `ruby_ui` gem isn't bundled, the installer aborts with instructions and the scaffold falls back to a warning.

### `--skip-model`

Re-running `rails g ruby_ui_scaffold Buddy ...` with the same name normally trips up on the model: Rails would try to recreate the model and add a **duplicate migration**, and the run aborts on the controller's class-collision check. `--skip-model` is for exactly this re-run case — it skips the whole model step (model, migration, model test, fixtures) and only (re)generates the controller, views, and route:

```bash
# First run — full scaffold
$ bin/rails g ruby_ui_scaffold Buddy name:string email:string
$ bin/rails db:migrate

# Later: refresh the views, or switch to the DataTable index, without
# touching the model or creating a second migration
$ bin/rails g ruby_ui_scaffold Buddy name:string email:string --datatable --skip-model
```

`--skip-model` **implies `--force`**: it overwrites the regenerated controller/views without per-file prompts and bypasses the collision check (the re-run would otherwise abort because `Buddy`/`BuddiesController` already exist). The route is left untouched if it already exists (idempotent).

The mental model: **the model is your code** (associations, validations, scopes) and is never touched on a re-run; **the controller and views are generated** and get overwritten. Put custom logic in the model. Note `--skip-model` is meant for re-runs — using it on a model that doesn't exist yet leaves you with a controller/views but no model.

---

## Reference

### Generated files (full scaffold)

```
invoke  active_record
create    db/migrate/20XXXXXXXXXXXX_create_buddies.rb
create    app/models/buddy.rb
invoke  test_unit
create    test/models/buddy_test.rb
create    test/fixtures/buddies.yml
invoke  ruby_ui_scaffold:scaffold_controller
create    app/controllers/buddies_controller.rb
invoke    ruby_ui_scaffold:scaffold
create      app/views/buddies/index.rb
create      app/views/buddies/show.rb
create      app/views/buddies/new.rb
create      app/views/buddies/edit.rb
create      app/views/buddies/form.rb
inject    app/components/base.rb (adds `register_output_helper :lucide_icon`)
invoke    test_unit
create      test/controllers/buddies_controller_test.rb
invoke    helper
create      app/helpers/buddies_helper.rb
invoke  resource_route
 route    resources :buddies
```

### Generated namespacing

Views live under the `Views::` module — matching the convention installed by `phlex:install` (which creates `Views::Base` and wires `app/views/` as the `Views::` namespace root):

```ruby
# app/views/buddies/index.rb
class Views::Buddies::Index < Views::Base
  ...
end

# For namespaced resources (rails g ruby_ui_scaffold Admin::Buddy ...):
# app/views/admin/buddies/index.rb
class Views::Admin::Buddies::Index < Views::Base
  ...
end
```

Controllers render via the fully-qualified constant — `render ::Views::Buddies::Index.new(...)` — so there's no ambiguity with non-Phlex `app/views/` siblings (e.g. ERB partials).

### Type → ruby_ui component mapping (form inputs)

| Rails column type         | ruby_ui component                                                    |
| ------------------------- | -------------------------------------------------------------------- |
| `string`                  | `Input(type: "text")`                                                |
| `text`                    | `Textarea(rows: 4)`                                                  |
| `integer`                 | `Input(type: "number", step: 1)`                                     |
| `float`, `decimal`        | `Input(type: "number", step: "any")`                                 |
| `boolean`                 | `Checkbox` + hidden `"0"`                                            |
| `date`                    | `DatePicker` (ruby_ui — Popover + Calendar over a submittable input) |
| `time`                    | `Input(type: "time")`                                                |
| `datetime`, `timestamp`   | `Input(type: "datetime-local")`                                      |
| `password_digest`         | `Input(type: "password")`                                            |
| `references`/`belongs_to` | `Combobox` (if `parent.count > 100`) or `Select`                     |
| polymorphic `references`  | `Input(type: "number")` + TODO                                       |
| `attachment(s)`           | `Input(type: "file")`                                                |

### Index features

**Always present (both modes):**

- `Table(class: "table-fixed")` + per-cell `truncate` so long values don't break the layout
- Boolean columns rendered as `Badge` (success/outline)
- `belongs_to` columns rendered with the friendly assoc label (`name → title → display_name`)
- Action column: `DropdownMenu(options: { strategy: "fixed" })` triggered by Lucide `more-horizontal`
- Delete inside an `AlertDialog` (Title + Description + Cancel + Delete `form_with(method: :delete)`)
- Wrapped in `div(class: "h-dvh overflow-y-auto")` so absolute-positioned popovers don't get clipped by ancestors with `overflow: hidden` (common in dashboard layouts)

**Only with `--datatable`:**

- `DataTable` wrapper with `DataTableToolbar` (`DataTableSearch` + `DataTablePerPageSelect`)
- `DataTableSortHead` for sortable columns (excludes `:text`, `:rich_text`, `:json`/`:jsonb`, `:binary`, attachments)
- `DataTablePagination` — manual `page`/`per_page`/`total_count` adapter, no pagy/kaminari dependency
- Controller bakes `SORTABLE_COLUMNS`, `params[:search]` LIKE clause, `params[:sort]` allowlist, `params[:page]`/`[:per_page]` clamp

### Seed command

```bash
$ bin/rails ruby_ui_scaffold:seed MODEL [--count N] [--reset] [--dry-run]
```

| Flag                | Behavior                                        |
| ------------------- | ----------------------------------------------- |
| `--count N`, `-c N` | Number of records to create (defaults to 10)    |
| `--reset`           | Runs `Model.destroy_all` before seeding         |
| `--dry-run`         | Prints one sample attribute hash without saving |

#### Inference chain

For each column the value comes from the first source that matches:

1. **`belongs_to` foreign key** — samples an existing parent record (`Author.ids.sample`).
2. **`ActiveRecord::Enum`** — samples a key from `Model.defined_enums[col]`.
3. **`validates :col, inclusion: { in: [...] }`** — samples from the allowlist.
4. **`validates :col, numericality: { greater_than: X, less_than: Y }`** — respects the range.
5. **Column name heuristic** — see table below.
6. **Column type fallback** — `:integer` → `rand(1..1000)`, `:boolean` → `[true, false].sample`, etc.

#### Column-name heuristics

| Column name                                                 | Generator                                           |
| ----------------------------------------------------------- | --------------------------------------------------- |
| `email`, `*_email`                                          | `Faker::Internet.unique.email`                      |
| `first_name`, `last_name`, `name`, `full_name`              | `Faker::Name.*`                                     |
| `username`, `login`, `handle`                               | `Faker::Internet.unique.username`                   |
| `phone`, `phone_number`, `*_phone`                          | `Faker::PhoneNumber.cell_phone`                     |
| `address`, `street`, `city`, `state`, `country`, `zip`      | `Faker::Address.*`                                  |
| `url`, `website`, `homepage`                                | `Faker::Internet.url`                               |
| `title`                                                     | `Faker::Lorem.sentence(word_count: 4)`              |
| `body`, `content`, `description`, `bio`, `summary`, `notes` | `Faker::Lorem.paragraph`                            |
| `company`, `company_name`                                   | `Faker::Company.name`                               |
| `slug`                                                      | `Faker::Internet.unique.slug`                       |
| `uuid`                                                      | `SecureRandom.uuid`                                 |
| `birthdate`, `birthday`, `dob`, `date_of_birth`             | `Faker::Date.birthday`                              |
| `age`                                                       | `rand(18..80)`                                      |
| `color`                                                     | `Faker::Color.color_name`                           |
| `latitude` / `longitude`                                    | `Faker::Address.latitude / .longitude`              |
| `price`, `amount`                                           | `(rand * 1000).round(2)`                            |
| `quantity`, `qty`                                           | `rand(1..100)`                                      |
| `password`, `password_digest`                               | `"password123"` (let `has_secure_password` hash it) |

#### Skipped columns

Never assigned:

- `id`
- `created_at`, `updated_at`
- Counter caches (`*_count`)
- STI inheritance column (default `type`)
- Polymorphic `*_type` columns

#### Failure handling

Each record gets up to 3 retries with newly-generated attributes. After that, it's counted as skipped and the run continues. Final summary shows how many were created vs. skipped and the first 3 unique error messages.

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## License

MIT
