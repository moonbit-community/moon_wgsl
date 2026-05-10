///|
fn WgslIrValidator::missing_function_expression_type(
  self : WgslIrValidator,
  function : Function,
  handle : Handle,
) -> WgslIrValidationError {
  ignore(self)
  let expression = match function.expressions.items.get(handle.index()) {
    Some(value) => @debug.to_string(value)
    None => "<invalid function expression handle>"
  }
  WgslIrValidationError::MissingExpressionType(handle.index(), expression)
}

///|
fn WgslIrValidator::missing_global_expression_type(
  self : WgslIrValidator,
  handle : Handle,
) -> WgslIrValidationError {
  let expression = match
    self.shader_module.global_expressions.items.get(handle.index()) {
    Some(value) => @debug.to_string(value)
    None => "<invalid global expression handle>"
  }
  WgslIrValidationError::MissingExpressionType(handle.index(), expression)
}

///|
fn WgslIrValidator::invalid_condition_type(
  self : WgslIrValidator,
  function : Function,
  handle : Handle,
  ty : Handle,
) -> WgslIrValidationError {
  let expression = match function.expressions.items.get(handle.index()) {
    Some(value) => @debug.to_string(value)
    None => "<invalid function expression handle>"
  }
  let ty_text = match self.shader_module.types.items.get(ty.index()) {
    Some(value) => @debug.to_string(value)
    None => "<invalid type handle>"
  }
  WgslIrValidationError::InvalidConditionType(
    self.function_display_name(function),
    handle.index(),
    expression,
    ty_text,
  )
}

///|
fn WgslIrValidator::require_bool_condition(
  self : WgslIrValidator,
  function : Function,
  handle : Handle,
) -> Unit raise WgslIrValidationError {
  guard self.function_expression_type(function, handle) is Some(ty) else {
    raise self.missing_function_expression_type(function, handle)
  }
  guard self.type_is_bool_scalar(ty) else {
    raise self.invalid_condition_type(function, handle, ty)
  }
}

///|
fn WgslIrValidator::require_integer_selector(
  self : WgslIrValidator,
  function : Function,
  handle : Handle,
) -> Unit raise WgslIrValidationError {
  guard self.function_expression_type(function, handle) is Some(ty) else {
    raise self.missing_function_expression_type(function, handle)
  }
  guard self.type_is_integer_scalar(ty) else {
    raise self.invalid_condition_type(function, handle, ty)
  }
}

///|
fn WgslIrValidator::require_return_value(
  self : WgslIrValidator,
  function : Function,
  handle : Handle,
) -> Unit raise WgslIrValidationError {
  guard function.result is Some(result) else {
    raise WgslIrValidationError::InvalidReturnValue(
      self.function_display_name(function),
    )
  }
  match self.function_expression_type(function, handle) {
    Some(actual) =>
      if !self.type_assignable(result.ty, actual) {
        raise WgslIrValidationError::InvalidReturnValue(
          self.function_display_name(function),
        )
      }
    None => ()
  }
}

///|
fn WgslIrValidator::require_void_return(
  self : WgslIrValidator,
  function : Function,
) -> Unit raise WgslIrValidationError {
  if function.result != None {
    raise WgslIrValidationError::InvalidReturnValue(
      self.function_display_name(function),
    )
  }
}

///|
fn WgslIrValidator::require_store(
  self : WgslIrValidator,
  function : Function,
  pointer : Handle,
  value : Handle,
) -> Unit raise WgslIrValidationError {
  guard self.store_target_value_type(function, pointer) is Some(value_ty) else {
    raise WgslIrValidationError::InvalidStoreTarget(pointer.index())
  }
  match self.function_expression_type(function, value) {
    Some(actual) =>
      if !self.type_assignable(value_ty, actual) {
        raise WgslIrValidationError::InvalidStoreTarget(pointer.index())
      }
    None => ()
  }
}

///|
fn WgslIrValidator::require_function_compose_signature(
  self : WgslIrValidator,
  function : Function,
  ty : Handle,
  components : Array[Handle],
) -> Unit raise WgslIrValidationError {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Scalar(_) =>
          if components.length() != 0 && components.length() != 1 {
            raise WgslIrValidationError::InvalidExpression(
              "scalar constructor component count mismatch",
              ty.index(),
            )
          }
        Vector(size, _) =>
          self.require_composite_component_capacity(
            function,
            components,
            size.width(),
            ty.index(),
          )
        Matrix(columns, rows, _) =>
          self.require_composite_component_capacity(
            function,
            components,
            columns.width() * rows.width(),
            ty.index(),
          )
        Struct(members, _) | PredeclaredStruct(members, _) =>
          if components.length() != 0 && components.length() != members.length() {
            raise WgslIrValidationError::InvalidExpression(
              "struct constructor component count mismatch",
              ty.index(),
            )
          }
        Array(_, Constant(count), _) | BindingArray(_, Constant(count)) =>
          if components.length() != 0 && components.length() != count {
            raise WgslIrValidationError::InvalidExpression(
              "array constructor component count mismatch",
              ty.index(),
            )
          }
        Array(_, Dynamic, _) | BindingArray(_, Dynamic) =>
          raise WgslIrValidationError::InvalidExpression(
            "runtime array constructor is not valid",
            ty.index(),
          )
        _ => ()
      }
    None => ()
  }
}

///|
fn WgslIrValidator::require_global_compose_signature(
  self : WgslIrValidator,
  ty : Handle,
  components : Array[Handle],
) -> Unit raise WgslIrValidationError {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Scalar(_) =>
          if components.length() != 0 && components.length() != 1 {
            raise WgslIrValidationError::InvalidExpression(
              "scalar constructor component count mismatch",
              ty.index(),
            )
          }
        Vector(size, _) =>
          self.require_global_composite_component_capacity(
            components,
            size.width(),
            ty.index(),
          )
        Matrix(columns, rows, _) =>
          self.require_global_composite_component_capacity(
            components,
            columns.width() * rows.width(),
            ty.index(),
          )
        Struct(members, _) | PredeclaredStruct(members, _) =>
          if components.length() != 0 && components.length() != members.length() {
            raise WgslIrValidationError::InvalidExpression(
              "struct constructor component count mismatch",
              ty.index(),
            )
          }
        Array(_, Constant(count), _) | BindingArray(_, Constant(count)) =>
          if components.length() != 0 && components.length() != count {
            raise WgslIrValidationError::InvalidExpression(
              "array constructor component count mismatch",
              ty.index(),
            )
          }
        Array(_, Dynamic, _) | BindingArray(_, Dynamic) =>
          raise WgslIrValidationError::InvalidExpression(
            "runtime array constructor is not valid",
            ty.index(),
          )
        _ => ()
      }
    None => ()
  }
}

///|
fn WgslIrValidator::require_composite_component_capacity(
  self : WgslIrValidator,
  function : Function,
  components : Array[Handle],
  expected_lanes : Int,
  expression_index : Int,
) -> Unit raise WgslIrValidationError {
  if components.length() == 0 {
    return
  }
  let mut lanes = 0
  for component in components {
    match self.function_expression_lane_count(function, component) {
      Some(count) => lanes += count
      None => raise self.missing_function_expression_type(function, component)
    }
  }
  if lanes != expected_lanes && !(components.length() == 1 && lanes == 1) {
    raise WgslIrValidationError::InvalidExpression(
      "vector constructor lane count mismatch", expression_index,
    )
  }
}

///|
fn WgslIrValidator::function_expression_lane_count(
  self : WgslIrValidator,
  function : Function,
  handle : Handle,
) -> Int? {
  match function.expressions.items.get(handle.index()) {
    Some(expression) =>
      match expression {
        Swizzle(size, _, _) | Splat(size, _) => Some(size.width())
        Compose(ty, _) | ZeroValue(ty) =>
          match self.shader_module.types.get(ty) {
            Some(_) => Some(self.type_lane_count(ty))
            None => None
          }
        Literal(_) => Some(1)
        _ =>
          match self.function_expression_type(function, handle) {
            Some(ty) => Some(self.type_lane_count(ty))
            None => None
          }
      }
    None => None
  }
}

///|
fn WgslIrValidator::global_expression_lane_count(
  self : WgslIrValidator,
  handle : Handle,
) -> Int? {
  match self.shader_module.global_expressions.items.get(handle.index()) {
    Some(expression) =>
      match expression {
        Swizzle(size, _, _) | Splat(size, _) => Some(size.width())
        Compose(ty, _) | ZeroValue(ty) =>
          match self.shader_module.types.get(ty) {
            Some(_) => Some(self.type_lane_count(ty))
            None => None
          }
        Literal(_) => Some(1)
        _ =>
          match self.global_expression_type(handle) {
            Some(ty) => Some(self.type_lane_count(ty))
            None => None
          }
      }
    None => None
  }
}

///|
fn WgslIrValidator::require_global_composite_component_capacity(
  self : WgslIrValidator,
  components : Array[Handle],
  expected_lanes : Int,
  expression_index : Int,
) -> Unit raise WgslIrValidationError {
  if components.length() == 0 {
    return
  }
  let mut lanes = 0
  for component in components {
    match self.global_expression_lane_count(component) {
      Some(count) => lanes += count
      None => {
        guard self.global_expression_type(component) is Some(_) else {
          raise self.missing_global_expression_type(component)
        }
      }
    }
  }
  if lanes != expected_lanes && !(components.length() == 1 && lanes == 1) {
    raise WgslIrValidationError::InvalidExpression(
      "vector constructor lane count mismatch", expression_index,
    )
  }
}

///|
fn WgslIrValidator::require_function_access_signature(
  self : WgslIrValidator,
  function : Function,
  base : Handle,
  index : Handle,
) -> Unit raise WgslIrValidationError {
  guard self.function_expression_type(function, base) is Some(base_ty) else {
    raise self.missing_function_expression_type(function, base)
  }
  guard self.dynamic_indexed_type(base_ty) is Some(_) else {
    raise WgslIrValidationError::InvalidExpression(
      "dynamic access base is not indexable",
      base.index(),
    )
  }
  guard self.function_expression_type(function, index) is Some(index_ty) else {
    raise self.missing_function_expression_type(function, index)
  }
  if !self.type_is_integer_scalar(index_ty) {
    raise WgslIrValidationError::InvalidExpression(
      "dynamic access index is not an integer scalar",
      index.index(),
    )
  }
}

///|
fn WgslIrValidator::require_global_access_signature(
  self : WgslIrValidator,
  base : Handle,
  index : Handle,
) -> Unit raise WgslIrValidationError {
  guard self.global_expression_type(base) is Some(base_ty) else {
    raise self.missing_global_expression_type(base)
  }
  guard self.dynamic_indexed_type(base_ty) is Some(_) else {
    raise WgslIrValidationError::InvalidExpression(
      "dynamic access base is not indexable",
      base.index(),
    )
  }
  guard self.global_expression_type(index) is Some(index_ty) else {
    raise self.missing_global_expression_type(index)
  }
  if !self.type_is_integer_scalar(index_ty) {
    raise WgslIrValidationError::InvalidExpression(
      "dynamic access index is not an integer scalar",
      index.index(),
    )
  }
}

///|
fn WgslIrValidator::require_function_access_index_signature(
  self : WgslIrValidator,
  function : Function,
  base : Handle,
  index : Int,
) -> Unit raise WgslIrValidationError {
  guard self.function_expression_type(function, base) is Some(base_ty) else {
    raise self.missing_function_expression_type(function, base)
  }
  guard self.indexed_type(base_ty, Some(index)) is Some(_) else {
    raise WgslIrValidationError::InvalidExpression(
      "constant access index is out of range or not indexable",
      base.index(),
    )
  }
}

///|
fn WgslIrValidator::require_global_access_index_signature(
  self : WgslIrValidator,
  base : Handle,
  index : Int,
) -> Unit raise WgslIrValidationError {
  guard self.global_expression_type(base) is Some(base_ty) else {
    raise self.missing_global_expression_type(base)
  }
  guard self.indexed_type(base_ty, Some(index)) is Some(_) else {
    raise WgslIrValidationError::InvalidExpression(
      "constant access index is out of range or not indexable",
      base.index(),
    )
  }
}

///|
fn WgslIrValidator::require_function_address_of_signature(
  self : WgslIrValidator,
  function : Function,
  ty : Handle,
  target : Handle,
) -> Unit raise WgslIrValidationError {
  guard self.expression_is_addressable(function, target) else {
    raise WgslIrValidationError::InvalidExpression(
      "address-of target is not addressable",
      target.index(),
    )
  }
  guard self.pointer_pointee_type(ty) is Some(pointee) else {
    raise WgslIrValidationError::InvalidExpression(
      "address-of result type is not pointer-like",
      target.index(),
    )
  }
  guard self.function_expression_value_type(function, target) is Some(target_ty) else {
    raise WgslIrValidationError::InvalidExpression(
      "address-of target has no value type",
      target.index(),
    )
  }
  if !self.type_assignable(pointee, target_ty) {
    raise WgslIrValidationError::InvalidExpression(
      "address-of result pointee type does not match target",
      target.index(),
    )
  }
}

///|
fn WgslIrValidator::require_global_address_of_signature(
  self : WgslIrValidator,
  ty : Handle,
  target : Handle,
) -> Unit raise WgslIrValidationError {
  guard self.global_expression_is_addressable(target) else {
    raise WgslIrValidationError::InvalidExpression(
      "address-of target is not addressable",
      target.index(),
    )
  }
  guard self.pointer_pointee_type(ty) is Some(pointee) else {
    raise WgslIrValidationError::InvalidExpression(
      "address-of result type is not pointer-like",
      target.index(),
    )
  }
  guard self.global_expression_value_type(target) is Some(target_ty) else {
    raise WgslIrValidationError::InvalidExpression(
      "address-of target has no value type",
      target.index(),
    )
  }
  if !self.type_assignable(pointee, target_ty) {
    raise WgslIrValidationError::InvalidExpression(
      "address-of result pointee type does not match target",
      target.index(),
    )
  }
}

///|
fn WgslIrValidator::require_as_width(
  self : WgslIrValidator,
  kind : ScalarKind,
  width : Int?,
) -> Unit raise WgslIrValidationError {
  ignore(self)
  match width {
    Some(value) =>
      if !wgsl_ir_validation_scalar_width_is_valid(kind, value) {
        raise WgslIrValidationError::InvalidType("invalid scalar cast width")
      }
    None => ()
  }
}

///|
fn WgslIrValidator::require_call_signature(
  self : WgslIrValidator,
  function : Function,
  callee : Handle,
  arguments : Array[Handle],
  result : Handle?,
) -> Unit raise WgslIrValidationError {
  let callee_function = match
    self.shader_module.functions.items.get(callee.index()) {
    Some(value) => value
    None => return
  }
  let name = self.function_display_name(callee_function)
  if arguments.length() != callee_function.arguments.length() {
    raise WgslIrValidationError::InvalidFunctionArgumentCount(
      name,
      callee_function.arguments.length(),
      arguments.length(),
    )
  }
  for index in 0..<arguments.length() {
    let argument = arguments[index]
    match self.function_expression_type(function, argument) {
      Some(actual) =>
        if !self.type_assignable(callee_function.arguments[index].ty, actual) {
          raise WgslIrValidationError::InvalidFunctionArgumentType(name, index)
        }
      None => ()
    }
  }
  match (callee_function.result, result) {
    (Some(expected), Some(actual_handle)) =>
      match self.function_expression_type(function, actual_handle) {
        Some(actual) =>
          if !self.type_assignable(expected.ty, actual) {
            raise WgslIrValidationError::InvalidFunctionResult(name)
          }
        None => ()
      }
    (None, None) => ()
    (Some(_), None) => ()
    (None, Some(_)) => raise WgslIrValidationError::InvalidFunctionResult(name)
  }
}

///|
fn WgslIrValidator::require_global_call_signature(
  self : WgslIrValidator,
  callee : Handle,
  arguments : Array[Handle],
) -> Unit raise WgslIrValidationError {
  let callee_function = match
    self.shader_module.functions.items.get(callee.index()) {
    Some(value) => value
    None => return
  }
  let name = self.function_display_name(callee_function)
  if arguments.length() != callee_function.arguments.length() {
    raise WgslIrValidationError::InvalidFunctionArgumentCount(
      name,
      callee_function.arguments.length(),
      arguments.length(),
    )
  }
  for index in 0..<arguments.length() {
    let argument = arguments[index]
    match self.global_expression_type(argument) {
      Some(actual) =>
        if !self.type_assignable(callee_function.arguments[index].ty, actual) {
          raise WgslIrValidationError::InvalidFunctionArgumentType(name, index)
        }
      None => ()
    }
  }
}

///|
fn WgslIrValidator::require_select_signature(
  self : WgslIrValidator,
  function : Function,
  condition : Handle,
  accept : Handle,
  reject : Handle,
) -> Unit raise WgslIrValidationError {
  guard self.function_expression_type(function, condition) is Some(cond_ty) else {
    raise self.missing_function_expression_type(function, condition)
  }
  guard self.function_expression_type(function, accept) is Some(accept_ty) else {
    raise self.missing_function_expression_type(function, accept)
  }
  guard self.function_expression_type(function, reject) is Some(reject_ty) else {
    raise self.missing_function_expression_type(function, reject)
  }
  guard self.types_are_select_compatible(accept_ty, reject_ty) else {
    raise WgslIrValidationError::InvalidFunctionArgumentType("select", 1)
  }
  guard self.select_condition_type_matches_result(cond_ty, accept_ty) else {
    raise self.invalid_condition_type(function, condition, cond_ty)
  }
}

///|
fn WgslIrValidator::require_global_select_signature(
  self : WgslIrValidator,
  condition : Handle,
  accept : Handle,
  reject : Handle,
) -> Unit raise WgslIrValidationError {
  guard self.global_expression_type(condition) is Some(cond_ty) else {
    raise self.missing_global_expression_type(condition)
  }
  guard self.global_expression_type(accept) is Some(accept_ty) else {
    raise self.missing_global_expression_type(accept)
  }
  guard self.global_expression_type(reject) is Some(reject_ty) else {
    raise self.missing_global_expression_type(reject)
  }
  guard self.types_are_select_compatible(accept_ty, reject_ty) else {
    raise WgslIrValidationError::InvalidFunctionArgumentType("select", 1)
  }
  guard self.select_condition_type_matches_result(cond_ty, accept_ty) else {
    let expression = match
      self.shader_module.global_expressions.items.get(condition.index()) {
      Some(value) => @debug.to_string(value)
      None => "<invalid global expression handle>"
    }
    let ty_text = match self.shader_module.types.items.get(cond_ty.index()) {
      Some(value) => @debug.to_string(value)
      None => "<invalid type handle>"
    }
    raise WgslIrValidationError::InvalidConditionType(
      "<global>",
      condition.index(),
      expression,
      ty_text,
    )
  }
}

///|
fn WgslIrValidator::require_image_store_signature(
  self : WgslIrValidator,
  function : Function,
  image : Handle,
  value : Handle,
) -> Unit raise WgslIrValidationError {
  guard self.function_expression_type(function, image) is Some(image_ty) else {
    raise self.missing_function_expression_type(function, image)
  }
  let scalar = match self.shader_module.types.get(image_ty) {
    Some(type_) =>
      match type_.inner {
        Image(_, _, Storage(format, access)) =>
          if access.contains(StorageAccess::store()) ||
            access.contains(StorageAccess::atomic_access()) {
            Some(wgsl_ir_validation_storage_format_scalar(format))
          } else {
            None
          }
        _ => None
      }
    None => None
  }
  guard scalar is Some(value_scalar) else {
    raise WgslIrValidationError::InvalidStatement(
      "imageStore target is not a writable storage texture",
    )
  }
  guard self.function_expression_type(function, value) is Some(actual) else {
    raise self.missing_function_expression_type(function, value)
  }
  guard self.vector_type(Quad, value_scalar) is Some(expected) else {
    raise WgslIrValidationError::InvalidStatement(
      "imageStore value has unsupported storage format",
    )
  }
  if !self.type_assignable(expected, actual) {
    raise WgslIrValidationError::InvalidStatement(
      "imageStore value type does not match storage texture format",
    )
  }
}

///|
fn WgslIrValidator::require_image_atomic_signature(
  self : WgslIrValidator,
  function : Function,
  image : Handle,
  atomic_function : AtomicFunction,
  value : Handle,
) -> Unit raise WgslIrValidationError {
  ignore(atomic_function)
  guard self.function_expression_type(function, image) is Some(image_ty) else {
    raise self.missing_function_expression_type(function, image)
  }
  let scalar = match self.shader_module.types.get(image_ty) {
    Some(type_) =>
      match type_.inner {
        Image(_, _, Storage(format, access)) =>
          if access.contains(StorageAccess::atomic_access()) {
            Some(wgsl_ir_validation_storage_format_scalar(format))
          } else {
            None
          }
        _ => None
      }
    None => None
  }
  guard scalar is Some(expected_scalar) else {
    raise WgslIrValidationError::InvalidStatement(
      "image atomic target is not an atomic storage texture",
    )
  }
  guard self.function_expression_type(function, value) is Some(actual) else {
    raise self.missing_function_expression_type(function, value)
  }
  guard self.find_scalar_type(expected_scalar) is Some(expected) else {
    raise WgslIrValidationError::InvalidStatement(
      "image atomic value has unsupported storage format",
    )
  }
  if !self.type_assignable(expected, actual) {
    raise WgslIrValidationError::InvalidStatement(
      "image atomic value type does not match storage texture format",
    )
  }
}

///|
fn WgslIrValidator::require_atomic_statement_signature(
  self : WgslIrValidator,
  function : Function,
  pointer : Handle,
  atomic_function : AtomicFunction,
  value : Handle,
  compare : Handle?,
) -> Unit raise WgslIrValidationError {
  guard self.function_expression_type(function, pointer) is Some(pointer_ty) else {
    raise self.missing_function_expression_type(function, pointer)
  }
  guard self.atomic_scalar_type(pointer_ty) is Some(scalar) else {
    raise WgslIrValidationError::InvalidStatement(
      "atomic statement target is not atomic",
    )
  }
  guard self.find_scalar_type(scalar) is Some(expected) else {
    raise WgslIrValidationError::InvalidStatement(
      "atomic statement scalar type is unavailable",
    )
  }
  guard self.function_expression_type(function, value) is Some(actual) else {
    raise self.missing_function_expression_type(function, value)
  }
  if !self.type_assignable(expected, actual) {
    raise WgslIrValidationError::InvalidStatement(
      "atomic statement value type mismatch",
    )
  }
  match (atomic_function, compare) {
    (CompareExchangeWeak, Some(compare_handle)) => {
      guard self.function_expression_type(function, compare_handle)
        is Some(compare_ty) else {
        raise self.missing_function_expression_type(function, compare_handle)
      }
      if !self.type_assignable(expected, compare_ty) {
        raise WgslIrValidationError::InvalidStatement(
          "atomic compare value type mismatch",
        )
      }
    }
    (CompareExchangeWeak, None) =>
      raise WgslIrValidationError::InvalidStatement(
        "atomic compare-exchange requires compare value",
      )
    (_, Some(_)) =>
      raise WgslIrValidationError::InvalidStatement(
        "atomic compare value is only valid for compare-exchange",
      )
    _ => ()
  }
}

///|
fn WgslIrValidator::require_atomic_call_signature(
  self : WgslIrValidator,
  function : Function,
  atomic_function : AtomicFunction,
  arguments : Array[Handle],
) -> Unit raise WgslIrValidationError {
  let expected_count = match atomic_function {
    Load => 1
    Store => 2
    CompareExchangeWeak => 3
    _ => 2
  }
  if arguments.length() != expected_count {
    raise WgslIrValidationError::InvalidFunctionArgumentCount(
      "atomic",
      expected_count,
      arguments.length(),
    )
  }
  guard arguments.get(0) is Some(pointer) else { return }
  guard self.function_expression_type(function, pointer) is Some(pointer_ty) else {
    raise self.missing_function_expression_type(function, pointer)
  }
  guard self.atomic_scalar_type(pointer_ty) is Some(scalar) else {
    raise WgslIrValidationError::InvalidFunctionArgumentType("atomic", 0)
  }
  guard self.find_scalar_type(scalar) is Some(expected) else { return }
  for index in 1..<arguments.length() {
    let argument = arguments[index]
    guard self.function_expression_type(function, argument) is Some(actual) else {
      raise self.missing_function_expression_type(function, argument)
    }
    if !self.type_assignable(expected, actual) {
      raise WgslIrValidationError::InvalidFunctionArgumentType("atomic", index)
    }
  }
}

///|
fn WgslIrValidator::require_workgroup_uniform_load_signature(
  self : WgslIrValidator,
  function : Function,
  pointer : Handle,
  result : Handle,
) -> Unit raise WgslIrValidationError {
  guard self.function_expression_type(function, pointer) is Some(pointer_ty) else {
    raise self.missing_function_expression_type(function, pointer)
  }
  if self.pointer_address_space(pointer_ty) != Some(AddressSpace::WorkGroup) {
    raise WgslIrValidationError::InvalidStatement(
      "workgroupUniformLoad pointer is not in workgroup address space",
    )
  }
  guard self.deref_type(pointer_ty) is Some(expected) else {
    raise WgslIrValidationError::InvalidStatement(
      "workgroupUniformLoad pointer has no value type",
    )
  }
  guard self.function_expression_type(function, result) is Some(actual) else {
    raise self.missing_function_expression_type(function, result)
  }
  if !self.type_assignable(expected, actual) {
    raise WgslIrValidationError::InvalidStatement(
      "workgroupUniformLoad result type mismatch",
    )
  }
}

///|
fn WgslIrValidator::require_subgroup_ballot_signature(
  self : WgslIrValidator,
  function : Function,
  value : Handle,
  result : Handle?,
) -> Unit raise WgslIrValidationError {
  guard self.function_expression_type(function, value) is Some(value_ty) else {
    raise self.missing_function_expression_type(function, value)
  }
  if !self.type_is_bool_scalar(value_ty) {
    raise WgslIrValidationError::InvalidStatement(
      "subgroupBallot value is not bool",
    )
  }
  match result {
    Some(handle) => {
      guard self.function_expression_type(function, handle) is Some(actual) else {
        raise self.missing_function_expression_type(function, handle)
      }
      guard self.vector_type(Quad, Scalar::Scalar(Uint, 4)) is Some(expected) else {
        return
      }
      if !self.type_assignable(expected, actual) {
        raise WgslIrValidationError::InvalidStatement(
          "subgroupBallot result type mismatch",
        )
      }
    }
    None => ()
  }
}

///|
fn WgslIrValidator::require_matching_statement_result(
  self : WgslIrValidator,
  function : Function,
  value : Handle,
  result : Handle,
) -> Unit raise WgslIrValidationError {
  guard self.function_expression_type(function, value) is Some(expected) else {
    raise self.missing_function_expression_type(function, value)
  }
  guard self.function_expression_type(function, result) is Some(actual) else {
    raise self.missing_function_expression_type(function, result)
  }
  if !self.type_assignable(expected, actual) {
    raise WgslIrValidationError::InvalidStatement(
      "statement result type mismatch",
    )
  }
}

///|
fn WgslIrValidator::require_array_length_argument(
  self : WgslIrValidator,
  function : Function,
  handle : Handle,
) -> Unit raise WgslIrValidationError {
  guard self.function_expression_type(function, handle) is Some(ty) else {
    raise self.missing_function_expression_type(function, handle)
  }
  if !self.pointer_targets_runtime_array(ty) &&
    !self.type_or_struct_tail_is_runtime_array(ty) {
    raise WgslIrValidationError::InvalidExpression(
      "arrayLength argument does not point at a runtime array",
      handle.index(),
    )
  }
}

///|
fn WgslIrValidator::require_swizzle_signature(
  self : WgslIrValidator,
  function : Function,
  size : VectorSize,
  expr : Handle,
  components : Array[SwizzleComponent],
) -> Unit raise WgslIrValidationError {
  if components.length() != size.width() {
    raise WgslIrValidationError::InvalidExpression(
      "swizzle component count does not match result size",
      expr.index(),
    )
  }
  guard self.function_expression_type(function, expr) is Some(ty) else {
    return
  }
  guard self.vector_size(ty) is Some(base_size) else {
    raise WgslIrValidationError::InvalidExpression(
      "swizzle base is not a vector",
      expr.index(),
    )
  }
  for component in components {
    if wgsl_ir_validation_swizzle_index(component) >= base_size.width() {
      raise WgslIrValidationError::InvalidExpression(
        "swizzle component is out of range",
        expr.index(),
      )
    }
  }
}
