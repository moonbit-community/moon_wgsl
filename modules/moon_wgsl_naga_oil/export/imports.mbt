///|
using @transform {
  type WgslEmittedDeclaration,
  collect_wgsl_named_declarations_strict,
}

///|
using @contract {
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
using @ir {tree_shake_wgsl_source_via_ir}

///|
