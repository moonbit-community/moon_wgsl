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
      self.require_global_compose_signature(ty, components)
    }
    Access(base, index) => {
      self.validate_global_expression_handle(base)
      self.validate_global_expression_handle(index)
      self.require_global_access_signature(base, index)
    }
    AccessIndex(base, index) => {
      self.validate_global_expression_handle(base)
      self.require_global_access_index_signature(base, index)
    }
    GlobalVariable(handle) => self.require_global_variable(handle)
    Load(pointer) => self.validate_global_expression_handle(pointer)
    AddressOf(ty, target) => {
      self.require_type(ty)
      self.validate_global_expression_handle(target)
      self.require_global_address_of_signature(ty, target)
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
      self.require_global_call_signature(handle, arguments)
    }
    Select(condition, accept, reject) => {
      self.validate_global_expression_handle(condition)
      self.validate_global_expression_handle(accept)
      self.validate_global_expression_handle(reject)
      self.require_global_select_signature(condition, accept, reject)
    }
    Bitcast(ty, expr) => {
      self.require_type(ty)
      self.validate_global_expression_handle(expr)
    }
    As(expr, kind, width) => {
      self.validate_global_expression_handle(expr)
      self.require_as_width(kind, width)
    }
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
      self.require_function_compose_signature(function, ty, components)
    }
    Access(base, index) => {
      self.validate_function_expression_handle(function, base)
      self.validate_function_expression_handle(function, index)
      self.require_function_access_signature(function, base, index)
    }
    AccessIndex(base, index) => {
      self.validate_function_expression_handle(function, base)
      self.require_function_access_index_signature(function, base, index)
    }
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
      self.require_function_address_of_signature(function, ty, target)
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
      self.require_call_signature(function, handle, arguments, None)
    }
    Select(condition, accept, reject) => {
      self.validate_function_expression_handle(function, condition)
      self.validate_function_expression_handle(function, accept)
      self.validate_function_expression_handle(function, reject)
      self.require_select_signature(function, condition, accept, reject)
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
    AtomicCall(atomic_function, arguments) => {
      for argument in arguments {
        self.validate_function_expression_handle(function, argument)
      }
      self.require_atomic_call_signature(function, atomic_function, arguments)
    }
    Bitcast(ty, expr) => {
      self.require_type(ty)
      self.validate_function_expression_handle(function, expr)
    }
    As(expr, kind, width) => {
      self.validate_function_expression_handle(function, expr)
      self.require_as_width(kind, width)
    }
    CallResult(handle) => self.require_function(handle)
    AtomicResult(handle, _) =>
      self.validate_function_expression_handle(function, handle)
    WorkGroupUniformLoadResult(handle) =>
      self.validate_function_expression_handle(function, handle)
    WorkGroupUniformLoad(handle) =>
      self.validate_function_expression_handle(function, handle)
    ArrayLength(handle) => {
      self.validate_function_expression_handle(function, handle)
      self.require_array_length_argument(function, handle)
    }
    Derivative(_, _, expr) =>
      self.validate_function_expression_handle(function, expr)
    Relational(_, expr) =>
      self.validate_function_expression_handle(function, expr)
    SubgroupCall(_, arguments) =>
      for argument in arguments {
        self.validate_function_expression_handle(function, argument)
      }
    CooperativeLoad(_, _, _, data) =>
      self.validate_cooperative_data(function, data)
    CooperativeMultiplyAdd(a, b, c) => {
      self.validate_function_expression_handle(function, a)
      self.validate_function_expression_handle(function, b)
      self.validate_function_expression_handle(function, c)
    }
    Splat(_, expr) => self.validate_function_expression_handle(function, expr)
    Swizzle(size, expr, components) => {
      self.validate_function_expression_handle(function, expr)
      self.require_swizzle_signature(function, size, expr, components)
    }
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
