///|
test "IR emitter does not count texture store as extra writer arena slot" {
  let source =
    #|@group(0) @binding(0) var tex: texture_2d<f32>;
    #|@group(0) @binding(1) var samp: sampler;
    #|
    #|fn fragment(uv: vec2<f32>) -> vec4<f32> {
    #|  var color = textureSample(tex, samp, uv);
    #|  return color;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir_compat_writer(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("let _e3: vec4<f32> = textureSample(tex, samp, uv);"),
    content="true",
  )
  debug_inspect(emitted.contains("let _e5: vec4<f32> = color;"), content="true")
  debug_inspect(emitted.contains("return _e5;"), content="true")
  debug_inspect(
    emitted.contains("let _e6: vec4<f32> = color;"),
    content="false",
  )
}

///|
test "naga-oil writer profile preserves source directives like upstream Writer" {
  let source =
    #|enable dual_source_blending;
    #|
    #|struct Out {
    #|  @location(0) @blend_src(0) a: vec4<f32>,
    #|  @location(0) @blend_src(1) b: vec4<f32>,
    #|}
    #|
    #|@fragment
    #|fn fragment() -> Out {
    #|  return Out(vec4<f32>(0.0), vec4<f32>(1.0));
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let runtime = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  let parity = emit_wgsl_module_from_ir_compat_writer(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    runtime.contains("enable dual_source_blending;"),
    content="true",
  )
  debug_inspect(parity.contains("enable dual_source_blending;"), content="true")
}

///|
test "naga-oil writer profile drops inactive semantic extension enables" {
  let source =
    #|enable dual_source_blending;
    #|
    #|struct FragmentOutput {
    #|  @location(0) color: vec4<f32>,
    #|}
    #|
    #|@fragment
    #|fn fragment() -> FragmentOutput {
    #|  return FragmentOutput(vec4<f32>());
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let parity = emit_wgsl_module_from_ir_compat_writer(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    parity.contains("enable dual_source_blending;"),
    content="false",
  )
  debug_inspect(parity.contains("@location(0) color"), content="true")
}

///|
test "naga-oil writer allocates entry body names before helper signatures" {
  let source =
    #|fn helper(world_from_local: mat4x4<f32>, vertex_position: vec4<f32>) -> vec4<f32> {
    #|  return world_from_local * vertex_position;
    #|}
    #|
    #|@vertex
    #|fn vertex() -> @builtin(position) vec4<f32> {
    #|  var world_from_local: mat4x4<f32> = mat4x4<f32>();
    #|  return helper(world_from_local, vec4<f32>(0.0, 0.0, 0.0, 1.0));
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir_compat_writer(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains(
      "fn helper(world_from_local_1: mat4x4<f32>, vertex_position: vec4<f32>) -> vec4<f32> {",
    ),
    content="true",
  )
  debug_inspect(
    emitted.contains("return (world_from_local_1 * vertex_position);"),
    content="true",
  )
  debug_inspect(
    emitted.contains("var world_from_local: mat4x4<f32> = mat4x4<f32>();"),
    content="true",
  )
  debug_inspect(
    emitted.contains("var world_from_local_1: mat4x4<f32>"),
    content="false",
  )
}

///|
test "naga-oil writer materializes var field before swizzle projection" {
  let source =
    #|struct Out {
    #|  world_position: vec4<f32>,
    #|}
    #|
    #|fn position_world_to_clip(world_position: vec3<f32>) -> vec4<f32> {
    #|  return vec4<f32>(world_position, 1.0);
    #|}
    #|
    #|@vertex
    #|fn vertex() -> @builtin(position) vec4<f32> {
    #|  var out: Out;
    #|  out.world_position = vec4<f32>(1.0, 2.0, 3.0, 1.0);
    #|  return position_world_to_clip(out.world_position.xyz);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir_compat_writer(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("let _e8: vec4<f32> = out.world_position;"),
    content="true",
  )
  debug_inspect(
    emitted.contains("let _e10: vec4<f32> = position_world_to_clip(_e8.xyz);"),
    content="true",
  )
  debug_inspect(
    emitted.contains(": vec3<f32> = out.world_position.xyz;"),
    content="false",
  )
}

///|
test "naga-oil writer resets nested for initializer at execution site" {
  let source =
    #|fn count(limit: u32) -> u32 {
    #|  var total: u32 = 0u;
    #|  for (var outer: u32 = 0u; outer < limit; outer++) {
    #|    for (var step_i: u32 = 0u; step_i < 4u; step_i++) {
    #|      total = total + step_i;
    #|    }
    #|  }
    #|  return total;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir_compat_writer(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("var step_i: u32;\n"), content="true")
  debug_inspect(emitted.contains("var step_i: u32 = 0u;"), content="false")
  debug_inspect(
    emitted.contains("step_i = 0u;\n            loop {"),
    content="true",
  )
}

///|
test "naga-oil writer materializes global field before swizzle projection" {
  let source =
    #|struct Lights {
    #|  ambient_color: vec4<f32>,
    #|}
    #|
    #|@group(0) @binding(0) var<uniform> lights: Lights;
    #|
    #|fn ambient() -> vec3<f32> {
    #|  return lights.ambient_color.xyz;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir_compat_writer(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("let _e2: vec4<f32> = lights.ambient_color;"),
    content="true",
  )
  debug_inspect(emitted.contains("return _e2.xyz;"), content="true")
  debug_inspect(
    emitted.contains(": vec3<f32> = lights.ambient_color.xyz;"),
    content="false",
  )
}

///|
test "naga-oil writer materializes control-flow global field before swizzle projection" {
  let source =
    #|struct Settings {
    #|  size: vec3<u32>,
    #|}
    #|
    #|@group(0) @binding(0) var<uniform> settings: Settings;
    #|
    #|fn guard(idx: vec3<u32>) -> bool {
    #|  if any(idx.xy > settings.size.xy) {
    #|    return true;
    #|  }
    #|  return false;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir_compat_writer(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains(": vec3<u32> = settings.size;"),
    content="true",
  )
  debug_inspect(emitted.contains(".size.xy;"), content="false")
  debug_inspect(emitted.contains(": vec2<u32> ="), content="false")
}

///|
test "naga-oil writer materializes pointer local field before swizzle projection" {
  let source =
    #|struct Light {
    #|  position_radius: vec4<f32>,
    #|}
    #|
    #|@group(0) @binding(0) var<storage, read> lights: array<Light>;
    #|
    #|fn direction(index: u32, p: vec3<f32>) -> vec3<f32> {
    #|  let light: ptr<storage, Light, read> = &lights[index];
    #|  let to_light = (*light).position_radius.xyz - p;
    #|  return to_light;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir_compat_writer(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("let _e") &&
    emitted.contains(": vec4<f32> = (*light).position_radius;"),
    content="true",
  )
  debug_inspect(
    emitted.contains(
      "let to_light: vec3<f32> = ((*light).position_radius.xyz - p);",
    ),
    content="false",
  )
}

///|
test "naga-oil writer inlines local store pointer index and materializes storage rhs" {
  let source =
    #|struct Input {
    #|  value: u32,
    #|}
    #|
    #|struct Output {
    #|  value: u32,
    #|}
    #|
    #|@group(0) @binding(0) var<storage, read> input: array<Input>;
    #|@group(0) @binding(1) var<storage, read_write> output: array<Output>;
    #|
    #|@compute @workgroup_size(1)
    #|fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    #|  let index = global_id.x;
    #|  output[index].value = input[index].value;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir_compat_writer(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("let _e8: u32 = input[index].value;") &&
    emitted.contains("output[index].value = _e8;"),
    content="true",
  )
  debug_inspect(emitted.contains(": u32 = input[index].value;"), content="true")
  debug_inspect(
    emitted.contains("output[index].value = input[index].value;"),
    content="false",
  )
}

///|
test "naga-oil writer materializes mutable local rhs for projected local store" {
  let source =
    #|struct Input {
    #|  H: vec3<f32>,
    #|}
    #|
    #|fn derive_lighting_input() -> Input {
    #|  var input: Input;
    #|  var H: vec3<f32>;
    #|  H = vec3<f32>(1.0, 0.0, 0.0);
    #|  input.H = H;
    #|  return input;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir_compat_writer(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains(": vec3<f32> = H;"), content="true")
  debug_inspect(emitted.contains("input.H = _e"), content="true")
  debug_inspect(emitted.contains("input.H = H;"), content="false")
}

///|
test "naga-oil writer does not rematerialize named rhs for projected local store" {
  let source =
    #|fn copy_named(points: array<vec3<f32>, 4>, index: i32) -> vec3<f32> {
    #|  var clipped: array<vec3<f32>, 5>;
    #|  var n: i32 = 0i;
    #|  let a = points[index];
    #|  clipped[n] = a;
    #|  return clipped[n];
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir_compat_writer(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("let a:"), content="true")
  debug_inspect(emitted.contains("clipped[_e"), content="true")
  debug_inspect(emitted.contains("] = a;"), content="true")
  debug_inspect(emitted.contains(": vec3<f32> = a"), content="false")
}

///|
test "naga-oil writer materializes mutable local rhs before local store" {
  let source =
    #|fn copy_local(a: bool) -> f32 {
    #|  var h: f32 = 0.0;
    #|  var g: f32 = 1.0;
    #|  if a {
    #|    h = g;
    #|  }
    #|  return h;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir_compat_writer(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains(": f32 = g;\n        h = _e"), content="true")
  debug_inspect(emitted.contains("h = g;"), content="false")
}

///|
test "naga-oil writer materializes statement call value arguments" {
  let source =
    #|fn sink(position: vec2<u32>, color: vec4<f32>) {
    #|  return;
    #|}
    #|
    #|fn main() {
    #|  var p: vec2<u32> = vec2<u32>(1u, 2u);
    #|  var values: array<vec4<f32>, 1>;
    #|  sink(p, values[0]);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir_compat_writer(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains(": vec2<u32> = p;") &&
    emitted.contains(": vec4<f32> = values[0];"),
    content="true",
  )
  debug_inspect(emitted.contains("sink(p, values[0]);"), content="false")
}

///|
test "naga-oil writer materializes atomic user-call value arguments" {
  let source =
    #|var<workgroup> counter: atomic<u32>;
    #|var<workgroup> shared_farthest_z: array<f32, 1>;
    #|
    #|fn f32_bits_to_sortable_u32(bits: u32) -> u32 {
    #|  return bits;
    #|}
    #|
    #|@compute
    #|@workgroup_size(1)
    #|fn main() {
    #|  atomicMax(&counter, f32_bits_to_sortable_u32(bitcast<u32>(shared_farthest_z[0u])));
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir_compat_writer(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains(": f32 = shared_farthest_z[0];") &&
    emitted.contains(": u32 = f32_bits_to_sortable_u32") &&
    emitted.contains("(bitcast<u32>(_e") &&
    emitted.contains("atomicMax((&counter), _e"),
    content="true",
  )
  debug_inspect(
    emitted.contains("atomicMax((&counter), f32_bits_to_sortable_u32("),
    content="false",
  )
}

///|
test "naga-oil writer materializes nested derivative arguments" {
  let source =
    #|fn helper(x: f32) -> f32 {
    #|  return x;
    #|}
    #|
    #|fn probe(x: f32) -> f32 {
    #|  let angle = helper(x);
    #|  let w = max(0.5 * fwidth(angle), 0.000001);
    #|  return w;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir_compat_writer(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains(": f32 = fwidth(_e"), content="true")
  debug_inspect(emitted.contains("* fwidth("), content="false")
  debug_inspect(emitted.contains("max((0.5f * _e"), content="true")
}

///|
test "naga-oil writer snapshots mutable splat operands inside conditions" {
  let source =
    #|fn probe(max_texel: vec2<u32>, min_texel: vec2<u32>) -> bool {
    #|  var mip: u32 = 1u;
    #|  if any((max_texel >> vec2(mip)) > (min_texel >> vec2(mip)) + 3u) {
    #|    mip = mip + 1u;
    #|  }
    #|  return mip > 0u;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir_compat_writer(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("let _e"), content="true")
  debug_inspect(
    emitted.contains("if any(((max_texel >> vec2(mip))"),
    content="false",
  )
}

///|
test "naga-oil writer materializes dynamic storage index before swizzle store" {
  let source =
    #|struct Item {
    #|  position_radius: vec4<f32>,
    #|}
    #|
    #|struct Buffer {
    #|  data: array<Item, 4>,
    #|}
    #|
    #|@group(0) @binding(0)
    #|var<storage> clustered_lights: Buffer;
    #|
    #|fn main(input_index: u32) -> vec3<f32> {
    #|  var object_index: u32 = input_index;
    #|  var position: vec3<f32>;
    #|  position = clustered_lights.data[object_index].position_radius.xyz;
    #|  return position;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir_compat_writer(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains(": u32 = object_index;") &&
    emitted.contains(".data[_e") &&
    emitted.contains("].position_radius;") &&
    emitted.contains("position = _e"),
    content="true",
  )
  debug_inspect(
    emitted.contains(".data[object_index].position_radius"),
    content="false",
  )
}

///|
test "naga-oil writer materializes mutable store pointer index" {
  let source =
    #|struct Output {
    #|  value: u32,
    #|}
    #|
    #|@group(0) @binding(0) var<storage, read_write> output: array<Output>;
    #|
    #|@compute @workgroup_size(1)
    #|fn main() {
    #|  var index: u32 = 1u;
    #|  output[index].value = 2u;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir_compat_writer(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains(": u32 = index;"), content="true")
  debug_inspect(emitted.contains("output[_e"), content="true")
  debug_inspect(emitted.contains("].value = 2u;"), content="true")
  debug_inspect(emitted.contains("output[index].value = 2u;"), content="false")
}

///|
test "naga-oil writer reuses side-effect store pointer index" {
  let source =
    #|struct Output {
    #|  x: u32,
    #|  y: u32,
    #|}
    #|
    #|@group(0) @binding(0) var<storage, read_write> output: array<Output>;
    #|var<workgroup> counter: atomic<u32>;
    #|
    #|@compute @workgroup_size(1)
    #|fn main() {
    #|  let index = atomicAdd(&counter, 1u);
    #|  output[index].x = 2u;
    #|  output[index].y = 3u;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir_compat_writer(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.split("atomicAdd").collect().length(), content="2")
  debug_inspect(emitted.contains("output[_e"), content="true")
  debug_inspect(emitted.contains("].x = 2u;"), content="true")
  debug_inspect(emitted.contains("].y = 3u;"), content="true")
}

///|
test "naga-oil writer materializes function pointer loads" {
  let source =
    #|fn rand_u(state: ptr<function, u32>) -> u32 {
    #|  *state = *state * 747796405u + 2891336453u;
    #|  let word = ((*state >> ((*state >> 28u) + 4u)) ^ *state) * 277803737u;
    #|  return (word >> 22u) ^ word;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir_compat_writer(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("let _e1: u32 = (*state);"), content="true")
  debug_inspect(
    emitted.contains("(*state) = ((_e1 * 747796405u) + 2891336453u);"),
    content="true",
  )
  debug_inspect(emitted.contains("let _e6: u32 = (*state);"), content="true")
  debug_inspect(emitted.contains("let _e7: u32 = (*state);"), content="true")
  debug_inspect(emitted.contains("let _e13: u32 = (*state);"), content="true")
  debug_inspect(emitted.contains("*(state) * 747796405u"), content="false")
}

///|
test "naga-oil writer elides local aliases of materialized temporaries" {
  let source =
    #|fn rand_f(state: ptr<function, u32>) -> f32 {
    #|  *state = *state + 1u;
    #|  return f32(*state);
    #|}
    #|
    #|fn sample(rng: ptr<function, u32>) -> vec3<f32> {
    #|  let cos_theta = rand_f(rng);
    #|  let phi = rand_f(rng);
    #|  let z = cos_theta;
    #|  return vec3<f32>(z, phi, cos_theta);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir_compat_writer(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("let _e1: f32 = rand_f(rng);"), content="true")
  debug_inspect(emitted.contains("let _e2: f32 = rand_f(rng);"), content="true")
  debug_inspect(
    emitted.contains("return vec3<f32>(_e1, _e2, _e1);"),
    content="true",
  )
  debug_inspect(emitted.contains("let z"), content="false")
  debug_inspect(emitted.contains("cos_theta"), content="false")
}

///|
test "naga-oil writer elides direct function argument aliases" {
  let source =
    #|fn sample(roughness: f32, normal: vec3<f32>, view: vec3<f32>) -> vec3<f32> {
    #|  let n = normal;
    #|  let alpha = roughness;
    #|  let wi_n = dot(view, n);
    #|  let wi_z = -n * wi_n;
    #|  return normalize(alpha * wi_z);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir_compat_writer(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("let n:"), content="false")
  debug_inspect(emitted.contains("let alpha:"), content="false")
  debug_inspect(
    emitted.contains("let wi_n: f32 = dot(view, normal);"),
    content="true",
  )
  debug_inspect(
    emitted.contains("let wi_z: vec3<f32> = (-(normal) * wi_n);"),
    content="true",
  )
  debug_inspect(
    emitted.contains("return normalize((roughness * wi_z));"),
    content="true",
  )
}

///|
test "naga-oil writer excludes inline operands before call-result temp slots" {
  let source =
    #|const SCALE: f32 = 6.2831853;
    #|
    #|fn rand_f(state: ptr<function, u32>) -> f32 {
    #|  *state = *state + 1u;
    #|  return f32(*state);
    #|}
    #|
    #|fn sample(rng: ptr<function, u32>) -> vec2<f32> {
    #|  let a = 1.0 - 2.0 * rand_f(rng);
    #|  let b = SCALE * rand_f(rng);
    #|  return vec2<f32>(a, b);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir_compat_writer(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("let _e1: f32 = rand_f(rng);"), content="true")
  debug_inspect(emitted.contains("let _e6: f32 = rand_f(rng);"), content="true")
  debug_inspect(
    emitted.contains("let _e2: f32 = rand_f(rng);"),
    content="false",
  )
  debug_inspect(
    emitted.contains("let _e7: f32 = rand_f(rng);"),
    content="false",
  )
}

///|
test "naga-oil writer materializes mutable local loads in control-flow conditions" {
  let source =
    #|fn sample(value: f32) -> f32 {
    #|  var b = value;
    #|  if (b == 0.0) {
    #|    b = 1.0;
    #|  }
    #|  if (1.0 < b) {
    #|    b = b + 1.0;
    #|  }
    #|  return b;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir_compat_writer(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains(": f32 = b;"), content="true")
  debug_inspect(emitted.contains("if (_e"), content="true")
  debug_inspect(emitted.contains("if (b == 0f)"), content="false")
  debug_inspect(emitted.contains("if (1f < b)"), content="false")
}

///|
test "naga-oil writer allocates function locals before later function arguments" {
  let source =
    #|fn first() -> f32 {
    #|  var dir: f32 = 1.0;
    #|  return dir;
    #|}
    #|
    #|fn second(dir: f32) -> f32 {
    #|  return dir;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir_compat_writer(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("var dir: f32 = 1f;"), content="true")
  debug_inspect(emitted.contains("fn second(dir_1: f32)"), content="true")
  debug_inspect(emitted.contains("var dir_1: f32"), content="false")
  debug_inspect(emitted.contains("return dir_1;"), content="true")
}

///|
test "naga-oil writer absorbs projected call-result argument slots" {
  let source =
    #|fn local_to_world(vertex_position: vec4<f32>) -> vec4<f32> {
    #|  return vertex_position;
    #|}
    #|
    #|fn world_to_clip(world_position: vec3<f32>) -> vec4<f32> {
    #|  return vec4<f32>(world_position, 1.0);
    #|}
    #|
    #|fn local_to_clip(vertex_position: vec4<f32>) -> vec4<f32> {
    #|  let world = local_to_world(vertex_position);
    #|  return world_to_clip(world.xyz);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir_compat_writer(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("let _e3: vec4<f32> = world_to_clip(_e1.xyz);"),
    content="true",
  )
  debug_inspect(emitted.contains("let _e5: vec4<f32>"), content="false")
}

///|
test "naga-oil writer counts projected user-local loads before call results" {
  let source =
    #|struct Out {
    #|  clip_position: vec4<f32>,
    #|  world_position: vec4<f32>,
    #|}
    #|
    #|fn world_to_clip(world_position: vec3<f32>) -> vec4<f32> {
    #|  return vec4<f32>(world_position, 1.0);
    #|}
    #|
    #|fn vertex(position: vec3<f32>) -> Out {
    #|  var out: Out;
    #|  out.world_position = vec4<f32>(position, 1.0);
    #|  out.clip_position = world_to_clip(out.world_position.xyz);
    #|  return out;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir_compat_writer(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("let _e7: vec4<f32> = out.world_position;"),
    content="true",
  )
  debug_inspect(
    emitted.contains("let _e9: vec4<f32> = world_to_clip(_e7.xyz);"),
    content="true",
  )
  debug_inspect(
    emitted.contains("let _e8: vec4<f32> = world_to_clip(_e7.xyz);"),
    content="false",
  )
}

///|
test "naga-oil writer does not persist function argument swizzle call slots" {
  let source =
    #|struct VertexOutput {
    #|  @builtin(position) position: vec4<f32>,
    #|}
    #|
    #|struct View {
    #|  viewport: vec4<f32>,
    #|}
    #|
    #|struct Uniforms {
    #|  brightness: f32,
    #|}
    #|
    #|@group(0) @binding(0) var<uniform> view: View;
    #|@group(1) @binding(0) var skybox: texture_cube<f32>;
    #|@group(1) @binding(1) var skybox_sampler: sampler;
    #|@group(1) @binding(2) var<uniform> uniforms: Uniforms;
    #|
    #|fn coords_to_ray_direction(coords: vec2<f32>, viewport: vec4<f32>) -> vec3<f32> {
    #|  return vec3<f32>(coords, viewport.x);
    #|}
    #|
    #|@fragment
    #|fn skybox_fragment(in: VertexOutput) -> @location(0) vec4<f32> {
    #|  let ray_direction = coords_to_ray_direction(in.position.xy, view.viewport);
    #|  let out = textureSample(skybox, skybox_sampler, ray_direction * vec3<f32>(1.0, 1.0, -1.0));
    #|  return vec4<f32>(out.xyz * uniforms.brightness, out.w);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir_compat_writer(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("let _e18: f32 = uniforms.brightness;"),
    content="true",
  )
  debug_inspect(
    emitted.contains("let _e19: f32 = uniforms.brightness;"),
    content="false",
  )
}

///|
test "naga-oil writer parenthesizes address-of expressions" {
  let source =
    #|fn read(value: ptr<function, f32>) -> f32 {
    #|  return *value;
    #|}
    #|
    #|fn f() -> f32 {
    #|  var x = 1.0;
    #|  let p: ptr<function, f32> = &x;
    #|  return read(&x) + read(p);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir_compat_writer(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("let p: ptr<function, f32> = (&x);"),
    content="true",
  )
  debug_inspect(emitted.contains("read((&x))"), content="true")
  debug_inspect(emitted.contains(" = &x;"), content="false")
  debug_inspect(emitted.contains("read(&x)"), content="false")
}
