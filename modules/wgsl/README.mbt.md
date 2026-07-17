# Milky2018/wgsl

Official WGSL frontend for MoonBit.

This module owns WGSL language syntax and semantic representation:

- `ast` and `ast_analysis` for syntax trees and language-level identifier facts
- `lex` for neutral WGSL lexical helpers
- `parser` for WGSL translation units and declaration fragments
- `ir` for semantic IR, validation, and runtime WGSL emission

The `ir` package also owns policy-neutral writer services for semantic
reachability, expression type inference, and type spelling. Compatibility
writers may consume these services, but Naga ordering, provenance, final-name
allocation, and byte policy remain outside this module.

It does not own shader definitions, naga-oil import syntax, composition
contracts, source registries, virtual overrides, or user-facing composer
convenience APIs. Use `Milky2018/moon_wgsl_naga_oil` for those workflows.
