---
okf_version: "0.2"
---

# ruby_ui_scaffold knowledge bundle

Architecture, decisions and pitfalls of the `ruby_ui_scaffold` gem. The README
remains the user-facing spec of generated output; this bundle records the *why*.

* [ruby_ui_scaffold](overview.md) - What the gem is, its entry points, dependencies and where truth lives.

# Areas

* [Architecture](architecture/) - The generator chain and the Rails-internals constraints holding it together.
* [Generators](generators/) - Entry, controller, views and install generators, flags and their decisions.
* [Runtime library](runtime/) - Field mapping, attribute rules, component resolution and load-order decisions.
* [Seeding](seeding/) - The `ruby_ui_scaffold:seed` command and its value inference.
* [Views](views/) - Conventions and index variants of the generated Phlex views.
* [Testing](testing/) - Test harness and CI matrix.
