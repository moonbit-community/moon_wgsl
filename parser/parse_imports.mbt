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
pub(all) suberror ParseImportsError {
  Parse(String, Int)
}

///|
fn wgsl_generated_import_token_end(token : WgslToken) -> Int {
  match token {
    Identifier(text, pos) | Whitespace(text, pos) => pos + text.length()
    Other(_, pos) => pos + 1
  }
}

///|
fn push_generated_import_token(
  tokens : Array[(Token, Int, Int)],
  generated : Token,
  start : Int,
  end_ : Int,
) -> Unit {
  tokens.push((generated, start, end_))
}

///|
fn tokenize_wgsl_import_targets(
  input : String,
) -> Array[(Token, Int, Int)] raise ParseImportsError {
  let out : Array[(Token, Int, Int)] = []
  let raw_tokens = tokenize(input, false)
  let mut previous_can_start_alias = false
  for token in raw_tokens {
    let start = utf8_byte_length(input[:token.pos()].to_owned())
    let end_ = start +
      utf8_byte_length(
        input[token.pos():wgsl_generated_import_token_end(token)].to_owned(),
      )
    match token {
      Identifier("as", _) =>
        if previous_can_start_alias {
          push_generated_import_token(out, Token::AS, start, end_)
          previous_can_start_alias = false
        } else {
          push_generated_import_token(out, Token::IDENT("as"), start, end_)
          previous_can_start_alias = true
        }
      Identifier(name, _) => {
        push_generated_import_token(out, Token::IDENT(name), start, end_)
        previous_can_start_alias = true
      }
      Other(123, _) => {
        push_generated_import_token(out, Token::LBRACE(start), start, end_)
        previous_can_start_alias = false
      }
      Other(125, _) => {
        push_generated_import_token(out, Token::RBRACE(start), start, end_)
        previous_can_start_alias = false
      }
      Other(44, _) => {
        push_generated_import_token(out, Token::COMMA, start, end_)
        previous_can_start_alias = false
      }
      Other(59, _) => {
        push_generated_import_token(out, Token::SEMI, start, end_)
        previous_can_start_alias = false
      }
      Other(_, pos) =>
        raise ParseImportsError::Parse(
          "unexpected token",
          utf8_byte_length(input[:pos].to_owned()),
        )
      Whitespace(_, _) => abort("whitespace tokens should not be emitted here")
    }
  }
  let eof = utf8_byte_length(input)
  push_generated_import_token(out, Token::EOF, eof, eof)
  out
}

///|
fn apply_wgsl_import_prefix(
  prefix : String,
  targets : Array[WgslImportTarget],
) -> Unit {
  let normalized_prefix = wgsl_trim_blankspace(prefix)
  if normalized_prefix == "" {
    return
  }
  for i in 0..<targets.length() {
    let path = wgsl_trim_blankspace(targets[i].raw_path)
    targets[i] = WgslImportTarget::{
      raw_path: if path == "" {
        normalized_prefix
      } else {
        "\{normalized_prefix}::\{path}"
      },
      alias_name: targets[i].alias_name,
    }
  }
}

///|
pub fn parse_wgsl_import_targets(
  input : String,
  prefix : String,
  targets : Array[WgslImportTarget],
) -> Unit raise ParseImportsError {
  if wgsl_regex_trim_whitespace(input) == "" {
    raise ParseImportsError::Parse(
      "expected import path",
      utf8_byte_length(input),
    )
  }
  let tokens = tokenize_wgsl_import_targets(input)
  for i in 0..<tokens.length() {
    let (token, _, _) = tokens[i]
    if token is Token::SEMI {
      let next_index = i + 1
      if next_index < tokens.length() {
        let (next_token, next_start, _) = tokens[next_index]
        if !(next_token is Token::EOF) {
          raise ParseImportsError::Parse(
            "unexpected token after ';'", next_start,
          )
        }
      }
    }
  }
  let parsed = import_targets(tokens) catch {
    ParseError::UnexpectedToken(_, (start, _), _) =>
      raise ParseImportsError::Parse("unexpected token", start)
    ParseError::UnexpectedEndOfInput(pos, _) =>
      raise ParseImportsError::Parse("unexpected end of input", pos)
  }
  apply_wgsl_import_prefix(prefix, parsed)
  for target in parsed {
    targets.push(target)
  }
}
