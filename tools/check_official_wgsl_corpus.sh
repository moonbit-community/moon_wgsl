#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

cts_ref="${WGSL_CTS_REF:-3b327ebc44f11212fd3872972a6dd394634fb9e3}"
cts_root="${WGSL_CTS_ROOT:-$repo_root/.moon_wgsl_cache/gpuweb_cts}"
blocked_by_oracle="$repo_root/testdata/gpuweb_cts_ir_blocked_by_oracle.txt"
template_blocked_by_oracle="$repo_root/testdata/gpuweb_cts_template_ir_blocked_by_oracle.txt"
execution_blocked_by_oracle="$repo_root/testdata/gpuweb_cts_execution_ir_blocked_by_oracle.txt"
invalid_accepted_by_oracle="$repo_root/testdata/gpuweb_cts_invalid_accepted_by_oracle.txt"
template_invalid_accepted_by_oracle="$repo_root/testdata/gpuweb_cts_template_invalid_accepted_by_oracle.txt"
expected_parse_cases="${WGSL_CTS_EXPECTED_PARSE_CASES:-114}"
expected_ir_cases="${WGSL_CTS_EXPECTED_IR_CASES:-111}"
expected_oracle_blocked_cases="${WGSL_CTS_EXPECTED_ORACLE_BLOCKED_CASES:-3}"
expected_template_valid_cases="${WGSL_CTS_EXPECTED_TEMPLATE_VALID_CASES:-99}"
expected_template_ir_cases="${WGSL_CTS_EXPECTED_TEMPLATE_IR_CASES:-97}"
expected_template_oracle_blocked_cases="${WGSL_CTS_EXPECTED_TEMPLATE_ORACLE_BLOCKED_CASES:-2}"
expected_invalid_cases="${WGSL_CTS_EXPECTED_INVALID_CASES:-87}"
expected_invalid_oracle_accepted_cases="${WGSL_CTS_EXPECTED_INVALID_ORACLE_ACCEPTED_CASES:-20}"
expected_template_invalid_cases="${WGSL_CTS_EXPECTED_TEMPLATE_INVALID_CASES:-57}"
expected_template_invalid_oracle_accepted_cases="${WGSL_CTS_EXPECTED_TEMPLATE_INVALID_ORACLE_ACCEPTED_CASES:-16}"
expected_execution_cases="${WGSL_CTS_EXPECTED_EXECUTION_CASES:-28}"
expected_execution_ir_cases="${WGSL_CTS_EXPECTED_EXECUTION_IR_CASES:-25}"
expected_execution_oracle_blocked_cases="${WGSL_CTS_EXPECTED_EXECUTION_ORACLE_BLOCKED_CASES:-3}"

if [[ ! -d "$cts_root/.git" ]]; then
  mkdir -p "$(dirname "$cts_root")"
  git clone --filter=blob:none --sparse https://github.com/gpuweb/cts.git "$cts_root"
  git -C "$cts_root" sparse-checkout set src/webgpu/shader/validation src/webgpu/shader/execution
fi
git -C "$cts_root" fetch --depth 1 origin "$cts_ref"
git -C "$cts_root" checkout --quiet FETCH_HEAD
git -C "$cts_root" sparse-checkout set src/webgpu/shader/validation src/webgpu/shader/execution

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

validate_wgsl_with_detected_capabilities() {
  local emitted="$1"
  local validate_args=()
  if grep -q 'enable f16' "$emitted" || grep -q 'f16' "$emitted" || grep -q 'vec[234]h' "$emitted" || grep -q 'mat[234]x[234]h' "$emitted"; then
    validate_args+=(--capability f16)
  fi
  if grep -q 'enable subgroups' "$emitted" || grep -q 'subgroup' "$emitted"; then
    validate_args+=(--capability subgroups)
  fi
  if grep -q 'enable dual_source_blending' "$emitted" || grep -q '@blend_src' "$emitted"; then
    validate_args+=(--capability dual-source-blending)
  fi
  if grep -q 'texture_external' "$emitted"; then
    validate_args+=(--capability texture-external)
  fi
  if grep -q 'textureAtomic' "$emitted" || grep -q 'texture_storage_.*atomic' "$emitted"; then
    validate_args+=(--capability texture-atomic)
  fi
  if grep -q 'var<immediate>' "$emitted"; then
    validate_args+=(--capability immediates)
  fi
  if grep -q 'binding_array' "$emitted"; then
    validate_args+=(--capability binding-arrays)
  fi
  if ((${#validate_args[@]} == 0)); then
    cargo run --quiet --manifest-path tools/naga_oil_oracle/Cargo.toml --bin wgsl_validate -- "$emitted" >/dev/null
  else
    cargo run --quiet --manifest-path tools/naga_oil_oracle/Cargo.toml --bin wgsl_validate -- "${validate_args[@]}" "$emitted" >/dev/null
  fi
}

print_case_failure() {
  local stage="$1"
  local id="$2"
  local case_file="$3"
  local stdout_file="$4"
  local stderr_file="$5"
  echo "official WGSL CTS $stage failed: $id" >&2
  echo "case file: $case_file" >&2
  if [[ -s "$stdout_file" ]]; then
    echo "stdout:" >&2
    sed -n '1,80p' "$stdout_file" >&2
  fi
  if [[ -s "$stderr_file" ]]; then
    echo "stderr:" >&2
    sed -n '1,80p' "$stderr_file" >&2
  fi
  echo "source:" >&2
  sed -n '1,120p' "$case_file" >&2
}

load_official_cts_id_manifest() {
  local path="$1"
  local label="$2"
  local output="$3"
  local duplicate_ids
  awk -F '\t' -v label="$label" '
    $0 ~ /^($|#)/ { next }
    NF != 1 {
      printf("%s manifest row has %d field(s), expected 1: %s\n", label, NF, $0) > "/dev/stderr"
      exit 1
    }
    $1 !~ /^src_webgpu_shader_/ {
      printf("%s manifest id has unexpected shape: %s\n", label, $1) > "/dev/stderr"
      exit 1
    }
    { print $1 }
  ' "$path" | sort > "$output"
  duplicate_ids="$(uniq -d "$output" | tr '\n' ' ')"
  if [[ -n "$duplicate_ids" ]]; then
    echo "$label manifest has duplicate id(s): $duplicate_ids" >&2
    exit 1
  fi
}

load_official_cts_extracted_manifest() {
  local manifest_path="$1"
  local cases_dir="$2"
  local label="$3"
  local output="$4"
  local file_ids="$output.files"
  local duplicate_ids
  awk -F '\t' -v label="$label" '
    $0 ~ /^($|#)/ { next }
    NF != 5 {
      printf("%s extracted manifest row has %d field(s), expected 5: %s\n", label, NF, $0) > "/dev/stderr"
      exit 1
    }
    $1 !~ /^src_webgpu_shader_/ {
      printf("%s extracted manifest id has unexpected shape: %s\n", label, $1) > "/dev/stderr"
      exit 1
    }
    $2 !~ /^src\/webgpu\/shader\// {
      printf("%s extracted manifest path has unexpected shape: %s\n", label, $2) > "/dev/stderr"
      exit 1
    }
    $3 !~ /^[0-9]+$/ {
      printf("%s extracted manifest line is not numeric: %s\n", label, $0) > "/dev/stderr"
      exit 1
    }
    $4 !~ /^[0-9a-f]{64}$/ {
      printf("%s extracted manifest sha256 is invalid: %s\n", label, $0) > "/dev/stderr"
      exit 1
    }
    $5 !~ /^[0-9]+$/ {
      printf("%s extracted manifest byte count is not numeric: %s\n", label, $0) > "/dev/stderr"
      exit 1
    }
    { print $1 }
  ' "$manifest_path" | sort > "$output"
  duplicate_ids="$(uniq -d "$output" | tr '\n' ' ')"
  if [[ -n "$duplicate_ids" ]]; then
    echo "$label extracted manifest has duplicate id(s): $duplicate_ids" >&2
    exit 1
  fi
  find "$cases_dir" -name '*.wgsl' -type f -exec basename {} .wgsl \; | sort > "$file_ids"
  if ! diff -u "$output" "$file_ids" >"$tmpdir/$label-extracted-manifest.diff"; then
    echo "official WGSL CTS $label extracted manifest does not match generated WGSL files" >&2
    sed -n '1,160p' "$tmpdir/$label-extracted-manifest.diff" >&2
    exit 1
  fi
}

cases_dir="$tmpdir/cases"
manifest="$tmpdir/manifest.tsv"
node tools/extract_gpuweb_cts_static_wgsl.mjs "$cts_root" "$cases_dir" "$manifest"
extracted_ids="$tmpdir/extracted.ids"
load_official_cts_extracted_manifest "$manifest" "$cases_dir" "static-valid" "$extracted_ids"

case_count="$(wc -l < "$extracted_ids" | tr -d ' ')"
if [[ "$case_count" == "0" ]]; then
  echo "official WGSL CTS extractor produced no static valid WGSL cases" >&2
  exit 1
fi
if ((case_count != expected_parse_cases)); then
  echo "official WGSL CTS extractor produced $case_count static valid WGSL cases; expected exactly $expected_parse_cases" >&2
  exit 1
fi

echo "== GPUWeb CTS WGSL parse corpus =="
echo "CTS ref: $(git -C "$cts_root" rev-parse HEAD)"
echo "static valid WGSL cases: $case_count"
while IFS= read -r case_file; do
  id="$(basename "$case_file" .wgsl)"
  if ! moon run tools/ir_roundtrip -- --mode parse --input "$case_file" --output "$tmpdir/parse.out" >"$tmpdir/$id.parse.stdout" 2>"$tmpdir/$id.parse.stderr"; then
    print_case_failure "parse" "$id" "$case_file" "$tmpdir/$id.parse.stdout" "$tmpdir/$id.parse.stderr"
    exit 1
  fi
done < <(find "$cases_dir" -name '*.wgsl' -type f | sort)

echo "== GPUWeb CTS WGSL IR corpus =="
if [[ ! -f "$blocked_by_oracle" ]]; then
  echo "missing IR blocked-by-oracle manifest: $blocked_by_oracle" >&2
  exit 1
fi
oracle_blocked_ids="$tmpdir/oracle-blocked.ids"
load_official_cts_id_manifest "$blocked_by_oracle" "static oracle-blocked" "$oracle_blocked_ids"
ir_count=0
oracle_blocked_count=0
while IFS= read -r id; do
  case_file="$cases_dir/$id.wgsl"
  if [[ ! -f "$case_file" ]]; then
    continue
  fi
  emitted="$tmpdir/$id.ir.wgsl"
  if ! moon run tools/ir_roundtrip -- --input "$case_file" --output "$emitted" >"$tmpdir/$id.ir.stdout" 2>"$tmpdir/$id.ir.stderr"; then
    print_case_failure "IR roundtrip" "$id" "$case_file" "$tmpdir/$id.ir.stdout" "$tmpdir/$id.ir.stderr"
    exit 1
  fi
  if ! moon run tools/ir_roundtrip -- --mode parse --input "$emitted" --output "$tmpdir/reparse.out" >"$tmpdir/$id.reparse.stdout" 2>"$tmpdir/$id.reparse.stderr"; then
    print_case_failure "IR reparse" "$id" "$emitted" "$tmpdir/$id.reparse.stdout" "$tmpdir/$id.reparse.stderr"
    exit 1
  fi
  if grep -Fxq "$id" "$oracle_blocked_ids"; then
    oracle_blocked_count=$((oracle_blocked_count + 1))
    continue
  fi
  validate_wgsl_with_detected_capabilities "$emitted"
  ir_count=$((ir_count + 1))
done < "$extracted_ids"

while IFS= read -r id; do
  if [[ ! -f "$cases_dir/$id.wgsl" ]]; then
    echo "official WGSL CTS oracle-blocked id not found in extracted manifest: $id" >&2
    echo "current extracted manifest:" >&2
    sed -n '1,160p' "$manifest" >&2
    exit 1
  fi
done < "$oracle_blocked_ids"

if ((ir_count == 0)); then
  echo "official WGSL CTS validated IR corpus is empty" >&2
  exit 1
fi
if ((ir_count != expected_ir_cases)); then
  echo "official WGSL CTS validated IR corpus contains $ir_count case(s); expected exactly $expected_ir_cases" >&2
  exit 1
fi
if ((oracle_blocked_count != expected_oracle_blocked_cases)); then
  echo "official WGSL CTS oracle-blocked corpus contains $oracle_blocked_count case(s); expected exactly $expected_oracle_blocked_cases" >&2
  exit 1
fi

echo "== GPUWeb CTS template WGSL corpus =="
template_cases_dir="$tmpdir/template-cases"
template_invalid_cases_dir="$tmpdir/template-invalid-cases"
template_manifest="$tmpdir/template-manifest.tsv"
template_invalid_manifest="$tmpdir/template-invalid-manifest.tsv"
node tools/extract_gpuweb_cts_template_wgsl.mjs "$cts_root" "$template_cases_dir" "$template_manifest" "$template_invalid_cases_dir" "$template_invalid_manifest"
template_extracted_ids="$tmpdir/template-extracted.ids"
load_official_cts_extracted_manifest "$template_manifest" "$template_cases_dir" "template-valid" "$template_extracted_ids"
template_case_count="$(wc -l < "$template_extracted_ids" | tr -d ' ')"
if ((template_case_count != expected_template_valid_cases)); then
  echo "official WGSL CTS template extractor produced $template_case_count valid WGSL cases; expected exactly $expected_template_valid_cases" >&2
  exit 1
fi
if [[ ! -f "$template_blocked_by_oracle" ]]; then
  echo "missing template IR blocked-by-oracle manifest: $template_blocked_by_oracle" >&2
  exit 1
fi
template_oracle_blocked_ids="$tmpdir/template-oracle-blocked.ids"
load_official_cts_id_manifest "$template_blocked_by_oracle" "template oracle-blocked" "$template_oracle_blocked_ids"
template_ir_count=0
template_oracle_blocked_count=0
while IFS= read -r id; do
  case_file="$template_cases_dir/$id.wgsl"
  emitted="$tmpdir/$id.template.ir.wgsl"
  if ! moon run tools/ir_roundtrip -- --mode parse --input "$case_file" --output "$tmpdir/template-parse.out" >"$tmpdir/$id.template-parse.stdout" 2>"$tmpdir/$id.template-parse.stderr"; then
    print_case_failure "template parse" "$id" "$case_file" "$tmpdir/$id.template-parse.stdout" "$tmpdir/$id.template-parse.stderr"
    exit 1
  fi
  if ! moon run tools/ir_roundtrip -- --input "$case_file" --output "$emitted" >"$tmpdir/$id.template-ir.stdout" 2>"$tmpdir/$id.template-ir.stderr"; then
    print_case_failure "template IR roundtrip" "$id" "$case_file" "$tmpdir/$id.template-ir.stdout" "$tmpdir/$id.template-ir.stderr"
    exit 1
  fi
  if ! moon run tools/ir_roundtrip -- --mode parse --input "$emitted" --output "$tmpdir/template-reparse.out" >"$tmpdir/$id.template-reparse.stdout" 2>"$tmpdir/$id.template-reparse.stderr"; then
    print_case_failure "template IR reparse" "$id" "$emitted" "$tmpdir/$id.template-reparse.stdout" "$tmpdir/$id.template-reparse.stderr"
    exit 1
  fi
  if grep -Fxq "$id" "$template_oracle_blocked_ids"; then
    template_oracle_blocked_count=$((template_oracle_blocked_count + 1))
    continue
  fi
  validate_wgsl_with_detected_capabilities "$emitted"
  template_ir_count=$((template_ir_count + 1))
done < "$template_extracted_ids"

while IFS= read -r id; do
  if [[ ! -f "$template_cases_dir/$id.wgsl" ]]; then
    echo "official WGSL CTS template oracle-blocked id not found in extracted manifest: $id" >&2
    echo "current template extracted manifest:" >&2
    sed -n '1,160p' "$template_manifest" >&2
    exit 1
  fi
done < "$template_oracle_blocked_ids"

if ((template_ir_count != expected_template_ir_cases)); then
  echo "official WGSL CTS template validated IR corpus contains $template_ir_count case(s); expected exactly $expected_template_ir_cases" >&2
  exit 1
fi
if ((template_oracle_blocked_count != expected_template_oracle_blocked_cases)); then
  echo "official WGSL CTS template oracle-blocked corpus contains $template_oracle_blocked_count case(s); expected exactly $expected_template_oracle_blocked_cases" >&2
  exit 1
fi

echo "== GPUWeb CTS WGSL execution IR corpus =="
execution_cases_dir="$tmpdir/execution-cases"
execution_manifest="$tmpdir/execution-manifest.tsv"
node tools/extract_gpuweb_cts_execution_static_wgsl.mjs "$cts_root" "$execution_cases_dir" "$execution_manifest"
execution_extracted_ids="$tmpdir/execution-extracted.ids"
load_official_cts_extracted_manifest "$execution_manifest" "$execution_cases_dir" "execution-valid" "$execution_extracted_ids"
execution_case_count="$(wc -l < "$execution_extracted_ids" | tr -d ' ')"
if ((execution_case_count != expected_execution_cases)); then
  echo "official WGSL CTS execution extractor produced $execution_case_count static WGSL cases; expected exactly $expected_execution_cases" >&2
  exit 1
fi
if [[ ! -f "$execution_blocked_by_oracle" ]]; then
  echo "missing execution IR blocked-by-oracle manifest: $execution_blocked_by_oracle" >&2
  exit 1
fi
execution_oracle_blocked_ids="$tmpdir/execution-oracle-blocked.ids"
load_official_cts_id_manifest "$execution_blocked_by_oracle" "execution oracle-blocked" "$execution_oracle_blocked_ids"
execution_ir_count=0
execution_oracle_blocked_count=0
while IFS= read -r id; do
  case_file="$execution_cases_dir/$id.wgsl"
  emitted="$tmpdir/$id.execution.ir.wgsl"
  if ! moon run tools/ir_roundtrip -- --mode parse --input "$case_file" --output "$tmpdir/execution-parse.out" >"$tmpdir/$id.execution-parse.stdout" 2>"$tmpdir/$id.execution-parse.stderr"; then
    print_case_failure "execution parse" "$id" "$case_file" "$tmpdir/$id.execution-parse.stdout" "$tmpdir/$id.execution-parse.stderr"
    exit 1
  fi
  if ! moon run tools/ir_roundtrip -- --input "$case_file" --output "$emitted" >"$tmpdir/$id.execution-ir.stdout" 2>"$tmpdir/$id.execution-ir.stderr"; then
    print_case_failure "execution IR roundtrip" "$id" "$case_file" "$tmpdir/$id.execution-ir.stdout" "$tmpdir/$id.execution-ir.stderr"
    exit 1
  fi
  if ! moon run tools/ir_roundtrip -- --mode parse --input "$emitted" --output "$tmpdir/execution-reparse.out" >"$tmpdir/$id.execution-reparse.stdout" 2>"$tmpdir/$id.execution-reparse.stderr"; then
    print_case_failure "execution IR reparse" "$id" "$emitted" "$tmpdir/$id.execution-reparse.stdout" "$tmpdir/$id.execution-reparse.stderr"
    exit 1
  fi
  if grep -Fxq "$id" "$execution_oracle_blocked_ids"; then
    execution_oracle_blocked_count=$((execution_oracle_blocked_count + 1))
    continue
  fi
  validate_wgsl_with_detected_capabilities "$emitted"
  execution_ir_count=$((execution_ir_count + 1))
done < "$execution_extracted_ids"

while IFS= read -r id; do
  if [[ ! -f "$execution_cases_dir/$id.wgsl" ]]; then
    echo "official WGSL CTS execution oracle-blocked id not found in extracted manifest: $id" >&2
    echo "current execution extracted manifest:" >&2
    sed -n '1,160p' "$execution_manifest" >&2
    exit 1
  fi
done < "$execution_oracle_blocked_ids"

if ((execution_ir_count != expected_execution_ir_cases)); then
  echo "official WGSL CTS execution validated IR corpus contains $execution_ir_count case(s); expected exactly $expected_execution_ir_cases" >&2
  exit 1
fi
if ((execution_oracle_blocked_count != expected_execution_oracle_blocked_cases)); then
  echo "official WGSL CTS execution oracle-blocked corpus contains $execution_oracle_blocked_count case(s); expected exactly $expected_execution_oracle_blocked_cases" >&2
  exit 1
fi

echo "== GPUWeb CTS invalid WGSL rejection corpus =="
invalid_cases_dir="$tmpdir/invalid-cases"
invalid_manifest="$tmpdir/invalid-manifest.tsv"
node tools/extract_gpuweb_cts_invalid_static_wgsl.mjs "$cts_root" "$invalid_cases_dir" "$invalid_manifest"
invalid_extracted_ids="$tmpdir/invalid-extracted.ids"
load_official_cts_extracted_manifest "$invalid_manifest" "$invalid_cases_dir" "static-invalid" "$invalid_extracted_ids"
invalid_case_count="$(wc -l < "$invalid_extracted_ids" | tr -d ' ')"
if ((invalid_case_count != expected_invalid_cases)); then
  echo "official WGSL CTS invalid extractor produced $invalid_case_count static WGSL cases; expected exactly $expected_invalid_cases" >&2
  exit 1
fi
if [[ ! -f "$invalid_accepted_by_oracle" ]]; then
  echo "missing invalid accepted-by-oracle manifest: $invalid_accepted_by_oracle" >&2
  exit 1
fi
invalid_expected_oracle_accepted_ids="$tmpdir/invalid-expected-oracle-accepted.ids"
invalid_actual_oracle_accepted_ids="$tmpdir/invalid-actual-oracle-accepted.ids"
load_official_cts_id_manifest "$invalid_accepted_by_oracle" "invalid accepted-by-oracle" "$invalid_expected_oracle_accepted_ids"
: > "$invalid_actual_oracle_accepted_ids"
while IFS= read -r invalid_case_file; do
  invalid_id="$(basename "$invalid_case_file" .wgsl)"
  invalid_emitted="$tmpdir/$invalid_id.invalid.ir.wgsl"
  if moon run tools/ir_roundtrip -- --input "$invalid_case_file" --output "$invalid_emitted" >/dev/null 2>"$tmpdir/$invalid_id.invalid-ir.stderr" &&
     validate_wgsl_with_detected_capabilities "$invalid_emitted" >/dev/null 2>"$tmpdir/$invalid_id.invalid-naga.stderr"; then
    if grep -Fxq "$invalid_id" "$invalid_expected_oracle_accepted_ids"; then
      echo "$invalid_id" >> "$invalid_actual_oracle_accepted_ids"
      continue
    fi
    echo "official WGSL CTS invalid case unexpectedly passed moon IR plus Naga validation: $invalid_id" >&2
    sed -n '1,120p' "$invalid_case_file" >&2
    exit 1
  fi
done < <(
  while IFS= read -r invalid_id; do
    printf '%s/%s.wgsl\n' "$invalid_cases_dir" "$invalid_id"
  done < "$invalid_extracted_ids"
)
sort -o "$invalid_actual_oracle_accepted_ids" "$invalid_actual_oracle_accepted_ids"
invalid_oracle_accepted_count="$(wc -l < "$invalid_actual_oracle_accepted_ids" | tr -d ' ')"
if ((invalid_oracle_accepted_count != expected_invalid_oracle_accepted_cases)); then
  echo "official WGSL CTS invalid oracle-accepted count is $invalid_oracle_accepted_count; expected exactly $expected_invalid_oracle_accepted_cases" >&2
  exit 1
fi
if ! diff -u "$invalid_expected_oracle_accepted_ids" "$invalid_actual_oracle_accepted_ids" >"$tmpdir/invalid-oracle-accepted.diff"; then
  echo "official WGSL CTS invalid accepted-by-oracle manifest is out of date" >&2
  sed -n '1,160p' "$tmpdir/invalid-oracle-accepted.diff" >&2
  exit 1
fi

template_invalid_extracted_ids="$tmpdir/template-invalid-extracted.ids"
load_official_cts_extracted_manifest "$template_invalid_manifest" "$template_invalid_cases_dir" "template-invalid" "$template_invalid_extracted_ids"
template_invalid_case_count="$(wc -l < "$template_invalid_extracted_ids" | tr -d ' ')"
if ((template_invalid_case_count != expected_template_invalid_cases)); then
  echo "official WGSL CTS template invalid extractor produced $template_invalid_case_count WGSL cases; expected exactly $expected_template_invalid_cases" >&2
  exit 1
fi
if [[ ! -f "$template_invalid_accepted_by_oracle" ]]; then
  echo "missing template invalid accepted-by-oracle manifest: $template_invalid_accepted_by_oracle" >&2
  exit 1
fi
template_invalid_expected_oracle_accepted_ids="$tmpdir/template-invalid-expected-oracle-accepted.ids"
template_invalid_actual_oracle_accepted_ids="$tmpdir/template-invalid-actual-oracle-accepted.ids"
load_official_cts_id_manifest "$template_invalid_accepted_by_oracle" "template invalid accepted-by-oracle" "$template_invalid_expected_oracle_accepted_ids"
: > "$template_invalid_actual_oracle_accepted_ids"
while IFS= read -r invalid_case_file; do
  invalid_id="$(basename "$invalid_case_file" .wgsl)"
  invalid_emitted="$tmpdir/$invalid_id.template-invalid.ir.wgsl"
  if moon run tools/ir_roundtrip -- --input "$invalid_case_file" --output "$invalid_emitted" >/dev/null 2>"$tmpdir/$invalid_id.template-invalid-ir.stderr" &&
     validate_wgsl_with_detected_capabilities "$invalid_emitted" >/dev/null 2>"$tmpdir/$invalid_id.template-invalid-naga.stderr"; then
    if grep -Fxq "$invalid_id" "$template_invalid_expected_oracle_accepted_ids"; then
      echo "$invalid_id" >> "$template_invalid_actual_oracle_accepted_ids"
      continue
    fi
    echo "official WGSL CTS template invalid case unexpectedly passed moon IR plus Naga validation: $invalid_id" >&2
    sed -n '1,120p' "$invalid_case_file" >&2
    exit 1
  fi
done < <(
  while IFS= read -r invalid_id; do
    printf '%s/%s.wgsl\n' "$template_invalid_cases_dir" "$invalid_id"
  done < "$template_invalid_extracted_ids"
)
sort -o "$template_invalid_actual_oracle_accepted_ids" "$template_invalid_actual_oracle_accepted_ids"
template_invalid_oracle_accepted_count="$(wc -l < "$template_invalid_actual_oracle_accepted_ids" | tr -d ' ')"
if ((template_invalid_oracle_accepted_count != expected_template_invalid_oracle_accepted_cases)); then
  echo "official WGSL CTS template invalid oracle-accepted count is $template_invalid_oracle_accepted_count; expected exactly $expected_template_invalid_oracle_accepted_cases" >&2
  exit 1
fi
if ! diff -u "$template_invalid_expected_oracle_accepted_ids" "$template_invalid_actual_oracle_accepted_ids" >"$tmpdir/template-invalid-oracle-accepted.diff"; then
  echo "official WGSL CTS template invalid accepted-by-oracle manifest is out of date" >&2
  sed -n '1,160p' "$tmpdir/template-invalid-oracle-accepted.diff" >&2
  exit 1
fi

invalid_rejected_count=$((invalid_case_count - invalid_oracle_accepted_count))
template_invalid_rejected_count=$((template_invalid_case_count - template_invalid_oracle_accepted_count))
echo "official WGSL CTS corpus gate passed: validation cases=$case_count validation-naga=$ir_count validation-oracle-blocked=$oracle_blocked_count template-validation cases=$template_case_count template-validation-naga=$template_ir_count template-validation-oracle-blocked=$template_oracle_blocked_count execution cases=$execution_case_count execution-naga=$execution_ir_count execution-oracle-blocked=$execution_oracle_blocked_count invalid-rejected=$invalid_rejected_count invalid-oracle-accepted=$invalid_oracle_accepted_count template-invalid-rejected=$template_invalid_rejected_count template-invalid-oracle-accepted=$template_invalid_oracle_accepted_count"
