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
pub(all) struct StructMemberParseNode {
  name : String
  type_text : String
  attributes : String
} derive(Eq, Debug)

///|
pub(all) struct StructParseNode {
  name : String
  members : Array[StructMemberParseNode]
} derive(Eq, Debug)

///|
pub(all) struct StructParseDiagnostic {
  offset : Int
  incomplete : Bool
} derive(Eq, Debug)

///|
pub(all) enum StructParseResult {
  Parsed(StructParseNode)
  Failed(StructParseDiagnostic)
} derive(Eq, Debug)

///|
priv enum StructLexResult {
  Lexed(Array[(Token, Int, Int)])
  LexFailed(StructParseDiagnostic)
}

///|
fn struct_parse_is_identifier_start(code : Int) -> Bool {
  (code >= 65 && code <= 90) ||
  (code >= 97 && code <= 122) ||
  code == 95 ||
  code >= 128
}

///|
fn struct_parse_is_identifier_char(code : Int) -> Bool {
  struct_parse_is_identifier_start(code) || (code >= 48 && code <= 57)
}

///|
fn struct_parse_skip_line_comment(source : String, index : Int) -> Int {
  let mut cursor = index
  while cursor < source.length() && source.code_unit_at(cursor).to_int() != 10 {
    cursor += 1
  }
  cursor
}

///|
fn struct_parse_skip_block_comment(source : String, index : Int) -> (Int, Bool) {
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
fn struct_parse_skip_layout(source : String, index : Int) -> (Int, Bool) {
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
        cursor = struct_parse_skip_line_comment(source, cursor + 2)
        continue
      }
      if next == 42 {
        let (end_, closed) = struct_parse_skip_block_comment(source, cursor + 2)
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
fn struct_parse_skip_attributes(source : String, index : Int) -> (Int, Bool) {
  let mut cursor = index
  while cursor < source.length() && source.code_unit_at(cursor).to_int() == 64 {
    cursor += 1
    while cursor < source.length() &&
          struct_parse_is_identifier_char(source.code_unit_at(cursor).to_int()) {
      cursor += 1
    }
    if cursor < source.length() && source.code_unit_at(cursor).to_int() == 40 {
      let mut depth = 1
      cursor += 1
      while cursor < source.length() {
        let code = source.code_unit_at(cursor).to_int()
        if code == 40 {
          depth += 1
        } else if code == 41 {
          depth -= 1
          cursor += 1
          if depth == 0 {
            break
          }
          continue
        }
        cursor += 1
      }
      if depth != 0 {
        return (cursor, false)
      }
    }
    let (next, ok) = struct_parse_skip_layout(source, cursor)
    if !ok {
      return (next, false)
    }
    cursor = next
  }
  (cursor, true)
}

///|
fn struct_parse_read_ident(source : String, index : Int) -> (String, Int)? {
  if index >= source.length() ||
    !struct_parse_is_identifier_start(source.code_unit_at(index).to_int()) {
    return None
  }
  let start = index
  let mut cursor = index + 1
  while cursor < source.length() &&
        struct_parse_is_identifier_char(source.code_unit_at(cursor).to_int()) {
    cursor += 1
  }
  Some((source[start:cursor].to_owned(), cursor))
}

///|
fn struct_parse_read_type(source : String, index : Int) -> (String, Int, Bool) {
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
        cursor = struct_parse_skip_line_comment(source, cursor + 2)
        continue
      }
      if next == 42 {
        let (end_, closed) = struct_parse_skip_block_comment(source, cursor + 2)
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
    } else if (code == 44 || code == 125) &&
      angle_depth == 0 &&
      paren_depth == 0 &&
      bracket_depth == 0 {
      return (source[start:cursor].trim().to_owned(), cursor, true)
    }
    cursor += 1
  }
  ("", cursor, false)
}

///|
fn struct_parse_keyword_token(name : String) -> Token {
  if name == "struct" {
    STRUCT
  } else {
    IDENT(name)
  }
}

///|
fn struct_parse_push(
  tokens : Array[(Token, Int, Int)],
  token : Token,
  start : Int,
  end_ : Int,
) -> Unit {
  tokens.push((token, start, end_))
}

///|
fn struct_parse_lex(source : String) -> StructLexResult {
  let tokens : Array[(Token, Int, Int)] = []
  let mut index = 0
  let (start_index, ok) = struct_parse_skip_layout(source, index)
  if !ok {
    return LexFailed({ offset: index, incomplete: true })
  }
  index = start_index
  let (after_attrs, ok) = struct_parse_skip_attributes(source, index)
  if !ok {
    return LexFailed({ offset: index, incomplete: true })
  }
  index = after_attrs
  match struct_parse_read_ident(source, index) {
    Some((name, end_)) => {
      struct_parse_push(tokens, struct_parse_keyword_token(name), index, end_)
      index = end_
    }
    None => return LexFailed({ offset: index, incomplete: false })
  }
  let (after_struct, ok) = struct_parse_skip_layout(source, index)
  if !ok {
    return LexFailed({ offset: index, incomplete: true })
  }
  index = after_struct
  match struct_parse_read_ident(source, index) {
    Some((name, end_)) => {
      struct_parse_push(tokens, IDENT(name), index, end_)
      index = end_
    }
    None => return LexFailed({ offset: index, incomplete: false })
  }
  let (after_name, ok) = struct_parse_skip_layout(source, index)
  if !ok {
    return LexFailed({ offset: index, incomplete: true })
  }
  index = after_name
  if index >= source.length() || source.code_unit_at(index).to_int() != 123 {
    return LexFailed({ offset: index, incomplete: index >= source.length() })
  }
  struct_parse_push(tokens, LEFT_BRACE, index, index + 1)
  index += 1
  while true {
    let (after_layout, ok) = struct_parse_skip_layout(source, index)
    if !ok {
      return LexFailed({ offset: index, incomplete: true })
    }
    index = after_layout
    if index >= source.length() {
      return LexFailed({ offset: index, incomplete: true })
    }
    if source.code_unit_at(index).to_int() == 125 {
      struct_parse_push(tokens, RIGHT_BRACE, index, index + 1)
      index += 1
      break
    }
    let attr_start = index
    let (after_attrs, ok) = struct_parse_skip_attributes(source, index)
    if !ok {
      return LexFailed({ offset: index, incomplete: true })
    }
    index = after_attrs
    let (member_name, after_member_name) = match
      struct_parse_read_ident(source, index) {
      Some(item) => item
      None => return LexFailed({ offset: index, incomplete: false })
    }
    let (after_member, ok) = struct_parse_skip_layout(source, after_member_name)
    if !ok {
      return LexFailed({ offset: after_member_name, incomplete: true })
    }
    if after_member >= source.length() ||
      source.code_unit_at(after_member).to_int() != 58 {
      return LexFailed({
        offset: after_member,
        incomplete: after_member >= source.length(),
      })
    }
    let (type_text, type_end, ok) = struct_parse_read_type(
      source,
      after_member + 1,
    )
    if !ok || type_text == "" {
      return LexFailed({ offset: after_member + 1, incomplete: !ok })
    }
    struct_parse_push(
      tokens,
      MEMBER({
        name: member_name,
        type_text,
        attributes: source[attr_start:after_attrs].trim().to_owned(),
      }),
      index,
      type_end,
    )
    index = type_end
    if index < source.length() && source.code_unit_at(index).to_int() == 44 {
      index += 1
    }
  }
  let (after_body, ok) = struct_parse_skip_layout(source, index)
  if !ok {
    return LexFailed({ offset: index, incomplete: true })
  }
  index = after_body
  if index < source.length() && source.code_unit_at(index).to_int() == 59 {
    struct_parse_push(tokens, SEMI, index, index + 1)
  }
  Lexed(tokens)
}

///|
pub fn parse_struct_source(source : String) -> StructParseResult {
  let tokens = match struct_parse_lex(source) {
    Lexed(tokens) => tokens
    LexFailed(diagnostic) => return Failed(diagnostic)
  }
  let parsed = parse_struct_decl(tokens) catch {
    UnexpectedToken(_, (start, _), _) =>
      return Failed({ offset: start, incomplete: false })
    UnexpectedEndOfInput(start, _) =>
      return Failed({ offset: start, incomplete: true })
  }
  Parsed(parsed)
}
