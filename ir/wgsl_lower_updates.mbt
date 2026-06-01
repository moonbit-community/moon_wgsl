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
    raise WgslIrLowerError::UnsupportedStatement("update without target")
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
    Expression::Literal(self.update_unit_literal(function, pointer)),
  )
  let loaded = function.expressions.append(Expression::Load(pointer))
  let loaded = self.materialize_function_expression(
    function, scope, block, loaded,
  )
  let op = if increment {
    BinaryOperator::Add
  } else {
    BinaryOperator::Subtract
  }
  let value = function.expressions.append(Expression::Binary(op, loaded, one))
  block.push(Statement::Store(pointer, value))
}

///|
fn WgslIrLowerer::update_unit_literal(
  self : WgslIrLowerer,
  function : Function,
  pointer : Handle,
) -> Literal {
  guard self.function_expression_type(function, pointer) is Some(pointer_ty) else {
    return Literal::I32(1)
  }
  let value_ty = self.deref_pointer_type_handle(pointer_ty)
  match self.shader_module.types.get(value_ty) {
    Some(ty) =>
      match ty.inner {
        Scalar(scalar) =>
          match scalar.kind {
            Uint => Literal::U32(1)
            Sint => Literal::I32(1)
            AbstractInt => Literal::AbstractInt(1)
            _ => Literal::I32(1)
          }
        _ => Literal::I32(1)
      }
    None => Literal::I32(1)
  }
}
