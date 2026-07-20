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
pub(all) enum DirectiveParseKind {
  Enable
  Requires
  Diagnostic
} derive(Eq, Debug)

///|
pub(all) struct DirectiveParseNode {
  kind : DirectiveParseKind
  arguments : Array[String]
} derive(Eq, Debug)

///|
pub(all) struct DirectiveParseDiagnostic {
  offset : Int
  incomplete : Bool
} derive(Eq, Debug)

///|
pub(all) enum DirectiveParseResult {
  Parsed(DirectiveParseNode)
  Failed(DirectiveParseDiagnostic)
} derive(Eq, Debug)

///|
priv enum DirectiveLexResult {
  Lexed(Array[(Token, Int, Int)])
  LexFailed(DirectiveParseDiagnostic)
}

///|
fn directive_parse_skip_line_comment(source : String, index : Int) -> Int {
  let mut cursor = index
  while cursor < source.length() && source.code_unit_at(cursor).to_int() != 10 {
    cursor += 1
  }
  cursor
}

///|
fn directive_parse_skip_block_comment(
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
fn directive_parse_skip_layout(source : String, index : Int) -> (Int, Bool) {
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
        cursor = directive_parse_skip_line_comment(source, cursor + 2)
        continue
      }
      if next == 42 {
        let (end_, closed) = directive_parse_skip_block_comment(
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
fn directive_parse_is_identifier_start(code : Int) -> Bool {
  (code >= 65 && code <= 90) ||
  (code >= 97 && code <= 122) ||
  code == 95 ||
  code >= 128
}

///|
fn directive_parse_is_item_char(code : Int) -> Bool {
  directive_parse_is_identifier_start(code) ||
  (code >= 48 && code <= 57) ||
  code == 46
}

///|
fn directive_parse_read_item(source : String, index : Int) -> (String, Int)? {
  if index >= source.length() ||
    !directive_parse_is_identifier_start(source.code_unit_at(index).to_int()) {
    return None
  }
  let start = index
  let mut cursor = index + 1
  while cursor < source.length() &&
        directive_parse_is_item_char(source.code_unit_at(cursor).to_int()) {
    cursor += 1
  }
  Some((source[start:cursor].to_owned(), cursor))
}

///|
fn directive_parse_skip_balanced(
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
fn directive_parse_skip_attributes(source : String, index : Int) -> (Int, Bool) {
  let mut cursor = index
  while cursor < source.length() && source.code_unit_at(cursor).to_int() == 64 {
    cursor += 1
    match directive_parse_read_item(source, cursor) {
      Some((_, end_)) => cursor = end_
      None => return (cursor, false)
    }
    if cursor < source.length() && source.code_unit_at(cursor).to_int() == 40 {
      let (end_, ok) = directive_parse_skip_balanced(source, cursor + 1, 40, 41)
      if !ok {
        return (end_, false)
      }
      cursor = end_
    }
    let (next, ok) = directive_parse_skip_layout(source, cursor)
    if !ok {
      return (next, false)
    }
    cursor = next
  }
  (cursor, true)
}

///|
fn directive_parse_keyword_token(name : String) -> Token {
  match name {
    "enable" => ENABLE
    "requires" => REQUIRES
    "diagnostic" => DIAGNOSTIC
    _ => ITEM(name)
  }
}

///|
fn directive_parse_push(
  tokens : Array[(Token, Int, Int)],
  token : Token,
  start : Int,
  end_ : Int,
) -> Unit {
  tokens.push((token, start, end_))
}

///|
fn directive_parse_lex(source : String) -> DirectiveLexResult {
  let tokens : Array[(Token, Int, Int)] = []
  let mut index = 0
  let (start_index, ok) = directive_parse_skip_layout(source, index)
  if !ok {
    return LexFailed({ offset: index, incomplete: true })
  }
  index = start_index
  let (after_attrs, ok) = directive_parse_skip_attributes(source, index)
  if !ok {
    return LexFailed({ offset: index, incomplete: true })
  }
  index = after_attrs
  let (keyword, after_keyword) = match
    directive_parse_read_item(source, index) {
    Some(item) => item
    None => return LexFailed({ offset: index, incomplete: false })
  }
  directive_parse_push(
    tokens,
    directive_parse_keyword_token(keyword),
    index,
    after_keyword,
  )
  index = after_keyword
  while true {
    let (after_layout, ok) = directive_parse_skip_layout(source, index)
    if !ok {
      return LexFailed({ offset: index, incomplete: true })
    }
    index = after_layout
    if index >= source.length() {
      break
    }
    let code = source.code_unit_at(index).to_int()
    if code == 40 {
      directive_parse_push(tokens, LEFT_PAREN, index, index + 1)
      index += 1
      continue
    }
    if code == 41 {
      directive_parse_push(tokens, RIGHT_PAREN, index, index + 1)
      index += 1
      continue
    }
    if code == 44 {
      directive_parse_push(tokens, COMMA, index, index + 1)
      index += 1
      continue
    }
    if code == 59 {
      directive_parse_push(tokens, SEMI, index, index + 1)
      index += 1
      continue
    }
    match directive_parse_read_item(source, index) {
      Some((item, end_)) => {
        directive_parse_push(tokens, ITEM(item), index, end_)
        index = end_
      }
      None => return LexFailed({ offset: index, incomplete: false })
    }
  }
  Lexed(tokens)
}

///|
pub fn parse_directive_source(source : String) -> DirectiveParseResult {
  let tokens = match directive_parse_lex(source) {
    Lexed(tokens) => tokens
    LexFailed(diagnostic) => return Failed(diagnostic)
  }
  let parsed = parse_directive(tokens) catch {
    UnexpectedToken(_, (start, _), _) =>
      return Failed({ offset: start, incomplete: false })
    UnexpectedEndOfInput(start, _) =>
      return Failed({ offset: start, incomplete: true })
  }
  Parsed(parsed)
}
