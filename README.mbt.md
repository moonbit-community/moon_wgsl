# moon_wgsl workspace

This repository contains four separately owned MoonBit modules:

- `Milky2018/wgsl` — official WGSL lexer, AST, parser, semantic IR,
  validation, and runtime writer
- `Milky2018/moon_wgsl_naga` — Naga-compatible ordering, naming, writer,
  and trace behavior
- `Milky2018/moon_wgsl_naga_oil` — naga-oil directives, imports,
  preprocessing, resolution, composition, export, profiles, and diagnostics
- `Milky2018/moon_wgsl` — the small user-facing workflow facade

Most applications should import `Milky2018/moon_wgsl`. Its opaque `Composer`
supports exactly source/module registration, `prepare`, `compose`, and
`export_wgsl`. Lower-level parser, IR, compatibility, graph, rewrite, and
diagnostic stages are not facade methods.

```mbt
let composer = @moon_wgsl.Composer::default()
composer.register_source("main.wgsl", "fn answer() -> u32 { return 42u; }")
let source = composer.compose(
  "main.wgsl",
  @moon_wgsl.WgslComposeOptions::default(),
)
```

The synchronized ownership change is intentionally breaking. Legacy package
paths, compatibility records in WGSL Core, direct directive/import parsers,
and the re-exported lower-level `Composer` are not retained as aliases. See
[`docs/ownership-migration.md`](docs/ownership-migration.md) for the complete
old-to-new mapping and [`docs/adr/0020-enforce-conceptual-ownership-and-deep-interfaces.md`](docs/adr/0020-enforce-conceptual-ownership-and-deep-interfaces.md)
for the final architecture.

Development and release commands are documented in [`README.md`](README.md).

## License

Apache-2.0
