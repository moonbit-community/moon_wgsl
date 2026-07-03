# naga_oil Preprocessing Parity

Last updated: 2026-07-03

## Scope

`moon_wgsl` targets `naga_oil` preprocessing and source-level composition
compatibility for WGSL, with an explicit parity boundary for functionality that
belongs to Naga itself. The current gate distinguishes three classes instead of
mixing them in shell control flow: moon_wgsl byte parity, moon_wgsl semantic
parity for explicitly stale upstream fixtures, and moon_wgsl source-level error
parity.

The preprocessing target is:

- Match upstream WGSL import syntax, shader-def condition handling, module path
  resolution, alias rewriting, declaration dependency expansion, diagnostic
  directive preservation, and single-file WGSL export behavior in the MoonBit
  core.
- Keep every mirrored upstream expected fixture classified in
  `testdata/naga_oil_upstream/compose_tests/parity_manifest.tsv`.
- Byte-diff every deterministic WGSL compose output through the independent
  naga-oil writer backend, while separately validating the default runtime
  WGSL backend when upstream writer bytes exercise a non-runtime writer form.
- Gate source-level composer errors locally, including the mirrored Naga-style
  parser/validator diagnostics and deterministic GLSL frontend compose outputs
  that appear in the upstream fixture set.
- Use the pinned `naga_oil` oracle only as a differential reference and CI
  guardrail, not as a runtime dependency of the MoonBit library.

## Current Status

As of current `main`, the published workspace line is `0.15.3`. There are no
known open WGSL source-level preprocessing gaps in the mirrored upstream compose
corpus. Deterministic WGSL outputs are byte-gated through
`tools/check_moon_wgsl_byte_parity.sh`; source-level error shapes are gated
through `tools/check_moon_wgsl_error_parity.sh`; every mirrored expected fixture
is classified by the manifest and audited by
`tools/check_naga_oil_parity_inventory.sh`.

The external naga-oil compose strict byte parity gate currently passes with:

- `cases=170`
- `comparable=149`
- `oracle-blocked=21`
- `writer-exact=149`
- `byte-exact=149`

The Naga writer representative trace gate currently passes 45 cases through
`tools/check_naga_writer_representative_trace.sh`.

Downstream consumers such as `mgstudio` should use current `main` or the latest
published release, then rerun their shader-pipeline tests. Runtime pipeline
layout compatibility is covered in this repository only through the isolated
native `tools/wgpu_validation` subproject, not as a root module dependency.

## Upstream References

- Upstream repository: `https://github.com/bevyengine/naga_oil`
- Current pinned oracle commit: `bc444c82bb593ede94c55cdbf799e9743800843e`
- `bevyengine/naga_oil/src/compose/test.rs`
- `bevyengine/naga_oil/src/compose/tests`

## Compatibility Gates

Parity is tracked with explicit gates:

1. Local source-level parity tests.
   `upstream_compose_parity_test.mbt` contains MoonBit ports of upstream
   `naga_oil` compose cases that can be expressed without Naga IR.

2. Real shader-tree regression tests.
   `bevy_wgsl_parity_test.mbt` registers complete Bevy WGSL fixture files from
   `testdata/bevy_wgsl` and checks that import-only roots tree-shake to empty
   output like upstream `naga_oil`.

3. Moon WGSL byte parity.
   `tools/check_moon_wgsl_byte_parity.sh` composes deterministic upstream WGSL
   fixtures through moon_wgsl and byte-diffs the emitted WGSL against the
   mirrored upstream expected files. The atomics fixture also validates the
   default runtime compose output so byte parity with upstream writer output
   cannot hide invalid runtime WGSL.

4. Moon WGSL source-level error parity.
   `tools/check_moon_wgsl_error_parity.sh` runs moon_wgsl against upstream
   source-level failure cases and asserts stable diagnostic shape for missing
   imports, invalid virtual overrides, unknown identifiers, and return-type
   validation failures.

5. Upstream oracle.
   `tools/naga_oil_oracle` is a Rust harness pinned to the upstream commit
   above. It composes WGSL and GLSL fixture trees through real `naga_oil` and
   compares every deterministic upstream compose output or diagnostic that can
   be emitted by the pinned oracle.

6. Fixture inventory gate.
   `tools/check_naga_oil_parity_inventory.sh` requires every file in
   `testdata/naga_oil_upstream/compose_tests/expected` to be classified by the
   manifest exactly once and verifies that byte/error rows are connected to
   their concrete gates.

7. Manifest-driven WGSL corpus matrix.
   `tools/check_wgsl_corpus_matrix.sh` reads
   `testdata/wgsl_corpus_manifest.tsv` and runs each case through declared
   stages: compose, parse, Naga validation, IR roundtrip, and Naga validation of
   emitted IR WGSL. This matrix is the expansion point for real shader coverage
   across static files, compose fixture roots, and generated downstream
   regressions.

8. Naga writer representative trace parity.
   `tools/check_naga_writer_representative_trace.sh` checks the Naga
   Compatibility Layer against representative upstream writer/order/name
   behavior. This is the gate for byte-level Naga writer convergence and should
   be expanded when new writer drift classes are found.

9. External naga-oil compose strict byte parity.
   `tools/check_external_naga_oil_compose_parity.sh` runs registered external
   compose cases against the pinned oracle and requires all comparable cases to
   be writer-exact and byte-exact. Oracle-blocked cases must be explicitly
   counted and cannot silently pass as skipped local failures.

10. CI parity gate.
   `tools/check_preprocess_parity.sh` runs the local preprocessing parity suite
   and pinned-oracle comparisons. The GitHub Actions `check` workflow runs the
   byte parity, error parity, inventory, preprocess parity, WGSL corpus matrix,
   validation, and wgpu runtime gates after the normal MoonBit test matrix.

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
| `test_diagnostic_filters`, `diagnostic_filters/` | Semantic local gate / oracle failure-guarded | The pinned upstream test is marked `should_panic` in `naga_oil` because diagnostic-filter validation/output emission is not supported there yet. The stale expected writer output is classified in the manifest as semantic rather than byte parity, while the oracle gate explicitly asserts the current upstream validation failure. |
| `effective_defs`, `effective_defs/` | Covered | Descriptor-level shader defs now propagate through imported module branches, including the upstream bool-false `#ifdef` semantics and all eight branch combinations. |
| `wgsl_dual_source_blending`, `dual_source_blending/` | Covered + oracle-diffed | Dual-source blending attributes are preserved as source text and pinned oracle output is diffed with `DUAL_SOURCE_BLENDING` enabled. |
| `missing_import_in_module`, `missing_import_in_shader` | Covered + oracle-diffed | Local errors cover source-level missing imports; pinned oracle emits upstream-identical missing-import diagnostics when exact Naga wording is required. |
| `err_parse`, `err_validation`, `error_test/` | Covered + oracle-diffed | The selected Naga-style parser/validator diagnostics are generated by moon_wgsl and byte-diffed locally, then pinned against the Rust oracle. |
| `wgsl_call_glsl`, `glsl_call_wgsl`, `basic_glsl`, `glsl/` | Covered + oracle-diffed | Deterministic GLSL/WGSL compose outputs are byte-gated through moon_wgsl and pinned against the Rust oracle. `basic_glsl` remains a frontend smoke case without a stable expected writer file. |
| `glsl_const_import`, `glsl_wgsl_const_import`, `wgsl_glsl_const_import`, `glsl_const_import/` | Covered + oracle-diffed | Mixed GLSL/WGSL const-import composition is byte-gated through moon_wgsl and pinned against the Rust oracle. |
| `test_raycasts`, `raycast/` | Oracle-covered / out of MoonBit core scope | Ray-query validation is Naga validator scope. Source-level imports remain covered locally, and the pinned parity gate compiles the upstream ray-query fixture with `RAY_QUERY` enabled because upstream intentionally has no stable writer expected output. |
| `additional_import`, `add_imports/` | Covered | Root compose/export requests and registered composable modules can inject additional imports, including upstream-style override plugins without `#define_import_path`. Runtime shader execution remains downstream/runtime scope rather than preprocessing parity scope. |
| `invalid_override` | Covered | Upstream `override fn module::item` syntax now errors when the target was not declared `virtual`; export diagnostics still warn when manual redirects never match. |
| `bad_identifiers`, `invalid_identifiers/` | Byte parity | Top-level declaration names, function parameters, local const-expression let inlining, global/member access materialization, and temporary names are byte-gated against the pinned upstream output; invalid struct-member identifiers still report compose errors like upstream. |
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
   that has not passed through compose-time alias resolution and identifier
   normalization.

7. Original-file provenance must use the origin graph.
   Source maps must read declaration provenance from
   `PreparedWgslSource.source_origins`, not from raw registered files and not
   from the final prepared-source catalog. The catalog describes runtime WGSL;
   the origin graph describes where each final declaration came from.

8. Rename and dependency analysis must be AST/token-driven.
   Composer import/name rewrites must stay symbol-binding-first: import
   liveness selects stable `WgslIrSymbolIdentity` bindings, transform resolves
   AST identifier nodes against that binding plan, and final names come from the
   identity-backed table. Phase boundaries must pass structured reference paths
   and non-optional symbol targets rather than `from_name` / `to_name` strings
   or `identity?` placeholders. `WgslRenamePlan` is only a package-private
   helper for synthetic local/virtual rewrites and must not be the composer
   binding model.
   Dependency analysis must consume parsed declaration identifiers rather than
   raw declaration text. Composer, virtual overrides, duplicate-binding cleanup,
   suffix lowering, and identifier normalization must not reintroduce
   source-span copy-and-replace rewriting.

9. Parser internals must stay narrow.
   Syntax should not expose debug-only statement classification, raw text spans,
   or convenience text wrappers unless a production package consumes them. Move
   package-specific identifier collection and planning helpers into the owning
   package instead of expanding the syntax public API.

10. The Naga boundary must stay explicit.
   Preprocessing and source-level WGSL composition belong in MoonBit. Mirrored
   upstream fixtures must enter a local moon_wgsl byte/error/semantic gate
   first; the pinned Rust oracle remains the differential reference, not the
   only executor for deterministic expected outputs.

## Downstream Verification

For `mgstudio` or similar consumers, the expected verification path is:

1. Upgrade to `Milky2018/moon_wgsl 0.15.3` or current `main`.
2. Rerun the downstream WGSL preprocessing/compose tests against byte-identical
   Bevy WGSL sources.
3. Confirm that previous preprocessing failures such as unresolved
   `View`/`view_bindings::view`, duplicate aliased bindings, and leaked
   root-local `#define TONEMAPPING_PASS`, and unresolved entrypoint parameter
   `in` no longer appear.
4. Treat any remaining wgpu pipeline creation or shader validation failure as a
   new issue only if the emitted WGSL still shows a preprocessing mismatch.
