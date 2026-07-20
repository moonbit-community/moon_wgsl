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
pub(all) struct ImportParseNode {
  path_segments : Array[String]
  rename : String?
  children : Array[ImportParseNode]
} derive(Eq, Debug)

///|
pub(all) struct ImportParseDiagnostic {
  offset : Int
  incomplete : Bool
} derive(Eq, Debug)

///|
pub(all) enum ImportParseResult {
  Parsed(Array[ImportParseNode])
  Failed(ImportParseDiagnostic)
} derive(Eq, Debug)

///|
priv enum ImportLexResult {
  Lexed(Array[(Token, Int, Int)])
  LexFailed(ImportParseDiagnostic)
}

///|
fn import_parse_is_identifier_start(code : Int) -> Bool {
  (code >= 65 && code <= 90) || (code >= 97 && code <= 122) || code == 95
}

///|
fn import_parse_is_identifier_char(code : Int) -> Bool {
  import_parse_is_identifier_start(code) || (code >= 48 && code <= 57)
}

///|
fn import_parse_lex(source : String) -> ImportLexResult {
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
        index += 2
        while index < source.length() &&
              source.code_unit_at(index).to_int() != 10 {
          index += 1
        }
        continue
      }
      if next == 42 {
        index += 2
        let mut closed = false
        while index + 1 < source.length() {
          if source.code_unit_at(index).to_int() == 42 &&
            source.code_unit_at(index + 1).to_int() == 47 {
            index += 2
            closed = true
            break
          }
          index += 1
        }
        if !closed {
          return LexFailed(ImportParseDiagnostic::{
            offset: index,
            incomplete: true,
          })
        }
        continue
      }
    }
    if import_parse_is_identifier_start(code) {
      let start = index
      index += 1
      while index < source.length() &&
            import_parse_is_identifier_char(source.code_unit_at(index).to_int()) {
        index += 1
      }
      let name = source[start:index].to_owned()
      let token = if name == "as" { AS } else { IDENT(name) }
      tokens.push((token, start, index))
      continue
    }
    match code {
      44 => {
        tokens.push((COMMA, index, index + 1))
        index += 1
      }
      58 if index + 1 < source.length() &&
        source.code_unit_at(index + 1).to_int() == 58 => {
        tokens.push((DOUBLE_COLON, index, index + 2))
        index += 2
      }
      123 => {
        tokens.push((LEFT_BRACE, index, index + 1))
        index += 1
      }
      125 => {
        tokens.push((RIGHT_BRACE, index, index + 1))
        index += 1
      }
      _ =>
        return LexFailed(ImportParseDiagnostic::{
          offset: index,
          incomplete: false,
        })
    }
  }
  Lexed(tokens)
}

///|
pub fn parse_import_tree_source(source : String) -> ImportParseResult {
  let tokens = match import_parse_lex(source) {
    Lexed(tokens) => tokens
    LexFailed(diagnostic) => return Failed(diagnostic)
  }
  if tokens.is_empty() {
    return Failed(ImportParseDiagnostic::{ offset: 0, incomplete: true })
  }
  let nodes = parse_import_tree(tokens) catch {
    UnexpectedToken(_, (start, _), _) =>
      return Failed(ImportParseDiagnostic::{ offset: start, incomplete: false })
    UnexpectedEndOfInput(start, _) =>
      return Failed(ImportParseDiagnostic::{ offset: start, incomplete: true })
  }
  Parsed(nodes)
}
