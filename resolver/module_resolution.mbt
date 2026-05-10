///|
pub fn resolve_wgsl_import_module_in_registry(
  registry : WgslSourceRegistry,
  import_path : String,
  modules : @hashmap.HashMap[String, String],
) -> WgslResolvedImportModule? {
  let segments : Array[String] = []
  for seg in import_path.split("::") {
    let text = seg.to_owned().trim().to_owned()
    if text != "" {
      segments.push(text)
    }
  }
  while segments.length() > 0 {
    let mut module_path = segments[0]
    for i in 1..<segments.length() {
      module_path = "\{module_path}::\{segments[i]}"
    }
    if modules.get(module_path) is Some(rel_path) {
      return Some(WgslResolvedImportModule(module_path, rel_path))
    }
    let default_rel = wgsl_module_path_to_rel_path(module_path)
    if registry.registered_source(default_rel) is Some(_) {
      return Some(WgslResolvedImportModule(module_path, default_rel))
    }
    let namespace_rel = wgsl_module_path_to_rel_path_namespace(module_path)
    if namespace_rel != "" &&
      namespace_rel != default_rel &&
      registry.registered_source(namespace_rel) is Some(_) {
      return Some(WgslResolvedImportModule(module_path, namespace_rel))
    }
    segments.pop() |> ignore
  }
  None
}

///|
