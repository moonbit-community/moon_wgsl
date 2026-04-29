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

///|
pub(all) struct WgslSourceFile {
  rel_path : String
  source : String
} derive(Eq, Debug)

///|
pub fn WgslSourceFile::default() -> WgslSourceFile {
  WgslSourceFile::{ rel_path: "", source: "" }
}

///|
pub(all) struct WgslSourceScanOptions {
  recursive : Bool
  extensions : Array[String]
  exclude_prefixes : Array[String]
} derive(Eq, Debug)

///|
pub fn WgslSourceScanOptions::default() -> WgslSourceScanOptions {
  WgslSourceScanOptions::{
    recursive: true,
    extensions: [".wgsl"],
    exclude_prefixes: [],
  }
}

///|
pub(all) enum WgslDiagnosticSeverity {
  Info
  Warn
  Error
} derive(Eq, Debug)

///|
pub struct WgslDiagnostic {
  severity : WgslDiagnosticSeverity
  message : String
  rel_path : String?
  symbol_name : String?
  generated_start : Int?
  source_start : Int?
} derive(Eq, Debug)

///|
pub fn WgslDiagnostic::default() -> WgslDiagnostic {
  WgslDiagnostic::{
    severity: WgslDiagnosticSeverity::Info,
    message: "",
    rel_path: None,
    symbol_name: None,
    generated_start: None,
    source_start: None,
  }
}

///|
pub struct WgslSourceCatalogEntry {
  rel_path : String
  symbol_name : String
  source_text : String
  source_start : Int
  source_end : Int
} derive(Eq, Debug)

///|
pub fn WgslSourceCatalogEntry::default() -> WgslSourceCatalogEntry {
  WgslSourceCatalogEntry::{
    rel_path: "",
    symbol_name: "",
    source_text: "",
    source_start: 0,
    source_end: 0,
  }
}

///|
pub(all) struct WgslSymbolRedirect {
  from_name : String
  to_name : String
} derive(Eq, Debug)

///|
pub fn WgslSymbolRedirect::default() -> WgslSymbolRedirect {
  WgslSymbolRedirect::{ from_name: "", to_name: "" }
}

///|
pub(all) struct WgslComposeOptions {
  assets_base : String
  defines : @hashmap.HashMap[String, Bool]
  value_defines : @hashmap.HashMap[String, Int]
  redirects : Array[WgslSymbolRedirect]
  additional_imports : Array[ImportDefinition]
} derive(Eq, Debug)

///|
pub fn WgslComposeOptions::default() -> WgslComposeOptions {
  WgslComposeOptions::{
    assets_base: "",
    defines: @hashmap.HashMap::new(),
    value_defines: default_wgsl_value_defines(),
    redirects: [],
    additional_imports: [],
  }
}

///|
pub struct WgslSourceMapEntry {
  generated_start : Int
  generated_end : Int
  rel_path : String
  source_start : Int
  source_end : Int
  symbol_name : String?
} derive(Eq, Debug)

///|
pub fn WgslSourceMapEntry::default() -> WgslSourceMapEntry {
  WgslSourceMapEntry::{
    generated_start: 0,
    generated_end: 0,
    rel_path: "",
    source_start: 0,
    source_end: 0,
    symbol_name: None,
  }
}

///|
pub(all) struct WgslExportOptions {
  root_items : Array[String]
} derive(Eq, Debug)

///|
pub fn WgslExportOptions::default() -> WgslExportOptions {
  WgslExportOptions::{ root_items: [] }
}

///|
pub struct WgslExportOutput {
  source : String
  source_catalog : Array[WgslSourceCatalogEntry]
  source_map : Array[WgslSourceMapEntry]
  diagnostics : Array[WgslDiagnostic]
} derive(Eq, Debug)

///|
pub fn WgslExportOutput::default() -> WgslExportOutput {
  WgslExportOutput::{
    source: "",
    source_catalog: [],
    source_map: [],
    diagnostics: [],
  }
}
