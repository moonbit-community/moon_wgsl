# Milky2018/moon_wgsl

Thin user-facing facade for WGSL preprocessing and composition.

Install this module when your application wants naga-oil-style shader
preprocessing without importing internal parser, IR, writer, or rewrite
packages directly.

The facade depends on:

- `Milky2018/wgsl` for WGSL parsing, IR, and validation
- `Milky2018/moon_wgsl_naga_oil` for preprocessing and composition

Legacy internal package paths from the old single-module layout are not
preserved. Import lower-level modules explicitly when you need their ownership
boundary.

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
  let source = composer.compose_wgsl("root.wgsl", WgslComposeOptions::default())
  assert_true(source.contains("fn root"))
}
```
