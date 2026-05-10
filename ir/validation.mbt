///|
priv suberror WgslIrValidationError {
  InvalidTypeHandle(Int)
  InvalidConstantHandle(Int)
  InvalidOverrideHandle(Int)
  InvalidGlobalVariableHandle(Int)
  InvalidGlobalExpressionHandle(Int)
  InvalidFunctionHandle(Int)
  InvalidLocalVariableHandle(Int)
  InvalidFunctionExpressionHandle(Int)
  InvalidHandleRange(Int, Int)
  InvalidEntryPoint(String)
  MissingExpressionType(Int, String)
  InvalidConditionType(String, Int, String, String)
  InvalidStoreTarget(Int)
  InvalidReturnValue(String)
  InvalidFunctionArgumentCount(String, Int, Int)
  InvalidFunctionArgumentType(String, Int)
  InvalidFunctionResult(String)
  InvalidType(String)
  InvalidGlobalVariable(String)
  InvalidExpression(String, Int)
  InvalidStatement(String)
}

///|
fn WgslIrValidationError::message(self : WgslIrValidationError) -> String {
  match self {
    InvalidTypeHandle(index) => "invalid IR type handle: \{index}"
    InvalidConstantHandle(index) => "invalid IR constant handle: \{index}"
    InvalidOverrideHandle(index) => "invalid IR override handle: \{index}"
    InvalidGlobalVariableHandle(index) =>
      "invalid IR global variable handle: \{index}"
    InvalidGlobalExpressionHandle(index) =>
      "invalid IR global expression handle: \{index}"
    InvalidFunctionHandle(index) => "invalid IR function handle: \{index}"
    InvalidLocalVariableHandle(index) =>
      "invalid IR local variable handle: \{index}"
    InvalidFunctionExpressionHandle(index) =>
      "invalid IR function expression handle: \{index}"
    InvalidHandleRange(start, end) =>
      "invalid IR handle range: \{start}..\{end}"
    InvalidEntryPoint(name) => "invalid IR entry point: \{name}"
    MissingExpressionType(index, expression) =>
      "missing IR expression type for handle: \{index} (\{expression})"
    InvalidConditionType(function_name, index, expression, ty) =>
      "invalid IR condition expression type in \{function_name} for handle: \{index} (\{expression}) with type \{ty}"
    InvalidStoreTarget(index) =>
      "invalid IR store target expression type for handle: \{index}"
    InvalidReturnValue(name) => "invalid IR return value for function: \{name}"
    InvalidFunctionArgumentCount(name, expected, actual) =>
      "invalid IR function call argument count for \{name}: expected \{expected}, got \{actual}"
    InvalidFunctionArgumentType(name, index) =>
      "invalid IR function call argument type for \{name} at argument \{index}"
    InvalidFunctionResult(name) => "invalid IR function call result for \{name}"
    InvalidType(message) => "invalid IR type: \{message}"
    InvalidGlobalVariable(message) => "invalid IR global variable: \{message}"
    InvalidExpression(message, index) =>
      "invalid IR expression for handle \{index}: \{message}"
    InvalidStatement(message) => "invalid IR statement: \{message}"
  }
}

///|
fn validate_wgsl_ir_module(
  shader_module : Module,
) -> Unit raise WgslIrValidationError {
  let validator = WgslIrValidator::{ shader_module, filter: None }
  validator.validate_module()
}

///|
fn validate_wgsl_ir_module_with_filter(
  shader_module : Module,
  filter : WgslIrEmitFilter,
) -> Unit raise WgslIrValidationError {
  let validator = WgslIrValidator::{ shader_module, filter: Some(filter) }
  validator.validate_module()
}

///|
priv struct WgslIrValidator {
  shader_module : Module
  filter : WgslIrEmitFilter?
}

///|
priv struct WgslIrValidationLayout {
  align : Int
  size : Int
}

///|
fn WgslIrValidator::validate_module(
  self : WgslIrValidator,
) -> Unit raise WgslIrValidationError {
  for index in 0..<self.shader_module.types.items.length() {
    if self.should_validate_type(index) {
      self.validate_type_inner(self.shader_module.types.items[index].inner)
    }
  }
  for index in 0..<self.shader_module.constants.items.length() {
    if self.should_validate_constant(index) {
      let constant = self.shader_module.constants.items[index]
      self.require_type(constant.ty)
      self.validate_global_expression_handle(constant.init)
    }
  }
  for condition in self.shader_module.const_asserts {
    self.validate_global_expression_handle(condition)
  }
  for index in 0..<self.shader_module.overrides.items.length() {
    if self.should_validate_override(index) {
      let override_ = self.shader_module.overrides.items[index]
      self.require_type(override_.ty)
      match override_.init {
        Some(init) => self.validate_global_expression_handle(init)
        None => ()
      }
    }
  }
  for index in 0..<self.shader_module.global_variables.items.length() {
    if self.should_validate_global_variable(index) {
      let global = self.shader_module.global_variables.items[index]
      self.validate_global_variable(global)
    }
  }
  for index in 0..<self.shader_module.global_expressions.items.length() {
    if self.should_validate_global_expression(index) {
      self.validate_global_expression(
        self.shader_module.global_expressions.items[index],
      )
    }
  }
  for index in 0..<self.shader_module.functions.items.length() {
    if self.should_validate_function(index) {
      self.validate_function(self.shader_module.functions.items[index])
    }
  }
  for index in 0..<self.shader_module.entry_points.length() {
    if self.should_validate_entry_point(index) {
      self.validate_entry_point(self.shader_module.entry_points[index])
    }
  }
}

///|
fn WgslIrValidator::validate_entry_point(
  self : WgslIrValidator,
  entry_point : EntryPoint,
) -> Unit raise WgslIrValidationError {
  if entry_point.name == "" {
    raise WgslIrValidationError::InvalidEntryPoint(entry_point.name)
  }
  self.validate_function(entry_point.function)
}

///|
fn WgslIrValidator::should_validate_type(
  self : WgslIrValidator,
  index : Int,
) -> Bool {
  match self.filter {
    Some(filter) => filter.contains_type(index)
    None => true
  }
}

///|
fn WgslIrValidator::should_validate_constant(
  self : WgslIrValidator,
  index : Int,
) -> Bool {
  match self.filter {
    Some(filter) => filter.contains_constant(index)
    None => true
  }
}

///|
fn WgslIrValidator::should_validate_override(
  self : WgslIrValidator,
  index : Int,
) -> Bool {
  match self.filter {
    Some(filter) => filter.contains_override(index)
    None => true
  }
}

///|
fn WgslIrValidator::should_validate_global_variable(
  self : WgslIrValidator,
  index : Int,
) -> Bool {
  match self.filter {
    Some(filter) => filter.contains_global_variable(index)
    None => true
  }
}

///|
fn WgslIrValidator::should_validate_global_expression(
  self : WgslIrValidator,
  index : Int,
) -> Bool {
  ignore(index)
  match self.filter {
    Some(_) => false
    None => true
  }
}

///|
fn WgslIrValidator::should_validate_function(
  self : WgslIrValidator,
  index : Int,
) -> Bool {
  match self.filter {
    Some(filter) => filter.contains_function(index)
    None => true
  }
}

///|
fn WgslIrValidator::should_validate_entry_point(
  self : WgslIrValidator,
  index : Int,
) -> Bool {
  match self.filter {
    Some(filter) => filter.contains_entry_point(index)
    None => true
  }
}
