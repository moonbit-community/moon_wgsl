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
pub fn split_last_identifier(text : String) -> (String, String)? {
  let mut found = -1
  let mut i = 0
  while i + 1 < text.length() {
    if text.code_unit_at(i).to_int() == 58 &&
      text.code_unit_at(i + 1).to_int() == 58 {
      found = i
    }
    i = i + 1
  }
  if found < 0 {
    return None
  }
  Some((text[:found].to_owned(), text[found + 2:text.length()].to_owned()))
}

///|
fn wgsl_generated_import_token_end(token : Token) -> Int {
  match token {
    Identifier(text, pos) | Whitespace(text, pos) => pos + text.length()
    Other(_, pos) => pos + 1
  }
}

///|
fn push_generated_import_token(
  tokens : Array[(@generated.Token, Int, Int)],
  generated : @generated.Token,
  start : Int,
  end_ : Int,
) -> Unit {
  tokens.push((generated, start, end_))
}

///|
fn tokenize_wgsl_import_targets(
  input : String,
) -> Array[(@generated.Token, Int, Int)] raise ParseImportsError {
  let out : Array[(@generated.Token, Int, Int)] = []
  for token in tokenize(input, false) {
    let start = token.pos()
    let end_ = wgsl_generated_import_token_end(token)
    match token {
      Identifier("as", _) =>
        push_generated_import_token(out, @generated.Token::AS, start, end_)
      Identifier(name, _) =>
        push_generated_import_token(
          out,
          @generated.Token::IDENT(name),
          start,
          end_,
        )
      Other(123, _) =>
        push_generated_import_token(out, @generated.Token::LBRACE, start, end_)
      Other(125, _) =>
        push_generated_import_token(out, @generated.Token::RBRACE, start, end_)
      Other(44, _) =>
        push_generated_import_token(out, @generated.Token::COMMA, start, end_)
      Other(59, _) =>
        push_generated_import_token(out, @generated.Token::SEMI, start, end_)
      Other(_, pos) => raise ParseImportsError::Parse("unexpected token", pos)
      Whitespace(_, _) => abort("whitespace tokens should not be emitted here")
    }
  }
  push_generated_import_token(
    out,
    @generated.Token::EOF,
    input.length(),
    input.length(),
  )
  out
}

///|
fn apply_wgsl_import_prefix(
  prefix : String,
  targets : Array[WgslImportTarget],
) -> Unit {
  let normalized_prefix = prefix.trim().to_owned()
  if normalized_prefix == "" {
    return
  }
  for i in 0..<targets.length() {
    let path = targets[i].raw_path.trim().to_owned()
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
  if input.trim() == "" {
    raise ParseImportsError::Parse("expected import path", input.length())
  }
  let parsed = @generated.import_targets(tokenize_wgsl_import_targets(input)) catch {
    @generated.ParseError::UnexpectedToken(_, (start, _), _) =>
      raise ParseImportsError::Parse("unexpected token", start)
    @generated.ParseError::UnexpectedEndOfInput(pos, _) =>
      raise ParseImportsError::Parse("unexpected end of input", pos)
    _ => raise ParseImportsError::Parse("unexpected parser failure", 0)
  }
  apply_wgsl_import_prefix(prefix, parsed)
  for target in parsed {
    targets.push(target)
  }
}
