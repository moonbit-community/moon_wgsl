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
pub(all) enum ShaderLanguage {
  Wgsl
  Glsl
} derive(Eq, Debug)

///|
pub(all) enum ShaderType {
  Wgsl
  GlslVertex
  GlslFragment
} derive(Eq, Debug)

///|
pub(all) enum ShaderDefValue {
  Bool(Bool)
  Int(Int)
  UInt(UInt)
} derive(Eq, Debug)

///|
pub fn ShaderDefValue::value_as_string(self : ShaderDefValue) -> String {
  match self {
    Bool(value) => value.to_string()
    Int(value) => value.to_string()
    UInt(value) => value.to_string()
  }
}

///|
pub(all) struct ImportDefinition {
  import_path : String
  items : Array[String]
} derive(Eq, Debug)

///|
pub fn ImportDefinition::default() -> ImportDefinition {
  ImportDefinition::{ import_path: "", items: [] }
}

///|
pub struct ImportDefWithOffset {
  definition : ImportDefinition
  offset : Int
} derive(Eq, Debug)

///|
pub struct EnableDirective {
  extensions : Array[String]
  source_location : Int
} derive(Eq, Debug)

///|
pub struct RequiresDirective {
  extensions : Array[String]
  source_location : Int
} derive(Eq, Debug)

///|
pub struct DiagnosticDirective {
  severity : String
  rule : String
  source_location : Int
} derive(Eq, Debug)

///|
pub struct WgslDirectives {
  enables : Array[EnableDirective]
  requires : Array[RequiresDirective]
  diagnostics : Array[DiagnosticDirective]
} derive(Eq, Debug)

///|
pub fn WgslDirectives::default() -> WgslDirectives {
  WgslDirectives::{ enables: [], requires: [], diagnostics: [] }
}

///|
pub fn WgslDirectives::is_empty(self : WgslDirectives) -> Bool {
  self.enables.is_empty() &&
  self.requires.is_empty() &&
  self.diagnostics.is_empty()
}

///|
pub struct PreprocessOutput {
  preprocessed_source : String
  imports : Array[ImportDefWithOffset]
}

///|
pub fn PreprocessOutput::default() -> PreprocessOutput {
  PreprocessOutput::{ preprocessed_source: "", imports: [] }
}

///|
pub struct PreprocessorMetaData {
  name : String?
  imports : Array[ImportDefWithOffset]
  defines : @hashmap.HashMap[String, ShaderDefValue]
  effective_defs : @hashset.HashSet[String]
  wgsl_directives : WgslDirectives
  cleaned_source : String
}
