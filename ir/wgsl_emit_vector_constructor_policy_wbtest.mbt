///|
test "naga-oil writer policy contextualizes vector splat literals" {
  let source =
    #|fn clamp_vec(value: vec2<f32>, flag: vec2<bool>) -> vec2<f32> {
    #|  let a = max(value, vec2(0.0));
    #|  let b = max(vec2(0.0), value);
    #|  return select(vec2(-1.0), vec2(1.0), flag) + a + b;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let naga_oil = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(naga_oil.contains("max(value, vec2(0f))"), content="true")
  debug_inspect(naga_oil.contains("max(vec2(0f), value)"), content="true")
  debug_inspect(
    naga_oil.contains("select(vec2(-1f), vec2(1f), flag)"),
    content="true",
  )
}

///|
test "naga-oil writer policy contextualizes multi-component select constructors" {
  let source =
    #|fn clip(delta_cs: vec3<f32>, mask: vec3<bool>) -> vec3<f32> {
    #|  return select(vec3(-1.0, -1.0, 0.0), vec3(1.0, 1.0, 1.0), mask);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let naga_oil = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    naga_oil.contains(
      "select(vec3<f32>(-1f, -1f, 0f), vec3<f32>(1f, 1f, 1f), mask)",
    ),
    content="true",
  )
  debug_inspect(naga_oil.contains("select(vec3(-1f"), content="false")
}

///|
test "naga-oil writer policy emits inferred vector splat constructors" {
  let source =
    #|fn screen_space_dither(frag_coord: vec2<f32>) -> vec3<f32> {
    #|  var dither: vec3<f32>;
    #|  dither = vec3(dot(vec2<f32>(171f, 231f), frag_coord)).xxx;
    #|  return dither;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let naga_oil = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    naga_oil.contains(
      "dither = vec3(dot(vec2<f32>(171f, 231f), frag_coord)).xxx;",
    ),
    content="true",
  )
  debug_inspect(naga_oil.contains("vec3<f32>(dot("), content="false")
}

///|
test "WGSL lowerer infers mixed abstract vector constructors from concrete components" {
  let source =
    #|fn direction(y: f32) -> vec3<f32> {
    #|  let light_dir = normalize(vec3(0.0, y, -1.0));
    #|  return light_dir;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  validate_wgsl_ir_module(module_) catch {
    error => abort(error.message())
  }
  let naga_oil = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(naga_oil.contains("vec3<abstract"), content="false")
  debug_inspect(
    naga_oil.contains(
      "let light_dir: vec3<f32> = normalize(vec3<f32>(0f, y, -1f));",
    ),
    content="true",
  )
}

///|
test "WGSL lowerer normalizes compound vector-scalar assignments" {
  let source =
    #|fn adjust(value: vec2<f32>) -> vec2<f32> {
    #|  var base_uv = value;
    #|  base_uv -= 0.5;
    #|  return base_uv;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let naga_oil = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(naga_oil.contains("- vec2(0.5f)"), content="true")
  debug_inspect(naga_oil.contains("- 0.5f"), content="false")
}

///|
test "naga-oil writer policy elides projection local aliases" {
  let source =
    #|@group(0) @binding(0) var image: texture_storage_2d<r32uint, read>;
    #|
    #|fn extract(coord: vec2<u32>) -> u32 {
    #|  let visibility = textureLoad(image, coord).x;
    #|  let depth = visibility;
    #|  return depth;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let naga_oil = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(naga_oil.contains("let visibility"), content="false")
  debug_inspect(naga_oil.contains("let depth"), content="true")
  debug_inspect(naga_oil.contains(".x;"), content="true")
}

///|
test "naga-oil writer policy materializes mutable access indices" {
  let source =
    #|fn sink(value: f32) {
    #|  return;
    #|}
    #|
    #|fn read_index(values: array<f32, 4>) {
    #|  var i: u32 = 0u;
    #|  sink(values[i]);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let naga_oil = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(naga_oil.contains("values[i]"), content="false")
  debug_inspect(naga_oil.contains("values[_e"), content="true")
}

///|
test "naga-oil writer policy materializes local array mutable access indices" {
  let source =
    #|fn sink(value: f32) {
    #|  return;
    #|}
    #|
    #|fn read_index() {
    #|  var values: array<f32, 4>;
    #|  var i: u32 = 0u;
    #|  sink(values[i]);
    #|  values[i] = 1.0;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let naga_oil = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(naga_oil.contains("values[i]"), content="false")
  debug_inspect(naga_oil.contains("values[_e"), content="true")
}

///|
test "naga-oil writer policy folds identity vector constructors" {
  let source =
    #|fn mip_coord(workgroup_id: vec2<u32>, x: u32, y: u32) -> vec2<u32> {
    #|  return vec2(workgroup_id * 16u) + vec2(x, y);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let naga_oil = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    naga_oil.contains("return ((workgroup_id * 16u) + vec2<u32>(x, y));"),
    content="true",
  )
  debug_inspect(
    naga_oil.contains("vec2<u32>((workgroup_id * 16u))"),
    content="false",
  )
}

///|
test "naga-oil writer policy preserves typed identity vector constructors" {
  let source =
    #|fn coords(global_id: vec3<u32>) -> vec2<u32> {
    #|  return vec2u(global_id.xy);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let naga_oil = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(naga_oil.contains("global_id.xy"), content="true")
  debug_inspect(naga_oil.contains("return global_id.xy;"), content="false")
}

///|
test "naga-oil writer policy materializes vector splat global loads" {
  let source =
    #|struct Globals {
    #|  delta_time: f32,
    #|}
    #|
    #|@group(0) @binding(0)
    #|var<uniform> globals: Globals;
    #|
    #|fn scale(v: vec2<f32>) -> vec4<f32> {
    #|  return vec4<f32>((v / vec2(globals.delta_time)), 0.0, 1.0);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("let _e"), content="true")
  debug_inspect(
    emitted.contains("globals.delta_time;\n    return vec4<f32>((v / vec2(_e"),
    content="true",
  )
}

///|
test "naga-oil writer policy contextualizes local vector stores" {
  let source =
    #|fn choose(face_index: u32) -> vec2<f32> {
    #|  var face_size: vec2<f32>;
    #|  switch face_index {
    #|    case 0u: {
    #|      face_size = vec2(0.33333334, 0.25);
    #|    }
    #|    default: {
    #|      face_size = vec2(1.0, 0.16666667);
    #|    }
    #|  }
    #|  return face_size;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let naga_oil = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    naga_oil.contains("face_size = vec2<f32>(0.33333334f, 0.25f);"),
    content="true",
  )
  debug_inspect(
    naga_oil.contains("face_size = vec2<f32>(1f, 0.16666667f);"),
    content="true",
  )
  debug_inspect(naga_oil.contains("face_size = vec2("), content="false")
}

///|
test "naga-oil writer policy contextualizes vector stores" {
  let source =
    #|struct RaymarchResult {
    #|  transmittance: vec3<f32>,
    #|  basis: mat3x3<f32>,
    #|}
    #|
    #|fn raymarch() -> RaymarchResult {
    #|  var result: RaymarchResult;
    #|  result.transmittance = vec3(1.0);
    #|  result.basis = mat3x3<f32>(
    #|    1.0, 0.0, 0.0,
    #|    0.0, 1.0, 0.0,
    #|    0.0, 0.0, 1.0,
    #|  );
    #|  return result;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let naga_oil = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    naga_oil.contains("result.transmittance = vec3(1f);"),
    content="true",
  )
  debug_inspect(
    naga_oil.contains("result.transmittance = vec3(1.0);"),
    content="false",
  )
  debug_inspect(
    naga_oil.contains(
      "result.basis = mat3x3<f32>(vec3<f32>(1f, 0f, 0f), vec3<f32>(0f, 1f, 0f), vec3<f32>(0f, 0f, 1f));",
    ),
    content="true",
  )
  debug_inspect(
    naga_oil.contains("result.basis = mat3x3<f32>(1f, 0f, 0f"),
    content="false",
  )
}

///|
test "naga-oil writer policy contextualizes nested math vector literals" {
  let source =
    #|const FRAC_PI_3: f32 = 1.0471976;
    #|
    #|fn hsv_to_rgb(hsv: vec3<f32>) -> vec3<f32> {
    #|  let n = vec3(5.0, 3.0, 1.0);
    #|  let k = (n + hsv.x / FRAC_PI_3) % 6.0;
    #|  return hsv.z - hsv.z * hsv.y * max(vec3(0.0), min(k, min(4.0 - k, vec3(1.0))));
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let naga_oil = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    naga_oil.contains("min((vec3(4f) - k), vec3(1f))"),
    content="true",
  )
  debug_inspect(
    naga_oil.contains("min((vec3(4f) - k), vec3(1.0))"),
    content="false",
  )
}
