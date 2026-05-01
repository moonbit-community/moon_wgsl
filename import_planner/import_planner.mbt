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
pub(all) struct WgslImportRequest {
  module_path : String
  rel_path : String
  mut import_full_module : Bool
  mut keep_requested_items : Bool
  requested_items : Array[String]
  alias_name : String
}

///|
priv struct WgslReferencePath {
  text : String
  segments : Array[String]
}

///|
fn string_list_push_unique(items : Array[String], item : String) -> Unit {
  if item == "" {
    return
  }
  for existing in items {
    if existing == item {
      return
    }
  }
  items.push(item)
}

///|
fn wgsl_path_segments(path : String) -> Array[String] {
  let segments : Array[String] = []
  for raw_segment in path.trim().split("::") {
    let segment = raw_segment.trim().to_owned()
    if segment != "" {
      segments.push(segment)
    }
  }
  segments
}

///|
fn wgsl_reference_path_from_identifier(name : String) -> WgslReferencePath? {
  let segments = wgsl_path_segments(name)
  if segments.length() == 0 {
    None
  } else {
    Some(WgslReferencePath::{ text: segments.join("::"), segments })
  }
}

///|
fn collect_wgsl_source_reference_paths(
  source : String,
  paths : Array[WgslReferencePath],
) -> Unit {
  let nodes : Array[WgslIdent] = []
  for decl in parse_wgsl_translation_unit(source).declarations {
    collect_wgsl_decl_identifier_nodes(decl.data, nodes)
  }
  for node in nodes {
    match wgsl_reference_path_from_identifier(node.name) {
      Some(path) => paths.push(path)
      None => ()
    }
  }
}

///|
pub fn unresolved_wgsl_namespace_reference(source : String) -> String? {
  let paths : Array[WgslReferencePath] = []
  collect_wgsl_source_reference_paths(source, paths)
  for path in paths {
    if path.segments.length() > 1 {
      return Some(path.text)
    }
  }
  None
}

///|
pub fn wgsl_source_contains_reference_path(
  source : String,
  reference_path : String,
) -> Bool {
  match wgsl_reference_path_from_identifier(reference_path) {
    Some(expected) => {
      let paths : Array[WgslReferencePath] = []
      collect_wgsl_source_reference_paths(source, paths)
      for path in paths {
        if path.text == expected.text {
          return true
        }
      }
      false
    }
    None => false
  }
}

///|
pub fn wgsl_import_default_alias(module_path : String) -> String {
  match split_last_identifier(module_path.trim().to_owned()) {
    Some((_, suffix)) => suffix.trim().to_owned()
    None => module_path.trim().to_owned()
  }
}

///|
pub fn wgsl_import_requested_item_name(
  raw_path : String,
  module_path : String,
) -> String {
  let raw_segments = wgsl_path_segments(raw_path)
  let module_segments = wgsl_path_segments(module_path)
  if raw_segments.length() <= module_segments.length() {
    return ""
  }
  for i in 0..<module_segments.length() {
    if raw_segments[i] != module_segments[i] {
      return ""
    }
  }
  let suffix : Array[String] = []
  for i in module_segments.length()..<raw_segments.length() {
    suffix.push(raw_segments[i])
  }
  suffix.join("::")
}

///|
pub fn collect_wgsl_alias_requested_paths(
  source : String,
  alias_name : String,
  requested_paths : Array[String],
) -> Unit {
  if alias_name == "" {
    return
  }
  let paths : Array[WgslReferencePath] = []
  collect_wgsl_source_reference_paths(source, paths)
  for path in paths {
    let requested_item = wgsl_import_requested_item_name(path.text, alias_name)
    if requested_item != "" {
      string_list_push_unique(requested_paths, requested_item)
    }
  }
}

///|
pub fn wgsl_source_uses_import_alias(
  source : String,
  alias_name : String,
) -> Bool {
  let requested_paths : Array[String] = []
  collect_wgsl_alias_requested_paths(source, alias_name, requested_paths)
  requested_paths.length() > 0
}

///|
pub fn split_last_wgsl_path(path : String) -> (String, String)? {
  let segments = wgsl_path_segments(path)
  if segments.length() < 2 {
    return None
  }
  let prefix : Array[String] = []
  for i in 0..<(segments.length() - 1) {
    prefix.push(segments[i])
  }
  Some((prefix.join("::"), segments[segments.length() - 1]))
}

///|
pub fn wgsl_import_targets_push_unique(
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
pub fn collect_wgsl_qualified_module_targets(
  source : String,
  current_rel_path : String,
  registry : WgslSourceRegistry,
  modules : @hashmap.HashMap[String, String],
  targets : Array[WgslImportTarget],
) -> Unit {
  let paths : Array[WgslReferencePath] = []
  collect_wgsl_source_reference_paths(source, paths)
  for ident in paths {
    if ident.segments.length() < 3 {
      continue
    }
    guard resolve_wgsl_import_request_module(
        current_rel_path,
        ident.text,
        registry,
        modules,
      )
      is Some(resolved_module) else {
      continue
    }
    let requested_item = wgsl_import_requested_item_name(
      ident.text,
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
}

///|
pub fn build_wgsl_import_rename_map(
  source : String,
  alias_name : String,
) -> @hashmap.HashMap[String, String] {
  let rename_map : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
  let alias_prefix = parse_wgsl_import_alias_prefix(alias_name)
  for declaration in collect_wgsl_named_declarations(source) {
    rename_map.set(declaration.name, "\{alias_prefix}__\{declaration.name}")
  }
  rename_map
}

///|
pub fn collect_wgsl_import_alias_redirects(
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
pub fn find_wgsl_import_request_index(
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
pub fn wgsl_import_request_visit_key(
  importer_rel_path : String,
  request : WgslImportRequest,
) -> String {
  let mut key = "\{importer_rel_path}=>\{request.rel_path}|\{request.alias_name}"
  if request.import_full_module {
    key = "\{key}|*"
  } else {
    if request.keep_requested_items {
      key = "\{key}|explicit"
    }
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
pub fn wgsl_full_module_visit_key(
  rel_path : String,
  alias_name : String,
) -> String {
  "\{rel_path}|\{alias_name}|*"
}

///|
pub fn wgsl_imported_item_name_key(
  rel_path : String,
  alias_name : String,
  item_name : String,
) -> String {
  "\{rel_path}|\{alias_name}|\{item_name}"
}

///|
pub fn resolve_wgsl_import_request_module(
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
        match wgsl_source_define_import_path(source) {
          Some(name) if name.trim() != "" => name.trim().to_owned()
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
pub fn wgsl_path_stack_contains(
  paths : Array[String],
  rel_path : String,
) -> Bool {
  paths.contains(rel_path)
}

///|
pub fn wgsl_import_cycle_string(
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

///|
