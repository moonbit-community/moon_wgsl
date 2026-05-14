///|
priv enum WgslIrEmitIntegerValue {
  Signed(Int)
  Unsigned(UInt)
  Abstract(Int64)
}

///|
fn WgslIrEmitter::folded_constant_expression(
  self : WgslIrEmitter,
  constant : Constant,
) -> String? {
  if !self.options.fold_integer_constant_expressions {
    return None
  }
  guard self.constant_type_integer_kind(constant) is Some(kind) else {
    return None
  }
  match
    self.eval_global_integer_expression_for_emit(constant.init, @set.Set([])) {
    Some(value) => self.integer_value_literal_for_kind(value, kind)
    None => None
  }
}

///|
fn WgslIrEmitter::constant_type_integer_kind(
  self : WgslIrEmitter,
  constant : Constant,
) -> ScalarKind? {
  match self.shader_module.types.items.get(constant.ty.index()) {
    Some(ty) =>
      match ty.inner {
        Scalar(scalar) =>
          match scalar.kind {
            Sint | Uint | AbstractInt => Some(scalar.kind)
            _ => None
          }
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrEmitter::integer_value_literal_for_kind(
  self : WgslIrEmitter,
  value : WgslIrEmitIntegerValue,
  kind : ScalarKind,
) -> String? {
  ignore(self)
  match kind {
    Uint =>
      match value.to_unsigned() {
        Some(value) => Some("\{value}u")
        None => None
      }
    Sint =>
      match value.to_signed_int() {
        Some(value) => Some("\{value}i")
        None => None
      }
    AbstractInt =>
      match value {
        Abstract(value) => Some("\{value}")
        Signed(value) => Some("\{value}")
        Unsigned(value) => Some("\{value}")
      }
    _ => None
  }
}

///|
fn WgslIrEmitter::eval_global_integer_expression_for_emit(
  self : WgslIrEmitter,
  handle : Handle,
  visiting_constants : @set.Set[Int],
) -> WgslIrEmitIntegerValue? {
  match self.shader_module.global_expressions.items.get(handle.index()) {
    Some(expression) =>
      self.eval_global_integer_expression_inner_for_emit(
        expression, visiting_constants,
      )
    None => None
  }
}

///|
fn WgslIrEmitter::eval_global_integer_expression_inner_for_emit(
  self : WgslIrEmitter,
  expression : Expression,
  visiting_constants : @set.Set[Int],
) -> WgslIrEmitIntegerValue? {
  match expression {
    Literal(Literal::I32(value)) => Some(Signed(value))
    Literal(Literal::U32(value)) => Some(Unsigned(value))
    Literal(Literal::AbstractInt(value)) => Some(Abstract(value))
    Constant(handle) =>
      self.eval_constant_integer_expression_for_emit(handle, visiting_constants)
    Unary(UnaryOperator::Negate, inner) => {
      guard self.eval_global_integer_expression_for_emit(
          inner, visiting_constants,
        )
        is Some(value) else {
        return None
      }
      match value.to_signed_int() {
        Some(value) => Some(Signed(-value))
        None => None
      }
    }
    Unary(UnaryOperator::BitwiseNot, inner) =>
      match
        self.eval_global_integer_expression_for_emit(inner, visiting_constants) {
        Some(Unsigned(value)) => Some(Unsigned(value.lnot()))
        Some(Signed(value)) => Some(Signed(value.lnot()))
        Some(Abstract(value)) => Some(Abstract(value.lnot()))
        None => None
      }
    Binary(op, left, right) => {
      guard self.eval_global_integer_expression_for_emit(
          left, visiting_constants,
        )
        is Some(left_value) else {
        return None
      }
      guard self.eval_global_integer_expression_for_emit(
          right, visiting_constants,
        )
        is Some(right_value) else {
        return None
      }
      wgsl_ir_emit_eval_integer_binary(op, left_value, right_value)
    }
    Math(MathFunction::Min, a, Some(b), None, None) => {
      guard self.eval_global_integer_expression_for_emit(a, visiting_constants)
        is Some(a_value) else {
        return None
      }
      guard self.eval_global_integer_expression_for_emit(b, visiting_constants)
        is Some(b_value) else {
        return None
      }
      wgsl_ir_emit_eval_integer_min(a_value, b_value)
    }
    Math(MathFunction::Max, a, Some(b), None, None) => {
      guard self.eval_global_integer_expression_for_emit(a, visiting_constants)
        is Some(a_value) else {
        return None
      }
      guard self.eval_global_integer_expression_for_emit(b, visiting_constants)
        is Some(b_value) else {
        return None
      }
      wgsl_ir_emit_eval_integer_max(a_value, b_value)
    }
    Math(MathFunction::Clamp, value, Some(low), Some(high), None) => {
      guard self.eval_global_integer_expression_for_emit(
          value, visiting_constants,
        )
        is Some(value) else {
        return None
      }
      guard self.eval_global_integer_expression_for_emit(
          low, visiting_constants,
        )
        is Some(low) else {
        return None
      }
      guard self.eval_global_integer_expression_for_emit(
          high, visiting_constants,
        )
        is Some(high) else {
        return None
      }
      match wgsl_ir_emit_eval_integer_max(value, low) {
        Some(value) => wgsl_ir_emit_eval_integer_min(value, high)
        None => None
      }
    }
    _ => None
  }
}

///|
fn WgslIrEmitter::eval_constant_integer_expression_for_emit(
  self : WgslIrEmitter,
  handle : Handle,
  visiting_constants : @set.Set[Int],
) -> WgslIrEmitIntegerValue? {
  if visiting_constants.contains(handle.index()) {
    return None
  }
  match self.shader_module.constants.items.get(handle.index()) {
    Some(constant) => {
      visiting_constants.add(handle.index())
      let result = self.eval_global_integer_expression_for_emit(
        constant.init,
        visiting_constants,
      )
      ignore(visiting_constants.remove(handle.index()))
      result
    }
    None => None
  }
}

///|
fn WgslIrEmitIntegerValue::is_unsigned(self : WgslIrEmitIntegerValue) -> Bool {
  match self {
    Unsigned(_) => true
    Signed(_) | Abstract(_) => false
  }
}

///|
fn WgslIrEmitIntegerValue::to_signed_int(self : WgslIrEmitIntegerValue) -> Int? {
  match self {
    Signed(value) => Some(value)
    Abstract(value) =>
      if value >= Int64::from_int(-2147483648) &&
        value <= Int64::from_int(2147483647) {
        let parsed : Int = @strconv.from_str("\{value}") catch {
          _ => return None
        }
        Some(parsed)
      } else {
        None
      }
    Unsigned(value) => wgsl_ir_uint_literal_to_small_int(value)
  }
}

///|
fn WgslIrEmitIntegerValue::to_unsigned(self : WgslIrEmitIntegerValue) -> UInt? {
  match self {
    Unsigned(value) => Some(value)
    Signed(value) => wgsl_ir_emit_non_negative_int_to_uint(value)
    Abstract(value) => wgsl_ir_emit_non_negative_int64_to_uint(value)
  }
}

///|
fn wgsl_ir_emit_non_negative_int_to_uint(value : Int) -> UInt? {
  if value < 0 {
    return None
  }
  let parsed : UInt = @strconv.from_str("\{value}") catch { _ => return None }
  Some(parsed)
}

///|
fn wgsl_ir_emit_non_negative_int64_to_uint(value : Int64) -> UInt? {
  if value < Int64::from_int(0) {
    return None
  }
  let max : Int64 = @strconv.from_str("4294967295") catch { _ => return None }
  if value > max {
    return None
  }
  let parsed : UInt = @strconv.from_str("\{value}") catch { _ => return None }
  Some(parsed)
}

///|
fn wgsl_ir_emit_eval_integer_binary(
  op : BinaryOperator,
  left : WgslIrEmitIntegerValue,
  right : WgslIrEmitIntegerValue,
) -> WgslIrEmitIntegerValue? {
  if left.is_unsigned() || right.is_unsigned() {
    guard left.to_unsigned() is Some(left) else { return None }
    guard right.to_unsigned() is Some(right) else { return None }
    guard WgslIrEmitIntegerValue::Unsigned(right).to_signed_int()
      is Some(right_shift) else {
      return None
    }
    return match op {
      Add => Some(Unsigned(left + right))
      Subtract => Some(Unsigned(left - right))
      Multiply => Some(Unsigned(left * right))
      Divide => Some(Unsigned(left / right))
      Modulo => Some(Unsigned(left % right))
      And => Some(Unsigned(left & right))
      ExclusiveOr => Some(Unsigned(left ^ right))
      InclusiveOr => Some(Unsigned(left | right))
      ShiftLeft => Some(Unsigned(left << right_shift))
      ShiftRight => Some(Unsigned(left >> right_shift))
      _ => None
    }
  }
  guard left.to_signed_int() is Some(left) else { return None }
  guard right.to_signed_int() is Some(right) else { return None }
  match op {
    Add => Some(Signed(left + right))
    Subtract => Some(Signed(left - right))
    Multiply => Some(Signed(left * right))
    Divide => Some(Signed(left / right))
    Modulo => Some(Signed(left % right))
    And => Some(Signed(left & right))
    ExclusiveOr => Some(Signed(left ^ right))
    InclusiveOr => Some(Signed(left | right))
    ShiftLeft => Some(Signed(left << right))
    ShiftRight => Some(Signed(left >> right))
    _ => None
  }
}

///|
fn wgsl_ir_emit_eval_integer_min(
  left : WgslIrEmitIntegerValue,
  right : WgslIrEmitIntegerValue,
) -> WgslIrEmitIntegerValue? {
  if left.is_unsigned() || right.is_unsigned() {
    guard left.to_unsigned() is Some(left) else { return None }
    guard right.to_unsigned() is Some(right) else { return None }
    Some(Unsigned(if left < right { left } else { right }))
  } else {
    guard left.to_signed_int() is Some(left) else { return None }
    guard right.to_signed_int() is Some(right) else { return None }
    Some(Signed(if left < right { left } else { right }))
  }
}

///|
fn wgsl_ir_emit_eval_integer_max(
  left : WgslIrEmitIntegerValue,
  right : WgslIrEmitIntegerValue,
) -> WgslIrEmitIntegerValue? {
  if left.is_unsigned() || right.is_unsigned() {
    guard left.to_unsigned() is Some(left) else { return None }
    guard right.to_unsigned() is Some(right) else { return None }
    Some(Unsigned(if left > right { left } else { right }))
  } else {
    guard left.to_signed_int() is Some(left) else { return None }
    guard right.to_signed_int() is Some(right) else { return None }
    Some(Signed(if left > right { left } else { right }))
  }
}
