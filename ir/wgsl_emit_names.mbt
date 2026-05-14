///|
fn WgslIrEmitter::constant_name(
  self : WgslIrEmitter,
  handle : Handle,
) -> String raise WgslIrEmitError {
  if self.shader_module.constants.items.get(handle.index()) == None {
    raise WgslIrEmitError::MissingHandle("constant \{handle.index()}")
  }
  self.required_emit_name(wgsl_ir_emit_name_key("const", handle.index()))
}

///|
fn WgslIrEmitter::constant_expression(
  self : WgslIrEmitter,
  handle : Handle,
) -> String raise WgslIrEmitError {
  match self.shader_module.constants.items.get(handle.index()) {
    Some(constant) =>
      if self.options.inline_generated_import_constants && constant.inline_value {
        self.global_expression(constant.init)
      } else {
        self.constant_name(handle)
      }
    None => raise WgslIrEmitError::MissingHandle("constant \{handle.index()}")
  }
}

///|
fn WgslIrEmitter::override_name(
  self : WgslIrEmitter,
  handle : Handle,
) -> String raise WgslIrEmitError {
  if self.shader_module.overrides.items.get(handle.index()) == None {
    raise WgslIrEmitError::MissingHandle("override \{handle.index()}")
  }
  self.required_emit_name(wgsl_ir_emit_name_key("override", handle.index()))
}

///|
fn WgslIrEmitter::global_variable_name(
  self : WgslIrEmitter,
  handle : Handle,
) -> String raise WgslIrEmitError {
  if self.shader_module.global_variables.items.get(handle.index()) == None {
    raise WgslIrEmitError::MissingHandle("global variable \{handle.index()}")
  }
  self.required_emit_name(wgsl_ir_emit_name_key("global", handle.index()))
}

///|
fn WgslIrEmitter::function_name(
  self : WgslIrEmitter,
  handle : Handle,
) -> String raise WgslIrEmitError {
  if self.shader_module.functions.items.get(handle.index()) == None {
    raise WgslIrEmitError::MissingHandle("function \{handle.index()}")
  }
  self.required_emit_name(wgsl_ir_emit_name_key("fn", handle.index()))
}

///|
fn WgslIrEmitter::function_argument_name(
  self : WgslIrEmitter,
  function : Function?,
  index : Int,
) -> String raise WgslIrEmitError {
  guard function is Some(func) else {
    raise WgslIrEmitError::Unsupported("function argument outside function")
  }
  if func.arguments.get(index) == None {
    raise WgslIrEmitError::MissingHandle("function argument \{index}")
  }
  match self.current_function_origin {
    Some(UserFunction(function_index)) =>
      self.required_emit_name(
        wgsl_ir_emit_name_key2("fn_arg", function_index, index),
      )
    Some(EntryPointFunction(entry_point_index)) =>
      self.required_emit_name(
        wgsl_ir_emit_name_key2("ep_arg", entry_point_index, index),
      )
    None =>
      raise WgslIrEmitError::Unsupported(
        "function argument without emitter function origin",
      )
  }
}

///|
fn WgslIrEmitter::local_variable_name(
  self : WgslIrEmitter,
  function : Function?,
  handle : Handle,
) -> String raise WgslIrEmitError {
  guard function is Some(func) else {
    raise WgslIrEmitError::Unsupported("local variable outside function")
  }
  if func.local_variables.items.get(handle.index()) == None {
    raise WgslIrEmitError::MissingHandle("local variable \{handle.index()}")
  }
  match self.current_function_origin {
    Some(UserFunction(function_index)) =>
      self.required_emit_name(
        wgsl_ir_emit_name_key2("fn_local", function_index, handle.index()),
      )
    Some(EntryPointFunction(entry_point_index)) =>
      self.required_emit_name(
        wgsl_ir_emit_name_key2("ep_local", entry_point_index, handle.index()),
      )
    None =>
      raise WgslIrEmitError::Unsupported(
        "local variable without emitter function origin",
      )
  }
}
