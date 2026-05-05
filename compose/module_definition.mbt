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
pub struct ComposableModuleDefinition {
  priv name : String
  priv shader_defs : @hashmap.HashMap[String, ShaderDefValue]
  priv effective_defs : Array[String]
  priv all_imports : @hashset.HashSet[String]
}

///|
fn ComposableModuleDefinition::new(
  name : String,
  shader_defs : @hashmap.HashMap[String, ShaderDefValue],
  effective_defs : Array[String],
  all_imports : @hashset.HashSet[String],
) -> ComposableModuleDefinition {
  ComposableModuleDefinition::{ name, shader_defs, effective_defs, all_imports }
}

///|
pub fn ComposableModuleDefinition::name(
  self : ComposableModuleDefinition,
) -> String {
  self.name
}

///|
pub fn ComposableModuleDefinition::shader_def(
  self : ComposableModuleDefinition,
  name : String,
) -> ShaderDefValue? {
  self.shader_defs.get(name)
}

///|
pub fn ComposableModuleDefinition::contains_effective_def(
  self : ComposableModuleDefinition,
  name : String,
) -> Bool {
  self.effective_defs.contains(name)
}

///|
pub fn ComposableModuleDefinition::all_imports_is_empty(
  self : ComposableModuleDefinition,
) -> Bool {
  self.all_imports.is_empty()
}

///|
pub fn ComposableModuleDefinition::imports_module(
  self : ComposableModuleDefinition,
  module_name : String,
) -> Bool {
  self.all_imports.contains(module_name)
}
