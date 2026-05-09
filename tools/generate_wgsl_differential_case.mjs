#!/usr/bin/env node

const cases = {
  "vector-select-modf-frexp": () => `@fragment
fn main(@location(0) uv: vec2f) -> @location(0) vec4f {
  let selected: vec2f = select(vec2f(1.0, 2.0), vec2f(3.0, 4.0), vec2<bool>((uv.x > 0.5), (uv.y > 0.5)));
  let m = modf(selected);
  let f = frexp(selected);
  return vec4f(m.fract + m.whole + f.fract + vec2f(f.exp), 0.0, 1.0);
}
`,
  "integer-vector-builtins": () => `@compute @workgroup_size(1)
fn main() {
  let v: vec3u = vec3u(1u, 2u, 4u);
  let bits: vec3u = countOneBits(v) + reverseBits(v) + countLeadingZeros(v) + countTrailingZeros(v);
  let extracted: vec3u = extractBits(bits, 0u, 4u);
  let inserted: vec3u = insertBits(bits, extracted, 4u, 4u);
  let leading: vec3i = firstLeadingBit(vec3i(inserted));
  let trailing: vec3u = firstTrailingBit(inserted);
}
`,
  "texture-optional-arguments": () => `@group(0) @binding(0) var tex: texture_2d<f32>;
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
`,
  "atomic-barrier-statements": () => `var<workgroup> counter: atomic<i32>;
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
`,
  "pointer-deref-store": () => `var<private> global_value: u32;

fn inc(p: ptr<private, u32>) {
  (*p) += 1u;
}

@compute @workgroup_size(1)
fn main() {
  inc(&global_value);
}
`,
  "local-pointer-value": () => `fn inc(p: ptr<function, u32>) {
  (*p) += 1u;
}

@compute @workgroup_size(1)
fn main() {
  var x: u32 = 1u;
  let p = &x;
  (*p) = (*p) + 1u;
  inc(p);
}
`,
  "unary-const-switch": () => `const NEG = -1;

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
`,
  "layout-abi-preservation": () => `struct Item {
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
`,
  "entry-io-preservation": () => `struct VOut {
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
`,
  "ray-query-full": () => `enable wgpu_ray_query;

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
`,
  "abstract-composite-access": () => `const idx = 0i;
const_assert mat2x2(1.11001100110011008404, 1, 1, 1)[idx][0i] == 1.11001100110011008404;

fn main() -> f32 {
  let m = mat3x2(1.0, 2.0, 3.0, 4.0, 5.0, 6.0);
  let v = array<vec2f, 3>(m[0], m[1], m[2]);
  return v[2u].y;
}
`,
  "scoped-control-flow": () => `fn classify(seed: u32) -> u32 {
  var total = 0u;
  for (var i = 0u; i < 4u; i = i + 1u) {
    if i == seed {
      continue;
    } else if i == 3u {
      break;
    }
    total += i;
  }
  var j = 0u;
  loop {
    switch j {
      case 0u, 1u: {
        total += 10u;
      }
      default: {
        total += 1u;
      }
    }
    continuing {
      j += 1u;
      break if j >= 4u;
    }
  }
  return total;
}

@compute @workgroup_size(1)
fn main() {
  _ = classify(2u);
}
`,
  "nested-lvalue-writeback": () => `struct Inner {
  values: array<vec4u, 2>,
}

struct Outer {
  inner: Inner,
}

fn bump_z(value: ptr<function, vec4u>) {
  (*value).z += 1u;
}

@compute @workgroup_size(1)
fn main() {
  var outer = Outer(Inner(array<vec4u, 2>(vec4u(1u), vec4u(2u))));
  outer.inner.values[1u].z += 4u;
  bump_z(&outer.inner.values[1u]);
}
`,
  "numeric-literal-boundaries": () => `const LARGE_U32: u32 = 3221225472u;
const HEX_MASK: u32 = 0xff00ff00u;
const DEC_VALUE: u32 = 165u;
const NEG_I32: i32 = -2147483647i - 1i;

@compute @workgroup_size(1)
fn main() {
  let folded: u32 = LARGE_U32 ^ HEX_MASK ^ DEC_VALUE;
  let signed: i32 = NEG_I32 + 1i;
}
`,
  "storage-texture-atomics": () => `@group(0) @binding(0) var tex: texture_storage_2d<r32uint, atomic>;
@group(0) @binding(1) var<storage, read_write> out: array<u32>;

@compute @workgroup_size(1)
fn main(@builtin(global_invocation_id) id: vec3u) {
  let xy = vec2i(id.xy);
  textureAtomicAdd(tex, xy, 3u);
  textureAtomicMax(tex, xy, 4u);
  out[0u] = id.x;
}
`,
  "function-call-boundaries": () => `fn mix3(a: u32, b: u32, c: u32) -> u32 {
  return a + b * c;
}

fn sink(a: u32, b: u32, c: u32) {
  _ = mix3(a, b, c);
}

@compute @workgroup_size(1)
fn main() {
  let x = mix3(1u, 2u, mix3(3u, 4u, 5u));
  sink(x, mix3(6u, 7u, 8u), 9u);
}
`,
};

const args = process.argv.slice(2);
if (args.length === 1 && args[0] === "--list") {
  for (const id of Object.keys(cases).sort()) {
    console.log(id);
  }
  process.exit(0);
}

if (args.length !== 1 || !cases[args[0]]) {
  console.error("usage: node tools/generate_wgsl_differential_case.mjs --list|CASE_ID");
  process.exit(1);
}

process.stdout.write(cases[args[0]]());
