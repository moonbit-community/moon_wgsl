///|
pub(all) struct WgslSourceFile {
  rel_path : String
  source : String
} derive(Eq, Debug)

///|
pub struct WgslSourceCatalogEntry {
  rel_path : String
  symbol_name : String
  source_start : Int
  source_end : Int
} derive(Eq, Debug)

///|
pub(all) enum WgslSourceOriginKind {
  Type
  Constant
  Override
  GlobalVariable
  Function
  Other
} derive(Eq, Debug)

///|
pub fn WgslSourceCatalogEntry::WgslSourceCatalogEntry(
  rel_path : String,
  symbol_name : String,
  source_start : Int,
  source_end : Int,
) -> WgslSourceCatalogEntry {
  { rel_path, symbol_name, source_start, source_end }
}

///|
pub struct WgslSourceOriginEntry {
  generated_symbol_name : String
  rel_path : String
  source_symbol_name : String
  kind : WgslSourceOriginKind
  source_start : Int
  source_end : Int
} derive(Eq, Debug)

///|
pub fn WgslSourceOriginEntry::WgslSourceOriginEntry(
  generated_symbol_name : String,
  rel_path : String,
  source_symbol_name : String,
  kind : WgslSourceOriginKind,
  source_start : Int,
  source_end : Int,
) -> WgslSourceOriginEntry {
  {
    generated_symbol_name,
    rel_path,
    source_symbol_name,
    kind,
    source_start,
    source_end,
  }
}

///|
pub fn WgslSourceOriginEntry::generated_symbol_name(
  self : WgslSourceOriginEntry,
) -> String {
  self.generated_symbol_name
}

///|
pub fn WgslSourceOriginEntry::rel_path(self : WgslSourceOriginEntry) -> String {
  self.rel_path
}

///|
pub fn WgslSourceOriginEntry::source_symbol_name(
  self : WgslSourceOriginEntry,
) -> String {
  self.source_symbol_name
}

///|
pub fn WgslSourceOriginEntry::kind(
  self : WgslSourceOriginEntry,
) -> WgslSourceOriginKind {
  self.kind
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
pub fn PreparedWgslSource::PreparedWgslSource(
  source : String,
  source_files : Array[WgslSourceFile],
  source_catalog : Array[WgslSourceCatalogEntry],
  source_origins : Array[WgslSourceOriginEntry],
  diagnostics : Array[WgslDiagnostic],
) -> PreparedWgslSource {
  { source, source_files, source_catalog, source_origins, diagnostics }
}

///|
pub(all) struct WgslSourceScanOptions {
  recursive : Bool
  extensions : Array[String]
  exclude_prefixes : Array[String]
} derive(Eq, Debug)

///|
pub fn WgslSourceScanOptions::default() -> WgslSourceScanOptions {
  { recursive: true, extensions: [".wgsl"], exclude_prefixes: [] }
}
