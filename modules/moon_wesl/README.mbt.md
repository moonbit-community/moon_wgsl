# moon_wesl

`Milky2018/moon_wesl` is a MoonBit library and baseline CLI for compiling WESL
shader modules into one emitted source string.

This package was extracted from `mgstudio` and preserves the former
`mgstudio/wesl` root-package surface for downstream users. The public API is
intentionally small and centered on:

- `ModulePath` for module naming and relative import semantics
- `Resolver` for loading source from any backing store
- `EscapeMangler` for turning module-local names into emitted global symbols
- `CompileOptions` for import resolution, stripping, lowering, and feature flags
- `compile(...)` and `Wesl::build_artifact(...)` as the main entry points

## Features

- Resolves WESL `import` statements across modules
- Supports `@publish import ...` re-exports
- Evaluates `@if(...)`, `@else if (...)`, and `@else` conditional blocks
- Strips unused declarations, rooted at shader entry points or explicit keep
  lists
- Optionally lowers top-level `alias` and `const` declarations into plain
  emitted code
- Delegates official WGSL parsing and semantic validation of emitted source to
  `Milky2018/wgsl`; WESL itself owns only extension and assembly semantics
- Lets callers provide source code from memory, files, asset systems, or editor
  buffers through the `Resolver` trait
- Provides a `cmd/wesl` command with `check`, `compile`, `eval`, `exec`, and
  `package` subcommands aligned to the upstream `wesl-rs` command matrix

## Install

Add the module dependency first:

```bash
moon add Milky2018/moon_wesl
```

Then import the package in `moon.pkg`:

```text
import {
  "Milky2018/moon_wesl",
}
```

## Quick Start

```mbt check
///|
test {
  let resolver = @moon_wesl.VirtualResolver::new()
  let util_path = @moon_wesl.ModulePath::from_path("/shaders/util.wesl")
  let root_path = @moon_wesl.ModulePath::from_path(
    "/shaders/custom_material.wesl",
  )

  resolver.add_module(
    util_path, "fn make_polka_dots(v: f32) -> f32 {\n  @if(PARTY_MODE) {\n    return v * 2.0;\n  } @else {\n    return v;\n  }\n}\n",
  )
  resolver.add_module(
    root_path, "import super::util::make_polka_dots;\n@fragment\nfn fragment(v: f32) -> f32 {\n  return make_polka_dots(v);\n}\n",
  )

  let options = @moon_wesl.CompileOptions::default()
    .with_lower(true)
    .with_feature("PARTY_MODE", true)

  let result = try! @moon_wesl.compile(
    root_path,
    resolver,
    @moon_wesl.EscapeMangler::default(),
    options,
  )
  inspect(result.to_string().contains("@fragment"), content="true")
}
```

The result contains the final emitted syntax tree in `result.syntax`; call
`result.to_string()` for the WGSL text. Loaded module order is available in
`result.modules`.

For build-script style workflows, `CompileResult::write_artifact(...)` and
`Wesl::build_artifact(...)` write `<artifact>.wgsl` into `OUT_DIR` by default,
matching the upstream `include_wesl!` artifact convention. Tests and MoonBit
build tools can pass an explicit `out_dir`.

## Core Concepts

### `ModulePath`

`ModulePath` models the Bevy-style module naming scheme used by WESL imports.
You can construct one from a filesystem-like path or parse the textual WESL
form directly.

Examples:

- `ModulePath::from_path("/shaders/custom_material.wesl")` ->
  `package::shaders::custom_material`
- `ModulePath::from_path("./util.wesl")` -> `self::util`
- `ModulePath::from_path("../shared/noise.wesl")` ->
  `super::shared::noise`
- `parse_module_path("package::shaders::util")`

`ModulePath::join_path(...)` applies relative-import semantics, so a parent
module can resolve `self::...` and `super::...` child paths without duplicating
that logic in callers.

### `Resolver`

The compiler itself is storage-agnostic. It only requires a type that can map a
`ModulePath` to source text:

```mbt check
///|
pub(open) trait Resolver {
  fn resolve_source(Self, @moon_wesl.ModulePath) -> String raise @moon_wesl.ResolveError
}
```

The library ships with `VirtualResolver`, an in-memory implementation that is
useful for tests, generated modules, editor integrations, and asset pipelines.

If you need to load shaders from disk, a game asset database, or another source
of truth, implement `Resolver` in your own package and use
`ModulePath::to_path_string()` to map module names back to your storage format.

### `EscapeMangler`

WESL modules are emitted into a flat output string, so imported declarations
need stable global names. `EscapeMangler` converts `(module path, item name)`
into emitted identifiers that preserve origin information and avoid collisions.

By default, declarations in the root module keep their original names.
Dependencies are mangled automatically. Call `with_mangle_root(true)` if you
want the root module to be mangled as well.

## Compilation Model

`compile(...)` performs four main steps:

1. Load the root module through `Resolver` and parse top-level items and
   imports.
2. Recursively resolve imports and compute the reachable declaration set.
3. Emit modules in dependency order while rewriting imported identifiers to
   mangled global names.
4. Optionally lower top-level `alias` and `const` declarations with
   `with_lower(true)`.

When stripping is enabled, the root set is determined by:

- functions annotated with `@fragment`, `@vertex`, or `@compute`
- any declarations named by `keep_declarations(...)`
- all root declarations if `with_keep_root(true)` is enabled

`const_assert` items are also scanned so their referenced declarations remain
reachable.

## `CompileOptions`

`CompileOptions::default()` returns:

- `imports = true`
- `condcomp = true`
- `strip = true`
- `lower = false`
- `lazy_resolution = true`
- `mangle_root = false`
- `keep_root = false`
- `keep = None`
- `features = {}`

Option behavior:

| Option | Default | Meaning |
| --- | --- | --- |
| `with_imports(Bool)` | `true` | Parse and resolve import statements. If disabled, import declarations are ignored instead of resolved. |
| `with_condcomp(Bool)` | `true` | Evaluate `@if` / `@else if` / `@else` blocks using the `features` map. |
| `with_strip(Bool)` | `true` | Emit only reachable declarations instead of the full transitive module closure. |
| `with_lower(Bool)` | `false` | Remove top-level `alias` and `const` declarations by textual substitution. |
| `with_lazy(Bool)` | `true` | When stripping is enabled, avoid eagerly loading imports that are never used. |
| `with_mangle_root(Bool)` | `false` | Mangle declarations from the root module too. |
| `with_keep_root(Bool)` | `false` | Keep every declaration in the root module when stripping is enabled. |
| `keep_declarations(Array[String])` | `None` | Keep a specific set of root declarations even if they are not entry points. |
| `with_feature(String, Bool)` | `{}` | Set a feature flag used by conditional compilation. |

## Re-exports and Visibility

The compiler distinguishes between ordinary imports and public re-exports:

- `import super::util::foo;` makes `foo` available only inside the current
  module
- `@publish import super::util::foo;` allows other modules to import `foo`
  through the current module

Attempting to re-export a private import raises `WeslCompileError::Private`.
Missing symbols raise `WeslCompileError::MissingDecl`, and missing modules are
reported through `WeslCompileError::Resolve(...)`.

## Errors

The public error surface is:

- `ModulePathParseError` for invalid textual module paths
- `ResolveError` for source-loading failures
- `WeslCompileError` for compile-time failures, including:
  - parse errors in WESL source
  - invalid conditional expressions
  - duplicate local declarations or import aliases
  - missing declarations in imported modules
  - private re-export attempts

Each error type exposes `message()` for user-facing diagnostics.

## CLI

The repository includes a MoonBit-native `wesl` command package:

```bash
moon run cmd/wesl -- compile --base src/shaders src/shaders/main.wesl
moon run cmd/wesl -- check --kind wesl src/shaders/main.wesl
moon run cmd/wesl -- eval "abs(3 - 5)"
moon run cmd/wesl -- eval --binary "42u"
moon run cmd/wesl -- exec src/shaders/main.wesl
moon run cmd/wesl -- package shader-lib src/shaders/lib
```

The `compile` command supports the upstream option shape for mangling,
conditional compilation, stripping, lowering, validation toggles, keep lists,
feature flags, and base-directory selection. `package` emits the same
MoonBit-native codegen artifact produced by `PkgBuilder`. `eval --binary`
emits little-endian scalar and vector buffers for storable `i32`, `u32`, and
`f32` const-eval results and rejects non-storable values such as `bool`. `exec`
can run a minimal entrypoint whose return expression fits the current
const-evaluator, including zero-initialized builtin entrypoint inputs,
user-defined `@location` inputs passed through `Inputs.user_defined`, scalar
pipeline overrides, scalar/vector/struct/array/matrix uniform/storage resource
buffers, field/index/component storage resource writeback through
`ExecResult::resource`, and matching `--out-binary` return output for storable
values. The
current evaluator applies basic vector arithmetic, comparisons, `clamp`, `min`,
`max`, `abs`, `select`, `all`, and `any` component-wise, supports struct member
access, WGSL `xyzw` / `rgba` vector swizzles, vector/array/matrix indexing,
`arrayLength(&runtime_array)` for storage buffers whose runtime length is
inferred from input bytes,
basic `if` / `else` branches, and `while`, `for`, `loop`, and `switch` control
flow with local assignment, `break`, `continue`, `continuing`, and `break if`,
and uses WGSL
memory layout for scalar/vector, struct member, array stride, and matrix column
padding. Pointer-style writes, atomics, textures, and the full arbitrary shader
control-flow model still require the broader CPU execution layer.

## Scope and Current Behavior

This package currently focuses on the mechanics required to compose WESL
modules:

- module-path resolution
- import parsing
- public re-export handling
- conditional compilation
- reachability-based stripping
- symbol mangling
- simple lowering of top-level aliases and constants
- scalar/vector `EvalResult::to_buffer()` for `i32`, `u32`, and `f32`
- minimal CPU execution for simple entrypoints, including scalar pipeline
  overrides, builtin and user-defined `@location` input parameters, struct
  field reads, vector swizzles, vector/array/matrix indexing, basic `if` /
  `else` and `while` control flow, `for` loops, `loop`/`continuing`/`break if`,
  `switch` selection, scalar/vector/struct/array/matrix resource buffers, and
  runtime array length queries, field/index/component storage resource
  writeback, and return buffers
- filesystem package scanning and artifact generation
- baseline CLI compile/check/eval/exec/package workflows

The parser and syntax layer are materially richer than the original
text-oriented implementation, but this package is still not a full source-level
port of `wgsl-parse`, `wgsl-types`, semantic lowering, or the complete CPU
execution model.

## Design Constraints

`moon_wesl` is intended to remain a pure computation library:

- no runtime dependency on graphics backends or platform SDKs
- no requirement to embed or link `wgpu`, GPU drivers, window systems, or
  engine-specific runtimes
- no platform-coupled execution model in the core package

Vendored Bevy and WGPU fixtures in the test suite are treated as compatibility
corpora only. They are used to improve parser, compiler, and validation
behavior, not as a signal that this package should depend on Bevy, WGPU, or
any other platform/runtime integration layer.

## Repository Layout

- [compile.mbt](./compile.mbt): main compiler pipeline
- [path.mbt](./path.mbt): module-path parsing and joining
- [resolve.mbt](./resolve.mbt): `Resolver` abstraction and `VirtualResolver`
- [mangle.mbt](./mangle.mbt): emitted-name mangling
- [wesl_test.mbt](./wesl_test.mbt): black-box tests covering the public API

## Development

Useful commands while working on the library:

```bash
moon test -v
moon info
moon fmt
```

## License

Apache-2.0.
