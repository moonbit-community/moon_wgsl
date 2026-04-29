# naga_oil Parity Plan

Last updated: 2026-04-29

## Scope

`moon_wgsl` targets full `naga_oil` compose compatibility. The core MoonBit
composer remains source-level, while behavior that requires real Naga IR,
GLSL parsing, Naga diagnostics, or runtime shader execution is covered by the
optional upstream oracle harness.

The parity target is therefore:

- Match upstream WGSL import syntax, shader-def condition handling, module path
  resolution, alias rewriting, declaration dependency expansion, diagnostics
  preservation, and single-file export behavior in the MoonBit core.
- Keep all source-only deltas covered by MoonBit tests.
- Route Naga-backed features through the pinned oracle instead of pretending a
  source-text implementation can produce identical parser, validator, GLSL, or
  writeback behavior.

## Upstream References

- Upstream repository: `https://github.com/bevyengine/naga_oil`
- Current pinned oracle commit: `bc444c82bb593ede94c55cdbf799e9743800843e`
- `bevyengine/naga_oil/src/compose/test.rs`
- `bevyengine/naga_oil/src/compose/tests`

## Compatibility Gates

Parity is tracked with three increasingly strict gates:

1. Local source-level parity tests.
   `upstream_compose_parity_test.mbt` contains MoonBit ports of upstream
   `naga_oil` compose cases that can be expressed without Naga IR.

2. Real shader-tree regression tests.
   `bevy_wgsl_parity_test.mbt` registers complete Bevy WGSL fixture files from
   `testdata/bevy_wgsl` and checks that import-only roots tree-shake to empty
   output like upstream `naga_oil`.

3. Optional upstream oracle.
   `tools/naga_oil_oracle` is a Rust harness pinned to the upstream commit
   above. It composes the same fixture tree through real `naga_oil`, validates
   the resulting Naga module, and emits Naga-written WGSL. This is the
   differential oracle for future parity investigations. The output is not
   expected to be byte-identical to `moon_wgsl`; compare structural properties
   such as resolved imports, retained entry points, declaration dependencies,
   collision handling, and absence of unknown identifiers.

There is no source-level compatibility mode for import-only entry points. If a
root shader only imports items and never references them, composition
tree-shakes them away, matching upstream `naga_oil`.

## Coverage Matrix

| Upstream compose test / fixture | Local status | Notes |
| --- | --- | --- |
| `simple_compose`, `simple/` | Covered | Local upstream-inspired composition fixtures cover basic imports and declaration emission. |
| `big_shaderdefs`, `big_shaderdefs/` | Covered | Boolean and value shader definitions are covered in parity tests. |
| `duplicate_import`, `dup_import/` | Covered | Import de-duplication and alias-scoped item emission are covered. |
| `wgsl_call_entrypoint`, `call_entrypoint/` | Covered | Imported entrypoint dependencies are preserved. |
| `apply_override`, `apply_mod_override`, `overrides/` | Covered | Source-level composer now accepts upstream `virtual fn` / `override fn module::item` syntax for WGSL and reports non-virtual override targets. |
| `import_in_decl`, `const_in_decl/` | Covered | Declaration dependency graph preserves imported globals referenced by declarations. |
| `item_import_test`, `item_import/` | Covered | Explicit item import and alias rewrite cases are in the local parity corpus. |
| `dup_struct_import`, `dup_struct_import/` | Covered | Alias-scoped type rewrites avoid duplicate struct collisions. |
| `item_sub_point`, `item_sub_point/` | Covered | Nested item import paths are represented in local tests. |
| `conditional_import`, `conditional_import/` | Covered | Conditional import inclusion is covered. |
| `conditional_missing_import`, `conditional_missing_import_nested`, `conditional_import_fail/` | Covered | Missing imports under active conditions raise local composer errors. |
| Strict preprocessor scope, local defines, and comparison errors | Covered | Composer-level preprocessing now applies root/local `#define` values, rejects missing shader defs in `#if`, unknown operators, invalid comparison literals, extra/missing `#endif`, and `#else` without a matching condition like upstream. |
| `rusty_imports`, `rusty_imports/` | Covered | Fully qualified namespace references synthesize source-level import targets. |
| `test_bevy_path_imports`, `bevy_path_imports/` | Covered | Bevy-style path syntax is covered by metadata/parser parity tests. |
| `test_quoted_import_dup_name`, `quoted_dup/` | Covered | Quoted import paths and duplicate local names are covered. |
| `use_shared_global`, `use_shared_global/` | Covered | Shared global dependencies are preserved once. |
| `problematic_expressions`, `problematic_expressions/` | Covered | Local dependency analysis includes the expression forms that previously broke source-level tree-shaking. |
| `test_atomics`, `atomics/` | Covered | Atomic declarations/usages are covered by source-level declaration dependency tests. |
| `test_modf`, `modf/` | Covered | Builtin-return usage is covered at source-text dependency level. |
| `test_diagnostic_filters`, `diagnostic_filters/` | Covered | Diagnostic directives are preserved. |
| `effective_defs`, `effective_defs/` | Covered | Descriptor-level shader defs now propagate through imported module branches, including the upstream bool-false `#ifdef` semantics and all eight branch combinations. |
| `wgsl_dual_source_blending`, `dual_source_blending/` | Covered | Dual-source blending attributes are preserved as source text. |
| `missing_import_in_module`, `missing_import_in_shader` | Covered | Local errors cover source-level missing imports; pinned oracle emits upstream-identical missing-import diagnostics when exact Naga wording is required. |
| `err_parse`, `err_validation`, `error_test/` | Covered by oracle | `tools/naga_oil_oracle` emits upstream pretty diagnostics with `--entry-only`, `--file-path-prefix`, and `--error-output`; direct and wrapped parse/validation expected files have been diff-verified. |
| `wgsl_call_glsl`, `glsl_call_wgsl`, `basic_glsl`, `glsl/` | Covered by oracle | Oracle enables upstream `naga_oil/glsl` and supports `--shader-type glsl-vertex|glsl-fragment`. |
| `glsl_const_import`, `glsl_wgsl_const_import`, `wgsl_glsl_const_import`, `glsl_const_import/` | Covered by oracle | Oracle handles GLSL/WGSL constant import composition through upstream Naga frontends. |
| `test_raycasts`, `raycast/` | Covered by oracle | Source-level compose is covered locally; oracle validates the Naga module with `--capability ray-query --check-only` because Naga WGSL writeback for ray query is unsupported upstream. |
| `additional_import`, `add_imports/` | Covered | Root compose/export requests and registered composable modules can inject additional imports, including upstream-style override plugins without `#define_import_path`. Runtime shader execution remains oracle-only. |
| `invalid_override` | Covered | Upstream `override fn module::item` syntax now errors when the target was not declared `virtual`; export diagnostics still warn when manual redirects never match. |
| `bad_identifiers`, `invalid_identifiers/` | Covered | Top-level declaration names and function parameters are sanitized in final composed/exported source; invalid struct-member identifiers now report compose errors like upstream. |
| `test_shader`, `compute_test.wgsl` | Covered | Local export smoke coverage preserves the compute entry point and imported module dependency. Upstream runtime execution remains outside the library scope and belongs to downstream runtime tests. |
| Complete Bevy import-only roots | Covered real-world fixture | Forward, prepass, and mesh-only roots tree-shake to empty output when their item imports are not referenced by root source, matching upstream oracle behavior. |
| Full upstream fixture mirror | Covered | `testdata/naga_oil_upstream/compose_tests` mirrors all 110 upstream fixture files, including 75 WGSL files, expected WGSL output, GLSL cases, errors, overrides, raycast, and Bevy path import fixtures. |

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

4. Keep the Naga boundary explicit.
   Missing import, duplicate registry, import cycle, source maps, source-level
   WGSL compose, and source-level export belong in the MoonBit core. Parser
   diagnostics, validator diagnostics, GLSL composition, IR writeback, and
   runtime shader execution belong to the pinned oracle or a future
   naga-backed integration layer.
