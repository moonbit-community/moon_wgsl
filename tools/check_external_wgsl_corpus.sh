#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

manifest="${EXTERNAL_WGSL_CORPUS_MANIFEST:-testdata/external_wgsl_corpus_manifest.tsv}"
skip_manifest="${EXTERNAL_WGSL_CORPUS_SKIP_MANIFEST:-testdata/external_wgsl_corpus_skips.tsv}"
cache_root="${EXTERNAL_WGSL_CACHE_ROOT:-$repo_root/.moon_wgsl_cache/external_wgsl}"

fail() {
  printf 'external WGSL corpus gate failed: %s\n' "$*" >&2
  exit 1
}

[[ -f "$manifest" ]] || fail "missing manifest: $manifest"
[[ -f "$skip_manifest" ]] || fail "missing skip manifest: $skip_manifest"

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
  if grep -q 'var<immediate>' "$source"; then
    validate_args+=(--capability immediates)
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
composed_valid_count=0
skip_actual="$tmpdir/skips.actual.tsv"
skip_expected="$tmpdir/skips.expected.tsv"
skip_actual_keys="$tmpdir/skips.actual.keys.tsv"
skip_expected_keys="$tmpdir/skips.expected.keys.tsv"
: > "$skip_actual"

{ grep -v -E '^($|#)' "$skip_manifest" || true; } | sort > "$skip_expected"

source_contains_preprocessor_directive() {
  local source="$1"
  grep -Eq '^[[:space:]]*#(import|define_import_path|if|ifdef|ifndef|else|elif|endif)' "$source"
}

materialize_valid_external_wgsl_source() {
  local id="$1"
  local checkout="$2"
  local source="$3"
  local output="$4"
  local reason_output="$5"

  if validate_wgsl_with_detected_capabilities "$source" >/dev/null 2>"$tmpdir/$id.naga.err"; then
    printf 'raw\n'
    printf '%s\n' "$source" > "$output"
    return 0
  fi

  if ! source_contains_preprocessor_directive "$source"; then
    printf 'raw_invalid_no_preprocessor\tNaga rejected raw source and the file has no naga-oil-style preprocessing directive\n' > "$reason_output"
    return 1
  fi

  local rel_path="${source#$checkout/}"
  local composed="$tmpdir/$id.compose.$(basename "$source").wgsl"
  if ! moon run tools/compose_case -- \
      --fixture-root "$checkout" \
      --entry "$rel_path" \
      --output "$composed" >"$tmpdir/$id.compose.stdout" 2>"$tmpdir/$id.compose.stderr"; then
    printf 'compose_failed\t%s\n' "$(
      { cat "$tmpdir/$id.compose.stdout"; cat "$tmpdir/$id.compose.stderr"; } |
        tr '\n' ' ' |
        sed 's/[[:space:]]\{1,\}/ /g; s/[[:space:]]$//'
    )" > "$reason_output"
    return 1
  fi

  if ! validate_wgsl_with_detected_capabilities "$composed" >/dev/null 2>"$tmpdir/$id.compose-naga.err"; then
    printf 'compose_naga_invalid\t%s\n' "$(tr '\n' ' ' < "$tmpdir/$id.compose-naga.err" | sed 's/[[:space:]]\{1,\}/ /g; s/[[:space:]]$//')" > "$reason_output"
    return 1
  fi

  printf 'compose\n'
  printf '%s\n' "$composed" > "$output"
}

while IFS=$'\t' read -r id repo ref sparse_paths min_valid min_composed notes; do
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
  repo_composed_count=0
  while IFS= read -r source; do
    file_count=$((file_count + 1))
    source_candidate_file="$tmpdir/$id.source-candidate"
    skip_reason_file="$tmpdir/$id.skip-reason"
    rel_path="${source#$checkout/}"
    if ! source_kind="$(materialize_valid_external_wgsl_source "$id" "$checkout" "$source" "$source_candidate_file" "$skip_reason_file")"; then
      skipped_count=$((skipped_count + 1))
      if [[ ! -s "$skip_reason_file" ]]; then
        printf 'unknown\tmaterialization failed without a recorded reason\n' > "$skip_reason_file"
      fi
      IFS=$'\t' read -r reason detail < "$skip_reason_file"
      printf '%s\t%s\t%s\t%s\n' "$id" "$rel_path" "$reason" "${detail:-}" >> "$skip_actual"
      continue
    fi
    validated_source="$(cat "$source_candidate_file")"
    if [[ "$source_kind" == "compose" ]]; then
      repo_composed_count=$((repo_composed_count + 1))
      composed_valid_count=$((composed_valid_count + 1))
    fi

    repo_valid_count=$((repo_valid_count + 1))
    source_valid_count=$((source_valid_count + 1))
    base="$(basename "$source" .wgsl)"
    emitted="$tmpdir/$id.$repo_valid_count.$base.ir.wgsl"
    if ! moon run tools/ir_roundtrip -- --mode parse --input "$validated_source" --output "$tmpdir/$id.parse.out" >"$tmpdir/$id.parse.stdout" 2>"$tmpdir/$id.parse.stderr"; then
      echo "moon parse failed for external WGSL corpus $id: ${source#$checkout/}" >&2
      sed -n '1,80p' "$tmpdir/$id.parse.stdout" >&2
      sed -n '1,80p' "$tmpdir/$id.parse.stderr" >&2
      exit 1
    fi
    if ! moon run tools/ir_roundtrip -- --input "$validated_source" --output "$emitted" >"$tmpdir/$id.ir.stdout" 2>"$tmpdir/$id.ir.stderr"; then
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
  ((repo_composed_count >= min_composed)) || fail "$id produced only $repo_composed_count composed source file(s); expected at least $min_composed"
  echo "external WGSL corpus $id passed: files=$repo_file_count source-valid=$repo_valid_count composed-valid=$repo_composed_count ir-valid=$repo_ir_count skipped=$((repo_file_count - repo_valid_count))"
done < "$manifest"

sort -o "$skip_actual" "$skip_actual"
awk -F '\t' '{ print $1 "\t" $2 "\t" $3 }' "$skip_expected" | sort > "$skip_expected_keys"
awk -F '\t' '{ print $1 "\t" $2 "\t" $3 }' "$skip_actual" | sort > "$skip_actual_keys"
if ! diff -u "$skip_expected_keys" "$skip_actual_keys" >"$tmpdir/skips.diff"; then
  echo "external WGSL corpus skipped-file manifest is out of date or incomplete" >&2
  echo "Every skipped file must be classified explicitly in $skip_manifest." >&2
  sed -n '1,200p' "$tmpdir/skips.diff" >&2
  echo "Observed skipped-file details:" >&2
  sed -n '1,200p' "$skip_actual" >&2
  exit 1
fi

((repo_count > 0)) || fail "manifest contains no repositories"
((source_valid_count > 0)) || fail "no Naga-valid external WGSL files were found"
((ir_valid_count == source_valid_count)) || fail "IR validation count mismatch"

echo "external WGSL corpus gate passed: repos=$repo_count files=$file_count source-valid=$source_valid_count composed-valid=$composed_valid_count ir-valid=$ir_valid_count skipped=$skipped_count"
