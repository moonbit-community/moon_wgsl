///|
test "naga-oil writer policy prints small f32 values without scientific notation when fixed spelling round-trips" {
  let source =
    #|const MIN_EXTINCTION: vec3<f32> = vec3<f32>(0.000000000001);
    #|fn clamp_energy(value: vec3<f32>) -> vec3<f32> {
    #|  return max(value, vec3<f32>(0.000001));
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let naga_oil = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(naga_oil.contains("vec3(0.000000000001f)"), content="true")
  debug_inspect(naga_oil.contains("vec3(0.000001f)"), content="true")
  debug_inspect(naga_oil.contains("e-"), content="false")
}

///|
test "naga-oil writer policy prints large f32 values as Naga fixed decimals" {
  let source =
    #|const FLOAT_MAX: f32 = 3.40282347e+38;
    #|fn sentinel(value: vec3<f32>) -> vec3<f32> {
    #|  return select(vec3(FLOAT_MAX), value, value >= vec3(0.0));
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let naga_oil = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    naga_oil.contains(
      "const FLOAT_MAX: f32 = 340282350000000000000000000000000000000f;",
    ),
    content="true",
  )
  debug_inspect(
    naga_oil.contains(
      "select(vec3(340282350000000000000000000000000000000f), value, (value >= vec3(0f)))",
    ),
    content="true",
  )
  debug_inspect(naga_oil.contains("3.4028234663852886e+38f"), content="false")
}
