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
