///|
fn wgsl_ir_switch_value_from_expression(
  lowerer : WgslIrLowerer,
  function : Function,
  selector : Handle,
  handle : Handle,
) -> SwitchValue raise WgslIrLowerError {
  let selector_is_unsigned = lowerer.switch_selector_is_unsigned(
    function, selector,
  )
  lowerer
  .eval_function_integer_expression(function, handle)
  .to_switch_value(selector_is_unsigned)
}

///|
fn WgslIrLowerer::switch_selector_is_unsigned(
  self : WgslIrLowerer,
  function : Function,
  selector : Handle,
) -> Bool {
  match self.function_expression_type(function, selector) {
    Some(ty_handle) =>
      match self.shader_module.types.get(ty_handle) {
        Some(ty) =>
          match ty.inner {
            Scalar(scalar) => scalar.kind == Uint
            _ => false
          }
        None => false
      }
    None => false
  }
}

///|
fn WgslIrLowerer::eval_global_integer_expression(
  self : WgslIrLowerer,
  handle : Handle,
) -> WgslIrIntegerValue raise WgslIrLowerError {
  match self.shader_module.global_expressions.items.get(handle.index()) {
    Some(expression) => self.eval_global_integer_expression_inner(expression)
    None =>
      raise WgslIrLowerError::UnsupportedExpression(
        "switch case selector references missing expression",
      )
  }
}

///|
fn WgslIrLowerer::lower_function_constant_array_size_expression(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle,
) -> ArraySize raise WgslIrLowerError {
  let evaluated = Some(self.eval_function_integer_expression(function, handle)) catch {
    _ => None
  }
  match evaluated {
    Some(value) => ArraySize::Constant(value.to_non_negative_int())
    None =>
      raise WgslIrLowerError::UnsupportedType(
        "local array size must resolve to an integer const expression",
      )
  }
}

///|
fn WgslIrLowerer::eval_function_integer_expression(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle,
) -> WgslIrIntegerValue raise WgslIrLowerError {
  match function.expressions.items.get(handle.index()) {
    Some(expression) =>
      self.eval_function_integer_expression_inner(function, expression)
    None =>
      raise WgslIrLowerError::UnsupportedExpression(
        "array size references missing expression",
      )
  }
}

///|
fn WgslIrLowerer::eval_function_integer_expression_inner(
  self : WgslIrLowerer,
  function : Function,
  expression : Expression,
) -> WgslIrIntegerValue raise WgslIrLowerError {
  match expression {
    Literal(Literal::I32(value)) => WgslIrIntegerValue::Signed(value)
    Literal(Literal::U32(value)) => WgslIrIntegerValue::Unsigned(value)
    Literal(Literal::AbstractInt(value)) => WgslIrIntegerValue::Abstract(value)
    Constant(handle) =>
      match self.shader_module.constants.items.get(handle.index()) {
        Some(constant) => self.eval_global_integer_expression(constant.init)
        None =>
          raise WgslIrLowerError::UnsupportedExpression(
            "array size references missing nested const",
          )
      }
    Binary(op, left, right) => {
      let left_value = self.eval_function_integer_expression(function, left)
      let right_value = self.eval_function_integer_expression(function, right)
      wgsl_ir_eval_integer_binary(op, left_value, right_value)
    }
    Unary(UnaryOperator::Negate, inner) => {
      let value = self
        .eval_function_integer_expression(function, inner)
        .to_signed_int()
      WgslIrIntegerValue::Signed(-value)
    }
    Unary(UnaryOperator::BitwiseNot, inner) =>
      match self.eval_function_integer_expression(function, inner) {
        Unsigned(value) => WgslIrIntegerValue::Unsigned(value.lnot())
        Signed(value) => WgslIrIntegerValue::Signed(value.lnot())
        Abstract(value) => WgslIrIntegerValue::Abstract(value.lnot())
      }
    _ =>
      raise WgslIrLowerError::UnsupportedExpression(
        "array size must initialize to an integer expression",
      )
  }
}

///|
fn WgslIrLowerer::eval_global_integer_expression_inner(
  self : WgslIrLowerer,
  expression : Expression,
) -> WgslIrIntegerValue raise WgslIrLowerError {
  match expression {
    Literal(Literal::I32(value)) => WgslIrIntegerValue::Signed(value)
    Literal(Literal::U32(value)) => WgslIrIntegerValue::Unsigned(value)
    Literal(Literal::AbstractInt(value)) => WgslIrIntegerValue::Abstract(value)
    Constant(handle) =>
      match self.shader_module.constants.items.get(handle.index()) {
        Some(constant) => self.eval_global_integer_expression(constant.init)
        None =>
          raise WgslIrLowerError::UnsupportedExpression(
            "switch case selector references missing nested const",
          )
      }
    Binary(op, left, right) => {
      let left_value = self.eval_global_integer_expression(left)
      let right_value = self.eval_global_integer_expression(right)
      wgsl_ir_eval_integer_binary(op, left_value, right_value)
    }
    Math(MathFunction::Min, a, Some(b), None, None) =>
      wgsl_ir_eval_integer_min(
        self.eval_global_integer_expression(a),
        self.eval_global_integer_expression(b),
      )
    Math(MathFunction::Max, a, Some(b), None, None) =>
      wgsl_ir_eval_integer_max(
        self.eval_global_integer_expression(a),
        self.eval_global_integer_expression(b),
      )
    Math(MathFunction::Clamp, value, Some(low), Some(high), None) =>
      wgsl_ir_eval_integer_clamp(
        self.eval_global_integer_expression(value),
        self.eval_global_integer_expression(low),
        self.eval_global_integer_expression(high),
      )
    Unary(UnaryOperator::Negate, inner) => {
      let value = self.eval_global_integer_expression(inner).to_signed_int()
      WgslIrIntegerValue::Signed(-value)
    }
    Unary(UnaryOperator::BitwiseNot, inner) =>
      match self.eval_global_integer_expression(inner) {
        Unsigned(value) => WgslIrIntegerValue::Unsigned(value.lnot())
        Signed(value) => WgslIrIntegerValue::Signed(value.lnot())
        Abstract(value) => WgslIrIntegerValue::Abstract(value.lnot())
      }
    _ =>
      raise WgslIrLowerError::UnsupportedExpression(
        "switch case const selector must initialize to an integer expression",
      )
  }
}

///|
priv enum WgslIrIntegerValue {
  Signed(Int)
  Unsigned(UInt)
  Abstract(Int64)
}

///|
fn WgslIrIntegerValue::is_unsigned(self : WgslIrIntegerValue) -> Bool {
  match self {
    Unsigned(_) => true
    Signed(_) | Abstract(_) => false
  }
}

///|
fn WgslIrIntegerValue::to_switch_value(
  self : WgslIrIntegerValue,
  selector_is_unsigned : Bool,
) -> SwitchValue raise WgslIrLowerError {
  if selector_is_unsigned {
    SwitchValue::U32(self.to_unsigned())
  } else {
    match self {
      Unsigned(value) =>
        SwitchValue::I32(WgslIrIntegerValue::Unsigned(value).to_signed_int())
      Signed(value) => SwitchValue::I32(value)
      Abstract(value) => SwitchValue::I32(wgsl_ir_int64_to_i32(value))
    }
  }
}

///|
fn WgslIrIntegerValue::to_signed_int(
  self : WgslIrIntegerValue,
) -> Int raise WgslIrLowerError {
  match self {
    Signed(value) => value
    Abstract(value) => wgsl_ir_int64_to_i32(value)
    Unsigned(value) =>
      match wgsl_ir_uint_literal_to_small_int(value) {
        Some(value) => value
        None =>
          raise WgslIrLowerError::UnsupportedExpression(
            "integer expression is outside signed int range",
          )
      }
  }
}

///|
fn WgslIrIntegerValue::to_unsigned(
  self : WgslIrIntegerValue,
) -> UInt raise WgslIrLowerError {
  match self {
    Unsigned(value) => value
    Signed(value) => wgsl_ir_non_negative_int_to_uint(value)
    Abstract(value) => {
      if value < Int64::from_int(0) {
        raise WgslIrLowerError::UnsupportedExpression(
          "unsigned integer expression contains a negative operand",
        )
      }
      if value > 4294967295L {
        raise WgslIrLowerError::UnsupportedExpression(
          "integer expression is outside unsigned int range",
        )
      }
      value.reinterpret_as_uint64().to_uint()
    }
  }
}

///|
fn wgsl_ir_non_negative_int_to_uint(value : Int) -> UInt raise WgslIrLowerError {
  if value < 0 {
    raise WgslIrLowerError::UnsupportedExpression(
      "unsigned integer expression contains a negative operand",
    )
  }
  value.reinterpret_as_uint()
}

///|
fn WgslIrIntegerValue::to_non_negative_int(
  self : WgslIrIntegerValue,
) -> Int raise WgslIrLowerError {
  let value = self.to_signed_int()
  if value < 0 {
    raise WgslIrLowerError::UnsupportedExpression(
      "integer expression must be non-negative",
    )
  }
  value
}

///|
fn wgsl_ir_eval_integer_binary(
  op : BinaryOperator,
  left : WgslIrIntegerValue,
  right : WgslIrIntegerValue,
) -> WgslIrIntegerValue raise WgslIrLowerError {
  if left.is_unsigned() || right.is_unsigned() {
    let left = left.to_unsigned()
    let right_value = right.to_unsigned()
    let right_shift = WgslIrIntegerValue::Unsigned(right_value).to_non_negative_int()
    return match op {
      Add => Unsigned(left + right_value)
      Subtract => Unsigned(left - right_value)
      Multiply => Unsigned(left * right_value)
      Divide => Unsigned(left / right_value)
      Modulo => Unsigned(left % right_value)
      And => Unsigned(left & right_value)
      ExclusiveOr => Unsigned(left ^ right_value)
      InclusiveOr => Unsigned(left | right_value)
      ShiftLeft => Unsigned(left << right_shift)
      ShiftRight => Unsigned(left >> right_shift)
      _ =>
        raise WgslIrLowerError::UnsupportedExpression(
          "switch case const selector uses non-integer binary operator",
        )
    }
  }
  let left = left.to_signed_int()
  let right = right.to_signed_int()
  match op {
    Add => Signed(left + right)
    Subtract => Signed(left - right)
    Multiply => Signed(left * right)
    Divide => Signed(left / right)
    Modulo => Signed(left % right)
    And => Signed(left & right)
    ExclusiveOr => Signed(left ^ right)
    InclusiveOr => Signed(left | right)
    ShiftLeft => Signed(left << right)
    ShiftRight => Signed(left >> right)
    _ =>
      raise WgslIrLowerError::UnsupportedExpression(
        "switch case const selector uses non-integer binary operator",
      )
  }
}

///|
fn wgsl_ir_eval_integer_min(
  left : WgslIrIntegerValue,
  right : WgslIrIntegerValue,
) -> WgslIrIntegerValue raise WgslIrLowerError {
  if left.is_unsigned() || right.is_unsigned() {
    let left = left.to_unsigned()
    let right = right.to_unsigned()
    Unsigned(if left < right { left } else { right })
  } else {
    let left = left.to_signed_int()
    let right = right.to_signed_int()
    Signed(if left < right { left } else { right })
  }
}

///|
fn wgsl_ir_eval_integer_max(
  left : WgslIrIntegerValue,
  right : WgslIrIntegerValue,
) -> WgslIrIntegerValue raise WgslIrLowerError {
  if left.is_unsigned() || right.is_unsigned() {
    let left = left.to_unsigned()
    let right = right.to_unsigned()
    Unsigned(if left > right { left } else { right })
  } else {
    let left = left.to_signed_int()
    let right = right.to_signed_int()
    Signed(if left > right { left } else { right })
  }
}

///|
fn wgsl_ir_eval_integer_clamp(
  value : WgslIrIntegerValue,
  low : WgslIrIntegerValue,
  high : WgslIrIntegerValue,
) -> WgslIrIntegerValue raise WgslIrLowerError {
  wgsl_ir_eval_integer_min(wgsl_ir_eval_integer_max(value, low), high)
}

///|
fn WgslIrLowerer::fold_function_constant_float_expression(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle,
) -> Literal? {
  match self.eval_function_float_expression(function, handle) {
    Some(value) => Some(Literal::AbstractFloat(value))
    None => None
  }
}

///|
fn WgslIrLowerer::normalized_local_constant_initializer(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle,
) -> Handle {
  match function.expressions.items.get(handle.index()) {
    Some(Expression::Literal(_)) => return handle
    _ => ()
  }
  match self.fold_function_constant_float_expression(function, handle) {
    Some(literal) =>
      function.expressions.append_with_origin(
        Expression::Literal(literal),
        FoldedLocalConstant,
      )
    None => handle
  }
}

///|
fn WgslIrLowerer::eval_function_float_expression(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle,
) -> Double? {
  match function.expressions.items.get(handle.index()) {
    Some(expression) =>
      self.eval_function_float_expression_inner(function, expression)
    None => None
  }
}

///|
fn WgslIrLowerer::eval_function_float_expression_inner(
  self : WgslIrLowerer,
  function : Function,
  expression : Expression,
) -> Double? {
  match expression {
    Literal(Literal::AbstractFloat(value)) => Some(value)
    Constant(handle) => self.eval_constant_float_expression(handle)
    Binary(op, left, right) => {
      guard self.eval_function_float_expression(function, left)
        is Some(left_value) else {
        return None
      }
      guard self.eval_function_float_expression(function, right)
        is Some(right_value) else {
        return None
      }
      wgsl_ir_eval_float_binary(op, left_value, right_value)
    }
    _ => None
  }
}

///|
fn WgslIrLowerer::eval_constant_float_expression(
  self : WgslIrLowerer,
  handle : Handle,
) -> Double? {
  match self.shader_module.constants.items.get(handle.index()) {
    Some(constant) => self.eval_global_float_expression(constant.init)
    None => None
  }
}

///|
fn WgslIrLowerer::eval_global_float_expression(
  self : WgslIrLowerer,
  handle : Handle,
) -> Double? {
  match self.shader_module.global_expressions.items.get(handle.index()) {
    Some(expression) => self.eval_global_float_expression_inner(expression)
    None => None
  }
}

///|
fn WgslIrLowerer::eval_global_float_expression_inner(
  self : WgslIrLowerer,
  expression : Expression,
) -> Double? {
  match expression {
    Literal(Literal::AbstractFloat(value)) => Some(value)
    Constant(handle) => self.eval_constant_float_expression(handle)
    Binary(op, left, right) => {
      guard self.eval_global_float_expression(left) is Some(left_value) else {
        return None
      }
      guard self.eval_global_float_expression(right) is Some(right_value) else {
        return None
      }
      wgsl_ir_eval_float_binary(op, left_value, right_value)
    }
    _ => None
  }
}

///|
fn wgsl_ir_eval_float_binary(
  op : BinaryOperator,
  left : Double,
  right : Double,
) -> Double? {
  match op {
    Add => Some(left + right)
    Subtract => Some(left - right)
    Multiply => Some(left * right)
    Divide => Some(left / right)
    _ => None
  }
}
