///|
test "function pointer member reads lower through explicit load expressions" {
  let source =
    #|struct Surface {
    #|  dielectric: f32,
    #|  metallic: f32,
    #|}
    #|
    #|fn shade(input: ptr<function, Surface>) -> f32 {
    #|  return max(input.dielectric, input.metallic);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("let _e"), content="true")
  debug_inspect(emitted.contains("max((*input).dielectric"), content="false")
  debug_inspect(emitted.contains("max(_e"), content="true")
}
