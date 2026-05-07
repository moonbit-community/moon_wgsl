#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

moon_compose_ir() {
  local fixture_root="$1"
  local entry="$2"
  local output="$3"
  shift 3
  moon run tools/compose_case -- \
    --fixture-root "$fixture_root" \
    --entry "$entry" \
    --ir \
    --output "$output" \
    "$@"
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

check_case() {
  local label="$1"
  local fixture_root="$2"
  local entry="$3"
  local expected="$4"
  shift 4
  local actual="$tmpdir/$label.wgsl"

  echo "== moon_wgsl byte parity: $label =="
  moon_compose_ir "$fixture_root" "$entry" "$actual" "$@"
  diff_exact "$expected" "$actual" "$label"
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
  dup_struct_import \
  testdata/naga_oil_upstream/compose_tests/dup_struct_import \
  top.wgsl \
  testdata/naga_oil_upstream/compose_tests/expected/dup_struct_import.txt

check_case \
  import_in_decl \
  testdata/naga_oil_upstream/compose_tests/const_in_decl \
  top.wgsl \
  testdata/naga_oil_upstream/compose_tests/expected/import_in_decl.txt

check_case \
  quoted_dup \
  testdata/naga_oil_upstream/compose_tests/quoted_dup \
  top.wgsl \
  testdata/naga_oil_upstream/compose_tests/expected/test_quoted_import_dup_name.txt
