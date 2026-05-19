///|
priv struct WgslIrNagaOilWriterBackend {
  shader_module : Module
  view : WgslIrNagaCompatView
}

///|
fn emit_wgsl_module_with_naga_oil_writer_backend(
  shader_module : Module,
  root_items : Array[String]?,
) -> String raise WgslIrEmitError {
  let backend = WgslIrNagaOilWriterBackend::{
    shader_module,
    view: build_wgsl_ir_naga_compat_view(shader_module, root_items),
  }
  backend.emit()
}

///|
fn WgslIrNagaOilWriterBackend::emit(
  self : WgslIrNagaOilWriterBackend,
) -> String raise WgslIrEmitError {
  self.validate()
  self.emitter().emit_module()
}

///|
fn WgslIrNagaOilWriterBackend::validate(
  self : WgslIrNagaOilWriterBackend,
) -> Unit raise WgslIrEmitError {
  match self.view.filter {
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
fn WgslIrNagaOilWriterBackend::emitter(
  self : WgslIrNagaOilWriterBackend,
) -> WgslIrEmitter {
  WgslIrEmitter::{
    shader_module: self.shader_module,
    options: WgslIrEmitOptions::naga_oil_writer_backend(),
    filter: self.view.filter,
    naga_compat_view: Some(self.view),
    names: self.view.names,
    current_function_origin: None,
  }
}
