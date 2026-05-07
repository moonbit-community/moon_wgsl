#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

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

moon_compose_error \
  conditional_missing_import \
  testdata/naga_oil_upstream/compose_tests/conditional_import_fail \
  top.wgsl
assert_error_contains conditional_missing_import "failed to resolve shader import"
assert_error_contains conditional_missing_import "b::C"

moon_compose_error \
  conditional_missing_import_nested \
  testdata/naga_oil_upstream/compose_tests/conditional_import_fail \
  top_nested.wgsl
assert_error_contains conditional_missing_import_nested "failed to resolve shader import"
assert_error_contains conditional_missing_import_nested "b::C"

moon_compose_error \
  missing_import \
  testdata/naga_oil_upstream/compose_tests/error_test \
  include.wgsl
assert_error_contains missing_import "failed to resolve shader import"
assert_error_contains missing_import "missing"

moon_compose_error \
  invalid_override_base \
  testdata/naga_oil_upstream/compose_tests/overrides \
  top_invalid.wgsl
assert_error_contains invalid_override_base "override is invalid"
assert_error_contains invalid_override_base "target is not virtual"

echo "moon_wgsl error parity passed"
