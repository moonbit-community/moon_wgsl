///|
test "IR emitter matches Naga temp slots around nested call arguments" {
  let source =
    #|struct View { clip_from_world: mat4x4<f32>, }
    #|@group(0) @binding(0) var<uniform> view: View;
    #|fn affine3_to_square(affine: mat3x4<f32>) -> mat4x4<f32> {
    #|  return transpose(mat4x4<f32>(affine[0], affine[1], affine[2], vec4<f32>(0.0, 0.0, 0.0, 1.0)));
    #|}
    #|struct VertexInput {
    #|  @builtin(vertex_index) index: u32,
    #|  @location(0) i_model_transpose_col0: vec4<f32>,
    #|  @location(1) i_model_transpose_col1: vec4<f32>,
    #|  @location(2) i_model_transpose_col2: vec4<f32>,
    #|  @location(3) i_color: vec4<f32>,
    #|  @location(4) i_uv_offset_scale: vec4<f32>,
    #|}
    #|struct VertexOutput {
    #|  @builtin(position) clip_position: vec4<f32>,
    #|  @location(0) uv: vec2<f32>,
    #|  @location(1) @interpolate(flat) color: vec4<f32>,
    #|}
    #|@vertex fn vertex(in: VertexInput) -> VertexOutput {
    #|  var out: VertexOutput;
    #|  let vertex_position = vec3<f32>(f32(in.index & 0x1u), f32((in.index & 0x2u) >> 1u), 0.0);
    #|  out.clip_position = view.clip_from_world * affine3_to_square(mat3x4<f32>(in.i_model_transpose_col0, in.i_model_transpose_col1, in.i_model_transpose_col2)) * vec4<f32>(vertex_position, 1.0);
    #|  out.uv = vec2<f32>(vertex_position.xy) * in.i_uv_offset_scale.zw + in.i_uv_offset_scale.xy;
    #|  out.color = in.i_color;
    #|  return out;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains(
      "let _e22: mat4x4<f32> = affine3_to_square(mat3x4<f32>(in.i_model_transpose_col0_, in.i_model_transpose_col1_, in.i_model_transpose_col2_));",
    ),
    content="true",
  )
  debug_inspect(
    emitted.contains(
      "out.clip_position = ((_e17 * _e22) * vec4<f32>(vertex_position, 1f));",
    ),
    content="true",
  )
  debug_inspect(
    emitted.contains("let _e38: VertexOutput = out;"),
    content="true",
  )
  debug_inspect(emitted.contains("let _e21: mat4x4<f32>"), content="false")
  debug_inspect(
    emitted.contains("let _e39: VertexOutput = out;"),
    content="false",
  )
}

///|
test "IR emitter ignores materialized temporary locals in Naga arena order" {
  let source =
    #|struct View {
    #|  clip_from_world: mat4x4<f32>,
    #|}
    #|
    #|struct UiVertexOutput {
    #|  @builtin(position) position: vec4<f32>,
    #|  @location(0) uv: vec2<f32>,
    #|  @location(1) size: vec2<f32>,
    #|  @location(2) border_widths: vec4<f32>,
    #|  @location(3) border_radius: vec4<f32>,
    #|}
    #|
    #|@group(0) @binding(0) var<uniform> view: View;
    #|
    #|@vertex
    #|fn vertex(
    #|  @location(0) vertex_position: vec3<f32>,
    #|  @location(1) vertex_uv: vec2<f32>,
    #|  @location(2) size: vec2<f32>,
    #|  @location(3) border_widths: vec4<f32>,
    #|  @location(4) border_radius: vec4<f32>,
    #|) -> UiVertexOutput {
    #|  var out: UiVertexOutput;
    #|  out.uv = vertex_uv;
    #|  out.position = view.clip_from_world * vec4<f32>(vertex_position, 1.0);
    #|  out.size = size;
    #|  out.border_widths = border_widths;
    #|  out.border_radius = border_radius;
    #|  return out;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("let _e17: UiVertexOutput = out;"),
    content="true",
  )
  debug_inspect(emitted.contains("return _e17;"), content="true")
  debug_inspect(
    emitted.contains("let _e18: UiVertexOutput = out;"),
    content="false",
  )
}

///|
test "IR emitter counts direct local stores of materialized temporary values in Naga arena order" {
  let source =
    #|struct Out {
    #|  value: mat4x4<f32>,
    #|}
    #|
    #|fn make_value(i: u32) -> mat4x4<f32> {
    #|  return mat4x4<f32>();
    #|}
    #|
    #|fn vertex(i: u32) -> Out {
    #|  var out: Out;
    #|  var world: mat4x4<f32>;
    #|
    #|  let value = make_value(i);
    #|  world = value;
    #|  return out;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("let _e1: mat4x4<f32> = make_value(i_1);"),
    content="true",
  )
  debug_inspect(emitted.contains("world = _e1;"), content="true")
  debug_inspect(emitted.contains("let _e4: Out = out;"), content="true")
  debug_inspect(emitted.contains("return _e4;"), content="true")
  debug_inspect(emitted.contains("let _e3: Out = out;"), content="false")
}

///|
test "IR emitter counts local member stores of materialized temporary values in Naga arena order" {
  let source =
    #|struct Inner {
    #|  value: mat4x4<f32>,
    #|}
    #|
    #|struct Out {
    #|  inner: Inner,
    #|}
    #|
    #|fn make_value() -> Inner {
    #|  return Inner();
    #|}
    #|
    #|fn vertex() -> Out {
    #|  var out: Out;
    #|  let value = make_value();
    #|  out.inner = value;
    #|  return out;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("let _e0: Inner = make_value();"),
    content="true",
  )
  debug_inspect(emitted.contains("out.inner = _e0;"), content="true")
  debug_inspect(emitted.contains("let _e3: Out = out;"), content="true")
  debug_inspect(emitted.contains("return _e3;"), content="true")
  debug_inspect(emitted.contains("let _e2: Out = out;"), content="false")
}

///|
test "IR emitter does not overcount member stores when the same member is loaded" {
  let source =
    #|struct Inner {
    #|  value: mat4x4<f32>,
    #|}
    #|
    #|struct Out {
    #|  inner: Inner,
    #|}
    #|
    #|fn make_value() -> Inner {
    #|  return Inner();
    #|}
    #|
    #|fn vertex() -> Out {
    #|  var out: Out;
    #|  let value = make_value();
    #|  out.inner = value;
    #|  let copied = out.inner;
    #|  return out;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("let _e0: Inner = make_value();"),
    content="true",
  )
  debug_inspect(
    emitted.contains("let copied: Inner = out.inner;"),
    content="true",
  )
  debug_inspect(emitted.contains("let _e5: Out = out;"), content="true")
  debug_inspect(emitted.contains("return _e5;"), content="true")
  debug_inspect(emitted.contains("let _e6: Out = out;"), content="false")
}

///|
test "IR emitter counts implicit matrix scalar constructor columns in Naga arena order" {
  let source =
    #|struct S {
    #|  m: mat3x3<f32>,
    #|}
    #|
    #|fn f() -> S {
    #|  var s: S;
    #|  s.m = mat3x3<f32>(1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0);
    #|  return s;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("let _e15: S = s;"), content="true")
  debug_inspect(emitted.contains("return _e15;"), content="true")
  debug_inspect(emitted.contains("let _e12: S = s;"), content="false")
}

///|
test "IR emitter does not count texture store as extra Naga arena slot" {
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
  let emitted = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
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
test "naga-oil writer profile suppresses source directives like Naga writer" {
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
  let parity = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    runtime.contains("enable dual_source_blending;"),
    content="true",
  )
  debug_inspect(
    parity.contains("enable dual_source_blending;"),
    content="false",
  )
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
  let emitted = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
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
  let emitted = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("let _e8: vec4<f32> = out.world_position;"),
    content="true",
  )
  debug_inspect(
    emitted.contains("let _e9: vec4<f32> = position_world_to_clip(_e8.xyz);"),
    content="true",
  )
  debug_inspect(
    emitted.contains(": vec3<f32> = out.world_position.xyz;"),
    content="false",
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
  let emitted = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
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
  let emitted = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
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
  let emitted = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains(": u32 = index;"), content="true")
  debug_inspect(emitted.contains("output[_e"), content="true")
  debug_inspect(emitted.contains("].value = 2u;"), content="true")
  debug_inspect(emitted.contains("output[index].value = 2u;"), content="false")
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
  let emitted = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
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
  let emitted = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
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
  let emitted = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("let _e1: f32 = rand_f(rng);"), content="true")
  debug_inspect(emitted.contains("let _e6: f32 = rand_f(rng);"), content="true")
  debug_inspect(
    emitted.contains("let _e3: f32 = rand_f(rng);"),
    content="false",
  )
  debug_inspect(
    emitted.contains("let _e8: f32 = rand_f(rng);"),
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
  let emitted = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
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
  let emitted = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
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
  let emitted = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("let _e3: vec4<f32> = world_to_clip(_e1.xyz);"),
    content="true",
  )
  debug_inspect(emitted.contains("let _e5: vec4<f32>"), content="false")
}
