///|
pub suberror WgslIrValidationError {
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
}

///|
pub fn WgslIrValidationError::message(self : WgslIrValidationError) -> String {
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
  }
}

///|
pub fn validate_wgsl_ir_module(
  shader_module : Module,
) -> Unit raise WgslIrValidationError {
  let validator = WgslIrValidator::{ shader_module, }
  validator.validate_module()
}

///|
priv struct WgslIrValidator {
  shader_module : Module
}

///|
fn WgslIrValidator::validate_module(
  self : WgslIrValidator,
) -> Unit raise WgslIrValidationError {
  for ty in self.shader_module.types.items {
    self.validate_type_inner(ty.inner)
  }
  for constant in self.shader_module.constants.items {
    self.require_type(constant.ty)
    self.validate_global_expression_handle(constant.init)
  }
  for condition in self.shader_module.const_asserts {
    self.validate_global_expression_handle(condition)
  }
  for override_ in self.shader_module.overrides.items {
    self.require_type(override_.ty)
    match override_.init {
      Some(init) => self.validate_global_expression_handle(init)
      None => ()
    }
  }
  for global in self.shader_module.global_variables.items {
    self.require_type(global.ty)
    match global.init {
      Some(init) => self.validate_global_expression_handle(init)
      None => ()
    }
  }
  for expression in self.shader_module.global_expressions.items {
    self.validate_global_expression(expression)
  }
  for function in self.shader_module.functions.items {
    self.validate_function(function)
  }
  for entry_point in self.shader_module.entry_points {
    self.validate_entry_point(entry_point)
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
fn WgslIrValidator::validate_type_inner(
  self : WgslIrValidator,
  inner : TypeInner,
) -> Unit raise WgslIrValidationError {
  match inner {
    Pointer(base, _) => self.require_type(base)
    Array(base, size, _) => {
      self.require_type(base)
      self.validate_array_size(size)
    }
    BindingArray(base, size) => {
      self.require_type(base)
      self.validate_array_size(size)
    }
    Struct(members, _) | PredeclaredStruct(members, _) =>
      for struct_member in members {
        self.require_type(struct_member.ty)
      }
    _ => ()
  }
}

///|
fn WgslIrValidator::validate_array_size(
  self : WgslIrValidator,
  size : ArraySize,
) -> Unit raise WgslIrValidationError {
  match size {
    Pending(handle) => self.validate_global_expression_handle(handle)
    Constant(_) | Dynamic => ()
  }
}

///|
fn WgslIrValidator::validate_function(
  self : WgslIrValidator,
  function : Function,
) -> Unit raise WgslIrValidationError {
  for argument in function.arguments {
    self.require_type(argument.ty)
  }
  match function.result {
    Some(result) => self.require_type(result.ty)
    None => ()
  }
  for local_var in function.local_variables.items {
    self.require_type(local_var.ty)
    match local_var.init {
      Some(init) => self.validate_function_expression_handle(function, init)
      None => ()
    }
  }
  for expression in function.expressions.items {
    self.validate_function_expression(function, expression)
  }
  self.validate_block(function, function.body)
}

///|
fn WgslIrValidator::validate_block(
  self : WgslIrValidator,
  function : Function,
  block : Block,
) -> Unit raise WgslIrValidationError {
  for statement in block.statements {
    self.validate_statement(function, statement)
  }
}

///|
fn WgslIrValidator::validate_statement(
  self : WgslIrValidator,
  function : Function,
  statement : Statement,
) -> Unit raise WgslIrValidationError {
  match statement {
    Declare(handle) => self.require_local_variable(function, handle)
    Emit(range) => self.validate_function_expression_range(function, range)
    Block(block) => self.validate_block(function, block)
    If(condition, accept, reject) => {
      self.validate_function_expression_handle(function, condition)
      self.validate_block(function, accept)
      self.validate_block(function, reject)
    }
    Switch(selector, cases) => {
      self.validate_function_expression_handle(function, selector)
      for case in cases {
        self.validate_block(function, case.body)
      }
    }
    Loop(body, continuing, break_if) => {
      self.validate_block(function, body)
      self.validate_block(function, continuing)
      match break_if {
        Some(condition) =>
          self.validate_function_expression_handle(function, condition)
        None => ()
      }
    }
    Return(value) =>
      match value {
        Some(handle) =>
          self.validate_function_expression_handle(function, handle)
        None => ()
      }
    ConstAssert(condition) =>
      self.validate_function_expression_handle(function, condition)
    Store(pointer, value) => {
      self.validate_function_expression_handle(function, pointer)
      self.validate_function_expression_handle(function, value)
    }
    ImageStore(image, coordinate, array_index, value) => {
      self.validate_function_expression_handle(function, image)
      self.validate_function_expression_handle(function, coordinate)
      match array_index {
        Some(index) => self.validate_function_expression_handle(function, index)
        None => ()
      }
      self.validate_function_expression_handle(function, value)
    }
    Atomic(pointer, _, value, compare) => {
      self.validate_function_expression_handle(function, pointer)
      self.validate_function_expression_handle(function, value)
      match compare {
        Some(handle) =>
          self.validate_function_expression_handle(function, handle)
        None => ()
      }
    }
    ImageAtomic(image, coordinate, array_index, _, value) => {
      self.validate_function_expression_handle(function, image)
      self.validate_function_expression_handle(function, coordinate)
      match array_index {
        Some(index) => self.validate_function_expression_handle(function, index)
        None => ()
      }
      self.validate_function_expression_handle(function, value)
    }
    WorkGroupUniformLoad(pointer, result) => {
      self.validate_function_expression_handle(function, pointer)
      self.validate_function_expression_handle(function, result)
    }
    Call(callee, arguments, result) => {
      self.require_function(callee)
      for argument in arguments {
        self.validate_function_expression_handle(function, argument)
      }
      match result {
        Some(handle) =>
          self.validate_function_expression_handle(function, handle)
        None => ()
      }
    }
    RayQuery(handle, _) =>
      self.validate_function_expression_handle(function, handle)
    RayPipelineFunction(_) => ()
    SubgroupBallot(value, result) => {
      self.validate_function_expression_handle(function, value)
      match result {
        Some(handle) =>
          self.validate_function_expression_handle(function, handle)
        None => ()
      }
    }
    SubgroupGather(_, value, result) => {
      self.validate_function_expression_handle(function, value)
      self.validate_function_expression_handle(function, result)
    }
    SubgroupCollectiveOperation(_, _, value, result) => {
      self.validate_function_expression_handle(function, value)
      self.validate_function_expression_handle(function, result)
    }
    CooperativeStore(_, data) => self.validate_cooperative_data(function, data)
    Break | Continue | Kill | ControlBarrier(_) | MemoryBarrier(_) => ()
  }
}

///|
fn WgslIrValidator::validate_global_expression(
  self : WgslIrValidator,
  expression : Expression,
) -> Unit raise WgslIrValidationError {
  match expression {
    Constant(handle) => self.require_constant(handle)
    Override(handle) => self.require_override(handle)
    ZeroValue(ty) => self.require_type(ty)
    Compose(ty, components) => {
      self.require_type(ty)
      for component in components {
        self.validate_global_expression_handle(component)
      }
    }
    Access(base, index) => {
      self.validate_global_expression_handle(base)
      self.validate_global_expression_handle(index)
    }
    AccessIndex(base, _) => self.validate_global_expression_handle(base)
    GlobalVariable(handle) => self.require_global_variable(handle)
    Load(pointer) => self.validate_global_expression_handle(pointer)
    AddressOf(ty, target) => {
      self.require_type(ty)
      self.validate_global_expression_handle(target)
    }
    Unary(_, expr) => self.validate_global_expression_handle(expr)
    Binary(_, left, right) => {
      self.validate_global_expression_handle(left)
      self.validate_global_expression_handle(right)
    }
    FunctionCall(handle, arguments) => {
      self.require_function(handle)
      for argument in arguments {
        self.validate_global_expression_handle(argument)
      }
    }
    Select(condition, accept, reject) => {
      self.validate_global_expression_handle(condition)
      self.validate_global_expression_handle(accept)
      self.validate_global_expression_handle(reject)
    }
    Bitcast(_, expr) => self.validate_global_expression_handle(expr)
    As(expr, _, _) => self.validate_global_expression_handle(expr)
    Relational(_, expr) => self.validate_global_expression_handle(expr)
    Literal(_) => ()
    _ => ()
  }
}

///|
fn WgslIrValidator::validate_function_expression(
  self : WgslIrValidator,
  function : Function,
  expression : Expression,
) -> Unit raise WgslIrValidationError {
  match expression {
    Constant(handle) => self.require_constant(handle)
    Override(handle) => self.require_override(handle)
    ZeroValue(ty) => self.require_type(ty)
    Compose(ty, components) => {
      self.require_type(ty)
      for component in components {
        self.validate_function_expression_handle(function, component)
      }
    }
    Access(base, index) => {
      self.validate_function_expression_handle(function, base)
      self.validate_function_expression_handle(function, index)
    }
    AccessIndex(base, _) =>
      self.validate_function_expression_handle(function, base)
    FunctionArgument(index) =>
      if index < 0 || index >= function.arguments.length() {
        raise WgslIrValidationError::InvalidFunctionExpressionHandle(index)
      }
    GlobalVariable(handle) => self.require_global_variable(handle)
    LocalVariable(handle) => self.require_local_variable(function, handle)
    Load(pointer) => self.validate_function_expression_handle(function, pointer)
    AddressOf(ty, target) => {
      self.require_type(ty)
      self.validate_function_expression_handle(function, target)
    }
    Unary(_, expr) => self.validate_function_expression_handle(function, expr)
    Binary(_, left, right) => {
      self.validate_function_expression_handle(function, left)
      self.validate_function_expression_handle(function, right)
    }
    FunctionCall(handle, arguments) => {
      self.require_function(handle)
      for argument in arguments {
        self.validate_function_expression_handle(function, argument)
      }
    }
    Select(condition, accept, reject) => {
      self.validate_function_expression_handle(function, condition)
      self.validate_function_expression_handle(function, accept)
      self.validate_function_expression_handle(function, reject)
    }
    ImageSample(
      image,
      sampler,
      gather,
      coordinate,
      array_index,
      offset,
      level,
      depth_ref,
      _
    ) => {
      self.validate_function_expression_handle(function, image)
      self.validate_function_expression_handle(function, sampler)
      match gather {
        Some(_) => ()
        None => ()
      }
      self.validate_function_expression_handle(function, coordinate)
      match array_index {
        Some(handle) =>
          self.validate_function_expression_handle(function, handle)
        None => ()
      }
      match offset {
        Some(handle) =>
          self.validate_function_expression_handle(function, handle)
        None => ()
      }
      self.validate_sample_level(function, level)
      match depth_ref {
        Some(handle) =>
          self.validate_function_expression_handle(function, handle)
        None => ()
      }
    }
    ImageLoad(image, coordinate, array_index, sample, level) => {
      self.validate_function_expression_handle(function, image)
      self.validate_function_expression_handle(function, coordinate)
      match array_index {
        Some(handle) =>
          self.validate_function_expression_handle(function, handle)
        None => ()
      }
      match sample {
        Some(handle) =>
          self.validate_function_expression_handle(function, handle)
        None => ()
      }
      match level {
        Some(handle) =>
          self.validate_function_expression_handle(function, handle)
        None => ()
      }
    }
    ImageQuery(image, query) => {
      self.validate_function_expression_handle(function, image)
      match query {
        Size(level) =>
          match level {
            Some(handle) =>
              self.validate_function_expression_handle(function, handle)
            None => ()
          }
        _ => ()
      }
    }
    RayQueryInitialize(query, acceleration, ray_desc) => {
      self.validate_function_expression_handle(function, query)
      self.validate_function_expression_handle(function, acceleration)
      self.validate_function_expression_handle(function, ray_desc)
    }
    RayQueryProceed(query)
    | RayQueryConfirmIntersection(query)
    | RayQueryTerminate(query)
    | RayQueryGetIntersection(query, _) =>
      self.validate_function_expression_handle(function, query)
    RayQueryGenerateIntersection(query, intersection_t) => {
      self.validate_function_expression_handle(function, query)
      self.validate_function_expression_handle(function, intersection_t)
    }
    Math(_, a, b, c, d) => {
      self.validate_function_expression_handle(function, a)
      self.validate_optional_function_expression(function, b)
      self.validate_optional_function_expression(function, c)
      self.validate_optional_function_expression(function, d)
    }
    AtomicCall(_, arguments) =>
      for argument in arguments {
        self.validate_function_expression_handle(function, argument)
      }
    Bitcast(_, expr) => self.validate_function_expression_handle(function, expr)
    As(expr, _, _) => self.validate_function_expression_handle(function, expr)
    CallResult(handle) => self.require_function(handle)
    AtomicResult(handle, _) =>
      self.validate_function_expression_handle(function, handle)
    WorkGroupUniformLoadResult(handle) =>
      self.validate_function_expression_handle(function, handle)
    WorkGroupUniformLoad(handle) =>
      self.validate_function_expression_handle(function, handle)
    ArrayLength(handle) =>
      self.validate_function_expression_handle(function, handle)
    Derivative(_, _, expr) =>
      self.validate_function_expression_handle(function, expr)
    Relational(_, expr) =>
      self.validate_function_expression_handle(function, expr)
    SubgroupCall(_, arguments) =>
      for argument in arguments {
        self.validate_function_expression_handle(function, argument)
      }
    Splat(_, expr) => self.validate_function_expression_handle(function, expr)
    Swizzle(_, expr, _) =>
      self.validate_function_expression_handle(function, expr)
    Literal(_) => ()
    _ => ()
  }
}

///|
fn WgslIrValidator::validate_sample_level(
  self : WgslIrValidator,
  function : Function,
  level : SampleLevel,
) -> Unit raise WgslIrValidationError {
  match level {
    Exact(handle) | Bias(handle) =>
      self.validate_function_expression_handle(function, handle)
    Gradient(x, y) => {
      self.validate_function_expression_handle(function, x)
      self.validate_function_expression_handle(function, y)
    }
    Auto | Zero => ()
  }
}

///|
fn WgslIrValidator::validate_cooperative_data(
  self : WgslIrValidator,
  function : Function,
  data : CooperativeData,
) -> Unit raise WgslIrValidationError {
  self.validate_function_expression_handle(function, data.pointer)
  self.validate_function_expression_handle(function, data.stride)
}

///|
fn WgslIrValidator::validate_optional_function_expression(
  self : WgslIrValidator,
  function : Function,
  handle : Handle?,
) -> Unit raise WgslIrValidationError {
  match handle {
    Some(value) => self.validate_function_expression_handle(function, value)
    None => ()
  }
}

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
    range.end.index() > function.expressions.items.length() {
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
