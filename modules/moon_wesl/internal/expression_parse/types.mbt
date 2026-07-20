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
pub(all) struct ExpressionParseDiagnostic {
  offset : Int
  incomplete : Bool
  message : String?
} derive(Eq, Debug)

///|
pub(all) enum ExpressionParseResult {
  Parsed(ExpressionParseNode)
  Failed(ExpressionParseDiagnostic)
} derive(Eq, Debug)

///|
pub(all) struct ExpressionTypeParseNode {
  path : Array[String]
  ident : String
  template_text : String?
} derive(Eq, Debug)

///|
pub(all) enum ExpressionUnaryOperator {
  Negation
  LogicalNegation
  BitwiseComplement
  Indirection
  AddressOf
} derive(Eq, Debug)

///|
pub(all) enum ExpressionBinaryOperator {
  ShortCircuitOr
  ShortCircuitAnd
  BitwiseOr
  BitwiseXor
  BitwiseAnd
  Equality
  Inequality
  LessThan
  LessThanEqual
  GreaterThan
  GreaterThanEqual
  ShiftLeft
  ShiftRight
  Addition
  Subtraction
  Multiplication
  Division
  Remainder
} derive(Eq, Debug)

///|
pub(all) struct ExpressionFunctionCallParseNode {
  callee : ExpressionTypeParseNode
  arguments : Array[ExpressionParseNode]
} derive(Eq, Debug)

///|
pub(all) enum ExpressionParseNode {
  Literal(String)
  Bool(Bool)
  TypeOrIdentifier(ExpressionTypeParseNode)
  Parenthesized(ExpressionParseNode)
  NamedComponent(ExpressionParseNode, String)
  Indexing(ExpressionParseNode, ExpressionParseNode)
  Unary(ExpressionUnaryOperator, ExpressionParseNode)
  Binary(ExpressionBinaryOperator, ExpressionParseNode, ExpressionParseNode)
  FunctionCall(ExpressionFunctionCallParseNode)
} derive(Eq, Debug)

///|
pub(all) enum ExpressionPostfixSuffix {
  NamedComponent(String)
  Indexing(ExpressionParseNode)
} derive(Eq, Debug)

///|
pub fn ExpressionTypeParseNode::from_path(
  path : Array[String],
) -> ExpressionTypeParseNode {
  let prefix : Array[String] = []
  for index in 0..<(path.length() - 1) {
    prefix.push(path[index])
  }
  { path: prefix, ident: path[path.length() - 1], template_text: None }
}

///|
pub fn ExpressionTypeParseNode::with_template(
  self : ExpressionTypeParseNode,
  template_text : String,
) -> ExpressionTypeParseNode {
  { path: self.path, ident: self.ident, template_text: Some(template_text) }
}

///|
pub fn ExpressionTypeParseNode::qualified_child(
  self : ExpressionTypeParseNode,
  ident : String,
) -> ExpressionTypeParseNode {
  let path : Array[String] = []
  for segment in self.path {
    path.push(segment)
  }
  path.push(self.ident)
  { path, ident, template_text: None }
}

///|
pub fn ExpressionParseNode::apply_postfix(
  self : ExpressionParseNode,
  suffix : ExpressionPostfixSuffix,
) -> ExpressionParseNode {
  match suffix {
    NamedComponent(component) => NamedComponent(self, component)
    Indexing(index) => Indexing(self, index)
  }
}

///|
priv enum ExpressionLexResult {
  Lexed(Array[(Token, Int, Int)])
  LexFailed(ExpressionParseDiagnostic)
}

///|
fn expression_parse_is_identifier_start(code : Int) -> Bool {
  (code >= 65 && code <= 90) ||
  (code >= 97 && code <= 122) ||
  code == 95 ||
  code >= 128
}

///|
fn expression_parse_is_identifier_char(code : Int) -> Bool {
  expression_parse_is_identifier_start(code) || (code >= 48 && code <= 57)
}

///|
fn expression_parse_is_digit(code : Int) -> Bool {
  code >= 48 && code <= 57
}

///|
fn expression_parse_is_hex_digit(code : Int) -> Bool {
  expression_parse_is_digit(code) ||
  (code >= 65 && code <= 70) ||
  (code >= 97 && code <= 102)
}

///|
fn expression_parse_skip_line_comment(source : String, index : Int) -> Int {
  let mut cursor = index
  while cursor < source.length() && source.code_unit_at(cursor).to_int() != 10 {
    cursor += 1
  }
  cursor
}

///|
fn expression_parse_skip_block_comment(
  source : String,
  index : Int,
) -> (Int, Bool) {
  let mut cursor = index
  let mut depth = 1
  while cursor + 1 < source.length() {
    let current = source.code_unit_at(cursor).to_int()
    let next = source.code_unit_at(cursor + 1).to_int()
    if current == 47 && next == 42 {
      depth += 1
      cursor += 2
      continue
    }
    if current == 42 && next == 47 {
      depth -= 1
      cursor += 2
      if depth == 0 {
        return (cursor, true)
      }
      continue
    }
    cursor += 1
  }
  (cursor, false)
}

///|
fn expression_parse_number_end(source : String, start : Int) -> (Int, Bool) {
  let mut index = start
  let mut is_hex = false
  let mut has_dot = false
  let mut has_exponent = false
  if index + 1 < source.length() &&
    source.code_unit_at(index).to_int() == 48 &&
    (
      source.code_unit_at(index + 1).to_int() == 120 ||
      source.code_unit_at(index + 1).to_int() == 88
    ) {
    is_hex = true
    index += 2
  }
  let digit_start = index
  while index < source.length() {
    let code = source.code_unit_at(index).to_int()
    if code == 95 ||
      (if is_hex {
        expression_parse_is_hex_digit(code)
      } else {
        expression_parse_is_digit(code)
      }) {
      index += 1
      continue
    }
    if code == 46 && !has_dot {
      has_dot = true
      index += 1
      continue
    }
    if (if is_hex {
        code == 112 || code == 80
      } else {
        code == 101 || code == 69
      }) &&
      !has_exponent {
      has_exponent = true
      index += 1
      if index < source.length() {
        let sign = source.code_unit_at(index).to_int()
        if sign == 43 || sign == 45 {
          index += 1
        }
      }
      continue
    }
    break
  }
  if index < source.length() {
    let suffix = source.code_unit_at(index).to_int()
    if suffix == 108 && index + 1 < source.length() {
      let long_suffix = source.code_unit_at(index + 1).to_int()
      if long_suffix == 105 || long_suffix == 117 || long_suffix == 102 {
        index += 2
      }
    } else if suffix == 105 || suffix == 117 || suffix == 102 || suffix == 104 {
      index += 1
    }
  }
  let mut significant_digits = 0
  for cursor in digit_start..<index {
    let code = source.code_unit_at(cursor).to_int()
    if expression_parse_is_digit(code) {
      significant_digits += 1
    }
  }
  let integer_like = !is_hex && !has_dot && !has_exponent
  let valid = !integer_like ||
    significant_digits <= 1 ||
    source.code_unit_at(digit_start).to_int() != 48
  (index, valid)
}

///|
fn expression_parse_template_end_if_call(source : String, start : Int) -> Int? {
  let mut index = start + 1
  let mut depth = 1
  while index < source.length() {
    let code = source.code_unit_at(index).to_int()
    if code == 60 {
      depth += 1
    } else if code == 62 {
      depth -= 1
      if depth == 0 {
        let mut cursor = index + 1
        while cursor < source.length() {
          let next = source.code_unit_at(cursor).to_int()
          if next == 32 || next == 9 || next == 10 || next == 13 {
            cursor += 1
            continue
          }
          if next == 40 {
            return Some(index + 1)
          }
          return None
        }
        return None
      }
    }
    index += 1
  }
  None
}

///|
fn expression_parse_push_operator(
  tokens : Array[(Token, Int, Int)],
  token : Token,
  start : Int,
  width : Int,
) -> Int {
  tokens.push((token, start, start + width))
  start + width
}

///|
fn expression_parse_lex(source : String) -> ExpressionLexResult {
  let tokens : Array[(Token, Int, Int)] = []
  let mut index = 0
  let mut template_allowed = false
  while index < source.length() {
    let code = source.code_unit_at(index).to_int()
    if code == 32 || code == 9 || code == 10 || code == 13 {
      index += 1
      continue
    }
    if code == 47 && index + 1 < source.length() {
      let next = source.code_unit_at(index + 1).to_int()
      if next == 47 {
        index = expression_parse_skip_line_comment(source, index + 2)
        continue
      }
      if next == 42 {
        let (end_, closed) = expression_parse_skip_block_comment(
          source,
          index + 2,
        )
        if !closed {
          return LexFailed({
            offset: index,
            incomplete: true,
            message: Some("unterminated block comment"),
          })
        }
        index = end_
        continue
      }
    }
    if expression_parse_is_identifier_start(code) {
      let start = index
      index += 1
      while index < source.length() &&
            expression_parse_is_identifier_char(
              source.code_unit_at(index).to_int(),
            ) {
        index += 1
      }
      let name = source[start:index].to_owned()
      let token = match name {
        "true" => TRUE
        "false" => FALSE
        _ => IDENT(name)
      }
      tokens.push((token, start, index))
      template_allowed = true
      continue
    }
    if expression_parse_is_digit(code) {
      let start = index
      let (end_, valid) = expression_parse_number_end(source, index)
      if !valid {
        return LexFailed({
          offset: start,
          incomplete: false,
          message: Some("invalid numeric literal"),
        })
      }
      tokens.push((NUMBER(source[start:end_].to_owned()), start, end_))
      index = end_
      template_allowed = false
      continue
    }
    let next = if index + 1 < source.length() {
      source.code_unit_at(index + 1).to_int()
    } else {
      -1
    }
    if code == 60 && template_allowed {
      match expression_parse_template_end_if_call(source, index) {
        Some(end_) => {
          tokens.push(
            (TEMPLATE(source[index + 1:end_ - 1].to_owned()), index, end_),
          )
          index = end_
          template_allowed = false
          continue
        }
        None => ()
      }
    }
    index = match code {
      40 => expression_parse_push_operator(tokens, LEFT_PAREN, index, 1)
      41 => expression_parse_push_operator(tokens, RIGHT_PAREN, index, 1)
      44 => expression_parse_push_operator(tokens, COMMA, index, 1)
      46 => expression_parse_push_operator(tokens, DOT, index, 1)
      91 => expression_parse_push_operator(tokens, LEFT_BRACKET, index, 1)
      93 => expression_parse_push_operator(tokens, RIGHT_BRACKET, index, 1)
      58 if next == 58 =>
        expression_parse_push_operator(tokens, DOUBLE_COLON, index, 2)
      60 if next == 60 =>
        expression_parse_push_operator(tokens, SHIFT_LEFT, index, 2)
      60 if next == 61 =>
        expression_parse_push_operator(tokens, LESS_EQUAL, index, 2)
      60 => expression_parse_push_operator(tokens, LESS, index, 1)
      62 if next == 62 =>
        expression_parse_push_operator(tokens, SHIFT_RIGHT, index, 2)
      62 if next == 61 =>
        expression_parse_push_operator(tokens, GREATER_EQUAL, index, 2)
      62 => expression_parse_push_operator(tokens, GREATER, index, 1)
      43 => expression_parse_push_operator(tokens, PLUS, index, 1)
      45 if next == 45 =>
        expression_parse_push_operator(tokens, MINUS_MINUS, index, 2)
      45 => expression_parse_push_operator(tokens, MINUS, index, 1)
      42 => expression_parse_push_operator(tokens, STAR, index, 1)
      47 => expression_parse_push_operator(tokens, SLASH, index, 1)
      37 => expression_parse_push_operator(tokens, PERCENT, index, 1)
      33 if next == 61 =>
        expression_parse_push_operator(tokens, BANG_EQUAL, index, 2)
      33 => expression_parse_push_operator(tokens, BANG, index, 1)
      126 => expression_parse_push_operator(tokens, TILDE, index, 1)
      38 if next == 38 =>
        expression_parse_push_operator(tokens, AMP_AMP, index, 2)
      38 => expression_parse_push_operator(tokens, AMP, index, 1)
      124 if next == 124 =>
        expression_parse_push_operator(tokens, PIPE_PIPE, index, 2)
      124 => expression_parse_push_operator(tokens, PIPE, index, 1)
      94 => expression_parse_push_operator(tokens, CARET, index, 1)
      61 if next == 61 =>
        expression_parse_push_operator(tokens, EQUAL_EQUAL, index, 2)
      _ =>
        return LexFailed({
          offset: index,
          incomplete: false,
          message: Some("unsupported expression token"),
        })
    }
    template_allowed = code == 58 && next == 58
  }
  Lexed(tokens)
}

///|
pub fn parse_expression_source(source : String) -> ExpressionParseResult {
  let tokens = match expression_parse_lex(source) {
    Lexed(tokens) => tokens
    LexFailed(diagnostic) => return Failed(diagnostic)
  }
  if tokens.is_empty() {
    return Failed({
      offset: 0,
      incomplete: true,
      message: Some("empty expression"),
    })
  }
  let parsed = parse_expression(tokens) catch {
    UnexpectedToken(_, (start, _), _) =>
      return Failed({ offset: start, incomplete: false, message: None })
    UnexpectedEndOfInput(start, _) =>
      return Failed({ offset: start, incomplete: true, message: None })
  }
  Parsed(parsed)
}
