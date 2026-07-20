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
pub(all) enum StatementParseKind {
  Empty
  Block
  Return
  Discard
  If
  Switch
  Loop
  For
  While
  Continuing
  Break
  Continue
  BreakIf
  ConstAssert
  Const
  Let
  Var
  Assignment
  CompoundAssignment
  Increment
  Decrement
  Call
  Other
} derive(Eq, Debug)

///|
pub(all) struct StatementParseNode {
  kind : StatementParseKind
  source : String
} derive(Eq, Debug)

///|
pub(all) struct FunctionBodyParseNode {
  statements : Array[StatementParseNode]
} derive(Eq, Debug)

///|
pub(all) struct StatementParseDiagnostic {
  offset : Int
  incomplete : Bool
} derive(Eq, Debug)

///|
pub(all) enum StatementParseResult {
  Parsed(FunctionBodyParseNode)
  Failed(StatementParseDiagnostic)
} derive(Eq, Debug)

///|
priv enum StatementLexResult {
  Lexed(Array[(Token, Int, Int)])
  LexFailed(StatementParseDiagnostic)
}

///|
fn statement_parse_is_identifier_start(code : Int) -> Bool {
  (code >= 65 && code <= 90) ||
  (code >= 97 && code <= 122) ||
  code == 95 ||
  code >= 128
}

///|
fn statement_parse_is_identifier_char(code : Int) -> Bool {
  statement_parse_is_identifier_start(code) || (code >= 48 && code <= 57)
}

///|
fn statement_parse_skip_line_comment(source : String, index : Int) -> Int {
  let mut cursor = index
  while cursor < source.length() && source.code_unit_at(cursor).to_int() != 10 {
    cursor += 1
  }
  cursor
}

///|
fn statement_parse_skip_block_comment(
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
fn statement_parse_skip_layout(source : String, index : Int) -> (Int, Bool) {
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
        cursor = statement_parse_skip_line_comment(source, cursor + 2)
        continue
      }
      if next == 42 {
        let (end_, closed) = statement_parse_skip_block_comment(
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
fn statement_parse_read_ident(source : String, index : Int) -> (String, Int)? {
  if index >= source.length() ||
    !statement_parse_is_identifier_start(source.code_unit_at(index).to_int()) {
    return None
  }
  let start = index
  let mut cursor = index + 1
  while cursor < source.length() &&
        statement_parse_is_identifier_char(source.code_unit_at(cursor).to_int()) {
    cursor += 1
  }
  Some((source[start:cursor].to_owned(), cursor))
}

///|
fn statement_parse_skip_balanced(
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
        cursor = statement_parse_skip_line_comment(source, cursor + 2)
        continue
      }
      if next == 42 {
        let (end_, closed) = statement_parse_skip_block_comment(
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
fn statement_parse_skip_attributes(source : String, index : Int) -> (Int, Bool) {
  let mut cursor = index
  while cursor < source.length() && source.code_unit_at(cursor).to_int() == 64 {
    cursor += 1
    match statement_parse_read_ident(source, cursor) {
      Some((_, end_)) => cursor = end_
      None => return (cursor, false)
    }
    if cursor < source.length() && source.code_unit_at(cursor).to_int() == 40 {
      let (end_, ok) = statement_parse_skip_balanced(source, cursor + 1, 40, 41)
      if !ok {
        return (end_, false)
      }
      cursor = end_
    }
    let (next, ok) = statement_parse_skip_layout(source, cursor)
    if !ok {
      return (next, false)
    }
    cursor = next
  }
  (cursor, true)
}

///|
fn statement_parse_keyword_at(source : String, index : Int) -> String? {
  let (after_attrs, ok) = statement_parse_skip_attributes(source, index)
  if !ok {
    return None
  }
  match statement_parse_read_ident(source, after_attrs) {
    Some((name, _)) => Some(name)
    None => None
  }
}

///|
fn statement_parse_contains_top_level_assignment(source : String) -> Bool {
  let mut cursor = 0
  let mut paren_depth = 0
  let mut bracket_depth = 0
  let mut brace_depth = 0
  while cursor < source.length() {
    let code = source.code_unit_at(cursor).to_int()
    if code == 40 {
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
    } else if code == 61 &&
      paren_depth == 0 &&
      bracket_depth == 0 &&
      brace_depth == 0 {
      let previous = if cursor > 0 {
        source.code_unit_at(cursor - 1).to_int()
      } else {
        -1
      }
      let next = if cursor + 1 < source.length() {
        source.code_unit_at(cursor + 1).to_int()
      } else {
        -1
      }
      return previous != 61 && next != 61
    }
    cursor += 1
  }
  false
}

///|
fn statement_parse_contains_compound_assignment(source : String) -> Bool {
  let operators = ["+=", "-=", "*=", "/=", "%=", "&=", "|=", "^=", "<<=", ">>="]
  for op in operators {
    if source.contains(op) {
      return true
    }
  }
  false
}

///|
fn statement_parse_kind(
  source : String,
  start : Int,
  end_ : Int,
) -> StatementParseKind {
  let text = source[start:end_].trim().to_owned()
  if text == ";" {
    return Empty
  }
  match statement_parse_keyword_at(source, start) {
    Some("return") => Return
    Some("discard") => Discard
    Some("if") => If
    Some("switch") => Switch
    Some("loop") => Loop
    Some("for") => For
    Some("while") => While
    Some("continuing") => Continuing
    Some("break") => if text.has_prefix("break if") { BreakIf } else { Break }
    Some("continue") => Continue
    Some("const_assert") => ConstAssert
    Some("const") => Const
    Some("let") => Let
    Some("var") => Var
    _ =>
      if text.has_suffix("++;") {
        Increment
      } else if text.has_suffix("--;") {
        Decrement
      } else if statement_parse_contains_compound_assignment(text) {
        CompoundAssignment
      } else if statement_parse_contains_top_level_assignment(text) {
        Assignment
      } else if text.has_suffix(");") {
        Call
      } else if text.has_prefix("{") {
        Block
      } else {
        Other
      }
  }
}

///|
fn statement_parse_statement_end(source : String, index : Int) -> (Int, Bool) {
  let mut cursor = index
  let mut paren_depth = 0
  let mut bracket_depth = 0
  let mut brace_depth = 0
  while cursor < source.length() {
    let code = source.code_unit_at(cursor).to_int()
    if code == 47 && cursor + 1 < source.length() {
      let next = source.code_unit_at(cursor + 1).to_int()
      if next == 47 {
        cursor = statement_parse_skip_line_comment(source, cursor + 2)
        continue
      }
      if next == 42 {
        let (end_, closed) = statement_parse_skip_block_comment(
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
    if code == 40 {
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
      if brace_depth == 0 && paren_depth == 0 && bracket_depth == 0 {
        return (cursor + 1, true)
      }
    } else if code == 59 &&
      paren_depth == 0 &&
      bracket_depth == 0 &&
      brace_depth == 0 {
      return (cursor + 1, true)
    }
    if paren_depth < 0 || bracket_depth < 0 || brace_depth < 0 {
      return (cursor, false)
    }
    cursor += 1
  }
  (cursor, false)
}

///|
fn statement_parse_lex(source : String) -> StatementLexResult {
  let tokens : Array[(Token, Int, Int)] = []
  let mut index = 0
  while index < source.length() {
    let (start, ok) = statement_parse_skip_layout(source, index)
    if !ok {
      return LexFailed(StatementParseDiagnostic::{
        offset: index,
        incomplete: true,
      })
    }
    index = start
    if index >= source.length() {
      break
    }
    let (end_, ok) = statement_parse_statement_end(source, index)
    if !ok {
      return LexFailed(StatementParseDiagnostic::{
        offset: index,
        incomplete: true,
      })
    }
    let text = source[index:end_].trim().to_owned()
    tokens.push(
      (
        STATEMENT(StatementParseNode::{
          kind: statement_parse_kind(source, index, end_),
          source: text,
        }),
        index,
        end_,
      ),
    )
    index = end_
  }
  Lexed(tokens)
}

///|
pub fn parse_function_body_source(source : String) -> StatementParseResult {
  let tokens = match statement_parse_lex(source) {
    Lexed(tokens) => tokens
    LexFailed(diagnostic) => return Failed(diagnostic)
  }
  if tokens.is_empty() {
    return Parsed(FunctionBodyParseNode::{ statements: [] })
  }
  let parsed = parse_function_body(tokens) catch {
    UnexpectedToken(_, (start, _), _) =>
      return Failed(StatementParseDiagnostic::{
        offset: start,
        incomplete: false,
      })
    UnexpectedEndOfInput(start, _) =>
      return Failed(StatementParseDiagnostic::{
        offset: start,
        incomplete: true,
      })
  }
  Parsed(parsed)
}
