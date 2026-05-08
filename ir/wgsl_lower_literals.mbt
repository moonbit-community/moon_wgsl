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
fn wgsl_ir_contextualize_literal(
  literal : Literal,
  scalar : Scalar,
) -> Literal raise WgslIrLowerError {
  match (literal, scalar.kind, scalar.width) {
    (AbstractInt(value), Sint, _) => Literal::I32(value.to_int())
    (AbstractInt(value), Uint, _) => {
      let parsed : UInt = @strconv.from_str("\{value}") catch {
        _ =>
          raise WgslIrLowerError::UnsupportedExpression(
            "unsigned literal \{value}",
          )
      }
      Literal::U32(parsed)
    }
    (AbstractFloat(value), Float, 2) => Literal::F16(value)
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
  let max = Int64::from_int(2147483647)
  if value > max {
    raise WgslIrLowerError::UnsupportedExpression(literal.raw_text)
  }
  value.to_int()
}

///|
fn wgsl_ir_u32_literal_from_numeric_literal(
  literal : @ast.WgslNumericLiteral,
) -> UInt raise WgslIrLowerError {
  let value = wgsl_ir_int64_literal_from_text(literal.raw_text)
  let max : Int64 = @strconv.from_str("4294967295") catch {
    _ => raise WgslIrLowerError::UnsupportedExpression(literal.raw_text)
  }
  if value > max {
    raise WgslIrLowerError::UnsupportedExpression(literal.raw_text)
  }
  @strconv.from_str("\{value}") catch {
    _ => raise WgslIrLowerError::UnsupportedExpression(literal.raw_text)
  }
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
    Some(node) =>
      match node.kind() {
        Literal(token) =>
          match token.kind() {
            NumericLiteral(literal) =>
              wgsl_ir_numeric_literal_to_small_int(literal)
            _ => None
          }
        _ => None
      }
    None => None
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
