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
fn emit_wgsl_module_from_ir_roots(
  shader_module : Module,
  root_items : Array[String],
) -> String raise WgslIrEmitError {
  emit_wgsl_module_with_runtime_writer_backend(shader_module, Some(root_items))
}

///|
priv struct WgslIrEmitter {
  shader_module : Module
  options : WgslIrEmitOptions
  writer_module : WgslIrWriterModule
  names : WgslIrFinalNamePlan
  current_function_origin : WgslIrEmitFunctionOrigin?
  emitted_function_named_expressions : @set.Set[Int]
  emitted_function_materialized_expressions : @set.Set[Int]
}

///|
fn WgslIrEmitter::type_inference(self : WgslIrEmitter) -> WgslIrTypeInference {
  WgslIrTypeInference::from_module(self.shader_module)
}

///|
fn WgslIrEmitter::optional_global_expression(
  self : WgslIrEmitter,
  handle : Handle,
) -> String? {
  Some(self.global_expression(handle)) catch {
    _ => None
  }
}

///|
fn WgslIrEmitter::type_spelling(self : WgslIrEmitter) -> WgslIrTypeSpelling {
  WgslIrTypeSpelling::new(
    self.shader_module,
    fn(handle) { self.names.get(wgsl_ir_emit_name_key("type", handle.index())) },
    fn(handle) { self.optional_global_expression(handle) },
    self.options.elide_storage_pointer_read_access(),
    self.options.storage_texture_type_argument_separator(),
  )
}

///|
fn WgslIrEmitter::type_is_pointer(
  self : WgslIrEmitter,
  handle : Handle,
) -> Bool {
  self.type_spelling().type_is_pointer(handle)
}

///|
fn WgslIrEmitter::type_contains_abstract_scalar(
  self : WgslIrEmitter,
  handle : Handle,
) -> Bool {
  self.type_spelling().type_contains_abstract_scalar(handle)
}

///|
fn WgslIrEmitter::expression_is_pointer(
  self : WgslIrEmitter,
  function : Function?,
  handle : Handle,
) -> Bool {
  self.type_spelling().expression_is_pointer(function, handle)
}

///|
fn WgslIrEmitter::type_name(
  self : WgslIrEmitter,
  handle : Handle,
) -> String raise WgslIrEmitError {
  self.type_spelling().type_name(handle) catch {
    error => raise Unsupported(error.message())
  }
}

///|
fn WgslIrEmitter::compose_constructor_name_for_components(
  self : WgslIrEmitter,
  handle : Handle,
  components : Array[Handle],
  function : Function?,
) -> String raise WgslIrEmitError {
  self
  .type_spelling()
  .compose_constructor_name_for_components(handle, components, function) catch {
    error => raise Unsupported(error.message())
  }
}

///|
fn WgslIrEmitter::expression_is_scalar_type(
  self : WgslIrEmitter,
  function : Function?,
  handle : Handle,
  scalar : Scalar,
) -> Bool {
  self.type_spelling().expression_is_scalar_type(function, handle, scalar)
}

///|
fn WgslIrEmitter::scalar_name(self : WgslIrEmitter, scalar : Scalar) -> String {
  self.type_spelling().scalar_name(scalar)
}

///|
fn WgslIrEmitter::address_space_template(
  self : WgslIrEmitter,
  space : AddressSpace,
) -> String {
  self.type_spelling().address_space_template(space)
}
