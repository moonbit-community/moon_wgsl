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
priv struct DeclaredImportBinding {
  used_name : String
  full_paths : Array[String]
}

///|
pub(all) suberror ParseImportsError {
  Parse(String, Int)
}

///|
pub(all) suberror SubstituteIdentifiersError {
  AmbiguousImport(Int)
}

///|
fn declared_imports_find_index(
  declared_imports : Array[DeclaredImportBinding],
  used_name : String,
) -> Int? {
  for i in 0..<declared_imports.length() {
    if declared_imports[i].used_name == used_name {
      return Some(i)
    }
  }
  None
}

///|
fn declared_imports_add(
  declared_imports : Array[DeclaredImportBinding],
  used_name : String,
  full_path : String,
) -> Unit {
  if declared_imports_find_index(declared_imports, used_name) is Some(index) {
    declared_imports[index].full_paths.push(full_path)
  } else {
    declared_imports.push(DeclaredImportBinding::{
      used_name,
      full_paths: [full_path],
    })
  }
}

///|
fn declared_imports_get_paths(
  declared_imports : Array[DeclaredImportBinding],
  used_name : String,
) -> Array[String]? {
  if declared_imports_find_index(declared_imports, used_name) is Some(index) {
    return Some(declared_imports[index].full_paths)
  }
  None
}

///|
fn split_once_identifier(text : String) -> (String, String)? {
  if text.find("::") is Some(index) {
    return Some(
      (text[:index].to_string(), text[index + 2:text.length()].to_string()),
    )
  }
  None
}

///|
fn split_last_identifier(text : String) -> (String, String)? {
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
  Some((text[:found].to_string(), text[found + 2:text.length()].to_string()))
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
fn parse_imports(
  input : String,
  declared_imports : Array[DeclaredImportBinding],
) -> Unit raise ParseImportsError {
  let tokens = tokenize(input, false)
  let mut index = 0

  guard index < tokens.length() else {
    raise Parse("expected #import", input.length())
  }
  guard tokens[index] == Token::Other(35, tokens[index].pos()) else {
    raise Parse("expected `#import`", tokens[index].pos())
  }
  index = index + 1

  guard index < tokens.length() else {
    raise Parse("expected `#import`", input.length())
  }
  guard tokens[index].identifier() == Some("import") else {
    raise Parse("expected `#import`", tokens[index].pos())
  }
  index = index + 1

  let stack : Array[String] = []
  let mut current = ""
  let mut as_name : String? = None
  let mut is_deprecated_itemlist = false

  while true {
    let peek = if index < tokens.length() { Some(tokens[index]) } else { None }
    match peek {
      Some(Token::Identifier(ident, _)) => {
        current = current + ident
        index = index + 1

        if index < tokens.length() && tokens[index].identifier() == Some("as") {
          let pos = tokens[index].pos()
          index = index + 1
          guard index < tokens.length() else {
            raise Parse("expected identifier after `as`", pos)
          }
          guard tokens[index] is Token::Identifier(name, _) else {
            raise Parse("expected identifier after `as`", pos)
          }
          as_name = Some(name)
          index = index + 1
        }

        if index < tokens.length() && tokens[index] is Token::Identifier(_, _) {
          is_deprecated_itemlist = true
          stack.push("\{current}::")
          current = ""
          as_name = None
        }
        continue
      }
      Some(Token::Other(code, pos)) if code == 123 => { // '{'
        if !current.has_suffix("::") {
          raise Parse("open brace must follow `::`", pos)
        }
        stack.push(current)
        current = ""
        as_name = None
        index = index + 1
        continue
      }
      Some(Token::Other(code, pos)) if code == 44 || code == 125 => { // ',' or '}'
        if current != "" {
          let used_name = match as_name {
            Some(alias_name) => alias_name
            None =>
              match split_last_identifier(current) {
                Some((_, tail)) => tail
                None => current
              }
          }
          declared_imports_add(
            declared_imports,
            used_name,
            stack_join(stack) + current,
          )
          current = ""
          as_name = None
        }
        if code == 125 {
          guard stack.pop() is Some(_) else {
            raise Parse("close brace without open", pos)
          }
        }
        index = index + 1
        continue
      }
      Some(Token::Other(code, _)) if code == 59 => { // ';'
        index = index + 1
        if index < tokens.length() {
          raise Parse("unexpected token after ';'", tokens[index].pos())
        }
        break
      }
      Some(Token::Other(_, pos)) => raise Parse("unexpected token", pos)
      Some(Token::Whitespace(_, _)) =>
        abort("whitespace tokens should not be emitted here")
      None => {
        if current != "" {
          let used_name = match as_name {
            Some(alias_name) => alias_name
            None =>
              match split_last_identifier(current) {
                Some((_, tail)) => tail
                None => current
              }
          }
          declared_imports_add(
            declared_imports,
            used_name,
            stack_join(stack) + current,
          )
        }
        break
      }
    }
  }

  if !(stack.is_empty() || (is_deprecated_itemlist && stack.length() == 1)) {
    raise Parse("missing close brace", input.length())
  }
  ()
}

///|
fn base32_nopad(input : String) -> String {
  let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
  let bytes = @utf8.encode(input[:])
  let mut value = 0U
  let mut bits = 0
  let mut out = ""
  for byte in bytes {
    value = (value << 8) | byte.to_uint()
    bits = bits + 8
    while bits >= 5 {
      let index = ((value >> (bits - 5)) & 31U).reinterpret_as_int()
      out = out + alphabet[index:index + 1].to_string()
      bits = bits - 5
    }
  }
  if bits > 0 {
    let index = ((value << (5 - bits)) & 31U).reinterpret_as_int()
    out = out + alphabet[index:index + 1].to_string()
  }
  out
}

///|
fn decorate(module_name : String) -> String {
  "X_naga_oil_mod_X\{base32_nopad(module_name)}X"
}

///|
fn used_imports_find_index(
  used_imports : Array[ImportDefWithOffset],
  module_path : String,
) -> Int? {
  for i in 0..<used_imports.length() {
    if used_imports[i].definition.import_path == module_path {
      return Some(i)
    }
  }
  None
}

///|
fn used_imports_record(
  used_imports : Array[ImportDefWithOffset],
  module_path : String,
  item_name : String,
  offset : Int,
) -> Unit {
  if used_imports_find_index(used_imports, module_path) is Some(index) {
    used_imports[index].definition.items.push(item_name)
  } else {
    used_imports.push(ImportDefWithOffset::{
      definition: ImportDefinition::{
        import_path: module_path,
        items: [item_name],
      },
      offset,
    })
  }
}

///|
fn code_unit_to_string(code : Int) -> String {
  String::from_array([Int::unsafe_to_char(code)])
}

///|
fn substitute_identifiers(
  input : String,
  offset : Int,
  declared_imports : Array[DeclaredImportBinding],
  used_imports : Array[ImportDefWithOffset],
  allow_ambiguous : Bool,
) -> String raise SubstituteIdentifiersError {
  let tokens = tokenize(input, true)
  let mut output = ""
  let mut in_substitution_position = true

  for token in tokens {
    match token {
      Token::Identifier(ident, token_pos) =>
        if in_substitution_position {
          let (first, residual) = match split_once_identifier(ident) {
            Some(parts) => parts
            None => (ident, "")
          }
          let full_paths = match
            declared_imports_get_paths(declared_imports, first) {
            Some(paths) => paths
            None => [first]
          }
          if !allow_ambiguous && full_paths.length() > 1 {
            raise AmbiguousImport(offset + token_pos)
          }

          for full_path_base in full_paths {
            let full_path = if residual != "" {
              "\{full_path_base}::\{residual}"
            } else {
              full_path_base
            }

            if split_last_identifier(full_path)
              is Some((module_path, item_name)) {
              used_imports_record(
                used_imports,
                module_path,
                item_name,
                offset + token_pos,
              )
              output = output + item_name + decorate(module_path)
            } else if full_path.contains("\"") {
              output = output + ident
            } else {
              output = output + full_path
            }
          }
        } else {
          output = output + ident
        }
      Token::Other(other, _) => {
        output = output + code_unit_to_string(other)
        if other == 46 || other == 64 { // '.' or '@'
          in_substitution_position = false
          continue
        }
      }
      Token::Whitespace(ws, _) => output = output + ws
    }

    in_substitution_position = true
  }

  output
}
