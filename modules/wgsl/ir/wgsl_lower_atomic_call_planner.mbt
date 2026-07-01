///|
fn WgslIrLowerer::lower_function_atomic_call(
  self : WgslIrLowerer,
  atomic_function : AtomicFunction,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  let expected = match atomic_function {
    Load => 1
    Store => 2
    Add | Subtract | And | ExclusiveOr | InclusiveOr | Min | Max | Exchange => 2
    CompareExchangeWeak => 3
  }
  if arguments.length() != expected {
    raise UnsupportedExpression(
      "\{wgsl_ir_atomic_function_name(atomic_function)} expects \{expected} arguments",
    )
  }
  if atomic_function == Load {
    guard arguments is [pointer_argument] else {
      raise UnsupportedExpression("atomicLoad expects 1 argument")
    }
    return function.expressions.append(
      Load(
        self.lower_atomic_pointer_argument(pointer_argument, function, scope),
      ),
    )
  }
  let handles : Array[Handle] = []
  for index in 0..<arguments.length() {
    let argument = arguments[index]
    if index == 0 {
      handles.push(
        self.lower_atomic_pointer_argument(argument, function, scope),
      )
    } else {
      handles.push(
        self.lower_function_expression_node(argument, function, scope),
      )
    }
  }
  if atomic_function == CompareExchangeWeak {
    match self.atomic_call_result_scalar_type(function, handles) {
      Some(scalar) =>
        ignore(
          self.predeclared_struct_type(AtomicCompareExchangeWeakResult(scalar)),
        )
      None => ()
    }
  }
  function.expressions.append(AtomicCall(atomic_function, handles))
}

///|
fn WgslIrLowerer::atomic_call_result_scalar_type(
  self : WgslIrLowerer,
  function : Function,
  arguments : Array[Handle],
) -> Scalar? {
  guard arguments is [pointer, .. rest] else { return None }
  match self.atomic_pointer_scalar_type(function, pointer) {
    Some(scalar) => Some(scalar)
    None =>
      match rest {
        [value, ..] =>
          match self.function_expression_type(function, value) {
            Some(ty) => self.scalar_from_numeric_type_handle(ty)
            None => None
          }
        [] => None
      }
  }
}

///|
fn WgslIrLowerer::lower_atomic_pointer_argument(
  self : WgslIrLowerer,
  argument : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  match wgsl_ir_address_of_operand_node(argument) {
    Some(target) => self.lower_function_lvalue_node(target, function, scope)
    None => self.lower_function_expression_node(argument, function, scope)
  }
}
