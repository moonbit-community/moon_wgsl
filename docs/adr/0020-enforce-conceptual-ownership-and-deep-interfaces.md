# Enforce conceptual ownership and deep interfaces

The physical workspace split is necessary but not sufficient. A module owns a concept only when its interface and implementation can change for that concept without forcing an unrelated lower-level module to change. The workspace therefore adopts the following final seams and rejects deviations in the architecture gate.

## WGSL Core

`Milky2018/wgsl` owns the Official WGSL Frontend:

- official WGSL lexer, AST, parser, validation, and semantic IR
- official `enable`, `requires`, and `diagnostic` directives
- generic semantic analysis and valid-WGSL writing
- neutral writer mechanics only when their interface contains no Naga or naga-oil policy

WGSL Core does not own preprocessing conditionals, shader definitions, imports, composition descriptors, source registries, symbol redirects, project profiles, generated-import provenance, final names, link graphs, import arena events, or compatibility writer modes.

`parse_wgsl_module_to_ir(source)` is the sole public semantic-lowering entry point. The resulting semantic IR records program meaning and source facts required by official WGSL diagnostics. It contains no compatibility flags, provenance caches, compose graph records, or writer naming policy.

## naga-oil frontend and composer

`Milky2018/moon_wgsl_naga_oil` owns all naga-oil dialect syntax and composition contracts:

- `ifdef`, `ifndef`, conditional expressions, defines, template constants, `define_import_path`, and imports
- shader-definition values and explicitly selected project profiles
- preprocess, metadata, source registry, compose, export, source catalog, and compatibility diagnostic contracts
- Compose Graph, Symbol Graph, Final Name Table, import events, source provenance, emission plans, and source editing

The naga-oil frontend preserves extension-source spans and diagnostics, then produces official WGSL before invoking WGSL Core. It may reuse the neutral lexer, but it must not add dialect variants to the official AST.

Generic defaults are empty and language-neutral. Bevy-compatible defaults live in an explicit profile selected by a caller; they are not implicit WGSL or generic composer facts.

Directive scanning, import syntax parsing, transform, import substitution, and source rewrite are in-process implementation packages under `Milky2018/moon_wgsl_naga_oil/internal/`. MoonBit's `internal` visibility prevents packages outside the owning module from importing them while preserving local package boundaries and white-box invariant tests. Their seams are not external interfaces.

## Naga compatibility

`Milky2018/moon_wgsl_naga` owns Naga-shaped declaration provenance, import ordering events, arena scheduling, final temporary naming, and writer behavior.

Its central seam is conceptually:

```text
write_naga_compatible_wgsl(
  module: WgslSemanticIr,
  context: NagaCompatibilityContext,
  options: NagaWriterOptions,
) -> String
```

`NagaCompatibilityContext` is opaque. Its construction types are Naga-owned compatibility facts, not WGSL IR records and not naga-oil graph implementation types. naga-oil maps its graph into this context. The Naga module derives its compatibility view internally; callers never mutate semantic IR to request compatibility behavior.

Trace and parity inspection belong to a diagnostics package used by repository tools. They are not methods on the normal writer or facade object.

## Moon WGSL Facade

`Milky2018/moon_wgsl` owns its user-facing `Composer` type instead of re-exporting the naga-oil implementation type. The target method interface is:

- `Composer::default`
- `Composer::register_source`
- `Composer::register_source_files`
- `Composer::clear_sources`
- `Composer::add_module`
- `Composer::remove_module`
- `Composer::compose`
- `Composer::prepare`
- `Composer::export`

`compose` is the single normal composition entry point. Runtime-valid versus strict compatibility output is selected through `ComposeOptions`, not through additional pipeline-stage methods. Filesystem scanning remains a separate adapter because it introduces I/O and is not required by the in-memory composition seam.

The facade owns its errors and maps lower-level failures. It exposes no before-IR, trace, parity, writer-plan, symbol-graph, source-edit, or internal-stage interface.

## Writer source ownership

Source symlinks are not an ownership mechanism. WGSL Core is the sole source owner for three neutral deep services: `WgslIrReachability` computes semantic root reachability, `WgslIrTypeInference` answers expression type queries, and `WgslIrTypeSpelling` formats types from caller-supplied final-name and global-expression lookups plus two explicit byte spelling choices. These interfaces are much smaller than their implementations and contain no Naga ordering, provenance, temporary naming, or compatibility view.

The Naga adapter consumes those services and owns all compatibility policy. It supplies names and byte choices but cannot mutate semantic IR through the service interfaces. The architecture manifest records each source owner, rejects retired Naga copies even under a new exact-copy path, and forbids all cross-module source symlinks.

## Migration and enforcement

This change is a synchronized breaking release. Compatibility aliases must not remain in WGSL Core merely to preserve old imports.

The architecture manifest records:

- exact package inventories
- forbidden concept families by owning path
- complete facade type method inventories, following re-exported types
- source symlink ownership
- strict package and source ownership without migration exceptions

The architecture manifest has no migration-exception mechanism. Ownership violations must be fixed in the code or reflected as an intentional final architecture change.
