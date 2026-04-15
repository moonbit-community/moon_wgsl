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
- Preserves and re-emits WGSL `enable`, `requires`, and `diagnostic(...)`
  directives.
- Tracks only actually used imported items when extracting metadata.
- Resolves composable modules from registered WGSL source strings.
- Exports single-file WGSL with declaration-level tree-shaking, source-map
  entries, and diagnostics.

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

The important implementation detail is that module resolution is currently
registry-based: shaders must be registered first with `register_wgsl_source`.

```moonbit
import "Milky2018/moon_wgsl"
import "moonbitlang/core/hashmap"

@moon_wgsl.clear_registered_wgsl_source_registry()

@moon_wgsl.register_wgsl_source(
  "render/maths.wgsl",
  "#define_import_path bevy_render::maths\nconst PI_2: f32 = 6.28318;\n",
)

@moon_wgsl.register_wgsl_source(
  "sprite_render/mesh2d/mesh2d_functions.wgsl",
  "#define_import_path bevy_sprite::mesh2d_functions\n#import bevy_render::maths::PI_2\nfn twice_pi() -> f32 {\n  return PI_2;\n}\n",
)

@moon_wgsl.register_wgsl_source(
  "sprite_render/mesh2d/mesh2d.wgsl",
  "#import bevy_sprite::mesh2d_functions as mesh_functions\nfn demo() -> f32 {\n  return mesh_functions::twice_pi();\n}\n",
)

let defines : @hashmap.HashMap[String, Bool] = @hashmap.HashMap::new()
let value_defines = @moon_wgsl.default_wgsl_value_defines()
let visited : @hashmap.HashMap[String, Bool] = @hashmap.HashMap::new()
let modules = @moon_wgsl.copy_registered_wgsl_import_module_paths()

let composed = @moon_wgsl.Composer::default().load_wgsl_preprocessed(
  "",
  "sprite_render/mesh2d/mesh2d.wgsl",
  defines,
  value_defines,
  visited,
  modules,
) catch {
  err => abort(err.message())
}

inspect(composed.contains("const PI_2"))
inspect(composed.contains("return twice_pi();"))
```

### 4. Bulk Registry and Relative File Imports

You can register a batch of shader files at once and use relative quoted paths
between them.

```moonbit
import "Milky2018/moon_wgsl"

@moon_wgsl.clear_registered_wgsl_source_registry()
@moon_wgsl.register_wgsl_source_files([
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
  @moon_wgsl.resolve_wgsl_import_file_path(
    "shaders/effects/main.wgsl",
    "\"../shared/common.wgsl\"",
  ),
)
```

### 5. Exporting a Single WGSL File

Use `Composer::export_wgsl` to produce a fully expanded single-file WGSL output.
The export path also supports declaration-level tree-shaking and returns
best-effort source map entries plus diagnostics.

```moonbit
import "Milky2018/moon_wgsl"
import "moonbitlang/core/hashmap"

let defines : @hashmap.HashMap[String, Bool] = @hashmap.HashMap::new()
let value_defines = @moon_wgsl.default_wgsl_value_defines()
let modules = @moon_wgsl.copy_registered_wgsl_import_module_paths()

let exported = @moon_wgsl.Composer::default().export_wgsl(
  "",
  "shaders/effects/main.wgsl",
  defines,
  value_defines,
  modules,
  { root_items: ["shade"] },
) catch {
  err => abort(err.message())
}

inspect(exported.source.contains("#import"))
inspect(exported.source_map.length())
inspect(exported.diagnostics.length())
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
  Loads and recursively composes registered WGSL shader modules.
- `get_preprocessor_metadata`
  Returns a rich metadata object for a shader source string.
- `get_preprocessor_data`
  Returns the simplified `(name, imports, defines)` tuple.
- `register_wgsl_source` / `registered_wgsl_source`
  Manage the in-memory WGSL source registry.
- `register_wgsl_source_files`
  Registers a batch of WGSL source files and extracts module names
  automatically.
- `build_wgsl_import_module_paths` / `resolve_wgsl_import_module`
  Build and query module-path resolution data.
- `resolve_wgsl_import_file_path`
  Resolves relative or quoted file-path imports against a source file path.
- `Composer::export_wgsl`
  Produces single-file WGSL plus source-map entries and diagnostics.

Important public data structures:

- `ShaderDefValue`
- `ImportDefinition`
- `PreprocessOutput`
- `PreprocessorMetaData`
- `ComposableModuleDescriptor`
- `ComposableModuleDefinition`
- `WgslDirectives`
- `WgslSourceFile`
- `WgslExportOptions`
- `WgslExportOutput`
- `WgslSourceMapEntry`
- `WgslDiagnostic`

For the full exported surface, see
[pkg.generated.mbti](./pkg.generated.mbti).

## Behavior Notes

- `#define_import_path` is used as the canonical module name for composition.
- `Composer::load_wgsl_preprocessed` resolves imports through registered
  sources, not by scanning directories on disk.
- Relative quoted file imports are resolved against the importing shader's
  registered path.
- `assets_base` is still present in the API for compatibility, but current
  source resolution is driven by the registry.
- `get_preprocessor_metadata` is forgiving by design: on parse failure it
  returns empty/default metadata instead of raising.
- `Preprocessor::preprocess` is the strict path and raises `PreprocessError`
  when parsing or conditional evaluation fails.
- `Composer::export_wgsl` returns declaration-level source-map entries on a
  best-effort basis; ambiguous matches are reported as diagnostics instead of
  hard errors.

## Development

Run the test suite from the module root:

```bash
moon test
```

The repository currently includes tests for:

- metadata extraction
- grouped and aliased imports
- quoted relative file imports
- WGSL directive preservation
- conditional preprocessing semantics
- module registration and import resolution
- recursive composition behavior
- single-file WGSL export with tree-shaking and diagnostics

## Compatibility Goal

This package aims to preserve the practical `naga_oil` programming model used
by existing downstream shader pipelines. The tests intentionally exercise
behavior that matches upstream usage patterns from the original extraction
context.

## License

Apache-2.0
