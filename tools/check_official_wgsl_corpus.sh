#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

cts_ref="${WGSL_CTS_REF:-main}"
cts_root="${WGSL_CTS_ROOT:-$repo_root/.moon_wgsl_cache/gpuweb_cts}"
blocked_by_oracle="$repo_root/testdata/gpuweb_cts_ir_blocked_by_oracle.txt"
execution_blocked_by_oracle="$repo_root/testdata/gpuweb_cts_execution_ir_blocked_by_oracle.txt"
min_parse_cases="${WGSL_CTS_MIN_PARSE_CASES:-114}"
min_ir_cases="${WGSL_CTS_MIN_IR_CASES:-111}"
min_execution_cases="${WGSL_CTS_MIN_EXECUTION_CASES:-28}"
min_execution_ir_cases="${WGSL_CTS_MIN_EXECUTION_IR_CASES:-25}"

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
  if grep -q '@blend_src' "$emitted"; then
    validate_args+=(--capability dual-source-blending)
  fi
  if grep -q 'texture_external' "$emitted"; then
    validate_args+=(--capability texture-external)
  fi
  if grep -q 'var<immediate>' "$emitted"; then
    validate_args+=(--capability immediates)
  fi
  if ((${#validate_args[@]} == 0)); then
    cargo run --quiet --manifest-path tools/naga_oil_oracle/Cargo.toml --bin wgsl_validate -- "$emitted" >/dev/null
  else
    cargo run --quiet --manifest-path tools/naga_oil_oracle/Cargo.toml --bin wgsl_validate -- "${validate_args[@]}" "$emitted" >/dev/null
  fi
}

cases_dir="$tmpdir/cases"
manifest="$tmpdir/manifest.tsv"
node tools/extract_gpuweb_cts_static_wgsl.mjs "$cts_root" "$cases_dir" "$manifest"

case_count="$(find "$cases_dir" -name '*.wgsl' -type f | wc -l | tr -d ' ')"
if [[ "$case_count" == "0" ]]; then
  echo "official WGSL CTS extractor produced no static valid WGSL cases" >&2
  exit 1
fi
if ((case_count < min_parse_cases)); then
  echo "official WGSL CTS extractor produced only $case_count static valid WGSL cases; expected at least $min_parse_cases" >&2
  exit 1
fi

echo "== GPUWeb CTS WGSL parse corpus =="
echo "CTS ref: $(git -C "$cts_root" rev-parse HEAD)"
echo "static valid WGSL cases: $case_count"
while IFS= read -r case_file; do
  moon run tools/ir_roundtrip -- --mode parse --input "$case_file" --output "$tmpdir/parse.out" >/dev/null
done < <(find "$cases_dir" -name '*.wgsl' -type f | sort)

echo "== GPUWeb CTS WGSL IR corpus =="
if [[ ! -f "$blocked_by_oracle" ]]; then
  echo "missing IR blocked-by-oracle manifest: $blocked_by_oracle" >&2
  exit 1
fi
extracted_ids="$tmpdir/extracted.ids"
oracle_blocked_ids="$tmpdir/oracle-blocked.ids"
find "$cases_dir" -name '*.wgsl' -type f -exec basename {} .wgsl \; | sort > "$extracted_ids"
grep -v -E '^($|#)' "$blocked_by_oracle" | sort > "$oracle_blocked_ids"
ir_count=0
oracle_blocked_count=0
while IFS= read -r id; do
  case_file="$cases_dir/$id.wgsl"
  if [[ ! -f "$case_file" ]]; then
    continue
  fi
  emitted="$tmpdir/$id.ir.wgsl"
  moon run tools/ir_roundtrip -- --input "$case_file" --output "$emitted" >/dev/null
  moon run tools/ir_roundtrip -- --mode parse --input "$emitted" --output "$tmpdir/reparse.out" >/dev/null
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
if ((ir_count < min_ir_cases)); then
  echo "official WGSL CTS validated IR corpus contains only $ir_count case(s); expected at least $min_ir_cases" >&2
  exit 1
fi

echo "== GPUWeb CTS WGSL execution IR corpus =="
execution_cases_dir="$tmpdir/execution-cases"
execution_manifest="$tmpdir/execution-manifest.tsv"
node tools/extract_gpuweb_cts_execution_static_wgsl.mjs "$cts_root" "$execution_cases_dir" "$execution_manifest"
execution_case_count="$(find "$execution_cases_dir" -name '*.wgsl' -type f | wc -l | tr -d ' ')"
if ((execution_case_count < min_execution_cases)); then
  echo "official WGSL CTS execution extractor produced only $execution_case_count static WGSL cases; expected at least $min_execution_cases" >&2
  exit 1
fi
if [[ ! -f "$execution_blocked_by_oracle" ]]; then
  echo "missing execution IR blocked-by-oracle manifest: $execution_blocked_by_oracle" >&2
  exit 1
fi
execution_extracted_ids="$tmpdir/execution-extracted.ids"
execution_oracle_blocked_ids="$tmpdir/execution-oracle-blocked.ids"
find "$execution_cases_dir" -name '*.wgsl' -type f -exec basename {} .wgsl \; | sort > "$execution_extracted_ids"
grep -v -E '^($|#)' "$execution_blocked_by_oracle" | sort > "$execution_oracle_blocked_ids"
execution_ir_count=0
execution_oracle_blocked_count=0
while IFS= read -r id; do
  case_file="$execution_cases_dir/$id.wgsl"
  emitted="$tmpdir/$id.execution.ir.wgsl"
  moon run tools/ir_roundtrip -- --mode parse --input "$case_file" --output "$tmpdir/execution-parse.out" >/dev/null
  moon run tools/ir_roundtrip -- --input "$case_file" --output "$emitted" >/dev/null
  moon run tools/ir_roundtrip -- --mode parse --input "$emitted" --output "$tmpdir/execution-reparse.out" >/dev/null
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

if ((execution_ir_count < min_execution_ir_cases)); then
  echo "official WGSL CTS execution validated IR corpus contains only $execution_ir_count case(s); expected at least $min_execution_ir_cases" >&2
  exit 1
fi

echo "official WGSL CTS corpus gate passed: validation cases=$case_count validation-naga=$ir_count validation-oracle-blocked=$oracle_blocked_count execution cases=$execution_case_count execution-naga=$execution_ir_count execution-oracle-blocked=$execution_oracle_blocked_count"
