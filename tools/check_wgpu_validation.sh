#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

tmpdir="$(mktemp -d)"
negative_output="$tmpdir/negative.out"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

moon -C tools/wgpu_validation build --target native >/dev/null
validator="$repo_root/tools/wgpu_validation/_build/native/debug/build/cmd/main/main.exe"

wgpu_validate() {
  "$validator" "$@"
}

emit_case() {
  local case_name="$1"
  local output="$2"
  moon run tools/wgsl_validation_cases -- "$case_name" > "$output"
}

echo "== wgpu validation: shader module smoke =="
cat > "$tmpdir/shader_module_smoke.wgsl" <<'WGSL'
@fragment
fn fs_main() -> @location(0) vec4<f32> {
  return vec4<f32>(0.0, 0.0, 0.0, 1.0);
}
WGSL
wgpu_validate --input "$tmpdir/shader_module_smoke.wgsl" --mode shader-module

echo "== wgpu validation: storage access runtime layout =="
cat > "$tmpdir/storage_access_source.wgsl" <<'WGSL'
@group(0) @binding(0)
var<storage> values: array<u32>;

@group(0) @binding(1)
var<storage, read_write> output: array<u32>;

@compute @workgroup_size(1)
fn main(@builtin(global_invocation_id) id: vec3<u32>) {
  if (id.x >= arrayLength(&values)) {
    return;
  }
  output[id.x] = values[id.x];
}
WGSL
moon run tools/ir_roundtrip -- \
  --input "$tmpdir/storage_access_source.wgsl" \
  --output "$tmpdir/storage_access_ir.wgsl" >/dev/null
wgpu_validate \
  --input "$tmpdir/storage_access_ir.wgsl" \
  --mode compute-storage-read \
  --compute-entry main

echo "== wgpu validation: storage access negative control =="
cat > "$tmpdir/storage_access_bad.wgsl" <<'WGSL'
@group(0) @binding(0)
var<storage, read_write> values: array<u32>;

@group(0) @binding(1)
var<storage, read_write> output: array<u32>;

@compute @workgroup_size(1)
fn main(@builtin(global_invocation_id) id: vec3<u32>) {
  if (id.x >= arrayLength(&values)) {
    return;
  }
  output[id.x] = values[id.x];
}
WGSL
if wgpu_validate \
  --input "$tmpdir/storage_access_bad.wgsl" \
  --mode compute-storage-read \
  --compute-entry main >"$negative_output" 2>&1; then
  cat "$negative_output" >&2
  echo "expected wgpu validation to reject read_write shader binding against read-only layout" >&2
  exit 1
fi

echo "== wgpu validation: Bevy PBR forward shader module =="
emit_case bevy-pbr-forward "$tmpdir/bevy_pbr_forward.wgsl"
wgpu_validate --input "$tmpdir/bevy_pbr_forward.wgsl" --mode shader-module

echo "== wgpu validation: MGStudio mesh3d forward shader module =="
emit_case mgstudio-mesh3d-forward "$tmpdir/mgstudio_mesh3d_forward.wgsl"
wgpu_validate --input "$tmpdir/mgstudio_mesh3d_forward.wgsl" --mode shader-module

echo "wgpu validation gate passed"
