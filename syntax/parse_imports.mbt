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
fn stack_join(stack : Array[String]) -> String {
  let mut out = ""
  for item in stack {
    out = out + item
  }
  out
}

///|
fn join_wgsl_import_prefix(prefix : String, path : String) -> String {
  let lhs = prefix.trim().to_owned()
  let rhs = path.trim().to_owned()
  if lhs == "" {
    rhs
  } else if rhs == "" {
    lhs
  } else {
    "\{lhs}::\{rhs}"
  }
}

///|
priv struct WgslImportParser {
  input : String
  mut token_view : ArrayView[Token]
}

///|
fn WgslImportParser::new(input : String) -> WgslImportParser {
  let tokens = tokenize(input, false)
  WgslImportParser::{ input, token_view: tokens[:] }
}

///|
fn WgslImportParser::view(self : WgslImportParser) -> ArrayView[Token] {
  self.token_view
}

///|
fn WgslImportParser::update_view(
  self : WgslImportParser,
  view : ArrayView[Token],
) -> Unit {
  self.token_view = view
}

///|
fn[A] WgslImportParser::error(
  self : WgslImportParser,
  message : String,
  pos? : Int,
) -> A raise ParseImportsError {
  match pos {
    Some(offset) => raise Parse(message, offset)
    None =>
      match self.view() {
        [token, ..] => raise Parse(message, token.pos())
        [] => raise Parse(message, self.input.length())
      }
  }
}

///|
fn WgslImportParser::expect_import_directive(
  self : WgslImportParser,
) -> Unit raise ParseImportsError {
  match self.view() {
    [Token::Other(35, _), Token::Identifier("import", _), .. rest] =>
      self.update_view(rest)
    [Token::Other(35, _), token, ..] =>
      self.error("expected `#import`", pos=token.pos())
    [token, ..] => self.error("expected `#import`", pos=token.pos())
    [] => self.error("expected #import", pos=self.input.length())
  }
}

///|
fn WgslImportParser::try_consume_alias(
  self : WgslImportParser,
) -> String? raise ParseImportsError {
  match self.view() {
    [Token::Identifier("as", _), Token::Identifier(name, _), .. rest] => {
      self.update_view(rest)
      Some(name)
    }
    [Token::Identifier("as", pos), ..] =>
      self.error("expected identifier after `as`", pos~)
    _ => None
  }
}

///|
fn push_wgsl_import_target(
  targets : Array[WgslImportTarget],
  prefix : String,
  stack : Array[String],
  current : String,
  as_name : String?,
) -> Unit {
  if current == "" {
    return
  }
  let alias_name = match as_name {
    Some(alias_text) => alias_text
    None => ""
  }
  targets.push(WgslImportTarget::{
    raw_path: join_wgsl_import_prefix(prefix, stack_join(stack) + current),
    alias_name,
  })
}

///|
fn WgslImportParser::parse_targets(
  self : WgslImportParser,
  require_directive : Bool,
  prefix : String,
  targets : Array[WgslImportTarget],
) -> Unit raise ParseImportsError {
  if require_directive {
    self.expect_import_directive()
  } else if self.view() is [] {
    self.error("expected import path", pos=self.input.length())
  }

  let stack : Array[String] = []
  let mut current = ""
  let mut as_name : String? = None
  let mut is_deprecated_itemlist = false

  while true {
    match self.view() {
      [Token::Identifier(ident, _), .. rest] => {
        self.update_view(rest)
        current = current + ident
        as_name = self.try_consume_alias()

        if self.view() is [Token::Identifier(_, _), ..] {
          is_deprecated_itemlist = true
          stack.push("\{current}::")
          current = ""
          as_name = None
        }
        continue
      }
      [Token::Other(code, pos), .. rest] if code == 123 => { // '{'
        if !current.has_suffix("::") {
          self.error("open brace must follow `::`", pos~)
        }
        stack.push(current)
        current = ""
        as_name = None
        self.update_view(rest)
        continue
      }
      [Token::Other(code, pos), .. rest] if code == 44 || code == 125 => { // ',' or '}'
        push_wgsl_import_target(targets, prefix, stack, current, as_name)
        current = ""
        as_name = None
        if code == 125 {
          guard stack.pop() is Some(_) else {
            self.error("close brace without open", pos~)
          }
        }
        self.update_view(rest)
        continue
      }
      [Token::Other(code, _), .. rest] if code == 59 => { // ';'
        self.update_view(rest)
        if self.view() is [token, ..] {
          self.error("unexpected token after ';'", pos=token.pos())
        }
        break
      }
      [Token::Other(_, pos), ..] => self.error("unexpected token", pos~)
      [Token::Whitespace(_, _), ..] =>
        abort("whitespace tokens should not be emitted here")
      [] => {
        push_wgsl_import_target(targets, prefix, stack, current, as_name)
        break
      }
    }
  }

  if !(stack.is_empty() || (is_deprecated_itemlist && stack.length() == 1)) {
    self.error("missing close brace", pos=self.input.length())
  }
  ()
}

///|
fn parse_wgsl_import_targets_from_tokens(
  input : String,
  require_directive : Bool,
  prefix : String,
  targets : Array[WgslImportTarget],
) -> Unit raise ParseImportsError {
  WgslImportParser::new(input).parse_targets(require_directive, prefix, targets)
}

///|
pub fn parse_wgsl_import_targets(
  input : String,
  prefix : String,
  targets : Array[WgslImportTarget],
) -> Unit raise ParseImportsError {
  parse_wgsl_import_targets_from_tokens(input, false, prefix, targets)
}
