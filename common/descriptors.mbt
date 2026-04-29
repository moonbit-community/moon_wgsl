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
pub(all) struct ComposableModuleDescriptor {
  source : String
  file_path : String
  language : ShaderLanguage
  as_name : String?
  additional_imports : Array[ImportDefinition]
  shader_defs : @hashmap.HashMap[String, ShaderDefValue]
} derive(Eq, Debug)

///|
pub fn ComposableModuleDescriptor::default() -> ComposableModuleDescriptor {
  {
    source: "",
    file_path: "",
    language: ShaderLanguage::Wgsl,
    as_name: None,
    additional_imports: [],
    shader_defs: @hashmap.HashMap::new(),
  }
}

///|
pub(all) struct NagaModuleDescriptor {
  source : String
  file_path : String
  shader_type : ShaderType
  shader_defs : @hashmap.HashMap[String, ShaderDefValue]
  additional_imports : Array[ImportDefinition]
} derive(Eq, Debug)

///|
pub fn NagaModuleDescriptor::default() -> NagaModuleDescriptor {
  {
    source: "",
    file_path: "",
    shader_type: ShaderType::Wgsl,
    shader_defs: @hashmap.HashMap::new(),
    additional_imports: [],
  }
}

///|
pub(all) struct ComposableModuleDefinition {
  name : String
  sanitized_source : String
  language : ShaderLanguage
  file_path : String
  shader_defs : @hashmap.HashMap[String, ShaderDefValue]
  effective_defs : Array[String]
  all_imports : @hashset.HashSet[String]
  additional_imports : Array[ImportDefinition]
}
