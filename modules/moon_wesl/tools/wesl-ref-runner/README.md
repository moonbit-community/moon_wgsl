# wesl-ref-runner

`wesl-ref-runner` is a test-only reference harness for comparing `moon_wesl`
against the published Rust `wesl` crate.

It intentionally lives under `tools/` and is not a runtime dependency of the
MoonBit package. Requests are JSON on stdin and responses are JSON on stdout.

Supported operations in this first slice:

- `parse-display`
- `validate-wesl`
- `validate-wgsl`
- `compile-virtual`

Example:

```bash
cargo run --manifest-path tools/wesl-ref-runner/Cargo.toml -- <<'JSON'
{
  "op": "parse-display",
  "source": "fn main() {}"
}
JSON
```
