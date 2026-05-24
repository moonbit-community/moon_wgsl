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
