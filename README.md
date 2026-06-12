# moon_wgsl

`moon_wgsl` is now a MoonBit workspace for WGSL tooling. The workspace is split
by ownership instead of exposing every internal package through one module.

## Modules

- `Milky2018/wgsl`: official WGSL syntax, AST, parser, semantic IR, validation,
  and runtime WGSL emission.
- `Milky2018/moon_wgsl_naga`: Naga-compatible writer and trace entry points.
- `Milky2018/moon_wgsl_naga_oil`: naga-oil-compatible preprocessing,
  import resolution, composition, and export.
- `Milky2018/moon_wgsl`: thin user-facing facade for ordinary preprocessing and
  composition workflows.

Most users should install `Milky2018/moon_wgsl`. Use the lower-level modules
only when you need their specific parser, IR, Naga, or naga-oil boundary.

## Migration

Legacy internal paths such as `Milky2018/moon_wgsl/parser`,
`Milky2018/moon_wgsl/ir`, and `Milky2018/moon_wgsl/compose` are intentionally
not preserved.

Use these imports instead:

```text
Milky2018/wgsl/parser
Milky2018/wgsl/ir
Milky2018/moon_wgsl_naga_oil/compose
Milky2018/moon_wgsl_naga_oil/preprocess
```

## Development

Run workspace checks from the repository root:

```bash
moon fmt
moon info --target all
moon check --target all --deny-warn
moon test --target all
```

Publish all public modules with the synchronized release script:

```bash
moon run --target js publish.mbtx <version>
```

## License

Apache-2.0
