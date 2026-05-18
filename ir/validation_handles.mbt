///|
fn WgslIrValidator::validate_global_expression_handle(
  self : WgslIrValidator,
  handle : Handle,
) -> Unit raise WgslIrValidationError {
  if handle.index() < 0 ||
    handle.index() >= self.shader_module.global_expressions.items.length() {
    raise WgslIrValidationError::InvalidGlobalExpressionHandle(handle.index())
  }
}

///|
fn WgslIrValidator::validate_function_expression_handle(
  self : WgslIrValidator,
  function : Function,
  handle : Handle,
) -> Unit raise WgslIrValidationError {
  ignore(self)
  if handle.index() < 0 || handle.index() >= function.expressions.items.length() {
    raise WgslIrValidationError::InvalidFunctionExpressionHandle(handle.index())
  }
}

///|
fn WgslIrValidator::validate_function_expression_range(
  self : WgslIrValidator,
  function : Function,
  range : HandleRange,
) -> Unit raise WgslIrValidationError {
  ignore(self)
  if range.start.index() < 0 ||
    range.end.index() < range.start.index() ||
    range.end.index() >= function.expressions.items.length() {
    raise WgslIrValidationError::InvalidHandleRange(
      range.start.index(),
      range.end.index(),
    )
  }
}

///|
fn WgslIrValidator::require_type(
  self : WgslIrValidator,
  handle : Handle,
) -> Unit raise WgslIrValidationError {
  if handle.index() < 0 ||
    handle.index() >= self.shader_module.types.items.length() {
    raise WgslIrValidationError::InvalidTypeHandle(handle.index())
  }
}

///|
fn WgslIrValidator::require_constant(
  self : WgslIrValidator,
  handle : Handle,
) -> Unit raise WgslIrValidationError {
  if handle.index() < 0 ||
    handle.index() >= self.shader_module.constants.items.length() {
    raise WgslIrValidationError::InvalidConstantHandle(handle.index())
  }
}

///|
fn WgslIrValidator::require_override(
  self : WgslIrValidator,
  handle : Handle,
) -> Unit raise WgslIrValidationError {
  if handle.index() < 0 ||
    handle.index() >= self.shader_module.overrides.items.length() {
    raise WgslIrValidationError::InvalidOverrideHandle(handle.index())
  }
}

///|
fn WgslIrValidator::require_global_variable(
  self : WgslIrValidator,
  handle : Handle,
) -> Unit raise WgslIrValidationError {
  if handle.index() < 0 ||
    handle.index() >= self.shader_module.global_variables.items.length() {
    raise WgslIrValidationError::InvalidGlobalVariableHandle(handle.index())
  }
}

///|
fn WgslIrValidator::require_function(
  self : WgslIrValidator,
  handle : Handle,
) -> Unit raise WgslIrValidationError {
  if handle.index() < 0 ||
    handle.index() >= self.shader_module.functions.items.length() {
    raise WgslIrValidationError::InvalidFunctionHandle(handle.index())
  }
}

///|
fn WgslIrValidator::require_local_variable(
  self : WgslIrValidator,
  function : Function,
  handle : Handle,
) -> Unit raise WgslIrValidationError {
  ignore(self)
  if handle.index() < 0 ||
    handle.index() >= function.local_variables.items.length() {
    raise WgslIrValidationError::InvalidLocalVariableHandle(handle.index())
  }
}
