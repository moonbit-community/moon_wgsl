///|
using @analysis {
  type WgslDeclarationGraph,
  type WgslGraphBlock,
  build_wgsl_declaration_graph,
  collect_wgsl_reachable_declaration_names,
  strip_wgsl_import_declarations,
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
  type WgslSourceFile,
  type WgslSourceMapEntry,
}

///|
using @compose {type Composer, type ComposerError}

///|
using @preprocess {apply_wgsl_ifdefs, apply_wgsl_template_consts}

///|
