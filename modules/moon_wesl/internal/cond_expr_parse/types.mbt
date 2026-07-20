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
pub(all) enum CondExprNode {
  Literal(Bool)
  Feature(String)
  Not(CondExprNode)
  And(CondExprNode, CondExprNode)
  Or(CondExprNode, CondExprNode)
} derive(Eq, Debug)

///|
pub(all) struct CondExprDiagnostic {
  offset : Int
  incomplete : Bool
} derive(Eq, Debug)

///|
pub(all) enum CondExprParseResult {
  Parsed(CondExprNode)
  Failed(CondExprDiagnostic)
} derive(Eq, Debug)

///|
priv enum CondExprLexResult {
  Lexed(Array[(Token, Int, Int)])
  LexFailed(CondExprDiagnostic)
}

///|
fn cond_expr_is_identifier_char(code : Int) -> Bool {
  (code >= 48 && code <= 57) ||
  (code >= 65 && code <= 90) ||
  (code >= 97 && code <= 122) ||
  code == 95
}

///|
fn cond_expr_keyword_token(name : String) -> Token {
  match name {
    "true" => TRUE
    "false" => FALSE
    _ => IDENT(name)
  }
}

///|
fn cond_expr_push_token(
  tokens : Array[(Token, Int, Int)],
  token : Token,
  start : Int,
  width : Int,
) -> Unit {
  tokens.push((token, start, start + width))
}

///|
fn cond_expr_lex(source : String) -> CondExprLexResult {
  let tokens : Array[(Token, Int, Int)] = []
  let mut index = 0
  while index < source.length() {
    let code = source.code_unit_at(index).to_int()
    if code == 32 || code == 9 || code == 10 || code == 13 {
      index += 1
      continue
    }
    if cond_expr_is_identifier_char(code) {
      let start = index
      index += 1
      while index < source.length() &&
            cond_expr_is_identifier_char(source.code_unit_at(index).to_int()) {
        index += 1
      }
      let name = source[start:index].to_owned()
      tokens.push((cond_expr_keyword_token(name), start, index))
      continue
    }
    match code {
      33 => {
        cond_expr_push_token(tokens, BANG, index, 1)
        index += 1
      }
      38 if index + 1 < source.length() &&
        source.code_unit_at(index + 1).to_int() == 38 => {
        cond_expr_push_token(tokens, AMP_AMP, index, 2)
        index += 2
      }
      124 if index + 1 < source.length() &&
        source.code_unit_at(index + 1).to_int() == 124 => {
        cond_expr_push_token(tokens, PIPE_PIPE, index, 2)
        index += 2
      }
      40 => {
        cond_expr_push_token(tokens, LEFT_PAREN, index, 1)
        index += 1
      }
      41 => {
        cond_expr_push_token(tokens, RIGHT_PAREN, index, 1)
        index += 1
      }
      _ =>
        return LexFailed(CondExprDiagnostic::{
          offset: index,
          incomplete: false,
        })
    }
  }
  Lexed(tokens)
}

///|
pub fn parse_cond_expr_source(source : String) -> CondExprParseResult {
  let tokens = match cond_expr_lex(source) {
    Lexed(tokens) => tokens
    LexFailed(diagnostic) => return Failed(diagnostic)
  }
  if tokens.is_empty() {
    return Failed(CondExprDiagnostic::{ offset: 0, incomplete: true })
  }
  let expr = parse_cond_expr(tokens) catch {
    UnexpectedToken(_, (start, _), _) =>
      return Failed(CondExprDiagnostic::{ offset: start, incomplete: false })
    UnexpectedEndOfInput(start, _) =>
      return Failed(CondExprDiagnostic::{ offset: start, incomplete: true })
  }
  Parsed(expr)
}
