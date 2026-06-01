#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

out_dir="${MOON_WGSL_NAGA_WRITER_TRACE_DIR:-_build/parity/naga_writer_trace}"
rm -rf "$out_dir"
mkdir -p "$out_dir"

entry="bevy_pbr/src/render/pbr_functions.wgsl"
function_prefix="${MOON_WGSL_NAGA_WRITER_TRACE_FUNCTION:-fresnelX_naga_oil_mod}"

moon_args=(
  --fixture-root testdata/bevy_wgsl
  --entry "$entry"
  --naga-writer-trace-function "$function_prefix"
  --output "$out_dir/moon.trace"
  --value-def AVAILABLE_STORAGE_BUFFER_BINDINGS=8
  --value-def MAX_DIRECTIONAL_LIGHTS=10
  --value-def MAX_CASCADES_PER_LIGHT=4
  --value-def MAX_RECT_LIGHTS=4
  --value-def MATERIAL_BIND_GROUP=3
  --value-def SORTED_FRAGMENT_MAX_COUNT=8
  --value-def WORLD_CACHE_SIZE=1048576
  --value-def PER_OBJECT_BUFFER_BATCH_SIZE=1
  --value-def SCREEN_SPACE_SPECULAR_TRANSMISSION_BLUR_TAPS=8
)

oracle_args=(
  --fixture-root testdata/bevy_wgsl
  --entry "$entry"
  --expression-inventory "$out_dir/oracle.inventory"
  --check-only
  --def AVAILABLE_STORAGE_BUFFER_BINDINGS=8
  --def MAX_DIRECTIONAL_LIGHTS=10
  --def MAX_CASCADES_PER_LIGHT=4
  --def MAX_RECT_LIGHTS=4
  --def MATERIAL_BIND_GROUP=3
  --def SORTED_FRAGMENT_MAX_COUNT=8
  --def WORLD_CACHE_SIZE=1048576
  --def PER_OBJECT_BUFFER_BATCH_SIZE=1
  --def SCREEN_SPACE_SPECULAR_TRANSMISSION_BLUR_TAPS=8
)

moon run tools/compose_case -- "${moon_args[@]}"
cargo run --quiet --manifest-path tools/naga_oil_oracle/Cargo.toml --bin naga_oil_oracle -- "${oracle_args[@]}"

awk -F '\t' -v prefix="fn:${function_prefix}" '
  $1 == "function" { active = index($2, prefix) == 1 }
  active && $1 == "expression" {
    kind = $4
    sub(/\(.*/, "", kind)
    sub(/ \{.*/, "", kind)
    print "expression\t" $3 "\t" kind
  }
  active && $1 == "body" {
    body = $3
    statement = 0
    while (match(body, /(Emit\(\[[0-9]+\.\.[0-9]+\]\)|Call \{[^}]*result: Some\(\[[0-9]+\]\)[^}]*\}|Return \{[^}]*\})/)) {
      item = substr(body, RSTART, RLENGTH)
      if (item ~ /^Emit/) {
        range = item
        sub(/^Emit\(\[/, "", range)
        sub(/\]\)$/, "", range)
        split(range, parts, "\\.\\.")
        start = parts[1] + 0
        end = parts[2] - 1
        print "statement\t" statement "\tEmit(" start ".." end ")"
      } else if (item ~ /^Call/) {
        result = item
        sub(/^.*result: Some\(\[/, "", result)
        sub(/\]\).*$/, "", result)
        print "statement\t" statement "\tCall(result=" result ")"
      } else if (item ~ /^Return/) {
        print "statement\t" statement "\tReturn"
      }
      body = substr(body, RSTART + RLENGTH)
      statement = statement + 1
    }
  }
' "$out_dir/oracle.inventory" > "$out_dir/oracle.expression-order"

awk -F '\t' '
  $1 == "expression" { print "expression\t" $3 "\t" $4 }
  $1 == "statement" { print "statement\t" $3 "\t" $4 }
' "$out_dir/moon.trace" > "$out_dir/moon.expression-order"

awk -F '\t' -v prefix="fn:${function_prefix}" '
  $1 == "function" { active = index($2, prefix) == 1 }
  active && $1 == "body" {
    text = $0
    while (match(text, /result: Some\(\[[0-9]+\]\)/)) {
      item = substr(text, RSTART, RLENGTH)
      gsub(/[^0-9]/, "", item)
      print "materialized\t" item "\ttemp=_e" item
      text = substr(text, RSTART + RLENGTH)
    }
  }
' "$out_dir/oracle.inventory" > "$out_dir/oracle.materialized"

awk -F '\t' '
  $1 == "expression" && $0 ~ /materialized=true/ {
    temp = $0
    sub(/^.*\ttemp=/, "", temp)
    sub(/\t.*$/, "", temp)
    print "materialized\t" $3 "\ttemp=" temp
  }
' "$out_dir/moon.trace" > "$out_dir/moon.materialized"

diff -u "$out_dir/oracle.expression-order" "$out_dir/moon.expression-order" > "$out_dir/expression-order.diff" || expression_drift=1
diff -u "$out_dir/oracle.materialized" "$out_dir/moon.materialized" > "$out_dir/materialized.diff" || materialized_drift=1

if [[ "${expression_drift:-0}" == 0 && "${materialized_drift:-0}" == 0 ]]; then
  echo "naga writer representative trace parity passed: $entry :: $function_prefix"
  exit 0
fi

echo "naga writer representative trace drift: $entry :: $function_prefix" >&2
echo "artifacts: $out_dir" >&2
[[ "${expression_drift:-0}" == 0 ]] || sed -n '1,120p' "$out_dir/expression-order.diff" >&2
[[ "${materialized_drift:-0}" == 0 ]] || sed -n '1,120p' "$out_dir/materialized.diff" >&2

if [[ "${MOON_WGSL_ALLOW_KNOWN_TRACE_DRIFT:-0}" == 1 ]]; then
  exit 0
fi
exit 1
