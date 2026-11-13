# Architecture

* [Generator chain](generator-chain.md) - How one `rails g ruby_ui_scaffold` fans out through three cooperating generators via hook redirection.
* [Flat `ruby_ui_scaffold` namespace](flat-namespace.md) - Why the entry generator forces a flat namespace.
* [Lazy generator loading](lazy-generator-loading.md) - Railtie sets defaults only; entry file eager-requires sub-generators.
* [Option propagation](option-propagation.md) - Flags reach sub-generators by re-parsing raw CLI args.
