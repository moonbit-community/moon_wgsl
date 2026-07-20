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
const CONST_EVAL_I32_MIN : Int64 = -2147483648L

///|
const CONST_EVAL_I32_MAX : Int64 = 2147483647L

///|
const CONST_EVAL_U32_MAX : Int64 = 4294967295L

///|
priv enum ConstEvalToken {
  At
  LeftParen
  RightParen
  LeftBracket
  RightBracket
  LeftBrace
  RightBrace
  Colon
  Semi
  Comma
  Dot
  Equal
  EqualEqual
  Bang
  BangEqual
  Less
  LessEqual
  LeftShift
  Greater
  GreaterEqual
  RightShift
  Amp
  AmpAmp
  Pipe
  PipePipe
  Caret
  Plus
  Minus
  Star
  Slash
  Percent
  Tilde
  Arrow
  Ident(String)
  Number(String)
}

///|
fn const_eval_is_whitespace(code : Int) -> Bool {
  code == 32 || code == 9 || code == 10 || code == 13
}

///|
fn const_eval_is_digit(code : Int) -> Bool {
  code >= 48 && code <= 57
}

///|
fn const_eval_is_identifier_start(code : Int) -> Bool {
  (code >= 65 && code <= 90) || (code >= 97 && code <= 122) || code == 95
}

///|
fn const_eval_is_identifier_char(code : Int) -> Bool {
  const_eval_is_identifier_start(code) || const_eval_is_digit(code)
}

///|
fn const_eval_is_number_char(code : Int) -> Bool {
  const_eval_is_identifier_char(code) || code == 46
}

///|
fn const_eval_lex(
  source : String,
) -> Array[ConstEvalToken] raise WeslCompileError {
  let tokens : Array[ConstEvalToken] = []
  let mut index = 0
  while index < source.length() {
    let code = source.code_unit_at(index).to_int()
    if const_eval_is_whitespace(code) {
      index += 1
      continue
    }
    if code == 47 &&
      index + 1 < source.length() &&
      source.code_unit_at(index + 1).to_int() == 47 {
      index += 2
      while index < source.length() && source.code_unit_at(index).to_int() != 10 {
        index += 1
      }
      continue
    }
    match code {
      64 => {
        tokens.push(ConstEvalToken::At)
        index += 1
      }
      40 => {
        tokens.push(ConstEvalToken::LeftParen)
        index += 1
      }
      41 => {
        tokens.push(ConstEvalToken::RightParen)
        index += 1
      }
      91 => {
        tokens.push(ConstEvalToken::LeftBracket)
        index += 1
      }
      93 => {
        tokens.push(ConstEvalToken::RightBracket)
        index += 1
      }
      123 => {
        tokens.push(ConstEvalToken::LeftBrace)
        index += 1
      }
      125 => {
        tokens.push(ConstEvalToken::RightBrace)
        index += 1
      }
      58 => {
        tokens.push(ConstEvalToken::Colon)
        index += 1
      }
      59 => {
        tokens.push(ConstEvalToken::Semi)
        index += 1
      }
      44 => {
        tokens.push(ConstEvalToken::Comma)
        index += 1
      }
      46 => {
        tokens.push(ConstEvalToken::Dot)
        index += 1
      }
      61 =>
        if index + 1 < source.length() &&
          source.code_unit_at(index + 1).to_int() == 61 {
          tokens.push(ConstEvalToken::EqualEqual)
          index += 2
        } else {
          tokens.push(ConstEvalToken::Equal)
          index += 1
        }
      33 =>
        if index + 1 < source.length() &&
          source.code_unit_at(index + 1).to_int() == 61 {
          tokens.push(ConstEvalToken::BangEqual)
          index += 2
        } else {
          tokens.push(ConstEvalToken::Bang)
          index += 1
        }
      60 =>
        if index + 1 < source.length() &&
          source.code_unit_at(index + 1).to_int() == 60 {
          tokens.push(ConstEvalToken::LeftShift)
          index += 2
        } else if index + 1 < source.length() &&
          source.code_unit_at(index + 1).to_int() == 61 {
          tokens.push(ConstEvalToken::LessEqual)
          index += 2
        } else {
          tokens.push(ConstEvalToken::Less)
          index += 1
        }
      62 =>
        if index + 1 < source.length() &&
          source.code_unit_at(index + 1).to_int() == 62 {
          tokens.push(ConstEvalToken::RightShift)
          index += 2
        } else if index + 1 < source.length() &&
          source.code_unit_at(index + 1).to_int() == 61 {
          tokens.push(ConstEvalToken::GreaterEqual)
          index += 2
        } else {
          tokens.push(ConstEvalToken::Greater)
          index += 1
        }
      38 =>
        if index + 1 < source.length() &&
          source.code_unit_at(index + 1).to_int() == 38 {
          tokens.push(ConstEvalToken::AmpAmp)
          index += 2
        } else {
          tokens.push(ConstEvalToken::Amp)
          index += 1
        }
      124 =>
        if index + 1 < source.length() &&
          source.code_unit_at(index + 1).to_int() == 124 {
          tokens.push(ConstEvalToken::PipePipe)
          index += 2
        } else {
          tokens.push(ConstEvalToken::Pipe)
          index += 1
        }
      94 => {
        tokens.push(ConstEvalToken::Caret)
        index += 1
      }
      43 => {
        tokens.push(ConstEvalToken::Plus)
        index += 1
      }
      42 => {
        tokens.push(ConstEvalToken::Star)
        index += 1
      }
      45 =>
        if index + 1 < source.length() &&
          source.code_unit_at(index + 1).to_int() == 62 {
          tokens.push(ConstEvalToken::Arrow)
          index += 2
        } else {
          tokens.push(ConstEvalToken::Minus)
          index += 1
        }
      47 => {
        tokens.push(ConstEvalToken::Slash)
        index += 1
      }
      37 => {
        tokens.push(ConstEvalToken::Percent)
        index += 1
      }
      126 => {
        tokens.push(ConstEvalToken::Tilde)
        index += 1
      }
      _ =>
        if const_eval_is_identifier_start(code) {
          let start = index
          index += 1
          while index < source.length() &&
                const_eval_is_identifier_char(
                  source.code_unit_at(index).to_int(),
                ) {
            index += 1
          }
          tokens.push(ConstEvalToken::Ident(source[start:index].to_owned()))
        } else if const_eval_is_digit(code) {
          let start = index
          index += 1
          while index < source.length() &&
                const_eval_is_number_char(source.code_unit_at(index).to_int()) {
            index += 1
          }
          tokens.push(ConstEvalToken::Number(source[start:index].to_owned()))
        } else {
          raise WeslCompileError::Parse(
            "unsupported const-eval token `\{source[index:index + 1].to_owned()}`",
          )
        }
    }
  }
  tokens
}

///|
priv struct ConstEvalParser {
  mut rest : ArrayView[ConstEvalToken]
}

///|
fn ConstEvalParser::new(tokens : Array[ConstEvalToken]) -> ConstEvalParser {
  ConstEvalParser::{ rest: tokens[:] }
}

///|
fn ConstEvalParser::view(self : ConstEvalParser) -> ArrayView[ConstEvalToken] {
  self.rest
}

///|
fn ConstEvalParser::update_view(
  self : ConstEvalParser,
  rest : ArrayView[ConstEvalToken],
) -> Unit {
  self.rest = rest
}

///|
fn[A] ConstEvalParser::error(
  self : ConstEvalParser,
  message : String,
) -> A raise WeslCompileError {
  ignore(self)
  raise WeslCompileError::Parse(message)
}

///|
fn ConstEvalParser::consume_token(
  self : ConstEvalParser,
  token : ConstEvalToken,
) -> Bool {
  match (token, self.view()) {
    (Semi, [Semi, .. rest]) => {
      self.update_view(rest)
      true
    }
    (RightParen, [RightParen, .. rest]) => {
      self.update_view(rest)
      true
    }
    _ => false
  }
}

///|
priv enum ConstEvalType {
  AbstractInt
  AbstractFloat
  Bool
  Void
  I32
  U32
  F32
  Vector(Int, ConstEvalType)
  Matrix(Int, Int, ConstEvalType)
  Array(ConstEvalType, Int?)
  Struct(String)
  FrexpAbstractResult
  FrexpF32Result
} derive(Eq)

///|
priv enum ConstEvalExpr {
  Literal(String)
  Binding(String)
  UnaryNeg(ConstEvalExpr)
  UnaryNot(ConstEvalExpr)
  UnaryBitNot(ConstEvalExpr)
  AddressOf(ConstEvalLValue)
  Binary(ConstEvalBinaryOp, ConstEvalExpr, ConstEvalExpr)
  Access(ConstEvalExpr, String)
  Index(ConstEvalExpr, ConstEvalExpr)
  Call(String, Array[ConstEvalExpr])
}

///|
priv enum ConstEvalBinaryOp {
  Add
  Sub
  Mul
  Div
  Mod
  Eq
  Ne
  Lt
  Le
  Gt
  Ge
  Shl
  Shr
  BitAnd
  BitOr
  BitXor
  LogicalAnd
  LogicalOr
}

///|
priv struct ConstEvalBinding {
  name : String
  declared_type : ConstEvalType?
  expr : ConstEvalExpr
}

///|
priv struct ConstEvalParam {
  name : String
  declared_type : ConstEvalType
}

///|
priv enum ConstEvalLValue {
  Root(String)
  Field(ConstEvalLValue, String)
  Element(ConstEvalLValue, ConstEvalExpr)
}

///|
priv enum ConstEvalSwitchSelector {
  SwitchExpression(ConstEvalExpr)
  SwitchDefault
}

///|
priv struct ConstEvalSwitchCase {
  selectors : Array[ConstEvalSwitchSelector]
  body : Array[ConstEvalStatement]
}

///|
priv enum ConstEvalStatement {
  Binding(ConstEvalBinding)
  Assignment(ConstEvalLValue, ConstEvalExpr)
  CompoundAssignment(ConstEvalLValue, ConstEvalBinaryOp, ConstEvalExpr)
  Increment(ConstEvalLValue)
  Decrement(ConstEvalLValue)
  If(ConstEvalExpr, Array[ConstEvalStatement], Array[ConstEvalStatement])
  Switch(ConstEvalExpr, Array[ConstEvalSwitchCase])
  Loop(Array[ConstEvalStatement], Array[ConstEvalStatement]?)
  While(ConstEvalExpr, Array[ConstEvalStatement])
  For(
    ConstEvalStatement?,
    ConstEvalExpr?,
    ConstEvalStatement?,
    Array[ConstEvalStatement]
  )
  Break
  BreakIf(ConstEvalExpr)
  Continue
  ReturnVoid
  Return(ConstEvalExpr)
}

///|
priv enum ConstEvalControl {
  ContinueExecution
  ReturnVoid
  ReturnValue(ConstEvalValue)
  BreakLoop
  ContinueLoop
}

///|
priv struct ConstEvalFunction {
  name : String
  params : Array[ConstEvalParam]
  return_type : ConstEvalType
  statements : Array[ConstEvalStatement]
}

///|
fn ConstEvalParser::parse_type(
  self : ConstEvalParser,
) -> ConstEvalType raise WeslCompileError {
  match self.view() {
    [Ident("bool"), .. rest] => {
      self.update_view(rest)
      ConstEvalType::Bool
    }
    [Ident("void"), .. rest] => {
      self.update_view(rest)
      ConstEvalType::Void
    }
    [Ident("i32"), .. rest] => {
      self.update_view(rest)
      ConstEvalType::I32
    }
    [Ident("u32"), .. rest] => {
      self.update_view(rest)
      ConstEvalType::U32
    }
    [Ident("f32"), .. rest] => {
      self.update_view(rest)
      ConstEvalType::F32
    }
    [Ident(name), Less, .. rest] => {
      if name == "array" {
        self.update_view(rest)
        let element = self.parse_type()
        let count = match self.view() {
          [Comma, Number(text), .. after_count] => {
            self.update_view(after_count)
            let value = const_eval_parse_array_count(text)
            match self.view() {
              [Comma, Greater, .. after] => self.update_view(after)
              [Greater, .. after] => self.update_view(after)
              _ => self.error("expected `>` in const-eval array type")
            }
            Some(value)
          }
          [Greater, .. after] => {
            self.update_view(after)
            None
          }
          _ => self.error("expected `>` in const-eval array type")
        }
        return ConstEvalType::Array(element, count)
      }
      if name.length() == 6 &&
        name[:3].to_owned() == "mat" &&
        name[4:5].to_owned() == "x" {
        self.update_view(rest)
        let columns = const_eval_matrix_dimension(name[3:4].to_owned())
        let rows = const_eval_matrix_dimension(name[5:6].to_owned())
        let element = self.parse_type()
        match element {
          F32 => ()
          _ => self.error("expected f32 matrix element type in const-eval type")
        }
        match self.view() {
          [Greater, .. after] => self.update_view(after)
          _ => self.error("expected `>` in const-eval matrix type")
        }
        return ConstEvalType::Matrix(columns, rows, element)
      }
      if !(name == "vec2" || name == "vec3" || name == "vec4") {
        self.error("expected const-eval type")
      }
      self.update_view(rest)
      let width = match name {
        "vec2" => 2
        "vec3" => 3
        _ => 4
      }
      let element = self.parse_type()
      match element {
        Bool | I32 | U32 | F32 => ()
        _ =>
          self.error("expected scalar vector element type in const-eval type")
      }
      match self.view() {
        [Greater, .. after] => self.update_view(after)
        _ => self.error("expected `>` in const-eval vector type")
      }
      ConstEvalType::Vector(width, element)
    }
    [Ident(name), .. rest] => {
      self.update_view(rest)
      ConstEvalType::Struct(name)
    }
    _ => self.error("expected const-eval type")
  }
}

///|
fn ConstEvalParser::parse_primary(
  self : ConstEvalParser,
) -> ConstEvalExpr raise WeslCompileError {
  match self.view() {
    [Number(text), .. rest] => {
      self.update_view(rest)
      ConstEvalExpr::Literal(text)
    }
    [Ident("true"), .. rest] => {
      self.update_view(rest)
      ConstEvalExpr::Literal("true")
    }
    [Ident("false"), .. rest] => {
      self.update_view(rest)
      ConstEvalExpr::Literal("false")
    }
    [Ident(name), Less, .. rest] => {
      if !(name == "vec2" || name == "vec3" || name == "vec4") {
        self.update_view(self.view()[1:])
        return ConstEvalExpr::Binding(name)
      }
      self.update_view(rest)
      let element = self.parse_type()
      match self.view() {
        [Greater, LeftParen, .. after] => self.update_view(after)
        _ => self.error("expected vector constructor argument list")
      }
      let args : Array[ConstEvalExpr] = []
      if self.view() is [RightParen, .. after_empty] {
        self.update_view(after_empty)
        return ConstEvalExpr::Call("\{name}<\{element.label()}>", args)
      }
      while true {
        args.push(self.parse_expression())
        match self.view() {
          [Comma, .. after_comma] => self.update_view(after_comma)
          [RightParen, .. after_paren] => {
            self.update_view(after_paren)
            break
          }
          _ => self.error("expected `,` or `)` in const-eval argument list")
        }
      }
      ConstEvalExpr::Call("\{name}<\{element.label()}>", args)
    }
    [Ident(name), LeftParen, .. rest] => {
      self.update_view(rest)
      let args : Array[ConstEvalExpr] = []
      if self.view() is [RightParen, .. after_empty] {
        self.update_view(after_empty)
        return ConstEvalExpr::Call(name, args)
      }
      while true {
        args.push(self.parse_expression())
        match self.view() {
          [Comma, .. after_comma] => self.update_view(after_comma)
          [RightParen, .. after_paren] => {
            self.update_view(after_paren)
            break
          }
          _ => self.error("expected `,` or `)` in const-eval argument list")
        }
      }
      ConstEvalExpr::Call(name, args)
    }
    [Ident(name), .. rest] => {
      self.update_view(rest)
      ConstEvalExpr::Binding(name)
    }
    [LeftParen, .. rest] => {
      self.update_view(rest)
      let expr = self.parse_expression()
      match self.view() {
        [RightParen, .. after_paren] => {
          self.update_view(after_paren)
          expr
        }
        _ => self.error("expected `)` in const-eval expression")
      }
    }
    _ => self.error("expected const-eval primary expression")
  }
}

///|
fn ConstEvalParser::parse_postfix(
  self : ConstEvalParser,
) -> ConstEvalExpr raise WeslCompileError {
  let mut expr = self.parse_primary()
  for rest = self.view() {
    match rest {
      [Dot, Ident(name), .. next] => {
        self.update_view(next)
        expr = ConstEvalExpr::Access(expr, name)
        continue self.view()
      }
      [Dot, ..] =>
        self.error("expected member name after `.` in const-eval expression")
      [LeftBracket, .. next] => {
        self.update_view(next)
        let index = self.parse_expression()
        match self.view() {
          [RightBracket, .. after] => self.update_view(after)
          _ => self.error("expected `]` in const-eval index expression")
        }
        expr = ConstEvalExpr::Index(expr, index)
        continue self.view()
      }
      _ => break
    }
  }
  expr
}

///|
fn ConstEvalParser::parse_unary(
  self : ConstEvalParser,
) -> ConstEvalExpr raise WeslCompileError {
  match self.view() {
    [Minus, .. rest] => {
      self.update_view(rest)
      ConstEvalExpr::UnaryNeg(self.parse_unary())
    }
    [Bang, .. rest] => {
      self.update_view(rest)
      ConstEvalExpr::UnaryNot(self.parse_unary())
    }
    [Tilde, .. rest] => {
      self.update_view(rest)
      ConstEvalExpr::UnaryBitNot(self.parse_unary())
    }
    [Amp, .. rest] => {
      self.update_view(rest)
      ConstEvalExpr::AddressOf(self.parse_lvalue())
    }
    _ => self.parse_postfix()
  }
}

///|
fn ConstEvalParser::parse_multiplicative(
  self : ConstEvalParser,
) -> ConstEvalExpr raise WeslCompileError {
  let mut expr = self.parse_unary()
  for rest = self.view() {
    match rest {
      [Star, .. next] => {
        self.update_view(next)
        expr = ConstEvalExpr::Binary(
          ConstEvalBinaryOp::Mul,
          expr,
          self.parse_unary(),
        )
        continue self.view()
      }
      [Slash, .. next] => {
        self.update_view(next)
        expr = ConstEvalExpr::Binary(
          ConstEvalBinaryOp::Div,
          expr,
          self.parse_unary(),
        )
        continue self.view()
      }
      [Percent, .. next] => {
        self.update_view(next)
        expr = ConstEvalExpr::Binary(
          ConstEvalBinaryOp::Mod,
          expr,
          self.parse_unary(),
        )
        continue self.view()
      }
      rest => {
        self.update_view(rest)
        break
      }
    }
  }
  expr
}

///|
fn ConstEvalParser::parse_additive(
  self : ConstEvalParser,
) -> ConstEvalExpr raise WeslCompileError {
  let mut expr = self.parse_multiplicative()
  for rest = self.view() {
    match rest {
      [Plus, .. next] => {
        self.update_view(next)
        expr = ConstEvalExpr::Binary(
          ConstEvalBinaryOp::Add,
          expr,
          self.parse_multiplicative(),
        )
        continue self.view()
      }
      [Minus, .. next] => {
        self.update_view(next)
        expr = ConstEvalExpr::Binary(
          ConstEvalBinaryOp::Sub,
          expr,
          self.parse_multiplicative(),
        )
        continue self.view()
      }
      rest => {
        self.update_view(rest)
        break
      }
    }
  }
  expr
}

///|
fn ConstEvalParser::parse_shift(
  self : ConstEvalParser,
) -> ConstEvalExpr raise WeslCompileError {
  let mut expr = self.parse_additive()
  for rest = self.view() {
    match rest {
      [LeftShift, .. next] => {
        self.update_view(next)
        expr = ConstEvalExpr::Binary(
          ConstEvalBinaryOp::Shl,
          expr,
          self.parse_additive(),
        )
        continue self.view()
      }
      [RightShift, .. next] => {
        self.update_view(next)
        expr = ConstEvalExpr::Binary(
          ConstEvalBinaryOp::Shr,
          expr,
          self.parse_additive(),
        )
        continue self.view()
      }
      rest => {
        self.update_view(rest)
        break
      }
    }
  }
  expr
}

///|
fn ConstEvalParser::parse_relational(
  self : ConstEvalParser,
) -> ConstEvalExpr raise WeslCompileError {
  let mut expr = self.parse_shift()
  for rest = self.view() {
    match rest {
      [Less, .. next] => {
        self.update_view(next)
        expr = ConstEvalExpr::Binary(
          ConstEvalBinaryOp::Lt,
          expr,
          self.parse_shift(),
        )
        continue self.view()
      }
      [LessEqual, .. next] => {
        self.update_view(next)
        expr = ConstEvalExpr::Binary(
          ConstEvalBinaryOp::Le,
          expr,
          self.parse_shift(),
        )
        continue self.view()
      }
      [Greater, .. next] => {
        self.update_view(next)
        expr = ConstEvalExpr::Binary(
          ConstEvalBinaryOp::Gt,
          expr,
          self.parse_shift(),
        )
        continue self.view()
      }
      [GreaterEqual, .. next] => {
        self.update_view(next)
        expr = ConstEvalExpr::Binary(
          ConstEvalBinaryOp::Ge,
          expr,
          self.parse_shift(),
        )
        continue self.view()
      }
      rest => {
        self.update_view(rest)
        break
      }
    }
  }
  expr
}

///|
fn ConstEvalParser::parse_equality(
  self : ConstEvalParser,
) -> ConstEvalExpr raise WeslCompileError {
  let mut expr = self.parse_relational()
  for rest = self.view() {
    match rest {
      [EqualEqual, .. next] => {
        self.update_view(next)
        expr = ConstEvalExpr::Binary(
          ConstEvalBinaryOp::Eq,
          expr,
          self.parse_relational(),
        )
        continue self.view()
      }
      [BangEqual, .. next] => {
        self.update_view(next)
        expr = ConstEvalExpr::Binary(
          ConstEvalBinaryOp::Ne,
          expr,
          self.parse_relational(),
        )
        continue self.view()
      }
      rest => {
        self.update_view(rest)
        break
      }
    }
  }
  expr
}

///|
fn ConstEvalParser::parse_bitwise_and(
  self : ConstEvalParser,
) -> ConstEvalExpr raise WeslCompileError {
  let mut expr = self.parse_equality()
  for rest = self.view() {
    match rest {
      [Amp, .. next] => {
        self.update_view(next)
        expr = ConstEvalExpr::Binary(
          ConstEvalBinaryOp::BitAnd,
          expr,
          self.parse_equality(),
        )
        continue self.view()
      }
      rest => {
        self.update_view(rest)
        break
      }
    }
  }
  expr
}

///|
fn ConstEvalParser::parse_bitwise_xor(
  self : ConstEvalParser,
) -> ConstEvalExpr raise WeslCompileError {
  let mut expr = self.parse_bitwise_and()
  for rest = self.view() {
    match rest {
      [Caret, .. next] => {
        self.update_view(next)
        expr = ConstEvalExpr::Binary(
          ConstEvalBinaryOp::BitXor,
          expr,
          self.parse_bitwise_and(),
        )
        continue self.view()
      }
      rest => {
        self.update_view(rest)
        break
      }
    }
  }
  expr
}

///|
fn ConstEvalParser::parse_bitwise_or(
  self : ConstEvalParser,
) -> ConstEvalExpr raise WeslCompileError {
  let mut expr = self.parse_bitwise_xor()
  for rest = self.view() {
    match rest {
      [Pipe, .. next] => {
        self.update_view(next)
        expr = ConstEvalExpr::Binary(
          ConstEvalBinaryOp::BitOr,
          expr,
          self.parse_bitwise_xor(),
        )
        continue self.view()
      }
      rest => {
        self.update_view(rest)
        break
      }
    }
  }
  expr
}

///|
fn ConstEvalParser::parse_logical_and(
  self : ConstEvalParser,
) -> ConstEvalExpr raise WeslCompileError {
  let mut expr = self.parse_bitwise_or()
  for rest = self.view() {
    match rest {
      [AmpAmp, .. next] => {
        self.update_view(next)
        expr = ConstEvalExpr::Binary(
          ConstEvalBinaryOp::LogicalAnd,
          expr,
          self.parse_bitwise_or(),
        )
        continue self.view()
      }
      rest => {
        self.update_view(rest)
        break
      }
    }
  }
  expr
}

///|
fn ConstEvalParser::parse_logical_or(
  self : ConstEvalParser,
) -> ConstEvalExpr raise WeslCompileError {
  let mut expr = self.parse_logical_and()
  for rest = self.view() {
    match rest {
      [PipePipe, .. next] => {
        self.update_view(next)
        expr = ConstEvalExpr::Binary(
          ConstEvalBinaryOp::LogicalOr,
          expr,
          self.parse_logical_and(),
        )
        continue self.view()
      }
      rest => {
        self.update_view(rest)
        break
      }
    }
  }
  expr
}

///|
fn ConstEvalParser::parse_expression(
  self : ConstEvalParser,
) -> ConstEvalExpr raise WeslCompileError {
  self.parse_logical_or()
}

///|
fn ConstEvalParser::parse_statement_block(
  self : ConstEvalParser,
) -> Array[ConstEvalStatement] raise WeslCompileError {
  match self.view() {
    [LeftBrace, .. rest] => self.update_view(rest)
    _ => self.error("expected `{` in const-eval statement block")
  }
  let statements : Array[ConstEvalStatement] = []
  while true {
    match self.view() {
      [RightBrace, .. rest] => {
        self.update_view(rest)
        break
      }
      [] => self.error("expected `}` in const-eval statement block")
      _ => statements.push(self.parse_statement())
    }
  }
  statements
}

///|
fn ConstEvalParser::parse_if_condition(
  self : ConstEvalParser,
) -> ConstEvalExpr raise WeslCompileError {
  match self.view() {
    [LeftParen, .. rest] => {
      self.update_view(rest)
      let expr = self.parse_expression()
      match self.view() {
        [RightParen, .. after] => self.update_view(after)
        _ => self.error("expected `)` after const-eval if condition")
      }
      expr
    }
    _ => self.parse_expression()
  }
}

///|
fn ConstEvalParser::parse_if_statement(
  self : ConstEvalParser,
) -> ConstEvalStatement raise WeslCompileError {
  let condition = self.parse_if_condition()
  let then_branch = self.parse_statement_block()
  let else_branch = match self.view() {
    [Ident("else"), Ident("if"), .. rest] => {
      self.update_view(rest)
      [self.parse_if_statement()]
    }
    [Ident("else"), .. rest] => {
      self.update_view(rest)
      self.parse_statement_block()
    }
    _ => []
  }
  ConstEvalStatement::If(condition, then_branch, else_branch)
}

///|
fn ConstEvalParser::parse_switch_selector(
  self : ConstEvalParser,
) -> ConstEvalSwitchSelector raise WeslCompileError {
  match self.view() {
    [Ident("default"), .. rest] => {
      self.update_view(rest)
      SwitchDefault
    }
    _ => SwitchExpression(self.parse_expression())
  }
}

///|
fn ConstEvalParser::parse_switch_case_body(
  self : ConstEvalParser,
) -> Array[ConstEvalStatement] raise WeslCompileError {
  match self.view() {
    [LeftBrace, ..] => self.parse_statement_block()
    _ => {
      let statements : Array[ConstEvalStatement] = []
      while true {
        match self.view() {
          [Ident("case"), ..] | [Ident("default"), ..] | [RightBrace, ..] =>
            break
          [] => self.error("expected `}` in const-eval switch body")
          _ => statements.push(self.parse_statement())
        }
      }
      statements
    }
  }
}

///|
fn ConstEvalParser::parse_switch_case(
  self : ConstEvalParser,
) -> ConstEvalSwitchCase raise WeslCompileError {
  let selectors : Array[ConstEvalSwitchSelector] = []
  match self.view() {
    [Ident("case"), .. rest] => {
      self.update_view(rest)
      while true {
        selectors.push(self.parse_switch_selector())
        match self.view() {
          [Comma, .. after_comma] => self.update_view(after_comma)
          [Colon, .. after_colon] => {
            self.update_view(after_colon)
            break
          }
          _ => self.error("expected `,` or `:` in const-eval switch case")
        }
      }
    }
    [Ident("default"), Colon, .. rest] => {
      self.update_view(rest)
      selectors.push(SwitchDefault)
    }
    _ => self.error("expected const-eval switch case")
  }
  ConstEvalSwitchCase::{ selectors, body: self.parse_switch_case_body() }
}

///|
fn ConstEvalParser::parse_switch_statement(
  self : ConstEvalParser,
) -> ConstEvalStatement raise WeslCompileError {
  let selector = self.parse_if_condition()
  match self.view() {
    [LeftBrace, .. rest] => self.update_view(rest)
    _ => self.error("expected `{` in const-eval switch body")
  }
  let cases : Array[ConstEvalSwitchCase] = []
  while true {
    match self.view() {
      [RightBrace, .. rest] => {
        self.update_view(rest)
        break
      }
      [] => self.error("expected `}` in const-eval switch body")
      _ => cases.push(self.parse_switch_case())
    }
  }
  ConstEvalStatement::Switch(selector, cases)
}

///|
fn ConstEvalParser::parse_while_statement(
  self : ConstEvalParser,
) -> ConstEvalStatement raise WeslCompileError {
  let condition = self.parse_if_condition()
  let body = self.parse_statement_block()
  ConstEvalStatement::While(condition, body)
}

///|
fn ConstEvalParser::parse_loop_statement(
  self : ConstEvalParser,
) -> ConstEvalStatement raise WeslCompileError {
  match self.view() {
    [LeftBrace, .. rest] => self.update_view(rest)
    _ => self.error("expected `{` in const-eval loop body")
  }
  let body : Array[ConstEvalStatement] = []
  let mut continuing : Array[ConstEvalStatement]? = None
  while true {
    match self.view() {
      [RightBrace, .. rest] => {
        self.update_view(rest)
        break
      }
      [Ident("continuing"), .. rest] => {
        if continuing is Some(_) {
          self.error("duplicate const-eval continuing block")
        }
        self.update_view(rest)
        continuing = Some(self.parse_statement_block())
      }
      [] => self.error("expected `}` in const-eval loop body")
      _ => body.push(self.parse_statement())
    }
  }
  ConstEvalStatement::Loop(body, continuing)
}

///|
fn ConstEvalParser::parse_binding_statement_with_terminator(
  self : ConstEvalParser,
  terminator : ConstEvalToken,
) -> ConstEvalStatement raise WeslCompileError {
  let name = match self.view() {
    [Ident(name), .. rest] => {
      self.update_view(rest)
      name
    }
    _ => self.error("expected const-eval binding name")
  }
  let declared_type = match self.view() {
    [Colon, .. rest] => {
      self.update_view(rest)
      Some(self.parse_type())
    }
    _ => None
  }
  match self.view() {
    [Equal, .. rest] => self.update_view(rest)
    _ => self.error("expected `=` in const-eval binding")
  }
  let expr = self.parse_expression()
  if !self.consume_token(terminator) {
    self.error("expected terminator after const-eval binding")
  }
  ConstEvalStatement::Binding(ConstEvalBinding::{ name, declared_type, expr })
}

///|
fn ConstEvalParser::parse_binding_statement(
  self : ConstEvalParser,
) -> ConstEvalStatement raise WeslCompileError {
  self.parse_binding_statement_with_terminator(Semi)
}

///|
fn ConstEvalParser::parse_assignment_statement_with_terminator(
  self : ConstEvalParser,
  target : ConstEvalLValue,
  terminator : ConstEvalToken,
) -> ConstEvalStatement raise WeslCompileError {
  match self.view() {
    [Equal, .. rest] => self.update_view(rest)
    _ => self.error("expected `=` in const-eval assignment")
  }
  let expr = self.parse_expression()
  if !self.consume_token(terminator) {
    self.error("expected terminator after const-eval assignment")
  }
  ConstEvalStatement::Assignment(target, expr)
}

///|
fn ConstEvalParser::parse_compound_assignment_statement_with_terminator(
  self : ConstEvalParser,
  target : ConstEvalLValue,
  op : ConstEvalBinaryOp,
  terminator : ConstEvalToken,
) -> ConstEvalStatement raise WeslCompileError {
  match self.view() {
    [Equal, .. rest] => self.update_view(rest)
    _ => self.error("expected `=` in const-eval compound assignment")
  }
  let expr = self.parse_expression()
  if !self.consume_token(terminator) {
    self.error("expected terminator after const-eval compound assignment")
  }
  ConstEvalStatement::CompoundAssignment(target, op, expr)
}

///|
fn ConstEvalParser::parse_lvalue_tail(
  self : ConstEvalParser,
  root : ConstEvalLValue,
) -> ConstEvalLValue raise WeslCompileError {
  let mut target = root
  for rest = self.view() {
    match rest {
      [Dot, Ident(name), .. next] => {
        self.update_view(next)
        target = ConstEvalLValue::Field(target, name)
        continue self.view()
      }
      [Dot, ..] =>
        self.error("expected member name after `.` in const-eval assignment")
      [LeftBracket, .. next] => {
        self.update_view(next)
        let index = self.parse_expression()
        match self.view() {
          [RightBracket, .. after] => self.update_view(after)
          _ => self.error("expected `]` in const-eval assignment target")
        }
        target = ConstEvalLValue::Element(target, index)
        continue self.view()
      }
      _ => break
    }
  }
  target
}

///|
fn ConstEvalParser::parse_lvalue(
  self : ConstEvalParser,
) -> ConstEvalLValue raise WeslCompileError {
  match self.view() {
    [Ident(name), .. rest] => {
      self.update_view(rest)
      self.parse_lvalue_tail(Root(name))
    }
    _ => self.error("expected const-eval assignment target")
  }
}

///|
fn ConstEvalParser::parse_lvalue_statement_with_terminator(
  self : ConstEvalParser,
  target : ConstEvalLValue,
  terminator : ConstEvalToken,
) -> ConstEvalStatement raise WeslCompileError {
  match self.view() {
    [Equal, ..] =>
      self.parse_assignment_statement_with_terminator(target, terminator)
    [Plus, Equal, ..] => {
      self.update_view(self.view()[1:])
      self.parse_compound_assignment_statement_with_terminator(
        target,
        Add,
        terminator,
      )
    }
    [Minus, Equal, ..] => {
      self.update_view(self.view()[1:])
      self.parse_compound_assignment_statement_with_terminator(
        target,
        Sub,
        terminator,
      )
    }
    [Star, Equal, ..] => {
      self.update_view(self.view()[1:])
      self.parse_compound_assignment_statement_with_terminator(
        target,
        Mul,
        terminator,
      )
    }
    [Slash, Equal, ..] => {
      self.update_view(self.view()[1:])
      self.parse_compound_assignment_statement_with_terminator(
        target,
        Div,
        terminator,
      )
    }
    [Percent, Equal, ..] => {
      self.update_view(self.view()[1:])
      self.parse_compound_assignment_statement_with_terminator(
        target,
        Mod,
        terminator,
      )
    }
    [Amp, Equal, ..] => {
      self.update_view(self.view()[1:])
      self.parse_compound_assignment_statement_with_terminator(
        target,
        BitAnd,
        terminator,
      )
    }
    [Pipe, Equal, ..] => {
      self.update_view(self.view()[1:])
      self.parse_compound_assignment_statement_with_terminator(
        target,
        BitOr,
        terminator,
      )
    }
    [Caret, Equal, ..] => {
      self.update_view(self.view()[1:])
      self.parse_compound_assignment_statement_with_terminator(
        target,
        BitXor,
        terminator,
      )
    }
    [LeftShift, Equal, ..] => {
      self.update_view(self.view()[1:])
      self.parse_compound_assignment_statement_with_terminator(
        target,
        Shl,
        terminator,
      )
    }
    [RightShift, Equal, ..] => {
      self.update_view(self.view()[1:])
      self.parse_compound_assignment_statement_with_terminator(
        target,
        Shr,
        terminator,
      )
    }
    [Plus, Plus, .. rest] => {
      self.update_view(rest)
      if !self.consume_token(terminator) {
        self.error("expected terminator after const-eval increment")
      }
      ConstEvalStatement::Increment(target)
    }
    [Minus, Minus, .. rest] => {
      self.update_view(rest)
      if !self.consume_token(terminator) {
        self.error("expected terminator after const-eval decrement")
      }
      ConstEvalStatement::Decrement(target)
    }
    _ => self.error("expected const-eval assignment statement")
  }
}

///|
fn ConstEvalParser::parse_for_init(
  self : ConstEvalParser,
) -> ConstEvalStatement? raise WeslCompileError {
  match self.view() {
    [Semi, .. rest] => {
      self.update_view(rest)
      None
    }
    [Ident("let"), .. rest] => {
      self.update_view(rest)
      Some(self.parse_binding_statement_with_terminator(Semi))
    }
    [Ident("var"), .. rest] => {
      self.update_view(rest)
      Some(self.parse_binding_statement_with_terminator(Semi))
    }
    [Ident(_), ..] => {
      let target = self.parse_lvalue()
      Some(self.parse_lvalue_statement_with_terminator(target, Semi))
    }
    _ => self.error("expected const-eval for-loop initializer")
  }
}

///|
fn ConstEvalParser::parse_for_update(
  self : ConstEvalParser,
) -> ConstEvalStatement? raise WeslCompileError {
  match self.view() {
    [RightParen, ..] => None
    [Ident(_), ..] => {
      let target = self.parse_lvalue()
      Some(self.parse_lvalue_statement_with_terminator(target, RightParen))
    }
    _ => self.error("expected const-eval for-loop update")
  }
}

///|
fn ConstEvalParser::parse_for_statement(
  self : ConstEvalParser,
) -> ConstEvalStatement raise WeslCompileError {
  match self.view() {
    [LeftParen, .. rest] => self.update_view(rest)
    _ => self.error("expected `(` after const-eval for")
  }
  let initializer : ConstEvalStatement? = self.parse_for_init()
  let condition : ConstEvalExpr? = match self.view() {
    [Semi, .. rest] => {
      self.update_view(rest)
      None
    }
    _ => {
      let expr = self.parse_expression()
      match self.view() {
        [Semi, .. rest] => self.update_view(rest)
        _ => self.error("expected `;` after const-eval for-loop condition")
      }
      Some(expr)
    }
  }
  let update : ConstEvalStatement? = self.parse_for_update()
  match self.view() {
    [RightParen, .. rest] => self.update_view(rest)
    _ => ()
  }
  let body = self.parse_statement_block()
  ConstEvalStatement::For(initializer, condition, update, body)
}

///|
fn ConstEvalParser::parse_param(
  self : ConstEvalParser,
) -> ConstEvalParam raise WeslCompileError {
  let name = match self.view() {
    [Ident(name), .. rest] => {
      self.update_view(rest)
      name
    }
    _ => self.error("expected const-eval parameter name")
  }
  match self.view() {
    [Colon, .. rest] => self.update_view(rest)
    _ => self.error("expected `:` in const-eval parameter")
  }
  ConstEvalParam::{ name, declared_type: self.parse_type() }
}

///|
fn ConstEvalParser::parse_params(
  self : ConstEvalParser,
) -> Array[ConstEvalParam] raise WeslCompileError {
  match self.view() {
    [LeftParen, .. rest] => self.update_view(rest)
    _ => self.error("expected `(` in const-eval function")
  }
  let params : Array[ConstEvalParam] = []
  if self.view() is [RightParen, .. after_empty] {
    self.update_view(after_empty)
    return params
  }
  while true {
    params.push(self.parse_param())
    match self.view() {
      [Comma, RightParen, .. after_trailing] => {
        self.update_view(after_trailing)
        break
      }
      [Comma, .. after_comma] => self.update_view(after_comma)
      [RightParen, .. after_paren] => {
        self.update_view(after_paren)
        break
      }
      _ => self.error("expected `,` or `)` in const-eval parameter list")
    }
  }
  params
}

///|
fn ConstEvalParser::parse_statement(
  self : ConstEvalParser,
) -> ConstEvalStatement raise WeslCompileError {
  match self.view() {
    [Ident("let"), .. rest] => {
      self.update_view(rest)
      self.parse_binding_statement()
    }
    [Ident("var"), .. rest] => {
      self.update_view(rest)
      self.parse_binding_statement()
    }
    [Ident("if"), .. rest] => {
      self.update_view(rest)
      self.parse_if_statement()
    }
    [Ident("switch"), .. rest] => {
      self.update_view(rest)
      self.parse_switch_statement()
    }
    [Ident("while"), .. rest] => {
      self.update_view(rest)
      self.parse_while_statement()
    }
    [Ident("loop"), .. rest] => {
      self.update_view(rest)
      self.parse_loop_statement()
    }
    [Ident("for"), .. rest] => {
      self.update_view(rest)
      self.parse_for_statement()
    }
    [Ident("break"), Ident("if"), .. rest] => {
      self.update_view(rest)
      let expr = self.parse_expression()
      match self.view() {
        [Semi, .. after_semi] => self.update_view(after_semi)
        _ => self.error("expected `;` after const-eval break-if")
      }
      ConstEvalStatement::BreakIf(expr)
    }
    [Ident("break"), Semi, .. rest] => {
      self.update_view(rest)
      ConstEvalStatement::Break
    }
    [Ident("continue"), Semi, .. rest] => {
      self.update_view(rest)
      ConstEvalStatement::Continue
    }
    [Ident("return"), .. rest] => {
      self.update_view(rest)
      if self.view() is [Semi, .. after_semi] {
        self.update_view(after_semi)
        return ConstEvalStatement::ReturnVoid
      }
      let expr = self.parse_expression()
      match self.view() {
        [Semi, .. after_semi] => self.update_view(after_semi)
        _ => self.error("expected `;` after const-eval return")
      }
      ConstEvalStatement::Return(expr)
    }
    [Ident(_), ..] => {
      let target = self.parse_lvalue()
      self.parse_lvalue_statement_with_terminator(target, Semi)
    }
    _ => self.error("expected const-eval statement")
  }
}

///|
fn ConstEvalParser::parse_function(
  self : ConstEvalParser,
) -> ConstEvalFunction raise WeslCompileError {
  let mut has_const = false
  for rest = self.view() {
    match rest {
      [At, Ident(name), .. next] => {
        if name == "const" {
          has_const = true
        }
        continue next
      }
      rest => {
        self.update_view(rest)
        break
      }
    }
  }
  if !has_const {
    raise WeslCompileError::Validation("expected `@const` function")
  }
  match self.view() {
    [Ident("fn"), .. rest] => self.update_view(rest)
    _ => self.error("expected `fn` in const-eval source")
  }
  let name = match self.view() {
    [Ident(name), .. rest] => {
      self.update_view(rest)
      name
    }
    _ => self.error("expected const-eval function name")
  }
  let params = self.parse_params()
  match self.view() {
    [Arrow, .. rest] => self.update_view(rest)
    _ => self.error("expected `->` in const-eval function")
  }
  let return_type = self.parse_type()
  match self.view() {
    [LeftBrace, .. rest] => self.update_view(rest)
    _ => self.error("expected `{` in const-eval function")
  }
  let statements : Array[ConstEvalStatement] = []
  while !(self.view() is [RightBrace, ..]) {
    statements.push(self.parse_statement())
  }
  match self.view() {
    [RightBrace, .. rest] => self.update_view(rest)
    _ => self.error("expected `}` in const-eval function")
  }
  if !self.view().is_empty() {
    self.error("unexpected trailing const-eval tokens")
  }
  ConstEvalFunction::{ name, params, return_type, statements }
}

///|
priv enum ConstEvalValue {
  Bool(Bool)
  AbstractInt(Int64)
  AbstractFloat(Double, Bool)
  I32(Int64)
  U32(Int64)
  F32(Float)
  Vector(Int, ConstEvalType, Array[ConstEvalValue])
  Matrix(Int, Int, ConstEvalType, Array[ConstEvalValue])
  Array(ConstEvalType, Int?, Array[ConstEvalValue])
  Struct(String, Array[(String, ConstEvalValue)])
  FrexpAbstract(Double, Int64)
  FrexpF32(Float, Int64)
}

///|
priv struct ConstEvalContext {
  bindings : @hashmap.HashMap[String, ConstEvalValue]
  functions : @hashmap.HashMap[String, ConstEvalFunction]
}

///|
fn ConstEvalContext::new() -> ConstEvalContext {
  ConstEvalContext::{
    bindings: @hashmap.HashMap([]),
    functions: @hashmap.HashMap([]),
  }
}

///|
fn const_eval_clone_bindings(
  bindings : @hashmap.HashMap[String, ConstEvalValue],
) -> @hashmap.HashMap[String, ConstEvalValue] {
  let copy : @hashmap.HashMap[String, ConstEvalValue] = @hashmap.HashMap([])
  for entry in bindings.iter() {
    let (name, value) = entry
    copy.set(name, value)
  }
  copy
}

///|
fn ConstEvalContext::new_call_scope(
  self : ConstEvalContext,
) -> ConstEvalContext {
  ConstEvalContext::{
    bindings: const_eval_clone_bindings(self.bindings),
    functions: self.functions,
  }
}

///|
fn ConstEvalValue::value_type(self : ConstEvalValue) -> ConstEvalType {
  match self {
    Bool(_) => ConstEvalType::Bool
    AbstractInt(_) => ConstEvalType::AbstractInt
    AbstractFloat(_, _) => ConstEvalType::AbstractFloat
    I32(_) => ConstEvalType::I32
    U32(_) => ConstEvalType::U32
    F32(_) => ConstEvalType::F32
    Vector(width, element, _) => ConstEvalType::Vector(width, element)
    Matrix(columns, rows, element, _) =>
      ConstEvalType::Matrix(columns, rows, element)
    Array(element, count, _) => ConstEvalType::Array(element, count)
    Struct(name, _) => ConstEvalType::Struct(name)
    FrexpAbstract(_, _) => ConstEvalType::FrexpAbstractResult
    FrexpF32(_, _) => ConstEvalType::FrexpF32Result
  }
}

///|
fn ConstEvalType::label(self : ConstEvalType) -> String {
  match self {
    AbstractInt => "AbstractInt"
    AbstractFloat => "AbstractFloat"
    Bool => "bool"
    Void => "void"
    I32 => "i32"
    U32 => "u32"
    F32 => "f32"
    Vector(width, element) => "vec\{width}<\{element.label()}>"
    Matrix(columns, rows, element) =>
      "mat\{columns}x\{rows}<\{element.label()}>"
    Array(element, Some(count)) => "array<\{element.label()}, \{count}>"
    Array(element, None) => "array<\{element.label()}>"
    Struct(name) => name
    FrexpAbstractResult => "__frexp_result_abstract"
    FrexpF32Result => "__frexp_result_f32"
  }
}

///|
fn ConstEvalBinaryOp::symbol(self : ConstEvalBinaryOp) -> String {
  match self {
    Add => "+"
    Sub => "-"
    Mul => "*"
    Div => "/"
    Mod => "%"
    Eq => "=="
    Ne => "!="
    Lt => "<"
    Le => "<="
    Gt => ">"
    Ge => ">="
    Shl => "<<"
    Shr => ">>"
    BitAnd => "&"
    BitOr => "|"
    BitXor => "^"
    LogicalAnd => "&&"
    LogicalOr => "||"
  }
}

///|
fn const_eval_remove_underscores(text : String) -> String {
  let parts : Array[String] = []
  for i = 0; i < text.length(); i = i + 1 {
    if text.code_unit_at(i).to_int() != 95 {
      parts.push(text[i:i + 1].to_owned())
    }
  }
  parts.join("")
}

///|
fn const_eval_is_hex_digit(code : Int) -> Bool {
  const_eval_is_digit(code) ||
  (code >= 65 && code <= 70) ||
  (code >= 97 && code <= 102)
}

///|
fn const_eval_hex_digit_value(code : Int) -> Int raise WeslCompileError {
  if const_eval_is_digit(code) {
    return code - 48
  }
  if code >= 65 && code <= 70 {
    return code - 55
  }
  if code >= 97 && code <= 102 {
    return code - 87
  }
  raise WeslCompileError::Validation("invalid hex digit")
}

///|
fn const_eval_parse_integer_literal(
  text : String,
) -> Int64 raise WeslCompileError {
  let normalized = const_eval_remove_underscores(text)
  if normalized.length() >= 2 &&
    (normalized[:2].to_owned() == "0x" || normalized[:2].to_owned() == "0X") {
    let digits = normalized[2:normalized.length()].to_owned()
    return @string.parse_int64(digits[:], base=16) catch {
      _ =>
        raise WeslCompileError::Validation("invalid integer literal `\{text}`")
    }
  }
  @string.parse_int64(normalized[:], base=10) catch {
    _ => raise WeslCompileError::Validation("invalid integer literal `\{text}`")
  }
}

///|
fn const_eval_parse_array_count(text : String) -> Int raise WeslCompileError {
  let normalized = if text.has_suffix("u") || text.has_suffix("i") {
    text[:text.length() - 1].to_owned()
  } else {
    text
  }
  let value = const_eval_parse_integer_literal(normalized)
  if value <= 0L || value > 2147483647L {
    raise WeslCompileError::Validation("invalid array count `\{text}`")
  }
  value.to_int()
}

///|
fn const_eval_matrix_dimension(text : String) -> Int raise WeslCompileError {
  let value = const_eval_parse_integer_literal(text)
  if value < 2L || value > 4L {
    raise WeslCompileError::Validation("invalid matrix dimension `\{text}`")
  }
  value.to_int()
}

///|
fn const_eval_parse_hex_float_literal(
  text : String,
) -> Double raise WeslCompileError {
  let normalized = const_eval_remove_underscores(text)
  guard normalized.length() >= 3 &&
    (normalized[:2].to_owned() == "0x" || normalized[:2].to_owned() == "0X") else {
    raise WeslCompileError::Validation("invalid float literal `\{text}`")
  }
  let body = normalized[2:normalized.length()].to_owned()
  let exponent_index = match body.find("p") {
    Some(index) => index
    None =>
      match body.find("P") {
        Some(index) => index
        None =>
          raise WeslCompileError::Validation("invalid float literal `\{text}`")
      }
  }
  let mantissa = body[:exponent_index].to_owned()
  let exponent = @string.parse_int(
    body[exponent_index + 1:body.length()],
    base=10,
  ) catch {
    _ => raise WeslCompileError::Validation("invalid float literal `\{text}`")
  }
  let dot_index = mantissa.find(".")
  let integer_text = match dot_index {
    Some(index) => mantissa[:index].to_owned()
    None => mantissa
  }
  let fraction_text = match dot_index {
    Some(index) => mantissa[index + 1:mantissa.length()].to_owned()
    None => ""
  }
  let mut value = if integer_text == "" {
    0.0
  } else {
    const_eval_parse_integer_literal("0x\{integer_text}").to_double()
  }
  let mut factor = 1.0 / 16.0
  for i = 0; i < fraction_text.length(); i = i + 1 {
    let code = fraction_text.code_unit_at(i).to_int()
    if !const_eval_is_hex_digit(code) {
      raise WeslCompileError::Validation("invalid float literal `\{text}`")
    }
    value = value + const_eval_hex_digit_value(code).to_double() * factor
    factor = factor / 16.0
  }
  if exponent >= 0 {
    for _ in 0..<exponent {
      value = value * 2.0
    }
  } else {
    for _ in 0..<-exponent {
      value = value / 2.0
    }
  }
  value
}

///|
fn const_eval_parse_double_literal(
  text : String,
) -> Double raise WeslCompileError {
  let normalized = const_eval_remove_underscores(text)
  let parsed = try @string.parse_double(normalized[:]) catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  match parsed {
    Ok(value) => value
    Err(_) =>
      if normalized.length() >= 2 &&
        (normalized[:2].to_owned() == "0x" || normalized[:2].to_owned() == "0X") {
        const_eval_parse_hex_float_literal(normalized)
      } else {
        raise WeslCompileError::Validation("invalid float literal `\{text}`")
      }
  }
}

///|
fn const_eval_exact_f32_from_double(
  text : String,
  value : Double,
) -> Float raise WeslCompileError {
  let narrowed = Float::from_double(value)
  if Float::is_inf(narrowed) || Float::is_nan(narrowed) {
    raise WeslCompileError::Validation("f32 literal out of range `\{text}`")
  }
  if narrowed.to_double() != value {
    raise WeslCompileError::Validation("f32 literal loses precision `\{text}`")
  }
  narrowed
}

///|
fn const_eval_rounded_f32_from_double(
  text : String,
  value : Double,
) -> Float raise WeslCompileError {
  let narrowed = Float::from_double(value)
  if Float::is_inf(narrowed) || Float::is_nan(narrowed) {
    raise WeslCompileError::Validation("f32 literal out of range `\{text}`")
  }
  narrowed
}

///|
fn const_eval_parse_literal(
  text : String,
) -> ConstEvalValue raise WeslCompileError {
  if text.length() == 0 {
    raise WeslCompileError::Validation("empty literal")
  }
  match text {
    "true" => return ConstEvalValue::Bool(true)
    "false" => return ConstEvalValue::Bool(false)
    _ => ()
  }
  let is_hex = text.length() >= 2 &&
    (text[:2].to_owned() == "0x" || text[:2].to_owned() == "0X")
  if text.contains(".") || text.contains("p") || text.contains("P") {
    let float_text = match text[text.length() - 1:text.length()].to_owned() {
      "f" => text[:text.length() - 1].to_owned()
      _ => text
    }
    let value = const_eval_parse_double_literal(float_text)
    return match text[text.length() - 1:text.length()].to_owned() {
      "f" =>
        ConstEvalValue::F32(const_eval_rounded_f32_from_double(text, value))
      _ => {
        let f32_lossless = if is_hex {
          Float::from_double(value).to_double() == value
        } else {
          true
        }
        ConstEvalValue::AbstractFloat(value, f32_lossless)
      }
    }
  }
  if is_hex {
    return ConstEvalValue::AbstractInt(const_eval_parse_integer_literal(text))
  }
  let suffix = text[text.length() - 1:text.length()].to_owned()
  match suffix {
    "u" =>
      ConstEvalValue::U32(
        const_eval_require_u32(
          ConstEvalValue::AbstractInt(
            const_eval_parse_integer_literal(
              text[:text.length() - 1].to_owned(),
            ),
          ),
          text,
        ),
      )
    "i" =>
      ConstEvalValue::I32(
        const_eval_require_i32(
          ConstEvalValue::AbstractInt(
            const_eval_parse_integer_literal(
              text[:text.length() - 1].to_owned(),
            ),
          ),
          text,
        ),
      )
    "f" => {
      let value = const_eval_parse_double_literal(
        text[:text.length() - 1].to_owned(),
      )
      ConstEvalValue::F32(const_eval_rounded_f32_from_double(text, value))
    }
    _ => ConstEvalValue::AbstractInt(const_eval_parse_integer_literal(text))
  }
}

///|
fn const_eval_require_i32(
  value : ConstEvalValue,
  context : String,
) -> Int64 raise WeslCompileError {
  match value {
    Bool(_) =>
      raise WeslCompileError::Validation(
        "cannot convert bool to i32 in \{context}",
      )
    AbstractInt(number) =>
      if number < CONST_EVAL_I32_MIN || number > CONST_EVAL_I32_MAX {
        raise WeslCompileError::Validation(
          "value out of range for i32 in \{context}",
        )
      } else {
        number
      }
    I32(number) => number
    U32(number) =>
      if number > CONST_EVAL_I32_MAX {
        raise WeslCompileError::Validation(
          "value out of range for i32 in \{context}",
        )
      } else {
        number
      }
    AbstractFloat(_, _) =>
      raise WeslCompileError::Validation(
        "cannot convert abstract float to i32 in \{context}",
      )
    F32(_) =>
      raise WeslCompileError::Validation(
        "cannot convert f32 to i32 in \{context}",
      )
    FrexpAbstract(_, _) | FrexpF32(_, _) =>
      raise WeslCompileError::Validation(
        "cannot convert frexp result to i32 in \{context}",
      )
    Struct(_, _) =>
      raise WeslCompileError::Validation(
        "cannot convert struct to i32 in \{context}",
      )
    Matrix(_, _, _, _) =>
      raise WeslCompileError::Validation(
        "cannot convert matrix to i32 in \{context}",
      )
    Array(_, _, _) =>
      raise WeslCompileError::Validation(
        "cannot convert array to i32 in \{context}",
      )
    Vector(_, _, _) =>
      raise WeslCompileError::Validation(
        "cannot convert vector to i32 in \{context}",
      )
  }
}

///|
fn const_eval_require_u32(
  value : ConstEvalValue,
  context : String,
) -> Int64 raise WeslCompileError {
  match value {
    Bool(_) =>
      raise WeslCompileError::Validation(
        "cannot convert bool to u32 in \{context}",
      )
    AbstractInt(number) =>
      if number < 0 || number > CONST_EVAL_U32_MAX {
        raise WeslCompileError::Validation(
          "value out of range for u32 in \{context}",
        )
      } else {
        number
      }
    U32(number) => number
    I32(number) =>
      if number < 0 {
        raise WeslCompileError::Validation(
          "value out of range for u32 in \{context}",
        )
      } else {
        number
      }
    AbstractFloat(_, _) =>
      raise WeslCompileError::Validation(
        "cannot convert abstract float to u32 in \{context}",
      )
    F32(_) =>
      raise WeslCompileError::Validation(
        "cannot convert f32 to u32 in \{context}",
      )
    FrexpAbstract(_, _) | FrexpF32(_, _) =>
      raise WeslCompileError::Validation(
        "cannot convert frexp result to u32 in \{context}",
      )
    Struct(_, _) =>
      raise WeslCompileError::Validation(
        "cannot convert struct to u32 in \{context}",
      )
    Matrix(_, _, _, _) =>
      raise WeslCompileError::Validation(
        "cannot convert matrix to u32 in \{context}",
      )
    Array(_, _, _) =>
      raise WeslCompileError::Validation(
        "cannot convert array to u32 in \{context}",
      )
    Vector(_, _, _) =>
      raise WeslCompileError::Validation(
        "cannot convert vector to u32 in \{context}",
      )
  }
}

///|
fn const_eval_require_f32(
  value : ConstEvalValue,
  context : String,
) -> Float raise WeslCompileError {
  match value {
    Bool(_) =>
      raise WeslCompileError::Validation(
        "cannot convert bool to f32 in \{context}",
      )
    AbstractInt(number) =>
      const_eval_exact_f32_from_double(context, number.to_double())
    AbstractFloat(number, f32_lossless) =>
      if f32_lossless {
        const_eval_rounded_f32_from_double(context, number)
      } else {
        const_eval_exact_f32_from_double(context, number)
      }
    F32(number) => number
    I32(_) =>
      raise WeslCompileError::Validation(
        "cannot convert i32 to f32 in \{context}",
      )
    U32(_) =>
      raise WeslCompileError::Validation(
        "cannot convert u32 to f32 in \{context}",
      )
    FrexpAbstract(_, _) | FrexpF32(_, _) =>
      raise WeslCompileError::Validation(
        "cannot convert frexp result to f32 in \{context}",
      )
    Struct(_, _) =>
      raise WeslCompileError::Validation(
        "cannot convert struct to f32 in \{context}",
      )
    Matrix(_, _, _, _) =>
      raise WeslCompileError::Validation(
        "cannot convert matrix to f32 in \{context}",
      )
    Array(_, _, _) =>
      raise WeslCompileError::Validation(
        "cannot convert array to f32 in \{context}",
      )
    Vector(_, _, _) =>
      raise WeslCompileError::Validation(
        "cannot convert vector to f32 in \{context}",
      )
  }
}

///|
fn const_eval_require_bool(
  value : ConstEvalValue,
  context : String,
) -> Bool raise WeslCompileError {
  match value {
    Bool(value) => value
    _ =>
      raise WeslCompileError::Validation(
        "cannot convert non-bool to bool in \{context}",
      )
  }
}

///|
fn const_eval_require_abstract_int(
  value : ConstEvalValue,
  context : String,
) -> Int64 raise WeslCompileError {
  match value {
    AbstractInt(number) => number
    _ =>
      raise WeslCompileError::Validation(
        "cannot convert non-abstract-int to abstract int in \{context}",
      )
  }
}

///|
fn const_eval_convert_to_type(
  value : ConstEvalValue,
  target : ConstEvalType,
  context : String,
) -> ConstEvalValue raise WeslCompileError {
  match target {
    AbstractInt => value
    AbstractFloat => value
    Void =>
      raise WeslCompileError::Validation(
        "cannot convert value to void in \{context}",
      )
    Bool => ConstEvalValue::Bool(const_eval_require_bool(value, context))
    I32 => ConstEvalValue::I32(const_eval_require_i32(value, context))
    U32 => ConstEvalValue::U32(const_eval_require_u32(value, context))
    F32 => ConstEvalValue::F32(const_eval_require_f32(value, context))
    Vector(width, element) =>
      match value {
        Vector(value_width, _, elements) =>
          if value_width != width || elements.length() != width {
            raise WeslCompileError::Validation(
              "cannot convert vector width in \{context}",
            )
          } else {
            let converted : Array[ConstEvalValue] = []
            for element_value in elements {
              converted.push(
                const_eval_convert_to_type(element_value, element, context),
              )
            }
            ConstEvalValue::Vector(width, element, converted)
          }
        _ =>
          raise WeslCompileError::Validation(
            "cannot convert non-vector to vec\{width}<\{element.label()}> in \{context}",
          )
      }
    Matrix(columns, rows, element) =>
      match value {
        Matrix(value_columns, value_rows, _, columns_values) =>
          if value_columns != columns ||
            value_rows != rows ||
            columns_values.length() != columns {
            raise WeslCompileError::Validation(
              "cannot convert matrix dimensions in \{context}",
            )
          } else {
            let converted : Array[ConstEvalValue] = []
            for column in columns_values {
              converted.push(
                const_eval_convert_to_type(
                  column,
                  ConstEvalType::Vector(rows, element),
                  context,
                ),
              )
            }
            ConstEvalValue::Matrix(columns, rows, element, converted)
          }
        _ =>
          raise WeslCompileError::Validation(
            "cannot convert non-matrix to mat\{columns}x\{rows}<\{element.label()}> in \{context}",
          )
      }
    Array(element, count) =>
      match value {
        Array(_, value_count, elements) =>
          if count != None && value_count != count {
            raise WeslCompileError::Validation(
              "cannot convert array count in \{context}",
            )
          } else {
            let converted : Array[ConstEvalValue] = []
            for element_value in elements {
              converted.push(
                const_eval_convert_to_type(element_value, element, context),
              )
            }
            ConstEvalValue::Array(element, count, converted)
          }
        _ =>
          raise WeslCompileError::Validation(
            "cannot convert non-array to \{target.label()} in \{context}",
          )
      }
    Struct(name) =>
      match value {
        Struct(value_name, fields) =>
          if value_name == name {
            ConstEvalValue::Struct(name, fields)
          } else {
            raise WeslCompileError::Validation(
              "cannot convert struct `\{value_name}` to `\{name}` in \{context}",
            )
          }
        _ =>
          raise WeslCompileError::Validation(
            "cannot convert non-struct to `\{name}` in \{context}",
          )
      }
    FrexpAbstractResult | FrexpF32Result => value
  }
}

///|
fn const_eval_unary_neg(
  value : ConstEvalValue,
) -> ConstEvalValue raise WeslCompileError {
  match value {
    Bool(_) => raise WeslCompileError::Validation("cannot negate bool literal")
    AbstractInt(number) => ConstEvalValue::AbstractInt(-number)
    AbstractFloat(number, f32_lossless) =>
      ConstEvalValue::AbstractFloat(-number, f32_lossless)
    I32(number) => ConstEvalValue::I32(-number)
    U32(_) => raise WeslCompileError::Validation("cannot negate u32 literal")
    F32(number) => ConstEvalValue::F32(-number)
    FrexpAbstract(_, _) | FrexpF32(_, _) =>
      raise WeslCompileError::Validation("cannot negate frexp result")
    Struct(_, _) => raise WeslCompileError::Validation("cannot negate struct")
    Matrix(_, _, _, _) =>
      raise WeslCompileError::Validation("cannot negate matrix")
    Array(_, _, _) => raise WeslCompileError::Validation("cannot negate array")
    Vector(width, _, elements) => {
      let values : Array[ConstEvalValue] = []
      for element in elements {
        values.push(const_eval_unary_neg(element))
      }
      const_eval_vector_from_elements(width, values, "unary negation")
    }
  }
}

///|
fn const_eval_unary_not(
  value : ConstEvalValue,
) -> ConstEvalValue raise WeslCompileError {
  match value {
    Vector(width, _, elements) => {
      let values : Array[ConstEvalValue] = []
      for element in elements {
        values.push(const_eval_unary_not(element))
      }
      const_eval_vector_from_elements(width, values, "logical not")
    }
    _ => ConstEvalValue::Bool(!const_eval_require_bool(value, "logical not"))
  }
}

///|
fn const_eval_unary_bit_not(
  value : ConstEvalValue,
) -> ConstEvalValue raise WeslCompileError {
  match value {
    Bool(_) =>
      raise WeslCompileError::Validation(
        "cannot use unary operator `~` on type `bool`",
      )
    AbstractInt(number) => ConstEvalValue::AbstractInt(number.lnot())
    I32(number) =>
      ConstEvalValue::I32(
        const_eval_require_i32(
          ConstEvalValue::AbstractInt(number.lnot()),
          "bitwise complement",
        ),
      )
    U32(number) => ConstEvalValue::U32(CONST_EVAL_U32_MAX - number)
    AbstractFloat(_, _) =>
      raise WeslCompileError::Validation(
        "cannot use unary operator `~` on type `AbstractFloat`",
      )
    F32(_) =>
      raise WeslCompileError::Validation(
        "cannot use unary operator `~` on type `f32`",
      )
    FrexpAbstract(_, _) | FrexpF32(_, _) =>
      raise WeslCompileError::Validation(
        "cannot use unary operator `~` on type `frexp result`",
      )
    Struct(_, _) =>
      raise WeslCompileError::Validation(
        "cannot use unary operator `~` on struct type",
      )
    Matrix(_, _, _, _) | Array(_, _, _) =>
      raise WeslCompileError::Validation(
        "cannot use unary operator `~` on aggregate type",
      )
    Vector(width, _, elements) => {
      let values : Array[ConstEvalValue] = []
      for element in elements {
        values.push(const_eval_unary_bit_not(element))
      }
      const_eval_vector_from_elements(width, values, "bitwise complement")
    }
  }
}

///|
fn const_eval_to_abstract_float(
  value : ConstEvalValue,
  context : String,
) -> Double raise WeslCompileError {
  match value {
    Bool(_) =>
      raise WeslCompileError::Validation(
        "cannot use bool with abstract float in \{context}",
      )
    AbstractInt(number) => number.to_double()
    AbstractFloat(number, _) => number
    F32(number) => number.to_double()
    I32(_) =>
      raise WeslCompileError::Validation(
        "cannot use i32 with abstract float in \{context}",
      )
    U32(_) =>
      raise WeslCompileError::Validation(
        "cannot use u32 with abstract float in \{context}",
      )
    FrexpAbstract(_, _) | FrexpF32(_, _) =>
      raise WeslCompileError::Validation(
        "cannot use frexp result with abstract float in \{context}",
      )
    Struct(_, _) =>
      raise WeslCompileError::Validation(
        "cannot use struct with abstract float in \{context}",
      )
    Matrix(_, _, _, _) | Array(_, _, _) =>
      raise WeslCompileError::Validation(
        "cannot use aggregate with abstract float in \{context}",
      )
    Vector(_, _, _) =>
      raise WeslCompileError::Validation(
        "cannot use vector with abstract float in \{context}",
      )
  }
}

///|
fn const_eval_binary_int(
  op : ConstEvalBinaryOp,
  lhs : Int64,
  rhs : Int64,
) -> Int64 raise WeslCompileError {
  match op {
    Add => lhs + rhs
    Sub => lhs - rhs
    Mul => lhs * rhs
    Div => lhs / rhs
    Mod => lhs % rhs
    _ =>
      raise WeslCompileError::Validation(
        "unsupported integer arithmetic operator `\{op.symbol()}`",
      )
  }
}

///|
fn const_eval_binary_float(
  op : ConstEvalBinaryOp,
  lhs : Float,
  rhs : Float,
) -> Float raise WeslCompileError {
  match op {
    Add => lhs + rhs
    Sub => lhs - rhs
    Mul => lhs * rhs
    Div => lhs / rhs
    Mod => lhs - (lhs / rhs).trunc() * rhs
    _ =>
      raise WeslCompileError::Validation(
        "unsupported f32 arithmetic operator `\{op.symbol()}`",
      )
  }
}

///|
fn const_eval_binary_abstract_float(
  op : ConstEvalBinaryOp,
  lhs : Double,
  rhs : Double,
) -> Double raise WeslCompileError {
  match op {
    Add => lhs + rhs
    Sub => lhs - rhs
    Mul => lhs * rhs
    Div => lhs / rhs
    Mod => lhs - (lhs / rhs).trunc() * rhs
    _ =>
      raise WeslCompileError::Validation(
        "unsupported abstract float arithmetic operator `\{op.symbol()}`",
      )
  }
}

///|
fn const_eval_bitwise_int(
  op : ConstEvalBinaryOp,
  lhs : Int64,
  rhs : Int64,
) -> Int64 raise WeslCompileError {
  match op {
    BitAnd => lhs & rhs
    BitOr => lhs | rhs
    BitXor => lhs ^ rhs
    _ =>
      raise WeslCompileError::Validation(
        "unsupported integer bitwise operator `\{op.symbol()}`",
      )
  }
}

///|
fn const_eval_shift_count(
  value : ConstEvalValue,
  context : String,
) -> Int raise WeslCompileError {
  let count = const_eval_require_u32(value, context)
  if count >= 64 {
    raise WeslCompileError::Validation("shift count out of range in \{context}")
  }
  count.to_int()
}

///|
fn const_eval_shift_int(
  op : ConstEvalBinaryOp,
  lhs : Int64,
  rhs : ConstEvalValue,
) -> Int64 raise WeslCompileError {
  let count = const_eval_shift_count(rhs, "shift expression")
  match op {
    Shl => lhs << count
    Shr => lhs >> count
    _ =>
      raise WeslCompileError::Validation(
        "unsupported shift operator `\{op.symbol()}`",
      )
  }
}

///|
fn const_eval_bool_order(value : Bool) -> Int {
  if value {
    1
  } else {
    0
  }
}

///|
fn const_eval_compare_int(
  op : ConstEvalBinaryOp,
  lhs : Int64,
  rhs : Int64,
) -> Bool raise WeslCompileError {
  match op {
    Eq => lhs == rhs
    Ne => lhs != rhs
    Lt => lhs < rhs
    Le => lhs <= rhs
    Gt => lhs > rhs
    Ge => lhs >= rhs
    _ =>
      raise WeslCompileError::Validation(
        "unsupported comparison operator `\{op.symbol()}`",
      )
  }
}

///|
fn const_eval_compare_float(
  op : ConstEvalBinaryOp,
  lhs : Double,
  rhs : Double,
) -> Bool raise WeslCompileError {
  match op {
    Eq => lhs == rhs
    Ne => lhs != rhs
    Lt => lhs < rhs
    Le => lhs <= rhs
    Gt => lhs > rhs
    Ge => lhs >= rhs
    _ =>
      raise WeslCompileError::Validation(
        "unsupported comparison operator `\{op.symbol()}`",
      )
  }
}

///|
fn const_eval_compare_bool(
  op : ConstEvalBinaryOp,
  lhs : Bool,
  rhs : Bool,
) -> Bool raise WeslCompileError {
  let left = const_eval_bool_order(lhs)
  let right = const_eval_bool_order(rhs)
  match op {
    Eq => lhs == rhs
    Ne => lhs != rhs
    Lt => left < right
    Le => left <= right
    Gt => left > right
    Ge => left >= right
    _ =>
      raise WeslCompileError::Validation(
        "unsupported comparison operator `\{op.symbol()}`",
      )
  }
}

///|
fn const_eval_binary_type_error(
  op : ConstEvalBinaryOp,
  lhs : ConstEvalValue,
  rhs : ConstEvalValue,
) -> ConstEvalValue raise WeslCompileError {
  raise WeslCompileError::Validation(
    "cannot use binary operator `\{op.symbol()}` with operands `\{lhs.value_type().label()}` and `\{rhs.value_type().label()}`",
  )
}

///|
fn const_eval_vector_width_of(value : ConstEvalValue) -> Int? {
  match value {
    Vector(width, _, _) => Some(width)
    _ => None
  }
}

///|
fn const_eval_vector_component(
  value : ConstEvalValue,
  index : Int,
) -> ConstEvalValue {
  match value {
    Vector(_, _, elements) => elements[index]
    _ => value
  }
}

///|
fn const_eval_swizzle_component(part : String) -> (Int, String)? {
  match part {
    "x" => Some((0, "position"))
    "y" => Some((1, "position"))
    "z" => Some((2, "position"))
    "w" => Some((3, "position"))
    "r" => Some((0, "color"))
    "g" => Some((1, "color"))
    "b" => Some((2, "color"))
    "a" => Some((3, "color"))
    _ => None
  }
}

///|
fn const_eval_vector_access(
  width : Int,
  element : ConstEvalType,
  elements : Array[ConstEvalValue],
  name : String,
) -> ConstEvalValue raise WeslCompileError {
  if name.length() == 0 || name.length() > 4 {
    raise WeslCompileError::Validation("invalid vector swizzle `\{name}`")
  }
  let values : Array[ConstEvalValue] = []
  let mut swizzle_space : String? = None
  for index in 0..<name.length() {
    let part = name[index:index + 1].to_owned()
    let (component, part_namespace) = match const_eval_swizzle_component(part) {
      Some(value) => value
      None =>
        raise WeslCompileError::Validation("invalid vector swizzle `\{name}`")
    }
    match swizzle_space {
      Some(current) =>
        if current != part_namespace {
          raise WeslCompileError::Validation(
            "cannot mix vector swizzle namespaces in `\{name}`",
          )
        }
      None => swizzle_space = Some(part_namespace)
    }
    if component >= width {
      raise WeslCompileError::Validation(
        "vector swizzle `\{name}` is out of bounds for vec\{width}",
      )
    }
    values.push(elements[component])
  }
  if values.length() == 1 {
    values[0]
  } else {
    ConstEvalValue::Vector(values.length(), element, values)
  }
}

///|
fn const_eval_access(
  value : ConstEvalValue,
  name : String,
) -> ConstEvalValue raise WeslCompileError {
  match value {
    Struct(type_name, fields) =>
      match const_eval_struct_field(fields, name) {
        Some(value) => value
        None =>
          raise WeslCompileError::Validation(
            "unknown field `\{name}` on struct `\{type_name}`",
          )
      }
    Vector(width, element, elements) =>
      const_eval_vector_access(width, element, elements, name)
    _ =>
      raise WeslCompileError::Validation(
        "cannot access member `\{name}` on `\{value.value_type().label()}`",
      )
  }
}

///|
fn const_eval_index_to_int(
  value : ConstEvalValue,
  context : String,
) -> Int raise WeslCompileError {
  let index = match value {
    AbstractInt(number) => number
    I32(number) =>
      if number < 0 {
        raise WeslCompileError::Validation("negative index in \{context}")
      } else {
        number
      }
    U32(number) => number
    _ =>
      raise WeslCompileError::Validation(
        "cannot use `\{value.value_type().label()}` as index in \{context}",
      )
  }
  if index < 0L || index > 2147483647L {
    raise WeslCompileError::Validation("index out of range in \{context}")
  }
  index.to_int()
}

///|
fn const_eval_index(
  value : ConstEvalValue,
  index_value : ConstEvalValue,
) -> ConstEvalValue raise WeslCompileError {
  let index = const_eval_index_to_int(index_value, "index expression")
  match value {
    Vector(width, _, elements) => {
      if index < 0 || index >= width {
        raise WeslCompileError::Validation(
          "vector index \{index} is out of bounds for vec\{width}",
        )
      }
      elements[index]
    }
    Matrix(columns, _, _, column_values) => {
      if index < 0 || index >= columns {
        raise WeslCompileError::Validation(
          "matrix column index \{index} is out of bounds for \{columns} columns",
        )
      }
      column_values[index]
    }
    Array(_, count, elements) => {
      let length = match count {
        Some(value) => value
        None => elements.length()
      }
      if index < 0 || index >= length || index >= elements.length() {
        raise WeslCompileError::Validation(
          "array index \{index} is out of bounds for length \{length}",
        )
      }
      elements[index]
    }
    _ =>
      raise WeslCompileError::Validation(
        "cannot index `\{value.value_type().label()}`",
      )
  }
}

///|
fn const_eval_get_lvalue(
  target : ConstEvalLValue,
  ctx : ConstEvalContext,
) -> ConstEvalValue raise WeslCompileError {
  match target {
    Root(name) =>
      match ctx.bindings.get(name) {
        Some(value) => value
        None =>
          raise WeslCompileError::Validation(
            "unknown const-eval assignment target `\{name}`",
          )
      }
    Field(base, name) =>
      const_eval_access(const_eval_get_lvalue(base, ctx), name)
    Element(base, index) =>
      const_eval_index(
        const_eval_get_lvalue(base, ctx),
        const_eval_eval_expr(index, ctx),
      )
  }
}

///|
fn const_eval_set_struct_field(
  type_name : String,
  fields : Array[(String, ConstEvalValue)],
  name : String,
  value : ConstEvalValue,
) -> ConstEvalValue raise WeslCompileError {
  let updated_fields : Array[(String, ConstEvalValue)] = []
  let mut found = false
  for field in fields {
    let (field_name, field_value) = field
    if field_name == name {
      found = true
      updated_fields.push(
        (
          field_name,
          const_eval_convert_to_type(value, field_value.value_type(), name),
        ),
      )
    } else {
      updated_fields.push(field)
    }
  }
  if !found {
    raise WeslCompileError::Validation(
      "unknown field `\{name}` on struct `\{type_name}`",
    )
  }
  ConstEvalValue::Struct(type_name, updated_fields)
}

///|
fn const_eval_set_vector_component(
  width : Int,
  element : ConstEvalType,
  elements : Array[ConstEvalValue],
  name : String,
  value : ConstEvalValue,
) -> ConstEvalValue raise WeslCompileError {
  if name.length() != 1 {
    raise WeslCompileError::Validation(
      "cannot assign to multi-component vector swizzle `\{name}`",
    )
  }
  let component = match const_eval_swizzle_component(name) {
    Some((component, _)) => component
    None =>
      raise WeslCompileError::Validation("unknown vector component `\{name}`")
  }
  if component >= width {
    raise WeslCompileError::Validation(
      "vector component `\{name}` is out of bounds for vec\{width}",
    )
  }
  let updated_elements : Array[ConstEvalValue] = []
  for index = 0; index < elements.length(); index = index + 1 {
    if index == component {
      updated_elements.push(const_eval_convert_to_type(value, element, name))
    } else {
      updated_elements.push(elements[index])
    }
  }
  ConstEvalValue::Vector(width, element, updated_elements)
}

///|
fn const_eval_set_field(
  base : ConstEvalValue,
  name : String,
  value : ConstEvalValue,
) -> ConstEvalValue raise WeslCompileError {
  match base {
    Struct(type_name, fields) =>
      const_eval_set_struct_field(type_name, fields, name, value)
    Vector(width, element, elements) =>
      const_eval_set_vector_component(width, element, elements, name, value)
    _ =>
      raise WeslCompileError::Validation(
        "cannot assign member `\{name}` on `\{base.value_type().label()}`",
      )
  }
}

///|
fn const_eval_set_index(
  base : ConstEvalValue,
  index_value : ConstEvalValue,
  value : ConstEvalValue,
) -> ConstEvalValue raise WeslCompileError {
  let index = const_eval_index_to_int(index_value, "index assignment")
  match base {
    Vector(width, element, elements) => {
      if index < 0 || index >= width {
        raise WeslCompileError::Validation(
          "vector index \{index} is out of bounds for vec\{width}",
        )
      }
      let updated_elements : Array[ConstEvalValue] = []
      for i = 0; i < elements.length(); i = i + 1 {
        if i == index {
          updated_elements.push(
            const_eval_convert_to_type(value, element, "vector element"),
          )
        } else {
          updated_elements.push(elements[i])
        }
      }
      ConstEvalValue::Vector(width, element, updated_elements)
    }
    Matrix(columns, rows, element, column_values) => {
      if index < 0 || index >= columns {
        raise WeslCompileError::Validation(
          "matrix column index \{index} is out of bounds for \{columns} columns",
        )
      }
      let column_type = ConstEvalType::Vector(rows, element)
      let updated_columns : Array[ConstEvalValue] = []
      for i = 0; i < column_values.length(); i = i + 1 {
        if i == index {
          updated_columns.push(
            const_eval_convert_to_type(value, column_type, "matrix column"),
          )
        } else {
          updated_columns.push(column_values[i])
        }
      }
      ConstEvalValue::Matrix(columns, rows, element, updated_columns)
    }
    Array(element, count, elements) => {
      let length = match count {
        Some(value) => value
        None => elements.length()
      }
      if index < 0 || index >= length || index >= elements.length() {
        raise WeslCompileError::Validation(
          "array index \{index} is out of bounds for length \{length}",
        )
      }
      let updated_elements : Array[ConstEvalValue] = []
      for i = 0; i < elements.length(); i = i + 1 {
        if i == index {
          updated_elements.push(
            const_eval_convert_to_type(value, element, "array element"),
          )
        } else {
          updated_elements.push(elements[i])
        }
      }
      ConstEvalValue::Array(element, count, updated_elements)
    }
    _ =>
      raise WeslCompileError::Validation(
        "cannot assign index on `\{base.value_type().label()}`",
      )
  }
}

///|
fn const_eval_set_lvalue(
  target : ConstEvalLValue,
  value : ConstEvalValue,
  ctx : ConstEvalContext,
) -> Unit raise WeslCompileError {
  match target {
    Root(name) => {
      let current = match ctx.bindings.get(name) {
        Some(value) => value
        None =>
          raise WeslCompileError::Validation(
            "unknown const-eval assignment target `\{name}`",
          )
      }
      ctx.bindings.set(
        name,
        const_eval_convert_to_type(value, current.value_type(), name),
      )
    }
    Field(base, name) => {
      let base_value = const_eval_get_lvalue(base, ctx)
      const_eval_set_lvalue(
        base,
        const_eval_set_field(base_value, name, value),
        ctx,
      )
    }
    Element(base, index) => {
      let base_value = const_eval_get_lvalue(base, ctx)
      let index_value = const_eval_eval_expr(index, ctx)
      const_eval_set_lvalue(
        base,
        const_eval_set_index(base_value, index_value, value),
        ctx,
      )
    }
  }
}

///|
fn const_eval_array_length_lvalue(
  target : ConstEvalLValue,
  ctx : ConstEvalContext,
) -> ConstEvalValue raise WeslCompileError {
  match const_eval_get_lvalue(target, ctx) {
    Array(_, None, elements) =>
      ConstEvalValue::U32(elements.length().to_int64())
    Array(_, Some(_), _) =>
      raise WeslCompileError::Validation(
        "`arrayLength` expects a pointer to a runtime-sized array",
      )
    value =>
      raise WeslCompileError::Validation(
        "`arrayLength` expects a pointer to a runtime-sized array, got `\{value.value_type().label()}`",
      )
  }
}

///|
fn const_eval_array_length_call(
  args : Array[ConstEvalExpr],
  ctx : ConstEvalContext,
) -> ConstEvalValue raise WeslCompileError {
  match args {
    [AddressOf(target)] => const_eval_array_length_lvalue(target, ctx)
    [_] =>
      raise WeslCompileError::Validation(
        "`arrayLength` expects a pointer to a runtime-sized array",
      )
    _ =>
      raise WeslCompileError::Validation("`arrayLength` expects one argument")
  }
}

///|
fn const_eval_step_value(
  value : ConstEvalValue,
  delta : Int64,
  name : String,
) -> ConstEvalValue raise WeslCompileError {
  let next = match value {
    AbstractInt(number) => ConstEvalValue::AbstractInt(number + delta)
    I32(number) =>
      ConstEvalValue::I32(
        const_eval_require_i32(
          ConstEvalValue::AbstractInt(number + delta),
          name,
        ),
      )
    U32(number) =>
      ConstEvalValue::U32(
        const_eval_require_u32(
          ConstEvalValue::AbstractInt(number + delta),
          name,
        ),
      )
    _ =>
      raise WeslCompileError::Validation(
        "cannot apply const-eval increment to `\{value.value_type().label()}`",
      )
  }
  const_eval_convert_to_type(next, value.value_type(), name)
}

///|
fn const_eval_switch_selector_matches(
  switch_value : ConstEvalValue,
  selector : ConstEvalExpr,
  ctx : ConstEvalContext,
) -> Bool raise WeslCompileError {
  match
    const_eval_apply_binary(
      Eq,
      switch_value,
      const_eval_eval_expr(selector, ctx),
    ) {
    Bool(value) => value
    value =>
      raise WeslCompileError::Validation(
        "const-eval switch selector comparison produced `\{const_eval_render_value(value)}`",
      )
  }
}

///|
fn const_eval_execute_update(
  statement : ConstEvalStatement,
  ctx : ConstEvalContext,
  return_type : ConstEvalType,
  function_name : String,
) -> ConstEvalControl raise WeslCompileError {
  match
    const_eval_execute_statement(statement, ctx, return_type, function_name) {
    ContinueExecution => ContinueExecution
    ReturnVoid => ReturnVoid
    ReturnValue(value) => ReturnValue(value)
    BreakLoop =>
      raise WeslCompileError::Validation("const-eval break in for-loop update")
    ContinueLoop =>
      raise WeslCompileError::Validation(
        "const-eval continue in for-loop update",
      )
  }
}

///|
fn const_eval_vector_width_for_values(
  values : Array[ConstEvalValue],
  context : String,
) -> Int? raise WeslCompileError {
  let mut width : Int? = None
  for value in values {
    match const_eval_vector_width_of(value) {
      Some(value_width) =>
        match width {
          Some(current) =>
            if current != value_width {
              raise WeslCompileError::Validation(
                "vector widths are incompatible in \{context}",
              )
            }
          None => width = Some(value_width)
        }
      None => ()
    }
  }
  width
}

///|
fn const_eval_vector_from_elements(
  width : Int,
  elements : Array[ConstEvalValue],
  context : String,
) -> ConstEvalValue raise WeslCompileError {
  if elements.length() != width || width <= 0 {
    raise WeslCompileError::Validation("invalid vector width in \{context}")
  }
  let element = match elements[0].value_type() {
    Bool => ConstEvalType::Bool
    I32 => ConstEvalType::I32
    U32 => ConstEvalType::U32
    F32 => ConstEvalType::F32
    other =>
      raise WeslCompileError::Validation(
        "invalid vector element type `\{other.label()}` in \{context}",
      )
  }
  for value in elements {
    if value.value_type() != element {
      raise WeslCompileError::Validation(
        "vector element types are incompatible in \{context}",
      )
    }
  }
  ConstEvalValue::Vector(width, element, elements)
}

///|
fn const_eval_apply_vector_binary(
  op : ConstEvalBinaryOp,
  lhs : ConstEvalValue,
  rhs : ConstEvalValue,
) -> ConstEvalValue raise WeslCompileError {
  match op {
    LogicalAnd | LogicalOr => return const_eval_binary_type_error(op, lhs, rhs)
    _ => ()
  }
  let width = match
    const_eval_vector_width_for_values([lhs, rhs], "binary expression") {
    Some(width) => width
    None => return const_eval_binary_type_error(op, lhs, rhs)
  }
  let values : Array[ConstEvalValue] = []
  for index in 0..<width {
    values.push(
      const_eval_apply_binary(
        op,
        const_eval_vector_component(lhs, index),
        const_eval_vector_component(rhs, index),
      ),
    )
  }
  const_eval_vector_from_elements(width, values, "binary expression")
}

///|
fn const_eval_apply_bitwise(
  op : ConstEvalBinaryOp,
  lhs : ConstEvalValue,
  rhs : ConstEvalValue,
) -> ConstEvalValue raise WeslCompileError {
  match (lhs, rhs) {
    (Bool(left), Bool(right)) =>
      match op {
        BitAnd => ConstEvalValue::Bool(left && right)
        BitOr => ConstEvalValue::Bool(left || right)
        _ => const_eval_binary_type_error(op, lhs, rhs)
      }
    (Bool(_), right) => const_eval_binary_type_error(op, lhs, right)
    (left, Bool(_)) => const_eval_binary_type_error(op, left, rhs)
    (AbstractFloat(_, _), right) => const_eval_binary_type_error(op, lhs, right)
    (left, AbstractFloat(_, _)) => const_eval_binary_type_error(op, left, rhs)
    (F32(_), right) => const_eval_binary_type_error(op, lhs, right)
    (left, F32(_)) => const_eval_binary_type_error(op, left, rhs)
    (FrexpAbstract(_, _) | FrexpF32(_, _), right) =>
      const_eval_binary_type_error(op, lhs, right)
    (left, FrexpAbstract(_, _) | FrexpF32(_, _)) =>
      const_eval_binary_type_error(op, left, rhs)
    (Vector(_, _, _), right) => const_eval_binary_type_error(op, lhs, right)
    (left, Vector(_, _, _)) => const_eval_binary_type_error(op, left, rhs)
    (Struct(_, _), right) => const_eval_binary_type_error(op, lhs, right)
    (left, Struct(_, _)) => const_eval_binary_type_error(op, left, rhs)
    (Matrix(_, _, _, _) | Array(_, _, _), right) =>
      const_eval_binary_type_error(op, lhs, right)
    (left, Matrix(_, _, _, _) | Array(_, _, _)) =>
      const_eval_binary_type_error(op, left, rhs)
    (U32(_), I32(_)) => const_eval_binary_type_error(op, lhs, rhs)
    (I32(_), U32(_)) => const_eval_binary_type_error(op, lhs, rhs)
    (U32(left), right) => {
      let value = const_eval_bitwise_int(
        op,
        left,
        const_eval_require_u32(right, "bitwise expression"),
      )
      ConstEvalValue::U32(
        const_eval_require_u32(
          ConstEvalValue::AbstractInt(value),
          "bitwise expression",
        ),
      )
    }
    (left, U32(right)) => {
      let value = const_eval_bitwise_int(
        op,
        const_eval_require_u32(left, "bitwise expression"),
        right,
      )
      ConstEvalValue::U32(
        const_eval_require_u32(
          ConstEvalValue::AbstractInt(value),
          "bitwise expression",
        ),
      )
    }
    (I32(left), right) => {
      let value = const_eval_bitwise_int(
        op,
        left,
        const_eval_require_i32(right, "bitwise expression"),
      )
      ConstEvalValue::I32(
        const_eval_require_i32(
          ConstEvalValue::AbstractInt(value),
          "bitwise expression",
        ),
      )
    }
    (left, I32(right)) => {
      let value = const_eval_bitwise_int(
        op,
        const_eval_require_i32(left, "bitwise expression"),
        right,
      )
      ConstEvalValue::I32(
        const_eval_require_i32(
          ConstEvalValue::AbstractInt(value),
          "bitwise expression",
        ),
      )
    }
    (AbstractInt(left), AbstractInt(right)) =>
      ConstEvalValue::AbstractInt(const_eval_bitwise_int(op, left, right))
  }
}

///|
fn const_eval_apply_shift(
  op : ConstEvalBinaryOp,
  lhs : ConstEvalValue,
  rhs : ConstEvalValue,
) -> ConstEvalValue raise WeslCompileError {
  match lhs {
    Bool(_) => const_eval_binary_type_error(op, lhs, rhs)
    AbstractFloat(_, _) => const_eval_binary_type_error(op, lhs, rhs)
    F32(_) => const_eval_binary_type_error(op, lhs, rhs)
    FrexpAbstract(_, _) | FrexpF32(_, _) =>
      const_eval_binary_type_error(op, lhs, rhs)
    Vector(_, _, _) => const_eval_binary_type_error(op, lhs, rhs)
    Struct(_, _) => const_eval_binary_type_error(op, lhs, rhs)
    Matrix(_, _, _, _) | Array(_, _, _) =>
      const_eval_binary_type_error(op, lhs, rhs)
    AbstractInt(left) =>
      ConstEvalValue::AbstractInt(const_eval_shift_int(op, left, rhs))
    U32(left) =>
      ConstEvalValue::U32(
        const_eval_require_u32(
          ConstEvalValue::AbstractInt(const_eval_shift_int(op, left, rhs)),
          "shift expression",
        ),
      )
    I32(left) =>
      ConstEvalValue::I32(
        const_eval_require_i32(
          ConstEvalValue::AbstractInt(const_eval_shift_int(op, left, rhs)),
          "shift expression",
        ),
      )
  }
}

///|
fn const_eval_apply_comparison(
  op : ConstEvalBinaryOp,
  lhs : ConstEvalValue,
  rhs : ConstEvalValue,
) -> ConstEvalValue raise WeslCompileError {
  match (lhs, rhs) {
    (Bool(left), Bool(right)) =>
      ConstEvalValue::Bool(const_eval_compare_bool(op, left, right))
    (Bool(_), right) => const_eval_binary_type_error(op, lhs, right)
    (left, Bool(_)) => const_eval_binary_type_error(op, left, rhs)
    (FrexpAbstract(_, _) | FrexpF32(_, _), right) =>
      const_eval_binary_type_error(op, lhs, right)
    (left, FrexpAbstract(_, _) | FrexpF32(_, _)) =>
      const_eval_binary_type_error(op, left, rhs)
    (Vector(_, _, _), right) => const_eval_binary_type_error(op, lhs, right)
    (left, Vector(_, _, _)) => const_eval_binary_type_error(op, left, rhs)
    (Struct(_, _), right) => const_eval_binary_type_error(op, lhs, right)
    (left, Struct(_, _)) => const_eval_binary_type_error(op, left, rhs)
    (Matrix(_, _, _, _) | Array(_, _, _), right) =>
      const_eval_binary_type_error(op, lhs, right)
    (left, Matrix(_, _, _, _) | Array(_, _, _)) =>
      const_eval_binary_type_error(op, left, rhs)
    (F32(left), right) =>
      ConstEvalValue::Bool(
        const_eval_compare_float(
          op,
          left.to_double(),
          const_eval_require_f32(right, "binary expression").to_double(),
        ),
      )
    (left, F32(right)) =>
      ConstEvalValue::Bool(
        const_eval_compare_float(
          op,
          const_eval_require_f32(left, "binary expression").to_double(),
          right.to_double(),
        ),
      )
    (AbstractFloat(left, _), right) =>
      ConstEvalValue::Bool(
        const_eval_compare_float(
          op,
          left,
          const_eval_to_abstract_float(right, "binary expression"),
        ),
      )
    (left, AbstractFloat(right, _)) =>
      ConstEvalValue::Bool(
        const_eval_compare_float(
          op,
          const_eval_to_abstract_float(left, "binary expression"),
          right,
        ),
      )
    (U32(_), I32(_)) => const_eval_binary_type_error(op, lhs, rhs)
    (I32(_), U32(_)) => const_eval_binary_type_error(op, lhs, rhs)
    (U32(left), right) =>
      ConstEvalValue::Bool(
        const_eval_compare_int(
          op,
          left,
          const_eval_require_u32(right, "binary expression"),
        ),
      )
    (left, U32(right)) =>
      ConstEvalValue::Bool(
        const_eval_compare_int(
          op,
          const_eval_require_u32(left, "binary expression"),
          right,
        ),
      )
    (I32(left), right) =>
      ConstEvalValue::Bool(
        const_eval_compare_int(
          op,
          left,
          const_eval_require_i32(right, "binary expression"),
        ),
      )
    (left, I32(right)) =>
      ConstEvalValue::Bool(
        const_eval_compare_int(
          op,
          const_eval_require_i32(left, "binary expression"),
          right,
        ),
      )
    (AbstractInt(left), AbstractInt(right)) =>
      ConstEvalValue::Bool(const_eval_compare_int(op, left, right))
  }
}

///|
fn const_eval_apply_binary(
  op : ConstEvalBinaryOp,
  lhs : ConstEvalValue,
  rhs : ConstEvalValue,
) -> ConstEvalValue raise WeslCompileError {
  if const_eval_vector_width_of(lhs) is Some(_) ||
    const_eval_vector_width_of(rhs) is Some(_) {
    return const_eval_apply_vector_binary(op, lhs, rhs)
  }
  match op {
    Eq | Ne | Lt | Le | Gt | Ge =>
      return const_eval_apply_comparison(op, lhs, rhs)
    Shl | Shr => return const_eval_apply_shift(op, lhs, rhs)
    BitAnd | BitOr | BitXor => return const_eval_apply_bitwise(op, lhs, rhs)
    LogicalAnd | LogicalOr => return const_eval_binary_type_error(op, lhs, rhs)
    _ => ()
  }
  match (lhs, rhs) {
    (FrexpAbstract(_, _) | FrexpF32(_, _), _) =>
      const_eval_binary_type_error(op, lhs, rhs)
    (_, FrexpAbstract(_, _) | FrexpF32(_, _)) =>
      const_eval_binary_type_error(op, lhs, rhs)
    (Vector(_, _, _), _) => const_eval_binary_type_error(op, lhs, rhs)
    (_, Vector(_, _, _)) => const_eval_binary_type_error(op, lhs, rhs)
    (Struct(_, _), _) => const_eval_binary_type_error(op, lhs, rhs)
    (_, Struct(_, _)) => const_eval_binary_type_error(op, lhs, rhs)
    (Matrix(_, _, _, _) | Array(_, _, _), _) =>
      const_eval_binary_type_error(op, lhs, rhs)
    (_, Matrix(_, _, _, _) | Array(_, _, _)) =>
      const_eval_binary_type_error(op, lhs, rhs)
    (Bool(_), _) =>
      raise WeslCompileError::Validation(
        "cannot use bool in arithmetic expression",
      )
    (_, Bool(_)) =>
      raise WeslCompileError::Validation(
        "cannot use bool in arithmetic expression",
      )
    (F32(left), right) =>
      ConstEvalValue::F32(
        const_eval_binary_float(
          op,
          left,
          const_eval_require_f32(right, "binary expression"),
        ),
      )
    (left, F32(right)) =>
      ConstEvalValue::F32(
        const_eval_binary_float(
          op,
          const_eval_require_f32(left, "binary expression"),
          right,
        ),
      )
    (AbstractFloat(left, left_lossless), right) =>
      ConstEvalValue::AbstractFloat(
        const_eval_binary_abstract_float(
          op,
          left,
          const_eval_to_abstract_float(right, "binary expression"),
        ),
        left_lossless,
      )
    (left, AbstractFloat(right, right_lossless)) =>
      ConstEvalValue::AbstractFloat(
        const_eval_binary_abstract_float(
          op,
          const_eval_to_abstract_float(left, "binary expression"),
          right,
        ),
        right_lossless,
      )
    (U32(_), I32(_)) =>
      raise WeslCompileError::Validation("cannot mix i32 and u32")
    (I32(_), U32(_)) =>
      raise WeslCompileError::Validation("cannot mix i32 and u32")
    (U32(left), right) => {
      let value = const_eval_binary_int(
        op,
        left,
        const_eval_require_u32(right, "binary expression"),
      )
      ConstEvalValue::U32(
        const_eval_require_u32(
          ConstEvalValue::AbstractInt(value),
          "binary expression",
        ),
      )
    }
    (left, U32(right)) => {
      let value = const_eval_binary_int(
        op,
        const_eval_require_u32(left, "binary expression"),
        right,
      )
      ConstEvalValue::U32(
        const_eval_require_u32(
          ConstEvalValue::AbstractInt(value),
          "binary expression",
        ),
      )
    }
    (I32(left), right) => {
      let value = const_eval_binary_int(
        op,
        left,
        const_eval_require_i32(right, "binary expression"),
      )
      ConstEvalValue::I32(
        const_eval_require_i32(
          ConstEvalValue::AbstractInt(value),
          "binary expression",
        ),
      )
    }
    (left, I32(right)) => {
      let value = const_eval_binary_int(
        op,
        const_eval_require_i32(left, "binary expression"),
        right,
      )
      ConstEvalValue::I32(
        const_eval_require_i32(
          ConstEvalValue::AbstractInt(value),
          "binary expression",
        ),
      )
    }
    (AbstractInt(left), AbstractInt(right)) =>
      ConstEvalValue::AbstractInt(const_eval_binary_int(op, left, right))
  }
}

///|
fn const_eval_eval_expr(
  expr : ConstEvalExpr,
  ctx : ConstEvalContext,
) -> ConstEvalValue raise WeslCompileError {
  match expr {
    Literal(text) => const_eval_parse_literal(text)
    Binding(name) =>
      match ctx.bindings.get(name) {
        Some(value) => value
        None =>
          raise WeslCompileError::Validation(
            "unknown const-eval binding `\{name}`",
          )
      }
    UnaryNeg(inner) => const_eval_unary_neg(const_eval_eval_expr(inner, ctx))
    UnaryNot(inner) => const_eval_unary_not(const_eval_eval_expr(inner, ctx))
    UnaryBitNot(inner) =>
      const_eval_unary_bit_not(const_eval_eval_expr(inner, ctx))
    AddressOf(_) =>
      raise WeslCompileError::Validation(
        "cannot evaluate pointer value directly",
      )
    Binary(LogicalAnd, lhs, rhs) => {
      let left = const_eval_eval_expr(lhs, ctx)
      if !const_eval_require_bool(left, "logical and") {
        return ConstEvalValue::Bool(false)
      }
      ConstEvalValue::Bool(
        const_eval_require_bool(const_eval_eval_expr(rhs, ctx), "logical and"),
      )
    }
    Binary(LogicalOr, lhs, rhs) => {
      let left = const_eval_eval_expr(lhs, ctx)
      if const_eval_require_bool(left, "logical or") {
        return ConstEvalValue::Bool(true)
      }
      ConstEvalValue::Bool(
        const_eval_require_bool(const_eval_eval_expr(rhs, ctx), "logical or"),
      )
    }
    Binary(op, lhs, rhs) =>
      const_eval_apply_binary(
        op,
        const_eval_eval_expr(lhs, ctx),
        const_eval_eval_expr(rhs, ctx),
      )
    Access(base, name) =>
      const_eval_access(const_eval_eval_expr(base, ctx), name)
    Index(base, index) =>
      const_eval_index(
        const_eval_eval_expr(base, ctx),
        const_eval_eval_expr(index, ctx),
      )
    Call(name, args) => {
      if name == "arrayLength" {
        return const_eval_array_length_call(args, ctx)
      }
      let values : Array[ConstEvalValue] = []
      for arg in args {
        values.push(const_eval_eval_expr(arg, ctx))
      }
      match const_eval_dispatch_builtin(name, values) {
        Some(value) => value
        None =>
          match ctx.functions.get(name) {
            Some(function_) =>
              const_eval_execute_function_value(
                function_,
                values,
                ctx.new_call_scope(),
              )
            None =>
              raise WeslCompileError::Validation(
                "unsupported const-eval call `\{name}`",
              )
          }
      }
    }
  }
}

///|
fn const_eval_format_f32(value : Float) -> String {
  let double_value = value.to_double()
  let full = double_value.to_string()
  if full.contains(".") && !full.contains("e") && !full.contains("E") {
    let mut scale = 1.0
    for _ in 0..<9 {
      let rounded = (double_value * scale).round() / scale
      if Float::from_double(rounded) == value {
        let text = const_eval_format_abstract_float(rounded)
        return "\{text}f"
      }
      scale *= 10.0
    }
  }
  let text = full
  "\{text}f"
}

///|
fn const_eval_format_abstract_float(value : Double) -> String {
  let text = value.to_string()
  if text.contains(".") || text.contains("e") || text.contains("E") {
    text
  } else {
    "\{text}.0"
  }
}

///|
fn const_eval_render_value(value : ConstEvalValue) -> String {
  match value {
    Bool(value) => if value { "true" } else { "false" }
    AbstractInt(number) => "\{number}"
    AbstractFloat(number, _) => const_eval_format_abstract_float(number)
    I32(number) => "\{number}i"
    U32(number) => "\{number}u"
    F32(number) => const_eval_format_f32(number)
    Vector(width, element, elements) => {
      let parts : Array[String] = []
      for element_value in elements {
        parts.push(const_eval_render_value(element_value))
      }
      let joined = parts.join(", ")
      "vec\{width}<\{element.label()}>(\{joined})"
    }
    Matrix(columns, rows, element, column_values) => {
      let parts : Array[String] = []
      for column in column_values {
        parts.push(const_eval_render_value(column))
      }
      let joined = parts.join(", ")
      "mat\{columns}x\{rows}<\{element.label()}>(\{joined})"
    }
    Array(element, _, elements) => {
      let parts : Array[String] = []
      for element_value in elements {
        parts.push(const_eval_render_value(element_value))
      }
      let joined = parts.join(", ")
      "array<\{element.label()}>(\{joined})"
    }
    Struct(name, fields) => {
      let parts : Array[String] = []
      for field in fields {
        let (field_name, field_value) = field
        parts.push("\{field_name}: \{const_eval_render_value(field_value)}")
      }
      let joined = parts.join(", ")
      "\{name}{ \{joined} }"
    }
    FrexpAbstract(fract, exp) =>
      "__frexp_result_abstract(\{const_eval_format_abstract_float(fract)}, \{exp})"
    FrexpF32(fract, exp) =>
      "__frexp_result_f32(\{const_eval_format_f32(fract)}, \{exp}i)"
  }
}

///|
fn const_eval_execute_function(
  function : ConstEvalFunction,
  args : Array[ConstEvalValue],
  ctx : ConstEvalContext,
) -> ConstEvalValue? raise WeslCompileError {
  if args.length() != function.params.length() {
    raise WeslCompileError::Validation(
      "const-eval function `\{function.name}` expects \{function.params.length()} arguments, got \{args.length()}",
    )
  }
  for index = 0; index < function.params.length(); index = index + 1 {
    let param = function.params[index]
    ctx.bindings.set(
      param.name,
      const_eval_convert_to_type(args[index], param.declared_type, param.name),
    )
  }
  match
    const_eval_execute_statements(
      function.statements,
      ctx,
      function.return_type,
      function.name,
    ) {
    ReturnValue(value) => Some(value)
    ReturnVoid =>
      match function.return_type {
        Void => None
        _ =>
          raise WeslCompileError::Validation(
            "const-eval function `\{function.name}` returned without a value",
          )
      }
    BreakLoop =>
      raise WeslCompileError::Validation("const-eval break outside loop")
    ContinueLoop =>
      raise WeslCompileError::Validation("const-eval continue outside loop")
    ContinueExecution =>
      match function.return_type {
        Void => None
        _ =>
          raise WeslCompileError::Validation(
            "const-eval function did not return",
          )
      }
  }
}

///|
fn const_eval_execute_function_value(
  function : ConstEvalFunction,
  args : Array[ConstEvalValue],
  ctx : ConstEvalContext,
) -> ConstEvalValue raise WeslCompileError {
  match const_eval_execute_function(function, args, ctx) {
    Some(value) => value
    None =>
      raise WeslCompileError::Validation(
        "const-eval function `\{function.name}` did not return a value",
      )
  }
}

///|
fn const_eval_execute_statement(
  statement : ConstEvalStatement,
  ctx : ConstEvalContext,
  return_type : ConstEvalType,
  function_name : String,
) -> ConstEvalControl raise WeslCompileError {
  match statement {
    Binding(binding) => {
      let value = const_eval_eval_expr(binding.expr, ctx)
      let stored = match binding.declared_type {
        Some(target) => const_eval_convert_to_type(value, target, binding.name)
        None => value
      }
      ctx.bindings.set(binding.name, stored)
      ContinueExecution
    }
    Assignment(target, expr) => {
      const_eval_set_lvalue(target, const_eval_eval_expr(expr, ctx), ctx)
      ContinueExecution
    }
    CompoundAssignment(target, op, expr) => {
      let current = const_eval_get_lvalue(target, ctx)
      let value = const_eval_apply_binary(
        op,
        current,
        const_eval_eval_expr(expr, ctx),
      )
      const_eval_set_lvalue(target, value, ctx)
      ContinueExecution
    }
    Increment(target) => {
      let current = const_eval_get_lvalue(target, ctx)
      const_eval_set_lvalue(
        target,
        const_eval_step_value(current, 1L, "increment target"),
        ctx,
      )
      ContinueExecution
    }
    Decrement(target) => {
      let current = const_eval_get_lvalue(target, ctx)
      const_eval_set_lvalue(
        target,
        const_eval_step_value(current, -1L, "decrement target"),
        ctx,
      )
      ContinueExecution
    }
    If(condition, then_branch, else_branch) => {
      let branch = if const_eval_require_bool(
          const_eval_eval_expr(condition, ctx),
          "if condition",
        ) {
        then_branch
      } else {
        else_branch
      }
      const_eval_execute_statements(branch, ctx, return_type, function_name)
    }
    Switch(selector, cases) => {
      let switch_value = const_eval_eval_expr(selector, ctx)
      let mut selected_body : Array[ConstEvalStatement]? = None
      let mut default_body : Array[ConstEvalStatement]? = None
      for case in cases {
        let mut case_matches = false
        let mut case_is_default = false
        for selector in case.selectors {
          match selector {
            SwitchDefault => case_is_default = true
            SwitchExpression(expr) =>
              if const_eval_switch_selector_matches(switch_value, expr, ctx) {
                case_matches = true
              }
          }
        }
        if case_matches {
          selected_body = Some(case.body)
          break
        }
        if case_is_default && default_body is None {
          default_body = Some(case.body)
        }
      }
      let body = match selected_body {
        Some(body) => Some(body)
        None => default_body
      }
      match body {
        Some(statements) =>
          match
            const_eval_execute_statements(
              statements, ctx, return_type, function_name,
            ) {
            ContinueExecution => ContinueExecution
            BreakLoop => ContinueExecution
            ContinueLoop => ContinueLoop
            ReturnVoid => ReturnVoid
            ReturnValue(value) => ReturnValue(value)
          }
        None => ContinueExecution
      }
    }
    Loop(body, continuing) => {
      let mut iterations = 0
      while true {
        iterations += 1
        if iterations > 1048576 {
          raise WeslCompileError::Validation(
            "const-eval loop exceeded iteration limit",
          )
        }
        let run_continuing = match
          const_eval_execute_statements(body, ctx, return_type, function_name) {
          ContinueExecution => true
          ContinueLoop => true
          ReturnVoid => return ReturnVoid
          ReturnValue(value) => return ReturnValue(value)
          BreakLoop => false
        }
        if !run_continuing {
          break
        }
        match continuing {
          Some(statements) =>
            match
              const_eval_execute_statements(
                statements, ctx, return_type, function_name,
              ) {
              ContinueExecution => ()
              ContinueLoop =>
                raise WeslCompileError::Validation(
                  "const-eval continue inside continuing block",
                )
              ReturnVoid => return ReturnVoid
              ReturnValue(value) => return ReturnValue(value)
              BreakLoop => break
            }
          None => ()
        }
      }
      ContinueExecution
    }
    While(condition, body) => {
      let mut iterations = 0
      while const_eval_require_bool(
              const_eval_eval_expr(condition, ctx),
              "while condition",
            ) {
        iterations += 1
        if iterations > 1048576 {
          raise WeslCompileError::Validation(
            "const-eval while loop exceeded iteration limit",
          )
        }
        match
          const_eval_execute_statements(body, ctx, return_type, function_name) {
          ContinueExecution => ()
          ReturnVoid => return ReturnVoid
          ReturnValue(value) => return ReturnValue(value)
          BreakLoop => return ContinueExecution
          ContinueLoop => ()
        }
      }
      ContinueExecution
    }
    For(initializer, condition, update, body) => {
      match initializer {
        Some(statement) =>
          match
            const_eval_execute_update(
              statement, ctx, return_type, function_name,
            ) {
            ContinueExecution => ()
            ReturnVoid => return ReturnVoid
            ReturnValue(value) => return ReturnValue(value)
            BreakLoop | ContinueLoop => ()
          }
        None => ()
      }
      let mut iterations = 0
      while (match condition {
              Some(expr) =>
                const_eval_require_bool(
                  const_eval_eval_expr(expr, ctx),
                  "for condition",
                )
              None => true
            }) {
        iterations += 1
        if iterations > 1048576 {
          raise WeslCompileError::Validation(
            "const-eval for loop exceeded iteration limit",
          )
        }
        let should_update = match
          const_eval_execute_statements(body, ctx, return_type, function_name) {
          ContinueExecution => true
          ContinueLoop => true
          ReturnVoid => return ReturnVoid
          ReturnValue(value) => return ReturnValue(value)
          BreakLoop => false
        }
        if !should_update {
          break
        }
        match update {
          Some(statement) =>
            match
              const_eval_execute_update(
                statement, ctx, return_type, function_name,
              ) {
              ContinueExecution => ()
              ReturnVoid => return ReturnVoid
              ReturnValue(value) => return ReturnValue(value)
              BreakLoop | ContinueLoop => ()
            }
          None => ()
        }
      }
      ContinueExecution
    }
    Break => BreakLoop
    BreakIf(expr) =>
      if const_eval_require_bool(const_eval_eval_expr(expr, ctx), "break-if") {
        BreakLoop
      } else {
        ContinueExecution
      }
    Continue => ContinueLoop
    ReturnVoid =>
      match return_type {
        Void => ReturnVoid
        _ =>
          raise WeslCompileError::Validation(
            "const-eval function `\{function_name}` returned without a value",
          )
      }
    Return(expr) => {
      let value = const_eval_eval_expr(expr, ctx)
      ReturnValue(const_eval_convert_to_type(value, return_type, function_name))
    }
  }
}

///|
fn const_eval_execute_statements(
  statements : Array[ConstEvalStatement],
  ctx : ConstEvalContext,
  return_type : ConstEvalType,
  function_name : String,
) -> ConstEvalControl raise WeslCompileError {
  for statement in statements {
    match
      const_eval_execute_statement(statement, ctx, return_type, function_name) {
      ContinueExecution => ()
      control => return control
    }
  }
  ContinueExecution
}

///|
fn const_eval_validate_target(
  source : String,
  function_name : String,
) -> Array[ConstEvalExpr] raise WeslCompileError {
  let tokens = const_eval_lex(source)
  let parser = ConstEvalParser::new(tokens)
  let expr = parser.parse_expression()
  if !parser.view().is_empty() {
    raise WeslCompileError::Validation(
      "unsupported const-eval target `\{source}`",
    )
  }
  match expr {
    Call(name, args) if name == function_name => args
    _ =>
      raise WeslCompileError::Validation(
        "unsupported const-eval target `\{source}`",
      )
  }
}

///|
