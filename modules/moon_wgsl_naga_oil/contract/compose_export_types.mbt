///|
pub(all) struct WgslSymbolRedirect {
  from_name : String
  to_name : String
} derive(Eq, Debug)

///|
/// Concrete values for one `var<immediate>` struct global.
///
/// `rel_path` and `global_name` identify the declaration before imports are
/// linked. Every field in the struct must have a value.
pub(all) struct WgslImmediateSpecialization {
  rel_path : String
  global_name : String
  field_values : Map[String, ShaderDefValue]
} derive(Eq, Debug)

///|
pub fn WgslImmediateSpecialization::WgslImmediateSpecialization(
  rel_path : String,
  global_name : String,
  field_values : Map[String, ShaderDefValue],
) -> WgslImmediateSpecialization {
  { rel_path, global_name, field_values }
}

///|
pub(all) struct WgslComposeOptions {
  defines : Map[String, Bool]
  value_defines : Map[String, ShaderDefValue]
  redirects : Array[WgslSymbolRedirect]
  additional_imports : Array[ImportDefinition]
  immediate_specializations : Array[WgslImmediateSpecialization]
} derive(Eq, Debug)

///|
pub fn WgslComposeOptions::default() -> WgslComposeOptions {
  {
    defines: Map([]),
    value_defines: Map([]),
    redirects: [],
    additional_imports: [],
    immediate_specializations: [],
  }
}

///|
pub struct WgslSourceMapEntry {
  rel_path : String
  symbol_name : String?
} derive(Eq, Debug)

///|
pub fn WgslSourceMapEntry::WgslSourceMapEntry(
  rel_path : String,
  symbol_name : String?,
) -> WgslSourceMapEntry {
  { rel_path, symbol_name }
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
pub fn WgslExportOutput::WgslExportOutput(
  source : String,
  source_catalog : Array[WgslSourceCatalogEntry],
  source_origins : Array[WgslSourceOriginEntry],
  source_map : Array[WgslSourceMapEntry],
  diagnostics : Array[WgslDiagnostic],
) -> WgslExportOutput {
  { source, source_catalog, source_origins, source_map, diagnostics }
}

///|
pub fn WgslExportOutput::source(self : WgslExportOutput) -> String {
  self.source
}

///|
pub fn WgslExportOutput::source_catalog(
  self : WgslExportOutput,
) -> Array[WgslSourceCatalogEntry] {
  self.source_catalog.copy()
}

///|
pub fn WgslExportOutput::source_origins(
  self : WgslExportOutput,
) -> Array[WgslSourceOriginEntry] {
  self.source_origins.copy()
}

///|
pub fn WgslExportOutput::source_map(
  self : WgslExportOutput,
) -> Array[WgslSourceMapEntry] {
  self.source_map.copy()
}

///|
pub fn WgslExportOutput::diagnostics(
  self : WgslExportOutput,
) -> Array[WgslDiagnostic] {
  self.diagnostics.copy()
}
