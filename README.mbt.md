# moon_wgsl

`Milky2018/moon_wgsl` is a MoonBit library for WGSL preprocessing, import
analysis, and shader composition.

The public surface follows `naga_oil` concepts while staying source-level and
multi-backend. Import the focused subpackage you need, such as `@common`,
`@ast`, `@parser`, `@metadata`, `@preprocess`, `@resolver`, `@analysis`, `@semantic`,
`@virtual_overrides`, `@writeback`, `@compose`, or `@export`:

```mbt check
///|
test "README: common package surface" {
  let value_defines = @common.default_wgsl_value_defines()
  debug_inspect(value_defines.length() > 0, content="true")
}
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
- Supports bulk source registration with `register_source_files`.
- Supports source-tree scanning and registration through `moonbitlang/x/fs`.
- Supports preflight registry diagnostics with
  `analyze_source_files` and
  `register_source_files_checked`.
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

Use `@metadata.get_preprocessor_metadata` when you want to inspect a shader
without fully composing it.

Metadata includes:

- Optional module name from `#define_import_path`
- Imported module/item pairs that are actually used
- Module-local shader definitions declared with `#define`
- Effective definition names referenced by conditional blocks or `#NAME`
  substitutions
- Top-level WGSL directives

Example:

```mbt check
///|
test "README: metadata extraction" {
  let metadata : @common.PreprocessorMetaData = @metadata.get_preprocessor_metadata(
    "#define_import_path bevy_ui::ui_node\n#define HDR\n#define TONEMAP_MODE 2\n#import bevy_render::{view::View, globals::Globals}\n#import bevy_render::maths as maths\nfn main(view: View, globals: Globals) -> f32 {\n  return maths::tone_map(1.0);\n}\n",
  ) catch {
    _ => abort("expected metadata extraction success")
  }

  debug_inspect(metadata.name, content="Some(\"bevy_ui::ui_node\")")
  debug_inspect(metadata.imports.length(), content="3")
  debug_inspect(metadata.wgsl_directives.is_empty(), content="true")
}
```

### 2. Preprocessing a Single Shader

Use `Preprocessor::preprocess` to evaluate conditional blocks, strip import
declarations from the output, and substitute shader-definition values.

```mbt check
///|
test "README: preprocess single shader" {
  let defs : @hashmap.HashMap[String, @common.ShaderDefValue] = @hashmap.HashMap::new()
  defs.set("TEXTURE", @common.ShaderDefValue::Bool(true))

  let source = "#ifdef TEXTURE\nvar sprite_texture: texture_2d<f32>;\n#else\nvar sprite_texture: texture_2d_array<f32>;\n#endif\n"

  let output : @common.PreprocessOutput = @preprocess.Preprocessor::default().preprocess(
    source, defs,
  ) catch {
    _ => abort("preprocess failed")
  }

  debug_inspect(
    output.preprocessed_source.contains("texture_2d<f32>"),
    content="true",
  )
  debug_inspect(output.imports.length(), content="0")
}
```

### 3. Composing Registered WGSL Modules

`Composer` expands `#import` directives recursively, resolves aliases, and
merges imported definitions into a final WGSL string.

The recommended path is to register shaders on the `Composer` instance itself.
`Composer::default()` starts with an empty registry and owns all state needed
for module resolution and composition.

```mbt check
///|
test "README: compose registered modules" {
  let composer : @compose.Composer = @compose.Composer::default()
  let defines : @hashmap.HashMap[String, Bool] = @hashmap.HashMap::new()
  let redirects : Array[@common.WgslSymbolRedirect] = []
  composer.clear_sources()

  composer.register_source(
    "render/maths.wgsl", "#define_import_path bevy_render::maths\nconst PI_2: f32 = 6.28318;\n",
  )

  composer.register_source(
    "sprite_render/mesh2d/mesh2d_functions.wgsl", "#define_import_path bevy_sprite::mesh2d_functions\n#import bevy_render::maths::PI_2\nfn twice_pi() -> f32 {\n  return PI_2;\n}\n",
  )

  composer.register_source(
    "sprite_render/mesh2d/mesh2d.wgsl", "#import bevy_sprite::mesh2d_functions as mesh_functions\nfn demo() -> f32 {\n  return mesh_functions::twice_pi();\n}\n",
  )

  let compose_options : @common.WgslComposeOptions = {
    defines,
    value_defines: @common.default_wgsl_value_defines(),
    redirects,
    additional_imports: [],
  }
  let composed : String = composer.compose_wgsl(
    "sprite_render/mesh2d/mesh2d.wgsl", compose_options,
  ) catch {
    _ => abort("compose failed")
  }

  debug_inspect(composed.contains("fn demo"), content="true")
  debug_inspect(composed.contains("mesh_functions::"), content="false")
}
```

### 4. Bulk Registry and Relative File Imports

You can register a batch of shader files at once and use relative quoted paths
between them. Composer instances own the registry used by composition.

```mbt check
///|
test "README: bulk registry and relative imports" {
  let composer : @compose.Composer = @compose.Composer::default()
  let defines : @hashmap.HashMap[String, Bool] = @hashmap.HashMap::new()
  let redirects : Array[@common.WgslSymbolRedirect] = []
  let files : Array[@common.WgslSourceFile] = [
    {
      rel_path: "shaders/shared/common.wgsl",
      source: "struct SharedValue {\n  tint: vec4<f32>,\n}\n",
    },
    {
      rel_path: "shaders/effects/main.wgsl",
      source: "#import \"../shared/common.wgsl\" SharedValue\nfn shade(value: SharedValue) -> vec4<f32> {\n  return value.tint;\n}\n",
    },
  ]

  composer.clear_sources()
  composer.register_source_files(files)

  debug_inspect(
    composer.registered_source("shaders/effects/main.wgsl") is Some(_),
    content="true",
  )
  let compose_options : @common.WgslComposeOptions = {
    defines,
    value_defines: @common.default_wgsl_value_defines(),
    redirects,
    additional_imports: [],
  }
  let composed : String = composer.compose_wgsl(
    "shaders/effects/main.wgsl", compose_options,
  ) catch {
    _ => abort("compose failed")
  }
  debug_inspect(composed.contains("struct SharedValue"), content="true")
}
```

If you want collision diagnostics before mutating the registry, use the checked
path:

```mbt check
///|
test "README: checked bulk registry" {
  let files : Array[@common.WgslSourceFile] = [
    {
      rel_path: "shaders/demo/a.wgsl",
      source: "#define_import_path demo::dup\nfn a() -> f32 { return 1.0; }\n",
    },
    {
      rel_path: "shaders/demo/b.wgsl",
      source: "#define_import_path demo::dup\nfn b() -> f32 { return 2.0; }\n",
    },
  ]

  let registry = @resolver.WgslSourceRegistry::default()
  let diagnostics : Array[@common.WgslDiagnostic] = registry.analyze_source_files(
    files,
  )
  debug_inspect(diagnostics.length(), content="1")

  let checked_diagnostics : Array[@common.WgslDiagnostic] = []
  registry.register_source_files_checked(files, checked_diagnostics)
  debug_inspect(checked_diagnostics.length(), content="1")
}
```

### 5. Scanning a WGSL Source Tree

If your shaders already live on disk, use `scan_wgsl_source_files` or the
Composer convenience helpers built on top of `moonbitlang/x/fs`.

Scanned `rel_path` values are relative to the scan root, so scanning
`assets/shaders` yields registry keys such as `effects/main.wgsl`.

```mbt check
///|
test "README: scan source tree" {
  let composer : @compose.Composer = @compose.Composer::default()
  let defines : @hashmap.HashMap[String, Bool] = @hashmap.HashMap::new()
  let redirects : Array[@common.WgslSymbolRedirect] = []
  let scan_options : @common.WgslSourceScanOptions = {
    recursive: true,
    extensions: [".wgsl"],
    exclude_prefixes: ["ignored"],
  }

  composer.clear_sources()
  composer.register_source_tree("testdata/wgsl_scan", scan_options) catch {
    _ => abort("failed to scan WGSL shader tree")
  }

  let compose_options : @common.WgslComposeOptions = {
    defines,
    value_defines: @common.default_wgsl_value_defines(),
    redirects,
    additional_imports: [],
  }
  let composed : String = composer.compose_wgsl(
    "effects/main.wgsl", compose_options,
  ) catch {
    _ => abort("compose failed")
  }

  debug_inspect(composed.contains("fn shade"), content="true")
}
```

If you want to preflight a tree before registration, use the checked scan path:

```mbt check
///|
test "README: checked tree scan" {
  let (files, diagnostics) = @resolver.scan_wgsl_source_files_checked(
    "testdata/wgsl_scan_dups",
    @common.WgslSourceScanOptions::default(),
  ) catch {
    _ => abort("failed to scan WGSL shader tree")
  }

  debug_inspect(files.length(), content="2")
  debug_inspect(diagnostics.length(), content="1")
}
```

### 6. Exporting a Single WGSL File

Use `export_wgsl_with_options` to produce a fully expanded
single-file WGSL output. The export path also supports declaration-level
tree-shaking and returns source-map entries, the dependency-closure source
catalog used for matching, plus diagnostics.

```mbt check
///|
test "README: export single WGSL file" {
  let composer : @compose.Composer = @compose.Composer::default()
  let defines : @hashmap.HashMap[String, Bool] = @hashmap.HashMap::new()
  let redirects : Array[@common.WgslSymbolRedirect] = []
  let files : Array[@common.WgslSourceFile] = [
    {
      rel_path: "shaders/shared/common.wgsl",
      source: "struct SharedParams {\n  tint: vec4<f32>,\n}\nstruct SharedVertex {\n  params: SharedParams,\n}\nfn build_color(vertex: SharedVertex) -> vec4<f32> {\n  return vertex.params.tint;\n}\n",
    },
    {
      rel_path: "shaders/effects/main.wgsl",
      source: "#import \"../shared/common.wgsl\" SharedVertex, build_color\nfn shade(vertex: SharedVertex) -> vec4<f32> {\n  return build_color(vertex);\n}\n",
    },
  ]

  composer.clear_sources()
  composer.register_source_files(files)

  let compose_options : @common.WgslComposeOptions = {
    defines,
    value_defines: @common.default_wgsl_value_defines(),
    redirects,
    additional_imports: [],
  }
  let export_options : @common.WgslExportOptions = { root_items: ["shade"] }
  let exported : @common.WgslExportOutput = @export.export_wgsl_with_options(
    composer, "shaders/effects/main.wgsl", compose_options, export_options,
  ) catch {
    _ => abort("export failed")
  }

  debug_inspect(exported.source.contains("#import"), content="false")
  debug_inspect(exported.source_catalog.length() > 0, content="true")
  debug_inspect(exported.source_map.length() > 0, content="true")
  debug_inspect(exported.diagnostics.length(), content="0")
}
```

If you need the declaration catalog directly, without exporting a specific
entrypoint, use `build_wgsl_source_catalog` on the same Composer:

```mbt check
///|
test "README: build source catalog" {
  let composer : @compose.Composer = @compose.Composer::default()
  let defines : @hashmap.HashMap[String, Bool] = @hashmap.HashMap::new()
  let redirects : Array[@common.WgslSymbolRedirect] = []
  let files : Array[@common.WgslSourceFile] = [
    {
      rel_path: "shaders/shared/common.wgsl",
      source: "struct SharedParams {\n  tint: vec4<f32>,\n}\nstruct SharedVertex {\n  params: SharedParams,\n}\nfn build_color(vertex: SharedVertex) -> vec4<f32> {\n  return vertex.params.tint;\n}\n",
    },
    {
      rel_path: "shaders/effects/main.wgsl",
      source: "#import \"../shared/common.wgsl\" SharedVertex, build_color\nfn shade(vertex: SharedVertex) -> vec4<f32> {\n  return build_color(vertex);\n}\n",
    },
  ]

  composer.clear_sources()
  composer.register_source_files(files)

  let compose_options : @common.WgslComposeOptions = {
    defines,
    value_defines: @common.default_wgsl_value_defines(),
    redirects,
    additional_imports: [],
  }
  let prepared = composer.prepare_wgsl_source(
    "shaders/effects/main.wgsl", compose_options,
  ) catch {
    err => abort("expected prepare success: \{err.message()}")
  }
  let catalog : Array[@common.WgslSourceCatalogEntry] = prepared.source_catalog
  debug_inspect(catalog.length() > 0, content="true")
}
```

### 7. Applying Source-Level Redirects

Use the redirect-aware APIs when you want to remap one imported symbol to
another during composition/export without depending on Naga IR.

```mbt check
///|
test "README: source-level redirects" {
  let composer : @compose.Composer = @compose.Composer::default()
  let defines : @hashmap.HashMap[String, Bool] = @hashmap.HashMap::new()
  let redirects : Array[@common.WgslSymbolRedirect] = [
    { from_name: "build_shadow", to_name: "build_color" },
  ]
  let files : Array[@common.WgslSourceFile] = [
    {
      rel_path: "shaders/shared/common.wgsl",
      source: "struct SharedParams {\n  tint: vec4<f32>,\n}\nstruct SharedVertex {\n  params: SharedParams,\n}\nfn build_color(vertex: SharedVertex) -> vec4<f32> {\n  return vertex.params.tint;\n}\nfn build_shadow(vertex: SharedVertex) -> vec4<f32> {\n  return vec4<f32>(0.0, 0.0, 0.0, 1.0);\n}\n",
    },
    {
      rel_path: "shaders/effects/redirect.wgsl",
      source: "#import \"../shared/common.wgsl\" SharedVertex, build_color, build_shadow\nfn shade(vertex: SharedVertex) -> vec4<f32> {\n  return build_shadow(vertex);\n}\n",
    },
  ]

  composer.clear_sources()
  composer.register_source_files(files)

  let compose_options : @common.WgslComposeOptions = {
    defines,
    value_defines: @common.default_wgsl_value_defines(),
    redirects,
    additional_imports: [],
  }
  let export_options : @common.WgslExportOptions = { root_items: ["shade"] }
  let exported : @common.WgslExportOutput = @export.export_wgsl_with_options(
    composer, "shaders/effects/redirect.wgsl", compose_options, export_options,
  ) catch {
    _ => abort("redirect export failed")
  }

  debug_inspect(exported.source.contains("build_shadow"), content="false")
  debug_inspect(exported.source.contains("build_color"), content="true")
}
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
- `@metadata.get_preprocessor_metadata`
  Returns a rich metadata object for a shader source string.
- `WgslSourceRegistry::register_source` / `WgslSourceRegistry::registered_source`
  Manage an explicit WGSL source registry value.
- `Composer::register_source` / `Composer::register_source_files`
  Manage a Composer-owned WGSL source registry for hermetic composition.
- `Composer::compose_wgsl`
  Composes WGSL from Composer-owned registry state and `WgslComposeOptions`.
- `WgslSourceRegistry::register_source_files`
  Registers a batch of WGSL source files into an explicit registry.
- `WgslSourceRegistry::analyze_source_files`
  Performs preflight validation for duplicate module names and rel-path
  ownership conflicts.
- `WgslSourceRegistry::register_source_files_checked`
  Runs preflight registry diagnostics and only mutates registry state when no
  errors are reported.
- `build_wgsl_source_catalog`
  Returns the declaration catalog for a prepared dependency closure.
- `WgslSourceRegistry::copy_import_module_paths` /
  `resolve_wgsl_import_module_in_registry`
  Build and query module-path resolution data for an explicit registry.
- `resolve_wgsl_import_file_path_from_registry`
  Resolves relative or quoted file-path imports against a source file path.
- `rewrite_wgsl_symbol_redirects`
  Applies token-based source-level symbol redirects to WGSL source from the
  `analysis` package.
- `Composer::compose_wgsl_source`
  Composes a raw WGSL source string using `WgslComposeOptions` without exposing
  session internals.
- `Composer::prepare_wgsl_source`
  Produces a stable `PreparedWgslSource` intermediate for tools such as
  single-file export.
- `export_wgsl_with_options`
  Produces single-file WGSL from `WgslComposeOptions` without depending on
  compose session internals.

Important public data structures:

- `ShaderDefValue`
- `ImportDefinition`
- `PreprocessOutput`
- `PreprocessorMetaData`
- `PreparedWgslSource`
- `ComposableModuleDescriptor`
- `ComposableModuleDefinition`
- `WgslDirectives`
- `WgslSourceFile`
- `WgslComposeOptions`
  Holds root compose settings: shader defs, value defs, symbol redirects, and
  root-only `additional_imports`.
- `WgslSymbolRedirect`
- `WgslExportOptions`
- `WgslExportOutput`
- `WgslSourceCatalogEntry`
- `WgslSourceMapEntry`
- `WgslDiagnostic`

For the full exported surface, see the generated subpackage interfaces:
`common/pkg.generated.mbti`, `ast/pkg.generated.mbti`,
`parser/pkg.generated.mbti`, `metadata/pkg.generated.mbti`, `preprocess/pkg.generated.mbti`,
`resolver/pkg.generated.mbti`, `analysis/pkg.generated.mbti`,
`semantic/pkg.generated.mbti`, `virtual_overrides/pkg.generated.mbti`,
`writeback/pkg.generated.mbti`, `compose/pkg.generated.mbti`, and
`export/pkg.generated.mbti`.

## Behavior Notes

- `#define_import_path` is used as the canonical module name for composition.
- `Composer` now owns registry/module resolution state; new code should prefer
  `Composer::register_source*`, `Composer::compose_wgsl`,
  `Composer::compose_wgsl_source`, and `export_wgsl_with_options`.
- `Composer::default()` is hermetic and starts with an empty registry.
- Relative quoted file imports are resolved against the importing shader's
  registered path in the active Composer registry.
- `register_source_files_checked` is the safe bulk-registration path when
  callers need deterministic diagnostics before mutating a Composer registry.
- `@metadata.get_preprocessor_metadata` is strict like upstream naga_oil and
  raises `MetadataError` when directive or import metadata is invalid.
- `Preprocessor::preprocess` is the strict path and raises `PreprocessError`
  when parsing or conditional evaluation fails.
- `export_wgsl_with_options` scopes `source_catalog` and
  `source_map` to the dependency closure of the current compose/export
  preparation result instead of the full registry.
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
