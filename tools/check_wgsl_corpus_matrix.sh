#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

manifest="${WGSL_CORPUS_MANIFEST:-testdata/wgsl_corpus_manifest.tsv}"
runtime_valid_compose_manifest="${WGSL_CORPUS_RUNTIME_VALID_COMPOSE_MANIFEST:-testdata/wgsl_corpus_runtime_valid_compose.txt}"
expected_case_count="${WGSL_CORPUS_EXPECTED_CASES:-52}"
expected_parse_count="${WGSL_CORPUS_EXPECTED_PARSE_CASES:-41}"
expected_ir_count="${WGSL_CORPUS_EXPECTED_IR_CASES:-45}"
expected_compose_count="${WGSL_CORPUS_EXPECTED_COMPOSE_CASES:-19}"
expected_runtime_valid_compose_count="${WGSL_CORPUS_EXPECTED_RUNTIME_VALID_COMPOSE_CASES:-2}"

fail() {
  printf 'WGSL corpus matrix failed: %s\n' "$*" >&2
  exit 1
}

[[ -f "$manifest" ]] || fail "missing manifest: $manifest"
[[ -f "$runtime_valid_compose_manifest" ]] ||
  fail "missing runtime-valid compose manifest: $runtime_valid_compose_manifest"

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

rows="$tmpdir/rows.tsv"
ids="$tmpdir/ids.txt"
runtime_valid_compose_ids="$tmpdir/runtime-valid-compose.ids"

awk -F '\t' '
  NF == 0 { next }
  $1 == "" { next }
  $1 ~ /^#/ { next }
  $1 == "id" { next }
  NF != 9 {
    printf("manifest row has %d field(s), expected 9: %s\n", NF, $0) > "/dev/stderr"
    exit 1
  }
  { print }
' "$manifest" > "$rows"

cut -f1 "$rows" | sort > "$ids"
duplicate_ids="$(uniq -d "$ids" | tr '\n' ' ')"
[[ -z "$duplicate_ids" ]] || fail "duplicate manifest id(s): $duplicate_ids"
awk -F '\t' '
  $0 ~ /^($|#)/ { next }
  NF != 1 {
    printf("runtime-valid compose row has %d field(s), expected 1: %s\n", NF, $0) > "/dev/stderr"
    exit 1
  }
  $1 == "" {
    printf("runtime-valid compose row must include a corpus id: %s\n", $0) > "/dev/stderr"
    exit 1
  }
  { print $1 }
' "$runtime_valid_compose_manifest" | sort > "$runtime_valid_compose_ids"
duplicate_runtime_valid_ids="$(uniq -d "$runtime_valid_compose_ids" | tr '\n' ' ')"
[[ -z "$duplicate_runtime_valid_ids" ]] ||
  fail "duplicate runtime-valid compose id(s): $duplicate_runtime_valid_ids"
runtime_valid_compose_count="$(wc -l < "$runtime_valid_compose_ids" | tr -d ' ')"
((runtime_valid_compose_count == expected_runtime_valid_compose_count)) ||
  fail "runtime-valid compose manifest contains $runtime_valid_compose_count id(s); expected exactly $expected_runtime_valid_compose_count"

while IFS= read -r runtime_valid_id; do
  rg -Fx "$runtime_valid_id" "$ids" >/dev/null ||
    fail "runtime-valid compose id is not present in corpus manifest: $runtime_valid_id"
done < "$runtime_valid_compose_ids"

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

parse_wgsl() {
  local id="$1"
  local source="$2"
  moon run tools/ir_roundtrip -- \
    --mode parse \
    --input "$source" \
    --output "$tmpdir/$id.parse.out" >/dev/null
}

ir_roundtrip_wgsl() {
  local id="$1"
  local source="$2"
  local emitted="$tmpdir/$id.ir.wgsl"
  moon run tools/ir_roundtrip -- --input "$source" --output "$emitted" >/dev/null
  moon run tools/ir_roundtrip -- \
    --mode parse \
    --input "$emitted" \
    --output "$tmpdir/$id.ir.parse.out" >/dev/null
  printf '%s\n' "$emitted"
}

materialize_source() {
  local id="$1"
  local kind="$2"
  local input="$3"
  local entry="$4"
  local defines="$5"
  local additional_imports="$6"
  local output="$tmpdir/$id.source.wgsl"
  local args=()
  local item

  case "$kind" in
    file)
      [[ -f "$input" ]] || fail "file case $id points to missing input: $input"
      printf '%s\n' "$input"
      ;;
    generated)
      moon run tools/wgsl_validation_cases -- "$input" > "$output"
      printf '%s\n' "$output"
      ;;
    compose)
      [[ -d "$input" ]] || fail "compose case $id points to missing fixture root: $input"
      [[ "$entry" != "-" && -n "$entry" ]] || fail "compose case $id has no entry"
      if [[ "$defines" != "-" && -n "$defines" ]]; then
        IFS=',' read -r -a items <<< "$defines"
        for item in "${items[@]}"; do
          [[ -n "$item" ]] || continue
          args+=("--def" "$item")
        done
      fi
      if [[ "$additional_imports" != "-" && -n "$additional_imports" ]]; then
        IFS=',' read -r -a items <<< "$additional_imports"
        for item in "${items[@]}"; do
          [[ -n "$item" ]] || continue
          args+=("--additional-import" "$item")
        done
      fi
      if rg -Fx "$id" "$runtime_valid_compose_ids" >/dev/null; then
        args+=("--runtime-valid")
      fi
      moon run tools/compose_case -- \
        --fixture-root "$input" \
        --entry "$entry" \
        "${args[@]+"${args[@]}"}" \
        --output "$output"
      printf '%s\n' "$output"
      ;;
    *)
      fail "case $id has unknown kind: $kind"
      ;;
  esac
}

case_count=0
compose_count=0
parse_count=0
ir_count=0

while IFS=$'\t' read -r id kind input entry defines additional_imports capabilities stages notes; do
  [[ -n "$notes" ]] || fail "case $id must have a note"
  echo "== WGSL corpus matrix: $id =="

  IFS=',' read -r -a stage_items <<< "$stages"
  for stage in "${stage_items[@]}"; do
    case "$stage" in
      compose | parse | ir)
        ;;
      *)
        fail "case $id has unknown stage: $stage"
        ;;
    esac
  done

  source="$(materialize_source "$id" "$kind" "$input" "$entry" "$defines" "$additional_imports")"
  case_count=$((case_count + 1))

  if contains_csv "$stages" "compose"; then
    [[ "$kind" == "compose" ]] || fail "case $id requests compose stage but is not a compose case"
    compose_count=$((compose_count + 1))
  fi

  if contains_csv "$stages" "parse"; then
    parse_wgsl "$id" "$source"
    parse_count=$((parse_count + 1))
  fi

  if contains_csv "$stages" "ir"; then
    emitted="$(ir_roundtrip_wgsl "$id" "$source")"
    ir_count=$((ir_count + 1))
  fi
done < "$rows"

((case_count > 0)) || fail "manifest contains no runnable cases"
((case_count == expected_case_count)) ||
  fail "manifest contains $case_count runnable case(s); expected exactly $expected_case_count"
((compose_count == expected_compose_count)) ||
  fail "manifest contains $compose_count compose-stage case(s); expected exactly $expected_compose_count"
((parse_count == expected_parse_count)) ||
  fail "manifest contains $parse_count parse-stage case(s); expected exactly $expected_parse_count"
((ir_count == expected_ir_count)) ||
  fail "manifest contains $ir_count IR roundtrip case(s); expected exactly $expected_ir_count"

echo "WGSL corpus matrix gate passed: cases=$case_count compose=$compose_count parse=$parse_count ir=$ir_count runtime-valid-compose=$runtime_valid_compose_count"
