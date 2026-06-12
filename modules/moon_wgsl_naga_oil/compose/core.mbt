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
pub struct Composer {
  priv module_sets : Map[String, ComposableModuleDefinition]
  priv registry : WgslSourceRegistry
  priv composable_module_registry_paths : Map[String, String]
}

///|
pub fn Composer::default() -> Composer {
  {
    module_sets: Map([]),
    registry: WgslSourceRegistry::default(),
    composable_module_registry_paths: Map([]),
  }
}

///|
pub(all) suberror ComposerError {
  FailedToResolveImport(String)
  ImportCycle(String)
  InvalidStructMemberIdentifier(String)
  InvalidWgslSyntax(String, Int)
  InvalidOverride(String)
  MissingRegisteredSource(String)
  MissingPreparedSourceDefs(String)
  MissingStartupRegisteredSource(String)
  NoModuleName(String)
  DefineInModule
  GlslInvalidVersion
  InvalidWgslDirective(String, String)
  InvalidIr(String)
  AmbiguousImportBinding(String)
  UnknownShaderDef(String)
  UnknownShaderDefOperator(String)
  InvalidShaderDefComparisonValue(String, String, String)
  ElseWithoutCondition
  TooManyEndIfs
  NotEnoughEndIfs
}

///|
pub fn ComposerError::message(self : ComposerError) -> String {
  match self {
    FailedToResolveImport(import_path) =>
      match wgsl_required_import_name_from_error(import_path) {
        Some(name) => "error: required import '\{name}' not found"
        None => "failed to resolve shader import: \{import_path}"
      }
    ImportCycle(cycle) => "shader import cycle detected: \{cycle}"
    InvalidStructMemberIdentifier(name) =>
      "composable module identifier requires AST identifier normalization: \{name}"
    InvalidWgslSyntax(message, offset) =>
      "invalid WGSL syntax at \{offset}: \{message}"
    InvalidOverride(name) =>
      "error: override is invalid as `\{name}` is not virtual (this error can be disabled with feature 'override_any')"
    MissingRegisteredSource(rel) => "missing registered WGSL source: \{rel}"
    MissingPreparedSourceDefs(rel) =>
      "missing prepared shader defs for WGSL source: \{rel}"
    MissingStartupRegisteredSource(rel) =>
      "shader source was not startup-registered: \{rel}"
    NoModuleName(path) =>
      "shader module is missing #define_import_path: \{path}"
    DefineInModule => "shader module cannot contain #define directives"
    GlslInvalidVersion => "invalid GLSL #version directive"
    InvalidWgslDirective(line, reason) =>
      "invalid WGSL directive: \{line}: \{reason}"
    InvalidIr(message) => "invalid WGSL IR pipeline: \{message}"
    AmbiguousImportBinding(message) =>
      "ambiguous shader import binding: \{message}"
    UnknownShaderDef(name) => "unknown shader def: \{name}"
    UnknownShaderDefOperator(operator) =>
      "unknown shader def operator: \{operator}"
    InvalidShaderDefComparisonValue(name, value, expected) =>
      "invalid shader def comparison value for \{name}: \{value}; expected \{expected}"
    ElseWithoutCondition => "#else without condition"
    TooManyEndIfs => "too many #endif directives"
    NotEnoughEndIfs => "not enough #endif directives"
  }
}

///|
fn wgsl_required_import_name_from_error(import_path : String) -> String? {
  let (path, from_reference) = match
    import_path.split(" in function ").collect() {
    [head, ..] => (head.to_owned().trim().to_owned(), true)
    _ => (import_path.trim().to_owned(), false)
  }
  if path == "" {
    return None
  }
  let name = if from_reference {
    match path.split("::").collect() {
      [head, ..] => head.to_owned()
      _ => path
    }
  } else {
    path
  }
  if name == "" {
    return None
  }
  for index in 0..<name.length() {
    let code = name[index]
    let valid = (code >= 97 && code <= 122) ||
      (code >= 65 && code <= 90) ||
      (code >= 48 && code <= 57) ||
      code == 95
    if !valid {
      return None
    }
  }
  Some(name)
}
