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
  token.end()
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
  let mut previous_identifier : String? = None
  let mut after_final_semicolon = false
  let mut index = 0
  while index < raw_tokens.length() {
    let token = raw_tokens[index]
    let start = utf8_byte_length(input[:token.pos()].to_owned())
    let end_ = start +
      utf8_byte_length(
        input[token.pos():wgsl_generated_import_token_end(token)].to_owned(),
      )
    if after_final_semicolon {
      raise ParseImportsError::Parse("unexpected token after ';'", start)
    }
    match token.identifier_text() {
      Some("as") =>
        if previous_can_start_alias {
          guard index + 1 < raw_tokens.length() &&
            raw_tokens[index + 1].identifier_text() is Some(_) else {
            raise ParseImportsError::Parse(
              "expected identifier after `as`", start,
            )
          }
          push_generated_import_token(out, Token::AS, start, end_)
          previous_can_start_alias = false
          previous_identifier = None
        } else {
          push_generated_import_token(out, Token::IDENT("as"), start, end_)
          previous_can_start_alias = true
          previous_identifier = Some("as")
        }
      Some(name) => {
        push_generated_import_token(out, Token::IDENT(name), start, end_)
        previous_can_start_alias = true
        previous_identifier = Some(name)
      }
      None if token.is_punctuation(123) => {
        guard previous_identifier is Some(name) && name.has_suffix("::") else {
          raise ParseImportsError::Parse("open brace must follow `::`", start)
        }
        push_generated_import_token(out, Token::LBRACE(start), start, end_)
        previous_can_start_alias = false
        previous_identifier = None
      }
      None if token.is_punctuation(125) => {
        push_generated_import_token(out, Token::RBRACE(start), start, end_)
        previous_can_start_alias = false
        previous_identifier = None
      }
      None if token.is_punctuation(44) => {
        push_generated_import_token(out, Token::COMMA, start, end_)
        previous_can_start_alias = false
        previous_identifier = None
      }
      None if token.is_punctuation(59) => {
        push_generated_import_token(out, Token::SEMI, start, end_)
        previous_can_start_alias = false
        previous_identifier = None
        after_final_semicolon = true
      }
      None if token.is_whitespace() =>
        abort("whitespace tokens should not be emitted here")
      _ =>
        raise ParseImportsError::Parse(
          "unexpected token",
          utf8_byte_length(input[:token.pos()].to_owned()),
        )
    }
    index = index + 1
  }
  let eof = utf8_byte_length(input)
  push_generated_import_token(out, Token::EOF, eof, eof)
  out
}

///|
pub fn parse_wgsl_import_spec_is_empty_or_final_semicolon(
  spec : String,
) -> Bool {
  let tokens = tokenize(spec, false)
  if tokens.length() == 0 {
    return true
  }
  tokens.length() == 1 && tokens[0].is_punctuation(59)
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
