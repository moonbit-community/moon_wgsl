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
  priv module_sets : @hashmap.HashMap[String, ComposableModuleDefinition]
  priv registry : WgslSourceRegistry
  priv composable_module_registry_paths : @hashmap.HashMap[String, String]
}

///|
pub fn Composer::default() -> Composer {
  Composer::{
    module_sets: @hashmap.HashMap::new(),
    registry: WgslSourceRegistry::default(),
    composable_module_registry_paths: @hashmap.HashMap::new(),
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
      "failed to resolve shader import: \{import_path}"
    ImportCycle(cycle) => "shader import cycle detected: \{cycle}"
    InvalidStructMemberIdentifier(name) =>
      "composable module identifier requires AST identifier normalization: \{name}"
    InvalidWgslSyntax(message, offset) =>
      "invalid WGSL syntax at \{offset}: \{message}"
    InvalidOverride(name) =>
      "override is invalid because target is not virtual: \{name}"
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
