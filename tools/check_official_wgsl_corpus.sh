#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

cts_ref="${WGSL_CTS_REF:-3b327ebc44f11212fd3872972a6dd394634fb9e3}"
cts_root="${WGSL_CTS_ROOT:-$repo_root/.moon_wgsl_cache/gpuweb_cts}"
allowlist="$repo_root/testdata/gpuweb_cts_ir_allowlist.txt"
min_parse_cases="${WGSL_CTS_MIN_PARSE_CASES:-100}"
min_ir_cases="${WGSL_CTS_MIN_IR_CASES:-110}"

if [[ ! -d "$cts_root/.git" ]]; then
  mkdir -p "$(dirname "$cts_root")"
  git clone --filter=blob:none --sparse https://github.com/gpuweb/cts.git "$cts_root"
  git -C "$cts_root" sparse-checkout set src/webgpu/shader/validation
fi
git -C "$cts_root" fetch --depth 1 origin "$cts_ref"
git -C "$cts_root" checkout --quiet FETCH_HEAD
git -C "$cts_root" sparse-checkout set src/webgpu/shader/validation

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

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
if [[ ! -f "$allowlist" ]]; then
  echo "missing IR allowlist: $allowlist" >&2
  exit 1
fi
ir_count=0
while IFS= read -r id; do
  [[ "$id" == "" || "$id" == \#* ]] && continue
  case_file="$cases_dir/$id.wgsl"
  if [[ ! -f "$case_file" ]]; then
    echo "official WGSL CTS IR allowlist id not found in extracted manifest: $id" >&2
    echo "current extracted manifest:" >&2
    sed -n '1,120p' "$manifest" >&2
    exit 1
  fi
  emitted="$tmpdir/$id.ir.wgsl"
  moon run tools/ir_roundtrip -- --input "$case_file" --output "$emitted" >/dev/null
  validate_args=()
  if grep -q 'enable f16' "$emitted" || grep -q 'f16' "$emitted" || grep -q 'vec[234]h' "$emitted" || grep -q 'mat[234]x[234]h' "$emitted"; then
    validate_args+=(--capability f16)
  fi
  if grep -q 'enable subgroups' "$emitted"; then
    validate_args+=(--capability subgroups)
  fi
  if grep -q '@blend_src' "$emitted"; then
    validate_args+=(--capability dual-source-blending)
  fi
  if grep -q 'texture_external' "$emitted"; then
    validate_args+=(--capability texture-external)
  fi
  if ((${#validate_args[@]} == 0)); then
    cargo run --quiet --manifest-path tools/naga_oil_oracle/Cargo.toml --bin wgsl_validate -- "$emitted" >/dev/null
  else
    cargo run --quiet --manifest-path tools/naga_oil_oracle/Cargo.toml --bin wgsl_validate -- "${validate_args[@]}" "$emitted" >/dev/null
  fi
  ir_count=$((ir_count + 1))
done < "$allowlist"

if ((ir_count == 0)); then
  echo "official WGSL CTS IR allowlist is empty" >&2
  exit 1
fi
if ((ir_count < min_ir_cases)); then
  echo "official WGSL CTS IR allowlist contains only $ir_count case(s); expected at least $min_ir_cases" >&2
  exit 1
fi

echo "official WGSL CTS corpus gate passed: parsed $case_count case(s), IR-roundtripped $ir_count allowlisted case(s)"
