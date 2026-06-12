# Milky2018/moon_wgsl_naga_oil

naga-oil-compatible preprocessing and composition for MoonBit WGSL.

This module owns:

- shader definition evaluation
- `#ifdef`, `#define`, and directive preprocessing
- `#define_import_path` and `#import` metadata
- source registries and module resolution
- symbol-bound composition and export

It depends on `Milky2018/wgsl` for syntax/IR validation and on
`Milky2018/moon_wgsl_naga` for compatibility writer entry points.

Most applications should use the facade module `Milky2018/moon_wgsl`; import
this module directly when you need lower-level composer or preprocessor APIs.
