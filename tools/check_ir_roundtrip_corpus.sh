#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

validate_wgsl() {
  cargo run --quiet --manifest-path tools/naga_oil_oracle/Cargo.toml --bin wgsl_validate -- "$@"
}

roundtrip_case() {
  local label="$1"
  local input="$2"
  local output="$tmpdir/${label}.wgsl"
  echo "== IR roundtrip corpus: ${label} =="
  moon run tools/ir_roundtrip -- --input "$input" --output "$output"
  validate_wgsl "$output"
}

compose_roundtrip_case() {
  local label="$1"
  local fixture_root="$2"
  local entry="$3"
  shift 3
  local composed="$tmpdir/${label}.composed.wgsl"
  local output="$tmpdir/${label}.ir.wgsl"
  echo "== Compose -> IR roundtrip corpus: ${label} =="
  moon run tools/compose_case -- \
    --fixture-root "$fixture_root" \
    --entry "$entry" \
    --ir \
    "$@" \
    --output "$composed"
  validate_wgsl "$composed"
  moon run tools/ir_roundtrip -- --input "$composed" --output "$output"
  validate_wgsl "$output"
}

roundtrip_case "simple-compute" "testdata/ir_corpus/simple_compute.wgsl"
roundtrip_case "switch-compute" "testdata/ir_corpus/switch_compute.wgsl"
roundtrip_case "for-compute" "testdata/ir_corpus/for_compute.wgsl"
roundtrip_case "struct-member-compute" \
  "testdata/ir_corpus/struct_member_compute.wgsl"
roundtrip_case "texture-compute" "testdata/ir_corpus/texture_compute.wgsl"
roundtrip_case "advanced-texture-fragment" \
  "testdata/ir_corpus/advanced_texture_fragment.wgsl"
roundtrip_case "texture-load-queries-compute" \
  "testdata/ir_corpus/texture_load_queries_compute.wgsl"
compose_roundtrip_case \
  "simple-compose-compute" \
  "testdata/ir_corpus/compose" \
  "top.wgsl"
compose_roundtrip_case \
  "upstream-simple-compose" \
  "testdata/upstream_compose/simple" \
  "top.wgsl"
compose_roundtrip_case \
  "upstream-item-import-compose" \
  "testdata/upstream_compose/item_import" \
  "top.wgsl"
compose_roundtrip_case \
  "upstream-dup-import-compose" \
  "testdata/upstream_compose/dup_import" \
  "top.wgsl"
compose_roundtrip_case \
  "upstream-dup-struct-import-compose" \
  "testdata/upstream_compose/dup_struct_import" \
  "top.wgsl"
compose_roundtrip_case \
  "upstream-conditional-import-compose" \
  "testdata/upstream_compose/conditional_import" \
  "top.wgsl"
compose_roundtrip_case \
  "upstream-conditional-import-a-compose" \
  "testdata/upstream_compose/conditional_import" \
  "top.wgsl" \
  --def USE_A
compose_roundtrip_case \
  "upstream-shared-global-compose" \
  "testdata/upstream_compose/use_shared_global" \
  "top.wgsl"
compose_roundtrip_case \
  "upstream-diagnostic-filters-compose" \
  "testdata/upstream_compose/diagnostic_filters" \
  "top.wgsl"
compose_roundtrip_case \
  "upstream-atomics-compose" \
  "testdata/upstream_compose/atomics" \
  "top.wgsl"
compose_roundtrip_case \
  "upstream-modf-compose" \
  "testdata/upstream_compose/modf" \
  "top.wgsl"
compose_roundtrip_case \
  "upstream-call-entrypoint-compose" \
  "testdata/upstream_compose/call_entrypoint" \
  "top.wgsl"
compose_roundtrip_case \
  "upstream-big-shaderdefs-compose" \
  "testdata/upstream_compose/big_shaderdefs" \
  "top.wgsl" \
  $(for i in $(seq 1 67); do printf -- '--def a%s ' "$i"; done)
compose_roundtrip_case \
  "upstream-add-imports-compose" \
  "testdata/upstream_compose/add_imports" \
  "top.wgsl" \
  --additional-import plugin
compose_roundtrip_case \
  "upstream-const-in-decl-compose" \
  "testdata/upstream_compose/const_in_decl" \
  "top.wgsl"
compose_roundtrip_case \
  "upstream-item-sub-point-compose" \
  "testdata/upstream_compose/item_sub_point" \
  "top.wgsl"
compose_roundtrip_case \
  "upstream-quoted-dup-compose" \
  "testdata/upstream_compose/quoted_dup" \
  "top.wgsl"
compose_roundtrip_case \
  "upstream-problematic-expressions-compose" \
  "testdata/upstream_compose/problematic_expressions" \
  "top.wgsl"
compose_roundtrip_case \
  "upstream-rusty-imports-compose" \
  "testdata/upstream_compose/rusty_imports" \
  "top.wgsl"
compose_roundtrip_case \
  "upstream-effective-defs-compose" \
  "testdata/upstream_compose/effective_defs" \
  "top.wgsl" \
  --def DEF_ONE \
  --def DEF_THREE
compose_roundtrip_case \
  "upstream-invalid-identifiers-compose" \
  "testdata/upstream_compose/invalid_identifiers" \
  "top_valid.wgsl"

echo "IR roundtrip corpus gate passed"
