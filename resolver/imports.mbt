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
using @metadata {wgsl_source_define_import_path}

///|
using @syntax {parse_wgsl_import_targets, trim_trailing_semicolons}
