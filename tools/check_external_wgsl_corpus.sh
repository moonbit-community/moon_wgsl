#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

manifest="${EXTERNAL_WGSL_CORPUS_MANIFEST:-testdata/external_wgsl_corpus_manifest.tsv}"
expected_invalid_manifest="${EXTERNAL_WGSL_CORPUS_EXPECTED_INVALID_MANIFEST:-testdata/external_wgsl_corpus_expected_invalid.tsv}"
expected_invalid_normalized_manifest="${EXTERNAL_WGSL_CORPUS_EXPECTED_INVALID_NORMALIZED_MANIFEST:-testdata/external_wgsl_corpus_expected_invalid_normalized_by_ir.tsv}"
profile_manifest="${EXTERNAL_WGSL_CORPUS_PROFILE_MANIFEST:-testdata/external_wgsl_corpus_profiles.tsv}"
profile_mode_manifest="${EXTERNAL_WGSL_CORPUS_PROFILE_MODE_MANIFEST:-testdata/external_wgsl_corpus_profile_modes.tsv}"
cache_root="${EXTERNAL_WGSL_CACHE_ROOT:-$repo_root/.moon_wgsl_cache/external_wgsl}"

fail() {
  printf 'external WGSL corpus gate failed: %s\n' "$*" >&2
  exit 1
}

[[ -f "$manifest" ]] || fail "missing manifest: $manifest"
[[ -f "$expected_invalid_manifest" ]] || fail "missing expected-invalid manifest: $expected_invalid_manifest"
[[ -f "$expected_invalid_normalized_manifest" ]] || fail "missing expected-invalid normalized-by-IR manifest: $expected_invalid_normalized_manifest"
[[ -f "$profile_manifest" ]] || fail "missing profile manifest: $profile_manifest"
[[ -f "$profile_mode_manifest" ]] || fail "missing profile mode manifest: $profile_mode_manifest"

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
  if grep -q 'f64' "$source"; then
    validate_args+=(--capability float64)
  fi
  if grep -Eq 'quantizeToF16|pack2x16float|unpack2x16float' "$source"; then
    validate_args+=(--capability shader-float16-in-float32)
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
  if grep -q 'r64uint' "$source" || grep -q 'r64sint' "$source"; then
    validate_args+=(--capability texture-int64-atomic)
  fi
  if grep -Eq '(^|[^[:alnum:]_])([iu]64)([^[:alnum:]_]|$)|vec[234]<[iu]64|r64[us]int' "$source"; then
    validate_args+=(--capability shader-int64)
  fi
  if grep -q 'enable wgpu_ray_query' "$source" || grep -q 'rayQuery' "$source" || grep -q 'acceleration_structure' "$source"; then
    validate_args+=(--capability ray-query)
  fi
  if grep -q 'enable wgpu_ray_query_vertex_return' "$source" || grep -q 'vertex_return' "$source" || grep -Eq 'get(Candidate|Committed)HitVertexPositions' "$source"; then
    validate_args+=(--capability ray-hit-vertex-position)
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
  if grep -q 'enable wgpu_mesh_shader' "$source" || grep -q '@mesh(' "$source" || grep -q '@task' "$source"; then
    validate_args+=(--capability mesh-shader)
  fi
  if grep -q '@builtin(point_index)' "$source"; then
    validate_args+=(--capability mesh-shader-point-topology)
  fi
  cargo run --quiet --manifest-path tools/naga_oil_oracle/Cargo.toml --bin wgsl_validate -- "${validate_args[@]+"${validate_args[@]}"}" "$source" >/dev/null
}

record_expected_invalid_normalization_if_any() {
  local id="$1"
  local rel_path="$2"
  local source="$3"
  local reason="$4"
  local emitted="$tmpdir/$id.expected-invalid.$(basename "$source").ir.wgsl"
  if moon run tools/ir_roundtrip -- --input "$source" --output "$emitted" >/dev/null 2>"$tmpdir/$id.expected-invalid-ir.stderr" &&
     validate_wgsl_with_detected_capabilities "$emitted" >/dev/null 2>"$tmpdir/$id.expected-invalid-naga.stderr"; then
    printf '%s\t%s\t%s\t%s\n' "$id" "$rel_path" "$reason" "moon IR currently normalizes this expected-invalid external fixture into Naga-valid WGSL" >> "$expected_invalid_normalized_actual"
  fi
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
composed_valid_count=0
expected_invalid_count=0
expected_invalid_actual="$tmpdir/expected-invalid.actual.tsv"
expected_invalid_expected="$tmpdir/expected-invalid.expected.tsv"
expected_invalid_actual_keys="$tmpdir/expected-invalid.actual.keys.tsv"
expected_invalid_expected_keys="$tmpdir/expected-invalid.expected.keys.tsv"
expected_invalid_normalized_actual="$tmpdir/expected-invalid-normalized.actual.tsv"
expected_invalid_normalized_expected="$tmpdir/expected-invalid-normalized.expected.tsv"
expected_invalid_normalized_actual_keys="$tmpdir/expected-invalid-normalized.actual.keys.tsv"
expected_invalid_normalized_expected_keys="$tmpdir/expected-invalid-normalized.expected.keys.tsv"
profile_expected_keys="$tmpdir/profile.expected.keys.tsv"
profile_used_keys="$tmpdir/profile.used.keys.tsv"
profile_mode_actual="$tmpdir/profile-mode.actual.tsv"
profile_mode_expected="$tmpdir/profile-mode.expected.tsv"
profile_mode_actual_keys="$tmpdir/profile-mode.actual.keys.tsv"
profile_mode_expected_keys="$tmpdir/profile-mode.expected.keys.tsv"
: > "$expected_invalid_actual"
: > "$expected_invalid_normalized_actual"
: > "$profile_used_keys"
: > "$profile_mode_actual"

awk -F '\t' '
  $0 ~ /^($|#)/ { next }
  $1 == "id" { next }
  NF != 9 {
    printf("external corpus manifest row has %d field(s), expected 9: %s\n", NF, $0) > "/dev/stderr"
    exit 1
  }
  { print $1 }
' "$manifest" | sort > "$tmpdir/repo.ids"
duplicate_repo_ids="$(uniq -d "$tmpdir/repo.ids" | tr '\n' ' ')"
[[ -z "$duplicate_repo_ids" ]] || fail "duplicate external WGSL corpus repo row(s): $duplicate_repo_ids"

awk -F '\t' '
  $0 ~ /^($|#)/ { next }
  $1 == "id" { next }
  NF != 4 {
    printf("expected-invalid manifest row has %d field(s), expected 4: %s\n", NF, $0) > "/dev/stderr"
    exit 1
  }
  $3 != "raw_invalid_no_preprocessor" {
    printf("expected-invalid reason must be raw_invalid_no_preprocessor: %s\n", $0) > "/dev/stderr"
    exit 1
  }
  { print $1 "\t" $2 "\t" $3 "\t" $4 }
' "$expected_invalid_manifest" | sort > "$expected_invalid_expected"
awk -F '\t' '{ print $1 "\t" $2 "\t" $3 }' "$expected_invalid_expected" | sort > "$expected_invalid_expected_keys"
duplicate_expected_invalid_keys="$(uniq -d "$expected_invalid_expected_keys" | tr '\n' ' ')"
[[ -z "$duplicate_expected_invalid_keys" ]] || fail "duplicate expected-invalid row(s): $duplicate_expected_invalid_keys"

awk -F '\t' '
  $0 ~ /^($|#)/ { next }
  $1 == "id" { next }
  NF != 4 {
    printf("expected-invalid normalized-by-IR manifest row has %d field(s), expected 4: %s\n", NF, $0) > "/dev/stderr"
    exit 1
  }
  $3 != "raw_invalid_no_preprocessor" {
    printf("expected-invalid normalized-by-IR reason must be raw_invalid_no_preprocessor: %s\n", $0) > "/dev/stderr"
    exit 1
  }
  { print $1 "\t" $2 "\t" $3 "\t" $4 }
' "$expected_invalid_normalized_manifest" | sort > "$expected_invalid_normalized_expected"
awk -F '\t' '{ print $1 "\t" $2 "\t" $3 }' "$expected_invalid_normalized_expected" | sort > "$expected_invalid_normalized_expected_keys"
duplicate_expected_invalid_normalized_keys="$(uniq -d "$expected_invalid_normalized_expected_keys" | tr '\n' ' ')"
[[ -z "$duplicate_expected_invalid_normalized_keys" ]] || fail "duplicate expected-invalid normalized-by-IR row(s): $duplicate_expected_invalid_normalized_keys"

awk -F '\t' '
  $0 ~ /^($|#)/ { next }
  $1 == "id" { next }
  NF != 10 {
    printf("profile manifest row has %d field(s), expected 10: %s\n", NF, $0) > "/dev/stderr"
    exit 1
  }
  { print $1 "\t" $2 }
' "$profile_manifest" | sort > "$profile_expected_keys"
duplicate_profile_keys="$(uniq -d "$profile_expected_keys" | tr '\n' ' ')"
[[ -z "$duplicate_profile_keys" ]] || fail "duplicate external WGSL profile row(s): $duplicate_profile_keys"
awk -F '\t' '
  $0 ~ /^($|#)/ { next }
  $1 == "id" { next }
  NF != 4 {
    printf("profile mode manifest row has %d field(s), expected 4: %s\n", NF, $0) > "/dev/stderr"
    exit 1
  }
  $3 != "raw" && $3 != "compose" {
    printf("profile mode must be raw or compose: %s\n", $0) > "/dev/stderr"
    exit 1
  }
  { print $1 "\t" $2 "\t" $3 }
' "$profile_mode_manifest" | sort > "$profile_mode_expected"
awk -F '\t' '{ print $1 "\t" $2 }' "$profile_mode_expected" | sort > "$profile_mode_expected_keys"
duplicate_profile_mode_keys="$(uniq -d "$profile_mode_expected_keys" | tr '\n' ' ')"
[[ -z "$duplicate_profile_mode_keys" ]] || fail "duplicate external WGSL profile mode row(s): $duplicate_profile_mode_keys"
if ! diff -u "$profile_expected_keys" "$profile_mode_expected_keys" >"$tmpdir/profile-mode-coverage.diff"; then
  echo "external WGSL corpus profile mode manifest does not match profile manifest" >&2
  echo "Every profile row must have exactly one expected raw/compose execution mode." >&2
  sed -n '1,200p' "$tmpdir/profile-mode-coverage.diff" >&2
  exit 1
fi

source_contains_preprocessor_directive() {
  local source="$1"
  node - "$source" <<'NODE'
const fs = require("node:fs");
const source = fs.readFileSync(process.argv[2], "utf8");
let cleaned = "";
let i = 0;
let blockDepth = 0;
let lineComment = false;
while (i < source.length) {
  const ch = source[i];
  const next = source[i + 1] ?? "";
  if (lineComment) {
    if (ch === "\n" || ch === "\r") {
      lineComment = false;
      cleaned += ch;
    } else {
      cleaned += " ";
    }
    i += 1;
    continue;
  }
  if (blockDepth > 0) {
    if (ch === "/" && next === "*") {
      blockDepth += 1;
      cleaned += "  ";
      i += 2;
    } else if (ch === "*" && next === "/") {
      blockDepth -= 1;
      cleaned += "  ";
      i += 2;
    } else {
      cleaned += ch === "\n" || ch === "\r" ? ch : " ";
      i += 1;
    }
    continue;
  }
  if (ch === "/" && next === "/") {
    lineComment = true;
    cleaned += "  ";
    i += 2;
  } else if (ch === "/" && next === "*") {
    blockDepth = 1;
    cleaned += "  ";
    i += 2;
  } else {
    cleaned += ch;
    i += 1;
  }
}
process.exit(
  /^[ \t]*#[ \t]*(import|define|define_import_path|if|ifdef|ifndef|else|elif|endif)\b/m.test(cleaned)
    ? 0
    : 1,
);
NODE
}

check_preprocessor_directive_classifier() {
  local commented="$tmpdir/commented-directive.wgsl"
  local block_prefixed="$tmpdir/block-prefixed-directive.wgsl"
  local spaced_define="$tmpdir/spaced-define-directive.wgsl"
  printf '// #import hidden::item\nfn main() {}\n' > "$commented"
  printf '/* comment */ # import visible::item\nfn main() {}\n' > "$block_prefixed"
  printf '# define FEATURE\nfn main() {}\n' > "$spaced_define"
  if source_contains_preprocessor_directive "$commented"; then
    fail "preprocessor directive classifier matched a line-commented directive"
  fi
  if ! source_contains_preprocessor_directive "$block_prefixed"; then
    fail "preprocessor directive classifier missed a block-comment-prefixed import"
  fi
  if ! source_contains_preprocessor_directive "$spaced_define"; then
    fail "preprocessor directive classifier missed a spaced #define"
  fi
}

check_preprocessor_directive_classifier

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

profile_overlay_root() {
  local id="$1"
  local checkout="$2"
  local rel_path="$3"
  local profile_source="$4"
  local reason_output="$5"
  local overlay="$tmpdir/$id.profile-root.$(printf '%s' "$rel_path" | tr '/.' '__')"

  mkdir -p "$overlay"
  if ! cp -R "$checkout/." "$overlay/" >/dev/null 2>&1; then
    printf 'profile_overlay_failed\tfailed to copy profile fixture root\n' > "$reason_output"
    return 1
  fi
  rm -rf "$overlay/.git"
  mkdir -p "$overlay/$(dirname "$rel_path")"
  cp "$profile_source" "$overlay/$rel_path"
  printf '%s\n' "$overlay"
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
  local capabilities_output="$6"
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
    printf '%s\t%s\n' "$id" "$rel_path" >> "$profile_used_keys"
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
    printf '%s\n' "$profile_capabilities" > "$capabilities_output"
    return 0
  fi

  if [[ "$profile_source" != "$source" ]]; then
    if ! source_contains_preprocessor_directive "$profile_source"; then
      printf 'profile_prefixed_invalid\t%s\n' "$(tr '\n' ' ' < "$tmpdir/$id.naga.err" | sed 's/[[:space:]]\{1,\}/ /g; s/[[:space:]]$//')" > "$reason_output"
      return 1
    fi
  fi

  if ! source_contains_preprocessor_directive "$source" && [[ -z "$profile_line" ]]; then
    printf 'raw_invalid_no_preprocessor\tNaga rejected raw source and the file has no naga-oil-style preprocessing directive\n' > "$reason_output"
    return 1
  fi

  local compose_checkout="$checkout"
  if [[ "$profile_source" != "$source" ]]; then
    compose_checkout="$(profile_overlay_root "$id" "$checkout" "$rel_path" "$profile_source" "$reason_output")" || return 1
  fi

  local composed="$tmpdir/$id.compose.$(basename "$source").wgsl"
  local -a compose_args=(
    --fixture-root "$compose_checkout"
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
  printf '%s\n' "$profile_capabilities" > "$capabilities_output"
}

while IFS=$'\t' read -r id repo ref sparse_paths expected_files expected_source_valid expected_composed_valid expected_invalid notes; do
  [[ -n "${id:-}" ]] || continue
  [[ "$id" == \#* ]] && continue
  [[ "$id" == "id" ]] && continue
  [[ -n "${notes:-}" ]] || fail "manifest row $id must include notes"
  [[ "$expected_files" =~ ^[0-9]+$ ]] || fail "manifest row $id must include an exact expected file count"
  [[ "$expected_source_valid" =~ ^[0-9]+$ ]] || fail "manifest row $id must include an exact expected source-valid count"
  [[ "$expected_composed_valid" =~ ^[0-9]+$ ]] || fail "manifest row $id must include an exact expected composed-valid count"
  [[ "$expected_invalid" =~ ^[0-9]+$ ]] || fail "manifest row $id must include an exact expected-invalid count"

  echo "== External WGSL corpus: $id =="
  checkout="$(clone_or_update_repo "$id" "$repo" "$ref" "$sparse_paths")"
  actual_ref="$(git -C "$checkout" rev-parse HEAD)"
  [[ "$actual_ref" == "$ref" ]] || fail "$id checked out $actual_ref, expected $ref"

  repo_count=$((repo_count + 1))
  repo_files="$tmpdir/$id.files"
  find "$checkout" -name '*.wgsl' -type f ! -name '*.expected.wgsl' | sort > "$repo_files"
  repo_file_count="$(wc -l < "$repo_files" | tr -d ' ')"
  ((repo_file_count > 0)) || fail "$id has no .wgsl files"
  ((repo_file_count == expected_files)) || fail "$id produced $repo_file_count WGSL file(s); expected exactly $expected_files"

  repo_valid_count=0
  repo_ir_count=0
  repo_expected_invalid_count=0
  repo_composed_count=0
  while IFS= read -r source; do
    file_count=$((file_count + 1))
    source_candidate_file="$tmpdir/$id.source-candidate"
    skip_reason_file="$tmpdir/$id.skip-reason"
    source_capabilities_file="$tmpdir/$id.source-capabilities"
    rel_path="${source#$checkout/}"
    if ! source_kind="$(materialize_valid_external_wgsl_source "$id" "$checkout" "$source" "$source_candidate_file" "$skip_reason_file" "$source_capabilities_file")"; then
      if [[ ! -s "$skip_reason_file" ]]; then
        printf 'unknown\tmaterialization failed without a recorded reason\n' > "$skip_reason_file"
      fi
      IFS=$'\t' read -r reason detail < "$skip_reason_file"
      if [[ "$reason" != "raw_invalid_no_preprocessor" ]]; then
        echo "external WGSL corpus materialization failed for $id: $rel_path" >&2
        echo "$reason ${detail:-}" >&2
        exit 1
      fi
      expected_invalid_count=$((expected_invalid_count + 1))
      repo_expected_invalid_count=$((repo_expected_invalid_count + 1))
      printf '%s\t%s\t%s\t%s\n' "$id" "$rel_path" "$reason" "${detail:-}" >> "$expected_invalid_actual"
      record_expected_invalid_normalization_if_any "$id" "$rel_path" "$source" "$reason"
      continue
    fi
    validated_source="$(cat "$source_candidate_file")"
    validated_capabilities="$(cat "$source_capabilities_file")"
    if [[ "$source_kind" == "compose" ]]; then
      repo_composed_count=$((repo_composed_count + 1))
      composed_valid_count=$((composed_valid_count + 1))
    fi
    if lookup_external_corpus_profile "$id" "$rel_path" >/dev/null 2>&1; then
      printf '%s\t%s\t%s\n' "$id" "$rel_path" "$source_kind" >> "$profile_mode_actual"
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
    if ! validate_wgsl_with_detected_capabilities "$emitted" "$validated_capabilities" >"$tmpdir/$id.emit-naga.stdout" 2>"$tmpdir/$id.emit-naga.stderr"; then
      echo "Naga validation failed for emitted external WGSL corpus $id: ${source#$checkout/}" >&2
      sed -n '1,120p' "$tmpdir/$id.emit-naga.stderr" >&2
      exit 1
    fi
    repo_ir_count=$((repo_ir_count + 1))
    ir_valid_count=$((ir_valid_count + 1))
  done < "$repo_files"

  ((repo_valid_count == expected_source_valid)) || fail "$id produced $repo_valid_count Naga-valid source file(s); expected exactly $expected_source_valid"
  ((repo_composed_count == expected_composed_valid)) || fail "$id produced $repo_composed_count composed source file(s); expected exactly $expected_composed_valid"
  ((repo_expected_invalid_count == expected_invalid)) || fail "$id produced $repo_expected_invalid_count expected-invalid source file(s); expected exactly $expected_invalid"
  echo "external WGSL corpus $id passed: files=$repo_file_count source-valid=$repo_valid_count composed-valid=$repo_composed_count ir-valid=$repo_ir_count expected-invalid=$repo_expected_invalid_count expected-failures=0 skipped=0"
done < "$manifest"

sort -o "$expected_invalid_actual" "$expected_invalid_actual"
awk -F '\t' '{ print $1 "\t" $2 "\t" $3 }' "$expected_invalid_expected" | sort > "$expected_invalid_expected_keys"
awk -F '\t' '{ print $1 "\t" $2 "\t" $3 }' "$expected_invalid_actual" | sort > "$expected_invalid_actual_keys"
if ! diff -u "$expected_invalid_expected_keys" "$expected_invalid_actual_keys" >"$tmpdir/expected-invalid.diff"; then
  echo "external WGSL corpus expected-invalid manifest is out of date or incomplete" >&2
  echo "Every standalone-invalid file must be classified explicitly in $expected_invalid_manifest." >&2
  sed -n '1,200p' "$tmpdir/expected-invalid.diff" >&2
  echo "Observed expected-invalid details:" >&2
  sed -n '1,200p' "$expected_invalid_actual" >&2
  exit 1
fi

sort -o "$expected_invalid_normalized_actual" "$expected_invalid_normalized_actual"
awk -F '\t' '{ print $1 "\t" $2 "\t" $3 }' "$expected_invalid_normalized_expected" | sort > "$expected_invalid_normalized_expected_keys"
awk -F '\t' '{ print $1 "\t" $2 "\t" $3 }' "$expected_invalid_normalized_actual" | sort > "$expected_invalid_normalized_actual_keys"
if ! diff -u "$expected_invalid_normalized_expected_keys" "$expected_invalid_normalized_actual_keys" >"$tmpdir/expected-invalid-normalized.diff"; then
  echo "external WGSL corpus expected-invalid normalized-by-IR manifest is out of date or incomplete" >&2
  echo "Every expected-invalid file that moon IR normalizes into Naga-valid WGSL must be classified explicitly in $expected_invalid_normalized_manifest." >&2
  sed -n '1,200p' "$tmpdir/expected-invalid-normalized.diff" >&2
  echo "Observed normalized expected-invalid details:" >&2
  sed -n '1,200p' "$expected_invalid_normalized_actual" >&2
  exit 1
fi

sort -o "$profile_used_keys" "$profile_used_keys"
if ! diff -u "$profile_expected_keys" "$profile_used_keys" >"$tmpdir/profile-coverage.diff"; then
  echo "external WGSL corpus profile manifest has stale or unconsumed rows" >&2
  echo "Every profile row must match a concrete WGSL source file in the pinned external corpus." >&2
  sed -n '1,200p' "$tmpdir/profile-coverage.diff" >&2
  exit 1
fi

sort -o "$profile_mode_actual" "$profile_mode_actual"
awk -F '\t' '{ print $1 "\t" $2 "\t" $3 }' "$profile_mode_actual" | sort > "$profile_mode_actual_keys"
if ! diff -u "$profile_mode_expected" "$profile_mode_actual_keys" >"$tmpdir/profile-mode.diff"; then
  echo "external WGSL corpus profile execution modes changed" >&2
  echo "Profiles must explicitly state whether they exercise raw WGSL validation or naga-oil compose." >&2
  sed -n '1,200p' "$tmpdir/profile-mode.diff" >&2
  exit 1
fi

((repo_count > 0)) || fail "manifest contains no repositories"
((source_valid_count > 0)) || fail "no Naga-valid external WGSL files were found"
((ir_valid_count == source_valid_count)) || fail "IR validation count mismatch"
((source_valid_count + expected_invalid_count == file_count)) || fail "external corpus accounting mismatch"

echo "external WGSL corpus gate passed: repos=$repo_count files=$file_count source-valid=$source_valid_count composed-valid=$composed_valid_count ir-valid=$ir_valid_count expected-invalid=$expected_invalid_count expected-failures=0 skipped=0"
