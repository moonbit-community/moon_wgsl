#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

manifest="${WGSL_DIFFERENTIAL_GENERATED_MANIFEST:-testdata/wgsl_differential_generated_manifest.tsv}"

fail() {
  printf 'WGSL differential generated gate failed: %s\n' "$*" >&2
  exit 1
}

[[ -f "$manifest" ]] || fail "missing manifest: $manifest"

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

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

write_case_source() {
  local id="$1"
  local output="$2"
  case "$id" in
    vector-select-modf-frexp)
      cat > "$output" <<'WGSL'
@fragment
fn main(@location(0) uv: vec2f) -> @location(0) vec4f {
  let selected: vec2f = select(vec2f(1.0, 2.0), vec2f(3.0, 4.0), vec2<bool>((uv.x > 0.5), (uv.y > 0.5)));
  let m = modf(selected);
  let f = frexp(selected);
  return vec4f(m.fract + m.whole + f.fract + vec2f(f.exp), 0.0, 1.0);
}
WGSL
      ;;
    integer-vector-builtins)
      cat > "$output" <<'WGSL'
@compute @workgroup_size(1)
fn main() {
  let v: vec3u = vec3u(1u, 2u, 4u);
  let bits: vec3u = countOneBits(v) + reverseBits(v) + countLeadingZeros(v) + countTrailingZeros(v);
  let extracted: vec3u = extractBits(bits, 0u, 4u);
  let inserted: vec3u = insertBits(bits, extracted, 4u, 4u);
  let leading: vec3i = firstLeadingBit(vec3i(inserted));
  let trailing: vec3u = firstTrailingBit(inserted);
}
WGSL
      ;;
    texture-optional-arguments)
      cat > "$output" <<'WGSL'
@group(0) @binding(0) var tex: texture_2d<f32>;
@group(0) @binding(1) var samp: sampler;
@group(0) @binding(2) var depth_tex: texture_depth_2d;
@group(0) @binding(3) var cmp_samp: sampler_comparison;

@fragment
fn main() -> @location(0) vec4f {
  let uv: vec2f = vec2f(0.5, 0.25);
  let dims: vec2u = textureDimensions(tex, 0u);
  let base: vec4f = textureSample(tex, samp, uv);
  let clamped: vec4f = textureSampleBaseClampToEdge(tex, samp, uv);
  let gathered: vec4f = textureGather(2u, tex, samp, uv);
  let compared: f32 = textureSampleCompare(depth_tex, cmp_samp, uv, 0.5);
  return base + clamped + gathered + vec4f(f32(dims.x) * 0.0 + compared);
}
WGSL
      ;;
    atomic-barrier-statements)
      cat > "$output" <<'WGSL'
var<workgroup> counter: atomic<i32>;
@group(0) @binding(0) var<storage, read_write> output: array<i32>;

@compute @workgroup_size(1)
fn main(@builtin(local_invocation_index) idx: u32) {
  atomicStore(&counter, 1i);
  workgroupBarrier();
  let old: i32 = atomicAdd(&counter, 2i);
  let exchanged = atomicCompareExchangeWeak(&counter, old + 2i, 10i);
  storageBarrier();
  textureBarrier();
  output[idx] = exchanged.old_value + select(0i, 1i, exchanged.exchanged);
}
WGSL
      ;;
    pointer-deref-store)
      cat > "$output" <<'WGSL'
var<private> global_value: u32;

fn inc(p: ptr<private, u32>) {
  (*p) += 1u;
}

@compute @workgroup_size(1)
fn main() {
  inc(&global_value);
}
WGSL
      ;;
    local-pointer-value)
      cat > "$output" <<'WGSL'
fn inc(p: ptr<function, u32>) {
  (*p) += 1u;
}

@compute @workgroup_size(1)
fn main() {
  var x: u32 = 1u;
  let p = &x;
  (*p) = (*p) + 1u;
  inc(p);
}
WGSL
      ;;
    unary-const-switch)
      cat > "$output" <<'WGSL'
const NEG = -1;

fn choose(value: i32) -> u32 {
  switch value {
    case NEG: {
      return 1u;
    }
    default {
      return 0u;
    }
  }
}
WGSL
      ;;
    layout-abi-preservation)
      cat > "$output" <<'WGSL'
struct Item {
  @size(16) a: f32,
  @align(16) b: vec2f,
}

@group(0) @binding(0) var<uniform> item: Item;
@group(0) @binding(1) var<storage> values: array<u32>;
@group(0) @binding(2) var<storage, read_write> output: array<u32>;

@compute @workgroup_size(1)
fn main(@builtin(global_invocation_id) id: vec3u) {
  if id.x < arrayLength(&values) {
    output[id.x] = values[id.x] + u32(item.a + item.b.x);
  }
}
WGSL
      ;;
    entry-io-preservation)
      cat > "$output" <<'WGSL'
struct VOut {
  @builtin(position) pos: vec4f,
  @location(0) @interpolate(flat) idx: u32,
  @location(1) @interpolate(perspective, centroid) uv: vec2f,
}

@vertex
fn vs(@builtin(vertex_index) vertex_index: u32) -> VOut {
  var out: VOut;
  out.pos = vec4f(0.0, 0.0, 0.0, 1.0);
  out.idx = vertex_index;
  out.uv = vec2f(0.0);
  return out;
}

@fragment
fn fs(in: VOut) -> @location(0) vec4f {
  return vec4f(in.uv, f32(in.idx), 1.0);
}
WGSL
      ;;
    ray-query-full)
      cat > "$output" <<'WGSL'
enable wgpu_ray_query;

@group(0) @binding(0) var tlas: acceleration_structure;

fn ray_func() -> f32 {
  var rq: ray_query;
  let desc: RayDesc = RayDesc(0u, 255u, 0.0001f, 100000f, vec3f(0f, 0f, 0f), vec3f(1f, 0f, 0f));
  rayQueryInitialize(&rq, tlas, desc);
  rayQueryProceed(&rq);
  let candidate: RayIntersection = rayQueryGetCandidateIntersection(&rq);
  rayQueryGenerateIntersection(&rq, 1.0f);
  rayQueryConfirmIntersection(&rq);
  let committed: RayIntersection = rayQueryGetCommittedIntersection(&rq);
  rayQueryTerminate(&rq);
  return candidate.t + committed.t;
}

fn main() -> f32 {
  return ray_func();
}
WGSL
      ;;
    *)
      fail "no generated source template for case: $id"
      ;;
  esac
}

assert_tokens() {
  local id="$1"
  local emitted="$2"
  local checks="$3"
  local token
  [[ "$checks" != "-" && -n "$checks" ]] || return 0
  IFS=',' read -r -a tokens <<< "$checks"
  for token in "${tokens[@]}"; do
    [[ -n "$token" ]] || continue
    rg -F "$token" "$emitted" >/dev/null ||
      fail "case $id emitted WGSL lost required token: $token"
  done
}

rows="$tmpdir/rows.tsv"
awk -F '\t' '
  NF == 0 { next }
  $1 == "" { next }
  $1 ~ /^#/ { next }
  $1 == "id" { next }
  NF < 4 {
    printf("manifest row has %d field(s), expected 4: %s\n", NF, $0) > "/dev/stderr"
    exit 1
  }
  { print }
' "$manifest" > "$rows"

case_count=0
while IFS=$'\t' read -r id capabilities checks notes; do
  [[ -n "$notes" ]] || fail "case $id must have notes"
  source="$tmpdir/$id.source.wgsl"
  emitted="$tmpdir/$id.emitted.wgsl"
  echo "== WGSL generated differential: $id =="
  write_case_source "$id" "$source"
  validate_wgsl "$source" "$capabilities"
  moon run tools/ir_roundtrip -- --input "$source" --output "$emitted" >/dev/null
  moon run tools/ir_roundtrip -- --mode parse --input "$emitted" --output "$tmpdir/$id.parse.out" >/dev/null
  validate_wgsl "$emitted" "$capabilities"
  assert_tokens "$id" "$emitted" "$checks"
  case_count=$((case_count + 1))
done < "$rows"

((case_count > 0)) || fail "manifest contains no generated differential cases"

echo "WGSL generated differential gate passed: cases=$case_count"
