# naga_oil Preprocessing Parity

Last updated: 2026-04-30

## Scope

`moon_wgsl` targets `naga_oil` preprocessing and source-level composition
compatibility. The compatibility target is intentionally narrower than all of
`naga_oil`: it does not include Naga IR generation, Naga validation, GLSL
frontends, WGSL writer byte-for-byte output, or runtime shader execution.

The preprocessing target is:

- Match upstream WGSL import syntax, shader-def condition handling, module path
  resolution, alias rewriting, declaration dependency expansion, diagnostic
  directive preservation, and single-file WGSL export behavior in the MoonBit
  core.
- Keep every known source-level delta covered by MoonBit tests.
- Use the pinned `naga_oil` oracle only as a differential reference and CI
  guardrail, not as a runtime dependency of the MoonBit library.

## Current Status

As of current `main` after `Milky2018/moon_wgsl 0.6.2`, there are no known
open source-level preprocessing gaps. Release `0.5.0` covers the historical
GitHub #2/#3/#5/#6 failures and the original GitHub #7 duplicate-binding /
root-local `#define` regressions. The later GitHub #7 `identifier: in`
regression and later AST dependency-analysis cleanup are covered by `0.6.0`.

Downstream consumers such as `mgstudio` should use `0.6.0` or current `main`,
then rerun their own shader-pipeline tests to confirm integration. That
verification is downstream runtime scope; this repository gates the
preprocessing output.

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

3. Upstream oracle.
   `tools/naga_oil_oracle` is a Rust harness pinned to the upstream commit
   above. It composes WGSL and GLSL fixture trees through real `naga_oil` and
   compares every deterministic upstream compose output or diagnostic that can
   be emitted by the pinned oracle.

4. CI parity gate.
   `tools/check_preprocess_parity.sh` runs the local preprocessing parity suite
   and pinned-oracle comparisons. The script also audits the upstream expected
   fixture inventory so newly mirrored expected files must be either diffed by
   the gate or explicitly classified as outside the MoonBit preprocessing
   boundary. The GitHub Actions `check` workflow runs this script after the
   normal MoonBit test matrix.

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
| Aliased function parameters | Covered | Alias/global declaration-name rewrites preserve function parameter locals such as Bevy entrypoint `in` while still rewriting visible function and type declarations. |
| `item_sub_point`, `item_sub_point/` | Covered | Nested item import paths are represented in local tests. |
| `conditional_import`, `conditional_import/` | Covered | Conditional import inclusion is covered. |
| `conditional_missing_import`, `conditional_missing_import_nested`, `conditional_import_fail/` | Covered | Missing imports under active conditions raise local composer errors. |
| Strict preprocessor scope, local defines, and comparison errors | Covered | Composer-level preprocessing now applies root/local `#define` values, rejects missing shader defs in `#if`, unknown operators, invalid comparison literals, extra/missing `#endif`, and `#else` without a matching condition like upstream. |
| `rusty_imports`, `rusty_imports/` | Covered | Fully qualified namespace references synthesize source-level import targets. |
| `test_bevy_path_imports`, `bevy_path_imports/` | Covered | Bevy-style path syntax is covered by metadata/parser parity tests. |
| `test_quoted_import_dup_name`, `quoted_dup/` | Covered | Quoted import paths and duplicate local names are covered. |
| `use_shared_global`, `use_shared_global/` | Covered | Shared global dependencies are preserved once. |
| `problematic_expressions`, `problematic_expressions/` | Covered | Local dependency analysis includes the expression forms that previously broke source-level tree-shaking, including same-name local initializer callees such as Bevy PBR `let point_light = point_light(...)`. |
| `test_atomics`, `atomics/` | Covered | Atomic declarations/usages are covered by source-level declaration dependency tests. |
| `test_modf`, `modf/` | Covered | Builtin-return usage is covered at source-text dependency level. |
| `test_diagnostic_filters`, `diagnostic_filters/` | Source-level failure-covered / oracle failure-guarded | The pinned upstream test is marked `should_panic` in `naga_oil` because diagnostic-filter validation/writeback is not supported there yet. MoonBit now treats the mirrored unsupported `diagnostic(warning, ...)` fixture as a compose failure, and the stale expected writer output is excluded from byte diffing while the parity gate explicitly asserts the current upstream diagnostic failure. |
| `effective_defs`, `effective_defs/` | Covered | Descriptor-level shader defs now propagate through imported module branches, including the upstream bool-false `#ifdef` semantics and all eight branch combinations. |
| `wgsl_dual_source_blending`, `dual_source_blending/` | Covered + oracle-diffed | Dual-source blending attributes are preserved as source text and pinned oracle output is diffed with `DUAL_SOURCE_BLENDING` enabled. |
| `missing_import_in_module`, `missing_import_in_shader` | Covered + oracle-diffed | Local errors cover source-level missing imports; pinned oracle emits upstream-identical missing-import diagnostics when exact Naga wording is required. |
| `err_parse`, `err_validation`, `error_test/` | Oracle guardrail | Exact Naga parser/validator diagnostics are out of preprocessing scope, but selected expected diagnostics are diff-checked by the pinned oracle. |
| `wgsl_call_glsl`, `glsl_call_wgsl`, `basic_glsl`, `glsl/` | Oracle-covered / out of MoonBit core scope | GLSL frontend behavior belongs to upstream Naga, so the MoonBit core does not implement it. The pinned parity gate now diff-checks both deterministic GLSL/WGSL writer outputs and treats `basic_glsl` as a frontend smoke case without a stable expected writer file. |
| `glsl_const_import`, `glsl_wgsl_const_import`, `wgsl_glsl_const_import`, `glsl_const_import/` | Oracle-covered / out of MoonBit core scope | Mixed GLSL/WGSL frontend composition is Naga-backed scope, not MoonBit source-level preprocessing scope. The pinned parity gate diff-checks all three upstream expected outputs. |
| `test_raycasts`, `raycast/` | Oracle-covered / out of MoonBit core scope | Ray-query validation is Naga validator scope. Source-level imports remain covered locally, and the pinned parity gate compiles the upstream ray-query fixture with `RAY_QUERY` enabled because upstream intentionally has no stable writer expected output. |
| `additional_import`, `add_imports/` | Covered | Root compose/export requests and registered composable modules can inject additional imports, including upstream-style override plugins without `#define_import_path`. Runtime shader execution remains oracle-only. |
| `invalid_override` | Covered | Upstream `override fn module::item` syntax now errors when the target was not declared `virtual`; export diagnostics still warn when manual redirects never match. |
| `bad_identifiers`, `invalid_identifiers/` | Covered | Top-level declaration names and function parameters are sanitized in final composed/exported source; invalid struct-member identifiers now report compose errors like upstream. |
| `test_shader`, `compute_test.wgsl` | Covered | Local export smoke coverage preserves the compute entry point and imported module dependency. Upstream runtime execution remains outside the library scope and belongs to downstream runtime tests. |
| Complete Bevy import-only roots | Covered real-world fixture | Forward, prepass, and mesh-only roots tree-shake to empty output when their item imports are not referenced by root source, matching upstream oracle behavior. |
| Full upstream fixture mirror | Covered | `testdata/naga_oil_upstream/compose_tests` mirrors all 110 upstream fixture files, including 75 WGSL files, expected WGSL output, GLSL cases, errors, overrides, raycast, and Bevy path import fixtures. |

## Standing Guardrails

1. Import syntax must stay canonical.
   Metadata parsing and compose planning now share the tokenizer-based import
   parser. Any future import syntax extension must land there first.

2. Compose must use checked metadata.
   `metadata.get_preprocessor_metadata` is a strict raising API, matching
   upstream metadata extraction. Composer paths must keep propagating metadata
   errors so module construction rejects upstream-invalid directives, including
   module-local `#define` directives in composable modules.

3. Compose requests must stay explicit.
   `WgslComposeOptions` owns root-scoped additional imports, shader defs, value
   defs, and redirects. Do not reintroduce implicit mutable session parameters
   on the public API.

4. Preprocessing must stay in `preprocess`.
   Template constant substitution and strict conditional filtering live in the
   `preprocess` package. GLSL `#version` stripping/validation is also part of
   that strict preprocessing boundary so full imports, item imports, active
   scans, and source catalogs cannot diverge. `compose` may map
   `PreprocessError` into `ComposerError`, but must not maintain a second
   preprocessor or a permissive conditional evaluator.

5. Declaration analysis must stay shared.
   Composition, export, source maps, and tree-shaking use the same declaration
   graph. Any new WGSL declaration form must be parsed there before composer or
   export logic consumes it.

6. Source catalogs must come from final prepared WGSL.
   `PreparedWgslSource.source_catalog` must be extracted from the same resolved
   WGSL stored in `PreparedWgslSource.source`. Do not rebuild catalogs from raw
   registered files, root-only bool/int maps, or any dependency-closure source
   that has not passed through compose-time alias resolution and writeback.

7. Rename/writeback and dependency analysis must be AST/token-driven.
   All semantic rewrites must be expressed as `WgslRenamePlan` rules in
   `analysis`: global declaration plus references, references only, or function
   locals. Dependency analysis must consume parsed declaration identifiers
   rather than raw declaration text. Composer, virtual overrides,
   duplicate-binding cleanup, suffix lowering, and writeback sanitization must
   not reintroduce source-span copy-and-replace rewriting.

8. Parser internals must stay narrow.
   Syntax should not expose debug-only statement classification, raw text spans,
   or convenience text wrappers unless a production package consumes them. Move
   package-specific identifier collection and planning helpers into the owning
   package instead of expanding the syntax public API.

9. The Naga boundary must stay explicit.
   Preprocessing and source-level WGSL composition belong in MoonBit. Naga IR,
   validation, GLSL, writer byte parity, and runtime execution remain outside
   this package's core scope.

## Downstream Verification

For `mgstudio` or similar consumers, the expected verification path is:

1. Upgrade to `Milky2018/moon_wgsl 0.6.2` or current `main`.
2. Rerun the downstream WGSL preprocessing/compose tests against byte-identical
   Bevy WGSL sources.
3. Confirm that previous preprocessing failures such as unresolved
   `View`/`view_bindings::view`, duplicate aliased bindings, and leaked
   root-local `#define TONEMAPPING_PASS`, and unresolved entrypoint parameter
   `in` no longer appear.
4. Treat any remaining wgpu pipeline creation or shader validation failure as a
   new issue only if the emitted WGSL still shows a preprocessing mismatch.
