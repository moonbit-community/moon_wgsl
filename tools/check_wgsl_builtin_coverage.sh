#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

coverage_manifest="${WGSL_BUILTIN_COVERAGE_MANIFEST:-testdata/wgsl_builtin_coverage_manifest.tsv}"
corpus_manifest="${WGSL_CORPUS_MANIFEST:-testdata/wgsl_corpus_manifest.tsv}"

fail() {
  printf 'WGSL builtin coverage failed: %s\n' "$*" >&2
  exit 1
}

contains_csv() {
  local csv="$1"
  local needle="$2"
  local item
  IFS=',' read -r -a items <<< "$csv"
  for item in "${items[@]}"; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

[[ -f "$coverage_manifest" ]] || fail "missing coverage manifest: $coverage_manifest"
[[ -f "$corpus_manifest" ]] || fail "missing corpus manifest: $corpus_manifest"

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

coverage_rows="$tmpdir/coverage.tsv"
corpus_rows="$tmpdir/corpus.tsv"
known_builtins="$tmpdir/known_builtins.txt"
covered_builtins="$tmpdir/covered_builtins.txt"
missing_builtins="$tmpdir/missing_builtins.txt"
extra_builtins="$tmpdir/extra_builtins.txt"

awk -F '\t' '
  NF == 0 { next }
  $1 == "" { next }
  $1 ~ /^#/ { next }
  $1 == "builtin" { next }
  NF < 6 {
    printf("coverage row has %d field(s), expected 6: %s\n", NF, $0) > "/dev/stderr"
    exit 1
  }
  { print }
' "$coverage_manifest" > "$coverage_rows"

awk -F '\t' '
  NF == 0 { next }
  $1 == "" { next }
  $1 ~ /^#/ { next }
  $1 == "id" { next }
  NF < 9 {
    printf("corpus row has %d field(s), expected 9: %s\n", NF, $0) > "/dev/stderr"
    exit 1
  }
  { print }
' "$corpus_manifest" > "$corpus_rows"

corpus_field() {
  local id="$1"
  local field="$2"
  awk -F '\t' -v id="$id" -v field="$field" '
    $1 == id {
      if (field == "kind") print $2
      else if (field == "input") print $3
      else if (field == "stages") print $8
      found = 1
      exit 0
    }
    END {
      if (!found) exit 1
    }
  ' "$corpus_rows"
}

extract_lowerer_builtin_names() {
  awk '
    /fn wgsl_ir_math_function_from_name/,/^}/ {
      if (match($0, /"[A-Za-z][A-Za-z0-9]*"/)) print substr($0, RSTART + 1, RLENGTH - 2)
    }
    /fn wgsl_ir_derivative_function_from_name/,/^}/ {
      if (match($0, /"[A-Za-z][A-Za-z0-9]*"/)) print substr($0, RSTART + 1, RLENGTH - 2)
    }
    /fn wgsl_ir_relational_function_from_name/,/^}/ {
      if (match($0, /"[A-Za-z][A-Za-z0-9]*"/)) print substr($0, RSTART + 1, RLENGTH - 2)
    }
    /fn wgsl_ir_atomic_function_from_name/,/^}/ {
      if (match($0, /"[A-Za-z][A-Za-z0-9]*"/)) print substr($0, RSTART + 1, RLENGTH - 2)
    }
  ' ir/wgsl_lower_builtins.mbt
  rg -o '"(texture[A-Za-z0-9]+|rayQuery[A-Za-z0-9]+|subgroup[A-Za-z0-9]+|quad[A-Za-z0-9]+|workgroupBarrier|storageBarrier|textureBarrier|arrayLength)"' \
    ir/wgsl_lower.mbt | tr -d '"'
}

extract_lowerer_builtin_names | sed '/^$/d' | sort -u > "$known_builtins"
cut -f1 "$coverage_rows" | sort > "$covered_builtins"

duplicate_builtins="$(uniq -d "$covered_builtins" | tr '\n' ' ')"
[[ -z "$duplicate_builtins" ]] || fail "duplicate coverage builtin(s): $duplicate_builtins"

comm -23 "$known_builtins" "$covered_builtins" > "$missing_builtins"
comm -13 "$known_builtins" "$covered_builtins" > "$extra_builtins"
if [[ -s "$missing_builtins" ]]; then
  cat "$missing_builtins" >&2
  fail "lowerer builtin(s) missing from coverage manifest"
fi
if [[ -s "$extra_builtins" ]]; then
  cat "$extra_builtins" >&2
  fail "coverage manifest references builtin(s) not owned by lowerer builtin dispatch"
fi

source_for_case() {
  local id="$1"
  local kind
  local input
  kind="$(corpus_field "$id" kind)" || fail "coverage row points to missing corpus id: $id"
  input="$(corpus_field "$id" input)" || fail "coverage row points to missing corpus id: $id"
  local safe_id
  safe_id="$(printf '%s' "$id" | tr -c 'A-Za-z0-9_-' '_')"
  local output="$tmpdir/$safe_id.source.wgsl"
  if [[ -f "$output" ]]; then
    printf '%s\n' "$output"
    return 0
  fi
  case "$kind" in
    file)
      [[ -f "$input" ]] || fail "coverage case $id points to missing source file: $input"
      cp "$input" "$output"
      printf '%s\n' "$output"
      ;;
    generated)
      moon run tools/wgsl_validation_cases -- "$input" > "$output"
      printf '%s\n' "$output"
      ;;
    *)
      fail "coverage case $id uses unsupported source materialization kind: $kind"
      ;;
  esac
}

row_count=0
naga_ir_count=0
ir_only_count=0
categories_file="$tmpdir/categories.txt"
while IFS=$'\t' read -r builtin category corpus_id required_stage token notes; do
  [[ -n "$notes" ]] || fail "coverage row $builtin must have notes"
  corpus_stages="$(corpus_field "$corpus_id" stages)" ||
    fail "coverage row $builtin points to missing corpus id: $corpus_id"
  contains_csv "$corpus_stages" "$required_stage" ||
    fail "coverage row $builtin requires stage $required_stage but $corpus_id has stages $corpus_stages"
  source="$(source_for_case "$corpus_id")"
  rg -F "$token" "$source" >/dev/null ||
    fail "coverage row $builtin token '$token' not found in materialized corpus source $corpus_id"
  row_count=$((row_count + 1))
  if [[ "$required_stage" == "naga-ir" ]]; then
    naga_ir_count=$((naga_ir_count + 1))
  elif [[ "$required_stage" == "ir" ]]; then
    ir_only_count=$((ir_only_count + 1))
  fi
  printf '%s\n' "$category" >> "$categories_file"
done < "$coverage_rows"

((row_count > 0)) || fail "coverage manifest contains no runnable rows"
((naga_ir_count > 0)) || fail "coverage manifest must include Naga-validated IR rows"
((ir_only_count > 0)) || fail "coverage manifest must explicitly track oracle-blocked IR-only rows"

for required_category in numeric integer derivative relational atomic barrier texture storage ray-query subgroup; do
  rg -Fx "$required_category" "$categories_file" >/dev/null ||
    fail "coverage manifest has no $required_category builtin category"
done

echo "WGSL builtin coverage passed: builtins=$row_count naga-ir=$naga_ir_count ir-only=$ir_only_count"
