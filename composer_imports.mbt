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
priv struct WgslImportRequest {
  module_path : String
  rel_path : String
  mut import_full_module : Bool
  requested_items : Array[String]
  alias_name : String
}

///|
fn unresolved_wgsl_namespace_reference(source : String) -> String? {
  let cleaned = replace_comments(source)
  let mut i = 0
  while i + 1 < cleaned.length() {
    if cleaned.code_unit_at(i).to_int() == 58 &&
      cleaned.code_unit_at(i + 1).to_int() == 58 {
      let mut start = i
      while start > 0 {
        let cu = cleaned.code_unit_at(start - 1).to_int()
        if !wgsl_identifier_char(cu) && cu != 58 {
          break
        }
        start = start - 1
      }
      let mut end = i + 2
      while end < cleaned.length() {
        let cu = cleaned.code_unit_at(end).to_int()
        if !wgsl_identifier_char(cu) && cu != 58 {
          break
        }
        end = end + 1
      }
      let path = cleaned[start:end].to_string().trim().to_string()
      if path != "" && path != "::" {
        return Some(path)
      }
    }
    i = i + 1
  }
  None
}

///|
fn wgsl_import_default_alias(module_path : String) -> String {
  let mut alias_name = ""
  for seg in module_path.split("::") {
    let text = seg.to_string().trim().to_string()
    if text != "" {
      alias_name = text
    }
  }
  alias_name
}

///|
fn wgsl_import_alias_prefix(alias_name : String) -> String {
  let mut prefix = ""
  for i in 0..<alias_name.length() {
    let code = alias_name.code_unit_at(i).to_int()
    if wgsl_identifier_char(code) {
      prefix = prefix + alias_name[i:i + 1].to_string()
    } else if !prefix.has_suffix("_") {
      prefix = prefix + "_"
    }
  }
  if prefix == "" {
    "import"
  } else {
    prefix
  }
}

///|
fn wgsl_import_requested_item_name(
  raw_path : String,
  module_path : String,
) -> String {
  let prefix = "\{module_path}::"
  if !starts_with_text(raw_path, prefix) {
    return ""
  }
  raw_path[prefix.length():raw_path.length()].to_string().trim().to_string()
}

///|
fn collect_wgsl_alias_requested_paths(
  source : String,
  alias_name : String,
  requested_paths : Array[String],
) -> Unit {
  let pattern = "\{alias_name}::"
  let mut search_from = 0
  while search_from + pattern.length() <= source.length() {
    let window = source[search_from:source.length()].to_string()
    let guard_pattern = window.contains(pattern)
    if !guard_pattern {
      break
    }
    let mut match_index = -1
    let limit = source.length() - pattern.length()
    for i in search_from..<=limit {
      if source[i:i + pattern.length()].to_string() == pattern {
        match_index = i
        break
      }
    }
    if match_index < 0 {
      break
    }
    let start = match_index + pattern.length()
    let mut end = start
    while end < source.length() &&
          (
            wgsl_identifier_char(source.code_unit_at(end).to_int()) ||
            (
              source.code_unit_at(end).to_int() == 58 &&
              end + 1 < source.length() &&
              source.code_unit_at(end + 1).to_int() == 58
            )
          ) {
      if source.code_unit_at(end).to_int() == 58 {
        end = end + 2
        continue
      }
      end = end + 1
    }
    if end > start {
      let item_path = source[start:end].to_string()
      wgsl_string_list_push_unique(requested_paths, item_path)
      search_from = end
    } else {
      search_from = start
    }
  }
}

///|
fn wgsl_path_separator_count(path : String) -> Int {
  let mut count = 0
  let mut i = 0
  while i + 1 < path.length() {
    if path.code_unit_at(i).to_int() == 58 &&
      path.code_unit_at(i + 1).to_int() == 58 {
      count = count + 1
      i = i + 2
      continue
    }
    i = i + 1
  }
  count
}

///|
fn split_last_wgsl_path(path : String) -> (String, String)? {
  let mut i = path.length() - 1
  while i > 0 {
    if path.code_unit_at(i - 1).to_int() == 58 &&
      path.code_unit_at(i).to_int() == 58 {
      let prefix = path[:i - 1].to_string().trim().to_string()
      let suffix = path[i + 1:path.length()].to_string().trim().to_string()
      if prefix != "" && suffix != "" {
        return Some((prefix, suffix))
      }
      return None
    }
    i = i - 1
  }
  None
}

///|
fn wgsl_import_targets_push_unique(
  targets : Array[WgslImportTarget],
  target : WgslImportTarget,
) -> Unit {
  for existing in targets {
    if existing.raw_path == target.raw_path &&
      existing.alias_name == target.alias_name {
      return
    }
  }
  targets.push(target)
}

///|
fn collect_wgsl_qualified_module_targets(
  source : String,
  current_rel_path : String,
  registry : WgslSourceRegistry,
  modules : @hashmap.HashMap[String, String],
  targets : Array[WgslImportTarget],
) -> Unit {
  let cleaned = replace_comments(source)
  for token in tokenize(cleaned, false) {
    match token {
      Token::Identifier(ident, _) => {
        if wgsl_path_separator_count(ident) < 2 {
          continue
        }
        guard resolve_wgsl_import_request_module(
            current_rel_path, ident, registry, modules,
          )
          is Some(resolved_module) else {
          continue
        }
        let requested_item = wgsl_import_requested_item_name(
          ident,
          resolved_module.module_path,
        )
        if requested_item == "" {
          continue
        }
        wgsl_import_targets_push_unique(targets, WgslImportTarget::{
          raw_path: resolved_module.module_path,
          alias_name: resolved_module.module_path,
        })
      }
      _ => ()
    }
  }
}

///|
fn build_wgsl_import_rename_map(
  source : String,
  alias_name : String,
) -> @hashmap.HashMap[String, String] {
  let rename_map : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
  let alias_prefix = wgsl_import_alias_prefix(alias_name)
  let graph = build_wgsl_declaration_graph(source)
  for block in graph.declaration_blocks {
    if block.name == "" {
      continue
    }
    rename_map.set(block.name, "\{alias_prefix}__\{block.name}")
  }
  rename_map
}

///|
fn collect_wgsl_import_alias_redirects(
  alias_name : String,
  rename_map : @hashmap.HashMap[String, String],
  redirects : Array[WgslSymbolRedirect],
) -> Unit {
  for entry in rename_map.iter() {
    let (from_name, to_name) = entry
    redirects.push(WgslSymbolRedirect::{
      from_name: "\{alias_name}::\{from_name}",
      to_name,
    })
  }
}

///|
fn wgsl_source_contains_identifier(
  source : String,
  identifier : String,
) -> Bool {
  if identifier == "" || identifier.length() > source.length() {
    return false
  }
  let limit = source.length() - identifier.length()
  for i in 0..<=limit {
    if source[i:i + identifier.length()].to_string() != identifier {
      continue
    }
    let left_ok = i == 0 ||
      !wgsl_identifier_char(source.code_unit_at(i - 1).to_int())
    let right_index = i + identifier.length()
    let right_ok = right_index >= source.length() ||
      !wgsl_identifier_char(source.code_unit_at(right_index).to_int())
    if left_ok && right_ok {
      return true
    }
  }
  false
}

///|
fn find_wgsl_import_request_index(
  requests : Array[WgslImportRequest],
  module_path : String,
  rel_path : String,
  alias_name : String,
) -> Int? {
  for i in 0..<requests.length() {
    let request = requests[i]
    if request.module_path == module_path &&
      request.rel_path == rel_path &&
      request.alias_name == alias_name {
      return Some(i)
    }
  }
  None
}

///|
fn wgsl_import_request_visit_key(
  importer_rel_path : String,
  request : WgslImportRequest,
) -> String {
  let mut key = "\{importer_rel_path}=>\{request.rel_path}|\{request.alias_name}"
  if request.import_full_module {
    key = "\{key}|*"
  } else {
    let sorted_items : Array[String] = []
    for item in request.requested_items {
      sorted_items.push(item)
    }
    sorted_items.sort()
    for item in sorted_items {
      key = "\{key}|\{item}"
    }
  }
  key
}

///|
fn resolve_wgsl_import_request_module(
  importer_rel_path : String,
  import_path : String,
  registry : WgslSourceRegistry,
  modules : @hashmap.HashMap[String, String],
) -> WgslResolvedImportModule? {
  if resolve_wgsl_import_file_path_from_registry(
      registry, importer_rel_path, import_path,
    )
    is Some(rel_path) {
    let module_path = match registry.registered_source(rel_path) {
      Some(source) =>
        match get_preprocessor_metadata(source).name {
          Some(name) if name.trim() != "" => name.trim().to_string()
          _ => import_path
        }
      None => import_path
    }
    return Some(WgslResolvedImportModule::{ module_path, rel_path })
  }
  if split_last_identifier(import_path) is Some((module_path, _)) {
    if resolve_wgsl_import_file_path_from_registry(
        registry, importer_rel_path, module_path,
      )
      is Some(rel_path) {
      return Some(WgslResolvedImportModule::{ module_path, rel_path })
    }
  }
  resolve_wgsl_import_module_in_registry(registry, import_path, modules)
}

///|
fn wgsl_visit_has_rel_prefix(
  visited : @hashmap.HashMap[String, Bool],
  rel_path : String,
) -> Bool {
  let prefix = "\{rel_path}|"
  for entry in visited.iter() {
    let (key, _) = entry
    if starts_with_text(key, prefix) {
      return true
    }
  }
  false
}

///|
fn wgsl_path_stack_contains(paths : Array[String], rel_path : String) -> Bool {
  for existing_path in paths {
    if existing_path == rel_path {
      return true
    }
  }
  false
}

///|
fn wgsl_import_cycle_string(
  active_rel_paths : Array[String],
  repeated_rel_path : String,
) -> String {
  let cycle_paths : Array[String] = []
  let mut found_cycle_start = false
  for rel_path in active_rel_paths {
    if rel_path == repeated_rel_path {
      found_cycle_start = true
    }
    if found_cycle_start {
      cycle_paths.push(rel_path)
    }
  }
  cycle_paths.push(repeated_rel_path)
  cycle_paths.join(" -> ")
}
