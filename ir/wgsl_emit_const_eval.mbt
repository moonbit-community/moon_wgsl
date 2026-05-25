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
  if !self.options.fold_numeric_constant_expressions() {
    return None
  }
  match self.constant_type_integer_kind(constant) {
    Some(kind) =>
      match
        self.eval_global_integer_expression_for_emit(
          constant.init,
          @set.Set([]),
        ) {
        Some(value) => return self.integer_value_literal_for_kind(value, kind)
        None => ()
      }
    None => ()
  }
  match self.constant_type_float_width(constant) {
    Some(width) =>
      match
        self.eval_global_float_expression_for_emit(constant.init, @set.Set([])) {
        Some(value) => self.float_value_literal_for_width(value, width)
        None => None
      }
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
fn WgslIrEmitter::constant_type_float_width(
  self : WgslIrEmitter,
  constant : Constant,
) -> Int? {
  match self.shader_module.types.items.get(constant.ty.index()) {
    Some(ty) =>
      match ty.inner {
        Scalar(scalar) =>
          match scalar.kind {
            Float | AbstractFloat => Some(scalar.width)
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
  let numeric_policy = self.options.numeric_literal_policy()
  match kind {
    Uint =>
      match value.to_unsigned() {
        Some(value) =>
          Some(wgsl_ir_emit_unsigned_literal(value, numeric_policy))
        None => None
      }
    Sint =>
      match value.to_signed_int() {
        Some(value) => Some(wgsl_ir_emit_signed_literal(value, numeric_policy))
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
fn WgslIrEmitter::float_value_literal_for_width(
  self : WgslIrEmitter,
  value : Double,
  width : Int,
) -> String? {
  let numeric_policy = self.options.numeric_literal_policy()
  match width {
    2 => Some(wgsl_ir_emit_f16_literal_text("\{value}"))
    4 => Some(self.f32_literal(Float::from_double(value), numeric_policy))
    8 => Some(wgsl_ir_emit_abstract_float_literal_text("\{value}"))
    _ => None
  }
}

///|
fn wgsl_ir_emit_unsigned_literal(
  value : UInt,
  policy : WgslIrNumericLiteralBytePolicy,
) -> String {
  match policy {
    NagaCompatibleNumericLiteralSpelling | RuntimeNumericLiteralSpelling =>
      "\{value}u"
  }
}

///|
fn wgsl_ir_emit_signed_literal(
  value : Int,
  policy : WgslIrNumericLiteralBytePolicy,
) -> String {
  match policy {
    NagaCompatibleNumericLiteralSpelling | RuntimeNumericLiteralSpelling =>
      "\{value}i"
  }
}

///|
fn WgslIrEmitter::eval_global_float_expression_for_emit(
  self : WgslIrEmitter,
  handle : Handle,
  visiting_constants : @set.Set[Int],
) -> Double? {
  match self.shader_module.global_expressions.items.get(handle.index()) {
    Some(expression) =>
      self.eval_global_float_expression_inner_for_emit(
        expression, visiting_constants,
      )
    None => None
  }
}

///|
fn WgslIrEmitter::eval_global_float_expression_inner_for_emit(
  self : WgslIrEmitter,
  expression : Expression,
  visiting_constants : @set.Set[Int],
) -> Double? {
  match expression {
    Literal(Literal::F32(value)) => wgsl_ir_emit_f32_to_double(value)
    Literal(Literal::F16(value))
    | Literal(Literal::F64(value))
    | Literal(Literal::AbstractFloat(value)) => Some(value)
    Constant(handle) =>
      self.eval_constant_float_expression_for_emit(handle, visiting_constants)
    Unary(UnaryOperator::Negate, inner) => {
      guard self.eval_global_float_expression_for_emit(
          inner, visiting_constants,
        )
        is Some(value) else {
        return None
      }
      Some(-value)
    }
    Binary(op, left, right) => {
      guard self.eval_global_float_expression_for_emit(left, visiting_constants)
        is Some(left_value) else {
        return None
      }
      guard self.eval_global_float_expression_for_emit(
          right, visiting_constants,
        )
        is Some(right_value) else {
        return None
      }
      wgsl_ir_emit_eval_float_binary(op, left_value, right_value)
    }
    _ => None
  }
}

///|
fn WgslIrEmitter::eval_constant_float_expression_for_emit(
  self : WgslIrEmitter,
  handle : Handle,
  visiting_constants : @set.Set[Int],
) -> Double? {
  let index = handle.index()
  if visiting_constants.contains(index) {
    return None
  }
  match self.shader_module.constants.items.get(index) {
    Some(constant) => {
      visiting_constants.add(index)
      let result = self.eval_global_float_expression_for_emit(
        constant.init,
        visiting_constants,
      )
      ignore(visiting_constants.remove(index))
      result
    }
    None => None
  }
}

///|
fn WgslIrEmitter::eval_constant_float_expression_for_writer(
  self : WgslIrEmitter,
  handle : Handle,
) -> Double? {
  match self.shader_module.constants.items.get(handle.index()) {
    Some(constant) if self.should_inline_constant_expression(constant) =>
      self.eval_global_float_expression_for_emit(constant.init, @set.Set([]))
    _ => None
  }
}

///|
fn wgsl_ir_emit_f32_to_double(value : Float) -> Double? {
  Some(value.to_double())
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
fn WgslIrEmitter::eval_constant_integer_expression_for_writer(
  self : WgslIrEmitter,
  handle : Handle,
) -> WgslIrEmitIntegerValue? {
  match self.shader_module.constants.items.get(handle.index()) {
    Some(constant) if self.should_inline_constant_expression(constant) =>
      self.eval_global_integer_expression_for_emit(constant.init, @set.Set([]))
    _ => None
  }
}

///|
fn WgslIrEmitter::eval_constant_float_expression_for_constructor(
  self : WgslIrEmitter,
  handle : Handle,
) -> Double? {
  match self.shader_module.constants.items.get(handle.index()) {
    Some(constant) if !constant.generated_import =>
      self.eval_global_float_expression_for_emit(constant.init, @set.Set([]))
    _ => None
  }
}

///|
fn WgslIrEmitter::eval_constant_integer_expression_for_constructor(
  self : WgslIrEmitter,
  handle : Handle,
) -> WgslIrEmitIntegerValue? {
  match self.shader_module.constants.items.get(handle.index()) {
    Some(constant) if !constant.generated_import =>
      self.eval_global_integer_expression_for_emit(constant.init, @set.Set([]))
    _ => None
  }
}

///|
fn WgslIrEmitter::eval_float_expression_with_retained_constants(
  self : WgslIrEmitter,
  function : Function?,
  handle : Handle,
) -> Double? raise WgslIrEmitError {
  if !self.expression_tree_contains_constant_reference(function, handle) {
    return None
  }
  self.eval_float_expression_with_retained_constants_inner(function, handle)
}

///|
fn WgslIrEmitter::eval_float_expression_with_retained_constants_inner(
  self : WgslIrEmitter,
  function : Function?,
  handle : Handle,
) -> Double? raise WgslIrEmitError {
  match self.required_expression(function, handle) {
    Literal(literal) => wgsl_ir_float_value_from_numeric_literal(literal)
    Constant(constant) =>
      match self.eval_constant_float_expression_for_retained_context(constant) {
        Some(value) => Some(value)
        None =>
          match
            self.eval_constant_integer_expression_for_constructor(constant) {
            Some(value) => value.to_double()
            None => None
          }
      }
    Compose(ty, [component]) =>
      match self.shader_module.types.items.get(ty.index()) {
        Some({ inner: Scalar({ kind: Float | AbstractFloat, .. }), .. }) =>
          self.eval_float_expression_with_retained_constants_inner(
            function, component,
          )
        _ => None
      }
    Unary(UnaryOperator::Negate, inner) =>
      match
        self.eval_float_expression_with_retained_constants_inner(
          function, inner,
        ) {
        Some(value) => Some(-value)
        None => None
      }
    Binary(op, left, right) => {
      guard self.eval_float_expression_with_retained_constants_inner(
          function, left,
        )
        is Some(left_value) else {
        return None
      }
      guard self.eval_float_expression_with_retained_constants_inner(
          function, right,
        )
        is Some(right_value) else {
        return None
      }
      wgsl_ir_emit_eval_float_binary(op, left_value, right_value)
    }
    _ => None
  }
}

///|
fn WgslIrEmitter::eval_constant_float_expression_for_retained_context(
  self : WgslIrEmitter,
  handle : Handle,
) -> Double? {
  match self.shader_module.constants.items.get(handle.index()) {
    Some(constant) =>
      self.eval_global_float_expression_for_emit(constant.init, @set.Set([]))
    None => None
  }
}

///|
fn WgslIrEmitter::expression_tree_contains_constant_reference(
  self : WgslIrEmitter,
  function : Function?,
  handle : Handle,
) -> Bool {
  match self.optional_expression(function, handle) {
    Some(expression) =>
      self.expression_contains_constant_reference(function, expression)
    None => false
  }
}

///|
fn WgslIrEmitter::expression_contains_constant_reference(
  self : WgslIrEmitter,
  function : Function?,
  expression : Expression,
) -> Bool {
  match expression {
    Constant(_) => true
    Literal(_)
    | Override(_)
    | FunctionArgument(_)
    | GlobalVariable(_)
    | LocalVariable(_)
    | Load(_)
    | AddressOf(_, _)
    | ZeroValue(_)
    | FunctionCall(_, _)
    | AtomicCall(_, _)
    | ImageSample(_, _, _, _, _, _, _, _, _)
    | ImageLoad(_, _, _, _, _)
    | ImageQuery(_, _)
    | CallResult(_)
    | AtomicResult(_, _)
    | WorkGroupUniformLoadResult(_)
    | WorkGroupUniformLoad(_)
    | ArrayLength(_)
    | RayQueryInitialize(_, _, _)
    | RayQueryProceed(_)
    | RayQueryGenerateIntersection(_, _)
    | RayQueryConfirmIntersection(_)
    | RayQueryTerminate(_)
    | RayQueryVertexPositions(_, _)
    | RayQueryProceedResult
    | RayQueryGetIntersection(_, _)
    | SubgroupCall(_, _)
    | SubgroupBallotResult
    | SubgroupOperationResult(_)
    | CooperativeLoad(_, _, _, _)
    | CooperativeMultiplyAdd(_, _, _) => false
    Unary(_, inner)
    | Bitcast(_, inner)
    | Relational(_, inner)
    | As(inner, _, _)
    | Splat(_, inner)
    | Swizzle(_, inner, _)
    | AccessIndex(inner, _)
    | Component(inner, _)
    | Derivative(_, _, inner) =>
      self.expression_tree_contains_constant_reference(function, inner)
    Access(base, index) | Binary(_, base, index) =>
      self.expression_tree_contains_constant_reference(function, base) ||
      self.expression_tree_contains_constant_reference(function, index)
    Select(left, right, condition) =>
      self.expression_tree_contains_constant_reference(function, left) ||
      self.expression_tree_contains_constant_reference(function, right) ||
      self.expression_tree_contains_constant_reference(function, condition)
    Compose(_, components) =>
      self.expression_list_contains_constant_reference(function, components)
    Math(_, first, second, third, fourth) =>
      self.expression_tree_contains_constant_reference(function, first) ||
      self.optional_expression_contains_constant_reference(function, second) ||
      self.optional_expression_contains_constant_reference(function, third) ||
      self.optional_expression_contains_constant_reference(function, fourth)
  }
}

///|
fn WgslIrEmitter::expression_list_contains_constant_reference(
  self : WgslIrEmitter,
  function : Function?,
  expressions : Array[Handle],
) -> Bool {
  for expression in expressions {
    if self.expression_tree_contains_constant_reference(function, expression) {
      return true
    }
  }
  false
}

///|
fn WgslIrEmitter::optional_expression_contains_constant_reference(
  self : WgslIrEmitter,
  function : Function?,
  expression : Handle?,
) -> Bool {
  match expression {
    Some(expression) =>
      self.expression_tree_contains_constant_reference(function, expression)
    None => false
  }
}

///|
fn WgslIrEmitter::eval_integer_expression_for_writer(
  self : WgslIrEmitter,
  function : Function?,
  handle : Handle,
) -> WgslIrEmitIntegerValue? raise WgslIrEmitError {
  match self.required_expression(function, handle) {
    Literal(Literal::I32(value)) => Some(Signed(value))
    Literal(Literal::U32(value)) => Some(Unsigned(value))
    Literal(Literal::AbstractInt(value)) => Some(Abstract(value))
    Constant(handle) => self.eval_constant_integer_expression_for_writer(handle)
    Unary(UnaryOperator::Negate, inner) => {
      guard self.eval_integer_expression_for_writer(function, inner)
        is Some(value) else {
        return None
      }
      match value.to_signed_int() {
        Some(value) => Some(Signed(-value))
        None => None
      }
    }
    Unary(UnaryOperator::BitwiseNot, inner) =>
      match self.eval_integer_expression_for_writer(function, inner) {
        Some(Unsigned(value)) => Some(Unsigned(value.lnot()))
        Some(Signed(value)) => Some(Signed(value.lnot()))
        Some(Abstract(value)) => Some(Abstract(value.lnot()))
        None => None
      }
    Binary(op, left, right) => {
      guard self.eval_integer_expression_for_writer(function, left)
        is Some(left_value) else {
        return None
      }
      guard self.eval_integer_expression_for_writer(function, right)
        is Some(right_value) else {
        return None
      }
      wgsl_ir_emit_eval_integer_binary(op, left_value, right_value)
    }
    Math(MathFunction::Min, a, Some(b), None, None) => {
      guard self.eval_integer_expression_for_writer(function, a)
        is Some(a_value) else {
        return None
      }
      guard self.eval_integer_expression_for_writer(function, b)
        is Some(b_value) else {
        return None
      }
      wgsl_ir_emit_eval_integer_min(a_value, b_value)
    }
    Math(MathFunction::Max, a, Some(b), None, None) => {
      guard self.eval_integer_expression_for_writer(function, a)
        is Some(a_value) else {
        return None
      }
      guard self.eval_integer_expression_for_writer(function, b)
        is Some(b_value) else {
        return None
      }
      wgsl_ir_emit_eval_integer_max(a_value, b_value)
    }
    Math(MathFunction::Clamp, value, Some(low), Some(high), None) => {
      guard self.eval_integer_expression_for_writer(function, value)
        is Some(value) else {
        return None
      }
      guard self.eval_integer_expression_for_writer(function, low) is Some(low) else {
        return None
      }
      guard self.eval_integer_expression_for_writer(function, high)
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
        Some(value.to_int())
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
  Some(value.reinterpret_as_uint())
}

///|
fn wgsl_ir_emit_non_negative_int64_to_uint(value : Int64) -> UInt? {
  if value < Int64::from_int(0) {
    return None
  }
  if value > 4294967295L {
    return None
  }
  Some(value.reinterpret_as_uint64().to_uint())
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
fn wgsl_ir_emit_eval_float_binary(
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
