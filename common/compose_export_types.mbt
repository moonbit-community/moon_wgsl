///|
pub(all) struct WgslSymbolRedirect {
  from_name : String
  to_name : String
} derive(Eq, Debug)

///|
pub(all) struct WgslComposeOptions {
  defines : Map[String, Bool]
  value_defines : Map[String, ShaderDefValue]
  redirects : Array[WgslSymbolRedirect]
  additional_imports : Array[ImportDefinition]
} derive(Eq, Debug)

///|
pub fn WgslComposeOptions::default() -> WgslComposeOptions {
  WgslComposeOptions::{
    defines: Map([]),
    value_defines: default_wgsl_value_defines(),
    redirects: [],
    additional_imports: [],
  }
}

///|
pub fn default_wgsl_value_defines() -> Map[String, ShaderDefValue] {
  let defines : Map[String, ShaderDefValue] = Map([])
  defines.set("AVAILABLE_STORAGE_BUFFER_BINDINGS", ShaderDefValue::Int(8))
  defines.set("MAX_DIRECTIONAL_LIGHTS", ShaderDefValue::Int(10))
  defines.set("MAX_CASCADES_PER_LIGHT", ShaderDefValue::Int(4))
  defines.set("MAX_RECT_LIGHTS", ShaderDefValue::Int(4))
  defines.set("MATERIAL_BIND_GROUP", ShaderDefValue::Int(3))
  defines.set("SORTED_FRAGMENT_MAX_COUNT", ShaderDefValue::Int(8))
  defines.set("WORLD_CACHE_SIZE", ShaderDefValue::Int(1048576))
  defines.set("PER_OBJECT_BUFFER_BATCH_SIZE", ShaderDefValue::Int(1))
  defines.set(
    "SCREEN_SPACE_SPECULAR_TRANSMISSION_BLUR_TAPS",
    ShaderDefValue::Int(8),
  )
  defines
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
pub fn WgslExportOutput::WgslExportOutput(
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
