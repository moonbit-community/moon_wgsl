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
  emit_wgsl_module_from_ir_with_options(
    shader_module,
    WgslIrEmitOptions::valid_wgsl(),
  )
}

///|
fn emit_wgsl_module_from_ir_naga_oil_writer_compatible(
  shader_module : Module,
) -> String raise WgslIrEmitError {
  emit_wgsl_module_from_ir_with_options(
    shader_module,
    WgslIrEmitOptions::naga_oil_writer_compatible(),
  )
}

///|
fn emit_wgsl_module_from_ir_with_options(
  shader_module : Module,
  options : WgslIrEmitOptions,
) -> String raise WgslIrEmitError {
  validate_wgsl_ir_module(shader_module) catch {
    error => raise WgslIrEmitError::Unsupported(error.message())
  }
  let emitter = WgslIrEmitter::{ shader_module, options, filter: None }
  emitter.emit_module()
}

///|
fn emit_wgsl_module_from_ir_roots(
  shader_module : Module,
  root_items : Array[String],
) -> String raise WgslIrEmitError {
  emit_wgsl_module_from_ir_with_options_and_roots(
    shader_module,
    WgslIrEmitOptions::valid_wgsl(),
    root_items,
  )
}

///|
fn emit_wgsl_module_from_ir_with_options_and_roots(
  shader_module : Module,
  options : WgslIrEmitOptions,
  root_items : Array[String],
) -> String raise WgslIrEmitError {
  if root_items.length() == 0 {
    return emit_wgsl_module_from_ir_with_options(shader_module, options)
  }
  let filter = build_wgsl_ir_emit_filter(shader_module, root_items)
  validate_wgsl_ir_module_with_filter(shader_module, filter) catch {
    error => raise WgslIrEmitError::Unsupported(error.message())
  }
  let emitter = WgslIrEmitter::{ shader_module, options, filter: Some(filter) }
  emitter.emit_module()
}

///|
priv struct WgslIrEmitter {
  shader_module : Module
  options : WgslIrEmitOptions
  filter : WgslIrEmitFilter?
}
