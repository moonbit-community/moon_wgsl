#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

manifest="${EXTERNAL_WGSL_CORPUS_MANIFEST:-testdata/external_wgsl_corpus_manifest.tsv}"
expected_failure_manifest="${EXTERNAL_WGSL_CORPUS_EXPECTED_FAILURE_MANIFEST:-testdata/external_wgsl_corpus_expected_failures.tsv}"
profile_manifest="${EXTERNAL_WGSL_CORPUS_PROFILE_MANIFEST:-testdata/external_wgsl_corpus_profiles.tsv}"
cache_root="${EXTERNAL_WGSL_CACHE_ROOT:-$repo_root/.moon_wgsl_cache/external_wgsl}"

fail() {
  printf 'external WGSL corpus gate failed: %s\n' "$*" >&2
  exit 1
}

[[ -f "$manifest" ]] || fail "missing manifest: $manifest"
[[ -f "$expected_failure_manifest" ]] || fail "missing expected-failure manifest: $expected_failure_manifest"
[[ -f "$profile_manifest" ]] || fail "missing profile manifest: $profile_manifest"

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

validate_wgsl_with_detected_capabilities() {
  local source="$1"
  local extra_capabilities="${2:-}"
  local validate_args=()
  if [[ -n "$extra_capabilities" && "$extra_capabilities" != "-" ]]; then
    IFS=',' read -r -a capability_list <<< "$extra_capabilities"
    local capability
    for capability in "${capability_list[@]}"; do
      [[ -n "$capability" ]] || continue
      validate_args+=(--capability "$capability")
    done
  fi
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
  if grep -q 'textureAtomic' "$source" || grep -q 'texture_storage_.*atomic' "$source"; then
    validate_args+=(--capability texture-atomic)
  fi
  if grep -q 'enable wgpu_ray_query' "$source" || grep -q 'rayQuery' "$source" || grep -q 'acceleration_structure' "$source"; then
    validate_args+=(--capability ray-query)
  fi
  if grep -q 'var<immediate>' "$source"; then
    validate_args+=(--capability immediates)
  fi
  if grep -q 'binding_array' "$source"; then
    validate_args+=(--capability binding-arrays)
  fi
  if grep -q 'enable primitive_index' "$source" || grep -q '@builtin(primitive_index)' "$source"; then
    validate_args+=(--capability primitive-index)
  fi
  if grep -q '@builtin(barycentric' "$source"; then
    validate_args+=(--capability shader-barycentrics)
  fi
  if grep -q 'enable wgpu_per_vertex' "$source" || grep -q '@interpolate(per_vertex' "$source"; then
    validate_args+=(--capability per-vertex)
  fi
  if grep -q '@builtin(view_index)' "$source"; then
    validate_args+=(--capability multiview)
  fi
  if grep -q 'enable wgpu_cooperative_matrix' "$source" || grep -q 'coop_mat' "$source"; then
    validate_args+=(--capability cooperative-matrix)
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
expected_failure_count=0
composed_valid_count=0
expected_failure_actual="$tmpdir/expected-failures.actual.tsv"
expected_failure_expected="$tmpdir/expected-failures.expected.tsv"
expected_failure_actual_keys="$tmpdir/expected-failures.actual.keys.tsv"
expected_failure_expected_keys="$tmpdir/expected-failures.expected.keys.tsv"
: > "$expected_failure_actual"

{ grep -v -E '^($|#)' "$expected_failure_manifest" || true; } | sort > "$expected_failure_expected"

source_contains_preprocessor_directive() {
  local source="$1"
  grep -Eq '^[[:space:]]*#(import|define_import_path|if|ifdef|ifndef|else|elif|endif)' "$source"
}

lookup_external_corpus_profile() {
  local id="$1"
  local rel_path="$2"
  awk -F '\t' -v id="$id" -v rel="$rel_path" '
    $0 !~ /^($|#)/ && $1 == id && $2 == rel { print; found = 1; exit }
    END { if (!found) exit 1 }
  ' "$profile_manifest"
}

apply_profile_text_replacements() {
  local replacements="$1"
  local target="$2"

  [[ -n "$replacements" && "$replacements" != "-" ]] || return 0
  IFS=',' read -r -a replacement_list <<< "$replacements"
  local replacement
  for replacement in "${replacement_list[@]}"; do
    [[ -n "$replacement" ]] || continue
    if [[ "$replacement" != *=* ]]; then
      printf 'invalid profile text replacement: %s\n' "$replacement" >&2
      return 1
    fi
    local from="${replacement%%=*}"
    local to="${replacement#*=}"
    FROM="$from" TO="$to" perl -0pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/g' "$target"
  done
}

append_profile_sources() {
  local checkout="$1"
  local sources="$2"
  local output="$3"
  local reason_output="$4"

  [[ -n "$sources" && "$sources" != "-" ]] || return 0
  IFS=',' read -r -a source_list <<< "$sources"
  local rel_source
  for rel_source in "${source_list[@]}"; do
    [[ -n "$rel_source" ]] || continue
    local source_path="$checkout/$rel_source"
    if [[ "$rel_source" == profile://* ]]; then
      source_path="$repo_root/testdata/external_wgsl_profile_sources/${rel_source#profile://}"
    fi
    if [[ ! -f "$source_path" ]]; then
      printf 'profile_source_missing\tprofile source fragment not found: %s\n' "$rel_source" > "$reason_output"
      return 1
    fi
    cat "$source_path" >> "$output"
    printf '\n' >> "$output"
  done
}

materialize_profile_source() {
  local checkout="$1"
  local source="$2"
  local prefix_sources="$3"
  local suffix_sources="$4"
  local text_replacements="$5"
  local output="$6"
  local reason_output="$7"

  if [[ (-z "$prefix_sources" || "$prefix_sources" == "-") && (-z "$suffix_sources" || "$suffix_sources" == "-") && (-z "$text_replacements" || "$text_replacements" == "-") ]]; then
    printf '%s\n' "$source" > "$output"
    return 0
  fi

  local source_body="$output.body"
  cp "$source" "$source_body"
  if ! apply_profile_text_replacements "$text_replacements" "$source_body"; then
    printf 'profile_replacement_invalid\tinvalid profile text replacement\n' > "$reason_output"
    return 1
  fi
  : > "$output"
  append_profile_sources "$checkout" "$prefix_sources" "$output" "$reason_output" || return 1
  cat "$source_body" >> "$output"
  printf '\n' >> "$output"
  append_profile_sources "$checkout" "$suffix_sources" "$output" "$reason_output" || return 1
}

append_csv_compose_args() {
  local flag="$1"
  local csv="$2"
  [[ -n "$csv" && "$csv" != "-" ]] || return 0
  IFS=',' read -r -a values <<< "$csv"
  local value
  for value in "${values[@]}"; do
    [[ -n "$value" ]] || continue
    compose_args+=("$flag" "$value")
  done
}

materialize_valid_external_wgsl_source() {
  local id="$1"
  local checkout="$2"
  local source="$3"
  local output="$4"
  local reason_output="$5"
  local rel_path="${source#$checkout/}"
  local profile_line=""
  profile_line="$(lookup_external_corpus_profile "$id" "$rel_path" || true)"
  local profile_defs="-"
  local profile_value_defs="-"
  local profile_imports="-"
  local profile_capabilities="-"
  local profile_prefix_sources="-"
  local profile_suffix_sources="-"
  local profile_text_replacements="-"
  if [[ -n "$profile_line" ]]; then
    IFS=$'\t' read -r _profile_id _profile_rel profile_defs profile_value_defs profile_imports profile_capabilities profile_prefix_sources profile_suffix_sources profile_text_replacements _profile_notes <<< "$profile_line"
  fi

  local profile_source="$source"
  if [[ (-n "$profile_prefix_sources" && "$profile_prefix_sources" != "-") ||
        (-n "$profile_suffix_sources" && "$profile_suffix_sources" != "-") ||
        (-n "$profile_text_replacements" && "$profile_text_replacements" != "-") ]]; then
    profile_source="$tmpdir/$id.profile.$(basename "$source").wgsl"
    if ! materialize_profile_source "$checkout" "$source" "$profile_prefix_sources" "$profile_suffix_sources" "$profile_text_replacements" "$profile_source" "$reason_output"; then
      return 1
    fi
  fi

  if validate_wgsl_with_detected_capabilities "$profile_source" "$profile_capabilities" >/dev/null 2>"$tmpdir/$id.naga.err"; then
    printf 'raw\n'
    printf '%s\n' "$profile_source" > "$output"
    return 0
  fi

  if [[ "$profile_source" != "$source" ]]; then
    printf 'profile_prefixed_invalid\t%s\n' "$(tr '\n' ' ' < "$tmpdir/$id.naga.err" | sed 's/[[:space:]]\{1,\}/ /g; s/[[:space:]]$//')" > "$reason_output"
    return 1
  fi

  if ! source_contains_preprocessor_directive "$source" && [[ -z "$profile_line" ]]; then
    printf 'raw_invalid_no_preprocessor\tNaga rejected raw source and the file has no naga-oil-style preprocessing directive\n' > "$reason_output"
    return 1
  fi

  local composed="$tmpdir/$id.compose.$(basename "$source").wgsl"
  local -a compose_args=(
    --fixture-root "$checkout"
    --entry "$rel_path"
    --output "$composed"
  )
  append_csv_compose_args "--def" "$profile_defs"
  append_csv_compose_args "--value-def" "$profile_value_defs"
  append_csv_compose_args "--additional-import" "$profile_imports"
  if ! moon run tools/compose_case -- "${compose_args[@]}" >"$tmpdir/$id.compose.stdout" 2>"$tmpdir/$id.compose.stderr"; then
    printf 'compose_failed\t%s\n' "$(
      { cat "$tmpdir/$id.compose.stdout"; cat "$tmpdir/$id.compose.stderr"; } |
        tr '\n' ' ' |
        sed 's/[[:space:]]\{1,\}/ /g; s/[[:space:]]$//'
    )" > "$reason_output"
    return 1
  fi

  if ! validate_wgsl_with_detected_capabilities "$composed" "$profile_capabilities" >/dev/null 2>"$tmpdir/$id.compose-naga.err"; then
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
  repo_expected_failure_count=0
  repo_composed_count=0
  while IFS= read -r source; do
    file_count=$((file_count + 1))
    source_candidate_file="$tmpdir/$id.source-candidate"
    skip_reason_file="$tmpdir/$id.skip-reason"
    rel_path="${source#$checkout/}"
    if ! source_kind="$(materialize_valid_external_wgsl_source "$id" "$checkout" "$source" "$source_candidate_file" "$skip_reason_file")"; then
      expected_failure_count=$((expected_failure_count + 1))
      repo_expected_failure_count=$((repo_expected_failure_count + 1))
      if [[ ! -s "$skip_reason_file" ]]; then
        printf 'unknown\tmaterialization failed without a recorded reason\n' > "$skip_reason_file"
      fi
      IFS=$'\t' read -r reason detail < "$skip_reason_file"
      printf '%s\t%s\t%s\t%s\n' "$id" "$rel_path" "$reason" "${detail:-}" >> "$expected_failure_actual"
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
  echo "external WGSL corpus $id passed: files=$repo_file_count source-valid=$repo_valid_count composed-valid=$repo_composed_count ir-valid=$repo_ir_count expected-failures=$repo_expected_failure_count skipped=0"
done < "$manifest"

sort -o "$expected_failure_actual" "$expected_failure_actual"
awk -F '\t' '{ print $1 "\t" $2 "\t" $3 }' "$expected_failure_expected" | sort > "$expected_failure_expected_keys"
awk -F '\t' '{ print $1 "\t" $2 "\t" $3 }' "$expected_failure_actual" | sort > "$expected_failure_actual_keys"
if ! diff -u "$expected_failure_expected_keys" "$expected_failure_actual_keys" >"$tmpdir/expected-failures.diff"; then
  echo "external WGSL corpus expected-failure manifest is out of date or incomplete" >&2
  echo "Every non-materialized file must be classified explicitly in $expected_failure_manifest." >&2
  sed -n '1,200p' "$tmpdir/expected-failures.diff" >&2
  echo "Observed expected-failure details:" >&2
  sed -n '1,200p' "$expected_failure_actual" >&2
  exit 1
fi

((repo_count > 0)) || fail "manifest contains no repositories"
((source_valid_count > 0)) || fail "no Naga-valid external WGSL files were found"
((ir_valid_count == source_valid_count)) || fail "IR validation count mismatch"
((source_valid_count + expected_failure_count == file_count)) || fail "external corpus accounting mismatch"

echo "external WGSL corpus gate passed: repos=$repo_count files=$file_count source-valid=$source_valid_count composed-valid=$composed_valid_count ir-valid=$ir_valid_count expected-failures=$expected_failure_count skipped=0"
