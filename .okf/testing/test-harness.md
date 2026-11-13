---
type: Runbook
title: Test harness and CI matrix
description: How the gem is tested without a host app — Rails generator TestCase into test/tmp, a subprocess Railtie regression test, unit tests for pure modules, and a Ruby × Rails CI matrix.
tags: [testing, compatibility]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-13T12:00:00Z
sources:
  - id: ci
    title: .github/workflows/ci.yml
    resource: ../../.github/workflows/ci.yml
  - id: railtie-test
    title: test/railtie_test.rb
    resource: ../../test/railtie_test.rb
---

# Run

```bash
rake test                                                    # full suite (default task)
ruby -Itest -Ilib test/generators/scaffold_generator_test.rb # one file
ruby -Itest -Ilib test/generators/scaffold_generator_test.rb -n test_creates_view_files
BUNDLE_GEMFILE=gemfiles/rails_8.0.gemfile bundle exec rake test   # one Rails version
```

# Layout

| Kind | Files | Note |
|---|---|---|
| Generator tests | `test/generators/*_test.rb` | `Rails::Generators::TestCase`, output in `test/tmp/` (gitignored, regenerated — not source); assert with `assert_file` + regex |
| Pure units | `field_type_mapper`, `component_resolver`, `value_generator`, `seeder` tests | no generator boot needed |
| Railtie regression | `test/railtie_test.rb` | runs in a **subprocess**[^railtie-test] |

Because `test/tmp/` has no `bin/rails`, [Auto-install](/generators/auto-install.md)
and on-demand component install are skipped with warnings — tests never shell out.

The Railtie test must be a subprocess because `test_helper` already loads every
generator class — exactly the state the test needs to avoid. See
[Lazy generator loading](/architecture/lazy-generator-loading.md).[^railtie-test]

# CI

GitHub Actions runs Ruby 3.2 / 3.3 / 3.4 / 4.0 × Rails 7.1 / 7.2 / 8.0 / 8.1,
`fail-fast: false`, selecting `gemfiles/rails_<v>.gemfile` via `BUNDLE_GEMFILE`.[^ci]
Keep the README compatibility matrix in step with this.
