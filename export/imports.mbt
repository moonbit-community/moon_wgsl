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
  type WgslSourceCatalogEntry,
  type WgslSourceFile,
  type WgslSourceMapEntry,
  type WgslSymbolRedirect,
  default_wgsl_value_defines,
}

///|
using @compose {
  type Composer,
  type ComposerError,
  type WgslComposeSession,
  finalize_wgsl_writeback_source,
}

///|
using @preprocess {apply_wgsl_ifdefs, apply_wgsl_template_consts}

///|
using @resolver {
  copy_registered_wgsl_source_files,
  copy_wgsl_source_files_from_registry,
}
