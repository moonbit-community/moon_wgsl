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
pub fn Composer::register_source_files_checked(
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
    value_defines: copy_int_defs(options.value_defines),
    modules: self.registry.copy_import_module_paths(),
    redirects: options.redirects.copy(),
    additional_imports: copy_import_definitions(options.additional_imports),
    redirect_match_counts: @hashmap.HashMap::new(),
    visited: @hashmap.HashMap::new(),
    imported_item_names: @hashmap.HashMap::new(),
    active_rel_paths: [],
    resolved_source_files: @hashmap.HashMap::new(),
  }
}
