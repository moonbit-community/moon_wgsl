#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

emit_case() {
  local case_name="$1"
  local output="$2"
  moon run tools/wgsl_validation_cases -- "$case_name" > "$output"
}

validate_wgsl() {
  cargo run --quiet --manifest-path tools/naga_oil_oracle/Cargo.toml --bin wgsl_validate -- "$@"
}

roundtrip_and_validate_wgsl() {
  local input="$1"
  shift
  local output="$tmpdir/$(basename "$input" .wgsl).ir.wgsl"
  moon run tools/ir_roundtrip -- --input "$input" --output "$output" >/dev/null
  validate_wgsl "$@" "$output"
}

echo "== WGSL validation: writer token boundaries =="
emit_case writer-boundary "$tmpdir/writer_boundary.wgsl"
validate_wgsl "$tmpdir/writer_boundary.wgsl"

echo "== WGSL validation: upstream compute export =="
emit_case upstream-compute "$tmpdir/upstream_compute.wgsl"
validate_wgsl "$tmpdir/upstream_compute.wgsl"

echo "== WGSL validation: upstream diagnostic filters compose =="
emit_case upstream-diagnostic-filters "$tmpdir/upstream_diagnostic_filters.wgsl"
validate_wgsl "$tmpdir/upstream_diagnostic_filters.wgsl"

echo "== WGSL validation: issue 8 alias binding compose =="
emit_case bevy-issue8 "$tmpdir/bevy_issue8.wgsl"
validate_wgsl "$tmpdir/bevy_issue8.wgsl"

echo "== WGSL validation: issue 9 imported type identity =="
emit_case issue9-type-identity "$tmpdir/issue9_type_identity.wgsl"
validate_wgsl "$tmpdir/issue9_type_identity.wgsl"

echo "== WGSL validation: issue 13 nested alias global identity =="
emit_case issue13-nested-alias-global "$tmpdir/issue13_nested_alias_global.wgsl"
validate_wgsl "$tmpdir/issue13_nested_alias_global.wgsl"

echo "== WGSL validation: storage access and arrayLength IR =="
emit_case storage-array-length-ir "$tmpdir/storage_array_length_ir.wgsl"
validate_wgsl "$tmpdir/storage_array_length_ir.wgsl"

echo "== WGSL validation: Bevy PBR functions compose =="
emit_case bevy-pbr-functions "$tmpdir/bevy_pbr_functions.wgsl"
validate_wgsl "$tmpdir/bevy_pbr_functions.wgsl"
roundtrip_and_validate_wgsl "$tmpdir/bevy_pbr_functions.wgsl"

echo "== WGSL validation: Bevy PBR forward compose =="
emit_case bevy-pbr-forward "$tmpdir/bevy_pbr_forward.wgsl"
validate_wgsl "$tmpdir/bevy_pbr_forward.wgsl"
roundtrip_and_validate_wgsl "$tmpdir/bevy_pbr_forward.wgsl"

echo "== WGSL validation: MGStudio mesh3d forward compose =="
emit_case mgstudio-mesh3d-forward "$tmpdir/mgstudio_mesh3d_forward.wgsl"
validate_wgsl "$tmpdir/mgstudio_mesh3d_forward.wgsl"
roundtrip_and_validate_wgsl "$tmpdir/mgstudio_mesh3d_forward.wgsl"

echo "== WGSL validation: upstream raycast compose =="
emit_case upstream-raycast "$tmpdir/upstream_raycast.wgsl"
validate_wgsl --capability ray-query "$tmpdir/upstream_raycast.wgsl"

echo "== WGSL validation: upstream dual source blending compose =="
emit_case upstream-dual-source-blending "$tmpdir/upstream_dual_source_blending.wgsl"
validate_wgsl --capability dual-source-blending "$tmpdir/upstream_dual_source_blending.wgsl"

echo "WGSL validation gate passed"
