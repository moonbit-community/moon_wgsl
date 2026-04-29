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

Ray-query fixtures can enable the matching Naga capability:

```sh
cargo run --manifest-path tools/naga_oil_oracle/Cargo.toml -- \
  --fixture-root testdata/naga_oil_upstream/compose_tests/raycast \
  --entry top.wgsl \
  --capability ray-query \
  --check-only
```

The output is not expected to be byte-identical to `moon_wgsl` because
`naga_oil` writes validated Naga IR while `moon_wgsl` is a source-level
composer. Compare structural properties instead: resolved imports, retained
entry points, declaration dependencies, absence of unknown identifiers, and
collision handling.

For import-only Bevy root shaders such as
`mgstudio/render/renderer/mesh3d_bevy_forward.wgsl`, keep the primary regression
in MoonBit source-level tests. Upstream `naga_oil` can validly write an empty
module for an import-only root when no entry point is referenced from root
source, while `moon_wgsl` intentionally preserves item-imported entry points for
the mgstudio runtime use case.
