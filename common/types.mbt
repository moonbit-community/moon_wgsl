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
pub struct ImportDefWithOffset {
  definition : ImportDefinition
} derive(Eq, Debug)

///|
pub fn ImportDefWithOffset::new(
  definition : ImportDefinition,
) -> ImportDefWithOffset {
  ImportDefWithOffset::{ definition, }
}

///|
pub struct EnableDirective {
  extensions : Array[String]
} derive(Eq, Debug)

///|
pub fn EnableDirective::new(extensions : Array[String]) -> EnableDirective {
  EnableDirective::{ extensions, }
}

///|
pub struct RequiresDirective {
  extensions : Array[String]
} derive(Eq, Debug)

///|
pub fn RequiresDirective::new(extensions : Array[String]) -> RequiresDirective {
  RequiresDirective::{ extensions, }
}

///|
pub struct DiagnosticDirective {
  severity : String
  rule : String
} derive(Eq, Debug)

///|
pub fn DiagnosticDirective::new(
  severity : String,
  rule : String,
) -> DiagnosticDirective {
  DiagnosticDirective::{ severity, rule }
}

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
pub fn PreprocessOutput::new(
  preprocessed_source : String,
  imports : Array[ImportDefWithOffset],
) -> PreprocessOutput {
  PreprocessOutput::{ preprocessed_source, imports }
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
pub fn PreprocessorMetaData::new(
  name : String?,
  imports : Array[ImportDefWithOffset],
  defines : @hashmap.HashMap[String, ShaderDefValue],
  effective_defs : @hashset.HashSet[String],
  wgsl_directives : WgslDirectives,
  cleaned_source : String,
) -> PreprocessorMetaData {
  PreprocessorMetaData::{
    name,
    imports,
    defines,
    effective_defs,
    wgsl_directives,
    cleaned_source,
  }
}

///|
pub(all) struct WgslSourceFile {
  rel_path : String
  source : String
} derive(Eq, Debug)

///|
pub struct WgslSourceCatalogEntry {
  rel_path : String
  symbol_name : String
  source_text : String
  source_start : Int
  source_end : Int
} derive(Eq, Debug)

///|
pub fn WgslSourceCatalogEntry::new(
  rel_path : String,
  symbol_name : String,
  source_text : String,
  source_start : Int,
  source_end : Int,
) -> WgslSourceCatalogEntry {
  WgslSourceCatalogEntry::{
    rel_path,
    symbol_name,
    source_text,
    source_start,
    source_end,
  }
}

///|
pub struct WgslSourceOriginEntry {
  generated_symbol_name : String
  rel_path : String
  source_symbol_name : String
  source_start : Int
  source_end : Int
} derive(Eq, Debug)

///|
pub fn WgslSourceOriginEntry::new(
  generated_symbol_name : String,
  rel_path : String,
  source_symbol_name : String,
  source_start : Int,
  source_end : Int,
) -> WgslSourceOriginEntry {
  WgslSourceOriginEntry::{
    generated_symbol_name,
    rel_path,
    source_symbol_name,
    source_start,
    source_end,
  }
}

///|
pub struct PreparedWgslSource {
  source : String
  source_files : Array[WgslSourceFile]
  source_catalog : Array[WgslSourceCatalogEntry]
  source_origins : Array[WgslSourceOriginEntry]
  diagnostics : Array[WgslDiagnostic]
}

///|
pub fn PreparedWgslSource::new(
  source : String,
  source_files : Array[WgslSourceFile],
  source_catalog : Array[WgslSourceCatalogEntry],
  source_origins : Array[WgslSourceOriginEntry],
  diagnostics : Array[WgslDiagnostic],
) -> PreparedWgslSource {
  PreparedWgslSource::{
    source,
    source_files,
    source_catalog,
    source_origins,
    diagnostics,
  }
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
  Warn
  Error
} derive(Eq, Debug)

///|
pub struct WgslDiagnostic {
  severity : WgslDiagnosticSeverity
  message : String
  rel_path : String?
  symbol_name : String?
} derive(Eq, Debug)

///|
pub fn WgslDiagnostic::new(
  severity : WgslDiagnosticSeverity,
  message : String,
  rel_path : String?,
  symbol_name : String?,
) -> WgslDiagnostic {
  WgslDiagnostic::{ severity, message, rel_path, symbol_name }
}

///|
pub(all) struct WgslSymbolRedirect {
  from_name : String
  to_name : String
} derive(Eq, Debug)

///|
pub(all) struct WgslComposeOptions {
  defines : @hashmap.HashMap[String, Bool]
  value_defines : @hashmap.HashMap[String, Int]
  redirects : Array[WgslSymbolRedirect]
  additional_imports : Array[ImportDefinition]
} derive(Eq, Debug)

///|
pub fn WgslComposeOptions::default() -> WgslComposeOptions {
  WgslComposeOptions::{
    defines: @hashmap.HashMap::new(),
    value_defines: default_wgsl_value_defines(),
    redirects: [],
    additional_imports: [],
  }
}

///|
pub fn default_wgsl_value_defines() -> @hashmap.HashMap[String, Int] {
  let defines : @hashmap.HashMap[String, Int] = @hashmap.HashMap::new()
  defines.set("AVAILABLE_STORAGE_BUFFER_BINDINGS", 8)
  defines.set("MAX_DIRECTIONAL_LIGHTS", 10)
  defines.set("MAX_CASCADES_PER_LIGHT", 4)
  defines.set("MAX_RECT_LIGHTS", 4)
  defines.set("MATERIAL_BIND_GROUP", 3)
  defines.set("SORTED_FRAGMENT_MAX_COUNT", 8)
  defines.set("WORLD_CACHE_SIZE", 1048576)
  defines.set("PER_OBJECT_BUFFER_BATCH_SIZE", 1)
  defines.set("SCREEN_SPACE_SPECULAR_TRANSMISSION_BLUR_TAPS", 8)
  defines
}

///|
pub struct WgslSourceMapEntry {
  rel_path : String
  symbol_name : String?
} derive(Eq, Debug)

///|
pub fn WgslSourceMapEntry::new(
  rel_path : String,
  symbol_name : String?,
) -> WgslSourceMapEntry {
  WgslSourceMapEntry::{ rel_path, symbol_name }
}

///|
pub(all) struct WgslExportOptions {
  root_items : Array[String]
} derive(Eq, Debug)

///|
pub struct WgslExportOutput {
  source : String
  source_catalog : Array[WgslSourceCatalogEntry]
  source_origins : Array[WgslSourceOriginEntry]
  source_map : Array[WgslSourceMapEntry]
  diagnostics : Array[WgslDiagnostic]
} derive(Eq, Debug)

///|
pub fn WgslExportOutput::new(
  source : String,
  source_catalog : Array[WgslSourceCatalogEntry],
  source_origins : Array[WgslSourceOriginEntry],
  source_map : Array[WgslSourceMapEntry],
  diagnostics : Array[WgslDiagnostic],
) -> WgslExportOutput {
  WgslExportOutput::{
    source,
    source_catalog,
    source_origins,
    source_map,
    diagnostics,
  }
}

///|
pub(all) struct WgslImportTarget {
  raw_path : String
  alias_name : String
} derive(Eq, Debug)

///|
pub struct WgslResolvedImportModule {
  module_path : String
  rel_path : String
} derive(Eq, Debug)

///|
pub fn WgslResolvedImportModule::new(
  module_path : String,
  rel_path : String,
) -> WgslResolvedImportModule {
  WgslResolvedImportModule::{ module_path, rel_path }
}
