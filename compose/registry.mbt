///|
pub fn Composer::clear_sources(self : Composer) -> Unit {
  self.registry.clear()
}

///|
pub fn Composer::register_source(
  self : Composer,
  rel_path : String,
  source : String,
) -> Unit {
  ignore(self.registry.register_source(rel_path, source, None))
}

///|
pub fn Composer::register_source_files(
  self : Composer,
  files : Array[WgslSourceFile],
) -> Unit {
  self.registry.register_source_files(files)
}

///|
fn Composer::register_source_files_checked(
  self : Composer,
  files : Array[WgslSourceFile],
) -> Array[WgslDiagnostic] {
  let diagnostics : Array[WgslDiagnostic] = []
  self.registry.register_source_files_checked(files, diagnostics)
  diagnostics
}

///|
pub fn Composer::register_source_tree(
  self : Composer,
  root : String,
  options : WgslSourceScanOptions,
) -> Unit raise @fs.IOError {
  self.register_source_files(scan_wgsl_source_files(root, options))
}

///|
pub fn Composer::register_source_tree_checked(
  self : Composer,
  root : String,
  options : WgslSourceScanOptions,
) -> Array[WgslDiagnostic] raise @fs.IOError {
  self.register_source_files_checked(scan_wgsl_source_files(root, options))
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
  WgslComposeSession::{
    defines: copy_bool_defs(options.defines),
    value_defines: copy_value_defs(options.value_defines),
    modules: self.registry.copy_import_module_paths(),
    redirects: options.redirects.copy(),
    additional_imports: copy_import_definitions(options.additional_imports),
    global_alias_bindings: WgslComposeBindingSet(),
    redirect_match_counts: Map([]),
    visited: @set.Set([]),
    graph_planned_requests: @set.Set([]),
    graph_planning_rel_paths: [],
    graph_execution_complete: false,
    occupied_resource_bindings: @set.Set([]),
    symbols: WgslComposeSymbolTable(),
    link_graph: WgslIrLinkGraph(),
    semantic_facts: Map([]),
    active_rel_paths: [],
  }
}
