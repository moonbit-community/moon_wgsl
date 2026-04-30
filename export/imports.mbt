///|
using @analysis {
  type WgslDeclarationGraph,
  type WgslGraphBlock,
  build_wgsl_declaration_graph,
  collect_wgsl_reachable_declaration_names,
}

///|
using @common {
  type WgslComposeOptions,
  type WgslDiagnostic,
  type WgslDiagnosticSeverity,
  type WgslExportOptions,
  type WgslExportOutput,
  type PreparedWgslSource,
  type WgslSourceCatalogEntry,
  type WgslSourceMapEntry,
}

///|
using @compose {type Composer, type ComposerError}

///|
