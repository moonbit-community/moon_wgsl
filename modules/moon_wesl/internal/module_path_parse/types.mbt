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
pub(all) enum ModulePathParseOrigin {
  Absolute
  Relative(Int)
  Package(String)
} derive(Eq, Debug)

///|
pub(all) struct ModulePathParseNode {
  origin : ModulePathParseOrigin
  components : Array[String]
} derive(Eq, Debug)

///|
pub(all) enum ModulePathParseProblem {
  Empty
  MisplacedPackage
  MisplacedSelf
  MisplacedSuper
} derive(Eq, Debug)

///|
pub(all) struct ModulePathParseDiagnostic {
  offset : Int
  problem : ModulePathParseProblem
} derive(Eq, Debug)

///|
pub(all) enum ModulePathParseResult {
  Parsed(ModulePathParseNode)
  Failed(ModulePathParseDiagnostic)
} derive(Eq, Debug)

///|
priv enum ModulePathLexResult {
  Lexed(Array[(Token, Int, Int)])
  LexFailed(ModulePathParseDiagnostic)
}

///|
fn module_path_parse_problem_for_segment(
  segment : String,
) -> ModulePathParseProblem? {
  match segment {
    "package" => Some(ModulePathParseProblem::MisplacedPackage)
    "self" => Some(ModulePathParseProblem::MisplacedSelf)
    "super" => Some(ModulePathParseProblem::MisplacedSuper)
    _ => None
  }
}

///|
fn module_path_parse_token_for_segment(segment : String) -> Token {
  match segment {
    "package" => PACKAGE
    "self" => SELF
    "super" => SUPER
    _ => SEGMENT(segment)
  }
}

///|
fn module_path_parse_problem_for_token(token : Token) -> ModulePathParseProblem {
  match token {
    PACKAGE => ModulePathParseProblem::MisplacedPackage
    SELF => ModulePathParseProblem::MisplacedSelf
    SUPER => ModulePathParseProblem::MisplacedSuper
    _ => ModulePathParseProblem::Empty
  }
}

///|
fn module_path_parse_lex(source : String) -> ModulePathLexResult {
  let text = source.trim()
  if text.length() == 0 {
    return LexFailed(ModulePathParseDiagnostic::{
      offset: 0,
      problem: ModulePathParseProblem::Empty,
    })
  }
  let tokens : Array[(Token, Int, Int)] = []
  let mut index = 0
  let mut expect_segment = true
  while index < text.length() {
    if expect_segment {
      let start = index
      while index < text.length() {
        let code = text.code_unit_at(index).to_int()
        if code == 58 &&
          index + 1 < text.length() &&
          text.code_unit_at(index + 1).to_int() == 58 {
          break
        }
        index += 1
      }
      if start == index {
        return LexFailed(ModulePathParseDiagnostic::{
          offset: start,
          problem: ModulePathParseProblem::Empty,
        })
      }
      let segment = text[start:index].to_owned()
      tokens.push((module_path_parse_token_for_segment(segment), start, index))
      expect_segment = false
      continue
    }
    if index + 1 < text.length() &&
      text.code_unit_at(index).to_int() == 58 &&
      text.code_unit_at(index + 1).to_int() == 58 {
      tokens.push((DOUBLE_COLON, index, index + 2))
      index += 2
      expect_segment = true
      continue
    }
    return LexFailed(ModulePathParseDiagnostic::{
      offset: index,
      problem: ModulePathParseProblem::Empty,
    })
  }
  if expect_segment {
    return LexFailed(ModulePathParseDiagnostic::{
      offset: text.length(),
      problem: ModulePathParseProblem::Empty,
    })
  }
  Lexed(tokens)
}

///|
pub fn parse_module_path_source(source : String) -> ModulePathParseResult {
  let tokens = match module_path_parse_lex(source) {
    Lexed(tokens) => tokens
    LexFailed(diagnostic) => return Failed(diagnostic)
  }
  let path = parse_module_path(tokens) catch {
    UnexpectedToken(token, (start, _), _) =>
      return Failed(ModulePathParseDiagnostic::{
        offset: start,
        problem: module_path_parse_problem_for_token(token),
      })
    UnexpectedEndOfInput(start, _) =>
      return Failed(ModulePathParseDiagnostic::{
        offset: start,
        problem: ModulePathParseProblem::Empty,
      })
  }
  for component in path.components {
    match module_path_parse_problem_for_segment(component) {
      Some(problem) =>
        return Failed(ModulePathParseDiagnostic::{ offset: 0, problem })
      None => ()
    }
  }
  Parsed(path)
}
