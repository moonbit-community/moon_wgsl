///|
using @analysis {
  build_wgsl_rename_plan_from_redirect_map,
  build_wgsl_symbol_redirect_map,
  collect_wgsl_named_declarations,
  extract_wgsl_module_items,
  normalize_wgsl_composed_declarations,
  rewrite_wgsl_declarations_with_rename_plan,
  rewrite_wgsl_symbol_redirects,
  strip_wgsl_import_declarations,
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
  type WgslSourceScanOptions,
  type WgslSymbolRedirect,
}

///|
using @import_planner {
  type WgslImportRequest,
  build_wgsl_import_rename_map,
  collect_wgsl_alias_requested_paths,
  collect_wgsl_import_alias_redirects,
  collect_wgsl_qualified_module_targets,
  find_wgsl_import_request_index,
  resolve_wgsl_import_request_module,
  split_last_wgsl_path,
  unresolved_wgsl_namespace_reference,
  wgsl_full_module_visit_key,
  wgsl_import_cycle_string,
  wgsl_import_default_alias,
  wgsl_import_request_visit_key,
  wgsl_import_requested_item_name,
  wgsl_import_targets_push_unique,
  wgsl_imported_item_name_key,
  wgsl_path_stack_contains,
  wgsl_source_contains_identifier,
  wgsl_source_uses_import_alias,
}

///|
using @metadata {get_preprocessor_metadata}

///|
using @preprocess {
  type PreprocessError,
  active_wgsl_ifdef_line_flags_strict,
  apply_wgsl_ifdefs,
  apply_wgsl_ifdefs_strict,
  apply_wgsl_template_consts,
}

///|
using @resolver {
  type WgslSourceRegistry,
  collect_wgsl_import_targets,
  default_shader_rel_path_for_module_path,
  normalize_shader_rel_path,
  scan_wgsl_source_files,
}

///|
using @ast {type WgslDirectiveKind}

///|
using @parser {
  import_brace_balance,
  split_source_lines,
  wgsl_directive_prefix_tail,
  wgsl_directive_tail,
}

///|
using @writeback {
  invalid_wgsl_struct_member_identifier,
  sanitize_wgsl_writeback_identifiers,
}
