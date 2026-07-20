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
pub(all) struct TypeParseDiagnostic {
  offset : Int
  incomplete : Bool
  message : String?
} derive(Eq, Debug)

///|
pub(all) enum TypeParseResult {
  Parsed(TypeSpecifierParseNode)
  Failed(TypeParseDiagnostic)
} derive(Eq, Debug)

///|
pub(all) struct TypeSpecifierParseNode {
  path : Array[String]
  ident : String
  template_args : Array[TypeTemplateArgumentParseNode]
} derive(Eq, Debug)

///|
pub(all) enum TypeTemplateArgumentParseNode {
  Type(TypeSpecifierParseNode)
  Literal(String)
} derive(Eq, Debug)

///|
pub fn TypeSpecifierParseNode::from_path(
  path : Array[String],
) -> TypeSpecifierParseNode {
  let prefix : Array[String] = []
  for index in 0..<(path.length() - 1) {
    prefix.push(path[index])
  }
  { path: prefix, ident: path[path.length() - 1], template_args: [] }
}

///|
pub fn TypeSpecifierParseNode::qualified_child(
  self : TypeSpecifierParseNode,
  ident : String,
) -> TypeSpecifierParseNode {
  let path : Array[String] = []
  for segment in self.path {
    path.push(segment)
  }
  path.push(self.ident)
  { path, ident, template_args: [] }
}

///|
pub fn TypeSpecifierParseNode::with_template_args(
  self : TypeSpecifierParseNode,
  template_args : Array[TypeTemplateArgumentParseNode],
) -> TypeSpecifierParseNode {
  { path: self.path, ident: self.ident, template_args }
}

///|
priv enum TypeLexResult {
  Lexed(Array[(Token, Int, Int)])
  LexFailed(TypeParseDiagnostic)
}

///|
fn type_parse_is_identifier_start(code : Int) -> Bool {
  (code >= 65 && code <= 90) ||
  (code >= 97 && code <= 122) ||
  code == 95 ||
  code >= 128
}

///|
fn type_parse_is_identifier_char(code : Int) -> Bool {
  type_parse_is_identifier_start(code) || (code >= 48 && code <= 57)
}

///|
fn type_parse_is_digit(code : Int) -> Bool {
  code >= 48 && code <= 57
}

///|
fn type_parse_is_hex_digit(code : Int) -> Bool {
  type_parse_is_digit(code) ||
  (code >= 65 && code <= 70) ||
  (code >= 97 && code <= 102)
}

///|
fn type_parse_skip_line_comment(source : String, index : Int) -> Int {
  let mut cursor = index
  while cursor < source.length() && source.code_unit_at(cursor).to_int() != 10 {
    cursor += 1
  }
  cursor
}

///|
fn type_parse_skip_block_comment(source : String, index : Int) -> (Int, Bool) {
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
fn type_parse_number_end(source : String, start : Int) -> (Int, Bool) {
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
        type_parse_is_hex_digit(code)
      } else {
        type_parse_is_digit(code)
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
    if suffix == 105 || suffix == 117 || suffix == 102 || suffix == 104 {
      index += 1
    }
  }
  let mut significant_digits = 0
  for cursor in digit_start..<index {
    let code = source.code_unit_at(cursor).to_int()
    if type_parse_is_digit(code) {
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
fn type_parse_push_token(
  tokens : Array[(Token, Int, Int)],
  token : Token,
  start : Int,
  width : Int,
) -> Int {
  tokens.push((token, start, start + width))
  start + width
}

///|
fn type_parse_lex(source : String) -> TypeLexResult {
  let tokens : Array[(Token, Int, Int)] = []
  let mut index = 0
  while index < source.length() {
    let code = source.code_unit_at(index).to_int()
    if code == 32 || code == 9 || code == 10 || code == 13 {
      index += 1
      continue
    }
    if code == 47 && index + 1 < source.length() {
      let next = source.code_unit_at(index + 1).to_int()
      if next == 47 {
        index = type_parse_skip_line_comment(source, index + 2)
        continue
      }
      if next == 42 {
        let (end_, closed) = type_parse_skip_block_comment(source, index + 2)
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
    if type_parse_is_identifier_start(code) {
      let start = index
      index += 1
      while index < source.length() &&
            type_parse_is_identifier_char(source.code_unit_at(index).to_int()) {
        index += 1
      }
      tokens.push((IDENT(source[start:index].to_owned()), start, index))
      continue
    }
    if type_parse_is_digit(code) {
      let start = index
      let (end_, valid) = type_parse_number_end(source, index)
      if !valid {
        return LexFailed({
          offset: start,
          incomplete: false,
          message: Some("invalid numeric literal"),
        })
      }
      tokens.push((NUMBER(source[start:end_].to_owned()), start, end_))
      index = end_
      continue
    }
    let next = if index + 1 < source.length() {
      source.code_unit_at(index + 1).to_int()
    } else {
      -1
    }
    index = match code {
      44 => type_parse_push_token(tokens, COMMA, index, 1)
      45 => type_parse_push_token(tokens, MINUS, index, 1)
      58 if next == 58 => type_parse_push_token(tokens, DOUBLE_COLON, index, 2)
      60 if next == 60 => type_parse_push_token(tokens, SHIFT_LEFT, index, 2)
      60 => type_parse_push_token(tokens, LESS, index, 1)
      62 => type_parse_push_token(tokens, GREATER, index, 1)
      _ =>
        return LexFailed({
          offset: index,
          incomplete: false,
          message: Some("unsupported type token"),
        })
    }
  }
  Lexed(tokens)
}

///|
pub fn parse_type_source(source : String) -> TypeParseResult {
  let tokens = match type_parse_lex(source) {
    Lexed(tokens) => tokens
    LexFailed(diagnostic) => return Failed(diagnostic)
  }
  if tokens.is_empty() {
    return Failed({ offset: 0, incomplete: true, message: Some("empty type") })
  }
  let parsed = parse_type_specifier(tokens) catch {
    UnexpectedToken(_, (start, _), _) =>
      return Failed({ offset: start, incomplete: false, message: None })
    UnexpectedEndOfInput(start, _) =>
      return Failed({ offset: start, incomplete: true, message: None })
  }
  Parsed(parsed)
}
