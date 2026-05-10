///|
fn wgsl_module_path_from_rel_path(rel_path : String) -> String? {
  let normalized_rel = normalize_shader_rel_path(rel_path)
  if normalized_rel == "" || !normalized_rel.has_suffix(".wgsl") {
    return None
  }
  let without_extension = normalized_rel[:normalized_rel.length() - 5].to_owned()
  let trimmed_prefix = if without_extension.has_prefix("shaders/") {
    without_extension[8:without_extension.length()].to_owned()
  } else {
    without_extension
  }
  let segments : Array[String] = []
  for segment in trimmed_prefix.split("/") {
    let text = segment.to_owned().trim().to_owned()
    if text != "" {
      segments.push(text)
    }
  }
  if segments.length() == 0 {
    None
  } else {
    Some(segments.join("::"))
  }
}

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
