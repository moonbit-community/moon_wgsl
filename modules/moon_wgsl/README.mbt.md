# Milky2018/moon_wgsl

User-facing facade for WGSL preprocessing and composition.

Install this module when your application wants naga-oil-style shader
preprocessing without importing internal parser, IR, writer, or rewrite
packages directly.

`Composer` is facade-owned and opaque. Its complete workflow is deliberately
small: register sources/modules, prepare, compose, and export. Internal
preprocessing stages, Compose graphs, semantic IR, writer plans, and parity
entry points are not methods on this type. Tooling that needs those details
imports `Milky2018/moon_wgsl_naga_oil/diagnostics` explicitly.

The implementation delegates to:

- `Milky2018/wgsl` for WGSL parsing, IR, and validation
- `Milky2018/moon_wgsl_naga_oil` for preprocessing and composition

Legacy internal package paths from the old single-module layout are not
preserved. Import lower-level modules explicitly when you need their ownership
boundary.

`WgslComposeOptions::default()` contains no project-specific shader values.
Use `bevy_wgsl_value_defines()` explicitly when composing Bevy shaders.

For a source that uses a backend-specific `var<immediate>` struct global, add
a structured specialization to the compose options. It names the source and
global declaration before import linking and must provide every struct field:

```mbt check
///|
test "configure an immediate specialization" {
  let options = {
    ..WgslComposeOptions::default(),
    immediate_specializations: [
      WgslImmediateSpecialization("root.wgsl", "constants", {
        "max_mip_level": UInt(12),
      }),
    ],
  }
  assert_eq(options.immediate_specializations.length(), 1)
}
```

Composition lowers the declaration to a concrete WGSL `const`; callers do not
need to patch the emitted shader text.

```mbt check
///|
test "compose a shader through the facade" {
  let composer = Composer::default()
  let util_source =
    #|#define_import_path test::util
    #|
    #|fn value() -> u32 {
    #|  return 1u;
    #|}
    #|
  composer.register_source("util.wgsl", util_source)
  let root_source =
    #|#import test::util::value
    #|
    #|fn root() -> u32 {
    #|  return value();
    #|}
    #|
  composer.register_source("root.wgsl", root_source)
  let source = composer.compose("root.wgsl", WgslComposeOptions::default())
  assert_true(source.contains("fn root"))
}
```
