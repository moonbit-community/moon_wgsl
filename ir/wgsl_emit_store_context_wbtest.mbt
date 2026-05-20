///|
test "naga-oil writer contextualizes store value from pointer type" {
  let source =
    #|var<private> counter: u32;
    #|
    #|fn reset() {
    #|  counter = 0;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("counter = 0u;"), content="true")
  debug_inspect(emitted.contains("counter = 0;"), content="false")
}
