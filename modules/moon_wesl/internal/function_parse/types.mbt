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
pub(all) struct FunctionParameterParseNode {
  name : String
  type_text : String
  attributes : String
} derive(Eq, Debug)

///|
pub(all) struct FunctionParseNode {
  name : String
  generic_parameters : String?
  parameters : Array[FunctionParameterParseNode]
  return_type : String?
  body_text : String
} derive(Eq, Debug)

///|
pub(all) struct FunctionParseDiagnostic {
  offset : Int
  incomplete : Bool
} derive(Eq, Debug)

///|
pub(all) enum FunctionParseResult {
  Parsed(FunctionParseNode)
  Failed(FunctionParseDiagnostic)
} derive(Eq, Debug)

///|
priv enum FunctionLexResult {
  Lexed(Array[(Token, Int, Int)])
  LexFailed(FunctionParseDiagnostic)
}

///|
fn function_parse_is_identifier_start(code : Int) -> Bool {
  (code >= 65 && code <= 90) ||
  (code >= 97 && code <= 122) ||
  code == 95 ||
  code >= 128
}

///|
fn function_parse_is_identifier_char(code : Int) -> Bool {
  function_parse_is_identifier_start(code) || (code >= 48 && code <= 57)
}

///|
fn function_parse_skip_line_comment(source : String, index : Int) -> Int {
  let mut cursor = index
  while cursor < source.length() && source.code_unit_at(cursor).to_int() != 10 {
    cursor += 1
  }
  cursor
}

///|
fn function_parse_skip_block_comment(
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
fn function_parse_skip_layout(source : String, index : Int) -> (Int, Bool) {
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
        cursor = function_parse_skip_line_comment(source, cursor + 2)
        continue
      }
      if next == 42 {
        let (end_, closed) = function_parse_skip_block_comment(
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
fn function_parse_skip_balanced(
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
        cursor = function_parse_skip_line_comment(source, cursor + 2)
        continue
      }
      if next == 42 {
        let (end_, closed) = function_parse_skip_block_comment(
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
fn function_parse_skip_attributes(source : String, index : Int) -> (Int, Bool) {
  let mut cursor = index
  while cursor < source.length() && source.code_unit_at(cursor).to_int() == 64 {
    cursor += 1
    while cursor < source.length() &&
          function_parse_is_identifier_char(
            source.code_unit_at(cursor).to_int(),
          ) {
      cursor += 1
    }
    if cursor < source.length() && source.code_unit_at(cursor).to_int() == 40 {
      let (end_, closed) = function_parse_skip_balanced(
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
    let (next, ok) = function_parse_skip_layout(source, cursor)
    if !ok {
      return (next, false)
    }
    cursor = next
  }
  (cursor, true)
}

///|
fn function_parse_read_ident(source : String, index : Int) -> (String, Int)? {
  if index >= source.length() ||
    !function_parse_is_identifier_start(source.code_unit_at(index).to_int()) {
    return None
  }
  let start = index
  let mut cursor = index + 1
  while cursor < source.length() &&
        function_parse_is_identifier_char(source.code_unit_at(cursor).to_int()) {
    cursor += 1
  }
  Some((source[start:cursor].to_owned(), cursor))
}

///|
fn function_parse_read_generics(
  source : String,
  index : Int,
) -> (String, Int, Bool) {
  let start = index + 1
  let (end_, ok) = function_parse_skip_balanced(source, index + 1, 60, 62)
  if !ok {
    return ("", end_, false)
  }
  (source[start:end_ - 1].trim().to_owned(), end_, true)
}

///|
fn function_parse_read_type_until(
  source : String,
  index : Int,
  stop_code : Int,
) -> (String, Int, Bool) {
  let start = index
  let mut cursor = index
  let mut angle_depth = 0
  let mut paren_depth = 0
  let mut bracket_depth = 0
  while cursor < source.length() {
    let code = source.code_unit_at(cursor).to_int()
    if code == 47 && cursor + 1 < source.length() {
      let next = source.code_unit_at(cursor + 1).to_int()
      if next == 47 {
        cursor = function_parse_skip_line_comment(source, cursor + 2)
        continue
      }
      if next == 42 {
        let (end_, closed) = function_parse_skip_block_comment(
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
    if code == 60 {
      angle_depth += 1
    } else if code == 62 {
      angle_depth -= 1
    } else if code == 40 {
      paren_depth += 1
    } else if code == 41 {
      paren_depth -= 1
    } else if code == 91 {
      bracket_depth += 1
    } else if code == 93 {
      bracket_depth -= 1
    } else if code == stop_code &&
      angle_depth == 0 &&
      paren_depth == 0 &&
      bracket_depth == 0 {
      return (source[start:cursor].trim().to_owned(), cursor, true)
    }
    if angle_depth < 0 || paren_depth < 0 || bracket_depth < 0 {
      return ("", cursor, false)
    }
    cursor += 1
  }
  ("", cursor, false)
}

///|
fn function_parse_read_param_type(
  source : String,
  index : Int,
) -> (String, Int, Bool) {
  let start = index
  let mut cursor = index
  let mut angle_depth = 0
  let mut paren_depth = 0
  let mut bracket_depth = 0
  while cursor < source.length() {
    let code = source.code_unit_at(cursor).to_int()
    if code == 47 && cursor + 1 < source.length() {
      let next = source.code_unit_at(cursor + 1).to_int()
      if next == 47 {
        cursor = function_parse_skip_line_comment(source, cursor + 2)
        continue
      }
      if next == 42 {
        let (end_, closed) = function_parse_skip_block_comment(
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
    if code == 60 {
      angle_depth += 1
    } else if code == 62 {
      angle_depth -= 1
    } else if code == 40 {
      paren_depth += 1
    } else if code == 41 {
      if angle_depth == 0 && paren_depth == 0 && bracket_depth == 0 {
        return (source[start:cursor].trim().to_owned(), cursor, true)
      }
      paren_depth -= 1
    } else if code == 91 {
      bracket_depth += 1
    } else if code == 93 {
      bracket_depth -= 1
    } else if code == 44 &&
      angle_depth == 0 &&
      paren_depth == 0 &&
      bracket_depth == 0 {
      return (source[start:cursor].trim().to_owned(), cursor, true)
    }
    if angle_depth < 0 || paren_depth < 0 || bracket_depth < 0 {
      return ("", cursor, false)
    }
    cursor += 1
  }
  ("", cursor, false)
}

///|
fn function_parse_keyword_token(name : String) -> Token {
  if name == "fn" {
    FN
  } else {
    IDENT(name)
  }
}

///|
fn function_parse_push(
  tokens : Array[(Token, Int, Int)],
  token : Token,
  start : Int,
  end_ : Int,
) -> Unit {
  tokens.push((token, start, end_))
}

///|
fn function_parse_lex(source : String) -> FunctionLexResult {
  let tokens : Array[(Token, Int, Int)] = []
  let mut index = 0
  let (start_index, ok) = function_parse_skip_layout(source, index)
  if !ok {
    return LexFailed(FunctionParseDiagnostic::{
      offset: index,
      incomplete: true,
    })
  }
  index = start_index
  let (after_attrs, ok) = function_parse_skip_attributes(source, index)
  if !ok {
    return LexFailed(FunctionParseDiagnostic::{
      offset: index,
      incomplete: true,
    })
  }
  index = after_attrs
  match function_parse_read_ident(source, index) {
    Some((name, end_)) => {
      function_parse_push(
        tokens,
        function_parse_keyword_token(name),
        index,
        end_,
      )
      index = end_
    }
    None =>
      return LexFailed(FunctionParseDiagnostic::{
        offset: index,
        incomplete: false,
      })
  }
  let (after_fn, ok) = function_parse_skip_layout(source, index)
  if !ok {
    return LexFailed(FunctionParseDiagnostic::{
      offset: index,
      incomplete: true,
    })
  }
  index = after_fn
  match function_parse_read_ident(source, index) {
    Some((name, end_)) => {
      function_parse_push(tokens, IDENT(name), index, end_)
      index = end_
    }
    None =>
      return LexFailed(FunctionParseDiagnostic::{
        offset: index,
        incomplete: false,
      })
  }
  let (after_name, ok) = function_parse_skip_layout(source, index)
  if !ok {
    return LexFailed(FunctionParseDiagnostic::{
      offset: index,
      incomplete: true,
    })
  }
  index = after_name
  if index < source.length() && source.code_unit_at(index).to_int() == 60 {
    let (generics, end_, ok) = function_parse_read_generics(source, index)
    if !ok {
      return LexFailed(FunctionParseDiagnostic::{
        offset: index,
        incomplete: true,
      })
    }
    function_parse_push(tokens, GENERICS(generics), index, end_)
    index = end_
    let (after_generics, ok) = function_parse_skip_layout(source, index)
    if !ok {
      return LexFailed(FunctionParseDiagnostic::{
        offset: index,
        incomplete: true,
      })
    }
    index = after_generics
  }
  if index >= source.length() || source.code_unit_at(index).to_int() != 40 {
    return LexFailed(FunctionParseDiagnostic::{
      offset: index,
      incomplete: index >= source.length(),
    })
  }
  function_parse_push(tokens, LEFT_PAREN, index, index + 1)
  index += 1
  while true {
    let (after_layout, ok) = function_parse_skip_layout(source, index)
    if !ok {
      return LexFailed(FunctionParseDiagnostic::{
        offset: index,
        incomplete: true,
      })
    }
    index = after_layout
    if index >= source.length() {
      return LexFailed(FunctionParseDiagnostic::{
        offset: index,
        incomplete: true,
      })
    }
    if source.code_unit_at(index).to_int() == 41 {
      function_parse_push(tokens, RIGHT_PAREN, index, index + 1)
      index += 1
      break
    }
    let attr_start = index
    let (after_param_attrs, ok) = function_parse_skip_attributes(source, index)
    if !ok {
      return LexFailed(FunctionParseDiagnostic::{
        offset: index,
        incomplete: true,
      })
    }
    index = after_param_attrs
    let (param_name, after_param_name) = match
      function_parse_read_ident(source, index) {
      Some(item) => item
      None =>
        return LexFailed(FunctionParseDiagnostic::{
          offset: index,
          incomplete: false,
        })
    }
    let (after_param, ok) = function_parse_skip_layout(source, after_param_name)
    if !ok {
      return LexFailed(FunctionParseDiagnostic::{
        offset: after_param_name,
        incomplete: true,
      })
    }
    if after_param >= source.length() ||
      source.code_unit_at(after_param).to_int() != 58 {
      return LexFailed(FunctionParseDiagnostic::{
        offset: after_param,
        incomplete: after_param >= source.length(),
      })
    }
    let (type_text, type_end, ok) = function_parse_read_param_type(
      source,
      after_param + 1,
    )
    if !ok || type_text == "" {
      return LexFailed(FunctionParseDiagnostic::{
        offset: after_param + 1,
        incomplete: !ok,
      })
    }
    function_parse_push(
      tokens,
      PARAM(FunctionParameterParseNode::{
        name: param_name,
        type_text,
        attributes: source[attr_start:after_param_attrs].trim().to_owned(),
      }),
      index,
      type_end,
    )
    index = type_end
    if index < source.length() && source.code_unit_at(index).to_int() == 44 {
      index += 1
    }
  }
  let (after_params, ok) = function_parse_skip_layout(source, index)
  if !ok {
    return LexFailed(FunctionParseDiagnostic::{
      offset: index,
      incomplete: true,
    })
  }
  index = after_params
  if index + 1 < source.length() &&
    source.code_unit_at(index).to_int() == 45 &&
    source.code_unit_at(index + 1).to_int() == 62 {
    index += 2
    let (after_arrow, ok) = function_parse_skip_layout(source, index)
    if !ok {
      return LexFailed(FunctionParseDiagnostic::{
        offset: index,
        incomplete: true,
      })
    }
    index = after_arrow
    let (after_return_attrs, ok) = function_parse_skip_attributes(source, index)
    if !ok {
      return LexFailed(FunctionParseDiagnostic::{
        offset: index,
        incomplete: true,
      })
    }
    index = after_return_attrs
    let (return_type, return_end, ok) = function_parse_read_type_until(
      source, index, 123,
    )
    if !ok || return_type == "" {
      return LexFailed(FunctionParseDiagnostic::{
        offset: index,
        incomplete: !ok,
      })
    }
    function_parse_push(tokens, RETURN_TYPE(return_type), index, return_end)
    index = return_end
    let (after_return, ok) = function_parse_skip_layout(source, index)
    if !ok {
      return LexFailed(FunctionParseDiagnostic::{
        offset: index,
        incomplete: true,
      })
    }
    index = after_return
  }
  if index >= source.length() || source.code_unit_at(index).to_int() != 123 {
    return LexFailed(FunctionParseDiagnostic::{
      offset: index,
      incomplete: index >= source.length(),
    })
  }
  let (body_end, ok) = function_parse_skip_balanced(source, index + 1, 123, 125)
  if !ok {
    return LexFailed(FunctionParseDiagnostic::{
      offset: index,
      incomplete: true,
    })
  }
  function_parse_push(
    tokens,
    BODY(source[index + 1:body_end - 1].to_owned()),
    index,
    body_end,
  )
  Lexed(tokens)
}

///|
pub fn parse_function_source(source : String) -> FunctionParseResult {
  let tokens = match function_parse_lex(source) {
    Lexed(tokens) => tokens
    LexFailed(diagnostic) => return Failed(diagnostic)
  }
  let parsed = parse_function_decl(tokens) catch {
    UnexpectedToken(_, (start, _), _) =>
      return Failed(FunctionParseDiagnostic::{
        offset: start,
        incomplete: false,
      })
    UnexpectedEndOfInput(start, _) =>
      return Failed(FunctionParseDiagnostic::{ offset: start, incomplete: true })
  }
  Parsed(parsed)
}
