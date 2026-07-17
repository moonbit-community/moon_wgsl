///|
priv struct WgslIrCompatWriterBackend {
  shader_module : Module
  view : WgslIrWriterModule
}

///|
fn emit_wgsl_module_with_compat_writer_backend(
  shader_module : Module,
  root_items : Array[String]?,
  compatibility : WgslNagaCompatibilityView,
) -> String raise WgslIrEmitError {
  let backend = WgslIrCompatWriterBackend::{
    shader_module,
    view: build_wgsl_ir_writer_module(shader_module, root_items, compatibility~),
  }
  backend.emit()
}

///|
fn WgslIrCompatWriterBackend::emit(
  self : WgslIrCompatWriterBackend,
) -> String raise WgslIrEmitError {
  self.validate()
  self.emitter().emit_module()
}

///|
fn WgslIrCompatWriterBackend::validate(
  self : WgslIrCompatWriterBackend,
) -> Unit raise WgslIrEmitError {
  ignore(self.view.filter)
  validate_wgsl_ir_module(self.shader_module) catch {
    error => raise Unsupported(error.message())
  }
}

///|
fn WgslIrCompatWriterBackend::emitter(
  self : WgslIrCompatWriterBackend,
) -> WgslIrEmitter {
  {
    shader_module: self.shader_module,
    options: WgslIrEmitOptions::compat_writer(),
    writer_module: self.view,
    names: self.view.names,
    current_function_origin: None,
    compat_negative_zero_seen: false,
    emitted_function_named_expressions: Set([]),
    emitted_function_materialized_expressions: Set([]),
  }
}
