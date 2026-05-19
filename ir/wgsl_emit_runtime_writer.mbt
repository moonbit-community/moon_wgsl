///|
priv struct WgslIrRuntimeWriterBackend {
  shader_module : Module
  filter : WgslIrEmitFilter?
}

///|
fn emit_wgsl_module_with_runtime_writer_backend(
  shader_module : Module,
  root_items : Array[String]?,
) -> String raise WgslIrEmitError {
  let backend = WgslIrRuntimeWriterBackend::{
    shader_module,
    filter: wgsl_ir_emit_filter_from_optional_roots(shader_module, root_items),
  }
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
  match self.filter {
    Some(filter) =>
      validate_wgsl_ir_module_with_filter(self.shader_module, filter) catch {
        error => raise WgslIrEmitError::Unsupported(error.message())
      }
    None =>
      validate_wgsl_ir_module(self.shader_module) catch {
        error => raise WgslIrEmitError::Unsupported(error.message())
      }
  }
}

///|
fn WgslIrRuntimeWriterBackend::emitter(
  self : WgslIrRuntimeWriterBackend,
) -> WgslIrEmitter {
  WgslIrEmitter::{
    shader_module: self.shader_module,
    options: WgslIrEmitOptions::valid_wgsl(),
    filter: self.filter,
    naga_writer_module: None,
    names: build_wgsl_ir_runtime_final_name_plan(self.shader_module),
    current_function_origin: None,
  }
}
