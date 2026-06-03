#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

taxonomy="${EXTERNAL_NAGA_OIL_COMPOSE_DRIFT_TAXONOMY:-testdata/external_naga_oil_compose_drift_taxonomy.tsv}"
trace_roots="${EXTERNAL_NAGA_OIL_COMPOSE_BYTE_TRACE_ROOTS:-testdata/external_naga_oil_compose_byte_trace_roots.tsv}"
writer_manifest="${EXTERNAL_NAGA_OIL_COMPOSE_PARITY_WRITER_DRIFT_MANIFEST:-testdata/external_naga_oil_compose_writer_drift.tsv}"
byte_manifest="${EXTERNAL_NAGA_OIL_COMPOSE_PARITY_BYTE_DRIFT_MANIFEST:-testdata/external_naga_oil_compose_byte_drift.tsv}"

fail() {
  printf 'external naga-oil drift taxonomy gate failed: %s\n' "$*" >&2
  exit 1
}

[[ -f "$taxonomy" ]] || fail "missing taxonomy: $taxonomy"
[[ -f "$trace_roots" ]] || fail "missing byte trace root classification: $trace_roots"
[[ -f "$writer_manifest" ]] || fail "missing writer drift manifest: $writer_manifest"
[[ -f "$byte_manifest" ]] || fail "missing byte drift manifest: $byte_manifest"

count_manifest_rows() {
  local file="$1"
  awk -F '\t' '
    $0 ~ /^($|#)/ { next }
    $1 == "id" { next }
    { count += 1 }
    END { print count + 0 }
  ' "$file"
}

writer_count="$(count_manifest_rows "$writer_manifest")"
byte_count="$(count_manifest_rows "$byte_manifest")"

((writer_count == 0)) ||
  fail "writer/order/name drift is no longer allowlisted; keep $writer_manifest empty and fix WGSL-283 regressions structurally"

mkdir -p _build
expected_keys="$(mktemp "${TMPDIR:-/tmp}/moon_wgsl_drift_expected.XXXXXX")"
actual_keys="$(mktemp "${TMPDIR:-/tmp}/moon_wgsl_drift_actual.XXXXXX")"
counts_file="$(mktemp "${TMPDIR:-/tmp}/moon_wgsl_drift_counts.XXXXXX")"
trap 'rm -f "$expected_keys" "$actual_keys" "$counts_file"' EXIT

{
  awk -F '\t' -v manifest="writer-drift" '
    $0 ~ /^($|#)/ { next }
    $1 == "id" { next }
    { print manifest "\t" $1 "\t" $2 }
  ' "$writer_manifest"
  awk -F '\t' -v manifest="byte-drift" '
    $0 ~ /^($|#)/ { next }
    $1 == "id" { next }
    { print manifest "\t" $1 "\t" $2 }
  ' "$byte_manifest"
} | sort > "$expected_keys"

awk -F '\t' '
  $0 ~ /^($|#)/ { next }
  NR == 1 && $1 == "manifest" { next }
  NF != 6 {
    printf("drift taxonomy row has %d field(s), expected 6: %s\n", NF, $0) > "/dev/stderr"
    exit 1
  }
  $1 != "writer-drift" && $1 != "byte-drift" {
    printf("unknown drift taxonomy manifest kind: %s\n", $1) > "/dev/stderr"
    exit 1
  }
  $2 == "" || $3 == "" || $4 == "" || $5 == "" || $6 == "" {
    printf("drift taxonomy row must include manifest, id, rel_path, category, tracker, and reason: %s\n", $0) > "/dev/stderr"
    exit 1
  }
  $5 !~ /^WGSL-[0-9]+$/ {
    printf("drift taxonomy tracker must be a WGSL issue id: %s\n", $0) > "/dev/stderr"
    exit 1
  }
  {
    key = $1 "\t" $2 "\t" $3
    if (seen[key]++) {
      printf("duplicate drift taxonomy row for %s\n", key) > "/dev/stderr"
      exit 1
    }
    counts[$1] += 1
    print key
  }
  END {
    print "writer-drift\t" (counts["writer-drift"] + 0)
    print "byte-drift\t" (counts["byte-drift"] + 0)
  }
' "$taxonomy" > "$counts_file"

awk -F '\t' 'NF == 3 { print $0 }' "$counts_file" | sort > "$actual_keys"
awk -F '\t' 'NF == 2 { print $0 }' "$counts_file" > _build/drift-taxonomy-counts.actual

if ! diff -u "$expected_keys" "$actual_keys" > _build/drift-taxonomy-keys.diff; then
  cat _build/drift-taxonomy-keys.diff >&2
  fail "drift taxonomy rows must exactly match writer and byte drift manifest cases"
fi

taxonomy_writer_count="$(awk -F '\t' '$1 == "writer-drift" { print $2 }' _build/drift-taxonomy-counts.actual)"
taxonomy_byte_count="$(awk -F '\t' '$1 == "byte-drift" { print $2 }' _build/drift-taxonomy-counts.actual)"

[[ "$taxonomy_writer_count" == "$writer_count" ]] ||
  fail "writer drift taxonomy count $taxonomy_writer_count does not match manifest count $writer_count"
[[ "$taxonomy_byte_count" == "$byte_count" ]] ||
  fail "byte drift taxonomy count $taxonomy_byte_count does not match manifest count $byte_count"

awk -F '\t' '
  FNR == NR {
    if ($0 ~ /^($|#)/ || $1 == "id") {
      next
    }
    byte[$1 "\t" $2] = 1
    next
  }
  $0 ~ /^($|#)/ { next }
  FNR == 1 && $1 == "id" { next }
  NF != 9 {
    printf("byte trace root row has %d field(s), expected 9: %s\n", NF, $0) > "/dev/stderr"
    exit 1
  }
  $1 == "" || $2 == "" || $3 == "" || $4 == "" || $5 == "" || $6 == "" || $7 == "" || $8 == "" || $9 == "" {
    printf("byte trace root row must include id, rel_path, trace_label, first_index, owner, expected, actual, category, and reason: %s\n", $0) > "/dev/stderr"
    exit 1
  }
  $4 !~ /^[0-9]+$/ {
    printf("byte trace root first_index must be numeric: %s\n", $0) > "/dev/stderr"
    exit 1
  }
  !byte[$1 "\t" $2] {
    printf("byte trace root row is not backed by current byte drift manifest: %s\n", $0) > "/dev/stderr"
    exit 1
  }
  {
    key = $1 "\t" $2
    if (seen[key]++) {
      printf("duplicate byte trace root row for %s\n", key) > "/dev/stderr"
      exit 1
    }
    count += 1
  }
  END {
    if (count < 5) {
      printf("byte trace root classification must contain at least 5 current byte drift rows, got %d\n", count + 0) > "/dev/stderr"
      exit 1
    }
  }
' "$byte_manifest" "$trace_roots"

printf 'external naga-oil drift taxonomy gate passed: writer-drift=%s byte-drift=%s\n' "$writer_count" "$byte_count"
