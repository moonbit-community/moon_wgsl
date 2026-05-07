#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

manifest="${WGSL_CORPUS_MANIFEST:-testdata/wgsl_corpus_manifest.tsv}"

fail() {
  printf 'WGSL corpus matrix failed: %s\n' "$*" >&2
  exit 1
}

[[ -f "$manifest" ]] || fail "missing manifest: $manifest"

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

rows="$tmpdir/rows.tsv"
ids="$tmpdir/ids.txt"

awk -F '\t' '
  NF == 0 { next }
  $1 == "" { next }
  $1 ~ /^#/ { next }
  $1 == "id" { next }
  NF < 9 {
    printf("manifest row has %d field(s), expected 9: %s\n", NF, $0) > "/dev/stderr"
    exit 1
  }
  { print }
' "$manifest" > "$rows"

cut -f1 "$rows" | sort > "$ids"
duplicate_ids="$(uniq -d "$ids" | tr '\n' ' ')"
[[ -z "$duplicate_ids" ]] || fail "duplicate manifest id(s): $duplicate_ids"

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

append_capability_args() {
  local csv="$1"
  local -a result=()
  local item
  if [[ "$csv" != "-" && -n "$csv" ]]; then
    IFS=',' read -r -a items <<< "$csv"
    for item in "${items[@]}"; do
      [[ -n "$item" ]] || continue
      result+=("--capability" "$item")
    done
  fi
  if ((${#result[@]} > 0)); then
    printf '%s\n' "${result[@]}"
  fi
}

validate_wgsl() {
  local source="$1"
  local capabilities="$2"
  local args=()
  local arg
  while IFS= read -r arg; do
    [[ -n "$arg" ]] || continue
    args+=("$arg")
  done < <(append_capability_args "$capabilities")
  cargo run --quiet --manifest-path tools/naga_oil_oracle/Cargo.toml --bin wgsl_validate -- "${args[@]+"${args[@]}"}" "$source" >/dev/null
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
parse_count=0
naga_count=0
ir_count=0
naga_ir_count=0

while IFS=$'\t' read -r id kind input entry defines additional_imports capabilities stages notes; do
  [[ -n "$notes" ]] || fail "case $id must have a note"
  echo "== WGSL corpus matrix: $id =="

  IFS=',' read -r -a stage_items <<< "$stages"
  for stage in "${stage_items[@]}"; do
    case "$stage" in
      compose | parse | naga | ir | naga-ir)
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
  fi

  if contains_csv "$stages" "parse"; then
    parse_wgsl "$id" "$source"
    parse_count=$((parse_count + 1))
  fi

  if contains_csv "$stages" "naga"; then
    validate_wgsl "$source" "$capabilities"
    naga_count=$((naga_count + 1))
  fi

  if contains_csv "$stages" "ir" || contains_csv "$stages" "naga-ir"; then
    emitted="$(ir_roundtrip_wgsl "$id" "$source")"
    ir_count=$((ir_count + 1))
    if contains_csv "$stages" "naga-ir"; then
      validate_wgsl "$emitted" "$capabilities"
      naga_ir_count=$((naga_ir_count + 1))
    fi
  fi
done < "$rows"

((case_count > 0)) || fail "manifest contains no runnable cases"
((parse_count > 0)) || fail "manifest contains no parse-stage cases"
((naga_count > 0)) || fail "manifest contains no naga validation cases"
((ir_count > 0)) || fail "manifest contains no IR roundtrip cases"
((naga_ir_count > 0)) || fail "manifest contains no emitted-IR validation cases"

echo "WGSL corpus matrix gate passed: cases=$case_count parse=$parse_count naga=$naga_count ir=$ir_count naga-ir=$naga_ir_count"
