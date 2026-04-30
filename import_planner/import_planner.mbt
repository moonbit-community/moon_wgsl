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
fn collect_wgsl_source_identifier_names(
  source : String,
  names : Array[String],
) -> Unit {
  let nodes : Array[WgslIdent] = []
  for decl in parse_wgsl_translation_unit(source).declarations {
    collect_wgsl_decl_identifier_nodes(decl.data, nodes)
  }
  for node in nodes {
    names.push(node.name)
  }
}

///|
pub fn unresolved_wgsl_namespace_reference(source : String) -> String? {
  let names : Array[String] = []
  collect_wgsl_source_identifier_names(source, names)
  for name in names {
    if split_last_identifier(name) is Some(_) {
      return Some(name)
    }
  }
  None
}

///|
pub fn wgsl_source_contains_identifier(
  source : String,
  identifier : String,
) -> Bool {
  if identifier == "" {
    return false
  }
  let names : Array[String] = []
  collect_wgsl_source_identifier_names(source, names)
  for path in names {
    if path == identifier {
      return true
    }
    match split_last_wgsl_path(path) {
      Some((_, suffix)) => if suffix == identifier { return true }
      None => ()
    }
  }
  false
}

///|
pub fn wgsl_import_default_alias(module_path : String) -> String {
  match split_last_identifier(module_path.trim().to_owned()) {
    Some((_, suffix)) => suffix.trim().to_owned()
    None => module_path.trim().to_owned()
  }
}

///|
fn wgsl_import_alias_prefix_separator(prefix : String) -> String {
  if prefix == "" || prefix.has_suffix("_") {
    prefix
  } else {
    "\{prefix}_"
  }
}

///|
fn wgsl_import_alias_prefix(alias_name : String) -> String {
  let mut prefix = ""
  let segments : Array[String] = []
  for segment in alias_name.trim().split("::") {
    segments.push(segment.to_owned())
  }
  for i in 0..<segments.length() {
    if i > 0 {
      prefix = wgsl_import_alias_prefix_separator(prefix)
    }
    for token in tokenize(segments[i], true) {
      match token {
        Token::Identifier(text, _) if !text.contains("\"") =>
          prefix = "\{prefix}\{text}"
        _ => prefix = wgsl_import_alias_prefix_separator(prefix)
      }
    }
  }
  if prefix == "" {
    "import"
  } else {
    prefix
  }
}

///|
pub fn wgsl_import_requested_item_name(
  raw_path : String,
  module_path : String,
) -> String {
  let prefix = "\{module_path}::"
  if !raw_path.has_prefix(prefix) {
    return ""
  }
  raw_path[prefix.length():raw_path.length()].to_owned().trim().to_owned()
}

///|
pub fn collect_wgsl_alias_requested_paths(
  source : String,
  alias_name : String,
  requested_paths : Array[String],
) -> Unit {
  let names : Array[String] = []
  collect_wgsl_source_identifier_names(source, names)
  for path in names {
    let requested_item = wgsl_import_requested_item_name(path, alias_name)
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
fn wgsl_path_separator_count(path : String) -> Int {
  let mut count = 0
  let mut rest = path
  while split_last_identifier(rest) is Some((prefix, _)) {
    count = count + 1
    rest = prefix
  }
  count
}

///|
pub fn split_last_wgsl_path(path : String) -> (String, String)? {
  match split_last_identifier(path) {
    Some((prefix, suffix)) => {
      let trimmed_prefix = prefix.trim().to_owned()
      let trimmed_suffix = suffix.trim().to_owned()
      if trimmed_prefix != "" && trimmed_suffix != "" {
        Some((trimmed_prefix, trimmed_suffix))
      } else {
        None
      }
    }
    None => None
  }
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
  let names : Array[String] = []
  collect_wgsl_source_identifier_names(source, names)
  for ident in names {
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
}

///|
pub fn build_wgsl_import_rename_map(
  source : String,
  alias_name : String,
) -> @hashmap.HashMap[String, String] {
  let rename_map : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
  let alias_prefix = wgsl_import_alias_prefix(alias_name)
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
  item_name : String,
) -> String {
  "\{rel_path}|\{item_name}"
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
        match get_preprocessor_metadata(source).name {
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
