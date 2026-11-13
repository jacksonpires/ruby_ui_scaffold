---
type: Component
title: Generator chain
description: How one `rails g ruby_ui_scaffold` fans out through three cooperating generators that subclass and selectively redirect Rails' own scaffold pipeline.
tags: [generators, rails-internals]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T12:00:00Z
sources:
  - id: entry
    title: RubyUiScaffoldGenerator
    resource: ../../lib/generators/ruby_ui_scaffold/ruby_ui_scaffold_generator.rb
  - id: controller
    title: ScaffoldControllerGenerator
    resource: ../../lib/generators/ruby_ui_scaffold/scaffold_controller/scaffold_controller_generator.rb
  - id: views
    title: ScaffoldGenerator (views)
    resource: ../../lib/generators/ruby_ui_scaffold/scaffold/scaffold_generator.rb
---

# Overview

The core trick is **hook redirection**: rather than reimplementing scaffold, the
gem subclasses Rails' generators and swaps exactly two hooks.

```
rails g ruby_ui_scaffold User name:string
  └─ RubyUiScaffoldGenerator  (< Rails ScaffoldGenerator)      namespace "ruby_ui_scaffold"
       ├─ :orm hook  → model, migration, model test, fixtures   (inherited; no-op under --skip-model)
       ├─ resource route, helper, tests                          (inherited)
       └─ :scaffold_controller hook, as: :scaffold_controller
            └─ ScaffoldControllerGenerator (< Rails ScaffoldControllerGenerator)
                 ├─ controller.rb.tt | controller_data_table.rb.tt
                 └─ :template_engine hook, as: :scaffold, default "ruby_ui_scaffold"
                      └─ ScaffoldGenerator (< NamedBase)  → Phlex views + components
```

1. The entry generator removes the inherited `scaffold_controller` hook and
   re-adds it with `as: :scaffold_controller` so lookup resolves
   `ruby_ui_scaffold:scaffold_controller`.[^entry] Details:
   [Entry generator](/generators/entry-generator.md).
2. The controller generator does the same for `template_engine`
   (`as: :scaffold`), so `ruby_ui_scaffold:scaffold` runs instead of
   `erb:scaffold`; the hook is skipped under `--api`.[^controller] Details:
   [Controller generator](/generators/controller-generator.md).
3. The views generator is the "template engine": preflight, Phlex views,
   helper injection into `Components::Base`, then on-demand component
   install.[^views] Details: [Views generator](/generators/views-generator.md).

# What makes it fragile

Three non-obvious constraints hold the chain together, each its own decision:

- the entry generator's namespace must be flat — [Flat namespace](/architecture/flat-namespace.md);
- the Railtie must not require generator classes, while the entry file must
  eagerly require its sub-generators — [Lazy generator loading](/architecture/lazy-generator-loading.md);
- options reach sub-generators by re-parsing the original CLI args —
  [Option propagation](/architecture/option-propagation.md).
