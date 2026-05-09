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
manifest_byte_labels="$tmpdir/manifest_byte_labels.txt"
manifest_error_labels="$tmpdir/manifest_error_labels.txt"
executed_byte_labels="$tmpdir/executed_byte_labels.txt"
executed_error_labels="$tmpdir/executed_error_labels.txt"

awk -F '\t' '
  NF == 0 { next }
  $1 == "" { next }
  $1 ~ /^#/ { next }
  $1 == "label" { next }
  { print }
' "$manifest" > "$rows"

cut -f1 "$rows" | sort > "$manifest_labels"
cut -f2 "$rows" | sort > "$manifest_expected"
awk -F '\t' '$3 == "byte" { print $1 }' "$rows" | sort > "$manifest_byte_labels"
awk -F '\t' '$3 == "error" { print $1 }' "$rows" | sort > "$manifest_error_labels"
tools/check_moon_wgsl_byte_parity.sh --list | sort > "$executed_byte_labels"
tools/check_moon_wgsl_error_parity.sh --list | sort > "$executed_error_labels"

duplicate_labels="$(uniq -d "$manifest_labels" | tr '\n' ' ')"
[[ -z "$duplicate_labels" ]] || fail "duplicate manifest label(s): $duplicate_labels"

duplicate_expected="$(uniq -d "$manifest_expected" | tr '\n' ' ')"
[[ -z "$duplicate_expected" ]] || fail "duplicate manifest expected path(s): $duplicate_expected"

find "$expected_dir" -maxdepth 1 -type f -name '*.txt' | sort > "$actual_expected"

missing_classification="$(comm -23 "$actual_expected" "$manifest_expected" | tr '\n' ' ')"
[[ -z "$missing_classification" ]] || fail "expected fixture is not classified: $missing_classification"

extra_classification="$(comm -13 "$actual_expected" "$manifest_expected" | tr '\n' ' ')"
[[ -z "$extra_classification" ]] || fail "manifest classifies non-inventory file(s): $extra_classification"

missing_byte_execution="$(comm -23 "$manifest_byte_labels" "$executed_byte_labels" | tr '\n' ' ')"
[[ -z "$missing_byte_execution" ]] || fail "byte-gated manifest row(s) are not executed: $missing_byte_execution"

extra_byte_execution="$(comm -13 "$manifest_byte_labels" "$executed_byte_labels" | tr '\n' ' ')"
[[ -z "$extra_byte_execution" ]] || fail "byte parity script executes row(s) not declared in manifest: $extra_byte_execution"

missing_error_execution="$(comm -23 "$manifest_error_labels" "$executed_error_labels" | tr '\n' ' ')"
[[ -z "$missing_error_execution" ]] || fail "error-gated manifest row(s) are not executed: $missing_error_execution"

extra_error_execution="$(comm -13 "$manifest_error_labels" "$executed_error_labels" | tr '\n' ' ')"
[[ -z "$extra_error_execution" ]] || fail "error parity script executes row(s) not declared in manifest: $extra_error_execution"

while IFS=$'\t' read -r label expected moon_gate oracle_gate notes; do
  [[ -n "${expected:-}" ]] || fail "row $label has empty expected path"
  [[ -n "${moon_gate:-}" ]] || fail "row $label has empty moon gate"
  [[ -n "${oracle_gate:-}" ]] || fail "row $label has empty oracle gate"
  [[ -f "$expected" ]] || fail "row $label points to missing expected file: $expected"

  case "$moon_gate" in
    byte | semantic | error | oracle-only)
      ;;
    *)
      fail "row $label has unknown moon gate: $moon_gate"
      ;;
  esac

  case "$oracle_gate" in
    oracle-byte | oracle-error)
      ;;
    *)
      fail "row $label has unknown oracle gate: $oracle_gate"
      ;;
  esac

  case "$moon_gate" in
    byte | error)
      ;;
    semantic | oracle-only)
      [[ -n "${notes:-}" ]] || fail "classified row $label needs an explicit note"
      ;;
  esac

  if ! rg -F "$expected" tools/check_preprocess_parity.sh >/dev/null && \
     ! rg -F "$label" tools/check_preprocess_parity.sh >/dev/null; then
    fail "oracle row $label is not referenced by tools/check_preprocess_parity.sh"
  fi
done < "$rows"

echo "naga_oil parity inventory passed"
