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
pub(all) enum PathOrigin {
  Absolute
  Relative(Int)
  Package(String)
} derive(Eq, Hash, Debug)

///|
pub(all) struct ModulePath {
  origin : PathOrigin
  components : Array[String]
} derive(Eq, Hash, Debug)

///|
pub(all) suberror ModulePathParseError {
  Empty
  MisplacedPackage
  MisplacedSelf
  MisplacedSuper
}

///|
pub fn ModulePathParseError::message(self : ModulePathParseError) -> String {
  match self {
    Empty => "module name cannot be empty"
    MisplacedPackage => "`package` must be a prefix of the module path"
    MisplacedSelf => "`self` must be a prefix of the module path"
    MisplacedSuper => "`super` must be a prefix of the module path"
  }
}

///|
pub fn ModulePath::new(
  origin : PathOrigin,
  components : Array[String],
) -> ModulePath {
  ModulePath::{ origin, components }
}

///|
pub fn ModulePath::new_root() -> ModulePath {
  ModulePath::new(PathOrigin::Absolute, [])
}

///|
fn module_path_normalize_fs(path : String) -> String {
  path.replace_all(old="\\", new="/")
}

///|
fn module_path_drop_extension(path : String) -> String {
  let mut last_slash = -1
  let mut last_dot = -1
  for i in 0..<path.length() {
    let code = path.code_unit_at(i).to_int()
    if code == 47 { // '/'
      last_slash = i
      last_dot = -1
    } else if code == 46 { // '.'
      last_dot = i
    }
  }
  if last_dot > last_slash {
    path[:last_dot].to_owned()
  } else {
    path
  }
}

///|
fn module_path_split_non_empty(path : String, sep : String) -> Array[String] {
  let parts : Array[String] = []
  for part in path.split(sep) {
    let text = part.to_owned()
    if text != "" {
      parts.push(text)
    }
  }
  parts
}

///|
fn module_path_slice(
  parts : Array[String],
  start : Int,
  end : Int,
) -> Array[String] {
  let out : Array[String] = []
  for i in start..<end {
    out.push(parts[i])
  }
  out
}

///|
fn module_path_join_components(
  components : Array[String],
  sep : String,
) -> String {
  if components.length() == 0 {
    ""
  } else {
    components.join(sep)
  }
}

///|
pub fn ModulePath::from_path(path : String) -> ModulePath {
  let normalized = module_path_drop_extension(module_path_normalize_fs(path))
  if normalized == "" {
    abort("path is empty")
  }
  if normalized == "/" {
    return ModulePath::new_root()
  }
  let absolute = normalized.has_prefix("/")
  let parts = module_path_split_non_empty(normalized, "/")
  if absolute {
    return ModulePath::new(PathOrigin::Absolute, parts)
  }
  if parts.length() == 0 {
    abort("path must contain at least one named component")
  }
  match parts[0] {
    "." =>
      ModulePath::new(
        PathOrigin::Relative(0),
        module_path_slice(parts, 1, parts.length()),
      )
    ".." => {
      let mut levels = 1
      while levels < parts.length() && parts[levels] == ".." {
        levels = levels + 1
      }
      ModulePath::new(
        PathOrigin::Relative(levels),
        module_path_slice(parts, levels, parts.length()),
      )
    }
    package_name =>
      ModulePath::new(
        PathOrigin::Package(package_name),
        module_path_slice(parts, 1, parts.length()),
      )
  }
}

///|
pub fn ModulePath::push(self : ModulePath, item : String) -> Unit {
  self.components.push(item)
}

///|
pub fn ModulePath::first(self : ModulePath) -> String? {
  self.components.get(0)
}

///|
pub fn ModulePath::last(self : ModulePath) -> String? {
  if self.components.length() == 0 {
    None
  } else {
    Some(self.components[self.components.length() - 1])
  }
}

///|
pub fn ModulePath::join(
  self : ModulePath,
  suffix : Array[String],
) -> ModulePath {
  let components = self.components.copy()
  for item in suffix {
    components.push(item)
  }
  ModulePath::{ origin: self.origin, components }
}

///|
pub fn ModulePath::join_path(
  self : ModulePath,
  suffix : ModulePath,
) -> ModulePath {
  match suffix.origin {
    Absolute =>
      match self.origin {
        Absolute => suffix
        Relative(_) => suffix
        Package(_) =>
          ModulePath::{ origin: self.origin, components: suffix.components }
      }
    Relative(levels) => {
      let to_keep = if self.components.length() > levels {
        self.components.length() - levels
      } else {
        0
      }
      let components = module_path_slice(self.components, 0, to_keep)
      for item in suffix.components {
        components.push(item)
      }
      let origin = match self.origin {
        Absolute => Absolute
        Package(_) => self.origin
        Relative(self_levels) => {
          let extra_levels = if levels > self.components.length() {
            levels - self.components.length()
          } else {
            0
          }
          Relative(self_levels + extra_levels)
        }
      }
      ModulePath::{ origin, components }
    }
    Package(suffix_pkg) =>
      match self.origin {
        Absolute => suffix
        Relative(_) => suffix
        Package(self_pkg) =>
          ModulePath::{
            origin: Package("\{self_pkg}/\{suffix_pkg}"),
            components: suffix.components,
          }
      }
  }
}

///|
pub fn ModulePath::starts_with(self : ModulePath, prefix : ModulePath) -> Bool {
  if self.origin != prefix.origin ||
    self.components.length() < prefix.components.length() {
    return false
  }
  for i in 0..<prefix.components.length() {
    if self.components[i] != prefix.components[i] {
      return false
    }
  }
  true
}

///|
pub fn ModulePath::is_root(self : ModulePath) -> Bool {
  match self.origin {
    Absolute => self.components.length() == 0
    _ => false
  }
}

///|
pub fn ModulePath::is_package(self : ModulePath) -> Bool {
  self.origin is Package(_)
}

///|
pub fn ModulePath::is_relative(self : ModulePath) -> Bool {
  self.origin is Relative(_)
}

///|
pub fn ModulePath::to_path_string(self : ModulePath) -> String {
  let prefix = match self.origin {
    Absolute => "/"
    Relative(0) => "."
    Relative(levels) => {
      let pieces : Array[String] = []
      for _ in 0..<levels {
        pieces.push("..")
      }
      pieces.join("/")
    }
    Package(name) => name
  }
  if self.components.length() == 0 {
    prefix
  } else {
    let tail = module_path_join_components(self.components, "/")
    if prefix == "/" {
      "/\{tail}"
    } else {
      "\{prefix}/\{tail}"
    }
  }
}

///|
pub fn ModulePath::to_string(self : ModulePath) -> String {
  let prefix = match self.origin {
    Absolute => "package"
    Relative(0) => "self"
    Relative(levels) => {
      let pieces : Array[String] = []
      for _ in 0..<levels {
        pieces.push("super")
      }
      pieces.join("::")
    }
    Package(name) => name
  }
  if self.components.length() == 0 {
    prefix
  } else {
    let tail = module_path_join_components(self.components, "::")
    "\{prefix}::\{tail}"
  }
}

///|
pub fn parse_module_path(
  text : String,
) -> ModulePath raise ModulePathParseError {
  let parsed = @module_path_parse.parse_module_path_source(text)
  let path = match parsed {
    @module_path_parse.Parsed(path) => path
    @module_path_parse.Failed(diagnostic) =>
      match diagnostic.problem {
        @module_path_parse.Empty => raise Empty
        @module_path_parse.MisplacedPackage => raise MisplacedPackage
        @module_path_parse.MisplacedSelf => raise MisplacedSelf
        @module_path_parse.MisplacedSuper => raise MisplacedSuper
      }
  }
  let origin = match path.origin {
    @module_path_parse.Absolute => Absolute
    @module_path_parse.Relative(levels) => Relative(levels)
    @module_path_parse.Package(name) => Package(name)
  }
  ModulePath::new(origin, path.components)
}
