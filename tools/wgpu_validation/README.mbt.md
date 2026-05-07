# moon_wgsl wgpu validation harness

This is an isolated native-only MoonBit subproject for validating generated
WGSL with `Milky2018/wgpu_mbt`.

It intentionally lives outside the root `Milky2018/moon_wgsl` module so the
published WGSL library remains backend-agnostic and can still be checked for
all MoonBit targets.

## Usage

```bash
moon -C tools/wgpu_validation build --target native
tools/wgpu_validation/_build/native/debug/build/cmd/main/main.exe \
  --input path/to/shader.wgsl \
  --mode shader-module
```

Modes:

- `shader-module`: create a wgpu shader module and inspect compilation info.
- `compute`: create a compute pipeline with the selected entry point.
- `compute-storage-read`: create a compute pipeline with an explicit layout
  where binding `0` is read-only storage and binding `1` is writable storage.
  This catches the storage access mismatch class that Naga-only validation can
  miss.
- `render-rgba8`: create an RGBA8 render pipeline with explicit vertex and
  fragment entry points.

Entry-point flags:

- `--compute-entry NAME`, default `main`
- `--vertex-entry NAME`, default `vs_main`
- `--fragment-entry NAME`, default `fs_main`
