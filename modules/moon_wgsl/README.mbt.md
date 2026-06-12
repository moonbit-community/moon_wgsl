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
