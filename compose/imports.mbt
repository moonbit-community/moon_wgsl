///|
using @analysis {
  type WgslGraphBlock,
  type WgslRenamePlan,
  build_wgsl_declaration_graph,
  build_wgsl_decl_local_name_map,
  build_wgsl_rename_plan_from_redirect_map,
  build_wgsl_symbol_redirect_map,
  extract_wgsl_module_items,
  normalize_wgsl_composed_declarations,
  rewrite_wgsl_declarations_with_rename_plan,
  rewrite_wgsl_symbol_redirects,
  strip_wgsl_import_declarations,
  wgsl_string_list_push_unique,
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
  type WgslResolvedImportModule,
  type WgslSourceFile,
  type WgslSourceScanOptions,
  type WgslSymbolRedirect,
}

///|
using @preprocess {
  type PreprocessError,
  active_wgsl_ifdef_line_flags_strict,
  apply_wgsl_ifdefs_strict,
  apply_wgsl_template_consts,
  get_preprocessor_metadata,
}

///|
using @resolver {
  type WgslSourceRegistry,
  collect_wgsl_import_targets,
  default_shader_rel_path_for_module_path,
  normalize_shader_rel_path,
  resolve_wgsl_import_file_path_from_registry,
  resolve_wgsl_import_module_in_registry,
  scan_wgsl_source_files,
}

///|
using @syntax {
  type Token,
  type WgslDirectiveKind,
  type WgslFunction,
  type WgslGlobalDeclData,
  collect_wgsl_source_identifier_names,
  import_brace_balance,
  split_last_identifier,
  split_source_lines,
  starts_with_text,
  tokenize,
  wgsl_directive_prefix_tail,
  wgsl_directive_tail,
}
