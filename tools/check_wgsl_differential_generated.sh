#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

manifest="${WGSL_DIFFERENTIAL_GENERATED_MANIFEST:-testdata/wgsl_differential_generated_manifest.tsv}"
generator="${WGSL_DIFFERENTIAL_GENERATED_GENERATOR:-tools/generate_wgsl_differential_case.mjs}"

fail() {
  printf 'WGSL differential generated gate failed: %s\n' "$*" >&2
  exit 1
}

[[ -f "$manifest" ]] || fail "missing manifest: $manifest"
[[ -f "$generator" ]] || fail "missing generator: $generator"

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

assert_tokens() {
  local id="$1"
  local emitted="$2"
  local checks="$3"
  local token
  [[ "$checks" != "-" && -n "$checks" ]] || return 0
  IFS=',' read -r -a tokens <<< "$checks"
  for token in "${tokens[@]}"; do
    [[ -n "$token" ]] || continue
    rg -F "$token" "$emitted" >/dev/null ||
      fail "case $id emitted WGSL lost required token: $token"
  done
}

rows="$tmpdir/rows.tsv"
awk -F '\t' '
  NF == 0 { next }
  $1 == "" { next }
  $1 ~ /^#/ { next }
  $1 == "id" { next }
  NF < 5 {
    printf("manifest row has %d field(s), expected 5: %s\n", NF, $0) > "/dev/stderr"
    exit 1
  }
  { print }
' "$manifest" > "$rows"

manifest_ids="$tmpdir/manifest.ids"
generator_ids="$tmpdir/generator.ids"
cut -f1 "$rows" | sort > "$manifest_ids"
node "$generator" --list | sort > "$generator_ids"
if ! diff -u "$generator_ids" "$manifest_ids" > "$tmpdir/generated-case-ids.diff"; then
  cat "$tmpdir/generated-case-ids.diff" >&2
  fail "generated differential manifest and generator case ids diverged"
fi

case_count=0
categories_file="$tmpdir/categories.txt"
while IFS=$'\t' read -r id category capabilities checks notes; do
  [[ -n "$category" && "$category" != "-" ]] || fail "case $id must have a coverage category"
  [[ -n "$notes" ]] || fail "case $id must have notes"
  source="$tmpdir/$id.source.wgsl"
  emitted="$tmpdir/$id.emitted.wgsl"
  echo "== WGSL generated differential: $id =="
  node "$generator" "$id" > "$source"
  moon run tools/ir_roundtrip -- --input "$source" --output "$emitted" >/dev/null
  moon run tools/ir_roundtrip -- --mode parse --input "$emitted" --output "$tmpdir/$id.parse.out" >/dev/null
  assert_tokens "$id" "$emitted" "$checks"
  printf '%s\n' "$category" >> "$categories_file"
  case_count=$((case_count + 1))
done < "$rows"

((case_count > 0)) || fail "manifest contains no generated differential cases"
for required_category in builtin control-flow entry expression layout literal pointer resource statement type; do
  rg -Fx "$required_category" "$categories_file" >/dev/null ||
    fail "manifest has no generated differential case in category: $required_category"
done

echo "WGSL generated differential gate passed: cases=$case_count"
