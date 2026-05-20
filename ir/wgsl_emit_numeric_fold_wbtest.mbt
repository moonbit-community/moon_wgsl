///|
test "naga-oil writer policy folds pure literal float expressions in constructor context" {
  let source =
    #|fn specular_occlusion(color: vec3<f32>) -> f32 {
    #|  return dot(color, vec3<f32>(50.0 * 0.33));
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let naga_oil = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(naga_oil.contains("16.5f"), content="true")
  debug_inspect(naga_oil.contains("50f * 0.33f"), content="false")
}
