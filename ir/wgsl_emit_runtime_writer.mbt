///|
priv struct WgslIrRuntimeWriterBackend {
  shader_module : Module
  view : WgslIrNagaWriterModule
}

///|
fn emit_wgsl_module_with_runtime_writer_backend(
  shader_module : Module,
  root_items : Array[String]?,
) -> String raise WgslIrEmitError {
  let view = build_wgsl_ir_runtime_writer_module(shader_module, root_items)
  let backend = WgslIrRuntimeWriterBackend::{ shader_module, view }
  backend.emit()
}

///|
fn WgslIrRuntimeWriterBackend::emit(
  self : WgslIrRuntimeWriterBackend,
) -> String raise WgslIrEmitError {
  self.validate()
  self.emitter().emit_module()
}

///|
fn WgslIrRuntimeWriterBackend::validate(
  self : WgslIrRuntimeWriterBackend,
) -> Unit raise WgslIrEmitError {
  match self.view.filter {
    Some(filter) =>
      validate_wgsl_ir_module_with_filter(self.shader_module, filter) catch {
        error => raise Unsupported(error.message())
      }
    None =>
      validate_wgsl_ir_module(self.shader_module) catch {
        error => raise Unsupported(error.message())
      }
  }
}

///|
fn WgslIrRuntimeWriterBackend::emitter(
  self : WgslIrRuntimeWriterBackend,
) -> WgslIrEmitter {
  {
    shader_module: self.shader_module,
    options: WgslIrEmitOptions::valid_wgsl(),
    writer_module: self.view,
    names: self.view.names,
    current_function_origin: None,
    naga_compatible_negative_zero_seen: false,
    emitted_function_named_expressions: Set([]),
    emitted_function_materialized_expressions: Set([]),
  }
}
