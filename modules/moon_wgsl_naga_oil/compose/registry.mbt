///|
pub fn Composer::clear_sources(self : Composer) -> Unit {
  self.registry.clear()
  self.processed_module_cache.clear()
}

///|
pub fn Composer::register_source(
  self : Composer,
  rel_path : String,
  source : String,
) -> Unit {
  self.processed_module_cache.clear()
  ignore(self.registry.register_source(rel_path, source, None))
}

///|
pub fn Composer::register_source_files(
  self : Composer,
  files : Array[WgslSourceFile],
) -> Unit {
  self.processed_module_cache.clear()
  self.registry.register_source_files(files)
}

///|
pub fn Composer::register_source_files_checked(
  self : Composer,
  files : Array[WgslSourceFile],
) -> Array[WgslDiagnostic] {
  let diagnostics : Array[WgslDiagnostic] = []
  self.registry.register_source_files_checked(files, diagnostics)
  diagnostics
}

///|
pub fn Composer::registered_source(
  self : Composer,
  rel_path : String,
) -> String? {
  self.registry.registered_source(rel_path)
}

///|
fn Composer::new_wgsl_compose_session(
  self : Composer,
  options : WgslComposeOptions,
) -> WgslComposeSession {
  {
    defines: copy_bool_defs(options.defines),
    value_defines: copy_value_defs(options.value_defines),
    modules: self.registry.copy_import_module_paths(),
    redirects: options.redirects.copy(),
    additional_imports: copy_import_definitions(options.additional_imports),
    immediate_specializations: copy_wgsl_immediate_specializations(
      options.immediate_specializations,
    ),
    global_alias_bindings: WgslComposeBindingSet(),
    redirect_match_counts: Map([]),
    visited: Set([]),
    graph_planned_requests: Set([]),
    graph_planning_rel_paths: [],
    graph_execution_complete: false,
    emitted_virtual_functions: false,
    symbols: WgslComposeSymbolTable(),
    link_graph: WgslComposeLinkGraph(),
    semantic_facts: Map([]),
    directive_scans: Map([]),
    importless_sources: Map([]),
    directive_import_targets: Map([]),
    directive_single_import_targets: Map([]),
    semantic_reference_first_starts: Map([]),
    source_local_shader_defs: Map([]),
    source_cache_ids: Map([]),
    next_source_cache_id: 0,
    processed_modules: Map([]),
    selected_import_candidate_rel_paths: Map([]),
    import_request_plans: Map([]),
    emitted_item_import_requests: Map([]),
    active_rel_paths: [],
  }
}
