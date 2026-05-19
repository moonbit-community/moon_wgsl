///|
priv suberror WgslIrEmitError {
  MissingHandle(String)
  MissingName(String)
  Unsupported(String)
}

///|
fn WgslIrEmitError::message(self : WgslIrEmitError) -> String {
  match self {
    MissingHandle(message) => "missing IR handle: \{message}"
    MissingName(message) => "missing IR name: \{message}"
    Unsupported(message) => "unsupported IR emission: \{message}"
  }
}

///|
fn emit_wgsl_module_from_ir(
  shader_module : Module,
) -> String raise WgslIrEmitError {
  emit_wgsl_module_with_runtime_writer_backend(shader_module, None)
}

///|
fn emit_wgsl_module_from_ir_naga_oil_writer_compatible(
  shader_module : Module,
) -> String raise WgslIrEmitError {
  emit_wgsl_module_with_naga_oil_writer_backend(shader_module, None)
}

///|
fn emit_wgsl_module_from_ir_roots(
  shader_module : Module,
  root_items : Array[String],
) -> String raise WgslIrEmitError {
  emit_wgsl_module_with_runtime_writer_backend(shader_module, Some(root_items))
}

///|
fn emit_wgsl_module_from_ir_naga_oil_writer_compatible_roots(
  shader_module : Module,
  root_items : Array[String],
) -> String raise WgslIrEmitError {
  emit_wgsl_module_with_naga_oil_writer_backend(shader_module, Some(root_items))
}

///|
priv struct WgslIrEmitter {
  shader_module : Module
  options : WgslIrEmitOptions
  writer_module : WgslIrNagaWriterModule
  names : WgslIrFinalNamePlan
  current_function_origin : WgslIrEmitFunctionOrigin?
}
