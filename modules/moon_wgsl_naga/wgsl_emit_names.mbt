///|
fn WgslIrEmitter::constant_name(
  self : WgslIrEmitter,
  handle : Handle,
) -> String raise WgslIrEmitError {
  if self.shader_module.constants.items.get(handle.index()) == None {
    raise MissingHandle("constant \{handle.index()}")
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
      if self.should_inline_constant_expression(constant) {
        self.global_expression(constant.init)
      } else {
        self.constant_name(handle)
      }
    None => raise MissingHandle("constant \{handle.index()}")
  }
}

///|
fn WgslIrEmitter::should_inline_constant_expression(
  self : WgslIrEmitter,
  constant : Constant,
) -> Bool {
  if self.options.fold_numeric_constant_expressions() &&
    self.type_contains_abstract_scalar(constant.ty) {
    return true
  }
  self.options.inline_generated_import_constants() &&
  (
    constant.inline_value ||
    (constant.generated_import && self.constant_has_inline_only_type(constant))
  )
}

///|
fn WgslIrEmitter::should_skip_constant_declaration(
  self : WgslIrEmitter,
  constant : Constant,
) -> Bool {
  if self.options.fold_numeric_constant_expressions() &&
    self.type_contains_abstract_scalar(constant.ty) {
    return true
  }
  self.options.inline_generated_import_constants() &&
  constant.generated_import &&
  self.constant_has_inline_only_type(constant)
}

///|
fn WgslIrEmitter::constant_has_inline_only_type(
  self : WgslIrEmitter,
  constant : Constant,
) -> Bool {
  match self.shader_module.types.items.get(constant.ty.index()) {
    Some({ inner: Array(_, _, _), .. }) => true
    _ => false
  }
}

///|
fn WgslIrEmitter::override_name(
  self : WgslIrEmitter,
  handle : Handle,
) -> String raise WgslIrEmitError {
  if self.shader_module.overrides.items.get(handle.index()) == None {
    raise MissingHandle("override \{handle.index()}")
  }
  self.required_emit_name(wgsl_ir_emit_name_key("override", handle.index()))
}

///|
fn WgslIrEmitter::global_variable_name(
  self : WgslIrEmitter,
  handle : Handle,
) -> String raise WgslIrEmitError {
  if self.shader_module.global_variables.items.get(handle.index()) == None {
    raise MissingHandle("global variable \{handle.index()}")
  }
  self.required_emit_name(wgsl_ir_emit_name_key("global", handle.index()))
}

///|
fn WgslIrEmitter::function_name(
  self : WgslIrEmitter,
  handle : Handle,
) -> String raise WgslIrEmitError {
  if self.shader_module.functions.items.get(handle.index()) == None {
    raise MissingHandle("function \{handle.index()}")
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
    raise Unsupported("function argument outside function")
  }
  if func.arguments.get(index) == None {
    raise MissingHandle("function argument \{index}")
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
      raise Unsupported("function argument without emitter function origin")
  }
}

///|
fn WgslIrEmitter::local_variable_name(
  self : WgslIrEmitter,
  function : Function?,
  handle : Handle,
) -> String raise WgslIrEmitError {
  guard function is Some(func) else {
    raise Unsupported("local variable outside function")
  }
  if func.local_variables.items.get(handle.index()) == None {
    raise MissingHandle("local variable \{handle.index()}")
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
    None => raise Unsupported("local variable without emitter function origin")
  }
}

///|
fn WgslIrEmitter::function_named_expression_name(
  self : WgslIrEmitter,
  function : Function,
  handle : Handle,
) -> String? {
  guard wgsl_ir_function_named_expression_name(function, handle) != None else {
    return None
  }
  match self.current_function_origin {
    Some(origin) =>
      match
        self.names.get(wgsl_ir_emit_named_expression_name_key(origin, handle)) {
        Some(value) => Some(value)
        None => wgsl_ir_function_named_expression_name(function, handle)
      }
    None => wgsl_ir_function_named_expression_name(function, handle)
  }
}

///|
fn WgslIrEmitter::function_expression_temporary_name(
  self : WgslIrEmitter,
  handle : Handle,
) -> String raise WgslIrEmitError {
  match self.current_function_origin {
    Some(UserFunction(function_index)) =>
      self.required_emit_name(
        wgsl_ir_emit_name_key2("fn_expr", function_index, handle.index()),
      )
    Some(EntryPointFunction(entry_point_index)) =>
      self.required_emit_name(
        wgsl_ir_emit_name_key2("ep_expr", entry_point_index, handle.index()),
      )
    None =>
      raise Unsupported("function expression without emitter function origin")
  }
}

///|
fn WgslIrEmitter::optional_function_expression_temporary_name(
  self : WgslIrEmitter,
  handle : Handle,
) -> String? {
  match self.current_function_origin {
    Some(origin) =>
      self.names.get(wgsl_ir_emit_expression_temporary_name_key(origin, handle))
    None => None
  }
}
