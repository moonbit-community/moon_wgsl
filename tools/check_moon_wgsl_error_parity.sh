#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

manifest="${MOON_WGSL_ERROR_PARITY_MANIFEST:-testdata/naga_oil_upstream/compose_tests/error_parity_cases.tsv}"
parity_manifest="${MOON_WGSL_UPSTREAM_PARITY_MANIFEST:-testdata/naga_oil_upstream/compose_tests/parity_manifest.tsv}"
failure_dir="${MOON_WGSL_ERROR_PARITY_FAILURE_DIR:-_build/parity/moon_wgsl_error_parity}"

fail() {
  printf 'moon_wgsl error parity failed: %s\n' "$*" >&2
  exit 1
}

rows_file() {
  awk -F '\t' '$0 !~ /^($|#)/ { print }' "$manifest"
}

if [[ "${1:-}" == "--list" ]]; then
  rows_file | cut -f1
  exit 0
fi

[[ -f "$manifest" ]] || fail "missing manifest: $manifest"
[[ -f "$parity_manifest" ]] || fail "missing upstream parity manifest: $parity_manifest"

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

rows="$tmpdir/rows.tsv"
rows_file > "$rows"

if [[ ! -s "$rows" ]]; then
  fail "manifest has no negative diagnostic rows"
fi

awk -F '\t' '
  NF != 6 {
    printf("error parity row has %d field(s), expected 6: %s\n", NF, $0) > "/dev/stderr"
    exit 1
  }
  $1 == "" || $2 == "" || $3 == "" || $4 == "" || $5 == "" || $6 == "" {
    printf("error parity row contains empty required field: %s\n", $0) > "/dev/stderr"
    exit 1
  }
' "$rows" || fail "manifest schema validation failed"

duplicate_labels="$(cut -f1 "$rows" | sort | uniq -d | tr '\n' ' ')"
[[ -z "$duplicate_labels" ]] || fail "duplicate manifest label(s): $duplicate_labels"

awk -F '\t' '$0 !~ /^($|#)/ && $3 == "error" { print $1 }' "$parity_manifest" | sort > "$tmpdir/parity-error-labels"
cut -f1 "$rows" | sort > "$tmpdir/error-labels"
if ! diff -u "$tmpdir/parity-error-labels" "$tmpdir/error-labels" > "$tmpdir/error-labels.diff"; then
  echo "error parity manifest labels must exactly match upstream parity manifest error rows" >&2
  sed -n '1,160p' "$tmpdir/error-labels.diff" >&2
  fail "manifest label mismatch"
fi

rm -rf "$failure_dir"
mkdir -p "$failure_dir"

write_diagnostic_summary() {
  local input="$1"
  local output="$2"
  local bytes_hash
  bytes_hash="$(shasum -a 256 "$input" | awk '{ print $1 }')"
  awk -v bytes_hash="$bytes_hash" '
    BEGIN {
      message = ""
      category = ""
      location = ""
    }
    message == "" && NF > 0 {
      message = $0
      category = $0
      sub(/:.*/, "", category)
    }
    /┌─ / && location == "" {
      location = $0
      sub(/^.*┌─ /, "", location)
    }
    END {
      printf("category\t%s\n", category)
      printf("message\t%s\n", message)
      printf("location\t%s\n", location)
      printf("bytes_sha256\t%s\n", bytes_hash)
    }
  ' "$input" > "$output"
}

run_oracle_error_case() {
  local label="$1"
  local fixture_root="$2"
  local entry="$3"
  local file_path_prefix="$4"
  local args_csv="$5"
  local output="$6"
  local args=()
  if [[ "$args_csv" != "-" ]]; then
    IFS=',' read -r -a args <<< "$args_csv"
  fi
  if cargo run --quiet --manifest-path tools/naga_oil_oracle/Cargo.toml --bin naga_oil_oracle -- \
    --fixture-root "$fixture_root" \
    --entry "$entry" \
    --file-path-prefix "$file_path_prefix" \
    --error-output "$output" \
    "${args[@]+"${args[@]}"}" \
    > "$failure_dir/$label.oracle.stdout" \
    2> "$failure_dir/$label.oracle.stderr"; then
    fail "expected pinned naga-oil oracle to fail for $label, but it succeeded"
  fi
  [[ -s "$output" ]] || fail "oracle produced no diagnostic bytes for $label"
}

run_moon_error_case() {
  local label="$1"
  local fixture_root="$2"
  local entry="$3"
  local file_path_prefix="$4"
  local args_csv="$5"
  local output="$6"
  local args=()
  if [[ "$args_csv" != "-" ]]; then
    IFS=',' read -r -a args <<< "$args_csv"
  fi
  moon run tools/compose_case -- \
    --fixture-root "$fixture_root" \
    --entry "$entry" \
    --file-path-prefix "$file_path_prefix" \
    --expect-error \
    --error-output "$output" \
    "${args[@]+"${args[@]}"}" \
    > "$failure_dir/$label.moon.stdout" \
    2> "$failure_dir/$label.moon.stderr"
  if grep -Fq "UNEXPECTED_SUCCESS" "$output"; then
    fail "expected moon_wgsl to fail for $label, but compose succeeded"
  fi
  [[ -s "$output" ]] || fail "moon_wgsl produced no diagnostic bytes for $label"
}

case_count=0
while IFS=$'\t' read -r label fixture_root entry file_path_prefix args_csv notes; do
  [[ -d "$fixture_root" ]] || fail "case $label fixture root does not exist: $fixture_root"
  [[ -f "$fixture_root/$entry" ]] || fail "case $label entry does not exist: $fixture_root/$entry"
  echo "== moon_wgsl diagnostic parity: $label =="
  oracle_output="$failure_dir/$label.oracle.txt"
  moon_output="$failure_dir/$label.moon.txt"
  oracle_summary="$failure_dir/$label.oracle.summary.tsv"
  moon_summary="$failure_dir/$label.moon.summary.tsv"
  run_oracle_error_case "$label" "$fixture_root" "$entry" "$file_path_prefix" "$args_csv" "$oracle_output"
  run_moon_error_case "$label" "$fixture_root" "$entry" "$file_path_prefix" "$args_csv" "$moon_output"
  write_diagnostic_summary "$oracle_output" "$oracle_summary"
  write_diagnostic_summary "$moon_output" "$moon_summary"
  if ! diff -u "$oracle_summary" "$moon_summary" > "$failure_dir/$label.summary.diff"; then
    sed -n '1,120p' "$failure_dir/$label.summary.diff" >&2
    fail "machine-readable diagnostic summary drift for $label"
  fi
  if ! diff -u "$oracle_output" "$moon_output" > "$failure_dir/$label.bytes.diff"; then
    sed -n '1,160p' "$failure_dir/$label.bytes.diff" >&2
    fail "rendered diagnostic byte drift for $label"
  fi
  case_count=$((case_count + 1))
done < "$rows"

echo "moon_wgsl diagnostic parity passed: cases=$case_count"
