///|
test "naga-oil writer policy folds pure literal math arguments in scalar context" {
  let source =
    #|fn linear_to_srgb(value: f32) -> f32 {
    #|  return (1.055 * pow(value, 1.0 / 2.4)) - 0.055;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let naga_oil = emit_wgsl_module_from_ir_compat_writer(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(naga_oil.contains("pow(value, 0.41666666f)"), content="true")
  debug_inspect(naga_oil.contains("pow(value, (1f / 2.4f))"), content="false")
}
