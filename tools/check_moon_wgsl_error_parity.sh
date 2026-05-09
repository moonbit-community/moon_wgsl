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
  local output="$tmpdir/$label.txt"

  echo "== moon_wgsl error parity: $label =="
  moon run tools/compose_case -- \
    --fixture-root "$fixture_root" \
    --entry "$entry" \
    --expect-error \
    --error-output "$output"

  if grep -Fq "UNEXPECTED_SUCCESS" "$output"; then
    printf 'expected %s to fail, but compose succeeded\n' "$label" >&2
    exit 1
  fi
}

assert_error_contains() {
  local label="$1"
  local needle="$2"
  local output="$tmpdir/$label.txt"

  if ! grep -Fq "$needle" "$output"; then
    printf 'expected %s error to contain: %s\n' "$label" "$needle" >&2
    printf 'actual %s error:\n' "$label" >&2
    sed -n '1,120p' "$output" >&2
    exit 1
  fi
}

assert_error_first_line_exact() {
  local label="$1"
  local expected="$2"
  local output="$tmpdir/$label.txt"
  local expected_line="$tmpdir/$label.expected.first"
  local actual_line="$tmpdir/$label.actual.first"

  printf '%s\n' "$(sed -n '1p' "$expected")" > "$expected_line"
  printf '%s\n' "$(sed -n '1p' "$output")" > "$actual_line"
  diff -u "$expected_line" "$actual_line"
}

moon_compose_error \
  conditional_missing_import \
  testdata/naga_oil_upstream/compose_tests/conditional_import_fail \
  top.wgsl
assert_error_first_line_exact \
  conditional_missing_import \
  testdata/naga_oil_upstream/compose_tests/expected/conditional_missing_import.txt

moon_compose_error \
  conditional_missing_import_nested \
  testdata/naga_oil_upstream/compose_tests/conditional_import_fail \
  top_nested.wgsl
assert_error_first_line_exact \
  conditional_missing_import_nested \
  testdata/naga_oil_upstream/compose_tests/expected/conditional_missing_import_nested.txt

moon_compose_error \
  missing_import \
  testdata/naga_oil_upstream/compose_tests/error_test \
  include.wgsl
assert_error_first_line_exact \
  missing_import \
  testdata/naga_oil_upstream/compose_tests/expected/missing_import.txt

moon_compose_error \
  invalid_override_base \
  testdata/naga_oil_upstream/compose_tests/overrides \
  top_invalid.wgsl
assert_error_first_line_exact \
  invalid_override_base \
  testdata/naga_oil_upstream/compose_tests/expected/invalid_override_base.txt

echo "moon_wgsl error parity passed"
