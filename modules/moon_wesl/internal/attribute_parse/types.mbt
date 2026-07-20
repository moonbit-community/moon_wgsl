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
pub(all) struct AttributeParseNode {
  name : String
  arguments : String?
  start_line : Int
  end_line : Int
  end_offset : Int
} derive(Eq, Debug)

///|
pub(all) struct AttributeParseDiagnostic {
  offset : Int
  incomplete : Bool
} derive(Eq, Debug)

///|
pub(all) struct AttributeParseSuccess {
  attributes : Array[AttributeParseNode]
  consumed_offset : Int
} derive(Eq, Debug)

///|
pub(all) enum AttributeParseResult {
  Parsed(AttributeParseSuccess)
  Failed(AttributeParseDiagnostic)
} derive(Eq, Debug)

///|
priv enum AttributeLexResult {
  Lexed(Array[(Token, Int, Int)], Int)
  LexFailed(AttributeParseDiagnostic)
}

///|
fn attribute_parse_is_identifier_start(code : Int) -> Bool {
  (code >= 65 && code <= 90) ||
  (code >= 97 && code <= 122) ||
  code == 95 ||
  code >= 128
}

///|
fn attribute_parse_is_identifier_char(code : Int) -> Bool {
  attribute_parse_is_identifier_start(code) || (code >= 48 && code <= 57)
}

///|
fn attribute_parse_skip_line_comment(source : String, index : Int) -> Int {
  let mut cursor = index
  while cursor < source.length() && source.code_unit_at(cursor).to_int() != 10 {
    cursor += 1
  }
  cursor
}

///|
fn attribute_parse_skip_block_comment(
  source : String,
  index : Int,
  line : Int,
) -> (Int, Int, Bool) {
  let mut cursor = index
  let mut current_line = line
  let mut depth = 1
  while cursor + 1 < source.length() {
    let current = source.code_unit_at(cursor).to_int()
    let next = source.code_unit_at(cursor + 1).to_int()
    if current == 10 {
      current_line += 1
      cursor += 1
      continue
    }
    if current == 47 && next == 42 {
      depth += 1
      cursor += 2
      continue
    }
    if current == 42 && next == 47 {
      depth -= 1
      cursor += 2
      if depth == 0 {
        return (cursor, current_line, true)
      }
      continue
    }
    cursor += 1
  }
  (cursor, current_line, false)
}

///|
fn attribute_parse_read_arguments(
  source : String,
  index : Int,
  line : Int,
) -> (String, Int, Int, Bool) {
  let start = index
  let mut cursor = index
  let mut current_line = line
  let mut depth = 1
  while cursor < source.length() {
    let code = source.code_unit_at(cursor).to_int()
    if code == 10 {
      current_line += 1
      cursor += 1
      continue
    }
    if code == 47 && cursor + 1 < source.length() {
      let next = source.code_unit_at(cursor + 1).to_int()
      if next == 47 {
        cursor = attribute_parse_skip_line_comment(source, cursor + 2)
        continue
      }
      if next == 42 {
        let (end_, end_line, closed) = attribute_parse_skip_block_comment(
          source,
          cursor + 2,
          current_line,
        )
        if !closed {
          return ("", end_, end_line, false)
        }
        cursor = end_
        current_line = end_line
        continue
      }
    }
    if code == 40 {
      depth += 1
    } else if code == 41 {
      depth -= 1
      if depth == 0 {
        return (
          source[start:cursor].trim().to_owned(),
          cursor + 1,
          current_line,
          true,
        )
      }
    }
    cursor += 1
  }
  ("", cursor, current_line, false)
}

///|
fn attribute_parse_lex(source : String) -> AttributeLexResult {
  let tokens : Array[(Token, Int, Int)] = []
  let mut index = 0
  let mut line = 1
  let mut consumed_offset = 0
  while index < source.length() {
    let code = source.code_unit_at(index).to_int()
    if code == 32 || code == 9 || code == 13 {
      index += 1
      continue
    }
    if code == 10 {
      line += 1
      index += 1
      continue
    }
    if code == 47 && index + 1 < source.length() {
      let next = source.code_unit_at(index + 1).to_int()
      if next == 47 {
        index = attribute_parse_skip_line_comment(source, index + 2)
        continue
      }
      if next == 42 {
        let (end_, end_line, closed) = attribute_parse_skip_block_comment(
          source,
          index + 2,
          line,
        )
        if !closed {
          return LexFailed(AttributeParseDiagnostic::{
            offset: index,
            incomplete: true,
          })
        }
        index = end_
        line = end_line
        continue
      }
    }
    if code != 64 {
      break
    }
    let attr_start = index
    let start_line = line
    index += 1
    if index >= source.length() ||
      !attribute_parse_is_identifier_start(source.code_unit_at(index).to_int()) {
      return LexFailed(AttributeParseDiagnostic::{
        offset: index,
        incomplete: index >= source.length(),
      })
    }
    let name_start = index
    index += 1
    while index < source.length() &&
          attribute_parse_is_identifier_char(
            source.code_unit_at(index).to_int(),
          ) {
      index += 1
    }
    let name = source[name_start:index].to_owned()
    let mut arguments : String? = None
    let mut end_line = line
    if index < source.length() && source.code_unit_at(index).to_int() == 40 {
      let (args, end_, args_end_line, closed) = attribute_parse_read_arguments(
        source,
        index + 1,
        line,
      )
      if !closed {
        return LexFailed(AttributeParseDiagnostic::{
          offset: attr_start,
          incomplete: true,
        })
      }
      arguments = Some(args)
      index = end_
      end_line = args_end_line
      line = args_end_line
    }
    consumed_offset = index
    tokens.push(
      (
        ATTRIBUTE(AttributeParseNode::{
          name,
          arguments,
          start_line,
          end_line,
          end_offset: consumed_offset,
        }),
        attr_start,
        consumed_offset,
      ),
    )
  }
  Lexed(tokens, consumed_offset)
}

///|
pub fn parse_attributes_source(source : String) -> AttributeParseResult {
  let (tokens, consumed_offset) = match attribute_parse_lex(source) {
    Lexed(tokens, consumed_offset) => (tokens, consumed_offset)
    LexFailed(diagnostic) => return Failed(diagnostic)
  }
  if tokens.is_empty() {
    return Parsed(AttributeParseSuccess::{ attributes: [], consumed_offset })
  }
  let attributes = parse_attributes(tokens) catch {
    UnexpectedToken(_, (start, _), _) =>
      return Failed(AttributeParseDiagnostic::{
        offset: start,
        incomplete: false,
      })
    UnexpectedEndOfInput(start, _) =>
      return Failed(AttributeParseDiagnostic::{
        offset: start,
        incomplete: true,
      })
  }
  Parsed(AttributeParseSuccess::{ attributes, consumed_offset })
}
