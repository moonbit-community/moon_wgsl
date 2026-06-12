// Copyright 2026 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
pub fn collect_wgsl_import_targets(
  spec : String,
  prefix : String,
  targets : Array[WgslImportTarget],
) -> Unit {
  parse_wgsl_import_targets(trim_trailing_semicolons(spec), prefix, targets) catch {
    _ => ()
  }
}

///|
pub fn normalize_shader_rel_path(rel : String) -> String {
  let mut text = rel.trim().to_owned()
  let n = text.length()
  let mut i = 0
  while i < n && text.code_unit_at(i).to_int() == 47 { // '/'
    i = i + 1
  }
  if i != 0 {
    text = text[i:n].to_owned()
  }
  while text.has_prefix("./") {
    text = text[2:text.length()].to_owned()
  }
  if text.has_prefix("assets/") {
    text = text[7:text.length()].to_owned()
  }
  let normalized_segments : Array[String] = []
  for raw_segment in text.split("/") {
    let segment = raw_segment.to_owned().trim().to_owned()
    if segment == "" || segment == "." {
      continue
    }
    if segment == ".." {
      if normalized_segments.length() > 0 {
        normalized_segments.pop() |> ignore
      }
      continue
    }
    normalized_segments.push(segment)
  }
  normalized_segments.join("/")
}

///|
fn shader_parent_rel_path(rel_path : String) -> String {
  let normalized = normalize_shader_rel_path(rel_path)
  if normalized == "" {
    return ""
  }
  let segments : Array[String] = []
  for raw_segment in normalized.split("/") {
    let segment = raw_segment.to_owned()
    if segment != "" {
      segments.push(segment)
    }
  }
  if segments.length() == 0 {
    return ""
  }
  segments.pop() |> ignore
  segments.join("/")
}

///|
fn unquote_wgsl_import_path(import_path : String) -> String? {
  let trimmed = import_path.trim().to_owned()
  if trimmed.length() >= 2 &&
    trimmed.code_unit_at(0).to_int() == 34 &&
    trimmed.code_unit_at(trimmed.length() - 1).to_int() == 34 {
    return Some(trimmed[1:trimmed.length() - 1].to_owned())
  }
  None
}

///|
fn wgsl_import_looks_like_file_path(import_path : String) -> Bool {
  if unquote_wgsl_import_path(import_path) is Some(_) {
    return true
  }
  let trimmed = import_path.trim().to_owned()
  if trimmed == "" {
    return false
  }
  trimmed.contains("/") ||
  trimmed.has_suffix(".wgsl") ||
  trimmed.has_prefix("./") ||
  trimmed.has_prefix("../")
}

///|
pub fn resolve_wgsl_import_file_path_from_registry(
  registry : WgslSourceRegistry,
  importer_rel_path : String,
  import_path : String,
) -> String? {
  guard wgsl_import_looks_like_file_path(import_path) else { return None }
  let raw_path = match unquote_wgsl_import_path(import_path) {
    Some(path) => path
    None => import_path.trim().to_owned()
  }
  let normalized = if raw_path.has_prefix("./") || raw_path.has_prefix("../") {
    let parent = shader_parent_rel_path(importer_rel_path)
    if parent == "" {
      normalize_shader_rel_path(raw_path)
    } else {
      normalize_shader_rel_path("\{parent}/\{raw_path}")
    }
  } else {
    normalize_shader_rel_path(raw_path)
  }
  if normalized == "" {
    return None
  }
  if registry.registered_source(normalized) is Some(_) {
    return Some(normalized)
  }
  None
}

///|
