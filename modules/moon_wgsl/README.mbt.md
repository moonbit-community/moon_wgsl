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
