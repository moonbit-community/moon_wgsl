///|
using @analysis {
  type WgslEmittedDeclaration,
  type WgslModuleItemExtraction,
  build_wgsl_global_rename_plan_from_redirect_map,
  build_wgsl_reference_rename_plan_from_redirect_map,
  build_wgsl_symbol_redirect_map,
  collect_wgsl_named_declarations_strict,
  extract_wgsl_module_item_origins_strict,
  invalid_wgsl_struct_member_identifier,
  normalize_wgsl_output_identifiers,
  normalize_wgsl_composed_declarations,
  rewrite_wgsl_declarations_with_rename_plan,
  rewrite_wgsl_symbol_redirects,
  strip_wgsl_import_declarations_strict,
}

///|
using @common {
  type ComposableModuleDefinition,
  type ComposableModuleDescriptor,
  type ImportDefinition,
  type PreparedWgslSource,
  type ShaderDefValue,
  type WgslComposeOptions,
  type WgslDiagnostic,
  type WgslDiagnosticSeverity,
  type WgslImportTarget,
  type WgslSourceCatalogEntry,
  type WgslSourceFile,
  type WgslSourceOriginEntry,
  type WgslSourceScanOptions,
  type WgslSymbolRedirect,
}

///|
using @metadata {type MetadataError, get_preprocessor_metadata}

///|
using @preprocess {
  type PreprocessError,
  apply_wgsl_ifdefs_strict,
  apply_wgsl_template_consts,
}

///|
using @resolver {
  type WgslSourceRegistry,
  default_shader_rel_path_for_module_path,
  normalize_shader_rel_path,
  scan_wgsl_source_files,
}

///|
using @ast {type WgslDirective, type WgslDirectiveKind}

///|
using @parser {
  type WgslParseError,
  type WgslDirectiveScanItem,
  type WgslDirectiveScanItemKind,
  parse_glsl_version_directive,
  parse_wgsl_import_spec_is_empty_or_final_semicolon,
  parse_wgsl_import_targets,
  parse_wgsl_directive_scan_items,
  parse_wgsl_translation_unit_strict,
}

///|
