# Update Log

## 2026-11-13
* **Update**: CLAUDE.md corrected to match the code on `--literal` declarations and `--skip-model`'s raw-args `--force` injection; divergence notes removed from [Option propagation](/architecture/option-propagation.md) and [Skip-model](/generators/skip-model.md).
* **Creation**: initial bundle derived from the gem source at v0.1.1 — architecture (generator chain, namespace, lazy loading, option propagation), generators, runtime library, seeding, views and testing. See [overview](/overview.md).
* **Note**: two places where CLAUDE.md and the code disagree are recorded in [Option propagation](/architecture/option-propagation.md) (`--literal` isn't declared on the controller generator) and [Skip-model](/generators/skip-model.md) (`--force` is injected into raw args, not merged into `options`).
