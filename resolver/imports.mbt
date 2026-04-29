///|
using @common {
  type WgslDiagnostic,
  type WgslDiagnosticSeverity,
  type WgslImportTarget,
  type WgslResolvedImportModule,
  type WgslSourceFile,
  type WgslSourceScanOptions,
}

///|
using @preprocess {get_preprocessor_data}

///|
using @syntax {parse_wgsl_import_targets, trim_trailing_semicolons}
