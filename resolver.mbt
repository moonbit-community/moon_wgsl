///|
pub type WgslSourceRegistry = @resolver.WgslSourceRegistry

///|
pub fn collect_wgsl_import_targets(
  spec : String,
  prefix : String,
  targets : Array[WgslImportTarget],
) -> Unit {
  @resolver.collect_wgsl_import_targets(spec, prefix, targets)
}

///|
pub fn normalize_shader_rel_path(rel : String) -> String {
  @resolver.normalize_shader_rel_path(rel)
}

///|
pub fn resolve_wgsl_import_file_path(
  importer_rel_path : String,
  import_path : String,
) -> String? {
  @resolver.resolve_wgsl_import_file_path(importer_rel_path, import_path)
}

///|
pub fn resolve_wgsl_source_file_path(
  assets_base : String,
  rel : String,
) -> String? {
  @resolver.resolve_wgsl_source_file_path(assets_base, rel)
}

///|
pub fn scan_wgsl_source_files(
  root : String,
  options : WgslSourceScanOptions,
) -> Array[WgslSourceFile] raise @fs.IOError {
  @resolver.scan_wgsl_source_files(root, options)
}

///|
pub fn scan_wgsl_source_files_checked(
  root : String,
  options : WgslSourceScanOptions,
) -> (Array[WgslSourceFile], Array[WgslDiagnostic]) raise @fs.IOError {
  @resolver.scan_wgsl_source_files_checked(root, options)
}

///|
pub fn clear_registered_wgsl_source_registry() -> Unit {
  @resolver.clear_registered_wgsl_source_registry()
}

///|
pub fn register_wgsl_source(rel_path : String, source : String) -> Unit {
  @resolver.register_wgsl_source(rel_path, source)
}

///|
pub fn analyze_wgsl_source_files_for_registry(
  files : Array[WgslSourceFile],
) -> Array[WgslDiagnostic] {
  @resolver.analyze_wgsl_source_files_for_registry(files)
}

///|
pub fn register_wgsl_source_files_checked(
  files : Array[WgslSourceFile],
) -> Array[WgslDiagnostic] {
  @resolver.register_wgsl_source_files_checked(files)
}

///|
pub fn register_wgsl_source_files(files : Array[WgslSourceFile]) -> Unit {
  @resolver.register_wgsl_source_files(files)
}

///|
pub fn registered_wgsl_source(rel_path : String) -> String? {
  @resolver.registered_wgsl_source(rel_path)
}

///|
pub fn copy_registered_wgsl_source_files() -> Array[WgslSourceFile] {
  @resolver.copy_registered_wgsl_source_files()
}

///|
pub fn copy_registered_wgsl_import_module_paths() -> @hashmap.HashMap[
  String,
  String,
] {
  @resolver.copy_registered_wgsl_import_module_paths()
}

///|
pub fn build_wgsl_import_module_paths(
  assets_base : String,
) -> @hashmap.HashMap[String, String] {
  @resolver.build_wgsl_import_module_paths(assets_base)
}

///|
pub fn resolve_wgsl_import_module(
  assets_base : String,
  import_path : String,
  modules : @hashmap.HashMap[String, String],
) -> WgslResolvedImportModule? {
  @resolver.resolve_wgsl_import_module(assets_base, import_path, modules)
}
