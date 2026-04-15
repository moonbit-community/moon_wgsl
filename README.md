# moon_wgsl

`Milky2018/moon_wgsl` is a MoonBit library for WGSL preprocessing, import
analysis, and shader composition.

This package was extracted from `mgstudio` and keeps the former `naga_oil`
surface at the root package so downstream code can continue to use the same
high-level concepts:

```moonbit
import "Milky2018/moon_wgsl"
```

## What This Library Provides

`moon_wgsl` focuses on three related tasks:

- Parse shader metadata such as `#define_import_path`, `#define`, used imports,
  and top-level WGSL directives.
- Preprocess shader source with conditional compilation and shader-definition
  substitution.
- Compose WGSL modules by resolving `#import` directives from a registered
  in-memory source registry.

The library is intended for projects that want `naga_oil`-style shader module
composition in MoonBit without introducing a separate CLI step.

## Highlights

- Supports `#ifdef`, `#ifndef`, `#if`, `#else if`, `#else`, and `#endif`.
- Supports shader definition values of type `Bool`, `Int`, and `UInt`.
- Parses grouped imports such as
  `#import bevy_render::{view::View, maths::{PI_2, powsafe}}`.
- Supports import aliases such as `#import bevy_render::maths as maths`.
- Supports quoted file-path imports such as
  `#import "../shared/common.wgsl" SharedVertex, build_color`.
- Supports bulk source registration with `register_wgsl_source_files`.
- Supports source-tree scanning and registration through `moonbitlang/x/fs`.
- Supports preflight registry diagnostics with
  `analyze_wgsl_source_files_for_registry` and
  `register_wgsl_source_files_checked`.
- Preserves and re-emits WGSL `enable`, `requires`, and `diagnostic(...)`
  directives.
- Tracks only actually used imported items when extracting metadata.
- Resolves composable modules from registered WGSL source strings.
- Exports single-file WGSL with declaration-level tree-shaking, an explicit
  source catalog, source-map entries, and diagnostics.
- Supports token-based source-level symbol redirects during composition and
  export.

## Core Concepts

### 1. Metadata Extraction

Use `get_preprocessor_metadata` or `get_preprocessor_data` when you want to
inspect a shader without fully composing it.

Metadata includes:

- Optional module name from `#define_import_path`
- Imported module/item pairs that are actually used
- Module-local shader definitions declared with `#define`
- Effective definition names referenced by conditional blocks or `#NAME`
  substitutions
- Top-level WGSL directives

Example:

```moonbit
import "Milky2018/moon_wgsl"

let metadata = @moon_wgsl.get_preprocessor_metadata(
  "#define_import_path bevy_ui::ui_node\n#define HDR\n#define TONEMAP_MODE 2u\n#import bevy_render::{view::View, globals::Globals}\n#import bevy_render::maths as maths\nfn main(view: View, globals: Globals) -> f32 {\n  return maths::tone_map(1.0);\n}\n",
)

inspect(metadata.name)
inspect(metadata.imports.length())
inspect(metadata.wgsl_directives.is_empty())
```

### 2. Preprocessing a Single Shader

Use `Preprocessor::preprocess` to evaluate conditional blocks, strip import
declarations from the output, and substitute shader-definition values.

```moonbit
import "Milky2018/moon_wgsl"
import "moonbitlang/core/hashmap"

let defs : @hashmap.HashMap[String, @moon_wgsl.ShaderDefValue] = @hashmap.HashMap::new()
defs.set("TEXTURE", @moon_wgsl.ShaderDefValue::Bool(true))

let source =
  "#ifdef TEXTURE\nvar sprite_texture: texture_2d<f32>;\n#else\nvar sprite_texture: texture_2d_array<f32>;\n#endif\n"

let output = @moon_wgsl.Preprocessor::default().preprocess(source, defs) catch {
  err => abort(err)
}

inspect(output.preprocessed_source)
inspect(output.imports.length())
```

### 3. Composing Registered WGSL Modules

`Composer` expands `#import` directives recursively, resolves aliases, and
merges imported definitions into a final WGSL string.

The recommended path is to register shaders on the `Composer` instance itself.
Global registry helpers still exist for compatibility, but new code should
prefer Composer-owned registry state.

```moonbit
import "Milky2018/moon_wgsl"
import "moonbitlang/core/hashmap"

let composer = @moon_wgsl.Composer::default()
composer.clear_registered_wgsl_source_registry()

composer.register_wgsl_source(
  "render/maths.wgsl",
  "#define_import_path bevy_render::maths\nconst PI_2: f32 = 6.28318;\n",
)

composer.register_wgsl_source(
  "sprite_render/mesh2d/mesh2d_functions.wgsl",
  "#define_import_path bevy_sprite::mesh2d_functions\n#import bevy_render::maths::PI_2\nfn twice_pi() -> f32 {\n  return PI_2;\n}\n",
)

composer.register_wgsl_source(
  "sprite_render/mesh2d/mesh2d.wgsl",
  "#import bevy_sprite::mesh2d_functions as mesh_functions\nfn demo() -> f32 {\n  return mesh_functions::twice_pi();\n}\n",
)

let composed = composer.compose_wgsl(
  "sprite_render/mesh2d/mesh2d.wgsl",
  {
    assets_base: "",
    defines: @hashmap.HashMap::new(),
    value_defines: @moon_wgsl.default_wgsl_value_defines(),
    redirects: [],
  },
) catch {
  err => abort(err.message())
}

inspect(composed.contains("const PI_2"))
inspect(composed.contains("return twice_pi();"))
```

### 4. Bulk Registry and Relative File Imports

You can register a batch of shader files at once and use relative quoted paths
between them. Composer instances expose the same registry APIs as the global
compatibility helpers.

```moonbit
import "Milky2018/moon_wgsl"
import "moonbitlang/core/hashmap"

let composer = @moon_wgsl.Composer::default()
composer.clear_registered_wgsl_source_registry()
composer.register_wgsl_source_files([
  {
    rel_path: "shaders/shared/common.wgsl",
    source: "struct SharedValue {\n  tint: vec4<f32>,\n}\n",
  },
  {
    rel_path: "shaders/effects/main.wgsl",
    source: "#import \"../shared/common.wgsl\" SharedValue\nfn shade(value: SharedValue) -> vec4<f32> {\n  return value.tint;\n}\n",
  },
])

inspect(
  composer.registered_wgsl_source("shaders/effects/main.wgsl") is Some(_),
)
let composed = composer.compose_wgsl("shaders/effects/main.wgsl", {
  assets_base: "",
  defines: @hashmap.HashMap::new(),
  value_defines: @moon_wgsl.default_wgsl_value_defines(),
  redirects: [],
}) catch {
  err => abort(err.message())
}
inspect(composed.contains("struct SharedValue"))
```

If you want collision diagnostics before mutating the registry, use the checked
path:

```moonbit
let files = [
  {
    rel_path: "shaders/demo/a.wgsl",
    source: "#define_import_path demo::dup\nfn a() -> f32 { return 1.0; }\n",
  },
  {
    rel_path: "shaders/demo/b.wgsl",
    source: "#define_import_path demo::dup\nfn b() -> f32 { return 2.0; }\n",
  },
]

let diagnostics = @moon_wgsl.analyze_wgsl_source_files_for_registry(files)
inspect(diagnostics.length())

let checked_diagnostics = @moon_wgsl.register_wgsl_source_files_checked(files)
inspect(checked_diagnostics.length())
```

### 5. Scanning a WGSL Source Tree

If your shaders already live on disk, use `scan_wgsl_source_files` or the
Composer convenience helpers built on top of `moonbitlang/x/fs`.

Scanned `rel_path` values are relative to the scan root, so scanning
`assets/shaders` yields registry keys such as `effects/main.wgsl`.

```moonbit
import "Milky2018/moon_wgsl"
import "moonbitlang/core/hashmap"

let composer = @moon_wgsl.Composer::default()
composer.clear_registered_wgsl_source_registry()
composer.register_wgsl_source_tree("assets/shaders", {
  recursive: true,
  extensions: [".wgsl"],
  exclude_prefixes: ["generated", "tmp"],
}) catch {
  _ => abort("failed to scan WGSL shader tree")
}

let composed = composer.compose_wgsl("effects/main.wgsl", {
  assets_base: "",
  defines: @hashmap.HashMap::new(),
  value_defines: @moon_wgsl.default_wgsl_value_defines(),
  redirects: [],
}) catch {
  err => abort(err.message())
}

inspect(composed.contains("fn shade"))
```

If you want to preflight a tree before registration, use the checked scan path:

```moonbit
let (files, diagnostics) = @moon_wgsl.scan_wgsl_source_files_checked(
  "assets/shaders",
  @moon_wgsl.WgslSourceScanOptions::default(),
) catch {
  _ => abort("failed to scan WGSL shader tree")
}

inspect(files.length())
inspect(diagnostics.length())
```

### 6. Exporting a Single WGSL File

Use `Composer::export_wgsl_with_options` to produce a fully expanded
single-file WGSL output. The export path also supports declaration-level
tree-shaking and returns source-map entries, the dependency-closure source
catalog used for matching, plus diagnostics.

```moonbit
import "Milky2018/moon_wgsl"
import "moonbitlang/core/hashmap"

let composer = @moon_wgsl.Composer::default()
composer.clear_registered_wgsl_source_registry()
composer.register_wgsl_source_files([
  {
    rel_path: "shaders/shared/common.wgsl",
    source: "struct SharedParams {\n  tint: vec4<f32>,\n}\nstruct SharedVertex {\n  params: SharedParams,\n}\nfn build_color(vertex: SharedVertex) -> vec4<f32> {\n  return vertex.params.tint;\n}\n",
  },
  {
    rel_path: "shaders/effects/main.wgsl",
    source: "#import \"../shared/common.wgsl\" SharedVertex, build_color\nfn shade(vertex: SharedVertex) -> vec4<f32> {\n  return build_color(vertex);\n}\n",
  },
])

let exported = composer.export_wgsl_with_options(
  "shaders/effects/main.wgsl",
  {
    assets_base: "",
    defines: @hashmap.HashMap::new(),
    value_defines: @moon_wgsl.default_wgsl_value_defines(),
    redirects: [],
  },
  { root_items: ["shade"] },
) catch {
  err => abort(err.message())
}

inspect(exported.source.contains("#import"))
inspect(exported.source_catalog.length())
inspect(exported.source_map.length())
inspect(exported.diagnostics.length())
```

If you need the declaration catalog directly, without exporting a specific
entrypoint, use `Composer::build_wgsl_source_catalog` on the same Composer:

```moonbit
let catalog = composer.build_wgsl_source_catalog({
  assets_base: "",
  defines: @hashmap.HashMap::new(),
  value_defines: @moon_wgsl.default_wgsl_value_defines(),
  redirects: [],
})
inspect(catalog.length())
```

The top-level `build_registered_wgsl_source_catalog` helper is still available
when you intentionally want to inspect the global compatibility registry.

### 7. Applying Source-Level Redirects

Use the redirect-aware APIs when you want to remap one imported symbol to
another during composition/export without depending on Naga IR.

```moonbit
let redirects = [{ from_name: "build_shadow", to_name: "build_color" }]

let exported = composer.export_wgsl_with_options(
  "shaders/effects/redirect.wgsl",
  {
    assets_base: "",
    defines: @hashmap.HashMap::new(),
    value_defines: @moon_wgsl.default_wgsl_value_defines(),
    redirects,
  },
  { root_items: ["shade"] },
) catch {
  err => abort(err.message())
}

inspect(exported.source.contains("build_shadow"))
inspect(exported.source.contains("build_color"))
```

Legacy compatibility wrappers are still available:

```moonbit
let catalog = @moon_wgsl.build_registered_wgsl_source_catalog(
  @hashmap.HashMap::new(),
  @moon_wgsl.default_wgsl_value_defines(),
)
inspect(catalog.length())
```

## Import Syntax Supported

The parser supports several common import forms:

```wgsl
#import bevy_render::view::View
#import bevy_render::maths as maths
#import bevy_render::{view::View, globals::Globals}
#import bevy_render::{maths::{PI_2, powsafe}}
#import "shaders/skills/shared.wgsl" Vertex, VertexOutput
#import "../shared/common.wgsl" SharedVertex, build_color
```

## Public API Overview

Main public entry points:

- `Preprocessor`
  Parses and preprocesses a single shader source string.
- `Composer`
  Owns a WGSL registry and recursively composes registered shader modules.
- `get_preprocessor_metadata`
  Returns a rich metadata object for a shader source string.
- `get_preprocessor_data`
  Returns the simplified `(name, imports, defines)` tuple.
- `register_wgsl_source` / `registered_wgsl_source`
  Manage the global compatibility WGSL source registry.
- `Composer::register_wgsl_source` / `Composer::register_wgsl_source_files`
  Manage a Composer-owned WGSL source registry for hermetic composition.
- `Composer::compose_wgsl`
  Composes WGSL from Composer-owned registry state and `WgslComposeOptions`.
- `register_wgsl_source_files`
  Registers a batch of WGSL source files into the global compatibility
  registry.
- `analyze_wgsl_source_files_for_registry`
  Performs preflight validation for duplicate module names and rel-path
  ownership conflicts.
- `register_wgsl_source_files_checked`
  Runs preflight registry diagnostics and only mutates registry state when no
  errors are reported.
- `build_registered_wgsl_source_catalog`
  Returns the declaration catalog for the global compatibility registry.
- `Composer::build_wgsl_source_catalog`
  Returns the declaration catalog for a specific Composer registry.
- `build_wgsl_import_module_paths` / `resolve_wgsl_import_module`
  Build and query module-path resolution data.
- `resolve_wgsl_import_file_path`
  Resolves relative or quoted file-path imports against a source file path.
- `rewrite_wgsl_symbol_redirects`
  Applies token-based source-level symbol redirects to WGSL source.
- `Composer::load_wgsl_preprocessed_with_redirects`
  Composes WGSL while applying symbol redirects before import pruning.
- `Composer::export_wgsl_with_options`
  Produces single-file WGSL from `WgslComposeOptions` without exposing legacy
  session internals.
- `Composer::export_wgsl`
  Legacy compatibility wrapper for single-file WGSL export.
- `Composer::export_wgsl_with_redirects`
  Legacy compatibility wrapper for redirect-aware single-file WGSL export.

Important public data structures:

- `ShaderDefValue`
- `ImportDefinition`
- `PreprocessOutput`
- `PreprocessorMetaData`
- `ComposableModuleDescriptor`
- `ComposableModuleDefinition`
- `WgslDirectives`
- `WgslSourceFile`
- `WgslComposeOptions`
- `WgslSymbolRedirect`
- `WgslExportOptions`
- `WgslExportOutput`
- `WgslSourceCatalogEntry`
- `WgslSourceMapEntry`
- `WgslDiagnostic`

For the full exported surface, see
[pkg.generated.mbti](./pkg.generated.mbti).

## Behavior Notes

- `#define_import_path` is used as the canonical module name for composition.
- `Composer` now owns registry/module resolution state; new code should prefer
  `Composer::register_wgsl_source*`, `Composer::compose_wgsl`, and
  `Composer::export_wgsl_with_options`.
- `Composer::load_wgsl_preprocessed` and global registry helpers remain
  available as compatibility APIs.
- Relative quoted file imports are resolved against the importing shader's
  registered path in the active Composer/global registry.
- `register_wgsl_source_files_checked` is the safe bulk-registration path when
  callers need deterministic diagnostics before mutating the global registry.
- `assets_base` is still present in the API for compatibility, but current
  source resolution is driven by the registry.
- `get_preprocessor_metadata` is forgiving by design: on parse failure it
  returns empty/default metadata instead of raising.
- `Preprocessor::preprocess` is the strict path and raises `PreprocessError`
  when parsing or conditional evaluation fails.
- `Composer::export_wgsl_with_options` scopes `source_catalog` and
  `source_map` to the dependency closure of the current compose/export
  session instead of the full registry.
- Source-level redirects are token-based and intentionally skip declaration
  heads, field accesses (`.`), and attributes (`@...`); they are intended for
  imported helper/type names rather than locally shadowed identifiers.

## Development

Run the test suite from the module root:

```bash
moon test
```

The repository currently includes tests for:

- metadata extraction
- grouped and aliased imports
- quoted relative file imports
- bulk registry collision diagnostics
- source catalog exposure for ambiguous source-map diagnostics
- WGSL directive preservation
- conditional preprocessing semantics
- module registration and import resolution
- recursive composition behavior
- source-level symbol redirects during composition/export
- single-file WGSL export with tree-shaking and diagnostics

## Compatibility Goal

This package aims to preserve the practical `naga_oil` programming model used
by existing downstream shader pipelines. The tests intentionally exercise
behavior that matches upstream usage patterns from the original extraction
context.

## License

Apache-2.0
