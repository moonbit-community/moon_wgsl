// Copyright 2026 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
fn WgslIrLowerer::literal_from_token_with_expected(
  self : WgslIrLowerer,
  token : @ast.WgslExprToken,
  expected_ty : Handle?,
) -> Literal raise WgslIrLowerError {
  let literal = wgsl_ir_literal_from_token(token)
  guard expected_ty is Some(ty_handle) else { return literal }
  match self.shader_module.types.get(ty_handle) {
    Some(ty) =>
      match ty.inner {
        Scalar(scalar) => wgsl_ir_contextualize_literal(literal, scalar)
        _ => literal
      }
    None => literal
  }
}

///|
fn WgslIrLowerer::contextualize_function_literal_expression(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle,
  expected_ty : Handle,
) -> Unit raise WgslIrLowerError {
  self.contextualize_function_expression_for_type(function, handle, expected_ty)
}

///|
fn WgslIrLowerer::contextualize_function_expression_for_type(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle,
  expected_ty : Handle,
) -> Unit raise WgslIrLowerError {
  match function.expressions.items.get(handle.index()) {
    Some(Literal(_)) =>
      self.contextualize_function_literal_handle(function, handle, expected_ty)
    Some(Unary(UnaryOperator::Negate, inner)) =>
      self.contextualize_function_expression_for_type(
        function, inner, expected_ty,
      )
    Some(Compose(actual_ty, components)) =>
      self.contextualize_function_constructor_expression(
        function, handle, actual_ty, components, expected_ty,
      )
    Some(Splat(_, inner)) =>
      match self.constructor_component_expected_type(expected_ty) {
        Some(component_ty) =>
          self.contextualize_function_expression_for_type(
            function, inner, component_ty,
          )
        None =>
          self.contextualize_function_expression_for_type(
            function, inner, expected_ty,
          )
      }
    _ => ()
  }
}

///|
fn WgslIrLowerer::contextualize_function_literal_handle(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle,
  expected_ty : Handle,
) -> Unit raise WgslIrLowerError {
  guard function.expressions.items.get(handle.index()) is Some(Literal(literal)) else {
    return
  }
  match self.scalar_for_literal_context_type(expected_ty) {
    Some(scalar) =>
      function.expressions.set(
        handle,
        Expression::Literal(wgsl_ir_contextualize_literal(literal, scalar)),
      )
    None => ()
  }
}

///|
fn WgslIrLowerer::contextualize_function_constructor_expression(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle,
  actual_ty : Handle,
  components : Array[Handle],
  expected_ty : Handle,
) -> Unit raise WgslIrLowerError {
  let target_ty = match
    self.contextualized_constructor_type(actual_ty, expected_ty) {
    Some(value) => value
    None => actual_ty
  }
  match self.constructor_component_expected_type(target_ty) {
    Some(component_ty) =>
      for component in components {
        self.contextualize_function_expression_for_type(
          function, component, component_ty,
        )
      }
    None => ()
  }
  if target_ty != actual_ty {
    match function.expressions.items.get(handle.index()) {
      Some(Splat(_, _)) => ()
      _ =>
        function.expressions.set(
          handle,
          Expression::Compose(target_ty, components),
        )
    }
  }
}

///|
fn WgslIrLowerer::contextualized_constructor_type(
  self : WgslIrLowerer,
  actual_ty : Handle,
  expected_ty : Handle,
) -> Handle? {
  guard self.type_is_concrete_numeric_literal_context(expected_ty) else {
    return None
  }
  guard self.shader_module.types.get(actual_ty) is Some(actual) else {
    return None
  }
  guard self.shader_module.types.get(expected_ty) is Some(expected) else {
    return None
  }
  if !self.type_inner_has_matching_constructor_shape(
      actual.inner,
      expected.inner,
    ) {
    return None
  }
  if self.type_inner_contains_abstract_numeric(actual.inner) {
    Some(expected_ty)
  } else {
    None
  }
}

///|
fn WgslIrLowerer::type_inner_has_matching_constructor_shape(
  self : WgslIrLowerer,
  actual : TypeInner,
  expected : TypeInner,
) -> Bool {
  ignore(self)
  match (actual, expected) {
    (Scalar(_), Scalar(_)) => true
    (Vector(actual_size, _), Vector(expected_size, _)) =>
      actual_size == expected_size
    (
      Matrix(actual_columns, actual_rows, _),
      Matrix(expected_columns, expected_rows, _),
    ) => actual_columns == expected_columns && actual_rows == expected_rows
    _ => false
  }
}

///|
fn WgslIrLowerer::type_inner_contains_abstract_numeric(
  self : WgslIrLowerer,
  inner : TypeInner,
) -> Bool {
  ignore(self)
  match inner {
    Scalar(scalar) | Vector(_, scalar) | Matrix(_, _, scalar) =>
      scalar.kind == AbstractInt || scalar.kind == AbstractFloat
    _ => false
  }
}

///|
fn WgslIrLowerer::negated_literal_from_token_with_expected(
  self : WgslIrLowerer,
  token : @ast.WgslExprToken,
  expected_ty : Handle?,
) -> Literal? raise WgslIrLowerError {
  wgsl_ir_negate_literal(
    self.literal_from_token_with_expected(token, expected_ty),
  )
}

///|
fn wgsl_ir_negate_literal(literal : Literal) -> Literal? {
  match literal {
    F64(value) => Some(Literal::F64(-value))
    F32(value) => Some(Literal::F32(Float::from_double(-value.to_double())))
    F16(value) => Some(Literal::F16(-value))
    I16(value) => Some(Literal::I16(-value))
    I32(value) => Some(Literal::I32(-value))
    I64(value) => Some(Literal::I64(-value))
    AbstractInt(value) => Some(Literal::AbstractInt(-value))
    AbstractFloat(value) => Some(Literal::AbstractFloat(-value))
    _ => None
  }
}

///|
fn WgslIrLowerer::scalar_for_literal_context_type(
  self : WgslIrLowerer,
  ty_handle : Handle,
) -> Scalar? {
  match self.shader_module.types.get(ty_handle) {
    Some(ty) =>
      match ty.inner {
        Scalar(scalar) => Some(scalar)
        Vector(_, scalar) => Some(scalar)
        _ => None
      }
    None => None
  }
}

///|
fn wgsl_ir_contextualize_literal(
  literal : Literal,
  scalar : Scalar,
) -> Literal raise WgslIrLowerError {
  match (literal, scalar.kind, scalar.width) {
    (AbstractInt(value), Sint, _) => Literal::I32(wgsl_ir_int64_to_i32(value))
    (AbstractInt(value), Uint, _) =>
      Literal::U32(wgsl_ir_int64_to_u32(value, "unsigned literal \{value}"))
    (AbstractFloat(value), Float, 2) => Literal::F16(value)
    (AbstractFloat(value), Float, 8) => Literal::F64(value)
    _ => literal
  }
}

///|
fn wgsl_ir_literal_from_token(
  token : @ast.WgslExprToken,
) -> Literal raise WgslIrLowerError {
  match token.kind() {
    BoolLiteral(value) => Literal::Bool(value)
    NumericLiteral(literal) =>
      match literal.category {
        AbstractIntLiteral =>
          Literal::AbstractInt(
            wgsl_ir_int64_literal_from_text(literal.raw_text),
          )
        I32Literal =>
          Literal::I32(wgsl_ir_i32_literal_from_numeric_literal(literal))
        U32Literal =>
          Literal::U32(wgsl_ir_u32_literal_from_numeric_literal(literal))
        AbstractFloatLiteral => {
          let text = wgsl_ir_float_literal_text(literal.raw_text)
          let value : Double = @strconv.from_str(text) catch {
            _ => raise WgslIrLowerError::UnsupportedExpression(literal.raw_text)
          }
          Literal::AbstractFloat(value)
        }
        F32Literal => {
          let text = wgsl_ir_float_literal_text(literal.raw_text)
          let value : Double = @strconv.from_str(text) catch {
            _ => raise WgslIrLowerError::UnsupportedExpression(literal.raw_text)
          }
          Literal::F32(Float::from_double(value))
        }
        F16Literal => Literal::F16(wgsl_ir_float64_literal_from_text(literal))
        InvalidNumericLiteral =>
          raise WgslIrLowerError::UnsupportedExpression(literal.raw_text)
      }
    _ => raise WgslIrLowerError::UnsupportedExpression(token.text())
  }
}

///|
fn wgsl_ir_i32_literal_from_numeric_literal(
  literal : @ast.WgslNumericLiteral,
) -> Int raise WgslIrLowerError {
  let value = wgsl_ir_int64_literal_from_text(literal.raw_text)
  wgsl_ir_int64_to_i32(value)
}

///|
fn wgsl_ir_int64_to_i32(value : Int64) -> Int raise WgslIrLowerError {
  let min = Int64::from_int(-2147483648)
  let max = Int64::from_int(2147483647)
  if value < min || value > max {
    raise WgslIrLowerError::UnsupportedExpression("i32 literal \{value}")
  }
  value.to_int()
}

///|
fn wgsl_ir_u32_literal_from_numeric_literal(
  literal : @ast.WgslNumericLiteral,
) -> UInt raise WgslIrLowerError {
  let value = wgsl_ir_int64_literal_from_text(literal.raw_text)
  wgsl_ir_int64_to_u32(value, literal.raw_text)
}

///|
fn wgsl_ir_int64_to_u32(
  value : Int64,
  source : String,
) -> UInt raise WgslIrLowerError {
  if value < Int64::from_int(0) {
    raise WgslIrLowerError::UnsupportedExpression(source)
  }
  if value > 4294967295L {
    raise WgslIrLowerError::UnsupportedExpression(source)
  }
  value.reinterpret_as_uint64().to_uint()
}

///|
fn wgsl_ir_float64_literal_from_text(
  literal : @ast.WgslNumericLiteral,
) -> Double raise WgslIrLowerError {
  let text = wgsl_ir_float_literal_text(literal.raw_text)
  @strconv.from_str(text) catch {
    _ => raise WgslIrLowerError::UnsupportedExpression(literal.raw_text)
  }
}

///|
fn wgsl_ir_numeric_literal_default_type_name(
  literal : @ast.WgslNumericLiteral,
) -> String {
  match literal.category {
    I32Literal => "i32"
    U32Literal => "u32"
    F32Literal => "f32"
    F16Literal => "f16"
    AbstractFloatLiteral => "__abstract_float"
    AbstractIntLiteral | InvalidNumericLiteral => "__abstract_int"
  }
}

///|
fn wgsl_ir_int64_literal_from_text(
  text : String,
) -> Int64 raise WgslIrLowerError {
  let body = wgsl_ir_integer_literal_without_suffix(text)
  let end = body.length()
  guard end > 0 else { raise WgslIrLowerError::UnsupportedExpression(text) }
  let mut value : Int64 = 0
  if end > 2 &&
    body.code_unit_at(0).to_int() == 48 &&
    (
      body.code_unit_at(1).to_int() == 120 ||
      body.code_unit_at(1).to_int() == 88
    ) {
    for i in 2..<end {
      match wgsl_ir_hex_digit_value(body.code_unit_at(i).to_int()) {
        Some(digit) => value = value * 16 + Int64::from_int(digit)
        None => raise WgslIrLowerError::UnsupportedExpression(text)
      }
    }
    return value
  }
  for i in 0..<end {
    let code = body.code_unit_at(i).to_int()
    if code < 48 || code > 57 {
      raise WgslIrLowerError::UnsupportedExpression(text)
    }
    value = value * 10 + Int64::from_int(code - 48)
  }
  value
}

///|
fn wgsl_ir_integer_literal_without_suffix(text : String) -> String {
  if text.length() == 0 {
    return text
  }
  let last = text.code_unit_at(text.length() - 1).to_int()
  if last == 105 || last == 73 || last == 117 || last == 85 {
    text[0:text.length() - 1].to_owned()
  } else {
    text
  }
}

///|
fn wgsl_ir_hex_digit_value(code : Int) -> Int? {
  if code >= 48 && code <= 57 {
    return Some(code - 48)
  }
  if code >= 65 && code <= 70 {
    return Some(code - 65 + 10)
  }
  if code >= 97 && code <= 102 {
    return Some(code - 97 + 10)
  }
  None
}

///|
fn wgsl_ir_float_literal_text(text : String) -> String {
  let trimmed = text.trim().to_owned()
  if trimmed.contains("f") {
    match trimmed.split("f").collect() {
      [head, ..] => head.to_owned()
      [] => trimmed
    }
  } else if trimmed.contains("h") {
    match trimmed.split("h").collect() {
      [head, ..] => head.to_owned()
      [] => trimmed
    }
  } else {
    trimmed
  }
}

///|
fn wgsl_ir_uint_literal_to_small_int(value : UInt) -> Int? {
  if value <= (2147483647 : Int).reinterpret_as_uint() {
    Some(value.reinterpret_as_int())
  } else {
    None
  }
}

///|
fn wgsl_ir_numeric_literal_to_small_int(
  literal : @ast.WgslNumericLiteral,
) -> Int? {
  match literal.category {
    AbstractIntLiteral | I32Literal | U32Literal => {
      let value = wgsl_ir_int64_literal_from_text(literal.raw_text) catch {
        _ => return None
      }
      if value <= Int64::from_int(2147483647) {
        Some(value.to_int())
      } else {
        None
      }
    }
    _ => None
  }
}

///|
fn wgsl_ir_int_literal_from_expr_ref(expr_ref : @ast.WgslExprRef) -> Int? {
  match expr_ref.root() {
    Some(node) => wgsl_ir_int_literal_from_expr_node(node)
    None => None
  }
}

///|
fn wgsl_ir_int_literal_from_expr_node(node : @ast.WgslExprNode) -> Int? {
  match node.kind() {
    Literal(token) =>
      match token.kind() {
        NumericLiteral(literal) => wgsl_ir_numeric_literal_to_small_int(literal)
        _ => None
      }
    _ => None
  }
}

///|
fn wgsl_ir_unary_operator(
  op : @ast.WgslExprOperator,
) -> UnaryOperator raise WgslIrLowerError {
  match op {
    Subtract => UnaryOperator::Negate
    Not => UnaryOperator::LogicalNot
    Complement => UnaryOperator::BitwiseNot
    _ =>
      raise WgslIrLowerError::UnsupportedExpression(
        "unary operator \{op.text()}",
      )
  }
}

///|
fn wgsl_ir_binary_operator(
  op : @ast.WgslExprOperator,
) -> BinaryOperator raise WgslIrLowerError {
  match op {
    Add => BinaryOperator::Add
    Subtract => BinaryOperator::Subtract
    Multiply => BinaryOperator::Multiply
    Divide => BinaryOperator::Divide
    Modulo => BinaryOperator::Modulo
    Equal => BinaryOperator::Equal
    NotEqual => BinaryOperator::NotEqual
    Less => BinaryOperator::Less
    LessEqual => BinaryOperator::LessEqual
    Greater => BinaryOperator::Greater
    GreaterEqual => BinaryOperator::GreaterEqual
    BitAnd => BinaryOperator::And
    BitXor => BinaryOperator::ExclusiveOr
    BitOr => BinaryOperator::InclusiveOr
    LogicalAnd => BinaryOperator::LogicalAnd
    LogicalOr => BinaryOperator::LogicalOr
    ShiftLeft => BinaryOperator::ShiftLeft
    ShiftRight => BinaryOperator::ShiftRight
    _ =>
      raise WgslIrLowerError::UnsupportedExpression(
        "binary operator \{op.text()}",
      )
  }
}

///|
fn wgsl_ir_compound_assignment_operator(op : String) -> BinaryOperator? {
  match op {
    "+=" => Some(BinaryOperator::Add)
    "-=" => Some(BinaryOperator::Subtract)
    "*=" => Some(BinaryOperator::Multiply)
    "/=" => Some(BinaryOperator::Divide)
    "%=" => Some(BinaryOperator::Modulo)
    "&=" => Some(BinaryOperator::And)
    "^=" => Some(BinaryOperator::ExclusiveOr)
    "|=" => Some(BinaryOperator::InclusiveOr)
    "<<=" => Some(BinaryOperator::ShiftLeft)
    ">>=" => Some(BinaryOperator::ShiftRight)
    _ => None
  }
}
