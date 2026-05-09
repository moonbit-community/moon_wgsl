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
conditional_missing_import
conditional_missing_import_nested
invalid_override_base
missing_import
LABELS
  exit 0
fi

moon_compose_error() {
  local label="$1"
  local fixture_root="$2"
  local entry="$3"
  local file_path_prefix="$4"
  local output="$tmpdir/$label.txt"

  echo "== moon_wgsl error parity: $label =="
  moon run tools/compose_case -- \
    --fixture-root "$fixture_root" \
    --entry "$entry" \
    --file-path-prefix "$file_path_prefix" \
    --expect-error \
    --error-output "$output"

  if grep -Fq "UNEXPECTED_SUCCESS" "$output"; then
    printf 'expected %s to fail, but compose succeeded\n' "$label" >&2
    exit 1
  fi
}

assert_error_exact() {
  local label="$1"
  local expected="$2"
  local output="$tmpdir/$label.txt"
  diff -u "$expected" "$output"
}

moon_compose_error \
  conditional_missing_import \
  testdata/naga_oil_upstream/compose_tests/conditional_import_fail \
  top.wgsl \
  tests/conditional_import_fail
assert_error_exact \
  conditional_missing_import \
  testdata/naga_oil_upstream/compose_tests/expected/conditional_missing_import.txt

moon_compose_error \
  conditional_missing_import_nested \
  testdata/naga_oil_upstream/compose_tests/conditional_import_fail \
  top_nested.wgsl \
  tests/conditional_import_fail
assert_error_exact \
  conditional_missing_import_nested \
  testdata/naga_oil_upstream/compose_tests/expected/conditional_missing_import_nested.txt

moon_compose_error \
  missing_import \
  testdata/naga_oil_upstream/compose_tests/error_test \
  include.wgsl \
  tests/error_test
assert_error_exact \
  missing_import \
  testdata/naga_oil_upstream/compose_tests/expected/missing_import.txt

moon_compose_error \
  invalid_override_base \
  testdata/naga_oil_upstream/compose_tests/overrides \
  top_invalid.wgsl \
  tests/overrides
assert_error_exact \
  invalid_override_base \
  testdata/naga_oil_upstream/compose_tests/expected/invalid_override_base.txt

echo "moon_wgsl error parity passed"
