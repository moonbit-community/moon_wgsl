#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

if [[ "${1:-}" == "--list" ]]; then
  cat <<'LABELS'
additional_import
atomics
bad_identifiers
big_shaderdefs
conditional_import_a
conditional_import_b
dup_import
dup_struct_import
import_in_decl
item_import_test
item_sub_point
override_top
problematic_expressions
simple_compose
test_quoted_import_dup_name
use_shared_global
wgsl_call_entrypoint
wgsl_dual_source_blending
LABELS
  exit 0
fi

moon_compose() {
  local fixture_root="$1"
  local entry="$2"
  local output="$3"
  shift 3
  moon run tools/compose_case -- \
    --fixture-root "$fixture_root" \
    --entry "$entry" \
    --output "$output" \
    "$@"
}

validate_wgsl() {
  cargo run --quiet --manifest-path tools/naga_oil_oracle/Cargo.toml --bin wgsl_validate -- "$@"
}

diff_exact() {
  local expected="$1"
  local actual="$2"
  local label="$3"
  if LC_ALL=C grep -q $'\r' "$expected"; then
    printf 'expected fixture %s contains CR bytes; byte-exact parity fixtures must match oracle output bytes\n' "$label" >&2
    exit 1
  fi
  diff -u "$expected" "$actual"
}

diff_atomics_expected_without_invalid_internal_type() {
  local expected="$1"
  local actual="$2"
  local label="$3"
  local normalized_expected="$tmpdir/${label}.expected.valid.wgsl"

  sed \
    's/: _atomic_compare_exchange_result_Uint_4_ = atomicCompareExchangeWeak/ = atomicCompareExchangeWeak/' \
    "$expected" > "$normalized_expected"
  diff_exact "$normalized_expected" "$actual" "$label"
  validate_wgsl "$actual" >/dev/null
  if validate_wgsl "$expected" >/dev/null 2>&1; then
    printf 'expected fixture %s unexpectedly validates; remove the atomics normalization exception\n' "$label" >&2
    exit 1
  fi
}

check_case() {
  local label="$1"
  local fixture_root="$2"
  local entry="$3"
  local expected="$4"
  shift 4
  local actual="$tmpdir/$label.wgsl"

  echo "== moon_wgsl byte parity: $label =="
  moon_compose "$fixture_root" "$entry" "$actual" "$@"
  diff_exact "$expected" "$actual" "$label"
}

check_case_atomics_validated() {
  local label="$1"
  local fixture_root="$2"
  local entry="$3"
  local expected="$4"
  shift 4
  local actual="$tmpdir/$label.wgsl"

  echo "== moon_wgsl byte parity: $label =="
  moon_compose "$fixture_root" "$entry" "$actual" "$@"
  diff_atomics_expected_without_invalid_internal_type "$expected" "$actual" "$label"
}

check_case \
  simple_compose \
  testdata/naga_oil_upstream/compose_tests/simple \
  top.wgsl \
  testdata/naga_oil_upstream/compose_tests/expected/simple_compose.txt

check_case \
  use_shared_global \
  testdata/naga_oil_upstream/compose_tests/use_shared_global \
  top.wgsl \
  testdata/naga_oil_upstream/compose_tests/expected/use_shared_global.txt

check_case \
  conditional_import_a \
  testdata/naga_oil_upstream/compose_tests/conditional_import \
  top.wgsl \
  testdata/naga_oil_upstream/compose_tests/expected/conditional_import_a.txt \
  --def USE_A

check_case \
  conditional_import_b \
  testdata/naga_oil_upstream/compose_tests/conditional_import \
  top.wgsl \
  testdata/naga_oil_upstream/compose_tests/expected/conditional_import_b.txt

big_shaderdef_args=()
for i in $(seq 1 67); do
  big_shaderdef_args+=(--def "a$i")
done

check_case \
  big_shaderdefs \
  testdata/naga_oil_upstream/compose_tests/big_shaderdefs \
  top.wgsl \
  testdata/naga_oil_upstream/compose_tests/expected/big_shaderdefs.txt \
  "${big_shaderdef_args[@]}"

check_case \
  additional_import \
  testdata/naga_oil_upstream/compose_tests/add_imports \
  top.wgsl \
  testdata/naga_oil_upstream/compose_tests/expected/additional_import.txt \
  --additional-import plugin

check_case \
  override_top \
  testdata/naga_oil_upstream/compose_tests/overrides \
  top.wgsl \
  testdata/naga_oil_upstream/compose_tests/expected/override_top.txt

check_case \
  dup_struct_import \
  testdata/naga_oil_upstream/compose_tests/dup_struct_import \
  top.wgsl \
  testdata/naga_oil_upstream/compose_tests/expected/dup_struct_import.txt

check_case \
  dup_import \
  testdata/naga_oil_upstream/compose_tests/dup_import \
  top.wgsl \
  testdata/naga_oil_upstream/compose_tests/expected/dup_import.txt

check_case \
  import_in_decl \
  testdata/naga_oil_upstream/compose_tests/const_in_decl \
  top.wgsl \
  testdata/naga_oil_upstream/compose_tests/expected/import_in_decl.txt

check_case \
  item_import_test \
  testdata/naga_oil_upstream/compose_tests/item_import \
  top.wgsl \
  testdata/naga_oil_upstream/compose_tests/expected/item_import_test.txt

check_case \
  item_sub_point \
  testdata/naga_oil_upstream/compose_tests/item_sub_point \
  top.wgsl \
  testdata/naga_oil_upstream/compose_tests/expected/item_sub_point.txt

check_case \
  wgsl_call_entrypoint \
  testdata/naga_oil_upstream/compose_tests/call_entrypoint \
  top.wgsl \
  testdata/naga_oil_upstream/compose_tests/expected/wgsl_call_entrypoint.txt

check_case \
  wgsl_dual_source_blending \
  testdata/naga_oil_upstream/compose_tests/dual_source_blending \
  blending.wgsl \
  testdata/naga_oil_upstream/compose_tests/expected/wgsl_dual_source_blending.txt

check_case \
  test_quoted_import_dup_name \
  testdata/naga_oil_upstream/compose_tests/quoted_dup \
  top.wgsl \
  testdata/naga_oil_upstream/compose_tests/expected/test_quoted_import_dup_name.txt

check_case \
  problematic_expressions \
  testdata/naga_oil_upstream/compose_tests/problematic_expressions \
  top.wgsl \
  testdata/naga_oil_upstream/compose_tests/expected/problematic_expressions.txt

check_case \
  bad_identifiers \
  testdata/naga_oil_upstream/compose_tests/invalid_identifiers \
  top_valid.wgsl \
  testdata/naga_oil_upstream/compose_tests/expected/bad_identifiers.txt

check_case_atomics_validated \
  atomics \
  testdata/naga_oil_upstream/compose_tests/atomics \
  top.wgsl \
  testdata/naga_oil_upstream/compose_tests/expected/atomics.txt
