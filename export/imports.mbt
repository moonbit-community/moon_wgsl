///|
using @transform {
  type WgslEmittedDeclaration,
  type WgslTreeShakenSource,
  emit_wgsl_tree_shaken_source_strict,
}

///|
using @common {
  type WgslComposeOptions,
  type WgslDiagnostic,
  type WgslDiagnosticSeverity,
  type WgslExportOptions,
  type WgslExportOutput,
  type WgslSourceCatalogEntry,
  type WgslSourceMapEntry,
  type WgslSourceOriginEntry,
}

///|
using @compose {type Composer, type ComposerError}

///|
using @parser {type WgslParseError}

///|
