---
type: Decision
title: On-demand ruby_ui component installation
description: The installer only installs a BASE shell set; each scaffold installs just the column/flag-specific components it references, skipping ones already present.
tags: [ruby_ui, install]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T12:00:00Z
sources:
  - id: resolver
    title: component_resolver.rb
    resource: ../../lib/ruby_ui_scaffold/component_resolver.rb
  - id: installer
    title: component_installer.rb
    resource: ../../lib/ruby_ui_scaffold/component_installer.rb
  - id: views
    title: ScaffoldGenerator#install_required_components
    resource: ../../lib/generators/ruby_ui_scaffold/scaffold/scaffold_generator.rb
---

# Decision

Apps should carry only the ruby_ui components they use, so neither generator
runs `ruby_ui:component:all`.

- `ComponentResolver::BASE` — always used (index/show/form shell): `table link
  button card typography dropdown_menu alert_dialog form input`. Installed by
  the [Install generator](/generators/install-generator.md).[^resolver]
- `ComponentResolver.call(attributes:, datatable:)` adds: `data_table` for
  `--datatable`; boolean → `badge checkbox`; text → `textarea`; date →
  `date_picker`; non-polymorphic reference → `combobox select`.[^resolver]
  Must stay consistent with [Field type mapper](/runtime/field-type-mapper.md).
- Lists **direct** references only; `ruby_ui:component` resolves transitive deps
  itself per ruby_ui's `dependencies.yml` (e.g. date_picker → calendar + popover).

# Load-bearing guard

`component_installed?` checks `app/components/ruby_ui/<name>` (dir or `.rb`).
Skipping present components is not an optimization: `ruby_ui:component` copies
without `--force`, so re-installing **prompts interactively and hangs** a
non-interactive subprocess.[^installer]

# Failure policy differs by caller

- Installer: abort on failure (`exit(1)`).
- Scaffold: **warn and continue** — the views are already written, so one missing
  component shouldn't tear down the run. Gated like [Auto-install](/generators/auto-install.md).[^views]
