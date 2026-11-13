---
type: Convention
title: Generated view conventions
description: Namespacing, layout wrapping, Literal props and UI patterns every generated Phlex view follows, with the reasons behind each.
tags: [phlex, ruby_ui, flags]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T12:00:00Z
sources:
  - id: index
    title: index.rb.tt
    resource: ../../lib/generators/ruby_ui_scaffold/scaffold/templates/index.rb.tt
  - id: form
    title: form.rb.tt
    resource: ../../lib/generators/ruby_ui_scaffold/scaffold/templates/form.rb.tt
  - id: changelog
    title: CHANGELOG 0.1.0 / 0.1.1
    resource: https://github.com/jacksonpires/ruby_ui_scaffold/blob/main/CHANGELOG.md
---

# Namespacing

Views are `Views::<Resource>::<Action> < Views::Base` in `app/views/<resource>/*.rb`,
matching `phlex:install` (which wires `app/views/` as the `Views::` root — no
extra autoload config). Controllers reference them as `::Views::...` so they
never resolve to an ERB sibling or a nested constant.[^index]

# Flags in templates

- `--literal` → `prop :users, _Any` / `prop :user, User` instead of
  `def initialize` + ivars; runtime type-checked.
- `--phlex_layout=Class` → body wrapped in `render(Class) do ... end` and
  controller `layout false`. Motivation: in dual-layout apps (ERB for guest
  pages, Phlex for the dashboard) inheriting the default Rails layout loads the
  wrong JS bundle and breaks Stimulus controllers.[^changelog]

# UI patterns and why

| Pattern | Why |
|---|---|
| Index body inside `div(class: "h-dvh w-full overflow-y-auto")` | Hosts with `body { overflow: hidden }` (fixed-sidebar dashboards) would otherwise not scroll[^index] |
| `Table(class: "table-fixed")` + `div.truncate` cells with `title:` | No horizontal overflow; full value on hover |
| Actions = `DropdownMenu(options: { strategy: "fixed" })` with Lucide `more-horizontal` trigger, no wrapper span | Wrapper elements stopped the dropdown toggle action from firing[^changelog] |
| Delete inside an `AlertDialog` + `form_with(method: :delete)` | No JS `confirm()` |
| Boolean `Badge(variant: :success / :outline)` — **symbols** | `RubyUI::Badge::COLORS` is symbol-keyed and doesn't `to_sym`; string variants rendered colorless (fixed 0.1.1)[^changelog] |
| Index `max-w-7xl`; show/new/edit `max-w-3xl`; form `max-w-prose` | Wide for tables, focused for single records |
| Form Back link → `request&.referer || index_path` | Return to where the user came from[^form] |

Index flavours are in [Index variants](/views/index-variants.md); inputs in
[Field type mapper](/runtime/field-type-mapper.md).
