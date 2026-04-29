///|
using @analysis {
  type WgslGraphBlock,
  build_wgsl_declaration_graph,
  build_wgsl_symbol_redirect_map,
  extract_wgsl_module_items,
  rewrite_wgsl_declaration_text_with_map,
  rewrite_wgsl_declaration_text_with_renamed_declarations,
  rewrite_wgsl_symbol_redirects,
  strip_wgsl_import_declarations,
  wgsl_identifier_char,
  wgsl_string_list_push_unique,
}

///|
using @common {
  type ComposableModuleDefinition,
  type ComposableModuleDescriptor,
  type ImportDefinition,
  type ShaderDefValue,
  type WgslComposeOptions,
  type WgslDiagnostic,
  type WgslImportTarget,
  type WgslResolvedImportModule,
  type WgslSourceFile,
  type WgslSourceScanOptions,
  type WgslSymbolRedirect,
  default_wgsl_value_defines,
}

///|
using @preprocess {get_preprocessor_metadata}

///|
using @resolver {
  type WgslSourceRegistry,
  collect_wgsl_import_targets,
  default_shader_rel_path_for_module_path,
  normalize_shader_rel_path,
  registered_wgsl_source,
  registered_wgsl_source_registry_singleton,
  resolve_wgsl_import_file_path_from_registry,
  resolve_wgsl_import_module_in_registry,
  scan_wgsl_source_files,
}

///|
using @syntax {
  type Token,
  type WgslAttribute,
  type WgslDirectiveKind,
  type WgslFunction,
  type WgslGlobalDeclData,
  collect_wgsl_source_identifier_names,
  import_brace_balance,
  parse_wgsl_translation_unit,
  split_last_identifier,
  split_source_lines,
  starts_with_text,
  tokenize,
  word_tail,
  wgsl_directive_prefix_tail,
  wgsl_directive_tail,
}
