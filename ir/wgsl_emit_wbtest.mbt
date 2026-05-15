///|
test "IR emitter prints WGSL lowered from AST without source writeback" {
  let source =
    #|struct VertexIn {
    #|  @location(0) value: f32,
    #|}
    #|
    #|@group(0) @binding(1)
    #|var<uniform> scale: f32;
    #|
    #|const COUNT: u32 = 4u;
    #|
    #|fn helper(x: u32) -> u32 {
    #|  return x + COUNT;
    #|}
    #|
    #|@compute @workgroup_size(2, 3, 4)
    #|fn main(@builtin(global_invocation_id) id: vec3u) {
    #|  var local_value: u32 = COUNT + 1u;
    #|  local_value = local_value + 1u;
    #|  helper(local_value);
    #|  return;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  debug_inspect(module_.functions.items[0].generated_import, content="false")
  debug_inspect(module_.functions.items[1].generated_import, content="false")
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  ignore(
    @parser.parse_wgsl_translation_unit_strict(emitted) catch {
      error => abort(error.message())
    },
  )
  debug_inspect(emitted.contains("struct VertexIn"), content="true")
  debug_inspect(emitted.contains("@group(0) @binding(1)"), content="true")
  debug_inspect(emitted.contains("const COUNT: u32 = 4u;"), content="true")
  debug_inspect(
    emitted.contains("@compute @workgroup_size(2, 3, 4)"),
    content="true",
  )
  debug_inspect(emitted.contains("helper(local_value);"), content="true")
}

///|
test "IR pipeline owns output identifier sanitization" {
  let source =
    #|fn fragment(value: f32) -> f32 {
    #|  var class: f32 = value;
    #|  var _naga_tmp: f32 = class;
    #|  class = class + _naga_tmp;
    #|  return class;
    #|}
    #|
  let emitted = roundtrip_wgsl_source_via_ir(source) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("var class_: f32;"), content="true")
  debug_inspect(emitted.contains("class_ = value;"), content="true")
  debug_inspect(emitted.contains("var gen__naga_tmp: f32;"), content="true")
  debug_inspect(emitted.contains("gen__naga_tmp = class_;"), content="true")
  debug_inspect(
    emitted.contains("class_ = (_e") && emitted.contains(" + _e"),
    content="true",
  )
  debug_inspect(emitted.contains("return class;"), content="false")
  debug_inspect(emitted.contains("return _naga_tmp;"), content="false")
}

///|
test "IR emitter resets Naga expression temporary names per function" {
  let source =
    #|fn f(x: u32) -> u32 {
    #|  var a = x;
    #|  a = a + 1u;
    #|  return a;
    #|}
    #|
    #|fn g(x: u32) -> u32 {
    #|  var a = x;
    #|  a = a + 2u;
    #|  return a;
    #|}
  let emitted = roundtrip_wgsl_source_via_ir(source) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("fn g(x_1: u32)"), content="true")
  debug_inspect(emitted.contains("let _e2: u32 = a;"), content="true")
  debug_inspect(emitted.contains("let _e2: u32 = a_1;"), content="true")
  debug_inspect(emitted.contains("_e2_1"), content="false")
  debug_inspect(emitted.contains("_e2_"), content="false")
}

///|
test "IR emitter numbers materialized temporaries like Naga" {
  let source =
    #|@group(0) @binding(0) var tex: texture_2d<f32>;
    #|@group(0) @binding(1) var samp: sampler;
    #|
    #|fn blit(uv: vec2<f32>) -> vec4<f32> {
    #|  var color = textureSample(tex, samp, uv);
    #|  return color;
    #|}
  let emitted = roundtrip_wgsl_source_via_ir(source) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("let _e3: vec4<f32> = textureSample(tex, samp, uv);"),
    content="true",
  )
  debug_inspect(emitted.contains("let _e5: vec4<f32> = color;"), content="true")
  debug_inspect(
    emitted.contains("let _e6: vec4<f32> = color;"),
    content="false",
  )
}

///|
test "IR emitter skips immutable let references in Naga temporary numbering" {
  let source =
    #|@group(0) @binding(0) var tex: texture_cube<f32>;
    #|@group(0) @binding(1) var samp: sampler;
    #|
    #|fn sample_cube(pos: vec4<f32>) -> vec4<f32> {
    #|  let direction: vec3<f32> = (pos.xyz * vec3<f32>(1f, 1f, -1f));
    #|  return textureSample(tex, samp, direction);
    #|}
  let emitted = roundtrip_wgsl_source_via_ir(source) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains(
      "let _e9: vec4<f32> = textureSample(tex, samp, direction);",
    ),
    content="true",
  )
  debug_inspect(
    emitted.contains(
      "let _e12: vec4<f32> = textureSample(tex, samp, direction);",
    ),
    content="false",
  )
}

///|
test "IR lowerer preserves direct value-call let initializers" {
  let source =
    #|@group(0) @binding(0) var tex: texture_2d<f32>;
    #|@group(0) @binding(1) var samp: sampler;
    #|
    #|fn dims() -> vec2<u32> {
    #|  let dim = textureDimensions(tex);
    #|  return dim;
    #|}
    #|
    #|fn sample(uv: vec2<f32>) -> vec4<f32> {
    #|  let color = textureSample(tex, samp, uv);
    #|  return color;
    #|}
  let emitted = roundtrip_wgsl_source_via_ir_with_generated_imports_naga_oil_writer_compatible(
    source,
    [],
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("let dim: vec2<u32> = textureDimensions(tex);"),
    content="true",
  )
  debug_inspect(
    emitted.contains("let color: vec4<f32> = textureSample(tex, samp, uv);"),
    content="true",
  )
  debug_inspect(
    emitted.contains("let _e1: vec2<u32> = textureDimensions"),
    content="false",
  )
  debug_inspect(
    emitted.contains("let _e3: vec4<f32> = textureSample"),
    content="false",
  )
  debug_inspect(emitted.contains("return color;"), content="true")
  debug_inspect(emitted.contains("let _e"), content="false")
}

///|
test "IR emitter counts projected materialized temporaries like Naga" {
  let source =
    #|struct FullscreenVertexOutput {
    #|  @builtin(position) position: vec4<f32>,
    #|  @location(0) uv: vec2<f32>,
    #|}
    #|
    #|struct FullScreenEffect {
    #|  intensity: f32,
    #|}
    #|
    #|@group(0) @binding(0) var screen_texture: texture_2d<f32>;
    #|@group(0) @binding(1) var texture_sampler: sampler;
    #|@group(0) @binding(2) var<uniform> settings: FullScreenEffect;
    #|
    #|@fragment
    #|fn fragment(in: FullscreenVertexOutput) -> @location(0) vec4<f32> {
    #|  let offset_strength = settings.intensity;
    #|  return vec4<f32>(
    #|    textureSample(screen_texture, texture_sampler, in.uv + vec2<f32>(offset_strength, -offset_strength)).r,
    #|    textureSample(screen_texture, texture_sampler, in.uv + vec2<f32>(-offset_strength, 0.0)).g,
    #|    textureSample(screen_texture, texture_sampler, in.uv + vec2<f32>(0.0, offset_strength)).b,
    #|    1.0,
    #|  );
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains(
      "let _e10: vec4<f32> = textureSample(screen_texture, texture_sampler, (in.uv + vec2<f32>(offset_strength, -(offset_strength))));",
    ),
    content="true",
  )
  debug_inspect(
    emitted.contains(
      "let _e19: vec4<f32> = textureSample(screen_texture, texture_sampler, (in.uv + vec2<f32>(-(offset_strength), 0f)));",
    ),
    content="true",
  )
  debug_inspect(
    emitted.contains(
      "let _e27: vec4<f32> = textureSample(screen_texture, texture_sampler, (in.uv + vec2<f32>(0f, offset_strength)));",
    ),
    content="true",
  )
  debug_inspect(
    emitted.contains("return vec4<f32>(_e10.x, _e19.y, _e27.z, 1f);"),
    content="true",
  )
}

///|
test "IR emitter reuses baked child expression names without shifting parent handles" {
  let source =
    #|struct VertexOutput { @location(0) uv: vec2<f32>, }
    #|@group(3) @binding(0) var<uniform> mip_level: u32;
    #|@group(3) @binding(1) var base_color_texture: texture_2d<f32>;
    #|@group(3) @binding(2) var base_color_sampler: sampler;
    #|@fragment fn fragment(mesh: VertexOutput) -> @location(0) vec4<f32> {
    #|  return textureSampleLevel(base_color_texture, base_color_sampler, mesh.uv, f32(mip_level));
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("let _e5: u32 = mip_level;"), content="true")
  debug_inspect(
    emitted.contains(
      "let _e7: vec4<f32> = textureSampleLevel(base_color_texture, base_color_sampler, mesh.uv, f32(_e5));",
    ),
    content="true",
  )
  debug_inspect(emitted.contains("return _e7;"), content="true")
  debug_inspect(emitted.contains("let _e10: vec4<f32>"), content="false")
  debug_inspect(emitted.contains("f32(mip_level)"), content="false")
}

///|
test "IR emitter numbers call results without local-reference handle drift" {
  let source =
    #|struct VertexOutput { @location(0) uv: vec2<f32>, }
    #|struct Globals { time: f32, }
    #|@group(0) @binding(0) var<uniform> globals: Globals;
    #|
    #|fn oklab_to_linear_srgb(c: vec3<f32>) -> vec3<f32> {
    #|  return c;
    #|}
    #|
    #|@fragment
    #|fn fragment(in: VertexOutput) -> @location(0) vec4<f32> {
    #|  let speed = 2.0;
    #|  let t_1 = sin(globals.time * speed) * 0.5 + 0.5;
    #|  let t_2 = cos(globals.time * speed);
    #|  let distance_to_center = distance(in.uv, vec2<f32>(0.5)) * 1.4;
    #|  let red = vec3<f32>(0.627955, 0.224863, 0.125846);
    #|  let green = vec3<f32>(0.86644, -0.233887, 0.179498);
    #|  let blue = vec3<f32>(0.701674, 0.274566, -0.169156);
    #|  let white = vec3<f32>(1.0, 0.0, 0.0);
    #|  let mixed = mix(mix(red, blue, t_1), mix(green, white, t_2), distance_to_center);
    #|  return vec4<f32>(oklab_to_linear_srgb(mixed), 1.0);
    #|}
  let emitted = roundtrip_wgsl_source_via_ir_with_generated_imports_naga_oil_writer_compatible(
    source,
    [],
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("let _e41: vec3<f32> = oklab_to_linear_srgb(mixed);"),
    content="true",
  )
  debug_inspect(
    emitted.contains("let _e50: vec3<f32> = oklab_to_linear_srgb(mixed);"),
    content="false",
  )
  debug_inspect(emitted.contains("return vec4<f32>(_e41, 1f);"), content="true")
}

///|
test "IR emitter mirrors naga entry-point stage attribute spacing" {
  let source =
    #|@fragment
    #|fn fragment() -> @location(0) f32 {
    #|  return 1.0;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("@fragment \nfn fragment"), content="true")
}

///|
test "IR emitter preserves f32 negative zero spelling" {
  let source =
    #|const NEG_ZERO: f32 = -0.0;
    #|const OFFSET: vec2<f32> = vec2<f32>(0.125, -0.0);
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("const NEG_ZERO: f32 = -0f;"), content="true")
  debug_inspect(emitted.contains("vec2<f32>(0.125f, -0f)"), content="true")
}

///|
test "IR lowerer materializes global member return values like Naga" {
  let source =
    #|struct Push {
    #|  color: vec4<f32>,
    #|}
    #|
    #|var<private> push_constants: Push;
    #|
    #|@fragment
    #|fn fragment() -> @location(0) vec4<f32> {
    #|  return push_constants.color;
    #|}
  let emitted = roundtrip_wgsl_source_via_ir(source) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("let _e2: vec4<f32> = push_constants.color;"),
    content="true",
  )
  debug_inspect(emitted.contains("return _e2;"), content="true")
  debug_inspect(
    emitted.contains("return push_constants.color;"),
    content="false",
  )
}

///|
test "IR emitter prints global and function const_asserts from IR" {
  let source =
    #|const VALUE: u32 = 1u;
    #|const_assert VALUE == 1u;
    #|
    #|fn helper() {
    #|  const_assert VALUE > 0u;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  ignore(
    @parser.parse_wgsl_translation_unit_strict(emitted) catch {
      error => abort(error.message())
    },
  )
  debug_inspect(emitted.contains("const_assert (VALUE == 1u);"), content="true")
  debug_inspect(
    emitted.contains("  const_assert (VALUE > 0u);"),
    content="true",
  )
}

///|
test "IR lowerer does not infer generated import provenance from names" {
  let source =
    #|fn firstX_naga_oil_mod_XABCDX(value: u32) -> u32 {
    #|  return value;
    #|}
    #|
    #|fn secondX_naga_oil_mod_XABCDX(value: u32) -> u32 {
    #|  return value;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(module_.functions.items[0].generated_import, content="false")
  debug_inspect(module_.functions.items[1].generated_import, content="false")
  debug_inspect(emitted.contains("value_1"), content="true")
}

///|
test "IR lowerer accepts explicit generated import provenance" {
  let source =
    #|fn firstX_naga_oil_mod_XABCDX(value: u32) -> u32 {
    #|  return value;
    #|}
    #|
    #|fn secondX_naga_oil_mod_XABCDX(value: u32) -> u32 {
    #|  return value;
    #|}
  let module_ = parse_wgsl_module_to_ir_with_generated_imports(source, [
    WgslIrGeneratedImportProvenance(
      "firstX_naga_oil_mod_XABCDX",
      "imports/first.wgsl",
      "first",
      WgslIrGeneratedImportProvenanceKind::ImportedSourceSymbol,
      false,
    ),
    WgslIrGeneratedImportProvenance(
      "secondX_naga_oil_mod_XABCDX",
      "imports/second.wgsl",
      "second",
      WgslIrGeneratedImportProvenanceKind::ImportedSourceSymbol,
      false,
    ),
  ]) catch {
    error => abort(error.message())
  }
  debug_inspect(module_.functions.items[0].generated_import, content="true")
  debug_inspect(module_.functions.items[1].generated_import, content="true")
}

///|
test "IR emitter preserves struct member layout attributes" {
  let source =
    #|struct Layout {
    #|  @size(16) @align(16) value: f32,
    #|  next: vec4f,
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  ignore(
    @parser.parse_wgsl_translation_unit_strict(emitted) catch {
      error => abort(error.message())
    },
  )
  debug_inspect(
    emitted.contains("@size(16) @align(16) value: f32"),
    content="true",
  )
}

///|
test "IR lowerer emits while as loop with leading condition guard" {
  let source =
    #|fn helper() {
    #|  var x: u32 = 0u;
    #|  while (x > 1u) {
    #|    x = x + 1u;
    #|  }
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  ignore(
    @parser.parse_wgsl_translation_unit_strict(emitted) catch {
      error => abort(error.message())
    },
  )
  debug_inspect(emitted.contains("loop {"), content="true")
  debug_inspect(emitted.contains("if (x > 1u) {"), content="true")
  debug_inspect(
    emitted.contains("} else {\n            break;"),
    content="true",
  )
  debug_inspect(emitted.contains("continuing {"), content="false")
}

///|
test "IR emitter prints official builtin names and workgroup override expressions" {
  let source =
    #|enable subgroups;
    #|
    #|const WIDTH: u32 = 4u;
    #|@id(0) override HEIGHT: u32 = 8u;
    #|
    #|@compute @workgroup_size(WIDTH, HEIGHT, 1)
    #|fn main(
    #|  @builtin(global_invocation_id) global_id: vec3u,
    #|  @builtin(subgroup_invocation_id) subgroup_invocation_id: u32,
    #|) {
    #|  let value = global_id.x + subgroup_invocation_id;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  ignore(
    @parser.parse_wgsl_translation_unit_strict(emitted) catch {
      error => abort(error.message())
    },
  )
  debug_inspect(
    emitted.contains("@compute @workgroup_size(4, HEIGHT, 1)"),
    content="true",
  )
  debug_inspect(
    emitted.contains("@builtin(global_invocation_id)"),
    content="true",
  )
  debug_inspect(
    emitted.contains("@builtin(subgroup_invocation_id)"),
    content="true",
  )
}

///|
test "IR emitter fails on invalid handles instead of inventing output" {
  let module_ = Module()
  let constant = Constant::{
    name: Some("BAD"),
    generated_import: false,
    inline_value: false,
    ty: Handle::Handle(99),
    init: Handle::Handle(0),
  }
  ignore(module_.append_constant(constant))
  let message = try {
    ignore(emit_wgsl_module_from_ir(module_))
    "ok"
  } catch {
    error => error.message()
  }
  debug_inspect(
    message,
    content="\"unsupported IR emission: invalid IR type handle: 99\"",
  )
}

///|
test "naga-oil writer policy folds typed integer global constants" {
  let source =
    #|const A: u32 = 1u << 29u;
    #|const B: u32 = A | (1u << 30u);
    #|const C: i32 = -1i;
    #|
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let valid = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  let naga_oil = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(valid.contains("const A: u32 = (1u << 29u);"), content="true")
  debug_inspect(naga_oil.contains("const A: u32 = 536870912u;"), content="true")
  debug_inspect(
    naga_oil.contains("const B: u32 = 1610612736u;"),
    content="true",
  )
  debug_inspect(naga_oil.contains("const C: i32 = -1i;"), content="true")
}

///|
test "naga-oil writer policy folds typed float global constants" {
  let source =
    #|const PI: f32 = 3.1415927;
    #|const TAU: f32 = 2.0 * PI;
    #|
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let valid = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  let naga_oil = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(valid.contains("const TAU: f32 = (2f * PI);"), content="true")
  debug_inspect(
    naga_oil.contains("const TAU: f32 = 6.2831855f;"),
    content="true",
  )
}

///|
test "naga-oil writer policy expands scalar matrix constructors into columns" {
  let source =
    #|fn helper() -> mat3x3<f32> {
    #|  return mat3x3<f32>(1f, 0f, 0f, 0f, 1f, 0f, 0f, 0f, 1f);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let valid = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  let naga_oil = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    valid.contains("mat3x3<f32>(1f, 0f, 0f, 0f, 1f, 0f, 0f, 0f, 1f)"),
    content="true",
  )
  debug_inspect(
    naga_oil.contains(
      "mat3x3<f32>(vec3<f32>(1f, 0f, 0f), vec3<f32>(0f, 1f, 0f), vec3<f32>(0f, 0f, 1f))",
    ),
    content="true",
  )
}
