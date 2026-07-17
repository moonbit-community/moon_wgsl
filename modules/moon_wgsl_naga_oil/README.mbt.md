# Milky2018/moon_wgsl_naga_oil

naga-oil-compatible preprocessing and composition for MoonBit WGSL.

This module owns:

- shader definition evaluation
- `#ifdef`, `#define`, and directive preprocessing
- `#define_import_path` and `#import` metadata
- public preprocess/compose/import/export contracts in `contract`
- explicit project profiles such as `profile::bevy_wgsl_value_defines`
- source registries and module resolution
- symbol-bound composition and export

It depends on `Milky2018/wgsl` for syntax/IR validation and on
`Milky2018/moon_wgsl_naga` for compatibility writer entry points.

Most applications should use the facade module `Milky2018/moon_wgsl`; import
this module directly when you need lower-level composer or preprocessor APIs.

The supported package inventory is `contract`, `profile`, `preprocess`,
`metadata`, `resolver`, `compose`, `export`, and `diagnostics`. Directive
scanning, import parsing, binding transforms, import substitution, and source
editing live under `internal/`; they are implementation details and cannot be
imported from another MoonBit module. Source editing receives bound token
replacements and does not resolve symbols or composition policy itself.

`WgslComposeOptions::default()` is language-neutral and has no predefined
shader values. Select project policy explicitly:

```mbt check
///|
test "select the Bevy compatibility profile explicitly" {
  let options = @contract.WgslComposeOptions::default()
  options.value_defines = @profile.bevy_wgsl_value_defines()
  assert_true(options.value_defines.contains("MATERIAL_BIND_GROUP"))
}
```
