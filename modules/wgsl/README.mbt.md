# Milky2018/wgsl

Official WGSL frontend for MoonBit.

This module owns WGSL language syntax and semantic representation:

- `ast` and `ast_analysis` for syntax trees and language-level identifier facts
- `lex`, `directive_syntax`, and `import_syntax` for lexical helpers and
  directive/import syntax parsing
- `parser` for WGSL translation units and declaration fragments
- `ir` for semantic IR, validation, and runtime WGSL emission

It does not own naga-oil composition, source registries, virtual overrides, or
user-facing composer convenience APIs. Use `Milky2018/moon_wgsl_naga_oil` for
those workflows.
