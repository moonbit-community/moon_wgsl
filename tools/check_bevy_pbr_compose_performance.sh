#!/usr/bin/env bash
set -euo pipefail

timeout_value="${MOON_WGSL_BEVY_PBR_COMPOSE_TIMEOUT:-45s}"
output="${TMPDIR:-/tmp}/moon_wgsl_bevy_pbr_compose_perf.wgsl"

args=(
  moon run tools/compose_case --
  --fixture-root testdata/bevy_wgsl
  --entry bevy_pbr/src/render/pbr.wgsl
  --def VERTEX_POSITIONS
  --def VERTEX_NORMALS
  --def VERTEX_UVS
  --def VERTEX_UVS_A
  --def VERTEX_COLORS
  --def VERTEX_OUTPUT_INSTANCE_INDEX
  --def MAY_DISCARD
  --value-def AVAILABLE_STORAGE_BUFFER_BINDINGS=8
  --value-def MAX_DIRECTIONAL_LIGHTS=10
  --value-def MAX_CASCADES_PER_LIGHT=4
  --value-def MAX_RECT_LIGHTS=4
  --value-def MATERIAL_BIND_GROUP=3
  --value-def SORTED_FRAGMENT_MAX_COUNT=8
  --value-def WORLD_CACHE_SIZE=1048576
  --value-def PER_OBJECT_BUFFER_BATCH_SIZE=1
  --value-def SCREEN_SPACE_SPECULAR_TRANSMISSION_BLUR_TAPS=8
  --output "$output"
)

rm -f "$output"
if command -v timeout >/dev/null 2>&1; then
  timeout "$timeout_value" "${args[@]}"
else
  "${args[@]}"
fi

if [[ ! -s "$output" ]]; then
  echo "Bevy PBR compose performance gate failed: no output produced" >&2
  exit 1
fi

echo "Bevy PBR compose performance gate passed"
