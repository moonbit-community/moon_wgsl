///|
using @transform {
  type WgslReferenceRewritePlan,
  type WgslEmittedDeclaration,
  type WgslModuleItemExtraction,
  collect_wgsl_named_declarations_strict,
  collect_wgsl_source_catalog_declarations_strict,
  collect_wgsl_virtual_override_targets_strict,
  extract_wgsl_module_item_origins_strict,
  rewrite_wgsl_declarations_with_binding_plan,
  rewrite_wgsl_references_with_binding_plan,
}

///|
using @common {
  type ComposableModuleDescriptor,
  type ImportDefinition,
  type PreparedWgslSource,
  type ShaderDefValue,
  type WgslComposeOptions,
  type WgslDiagnostic,
  type WgslDiagnosticSeverity,
  type WgslImportTarget,
  type WgslReferencePath,
  type WgslSourceCatalogEntry,
  type WgslSourceFile,
  type WgslSourceOriginEntry,
  type WgslSourceOriginKind,
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
using @ast {type WgslDirective, type WgslDirectiveKind, type WgslGlobalDeclData}

///|
using @parser {type WgslParseError, parse_wgsl_translation_unit_strict}

///|
using @ir {
  type WgslIrAliasSymbolIdentity,
  type WgslIrFinalNameTable,
  type WgslIrLinkGraph,
  type WgslIrSymbolIdentity,
}

///|
using @import_syntax {
  parse_wgsl_import_spec_is_empty_or_final_semicolon,
  parse_wgsl_import_targets,
}

///|
using @directive {
  type WgslDirectiveScanItem,
  type WgslDirectiveScanItemKind,
  parse_wgsl_directive_scan_items,
}

///|
using @directive_syntax {parse_glsl_version_directive}

///|
