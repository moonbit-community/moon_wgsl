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
fn emit_wgsl_module_from_ir_compat_writer(
  shader_module : Module,
) -> String raise WgslIrEmitError {
  emit_wgsl_module_with_compat_writer_backend(shader_module, None)
}

///|
fn emit_wgsl_module_from_ir_roots(
  shader_module : Module,
  root_items : Array[String],
) -> String raise WgslIrEmitError {
  emit_wgsl_module_with_runtime_writer_backend(shader_module, Some(root_items))
}

///|
fn emit_wgsl_module_from_ir_compat_writer_roots(
  shader_module : Module,
  root_items : Array[String],
) -> String raise WgslIrEmitError {
  emit_wgsl_module_with_compat_writer_backend(shader_module, Some(root_items))
}

///|
priv struct WgslIrEmitter {
  shader_module : Module
  options : WgslIrEmitOptions
  writer_module : WgslIrWriterModule
  names : WgslIrFinalNamePlan
  current_function_origin : WgslIrEmitFunctionOrigin?
  mut compat_negative_zero_seen : Bool
  emitted_function_named_expressions : @set.Set[Int]
  emitted_function_materialized_expressions : @set.Set[Int]
}
