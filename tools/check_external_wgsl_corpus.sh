#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

manifest="${EXTERNAL_WGSL_CORPUS_MANIFEST:-testdata/external_wgsl_corpus_manifest.tsv}"
cache_root="${EXTERNAL_WGSL_CACHE_ROOT:-$repo_root/.moon_wgsl_cache/external_wgsl}"

fail() {
  printf 'external WGSL corpus gate failed: %s\n' "$*" >&2
  exit 1
}

[[ -f "$manifest" ]] || fail "missing manifest: $manifest"

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

validate_wgsl_with_detected_capabilities() {
  local source="$1"
  local validate_args=()
  if grep -q 'enable f16' "$source" || grep -q 'f16' "$source" || grep -q 'vec[234]h' "$source" || grep -q 'mat[234]x[234]h' "$source"; then
    validate_args+=(--capability f16)
  fi
  if grep -q 'enable subgroups' "$source" || grep -q 'subgroup' "$source"; then
    validate_args+=(--capability subgroups)
  fi
  if grep -q '@blend_src' "$source"; then
    validate_args+=(--capability dual-source-blending)
  fi
  if grep -q 'texture_external' "$source"; then
    validate_args+=(--capability texture-external)
  fi
  if grep -q 'enable wgpu_ray_query' "$source" || grep -q 'rayQuery' "$source" || grep -q 'acceleration_structure' "$source"; then
    validate_args+=(--capability ray-query)
  fi
  cargo run --quiet --manifest-path tools/naga_oil_oracle/Cargo.toml --bin wgsl_validate -- "${validate_args[@]+"${validate_args[@]}"}" "$source" >/dev/null
}

clone_or_update_repo() {
  local id="$1"
  local repo="$2"
  local ref="$3"
  local sparse_paths="$4"
  local checkout="$cache_root/$id"

  if [[ ! -d "$checkout/.git" ]]; then
    rm -rf "$checkout"
    mkdir -p "$cache_root"
    git clone --filter=blob:none --sparse "$repo" "$checkout" >/dev/null
  fi

  IFS=',' read -r -a paths <<< "$sparse_paths"
  git -C "$checkout" sparse-checkout set "${paths[@]}" >/dev/null
  git -C "$checkout" fetch --depth 1 origin "$ref" >/dev/null
  git -C "$checkout" checkout --quiet "$ref"
  printf '%s\n' "$checkout"
}

repo_count=0
file_count=0
source_valid_count=0
ir_valid_count=0
skipped_count=0

while IFS=$'\t' read -r id repo ref sparse_paths min_valid notes; do
  [[ -n "${id:-}" ]] || continue
  [[ "$id" == \#* ]] && continue
  [[ "$id" == "id" ]] && continue
  [[ -n "${notes:-}" ]] || fail "manifest row $id must include notes"

  echo "== External WGSL corpus: $id =="
  checkout="$(clone_or_update_repo "$id" "$repo" "$ref" "$sparse_paths")"
  actual_ref="$(git -C "$checkout" rev-parse HEAD)"
  [[ "$actual_ref" == "$ref" ]] || fail "$id checked out $actual_ref, expected $ref"

  repo_count=$((repo_count + 1))
  repo_files="$tmpdir/$id.files"
  find "$checkout" -name '*.wgsl' -type f ! -name '*.expected.wgsl' | sort > "$repo_files"
  repo_file_count="$(wc -l < "$repo_files" | tr -d ' ')"
  ((repo_file_count > 0)) || fail "$id has no .wgsl files"

  repo_valid_count=0
  repo_ir_count=0
  while IFS= read -r source; do
    file_count=$((file_count + 1))
    if ! validate_wgsl_with_detected_capabilities "$source" >/dev/null 2>"$tmpdir/$id.naga.err"; then
      skipped_count=$((skipped_count + 1))
      continue
    fi

    repo_valid_count=$((repo_valid_count + 1))
    source_valid_count=$((source_valid_count + 1))
    base="$(basename "$source" .wgsl)"
    emitted="$tmpdir/$id.$repo_valid_count.$base.ir.wgsl"
    if ! moon run tools/ir_roundtrip -- --mode parse --input "$source" --output "$tmpdir/$id.parse.out" >"$tmpdir/$id.parse.stdout" 2>"$tmpdir/$id.parse.stderr"; then
      echo "moon parse failed for external WGSL corpus $id: ${source#$checkout/}" >&2
      sed -n '1,80p' "$tmpdir/$id.parse.stdout" >&2
      sed -n '1,80p' "$tmpdir/$id.parse.stderr" >&2
      exit 1
    fi
    if ! moon run tools/ir_roundtrip -- --input "$source" --output "$emitted" >"$tmpdir/$id.ir.stdout" 2>"$tmpdir/$id.ir.stderr"; then
      echo "moon IR roundtrip failed for external WGSL corpus $id: ${source#$checkout/}" >&2
      sed -n '1,80p' "$tmpdir/$id.ir.stdout" >&2
      sed -n '1,80p' "$tmpdir/$id.ir.stderr" >&2
      exit 1
    fi
    if ! moon run tools/ir_roundtrip -- --mode parse --input "$emitted" --output "$tmpdir/$id.reparse.out" >"$tmpdir/$id.reparse.stdout" 2>"$tmpdir/$id.reparse.stderr"; then
      echo "moon reparse failed for emitted external WGSL corpus $id: ${source#$checkout/}" >&2
      sed -n '1,80p' "$tmpdir/$id.reparse.stdout" >&2
      sed -n '1,80p' "$tmpdir/$id.reparse.stderr" >&2
      exit 1
    fi
    if ! validate_wgsl_with_detected_capabilities "$emitted" >"$tmpdir/$id.emit-naga.stdout" 2>"$tmpdir/$id.emit-naga.stderr"; then
      echo "Naga validation failed for emitted external WGSL corpus $id: ${source#$checkout/}" >&2
      sed -n '1,120p' "$tmpdir/$id.emit-naga.stderr" >&2
      exit 1
    fi
    repo_ir_count=$((repo_ir_count + 1))
    ir_valid_count=$((ir_valid_count + 1))
  done < "$repo_files"

  ((repo_valid_count >= min_valid)) || fail "$id produced only $repo_valid_count Naga-valid source file(s); expected at least $min_valid"
  echo "external WGSL corpus $id passed: files=$repo_file_count source-valid=$repo_valid_count ir-valid=$repo_ir_count skipped=$((repo_file_count - repo_valid_count))"
done < "$manifest"

((repo_count > 0)) || fail "manifest contains no repositories"
((source_valid_count > 0)) || fail "no Naga-valid external WGSL files were found"
((ir_valid_count == source_valid_count)) || fail "IR validation count mismatch"

echo "external WGSL corpus gate passed: repos=$repo_count files=$file_count source-valid=$source_valid_count ir-valid=$ir_valid_count skipped=$skipped_count"
