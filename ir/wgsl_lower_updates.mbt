///|
fn WgslIrLowerer::lower_update_statement(
  self : WgslIrLowerer,
  target : @ast.WgslExprRef?,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
  increment : Bool,
) -> Unit raise WgslIrLowerError {
  guard target is Some(target_ref) else {
    raise UnsupportedStatement("update without target")
  }
  let pointer = self.lower_function_lvalue_ref(target_ref, function, scope)
  self.lower_update_handle(pointer, function, scope, block, increment)
}

///|
fn WgslIrLowerer::lower_update_handle(
  self : WgslIrLowerer,
  pointer : Handle,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
  increment : Bool,
) -> Unit raise WgslIrLowerError {
  let one = function.expressions.append(
    Literal(self.update_unit_literal(function, pointer)),
  )
  let loaded = function.expressions.append(Load(pointer))
  let loaded = self.materialize_function_expression(
    function, scope, block, loaded,
  )
  let op = if increment { BinaryOperator::Add } else { Subtract }
  let value = function.expressions.append(Binary(op, loaded, one))
  block.push(Store(pointer, value))
}

///|
fn WgslIrLowerer::update_unit_literal(
  self : WgslIrLowerer,
  function : Function,
  pointer : Handle,
) -> Literal {
  guard self.function_expression_type(function, pointer) is Some(pointer_ty) else {
    return I32(1)
  }
  let value_ty = self.deref_pointer_type_handle(pointer_ty)
  match self.shader_module.types.get(value_ty) {
    Some(ty) =>
      match ty.inner {
        Scalar(scalar) =>
          match scalar.kind {
            Uint => U32(1)
            Sint => I32(1)
            AbstractInt => AbstractInt(1)
            _ => I32(1)
          }
        _ => I32(1)
      }
    None => I32(1)
  }
}
