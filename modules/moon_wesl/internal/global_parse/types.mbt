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
pub(all) struct GlobalParseVar {
  name : String?
  template_arguments : String?
} derive(Eq, Debug)

///|
pub(all) enum GlobalParseHeader {
  Function(String)
  Struct(String)
  Alias(String)
  Const(String)
  Override(String)
  Let(String)
  Var(GlobalParseVar)
  ConstAssert
  EnableDirective
  RequiresDirective
  DiagnosticDirective
  Other
} derive(Eq, Debug)

///|
pub(all) struct GlobalParseDiagnostic {
  offset : Int
  incomplete : Bool
} derive(Eq, Debug)

///|
pub(all) enum GlobalParseResult {
  Parsed(GlobalParseHeader)
  Failed(GlobalParseDiagnostic)
} derive(Eq, Debug)

///|
priv enum GlobalLexResult {
  Lexed(Array[(Token, Int, Int)])
  LexFailed(GlobalParseDiagnostic)
}

///|
fn global_parse_is_identifier_start(code : Int) -> Bool {
  (code >= 65 && code <= 90) ||
  (code >= 97 && code <= 122) ||
  code == 95 ||
  code >= 128
}

///|
fn global_parse_is_identifier_char(code : Int) -> Bool {
  global_parse_is_identifier_start(code) || (code >= 48 && code <= 57)
}

///|
fn global_parse_skip_line_comment(source : String, index : Int) -> Int {
  let mut cursor = index
  while cursor < source.length() && source.code_unit_at(cursor).to_int() != 10 {
    cursor += 1
  }
  cursor
}

///|
fn global_parse_skip_block_comment(source : String, index : Int) -> (Int, Bool) {
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
fn global_parse_skip_balanced(
  source : String,
  index : Int,
  open_code : Int,
  close_code : Int,
) -> (Int, Bool) {
  let mut cursor = index
  let mut depth = 1
  while cursor < source.length() {
    let code = source.code_unit_at(cursor).to_int()
    if code == open_code {
      depth += 1
    } else if code == close_code {
      depth -= 1
      if depth == 0 {
        return (cursor + 1, true)
      }
    }
    cursor += 1
  }
  (cursor, false)
}

///|
fn global_parse_template(source : String, index : Int) -> (String, Int, Bool) {
  let start = index
  let mut cursor = index
  let mut depth = 1
  while cursor < source.length() {
    let code = source.code_unit_at(cursor).to_int()
    if code == 60 {
      depth += 1
    } else if code == 62 {
      depth -= 1
      if depth == 0 {
        return (source[start:cursor].trim().to_owned(), cursor + 1, true)
      }
    }
    cursor += 1
  }
  ("", cursor, false)
}

///|
fn global_parse_keyword_token(name : String) -> Token {
  match name {
    "fn" => FN
    "struct" => STRUCT
    "alias" => ALIAS
    "const" => CONST
    "override" => OVERRIDE
    "let" => LET
    "var" => VAR
    "const_assert" => CONST_ASSERT
    "enable" => ENABLE
    "requires" => REQUIRES
    "diagnostic" => DIAGNOSTIC
    _ => IDENT(name)
  }
}

///|
fn global_parse_lex(source : String) -> GlobalLexResult {
  let tokens : Array[(Token, Int, Int)] = []
  let mut index = 0
  let mut can_parse_var_template = false
  while index < source.length() {
    let code = source.code_unit_at(index).to_int()
    if code == 32 || code == 9 || code == 10 || code == 13 {
      index += 1
      continue
    }
    if code == 47 && index + 1 < source.length() {
      let next = source.code_unit_at(index + 1).to_int()
      if next == 47 {
        index = global_parse_skip_line_comment(source, index + 2)
        continue
      }
      if next == 42 {
        let (end_, closed) = global_parse_skip_block_comment(source, index + 2)
        if !closed {
          return LexFailed({ offset: index, incomplete: true })
        }
        index = end_
        continue
      }
    }
    if code == 64 {
      let start = index
      index += 1
      while index < source.length() &&
            global_parse_is_identifier_char(source.code_unit_at(index).to_int()) {
        index += 1
      }
      if index < source.length() && source.code_unit_at(index).to_int() == 40 {
        let (end_, closed) = global_parse_skip_balanced(
          source,
          index + 1,
          40,
          41,
        )
        if !closed {
          return LexFailed({ offset: start, incomplete: true })
        }
        index = end_
      }
      tokens.push((ATTRIBUTE, start, index))
      can_parse_var_template = false
      continue
    }
    if code == 60 && can_parse_var_template {
      let start = index
      let (template, end_, closed) = global_parse_template(source, index + 1)
      if !closed {
        return LexFailed({ offset: start, incomplete: true })
      }
      tokens.push((VAR_TEMPLATE(template), start, end_))
      index = end_
      can_parse_var_template = false
      continue
    }
    if global_parse_is_identifier_start(code) {
      let start = index
      index += 1
      while index < source.length() &&
            global_parse_is_identifier_char(source.code_unit_at(index).to_int()) {
        index += 1
      }
      let name = source[start:index].to_owned()
      let token = global_parse_keyword_token(name)
      can_parse_var_template = token is VAR
      tokens.push((token, start, index))
      continue
    }
    tokens.push((OTHER, index, index + 1))
    can_parse_var_template = false
    index += 1
  }
  Lexed(tokens)
}

///|
pub fn parse_global_header_source(source : String) -> GlobalParseResult {
  let tokens = match global_parse_lex(source) {
    Lexed(tokens) => tokens
    LexFailed(diagnostic) => return Failed(diagnostic)
  }
  if tokens.is_empty() {
    return Parsed(Other)
  }
  let header = parse_global_header(tokens) catch {
    UnexpectedToken(_, (start, _), _) =>
      return Failed({ offset: start, incomplete: false })
    UnexpectedEndOfInput(start, _) =>
      return Failed({ offset: start, incomplete: true })
  }
  Parsed(header)
}
