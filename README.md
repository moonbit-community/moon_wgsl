# moon_wgsl

`moon_wgsl` is now a MoonBit workspace for WGSL tooling. The workspace is split
by ownership instead of exposing every internal package through one module.

## Modules

- `Milky2018/wgsl`: official WGSL syntax, AST, parser, semantic IR, validation,
  and runtime WGSL emission.
- `Milky2018/moon_wgsl_naga`: Naga-compatible writer and trace entry points.
- `Milky2018/moon_wgsl_naga_oil`: naga-oil-compatible preprocessing,
  import resolution, composition contracts, explicit project profiles, and
  export.
- `Milky2018/moon_wgsl`: thin user-facing facade for ordinary preprocessing,
  composition, and WESL compilation workflows.
- `Milky2018/moon_wesl`: WESL module resolution, conditional compilation,
  and source assembly. It is maintained and released from this workspace with
  its own semantic version while depending on WGSL Core for official WGSL
  parsing and validation.

Most shader users should install `Milky2018/moon_wgsl`, including applications
that only need to compile registered WESL sources. Install
`Milky2018/moon_wesl` directly when you need custom resolvers, source maps, AST
access, or detailed compiler diagnostics. Use the lower-level WGSL, Naga, and
naga-oil modules only when you need their specific interfaces.

The facade owns an opaque `Composer` with only registration, `prepare`,
`compose`, `compile_wesl`, and `export_wgsl` workflows. Repository diagnostics
use the explicit `Milky2018/moon_wgsl_naga_oil/diagnostics` adapter. Naga-oil
directive parsing, import parsing, substitution, transformation, and source
editing are compiler-enforced `internal/` packages.

## Migration

Legacy internal paths such as `Milky2018/moon_wgsl/parser`,
`Milky2018/moon_wgsl/ir`, and `Milky2018/moon_wgsl/compose` are intentionally
not preserved.

Use these imports instead:

```text
Milky2018/wgsl/parser
Milky2018/wgsl/ir
Milky2018/moon_wgsl_naga_oil/contract
Milky2018/moon_wgsl_naga_oil/profile
Milky2018/moon_wgsl_naga_oil/compose
Milky2018/moon_wgsl_naga_oil/preprocess
```

The former `Milky2018/wgsl/common` contracts now belong to
`Milky2018/moon_wgsl_naga_oil/contract`. The former
`default_wgsl_value_defines()` policy is now the explicit
`bevy_wgsl_value_defines()` profile.

See [the ownership migration guide](docs/ownership-migration.md) for the full
package, type, method, result-accessor, and diagnostics mapping.

## Development

Run workspace checks from the repository root:

```bash
moon fmt
moon info --target all
moon check --target all --warn-list +73 --deny-warn
moon test --target all
```

Publish the synchronized WGSL compatibility line and the independently
versioned WESL module with the release script:

```bash
moon run --target js publish.mbtx <workspace-version> <wesl-version>
```

`moon_wesl` depends on `Milky2018/wgsl` for official WGSL parsing and semantic
validation. The script publishes it after the synchronized line so the pinned
WGSL Core version is available first.

## License

Apache-2.0
