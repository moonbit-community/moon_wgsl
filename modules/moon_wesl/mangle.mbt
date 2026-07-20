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
pub struct EscapeMangler {}

///|
pub(all) enum ManglerKind {
  Escape
  Hash
  Unicode
  None
} derive(Eq, Debug)

///|
pub fn ManglerKind::default() -> ManglerKind {
  Escape
}

///|
pub fn EscapeMangler::default() -> EscapeMangler {
  EscapeMangler::{  }
}

///|
fn escape_mangler_count_char(text : String, ch : Int) -> Int {
  let mut count = 0
  for i in 0..<text.length() {
    if text.code_unit_at(i).to_int() == ch {
      count = count + 1
    }
  }
  count
}

///|
fn escape_mangler_component(comp : String) -> String {
  if comp.contains("/") {
    let count = escape_mangler_count_char(comp, 47) + 1
    let pieces : Array[String] = []
    for piece in comp.split("/") {
      pieces.push(escape_mangler_component(piece.to_owned()))
    }
    let suffix = pieces.join("_")
    return "import_\{count}_\{suffix}"
  }
  let underscores = escape_mangler_count_char(comp, 95)
  if underscores > 0 {
    "_\{underscores}\{comp}"
  } else {
    comp
  }
}

///|
fn escape_mangler_parse_count(text : String) -> (Int, String)? {
  let mut digits = 0
  while digits < text.length() {
    let code = text.code_unit_at(digits).to_int()
    if code < 48 || code > 57 {
      break
    }
    digits = digits + 1
  }
  if digits == 0 {
    return None
  }
  let count = @string.parse_int(text[:digits]) catch { _ => return None }
  Some((count, text[digits:].to_owned()))
}

///|
fn escape_mangler_unescape_component(
  parts : Array[String],
  cursor : Int,
) -> (String, Int)? {
  guard cursor < parts.length() else { return None }
  let part = parts[cursor]
  if part != "" {
    return Some((part, cursor + 1))
  }
  guard cursor + 1 < parts.length() else { return None }
  let first = parts[cursor + 1]
  guard escape_mangler_parse_count(first) is Some((count, rem)) else {
    return None
  }
  let end_index = cursor + 2 + count
  guard end_index <= parts.length() else { return None }
  let component_parts : Array[String] = [rem]
  for index in (cursor + 2)..<end_index {
    component_parts.push(parts[index])
  }
  Some((component_parts.join("_"), end_index))
}

///|
fn escape_mangler_split(mangled : String) -> Array[String] {
  let parts : Array[String] = []
  for part in mangled.split("_") {
    parts.push(part.to_owned())
  }
  parts
}

///|
pub fn EscapeMangler::unmangle(
  _self : EscapeMangler,
  mangled : String,
) -> (ModulePath, String)? {
  let parts = escape_mangler_split(mangled)
  guard parts.length() > 0 else { return None }
  let mut cursor = 1
  let origin = match parts[0] {
    "package" => PathOrigin::Absolute
    "self" => PathOrigin::Relative(0)
    "super" => {
      let mut levels = 1
      while cursor < parts.length() && parts[cursor] == "super" {
        levels = levels + 1
        cursor = cursor + 1
      }
      PathOrigin::Relative(levels)
    }
    "import" => {
      guard cursor < parts.length() else { return None }
      let count = @string.parse_int(parts[cursor][:]) catch { _ => return None }
      cursor = cursor + 1
      let package_parts : Array[String] = []
      for _ in 0..<count {
        guard escape_mangler_unescape_component(parts, cursor)
          is Some((component, next_cursor)) else {
          return None
        }
        package_parts.push(component)
        cursor = next_cursor
      }
      PathOrigin::Package(package_parts.join("/"))
    }
    _ => {
      guard escape_mangler_unescape_component(parts, 0)
        is Some((package_name, next_cursor)) else {
        return None
      }
      cursor = next_cursor
      PathOrigin::Package(package_name)
    }
  }
  let components : Array[String] = []
  while cursor < parts.length() {
    guard escape_mangler_unescape_component(parts, cursor)
      is Some((component, next_cursor)) else {
      return None
    }
    components.push(component)
    cursor = next_cursor
  }
  guard components.length() > 0 else { return None }
  let item = components[components.length() - 1]
  let path_components : Array[String] = []
  for index in 0..<(components.length() - 1) {
    path_components.push(components[index])
  }
  Some((ModulePath::new(origin, path_components), item))
}

///|
pub fn EscapeMangler::mangle(
  _self : EscapeMangler,
  path : ModulePath,
  item : String,
) -> String {
  let origin = match path.origin {
    Absolute => "package"
    Relative(0) => "self"
    Relative(levels) => {
      let pieces : Array[String] = []
      for _ in 0..<levels {
        pieces.push("super")
      }
      pieces.join("_")
    }
    Package(name) => escape_mangler_component(name)
  }
  let escaped_item = escape_mangler_component(item)
  if path.components.length() == 0 {
    "\{origin}_\{escaped_item}"
  } else {
    let escaped_components : Array[String] = []
    for component in path.components {
      escaped_components.push(escape_mangler_component(component))
    }
    let escaped_path = escaped_components.join("_")
    "\{origin}_\{escaped_path}_\{escaped_item}"
  }
}

///|
fn hash_mangler_hash(path : ModulePath, item : String) -> UInt {
  let mut hash = 2166136261U
  let text = path.to_string() + "::" + item
  for index in 0..<text.length() {
    hash = hash ^ text.code_unit_at(index).to_uint()
    hash = hash * 16777619U
  }
  hash
}

///|
fn unicode_mangler_component(text : String) -> String {
  text
  .replace(old="_", new="＿")
  .replace(old="/", new="ᐟ")
  .replace(old=":", new="꞉")
  .replace(old="<", new="ᐸ")
  .replace(old=">", new="ᐳ")
  .replace(old=",", new="ˏ")
  .replace(old=" ", new="")
}

///|
fn unicode_mangler_uncomponent(text : String) -> String {
  text
  .replace(old="＿", new="_")
  .replace(old="ᐟ", new="/")
  .replace(old="꞉", new=":")
  .replace(old="ᐸ", new="<")
  .replace(old="ᐳ", new=">")
  .replace(old="ˏ", new=",")
}

///|
fn unicode_mangler_last_separator(text : String) -> Int {
  let mut last = -1
  for index in 0..<text.length() {
    if text.code_unit_at(index).to_int() == 95 {
      last = index
    }
  }
  last
}

///|
pub fn ManglerKind::mangle(
  self : ManglerKind,
  path : ModulePath,
  item : String,
) -> String {
  match self {
    Escape => EscapeMangler::mangle(EscapeMangler::default(), path, item)
    Hash => "\{item}_\{hash_mangler_hash(path, item).to_string()}"
    Unicode =>
      if path.is_root() {
        unicode_mangler_component(item)
      } else {
        unicode_mangler_component(path.to_string()) +
        "_" +
        unicode_mangler_component(item)
      }
    None => item
  }
}

///|
pub fn ManglerKind::unmangle(
  self : ManglerKind,
  mangled : String,
) -> (ModulePath, String)? {
  match self {
    Escape => EscapeMangler::unmangle(EscapeMangler::default(), mangled)
    Unicode => {
      let sep = unicode_mangler_last_separator(mangled)
      if sep < 0 {
        return Some(
          (ModulePath::new_root(), unicode_mangler_uncomponent(mangled)),
        )
      }
      let path_text = unicode_mangler_uncomponent(mangled[:sep].to_owned())
      let item = unicode_mangler_uncomponent(
        mangled[sep + 1:mangled.length()].to_owned(),
      )
      let path = parse_module_path(path_text) catch { _ => return None }
      Some((path, item))
    }
    Hash | None => None
  }
}
