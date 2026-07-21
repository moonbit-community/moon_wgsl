///|
using @transform {
  type WgslReferenceRewritePlan,
  type WgslModuleItemExtractor,
  type WgslModuleItemExtraction,
  type WgslModuleItemOrigin,
  collect_wgsl_source_catalog_declarations_strict,
  collect_wgsl_virtual_override_targets_strict,
  extract_wgsl_module_item_origins_strict,
  new_wgsl_module_item_extractor_from_unit,
  rewrite_wgsl_declarations_with_binding_plan,
  rewrite_wgsl_references_with_binding_plan,
  specialize_wgsl_immediate_globals,
}

///|
using @contract {
  type ComposableModuleDescriptor,
  type ImportDefinition,
  type PreparedWgslSource,
  type ShaderDefValue,
  type WgslComposeAliasSymbolIdentity,
  type WgslComposeOptions,
  type WgslComposeSymbolIdentity,
  type WgslDiagnostic,
  type WgslImportTarget,
  type WgslImmediateSpecialization,
  type WgslReferencePath,
  type WgslSourceCatalogEntry,
  type WgslSourceFile,
  type WgslSourceOriginEntry,
  type WgslSourceOriginKind,
  type WgslSymbolRedirect,
}

///|
using @metadata {
  type MetadataError,
  collect_wgsl_source_local_shader_defines,
  get_preprocessor_metadata,
}

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
}

///|
using @ast {type WgslGlobalDecl, type WgslTranslationUnit}

///|
using @parser {type WgslParseError, parse_wgsl_translation_unit_strict}

///|
using @lex {
  type WgslToken,
  replace_comments,
  tokenize_wgsl,
  wgsl_code_point_at,
  wgsl_line_end,
  wgsl_regex_whitespace_code_point,
  wgsl_xid_continue_code_point,
  wgsl_xid_start_code_point,
}

///|

///|
using @import_syntax {
  parse_wgsl_import_spec_is_empty_or_final_semicolon,
  parse_wgsl_import_targets,
}

///|
using @directive {
  type WgslPreprocessorDirective,
  type WgslDirectiveScanItem,
  mask_naga_oil_directives_for_wgsl,
  parse_glsl_version_directive,
  parse_wgsl_directive_scan_items,
}

///|
