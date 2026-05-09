#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

manifest="${EXTERNAL_NAGA_OIL_COMPOSE_PARITY_MANIFEST:-testdata/external_naga_oil_compose_parity.tsv}"
repo_manifest="${EXTERNAL_WGSL_CORPUS_MANIFEST:-testdata/external_wgsl_corpus_manifest.tsv}"
cache_root="${EXTERNAL_WGSL_CACHE_ROOT:-$repo_root/.moon_wgsl_cache/external_wgsl}"
expected_case_count="${EXTERNAL_NAGA_OIL_COMPOSE_PARITY_EXPECTED_CASES:-6}"

fail() {
  printf 'external naga-oil compose parity gate failed: %s\n' "$*" >&2
  exit 1
}

[[ -f "$manifest" ]] || fail "missing manifest: $manifest"
[[ -f "$repo_manifest" ]] || fail "missing repo manifest: $repo_manifest"

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

validate_manifest_schemas() {
  local parity_keys="$tmpdir/parity.keys"
  local repo_ids="$tmpdir/repo.ids"
  local duplicate_keys
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
    NF != 9 {
      printf("external WGSL corpus repo row has %d field(s), expected 9: %s\n", NF, $0) > "/dev/stderr"
      exit 1
    }
    { print $1 }
  ' "$repo_manifest" | sort > "$repo_ids"
  duplicate_repo_ids="$(uniq -d "$repo_ids" | tr '\n' ' ')"
  [[ -z "$duplicate_repo_ids" ]] || fail "duplicate external WGSL corpus repo row(s): $duplicate_repo_ids"
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
    [[ "$value" != *=raw:* ]] || fail "raw template value defs are not supported by the naga-oil parity manifest: $value"
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
    [[ "$value" != *=raw:* ]] || fail "raw template value defs are not supported by the naga-oil parity manifest: $value"
    oracle_args+=(--def "$value")
  done
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

append_bevy_default_oracle_defs() {
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

compare_fingerprints() {
  local oracle_fingerprint="$1"
  local moon_fingerprint="$2"
  local label="$3"
  local oracle_entries="$tmpdir/$label.oracle.entries"
  local moon_entries="$tmpdir/$label.moon.entries"
  local moon_non_entries="$tmpdir/$label.moon.non-entries"
  local moon_extra="$tmpdir/$label.moon.extra"

  grep $'^entry\t' "$oracle_fingerprint" | sort > "$oracle_entries" || true
  grep $'^entry\t' "$moon_fingerprint" | sort > "$moon_entries" || true
  if ! diff -u "$oracle_entries" "$moon_entries"; then
    fail "Naga IR entry-point fingerprint differs for $label"
  fi

  grep -v $'^entry\t' "$moon_fingerprint" | sort > "$moon_non_entries" || true
  comm -23 "$moon_non_entries" "$oracle_fingerprint" > "$moon_extra"
  if [[ -s "$moon_extra" ]]; then
    echo "moon_wgsl emitted pipeline-interface items that are absent from upstream naga-oil for $label:" >&2
    sed -n '1,120p' "$moon_extra" >&2
    fail "Naga IR pipeline-interface fingerprint is not an upstream subset for $label"
  fi
}

case_count=0
validate_manifest_schemas
while IFS=$'\t' read -r id rel_path bool_defs value_defs additional_imports capabilities notes; do
  [[ -n "${id:-}" ]] || continue
  [[ "$id" == \#* ]] && continue
  [[ "$id" == "id" ]] && continue
  [[ -n "${notes:-}" ]] || fail "manifest row $id/$rel_path must include notes"

  repo_line="$(lookup_repo_row "$id")" || fail "repo $id is not present in $repo_manifest"
  IFS=$'\t' read -r _repo_id repo ref sparse_paths _expected_files _expected_source_valid _expected_composed_valid _expected_invalid _repo_notes <<< "$repo_line"
  checkout="$(clone_or_update_repo "$id" "$repo" "$ref" "$sparse_paths")"
  actual_ref="$(git -C "$checkout" rev-parse HEAD)"
  [[ "$actual_ref" == "$ref" ]] || fail "$id checked out $actual_ref, expected $ref"
  [[ -f "$checkout/$rel_path" ]] || fail "entry not found: $id/$rel_path"

  case_count=$((case_count + 1))
  label="$id.$case_count.$(basename "$rel_path" .wgsl)"
  moon_output="$tmpdir/$label.moon.wgsl"
  oracle_output="$tmpdir/$label.oracle.wgsl"
  moon_fingerprint="$tmpdir/$label.moon.interface.txt"
  oracle_fingerprint="$tmpdir/$label.oracle.interface.txt"

  echo "== External naga-oil compose parity: $id $rel_path =="
  moon_args=(--fixture-root "$checkout" --entry "$rel_path" --output "$moon_output")
  oracle_args=(--fixture-root "$checkout" --entry "$rel_path" --output "$oracle_output")
  fingerprint_args=()

  if [[ "$id" == "bevy" ]]; then
    append_bevy_default_oracle_defs
  fi
  append_moon_bool_defs "$bool_defs"
  append_oracle_defs "$bool_defs"
  append_moon_value_defs "$value_defs"
  append_oracle_defs "$value_defs"
  append_imports "$additional_imports"
  append_capabilities "$capabilities"

  if ! moon_compose >"$tmpdir/$label.moon.stdout" 2>"$tmpdir/$label.moon.stderr"; then
    sed -n '1,120p' "$tmpdir/$label.moon.stdout" >&2
    sed -n '1,120p' "$tmpdir/$label.moon.stderr" >&2
    fail "moon compose failed for $id/$rel_path"
  fi
  if ! oracle_compose >"$tmpdir/$label.oracle.stdout" 2>"$tmpdir/$label.oracle.stderr"; then
    sed -n '1,120p' "$tmpdir/$label.oracle.stdout" >&2
    sed -n '1,120p' "$tmpdir/$label.oracle.stderr" >&2
    fail "naga-oil oracle compose failed for $id/$rel_path"
  fi
  fingerprint_wgsl "$moon_output" "$moon_fingerprint"
  fingerprint_wgsl "$oracle_output" "$oracle_fingerprint"
  compare_fingerprints "$oracle_fingerprint" "$moon_fingerprint" "$label"
done < "$manifest"

((case_count > 0)) || fail "manifest contains no parity cases"
((case_count == expected_case_count)) || fail "manifest contains $case_count parity case(s); expected exactly $expected_case_count"

echo "external naga-oil compose parity gate passed: cases=$case_count"
