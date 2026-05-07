# naga_oil Oracle

This is an optional compatibility tool. It is not part of the MoonBit package or
the default `moon test` path.

It composes the same fixture tree through upstream `bevyengine/naga_oil` pinned
at commit `bc444c82bb593ede94c55cdbf799e9743800843e`, validates the resulting
Naga module, and writes canonical WGSL with Naga's WGSL writer. Use it when
refreshing compatibility expectations or investigating a parity gap.

Example with a small upstream-style fixture:

```sh
cargo run --manifest-path tools/naga_oil_oracle/Cargo.toml -- \
  --fixture-root testdata/upstream_compose/simple \
  --entry top.wgsl \
  --output /tmp/naga_oil_simple.wgsl
```

Additional-import fixtures can inject modules the same way upstream
`NagaModuleDescriptor::additional_imports` does:

```sh
cargo run --manifest-path tools/naga_oil_oracle/Cargo.toml -- \
  --fixture-root testdata/naga_oil_upstream/compose_tests/add_imports \
  --entry top.wgsl \
  --additional-import plugin \
  --output /tmp/naga_oil_additional_import.wgsl
```

GLSL fixtures can use upstream's GLSL frontend through the same pinned oracle:

```sh
cargo run --manifest-path tools/naga_oil_oracle/Cargo.toml -- \
  --fixture-root testdata/naga_oil_upstream/compose_tests/glsl \
  --entry top.glsl \
  --shader-type glsl-vertex \
  --output /tmp/naga_oil_glsl_call_wgsl.wgsl
```

Parser and validator diagnostics can be emitted and compared to upstream
expected files:

```sh
cargo run --manifest-path tools/naga_oil_oracle/Cargo.toml -- \
  --fixture-root testdata/naga_oil_upstream/compose_tests/error_test \
  --entry wgsl_parse_err.wgsl \
  --entry-only \
  --file-path-prefix tests/error_test \
  --error-output /tmp/naga_oil_err_parse.txt
```

Use `--module` when a fixture directory contains unrelated invalid files and
the upstream test registered only a selected composable module:

```sh
cargo run --manifest-path tools/naga_oil_oracle/Cargo.toml -- \
  --fixture-root testdata/naga_oil_upstream/compose_tests/error_test \
  --entry wgsl_valid_wrap.wgsl \
  --module wgsl_valid_err.wgsl \
  --additional-import valid_inc \
  --file-path-prefix tests/error_test \
  --error-output /tmp/naga_oil_err_validation.txt
```

Ray-query fixtures can enable the matching Naga capability:

```sh
cargo run --manifest-path tools/naga_oil_oracle/Cargo.toml -- \
  --fixture-root testdata/naga_oil_upstream/compose_tests/raycast \
  --entry top.wgsl \
  --capability ray-query \
  --check-only
```

Dual-source blending fixtures use the same capability flag style:

```sh
cargo run --manifest-path tools/naga_oil_oracle/Cargo.toml -- \
  --fixture-root testdata/naga_oil_upstream/compose_tests/dual_source_blending \
  --entry blending.wgsl \
  --capability dual-source-blending \
  --output /tmp/naga_oil_dual_source_blending.wgsl
```

`moon_wgsl` now treats byte-identical WGSL writer output as the long-term
parity target for WGSL compose cases that are fully representable in the local
IR. `tools/check_moon_wgsl_byte_parity.sh` gates the cases that currently match
the pinned `naga_oil` expected bytes exactly. Broader oracle parity still uses
`tools/check_preprocess_parity.sh` for upstream diagnostics, GLSL-backed cases,
capability-gated validation, and cases where local IR lowering is still being
expanded.
