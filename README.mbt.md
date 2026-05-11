# moon_wgsl

`Milky2018/moon_wgsl` is a MoonBit library for composing WGSL shader modules
with `naga_oil`-style preprocessing and imports.

Use it when your shaders contain directives such as `#define_import_path`,
`#ifdef`, `#define`, and `#import`, and you want to resolve them from MoonBit
without adding a separate shader build step.

## Install

Add the package from Mooncakes, then import the subpackages you need:

```mbt check
///|
test "README: package is available" {
  let value_defines = @common.default_wgsl_value_defines()
  debug_inspect(value_defines.length() > 0, content="true")
}
```

Most users only need these packages:

- `@common` for shared option and result types
- `@metadata` for inspecting directives and imports
- `@preprocess` for evaluating one shader source
- `@resolver` for source registries and source-tree scanning
- `@compose` for module composition
- `@export` for single-file export

## Features

- Conditional preprocessing: `#ifdef`, `#ifndef`, `#if`, `#else if`, `#else`,
  and `#endif`
- Shader definition values: bools, signed integers, unsigned integers, and raw
  WGSL text values
- Grouped, aliased, and quoted-path imports
- Composer-owned source registries for hermetic composition
- Optional source-tree scanning through `moonbitlang/x/fs`
- Single-file WGSL export with source catalog, source map, provenance, and
  diagnostics

## Quick Start

### Compose Modules

Register WGSL source strings on a `Composer`, then compose the root shader.

```mbt check
///|
test "README: compose registered modules" {
  let composer : @compose.Composer = @compose.Composer::default()
  composer.clear_sources()

  composer.register_source(
    "maths.wgsl",
    "#define_import_path demo::maths\nconst TWO: f32 = 2.0;\n",
  )
  composer.register_source(
    "main.wgsl",
    "#import demo::maths::TWO\nfn scale(x: f32) -> f32 {\n  return x * TWO;\n}\n",
  )

  let options : @common.WgslComposeOptions = @common.WgslComposeOptions::default()
  let composed = composer.compose_wgsl("main.wgsl", options) catch {
    err => abort(err.message())
  }

  debug_inspect(composed.contains("fn scale"), content="true")
  debug_inspect(composed.contains("#import"), content="false")
}
```

### Preprocess One Shader

Use `Preprocessor::preprocess` when you only need conditional compilation and
shader-definition substitution for a single source string.

```mbt check
///|
test "README: preprocess one shader" {
  let defs : @hashmap.HashMap[String, @common.ShaderDefValue] = @hashmap.HashMap([])
  defs.set("TEXTURE", @common.ShaderDefValue::Bool(true))

  let source = "#ifdef TEXTURE\nvar sprite_texture: texture_2d<f32>;\n#else\nvar sprite_texture: texture_2d_array<f32>;\n#endif\n"
  let output = @preprocess.Preprocessor::default().preprocess(source, defs) catch {
    _ => abort("preprocess failed")
  }

  debug_inspect(
    output.preprocessed_source.contains("texture_2d<f32>"),
    content="true",
  )
}
```

### Read Metadata

Use metadata extraction when you want to inspect a shader before composing it.

```mbt check
///|
test "README: inspect metadata" {
  let source = "#define_import_path demo::main\n#define HDR\n#import demo::maths::TWO\nfn scale(x: f32) -> f32 {\n  return x * TWO;\n}\n"
  let metadata = @metadata.get_preprocessor_metadata(source) catch {
    _ => abort("metadata extraction failed")
  }

  debug_inspect(metadata.name, content="Some(\"demo::main\")")
  debug_inspect(metadata.imports.length(), content="1")
}
```

### Export One File

Use `export_wgsl_with_options` to compose and tree-shake a root shader into one
WGSL file.

```mbt check
///|
test "README: export single file" {
  let composer : @compose.Composer = @compose.Composer::default()
  composer.clear_sources()
  composer.register_source(
    "shared.wgsl",
    "#define_import_path demo::shared\nstruct Value {\n  x: f32,\n}\nfn read(value: Value) -> f32 {\n  return value.x;\n}\n",
  )
  composer.register_source(
    "main.wgsl",
    "#import demo::shared::{Value, read}\nfn shade(value: Value) -> f32 {\n  return read(value);\n}\n",
  )

  let compose_options : @common.WgslComposeOptions = @common.WgslComposeOptions::default()
  let export_options : @common.WgslExportOptions = { root_items: ["shade"] }
  let output = @export.export_wgsl_with_options(
    composer,
    "main.wgsl",
    compose_options,
    export_options,
  ) catch {
    err => abort(err.message())
  }

  debug_inspect(output.source.contains("#import"), content="false")
  debug_inspect(output.source.contains("fn shade"), content="true")
  debug_inspect(output.diagnostics.length(), content="0")
}
```

## Import Syntax

The supported import forms match common `naga_oil` usage:

```wgsl
#import bevy_render::view::View
#import bevy_render::maths as maths
#import bevy_render::{view::View, globals::Globals}
#import bevy_render::{maths::{PI_2, powsafe}}
#import "shaders/skills/shared.wgsl" Vertex, VertexOutput
#import "../shared/common.wgsl" SharedVertex, build_color
```

Relative quoted imports are resolved against the registered path of the
importing shader.

## Recommended APIs

- `@compose.Composer::default`
- `Composer::register_source`
- `Composer::register_source_files`
- `Composer::register_source_tree`
- `Composer::compose_wgsl`
- `@preprocess.Preprocessor::default`
- `Preprocessor::preprocess`
- `@metadata.get_preprocessor_metadata`
- `@resolver.scan_wgsl_source_files`
- `@resolver.scan_wgsl_source_files_checked`
- `@export.export_wgsl_with_options`

Important option/result types live in `@common`, including:

- `WgslComposeOptions`
- `WgslExportOptions`
- `WgslSourceFile`
- `WgslSourceScanOptions`
- `PreprocessOutput`
- `PreprocessorMetaData`
- `PreparedWgslSource`
- `WgslExportOutput`
- `WgslDiagnostic`
- `ShaderDefValue`

## Compatibility

The library aims to preserve the practical `naga_oil` programming model used by
real shader pipelines. Internally, composition uses structured parsing,
symbol-identity-aware binding, and an IR-backed validation pipeline before
returning runtime-oriented WGSL.

For implementation details and parity status, see:

- [`docs/naga_oil-parity.md`](docs/naga_oil-parity.md)
- [`docs/moon_wgsl-issue-tracker.md`](docs/moon_wgsl-issue-tracker.md)

## Development

Run the test suite from the module root:

```bash
moon test
```

## License

Apache-2.0
