# Ownership and API migration

This is a synchronized breaking change. It removes forwarding aliases that
would keep concepts in the wrong module. Choose the package that owns the
operation instead of importing implementation stages.

## Module and package imports

| Old import | New import or workflow |
| --- | --- |
| `Milky2018/moon_wgsl` subpackages for ordinary composition | Import the root package `Milky2018/moon_wgsl` and use its opaque `Composer`. |
| `Milky2018/moon_wgsl/{ast,ast_analysis,lex,parser,ir}` | `Milky2018/wgsl/{ast,ast_analysis,lex,parser,ir}`. |
| `Milky2018/moon_wgsl/common` or `Milky2018/wgsl/common` | `Milky2018/moon_wgsl_naga_oil/contract`; the facade re-exports the application-facing contract types. |
| `Milky2018/moon_wgsl/{metadata,preprocess,resolver,compose,export}` | For normal workflows use the facade. For independently useful lower-level APIs use the package with the same final segment under `Milky2018/moon_wgsl_naga_oil/`. |
| Naga-compatible writer or trace helpers in WGSL Core | `Milky2018/moon_wgsl_naga`. |
| `Milky2018/wgsl/directive_syntax` | No direct parser replacement. Use `preprocess` or `metadata`; directive scanning is now `moon_wgsl_naga_oil/internal/directive`. |
| `Milky2018/wgsl/import_syntax` | No direct parser replacement. Use `metadata`, `resolver`, or `compose`; import parsing is now `moon_wgsl_naga_oil/internal/import_syntax`. |
| `moon_wgsl_naga_oil/{directive,import_syntax,import_substitution,source_rewrite,transform}` | No external import. These are compiler-enforced internal implementation packages. Use `preprocess`, `metadata`, `resolver`, `compose`, or `export` according to the desired result. |
| Writer source files linked from `moon_wgsl_naga` into WGSL Core | No source-level API. Core now owns neutral `WgslIrReachability`, `WgslIrTypeInference`, and `WgslIrTypeSpelling` services; Naga consumes them through normal package imports. |

The supported public naga-oil package inventory is `contract`, `profile`,
`preprocess`, `metadata`, `resolver`, `compose`, `export`, and `diagnostics`.

## Contract types and defaults

Every type formerly exported from `wgsl/common` moved unchanged in meaning to
`moon_wgsl_naga_oil/contract`:

- composition: `ComposableModuleDescriptor`, `WgslComposeOptions`,
  `WgslSymbolRedirect`
- imports: `ImportDefinition`, `ImportDefWithOffset`, `WgslImportTarget`,
  `WgslReferencePath`, `WgslResolvedImportModule`
- preprocessing: `ShaderDefValue`, `PreprocessOutput`,
  `PreprocessorMetaData`
- official source directives: `EnableDirective`, `RequiresDirective`,
  `DiagnosticDirective`, `WgslDirectives`
- sources and diagnostics: `WgslSourceFile`, `WgslSourceScanOptions`,
  `WgslSourceCatalogEntry`, `WgslSourceOriginEntry`,
  `WgslSourceOriginKind`, `PreparedWgslSource`, `WgslDiagnostic`, and
  `WgslDiagnosticSeverity`
- export: `WgslExportOptions`, `WgslExportOutput`, and `WgslSourceMapEntry`

`default_wgsl_value_defines()` was not a language default. Replace it with an
explicit project policy:

```mbt
let options = @contract.WgslComposeOptions::default()
options.value_defines = @profile.bevy_wgsl_value_defines()
```

`WgslComposeOptions::default()` is now language-neutral and starts with no
project-specific defines.

Opaque result records now have stable accessors. Replace direct field access
with `PreprocessOutput::source()` / `imports()`,
`PreparedWgslSource::source()` / `source_files()` / `source_catalog()` /
`source_origins()` / `diagnostics()`, and the corresponding
`WgslExportOutput` accessors (`source`, `source_catalog`, `source_origins`,
`source_map`, and `diagnostics`). Array accessors return copies.

## Facade workflow changes

The old facade re-exported `@compose.Composer`, `ComposerError`, and
`ComposableModuleDefinition`. The new facade owns `Composer` and `WgslError`;
lower-level stage errors are mapped to `WgslError::WorkflowFailed`.

| Old facade or lower-level call | New facade call |
| --- | --- |
| `Composer::default()` | `Composer::default()` (now a facade-owned opaque type). |
| `register_source`, `register_source_files`, `clear_sources` | Same names. |
| `add_composable_module(desc)` | `add_module(desc)`; the facade no longer returns an internal module definition. |
| `remove_composable_module(name)` | `remove_module(name)`. |
| `prepare_wgsl_source(path, options)` | `prepare(path, options)`. |
| `compose_wgsl(path, options)` or normal uses of `compose_wgsl_source` | `compose(path, options)`. |
| `export_wgsl_with_options(composer, path, compose_options, export_options)` | `composer.export_wgsl(path, compose_options, export_options)`. |
| `compose_wgsl_runtime_valid` / `prepare_wgsl_source_runtime_valid` | Use normal `compose` / `prepare`; runtime-valid output is the facade contract. |
| `registered_source`, `contains_module` | No facade query. Keep registration state in the application, or deliberately use the lower-level `compose` package. |
| `register_source_tree` / `register_source_tree_checked` | Filesystem scanning remains an explicit adapter: call `resolver::scan_wgsl_source_files[_checked]`, then `register_source_files`. |
| before-IR, writer-parity, or writer-plan trace methods | Import `Milky2018/moon_wgsl_naga_oil/diagnostics` explicitly. These are repository/tooling workflows, not facade methods. |

The facade's complete `Composer` method inventory is `default`,
`register_source`, `register_source_files`, `clear_sources`, `add_module`,
`remove_module`, `prepare`, `compose`, and `export_wgsl`.

## Semantic IR and Naga compatibility

WGSL Core now exposes one semantic lowering entry point:
`parse_wgsl_module_to_ir(source)`. Removed overloads that accepted generated
imports or import-arena events have no Core replacement.

The removed `WgslIrGeneratedImportProvenance`, `WgslIrImportArenaEvent`,
`WgslIrImportArenaSymbol`, `WgslIrFinalNameTable`, `WgslIrLinkGraph`, and
`WgslIrSymbolIdentity` families were compatibility or composition state, not
semantic IR. Their ownership is now split as follows:

- composition identities, symbol graph, final-name table, reachability, and
  import events are owned by `moon_wgsl_naga_oil/compose`;
- Naga-shaped provenance and import-arena records are
  `WgslNagaGeneratedImportProvenance`, `WgslNagaImportArenaEvent`, and
  `WgslNagaImportArenaSymbol` in `moon_wgsl_naga`;
- the Naga writer accepts an opaque `WgslNagaComposeContext` and never mutates
  semantic IR to request compatibility behavior.

Application code should normally let the composer build this context. Direct
Naga integrations use `roundtrip_wgsl_source` for plain WGSL or
`roundtrip_wgsl_compose_source` with a deliberately constructed context.

## Diagnostics and advanced APIs

Normal callers use the facade and receive `WgslError`. Callers that need
preprocessing-only or metadata-only errors import the public lower-level
package directly. Repository parity and trace tools import
`moon_wgsl_naga_oil/diagnostics`, whose four explicit functions are
`compose_before_ir`, `compose_for_writer_parity`,
`trace_writer_function_plan`, and `trace_writer_module_plan`.

There are no compatibility aliases for removed internal stages. This keeps a
future parser, composer, or writer rewrite from becoming an application API
break merely because an implementation method changed.
