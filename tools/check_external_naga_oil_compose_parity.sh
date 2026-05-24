#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

manifest="${EXTERNAL_NAGA_OIL_COMPOSE_PARITY_MANIFEST:-testdata/external_naga_oil_compose_parity.tsv}"
oracle_blocked_manifest="${EXTERNAL_NAGA_OIL_COMPOSE_PARITY_ORACLE_BLOCKED_MANIFEST:-testdata/external_naga_oil_compose_oracle_blocked.tsv}"
writer_drift_manifest="${EXTERNAL_NAGA_OIL_COMPOSE_PARITY_WRITER_DRIFT_MANIFEST:-testdata/external_naga_oil_compose_writer_drift.tsv}"
byte_drift_manifest="${EXTERNAL_NAGA_OIL_COMPOSE_PARITY_BYTE_DRIFT_MANIFEST:-testdata/external_naga_oil_compose_byte_drift.tsv}"
repo_manifest="${EXTERNAL_WGSL_CORPUS_MANIFEST:-testdata/external_wgsl_corpus_manifest.tsv}"
profile_manifest="${EXTERNAL_WGSL_CORPUS_PROFILE_MANIFEST:-testdata/external_wgsl_corpus_profiles.tsv}"
cache_root="${EXTERNAL_WGSL_CACHE_ROOT:-$repo_root/.moon_wgsl_cache/external_wgsl}"
expected_case_count="${EXTERNAL_NAGA_OIL_COMPOSE_PARITY_EXPECTED_CASES:-150}"
expected_oracle_blocked_count="${EXTERNAL_NAGA_OIL_COMPOSE_PARITY_EXPECTED_ORACLE_BLOCKED_CASES:-1}"
allow_known_drift="${MOON_WGSL_ALLOW_KNOWN_DRIFT:-0}"
failure_dir="${EXTERNAL_NAGA_OIL_COMPOSE_PARITY_FAILURE_DIR:-_build/parity/external_naga_oil_compose}"

fail() {
  printf 'external naga-oil compose parity gate failed: %s\n' "$*" >&2
  exit 1
}

[[ -f "$manifest" ]] || fail "missing manifest: $manifest"
[[ -f "$oracle_blocked_manifest" ]] || fail "missing oracle-blocked manifest: $oracle_blocked_manifest"
if [[ "$allow_known_drift" == "1" ]]; then
  [[ -f "$byte_drift_manifest" ]] || fail "missing byte-drift manifest: $byte_drift_manifest"
fi
[[ -f "$repo_manifest" ]] || fail "missing repo manifest: $repo_manifest"
[[ -f "$profile_manifest" ]] || fail "missing profile manifest: $profile_manifest"

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

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

lookup_repo_row() {
  local id="$1"
  awk -F '\t' -v id="$id" '
    $0 !~ /^($|#)/ && $1 == id { print; found = 1; exit }
    END { if (!found) exit 1 }
  ' "$repo_manifest"
}

lookup_external_corpus_profile() {
  local id="$1"
  local rel_path="$2"
  awk -F '\t' -v id="$id" -v rel="$rel_path" '
    $0 !~ /^($|#)/ && $1 == id && $2 == rel { print; found = 1; exit }
    END { if (!found) exit 1 }
  ' "$profile_manifest"
}

validate_manifest_schemas() {
  local parity_keys="$tmpdir/parity.keys"
  local compose_source_keys="$tmpdir/compose-source.keys"
  local oracle_blocked_keys="$tmpdir/oracle-blocked.keys"
  local writer_drift_keys="$tmpdir/writer-drift.keys"
  local byte_drift_keys="$tmpdir/byte-drift.keys"
  local repo_ids="$tmpdir/repo.ids"
  local duplicate_keys
  local duplicate_oracle_blocked_keys
  local duplicate_writer_drift_keys
  local duplicate_byte_drift_keys
  local duplicate_repo_ids
  awk -F '\t' '
    $0 ~ /^($|#)/ { next }
    $1 == "id" { next }
    NF != 7 {
      printf("external naga-oil compose parity row has %d field(s), expected 7: %s\n", NF, $0) > "/dev/stderr"
      exit 1
    }
    $1 == "" || $2 == "" || $7 == "" {
      printf("external naga-oil compose parity row must include id, rel_path, and notes: %s\n", $0) > "/dev/stderr"
      exit 1
    }
    { print $1 "\t" $2 }
  ' "$manifest" | sort > "$parity_keys"
  duplicate_keys="$(uniq -d "$parity_keys" | tr '\n' ' ')"
  [[ -z "$duplicate_keys" ]] || fail "duplicate external naga-oil compose parity row(s): $duplicate_keys"

  awk -F '\t' '
    $0 ~ /^($|#)/ { next }
    $1 == "id" { next }
    NF != 3 {
      printf("external naga-oil oracle-blocked row has %d field(s), expected 3: %s\n", NF, $0) > "/dev/stderr"
      exit 1
    }
    $1 == "" || $2 == "" || $3 == "" {
      printf("external naga-oil oracle-blocked row must include id, rel_path, and reason: %s\n", $0) > "/dev/stderr"
      exit 1
    }
    { print $1 "\t" $2 }
  ' "$oracle_blocked_manifest" | sort > "$oracle_blocked_keys"
  duplicate_oracle_blocked_keys="$(uniq -d "$oracle_blocked_keys" | tr '\n' ' ')"
  [[ -z "$duplicate_oracle_blocked_keys" ]] || fail "duplicate external naga-oil oracle-blocked row(s): $duplicate_oracle_blocked_keys"
  oracle_blocked_manifest_count="$(wc -l < "$oracle_blocked_keys" | tr -d ' ')"
  ((oracle_blocked_manifest_count == expected_oracle_blocked_count)) ||
    fail "oracle-blocked manifest contains $oracle_blocked_manifest_count case(s); expected exactly $expected_oracle_blocked_count"

  awk -F '\t' '
    $0 ~ /^($|#)/ { next }
    $1 == "id" { next }
    NF != 3 {
      printf("external compose source row has %d field(s), expected 3: %s\n", NF, $0) > "/dev/stderr"
      exit 1
    }
    { print $1 "\t" $2 }
  ' testdata/external_wgsl_corpus_compose_sources.tsv | sort > "$compose_source_keys"
  if ! diff -u "$compose_source_keys" "$parity_keys" >"$tmpdir/compose-source-parity.diff"; then
    echo "external naga-oil compose parity manifest must match the compose source inventory" >&2
    sed -n '1,200p' "$tmpdir/compose-source-parity.diff" >&2
    exit 1
  fi
  if comm -23 "$oracle_blocked_keys" "$parity_keys" | grep . >"$tmpdir/oracle-blocked-stale"; then
    echo "external naga-oil oracle-blocked manifest has rows absent from parity manifest" >&2
    sed -n '1,200p' "$tmpdir/oracle-blocked-stale" >&2
    exit 1
  fi

  if [[ "$allow_known_drift" == "1" ]]; then
    awk -F '\t' '
      $0 ~ /^($|#)/ { next }
      $1 == "id" { next }
      NF != 5 {
        printf("external naga-oil byte-drift row has %d field(s), expected 5: %s\n", NF, $0) > "/dev/stderr"
        exit 1
      }
      $1 == "" || $2 == "" || $3 == "" || $4 == "" || $5 == "" {
        printf("external naga-oil byte-drift row must include id, rel_path, hash, class, and reason: %s\n", $0) > "/dev/stderr"
        exit 1
      }
      { print $1 "\t" $2 "\t" $3 }
    ' "$byte_drift_manifest" | sort > "$byte_drift_keys"
    duplicate_byte_drift_keys="$(awk -F '\t' '{ print $1 "\t" $2 }' "$byte_drift_keys" | uniq -d | tr '\n' ' ')"
    [[ -z "$duplicate_byte_drift_keys" ]] || fail "duplicate external naga-oil byte-drift row(s): $duplicate_byte_drift_keys"
  fi

  awk -F '\t' '
    $0 ~ /^($|#)/ { next }
    $1 == "id" { next }
    NF != 9 {
      printf("external WGSL corpus repo row has %d field(s), expected 9: %s\n", NF, $0) > "/dev/stderr"
      exit 1
    }
    { print $1 }
  ' "$repo_manifest" | sort > "$repo_ids"
  duplicate_repo_ids="$(uniq -d "$repo_ids" | tr '\n' ' ')"
  [[ -z "$duplicate_repo_ids" ]] || fail "duplicate external WGSL corpus repo row(s): $duplicate_repo_ids"
}

is_oracle_blocked_case() {
  local id="$1"
  local rel_path="$2"
  awk -F '\t' -v id="$id" -v rel="$rel_path" '
    $0 !~ /^($|#)/ && $1 == id && $2 == rel { found = 1; exit }
    END { exit found ? 0 : 1 }
  ' "$oracle_blocked_manifest"
}

append_moon_bool_defs() {
  local csv="$1"
  [[ -n "$csv" && "$csv" != "-" ]] || return 0
  IFS=',' read -r -a values <<< "$csv"
  local value
  for value in "${values[@]}"; do
    [[ -n "$value" ]] || continue
    moon_args+=(--def "$value")
  done
}

append_moon_value_defs() {
  local csv="$1"
  [[ -n "$csv" && "$csv" != "-" ]] || return 0
  IFS=',' read -r -a values <<< "$csv"
  local value
  for value in "${values[@]}"; do
    [[ -n "$value" ]] || continue
    [[ "$value" != *=raw:* ]] || continue
    moon_args+=(--value-def "$value")
  done
}

append_oracle_defs() {
  local csv="$1"
  [[ -n "$csv" && "$csv" != "-" ]] || return 0
  IFS=',' read -r -a values <<< "$csv"
  local value
  for value in "${values[@]}"; do
    [[ -n "$value" ]] || continue
    [[ "$value" != *=raw:* ]] || continue
    oracle_args+=(--def "$value")
  done
}

materialize_raw_template_value_defs() {
  local checkout="$1"
  local rel_path="$2"
  local value_defs="$3"
  local label="$4"
  local overlay="$checkout"

  [[ -n "$value_defs" && "$value_defs" != "-" ]] || {
    printf '%s\n' "$checkout"
    return 0
  }

  IFS=',' read -r -a values <<< "$value_defs"
  local raw_values=()
  local value
  for value in "${values[@]}"; do
    [[ -n "$value" ]] || continue
    [[ "$value" == *=raw:* ]] || continue
    raw_values+=("$value")
  done

  if (( ${#raw_values[@]} == 0 )); then
    printf '%s\n' "$checkout"
    return 0
  fi

  overlay="$tmpdir/$label.raw-overlay"
  mkdir -p "$overlay"
  cp -R "$checkout/." "$overlay/"
  rm -rf "$overlay/.git"
  local target="$overlay/$rel_path"
  [[ -f "$target" ]] || fail "raw template overlay entry not found: $rel_path"

  for value in "${raw_values[@]}"; do
    local name="${value%%=*}"
    local raw="${value#*=raw:}"
    [[ -n "$name" ]] || fail "raw template value-def has empty name: $value"
    FROM="##${name}##" TO="$raw" perl -0pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/g' "$target"
  done

  printf '%s\n' "$overlay"
}

apply_profile_text_replacements() {
  local replacements="$1"
  local target="$2"

  [[ -n "$replacements" && "$replacements" != "-" ]] || return 0
  IFS=',' read -r -a replacement_list <<< "$replacements"
  local replacement
  for replacement in "${replacement_list[@]}"; do
    [[ -n "$replacement" ]] || continue
    [[ "$replacement" == *=* ]] || fail "invalid profile text replacement: $replacement"
    local from="${replacement%%=*}"
    local to="${replacement#*=}"
    FROM="$from" TO="$to" perl -0pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/g' "$target"
  done
}

append_profile_sources_to_file() {
  local root="$1"
  local sources="$2"
  local output="$3"

  [[ -n "$sources" && "$sources" != "-" ]] || return 0
  IFS=',' read -r -a source_list <<< "$sources"
  local rel_source
  for rel_source in "${source_list[@]}"; do
    [[ -n "$rel_source" ]] || continue
    local source_path="$root/$rel_source"
    if [[ "$rel_source" == profile://* ]]; then
      source_path="$repo_root/testdata/external_wgsl_profile_sources/${rel_source#profile://}"
    fi
    [[ -f "$source_path" ]] || fail "profile source fragment not found: $rel_source"
    cat "$source_path" >> "$output"
    printf '\n' >> "$output"
  done
}

materialize_profile_source_overlay() {
  local checkout="$1"
  local id="$2"
  local rel_path="$3"
  local label="$4"
  local profile_line
  profile_line="$(lookup_external_corpus_profile "$id" "$rel_path" || true)"
  [[ -n "$profile_line" ]] || {
    printf '%s\n' "$checkout"
    return 0
  }

  local _profile_id _profile_rel _profile_defs _profile_value_defs _profile_imports _profile_capabilities
  local profile_prefix_sources profile_suffix_sources profile_text_replacements _profile_notes
  IFS=$'\t' read -r _profile_id _profile_rel _profile_defs _profile_value_defs _profile_imports _profile_capabilities profile_prefix_sources profile_suffix_sources profile_text_replacements _profile_notes <<< "$profile_line"
  if [[ (-z "$profile_prefix_sources" || "$profile_prefix_sources" == "-") &&
        (-z "$profile_suffix_sources" || "$profile_suffix_sources" == "-") &&
        (-z "$profile_text_replacements" || "$profile_text_replacements" == "-") ]]; then
    printf '%s\n' "$checkout"
    return 0
  fi

  local overlay="$tmpdir/$label.profile-overlay"
  mkdir -p "$overlay"
  cp -R "$checkout/." "$overlay/"
  rm -rf "$overlay/.git"
  local target="$overlay/$rel_path"
  [[ -f "$target" ]] || fail "profile overlay entry not found: $rel_path"
  apply_profile_text_replacements "$profile_text_replacements" "$target"
  if [[ (-n "$profile_prefix_sources" && "$profile_prefix_sources" != "-") ||
        (-n "$profile_suffix_sources" && "$profile_suffix_sources" != "-") ]]; then
    local body="$target.profile-body"
    cp "$target" "$body"
    : > "$target"
    append_profile_sources_to_file "$overlay" "$profile_prefix_sources" "$target"
    cat "$body" >> "$target"
    printf '\n' >> "$target"
    append_profile_sources_to_file "$overlay" "$profile_suffix_sources" "$target"
  fi
  printf '%s\n' "$overlay"
}

append_imports() {
  local csv="$1"
  [[ -n "$csv" && "$csv" != "-" ]] || return 0
  IFS=',' read -r -a values <<< "$csv"
  local value
  for value in "${values[@]}"; do
    [[ -n "$value" ]] || continue
    moon_args+=(--additional-import "$value")
    oracle_args+=(--additional-import "$value")
  done
}

append_capabilities() {
  local csv="$1"
  [[ -n "$csv" && "$csv" != "-" ]] || return 0
  IFS=',' read -r -a values <<< "$csv"
  local value
  for value in "${values[@]}"; do
    [[ -n "$value" ]] || continue
    oracle_args+=(--capability "$value")
    fingerprint_args+=(--capability "$value")
  done
}

append_detected_capabilities() {
  local source="$1"
  if grep -q 'var<immediate>' "$source"; then
    oracle_args+=(--capability immediates)
    fingerprint_args+=(--capability immediates)
  fi
  if grep -q 'enable subgroups' "$source" || grep -q 'subgroup' "$source"; then
    oracle_args+=(--capability subgroups)
    fingerprint_args+=(--capability subgroups)
  fi
  if grep -q 'textureAtomic' "$source" || grep -q 'texture_storage_.*atomic' "$source"; then
    oracle_args+=(--capability texture-atomic)
    fingerprint_args+=(--capability texture-atomic)
  fi
  if grep -q '@builtin(view_index)' "$source"; then
    oracle_args+=(--capability multiview)
    fingerprint_args+=(--capability multiview)
  fi
  if grep -q '@builtin(barycentric' "$source"; then
    oracle_args+=(--capability shader-barycentrics)
    fingerprint_args+=(--capability shader-barycentrics)
  fi
}

append_bevy_default_defs() {
  moon_args+=(--value-def AVAILABLE_STORAGE_BUFFER_BINDINGS=8)
  moon_args+=(--value-def MAX_DIRECTIONAL_LIGHTS=10)
  moon_args+=(--value-def MAX_CASCADES_PER_LIGHT=4)
  moon_args+=(--value-def MAX_RECT_LIGHTS=4)
  moon_args+=(--value-def MATERIAL_BIND_GROUP=3)
  moon_args+=(--value-def SORTED_FRAGMENT_MAX_COUNT=8)
  moon_args+=(--value-def WORLD_CACHE_SIZE=1048576)
  moon_args+=(--value-def PER_OBJECT_BUFFER_BATCH_SIZE=1)
  moon_args+=(--value-def SCREEN_SPACE_SPECULAR_TRANSMISSION_BLUR_TAPS=8)
  oracle_args+=(--def AVAILABLE_STORAGE_BUFFER_BINDINGS=8)
  oracle_args+=(--def MAX_DIRECTIONAL_LIGHTS=10)
  oracle_args+=(--def MAX_CASCADES_PER_LIGHT=4)
  oracle_args+=(--def MAX_RECT_LIGHTS=4)
  oracle_args+=(--def MATERIAL_BIND_GROUP=3)
  oracle_args+=(--def SORTED_FRAGMENT_MAX_COUNT=8)
  oracle_args+=(--def WORLD_CACHE_SIZE=1048576)
  oracle_args+=(--def PER_OBJECT_BUFFER_BATCH_SIZE=1)
  oracle_args+=(--def SCREEN_SPACE_SPECULAR_TRANSMISSION_BLUR_TAPS=8)
}

moon_compose() {
  moon run tools/compose_case -- "${moon_args[@]}"
}

oracle_compose() {
  cargo run --quiet --manifest-path tools/naga_oil_oracle/Cargo.toml --bin naga_oil_oracle -- "${oracle_args[@]}"
}

fingerprint_wgsl() {
  cargo run --quiet --manifest-path tools/naga_oil_oracle/Cargo.toml --bin wgsl_interface_fingerprint -- "${fingerprint_args[@]+"${fingerprint_args[@]}"}" --input "$1" --output "$2"
}

writer_fingerprint_wgsl() {
  cargo run --quiet --manifest-path tools/naga_oil_oracle/Cargo.toml --bin wgsl_writer_fingerprint -- --input "$1" --output "$2"
}

diff_hash() {
  local expected="$1"
  local actual="$2"
  local diff_file="$3"
  if diff -u --label expected --label actual "$expected" "$actual" >"$diff_file"; then
    return 1
  fi
  shasum -a 256 "$diff_file" | awk '{ print $1 }'
}

compare_fingerprints() {
  local oracle_fingerprint="$1"
  local moon_fingerprint="$2"
  local label="$3"
  local oracle_entries="$tmpdir/$label.oracle.entries"
  local moon_entries="$tmpdir/$label.moon.entries"
  local moon_non_entries="$tmpdir/$label.moon.non-entries"
  local moon_extra="$tmpdir/$label.moon.extra"

  grep $'^entry\t' "$oracle_fingerprint" | sed '/^$/d' | sort > "$oracle_entries" || true
  grep $'^entry\t' "$moon_fingerprint" | sed '/^$/d' | sort > "$moon_entries" || true
  if ! diff -u "$oracle_entries" "$moon_entries"; then
    fail "Naga IR entry-point fingerprint differs for $label"
  fi

  grep -v $'^entry\t' "$moon_fingerprint" | sed '/^$/d' | sort > "$moon_non_entries" || true
  comm -23 "$moon_non_entries" "$oracle_fingerprint" > "$moon_extra"
  if [[ -s "$moon_extra" ]]; then
    echo "moon_wgsl emitted pipeline-interface items that are absent from upstream naga-oil for $label:" >&2
    sed -n '1,120p' "$moon_extra" >&2
    fail "Naga IR pipeline-interface fingerprint is not an upstream subset for $label"
  fi
}

case_count=0
comparable_count=0
oracle_blocked_count=0
writer_exact_count=0
writer_drift_count=0
byte_exact_count=0
byte_drift_count=0
oracle_blocked_actual="$tmpdir/oracle-blocked.actual"
oracle_blocked_expected="$tmpdir/oracle-blocked.expected"
writer_drift_actual="$tmpdir/writer-drift.actual"
writer_drift_expected="$tmpdir/writer-drift.expected"
byte_drift_actual="$tmpdir/byte-drift.actual"
byte_drift_expected="$tmpdir/byte-drift.expected"
: > "$oracle_blocked_actual"
: > "$writer_drift_actual"
: > "$byte_drift_actual"
if [[ "$allow_known_drift" != "1" ]]; then
  rm -rf "$failure_dir"
  mkdir -p "$failure_dir/diffs"
fi
cached_repo_id=""
cached_checkout=""
cached_repo=""
cached_ref=""
cached_sparse_paths=""
validate_manifest_schemas
while IFS=$'\t' read -r id rel_path bool_defs value_defs additional_imports capabilities notes; do
  [[ -n "${id:-}" ]] || continue
  [[ "$id" == \#* ]] && continue
  [[ "$id" == "id" ]] && continue
  [[ -n "${notes:-}" ]] || fail "manifest row $id/$rel_path must include notes"

  repo_line="$(lookup_repo_row "$id")" || fail "repo $id is not present in $repo_manifest"
  IFS=$'\t' read -r _repo_id repo ref sparse_paths _expected_files _expected_source_valid _expected_composed_valid _expected_invalid _repo_notes <<< "$repo_line"
  if [[ "$cached_repo_id" == "$id" && "$cached_repo" == "$repo" && "$cached_ref" == "$ref" && "$cached_sparse_paths" == "$sparse_paths" ]]; then
    checkout="$cached_checkout"
  else
    checkout="$(clone_or_update_repo "$id" "$repo" "$ref" "$sparse_paths")"
    actual_ref="$(git -C "$checkout" rev-parse HEAD)"
    [[ "$actual_ref" == "$ref" ]] || fail "$id checked out $actual_ref, expected $ref"
    cached_repo_id="$id"
    cached_repo="$repo"
    cached_ref="$ref"
    cached_sparse_paths="$sparse_paths"
    cached_checkout="$checkout"
  fi
  [[ -f "$checkout/$rel_path" ]] || fail "entry not found: $id/$rel_path"

  case_count=$((case_count + 1))
  label="$id.$case_count.$(basename "$rel_path" .wgsl)"
  profile_root="$(materialize_profile_source_overlay "$checkout" "$id" "$rel_path" "$label")"
  compose_root="$(materialize_raw_template_value_defs "$profile_root" "$rel_path" "$value_defs" "$label")"
  moon_output="$tmpdir/$label.moon.wgsl"
  oracle_output="$tmpdir/$label.oracle.wgsl"
  moon_fingerprint="$tmpdir/$label.moon.interface.txt"
  oracle_fingerprint="$tmpdir/$label.oracle.interface.txt"
  moon_writer_fingerprint="$tmpdir/$label.moon.writer.txt"
  oracle_writer_fingerprint="$tmpdir/$label.oracle.writer.txt"

  echo "== External naga-oil compose parity: $id $rel_path =="
  moon_args=(--fixture-root "$compose_root" --entry "$rel_path" --output "$moon_output")
  oracle_args=(--fixture-root "$compose_root" --entry "$rel_path" --output "$oracle_output")
  fingerprint_args=()

  if [[ "$id" == "bevy" ]]; then
    append_bevy_default_defs
  fi
  append_moon_bool_defs "$bool_defs"
  append_oracle_defs "$bool_defs"
  append_moon_value_defs "$value_defs"
  append_oracle_defs "$value_defs"
  append_imports "$additional_imports"
  append_capabilities "$capabilities"
  append_detected_capabilities "$compose_root/$rel_path"

  if ! moon_compose >"$tmpdir/$label.moon.stdout" 2>"$tmpdir/$label.moon.stderr"; then
    sed -n '1,120p' "$tmpdir/$label.moon.stdout" >&2
    sed -n '1,120p' "$tmpdir/$label.moon.stderr" >&2
    fail "moon compose failed for $id/$rel_path"
  fi
  if ! oracle_compose >"$tmpdir/$label.oracle.stdout" 2>"$tmpdir/$label.oracle.stderr"; then
    if is_oracle_blocked_case "$id" "$rel_path"; then
      printf '%s\t%s\n' "$id" "$rel_path" >> "$oracle_blocked_actual"
      oracle_blocked_count=$((oracle_blocked_count + 1))
      continue
    fi
    sed -n '1,120p' "$tmpdir/$label.oracle.stdout" >&2
    sed -n '1,120p' "$tmpdir/$label.oracle.stderr" >&2
    fail "naga-oil oracle compose failed for $id/$rel_path"
  fi
  if is_oracle_blocked_case "$id" "$rel_path"; then
    fail "oracle-blocked case unexpectedly composed successfully: $id/$rel_path"
  fi
  fingerprint_wgsl "$moon_output" "$moon_fingerprint"
  fingerprint_wgsl "$oracle_output" "$oracle_fingerprint"
  compare_fingerprints "$oracle_fingerprint" "$moon_fingerprint" "$label"
  writer_fingerprint_wgsl "$moon_output" "$moon_writer_fingerprint"
  writer_fingerprint_wgsl "$oracle_output" "$oracle_writer_fingerprint"
  writer_diff="$tmpdir/$label.writer.diff"
  if writer_hash="$(diff_hash "$oracle_writer_fingerprint" "$moon_writer_fingerprint" "$writer_diff")"; then
    printf '%s\t%s\t%s\n' "$id" "$rel_path" "$writer_hash" >> "$writer_drift_actual"
    if [[ "$allow_known_drift" != "1" ]]; then
      cp "$writer_diff" "$failure_dir/diffs/$label.writer.diff"
    fi
    writer_drift_count=$((writer_drift_count + 1))
  else
    writer_exact_count=$((writer_exact_count + 1))
  fi
  byte_diff="$tmpdir/$label.byte.diff"
  if byte_hash="$(diff_hash "$oracle_output" "$moon_output" "$byte_diff")"; then
    printf '%s\t%s\t%s\n' "$id" "$rel_path" "$byte_hash" >> "$byte_drift_actual"
    if [[ "$allow_known_drift" != "1" ]]; then
      cp "$byte_diff" "$failure_dir/diffs/$label.byte.diff"
    fi
    byte_drift_count=$((byte_drift_count + 1))
  else
    byte_exact_count=$((byte_exact_count + 1))
  fi
  comparable_count=$((comparable_count + 1))
done < "$manifest"

((case_count > 0)) || fail "manifest contains no parity cases"
((case_count == expected_case_count)) || fail "manifest contains $case_count parity case(s); expected exactly $expected_case_count"
awk -F '\t' '
  $0 ~ /^($|#)/ { next }
  $1 == "id" { next }
  { print $1 "\t" $2 }
' "$oracle_blocked_manifest" | sort > "$oracle_blocked_expected"
sort -o "$oracle_blocked_actual" "$oracle_blocked_actual"
if ! diff -u "$oracle_blocked_expected" "$oracle_blocked_actual" >"$tmpdir/oracle-blocked.diff"; then
  echo "external naga-oil oracle-blocked manifest does not match observed oracle failures" >&2
  sed -n '1,200p' "$tmpdir/oracle-blocked.diff" >&2
  exit 1
fi
sort -o "$writer_drift_actual" "$writer_drift_actual"
sort -o "$byte_drift_actual" "$byte_drift_actual"

if [[ -s "$writer_drift_actual" ]]; then
  writer_failure_report="$failure_dir/writer_failures.tsv"
  {
    printf 'id\trel_path\thash\tclass\treason\n'
    awk -F '\t' '{ print $1 "\t" $2 "\t" $3 "\twriter-fingerprint-drift\tstrict-byte-parity-failure" }' "$writer_drift_actual"
  } > "$writer_failure_report"
  echo "external naga-oil writer/order/name parity regressed" >&2
  echo "writer/order/name drift is no longer allowlisted; fix WGSL-283 structurally instead of adding manifest rows" >&2
  sed -n '1,120p' "$writer_failure_report" >&2
  echo "failure report written to: $writer_failure_report" >&2
  exit 1
fi

if [[ "$allow_known_drift" == "1" ]]; then
  awk -F '\t' '
    $0 ~ /^($|#)/ { next }
    $1 == "id" { next }
    { print $1 "\t" $2 "\t" $3 }
  ' "$byte_drift_manifest" | sort > "$byte_drift_expected"
  if ! diff -u "$byte_drift_expected" "$byte_drift_actual" >"$tmpdir/byte-drift.diff"; then
    echo "external naga-oil byte-drift manifest does not match observed byte diffs" >&2
    sed -n '1,200p' "$tmpdir/byte-drift.diff" >&2
    echo "Observed byte drift rows:" >&2
    sed -n '1,240p' "$byte_drift_actual" >&2
    exit 1
  fi
  echo "external naga-oil compose parity gate passed with known drift allowed: cases=$case_count comparable=$comparable_count oracle-blocked=$oracle_blocked_count writer-exact=$writer_exact_count writer-drift=$writer_drift_count byte-exact=$byte_exact_count byte-drift=$byte_drift_count"
  exit 0
fi

if ((writer_drift_count != 0 || byte_drift_count != 0)); then
  writer_failure_report="$failure_dir/writer_failures.tsv"
  byte_failure_report="$failure_dir/byte_failures.tsv"
  {
    printf 'id\trel_path\thash\tclass\treason\n'
    awk -F '\t' '{ print $1 "\t" $2 "\t" $3 "\twriter-fingerprint-drift\tstrict-byte-parity-failure" }' "$writer_drift_actual"
  } > "$writer_failure_report"
  {
    printf 'id\trel_path\thash\tclass\treason\n'
    awk -F '\t' '{ print $1 "\t" $2 "\t" $3 "\tbyte-output-drift\tstrict-byte-parity-failure" }' "$byte_drift_actual"
  } > "$byte_failure_report"
  echo "external naga-oil compose strict byte parity failed" >&2
  echo "writer/order/name failures: $writer_drift_count" >&2
  sed -n '1,80p' "$writer_failure_report" >&2
  echo "byte-output failures: $byte_drift_count" >&2
  sed -n '1,80p' "$byte_failure_report" >&2
  echo "failure reports written to: $failure_dir" >&2
  echo "set MOON_WGSL_ALLOW_KNOWN_DRIFT=1 only for legacy drift-manifest compatibility checks" >&2
  exit 1
fi

echo "external naga-oil compose strict byte parity gate passed: cases=$case_count comparable=$comparable_count oracle-blocked=$oracle_blocked_count writer-exact=$writer_exact_count byte-exact=$byte_exact_count"
