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
pub(all) enum BindingParseKind {
  Alias
  Const
  Override
  Let
  Var
} derive(Eq, Debug)

///|
pub(all) struct BindingParseNode {
  kind : BindingParseKind
  name : String?
  var_template : String?
  type_text : String?
  initializer : String?
} derive(Eq, Debug)

///|
pub(all) struct BindingParseDiagnostic {
  offset : Int
  incomplete : Bool
} derive(Eq, Debug)

///|
pub(all) enum BindingParseResult {
  Parsed(BindingParseNode)
  Failed(BindingParseDiagnostic)
} derive(Eq, Debug)

///|
priv enum BindingLexResult {
  Lexed(Array[(Token, Int, Int)])
  LexFailed(BindingParseDiagnostic)
}

///|
fn binding_parse_is_identifier_start(code : Int) -> Bool {
  (code >= 65 && code <= 90) ||
  (code >= 97 && code <= 122) ||
  code == 95 ||
  code >= 128
}

///|
fn binding_parse_is_identifier_char(code : Int) -> Bool {
  binding_parse_is_identifier_start(code) || (code >= 48 && code <= 57)
}

///|
fn binding_parse_skip_line_comment(source : String, index : Int) -> Int {
  let mut cursor = index
  while cursor < source.length() && source.code_unit_at(cursor).to_int() != 10 {
    cursor += 1
  }
  cursor
}

///|
fn binding_parse_skip_block_comment(
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
fn binding_parse_skip_layout(source : String, index : Int) -> (Int, Bool) {
  let mut cursor = index
  while cursor < source.length() {
    let code = source.code_unit_at(cursor).to_int()
    if code == 32 || code == 9 || code == 10 || code == 13 {
      cursor += 1
      continue
    }
    if code == 47 && cursor + 1 < source.length() {
      let next = source.code_unit_at(cursor + 1).to_int()
      if next == 47 {
        cursor = binding_parse_skip_line_comment(source, cursor + 2)
        continue
      }
      if next == 42 {
        let (end_, closed) = binding_parse_skip_block_comment(
          source,
          cursor + 2,
        )
        if !closed {
          return (cursor, false)
        }
        cursor = end_
        continue
      }
    }
    break
  }
  (cursor, true)
}

///|
fn binding_parse_skip_balanced(
  source : String,
  index : Int,
  open_code : Int,
  close_code : Int,
) -> (Int, Bool) {
  let mut cursor = index
  let mut depth = 1
  while cursor < source.length() {
    let code = source.code_unit_at(cursor).to_int()
    if code == 47 && cursor + 1 < source.length() {
      let next = source.code_unit_at(cursor + 1).to_int()
      if next == 47 {
        cursor = binding_parse_skip_line_comment(source, cursor + 2)
        continue
      }
      if next == 42 {
        let (end_, closed) = binding_parse_skip_block_comment(
          source,
          cursor + 2,
        )
        if !closed {
          return (cursor, false)
        }
        cursor = end_
        continue
      }
    }
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
fn binding_parse_skip_attributes(source : String, index : Int) -> (Int, Bool) {
  let mut cursor = index
  while cursor < source.length() && source.code_unit_at(cursor).to_int() == 64 {
    cursor += 1
    while cursor < source.length() &&
          binding_parse_is_identifier_char(source.code_unit_at(cursor).to_int()) {
      cursor += 1
    }
    if cursor < source.length() && source.code_unit_at(cursor).to_int() == 40 {
      let (end_, closed) = binding_parse_skip_balanced(
        source,
        cursor + 1,
        40,
        41,
      )
      if !closed {
        return (end_, false)
      }
      cursor = end_
    }
    let (next, ok) = binding_parse_skip_layout(source, cursor)
    if !ok {
      return (next, false)
    }
    cursor = next
  }
  (cursor, true)
}

///|
fn binding_parse_read_ident(source : String, index : Int) -> (String, Int)? {
  if index >= source.length() ||
    !binding_parse_is_identifier_start(source.code_unit_at(index).to_int()) {
    return None
  }
  let start = index
  let mut cursor = index + 1
  while cursor < source.length() &&
        binding_parse_is_identifier_char(source.code_unit_at(cursor).to_int()) {
    cursor += 1
  }
  Some((source[start:cursor].to_owned(), cursor))
}

///|
fn binding_parse_read_template(
  source : String,
  index : Int,
) -> (String, Int, Bool) {
  let start = index + 1
  let (end_, ok) = binding_parse_skip_balanced(source, index + 1, 60, 62)
  if !ok {
    return ("", end_, false)
  }
  (source[start:end_ - 1].trim().to_owned(), end_, true)
}

///|
fn binding_parse_keyword_token(name : String) -> Token {
  match name {
    "alias" => ALIAS
    "const" => CONST
    "override" => OVERRIDE
    "let" => LET
    "var" => VAR
    _ => IDENT(name)
  }
}

///|
fn binding_parse_push(
  tokens : Array[(Token, Int, Int)],
  token : Token,
  start : Int,
  end_ : Int,
) -> Unit {
  tokens.push((token, start, end_))
}

///|
fn binding_parse_segment_end(
  source : String,
  index : Int,
  first_stop : Int,
  second_stop : Int,
  track_angle : Bool,
) -> (String, Int, Bool) {
  let start = index
  let mut cursor = index
  let mut angle_depth = 0
  let mut paren_depth = 0
  let mut bracket_depth = 0
  let mut brace_depth = 0
  while cursor < source.length() {
    let code = source.code_unit_at(cursor).to_int()
    if code == 47 && cursor + 1 < source.length() {
      let next = source.code_unit_at(cursor + 1).to_int()
      if next == 47 {
        cursor = binding_parse_skip_line_comment(source, cursor + 2)
        continue
      }
      if next == 42 {
        let (end_, closed) = binding_parse_skip_block_comment(
          source,
          cursor + 2,
        )
        if !closed {
          return ("", cursor, false)
        }
        cursor = end_
        continue
      }
    }
    let next_code = if cursor + 1 < source.length() {
      source.code_unit_at(cursor + 1).to_int()
    } else {
      -1
    }
    if code == 60 && next_code == 60 && track_angle {
      cursor += 2
      continue
    }
    if code == 60 && track_angle {
      angle_depth += 1
    } else if code == 62 && track_angle {
      angle_depth -= 1
    } else if code == 40 {
      paren_depth += 1
    } else if code == 41 {
      paren_depth -= 1
    } else if code == 91 {
      bracket_depth += 1
    } else if code == 93 {
      bracket_depth -= 1
    } else if code == 123 {
      brace_depth += 1
    } else if code == 125 {
      brace_depth -= 1
    } else if (code == first_stop || code == second_stop) &&
      angle_depth == 0 &&
      paren_depth == 0 &&
      bracket_depth == 0 &&
      brace_depth == 0 {
      return (source[start:cursor].trim().to_owned(), cursor, true)
    }
    if angle_depth < 0 ||
      paren_depth < 0 ||
      bracket_depth < 0 ||
      brace_depth < 0 {
      return ("", cursor, false)
    }
    cursor += 1
  }
  if first_stop == -1 || second_stop == -1 {
    return (source[start:cursor].trim().to_owned(), cursor, true)
  }
  ("", cursor, false)
}

///|
fn binding_parse_lex(source : String) -> BindingLexResult {
  let tokens : Array[(Token, Int, Int)] = []
  let mut index = 0
  let (start_index, ok) = binding_parse_skip_layout(source, index)
  if !ok {
    return LexFailed(BindingParseDiagnostic::{ offset: index, incomplete: true })
  }
  index = start_index
  let (after_attrs, ok) = binding_parse_skip_attributes(source, index)
  if !ok {
    return LexFailed(BindingParseDiagnostic::{ offset: index, incomplete: true })
  }
  index = after_attrs
  let (keyword, after_keyword) = match binding_parse_read_ident(source, index) {
    Some(item) => item
    None =>
      return LexFailed(BindingParseDiagnostic::{
        offset: index,
        incomplete: false,
      })
  }
  binding_parse_push(
    tokens,
    binding_parse_keyword_token(keyword),
    index,
    after_keyword,
  )
  index = after_keyword
  let (after_keyword_layout, ok) = binding_parse_skip_layout(source, index)
  if !ok {
    return LexFailed(BindingParseDiagnostic::{ offset: index, incomplete: true })
  }
  index = after_keyword_layout
  if tokens[0].0 is VAR &&
    index < source.length() &&
    source.code_unit_at(index).to_int() == 60 {
    let (template, end_, ok) = binding_parse_read_template(source, index)
    if !ok {
      return LexFailed(BindingParseDiagnostic::{
        offset: index,
        incomplete: true,
      })
    }
    binding_parse_push(tokens, VAR_TEMPLATE(template), index, end_)
    index = end_
    let (after_template, ok) = binding_parse_skip_layout(source, index)
    if !ok {
      return LexFailed(BindingParseDiagnostic::{
        offset: index,
        incomplete: true,
      })
    }
    index = after_template
  }
  let (name, after_name) = match binding_parse_read_ident(source, index) {
    Some(item) => item
    None =>
      return LexFailed(BindingParseDiagnostic::{
        offset: index,
        incomplete: false,
      })
  }
  binding_parse_push(tokens, IDENT(name), index, after_name)
  index = after_name
  let (after_name_layout, ok) = binding_parse_skip_layout(source, index)
  if !ok {
    return LexFailed(BindingParseDiagnostic::{ offset: index, incomplete: true })
  }
  index = after_name_layout
  if tokens[0].0 is ALIAS {
    if index >= source.length() || source.code_unit_at(index).to_int() != 61 {
      return LexFailed(BindingParseDiagnostic::{
        offset: index,
        incomplete: index >= source.length(),
      })
    }
    binding_parse_push(tokens, EQ, index, index + 1)
    let (target, target_end, ok) = binding_parse_segment_end(
      source,
      index + 1,
      59,
      -1,
      true,
    )
    if !ok || target == "" {
      return LexFailed(BindingParseDiagnostic::{
        offset: index + 1,
        incomplete: !ok,
      })
    }
    binding_parse_push(tokens, TYPE_TEXT(target), index + 1, target_end)
    index = target_end
  } else {
    if index < source.length() && source.code_unit_at(index).to_int() == 58 {
      binding_parse_push(tokens, COLON, index, index + 1)
      let (type_text, type_end, ok) = binding_parse_segment_end(
        source,
        index + 1,
        61,
        59,
        true,
      )
      if !ok || type_text == "" {
        return LexFailed(BindingParseDiagnostic::{
          offset: index + 1,
          incomplete: !ok,
        })
      }
      binding_parse_push(tokens, TYPE_TEXT(type_text), index + 1, type_end)
      index = type_end
      let (after_type, ok) = binding_parse_skip_layout(source, index)
      if !ok {
        return LexFailed(BindingParseDiagnostic::{
          offset: index,
          incomplete: true,
        })
      }
      index = after_type
    }
    if index < source.length() && source.code_unit_at(index).to_int() == 61 {
      binding_parse_push(tokens, EQ, index, index + 1)
      let (initializer, init_end, ok) = binding_parse_segment_end(
        source,
        index + 1,
        59,
        -1,
        false,
      )
      if !ok || initializer == "" {
        return LexFailed(BindingParseDiagnostic::{
          offset: index + 1,
          incomplete: !ok,
        })
      }
      binding_parse_push(tokens, INIT_TEXT(initializer), index + 1, init_end)
      index = init_end
    }
  }
  let (after_tail, ok) = binding_parse_skip_layout(source, index)
  if !ok {
    return LexFailed(BindingParseDiagnostic::{ offset: index, incomplete: true })
  }
  index = after_tail
  if index < source.length() && source.code_unit_at(index).to_int() == 59 {
    binding_parse_push(tokens, SEMI, index, index + 1)
  }
  Lexed(tokens)
}

///|
pub fn parse_binding_source(source : String) -> BindingParseResult {
  let tokens = match binding_parse_lex(source) {
    Lexed(tokens) => tokens
    LexFailed(diagnostic) => return Failed(diagnostic)
  }
  let parsed = parse_binding_decl(tokens) catch {
    UnexpectedToken(_, (start, _), _) =>
      return Failed(BindingParseDiagnostic::{ offset: start, incomplete: false })
    UnexpectedEndOfInput(start, _) =>
      return Failed(BindingParseDiagnostic::{ offset: start, incomplete: true })
  }
  Parsed(parsed)
}
