#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

taxonomy="${EXTERNAL_NAGA_OIL_COMPOSE_DRIFT_TAXONOMY:-testdata/external_naga_oil_compose_drift_taxonomy.tsv}"
writer_manifest="${EXTERNAL_NAGA_OIL_COMPOSE_PARITY_WRITER_DRIFT_MANIFEST:-testdata/external_naga_oil_compose_writer_drift.tsv}"
byte_manifest="${EXTERNAL_NAGA_OIL_COMPOSE_PARITY_BYTE_DRIFT_MANIFEST:-testdata/external_naga_oil_compose_byte_drift.tsv}"

fail() {
  printf 'external naga-oil drift taxonomy gate failed: %s\n' "$*" >&2
  exit 1
}

[[ -f "$taxonomy" ]] || fail "missing taxonomy: $taxonomy"
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

awk -F '\t' '
  $0 ~ /^($|#)/ { next }
  NR == 1 && $1 == "manifest" { next }
  NF != 5 {
    printf("drift taxonomy row has %d field(s), expected 5: %s\n", NF, $0) > "/dev/stderr"
    exit 1
  }
  $1 != "writer-drift" && $1 != "byte-drift" {
    printf("unknown drift taxonomy manifest kind: %s\n", $1) > "/dev/stderr"
    exit 1
  }
  $2 == "" || $3 == "" || $4 == "" || $5 == "" {
    printf("drift taxonomy row must include category, expected_count, tracker, and reason: %s\n", $0) > "/dev/stderr"
    exit 1
  }
  $3 !~ /^[0-9]+$/ {
    printf("drift taxonomy expected_count must be numeric: %s\n", $0) > "/dev/stderr"
    exit 1
  }
  { counts[$1] += $3 }
  END {
    print "writer-drift\t" (counts["writer-drift"] + 0)
    print "byte-drift\t" (counts["byte-drift"] + 0)
  }
' "$taxonomy" > _build/drift-taxonomy-counts.actual

taxonomy_writer_count="$(awk -F '\t' '$1 == "writer-drift" { print $2 }' _build/drift-taxonomy-counts.actual)"
taxonomy_byte_count="$(awk -F '\t' '$1 == "byte-drift" { print $2 }' _build/drift-taxonomy-counts.actual)"

[[ "$taxonomy_writer_count" == "$writer_count" ]] ||
  fail "writer drift taxonomy count $taxonomy_writer_count does not match manifest count $writer_count"
[[ "$taxonomy_byte_count" == "$byte_count" ]] ||
  fail "byte drift taxonomy count $taxonomy_byte_count does not match manifest count $byte_count"

printf 'external naga-oil drift taxonomy gate passed: writer-drift=%s byte-drift=%s\n' "$writer_count" "$byte_count"
