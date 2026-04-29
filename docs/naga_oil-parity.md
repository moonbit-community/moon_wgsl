# naga_oil Parity Plan

Last updated: 2026-04-29

## Scope

`moon_wgsl` is a source-level WGSL composer and exporter. It should match
`naga_oil` for source composition features that can be implemented without
Naga IR, GLSL parsing, backend writeback, or runtime shader execution.

The parity target is therefore:

- Match upstream WGSL import syntax, shader-def condition handling, module path
  resolution, alias rewriting, declaration dependency expansion, diagnostics
  preservation, and single-file export behavior.
- Keep all source-only deltas covered by MoonBit tests.
- Keep Naga-backed features explicit instead of hiding them behind approximate
  source-text heuristics.

## Upstream References

- `bevyengine/naga_oil/src/compose/test.rs`
- `bevyengine/naga_oil/src/compose/tests`

## Coverage Matrix

| Upstream compose test / fixture | Local status | Notes |
| --- | --- | --- |
| `simple_compose`, `simple/` | Covered | Local upstream-inspired composition fixtures cover basic imports and declaration emission. |
| `big_shaderdefs`, `big_shaderdefs/` | Covered | Boolean and value shader definitions are covered in parity tests. |
| `duplicate_import`, `dup_import/` | Covered | Import de-duplication and alias-scoped item emission are covered. |
| `wgsl_call_entrypoint`, `call_entrypoint/` | Covered | Imported entrypoint dependencies are preserved. |
| `apply_override`, `apply_mod_override`, `overrides/` | Covered | Source-level symbol redirects cover the practical override behavior available without Naga. |
| `import_in_decl`, `const_in_decl/` | Covered | Declaration dependency graph preserves imported globals referenced by declarations. |
| `item_import_test`, `item_import/` | Covered | Explicit item import and alias rewrite cases are in the local parity corpus. |
| `dup_struct_import`, `dup_struct_import/` | Covered | Alias-scoped type rewrites avoid duplicate struct collisions. |
| `item_sub_point`, `item_sub_point/` | Covered | Nested item import paths are represented in local tests. |
| `conditional_import`, `conditional_import/` | Covered | Conditional import inclusion is covered. |
| `conditional_missing_import`, `conditional_missing_import_nested`, `conditional_import_fail/` | Covered | Missing imports under active conditions raise local composer errors. |
| `rusty_imports`, `rusty_imports/` | Covered | Fully qualified namespace references synthesize source-level import targets. |
| `test_bevy_path_imports`, `bevy_path_imports/` | Covered | Bevy-style path syntax is covered by metadata/parser parity tests. |
| `test_quoted_import_dup_name`, `quoted_dup/` | Covered | Quoted import paths and duplicate local names are covered. |
| `use_shared_global`, `use_shared_global/` | Covered | Shared global dependencies are preserved once. |
| `problematic_expressions`, `problematic_expressions/` | Covered | Local dependency analysis includes the expression forms that previously broke source-level tree-shaking. |
| `test_atomics`, `atomics/` | Covered | Atomic declarations/usages are covered by source-level declaration dependency tests. |
| `test_modf`, `modf/` | Covered | Builtin-return usage is covered at source-text dependency level. |
| `test_diagnostic_filters`, `diagnostic_filters/` | Covered | Diagnostic directives are preserved. |
| `effective_defs`, `effective_defs/` | Covered | Effective shader-def metadata is tested. |
| `wgsl_dual_source_blending`, `dual_source_blending/` | Covered | Dual-source blending attributes are preserved as source text. |
| `missing_import_in_module`, `missing_import_in_shader` | Partially covered | Local errors cover missing imports, but error wording is not intended to match Naga exactly. |
| `err_parse`, `err_validation`, `error_test/` | Blocked | Full parity needs Naga parsing/validation diagnostics rather than source-level string checks. |
| `wgsl_call_glsl`, `glsl_call_wgsl`, `basic_glsl`, `glsl/` | Blocked | Requires GLSL frontend and cross-language composition. |
| `glsl_const_import`, `glsl_wgsl_const_import`, `wgsl_glsl_const_import`, `glsl_const_import/` | Blocked | Requires GLSL parsing plus constant import/writeback semantics. |
| `test_raycasts`, `raycast/` | Blocked | Requires Naga/wgpu-style shader validation or runtime execution behavior. |
| `additional_import`, `add_imports/` | Covered source-level subset | Root compose/export requests and registered composable modules can inject additional imports. Upstream `virtual`/`override` overlay semantics still require Naga and remain blocked. |
| `invalid_override` | TODO | Local redirect diagnostics should pin invalid redirect/override behavior explicitly. |
| `bad_identifiers`, `invalid_identifiers/` | TODO | A limited source-level sanitizer is feasible for locally parsed declarations; full Naga writeback parity is not. |
| `test_shader`, `compute_test.wgsl` | Covered source-level subset | Local export smoke coverage preserves the compute entry point and imported module dependency. Upstream runtime execution remains outside source-only scope. |

## Architecture Priorities

1. Make import syntax one canonical subsystem.
   Today, metadata parsing and compose planning can parse the same `#import`
   syntax through different code paths. That has already caused alias/group
   regressions. A canonical import AST should feed both the preprocessor output
   and the recursive composer.

2. Keep the compose request model explicit.
   `WgslComposeOptions` now owns root-scoped additional imports alongside
   shader defs, value defs, and redirects. Future request-level options should
   continue to live on this stable surface instead of leaking session internals.

3. Keep declaration analysis shared.
   Composition, export, source maps, and tree-shaking should continue using the
   same declaration graph. Any new WGSL declaration form must be added there
   first, then consumed by composer/export.

4. Separate source-only diagnostics from Naga diagnostics.
   Missing import, duplicate registry, import cycle, and source-map diagnostics
   belong in this library. Parser/validator diagnostics should remain blocked
   unless a true Naga-backed integration layer is introduced.

## Blocked Boundary

The following upstream behavior is intentionally out of scope for a pure
source-level MoonBit implementation:

- GLSL parsing or GLSL/WGSL cross-language composition.
- Naga validator error messages.
- Naga IR writeback behavior that rewrites invalid identifiers with full parser
  knowledge.
- wgpu/runtime shader execution checks.

These can be added later as an optional backend integration, but they should not
be approximated in the core source composer because approximate behavior would
make diagnostics and generated WGSL less predictable.
