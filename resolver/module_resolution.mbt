///|
fn wgsl_module_path_to_rel_path(module_path : String) -> String {
  let mut rel = "shaders/"
  let mut first = true
  for seg in module_path.split("::") {
    let text = seg.to_owned()
    if text == "" {
      continue
    }
    if first {
      first = false
    } else {
      rel = "\{rel}/"
    }
    rel = "\{rel}\{text}"
  }
  "\{rel}.wgsl"
}

///|
fn wgsl_module_path_to_rel_path_namespace(module_path : String) -> String {
  let segments : Array[String] = []
  for seg in module_path.split("::") {
    let text = seg.to_owned().trim().to_owned()
    if text != "" {
      segments.push(text)
    }
  }
  if segments.length() == 0 {
    return ""
  }
  let mut rel = "shaders/\{segments[0]}"
  for i in 1..<segments.length() {
    rel = "\{rel}/\{segments[i]}"
  }
  "\{rel}.wgsl"
}

///|
pub fn default_shader_rel_path_for_module_path(module_path : String) -> String {
  wgsl_module_path_to_rel_path_namespace(module_path)
}

///|
pub fn build_wgsl_import_module_paths() -> @hashmap.HashMap[String, String] {
  copy_registered_wgsl_import_module_paths()
}

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
      return Some(WgslResolvedImportModule::{ module_path, rel_path })
    }
    let default_rel = wgsl_module_path_to_rel_path(module_path)
    if registry.registered_source(default_rel) is Some(_) {
      return Some(WgslResolvedImportModule::{
        module_path,
        rel_path: default_rel,
      })
    }
    let namespace_rel = wgsl_module_path_to_rel_path_namespace(module_path)
    if namespace_rel != "" &&
      namespace_rel != default_rel &&
      registry.registered_source(namespace_rel) is Some(_) {
      return Some(WgslResolvedImportModule::{
        module_path,
        rel_path: namespace_rel,
      })
    }
    segments.pop() |> ignore
  }
  None
}

///|
pub fn resolve_wgsl_import_module(
  import_path : String,
  modules : @hashmap.HashMap[String, String],
) -> WgslResolvedImportModule? {
  resolve_wgsl_import_module_in_registry(
    registered_wgsl_source_registry_singleton, import_path, modules,
  )
}
