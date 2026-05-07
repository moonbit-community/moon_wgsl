#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

manifest="testdata/naga_oil_upstream/compose_tests/parity_manifest.tsv"
expected_dir="testdata/naga_oil_upstream/compose_tests/expected"

fail() {
  printf 'naga_oil parity inventory failed: %s\n' "$*" >&2
  exit 1
}

[[ -f "$manifest" ]] || fail "missing manifest: $manifest"

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

rows="$tmpdir/manifest_rows.tsv"
manifest_labels="$tmpdir/manifest_labels.txt"
manifest_expected="$tmpdir/manifest_expected.txt"
actual_expected="$tmpdir/actual_expected.txt"

awk -F '\t' '
  NF == 0 { next }
  $1 == "" { next }
  $1 ~ /^#/ { next }
  $1 == "label" { next }
  { print }
' "$manifest" > "$rows"

cut -f1 "$rows" | sort > "$manifest_labels"
cut -f2 "$rows" | sort > "$manifest_expected"

duplicate_labels="$(uniq -d "$manifest_labels" | tr '\n' ' ')"
[[ -z "$duplicate_labels" ]] || fail "duplicate manifest label(s): $duplicate_labels"

duplicate_expected="$(uniq -d "$manifest_expected" | tr '\n' ' ')"
[[ -z "$duplicate_expected" ]] || fail "duplicate manifest expected path(s): $duplicate_expected"

find "$expected_dir" -maxdepth 1 -type f -name '*.txt' | sort > "$actual_expected"

missing_classification="$(comm -23 "$actual_expected" "$manifest_expected" | tr '\n' ' ')"
[[ -z "$missing_classification" ]] || fail "expected fixture is not classified: $missing_classification"

extra_classification="$(comm -13 "$actual_expected" "$manifest_expected" | tr '\n' ' ')"
[[ -z "$extra_classification" ]] || fail "manifest classifies non-inventory file(s): $extra_classification"

while IFS=$'\t' read -r label expected moon_gate oracle_gate notes; do
  [[ -n "${expected:-}" ]] || fail "row $label has empty expected path"
  [[ -n "${moon_gate:-}" ]] || fail "row $label has empty moon gate"
  [[ -n "${oracle_gate:-}" ]] || fail "row $label has empty oracle gate"
  [[ -f "$expected" ]] || fail "row $label points to missing expected file: $expected"

  case "$moon_gate" in
    byte | byte-exception | semantic | error | oracle-only)
      ;;
    *)
      fail "row $label has unknown moon gate: $moon_gate"
      ;;
  esac

  case "$oracle_gate" in
    oracle-byte | oracle-byte-exception | oracle-error)
      ;;
    *)
      fail "row $label has unknown oracle gate: $oracle_gate"
      ;;
  esac

  case "$moon_gate" in
    byte | byte-exception)
      if ! rg -F "$expected" tools/check_moon_wgsl_byte_parity.sh >/dev/null; then
        fail "byte-gated row $label is missing from tools/check_moon_wgsl_byte_parity.sh"
      fi
      ;;
    error)
      if ! rg -F "$label" tools/check_moon_wgsl_error_parity.sh >/dev/null; then
        fail "error-gated row $label is missing from tools/check_moon_wgsl_error_parity.sh"
      fi
      ;;
    semantic | oracle-only)
      [[ -n "${notes:-}" ]] || fail "classified row $label needs an explicit note"
      ;;
  esac

  if [[ "$moon_gate" == "byte-exception" || "$oracle_gate" == *"exception"* ]]; then
    [[ -n "${notes:-}" ]] || fail "exception row $label needs an explicit note"
  fi

  if ! rg -F "$expected" tools/check_preprocess_parity.sh >/dev/null && \
     ! rg -F "$label" tools/check_preprocess_parity.sh >/dev/null; then
    fail "oracle row $label is not referenced by tools/check_preprocess_parity.sh"
  fi
done < "$rows"

echo "naga_oil parity inventory passed"
