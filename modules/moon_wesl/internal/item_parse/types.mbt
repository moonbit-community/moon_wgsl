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
pub(all) struct TopLevelItemSpan {
  start_offset : Int
  end_offset : Int
} derive(Eq, Debug)

///|
pub(all) struct TopLevelItemDiagnostic {
  offset : Int
  incomplete : Bool
} derive(Eq, Debug)

///|
pub(all) enum TopLevelItemParseResult {
  Parsed(Array[TopLevelItemSpan])
  Failed(TopLevelItemDiagnostic)
} derive(Eq, Debug)

///|
priv enum TopLevelItemLexResult {
  Lexed(Array[(Token, Int, Int)])
  LexFailed(TopLevelItemDiagnostic)
}

///|
fn item_parse_skip_line_comment(source : String, index : Int) -> Int {
  let mut cursor = index
  while cursor < source.length() && source.code_unit_at(cursor).to_int() != 10 {
    cursor += 1
  }
  cursor
}

///|
fn item_parse_skip_block_comment(source : String, index : Int) -> (Int, Bool) {
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
fn item_parse_skip_trivia(source : String, index : Int) -> (Int, Bool) {
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
        cursor = item_parse_skip_line_comment(source, cursor + 2)
        continue
      }
      if next == 42 {
        let (end_, closed) = item_parse_skip_block_comment(source, cursor + 2)
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
fn item_parse_push_item(
  tokens : Array[(Token, Int, Int)],
  start_offset : Int,
  end_offset : Int,
) -> Unit {
  tokens.push(
    (
      ITEM(TopLevelItemSpan::{ start_offset, end_offset }),
      start_offset,
      end_offset,
    ),
  )
}

///|
fn item_parse_lex(source : String) -> TopLevelItemLexResult {
  let tokens : Array[(Token, Int, Int)] = []
  let mut index = 0
  let mut item_start : Int? = None
  let mut paren_depth = 0
  let mut bracket_depth = 0
  let mut brace_depth = 0
  let mut saw_brace = false
  while index < source.length() {
    if item_start is None {
      let (next_index, ok) = item_parse_skip_trivia(source, index)
      if !ok {
        return LexFailed(TopLevelItemDiagnostic::{
          offset: next_index,
          incomplete: true,
        })
      }
      index = next_index
      if index >= source.length() {
        break
      }
      item_start = Some(index)
    }
    let code = source.code_unit_at(index).to_int()
    if code == 47 && index + 1 < source.length() {
      let next = source.code_unit_at(index + 1).to_int()
      if next == 47 {
        index = item_parse_skip_line_comment(source, index + 2)
        continue
      }
      if next == 42 {
        let (end_, closed) = item_parse_skip_block_comment(source, index + 2)
        if !closed {
          return LexFailed(TopLevelItemDiagnostic::{
            offset: index,
            incomplete: true,
          })
        }
        index = end_
        continue
      }
    }
    if code == 40 {
      paren_depth += 1
      index += 1
      continue
    }
    if code == 41 {
      paren_depth -= 1
      index += 1
      continue
    }
    if code == 91 {
      bracket_depth += 1
      index += 1
      continue
    }
    if code == 93 {
      bracket_depth -= 1
      index += 1
      continue
    }
    if code == 123 {
      brace_depth += 1
      saw_brace = true
      index += 1
      continue
    }
    if code == 125 {
      brace_depth -= 1
      index += 1
      if paren_depth == 0 && bracket_depth == 0 && brace_depth == 0 && saw_brace {
        let (after_trivia, ok) = item_parse_skip_trivia(source, index)
        if !ok {
          return LexFailed(TopLevelItemDiagnostic::{
            offset: after_trivia,
            incomplete: true,
          })
        }
        let end_offset = if after_trivia < source.length() &&
          source.code_unit_at(after_trivia).to_int() == 59 {
          after_trivia + 1
        } else {
          index
        }
        match item_start {
          Some(start) => item_parse_push_item(tokens, start, end_offset)
          None => ()
        }
        index = end_offset
        item_start = None
        paren_depth = 0
        bracket_depth = 0
        brace_depth = 0
        saw_brace = false
      }
      continue
    }
    if code == 59 && paren_depth == 0 && bracket_depth == 0 && brace_depth == 0 {
      match item_start {
        Some(start) => item_parse_push_item(tokens, start, index + 1)
        None => ()
      }
      index += 1
      item_start = None
      saw_brace = false
      continue
    }
    index += 1
  }
  match item_start {
    Some(start) =>
      return LexFailed(TopLevelItemDiagnostic::{
        offset: start,
        incomplete: true,
      })
    None => ()
  }
  Lexed(tokens)
}

///|
pub fn parse_top_level_items_source(source : String) -> TopLevelItemParseResult {
  let tokens = match item_parse_lex(source) {
    Lexed(tokens) => tokens
    LexFailed(diagnostic) => return Failed(diagnostic)
  }
  if tokens.is_empty() {
    return Parsed([])
  }
  let items = parse_top_level_items(tokens) catch {
    UnexpectedToken(_, (start, _), _) =>
      return Failed(TopLevelItemDiagnostic::{ offset: start, incomplete: false })
    UnexpectedEndOfInput(start, _) =>
      return Failed(TopLevelItemDiagnostic::{ offset: start, incomplete: true })
  }
  Parsed(items)
}
