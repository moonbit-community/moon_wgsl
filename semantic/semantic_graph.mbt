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
pub(all) struct WgslSemanticReferencePath {
  text : String
  segments : Array[String]
} derive(Eq, Debug)

///|
pub(all) struct WgslSemanticAliasBinding {
  alias_name : String
  module_path : String
  rel_path : String
} derive(Eq, Debug)

///|
pub(all) struct WgslSemanticResolvedReference {
  reference_path : String
  alias_name : String
  module_path : String
  rel_path : String
  item_path : String
  is_alias_reference : Bool
} derive(Eq, Debug)

///|
pub(all) struct WgslSemanticImportGraph {
  references : Array[WgslSemanticReferencePath]
  aliases : Array[WgslSemanticAliasBinding]
  resolved_references : Array[WgslSemanticResolvedReference]
  targets : Array[WgslImportTarget]
} derive(Eq, Debug)

///|
fn semantic_string_list_push_unique(
  items : Array[String],
  item : String,
) -> Unit {
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
fn semantic_import_targets_push_unique(
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
pub fn wgsl_semantic_path_segments(path : String) -> Array[String] {
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
pub fn wgsl_semantic_reference_path_from_identifier(
  name : String,
) -> WgslSemanticReferencePath? {
  let segments = wgsl_semantic_path_segments(name)
  if segments.length() == 0 {
    None
  } else {
    Some(WgslSemanticReferencePath::{ text: segments.join("::"), segments })
  }
}

///|
pub fn collect_wgsl_semantic_reference_paths(
  source : String,
  paths : Array[WgslSemanticReferencePath],
) -> Unit raise WgslParseError {
  let nodes : Array[WgslIdent] = []
  for decl in parse_wgsl_translation_unit_strict(source).declarations {
    collect_wgsl_decl_identifier_nodes(decl.data, nodes)
  }
  for node in nodes {
    match wgsl_semantic_reference_path_from_identifier(node.name) {
      Some(path) => paths.push(path)
      None => ()
    }
  }
}

///|
pub fn wgsl_semantic_requested_item_name(
  raw_path : String,
  module_path : String,
) -> String {
  let raw_segments = wgsl_semantic_path_segments(raw_path)
  let module_segments = wgsl_semantic_path_segments(module_path)
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
pub fn split_last_wgsl_semantic_path(path : String) -> (String, String)? {
  let segments = wgsl_semantic_path_segments(path)
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
pub fn wgsl_semantic_alias_requested_item_name(
  reference_path : WgslSemanticReferencePath,
  alias_name : String,
) -> String {
  let alias_segments = wgsl_semantic_path_segments(alias_name)
  if alias_segments.length() == 0 ||
    reference_path.segments.length() <= alias_segments.length() {
    return ""
  }
  for i in 0..<alias_segments.length() {
    if reference_path.segments[i] != alias_segments[i] {
      return ""
    }
  }
  let suffix : Array[String] = []
  for i in alias_segments.length()..<reference_path.segments.length() {
    suffix.push(reference_path.segments[i])
  }
  suffix.join("::")
}

///|
pub fn collect_wgsl_semantic_alias_requested_paths(
  source : String,
  alias_name : String,
  requested_paths : Array[String],
) -> Unit raise WgslParseError {
  if alias_name == "" {
    return
  }
  let paths : Array[WgslSemanticReferencePath] = []
  collect_wgsl_semantic_reference_paths(source, paths)
  for path in paths {
    let requested_item = wgsl_semantic_alias_requested_item_name(
      path, alias_name,
    )
    semantic_string_list_push_unique(requested_paths, requested_item)
  }
}

///|
pub fn wgsl_semantic_source_uses_alias(
  source : String,
  alias_name : String,
) -> Bool raise WgslParseError {
  let requested_paths : Array[String] = []
  collect_wgsl_semantic_alias_requested_paths(
    source, alias_name, requested_paths,
  )
  requested_paths.length() > 0
}

///|
pub fn wgsl_semantic_source_contains_reference_path(
  source : String,
  reference_path : String,
) -> Bool raise WgslParseError {
  match wgsl_semantic_reference_path_from_identifier(reference_path) {
    Some(expected) => {
      let paths : Array[WgslSemanticReferencePath] = []
      collect_wgsl_semantic_reference_paths(source, paths)
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
pub fn unresolved_wgsl_semantic_namespace_reference(
  source : String,
) -> String? raise WgslParseError {
  let paths : Array[WgslSemanticReferencePath] = []
  collect_wgsl_semantic_reference_paths(source, paths)
  for path in paths {
    if path.segments.length() > 1 {
      return Some(path.text)
    }
  }
  None
}

///|
pub fn resolve_wgsl_semantic_import_module(
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
pub fn collect_wgsl_semantic_qualified_module_targets(
  source : String,
  current_rel_path : String,
  registry : WgslSourceRegistry,
  modules : @hashmap.HashMap[String, String],
  targets : Array[WgslImportTarget],
) -> Unit raise WgslParseError {
  let paths : Array[WgslSemanticReferencePath] = []
  collect_wgsl_semantic_reference_paths(source, paths)
  for path in paths {
    if path.segments.length() < 3 {
      continue
    }
    guard resolve_wgsl_semantic_import_module(
        current_rel_path,
        path.text,
        registry,
        modules,
      )
      is Some(resolved_module) else {
      continue
    }
    let requested_item = wgsl_semantic_requested_item_name(
      path.text,
      resolved_module.module_path,
    )
    if requested_item == "" {
      continue
    }
    semantic_import_targets_push_unique(targets, WgslImportTarget::{
      raw_path: resolved_module.module_path,
      alias_name: resolved_module.module_path,
    })
  }
}

///|
pub fn build_wgsl_semantic_import_rename_map(
  source : String,
  alias_name : String,
) -> @hashmap.HashMap[String, String] raise WgslParseError {
  let rename_map : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
  let alias_prefix = parse_wgsl_import_alias_prefix(alias_name)
  for declaration in collect_wgsl_named_declarations_strict(source) {
    rename_map.set(declaration.name, "\{alias_prefix}__\{declaration.name}")
  }
  rename_map
}

///|
pub fn collect_wgsl_semantic_import_alias_redirects(
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
pub fn build_wgsl_semantic_import_graph(
  source : String,
  current_rel_path : String,
  registry : WgslSourceRegistry,
  modules : @hashmap.HashMap[String, String],
  aliases : Array[WgslSemanticAliasBinding],
) -> WgslSemanticImportGraph raise WgslParseError {
  let references : Array[WgslSemanticReferencePath] = []
  let resolved_references : Array[WgslSemanticResolvedReference] = []
  let targets : Array[WgslImportTarget] = []
  collect_wgsl_semantic_reference_paths(source, references)
  collect_wgsl_semantic_qualified_module_targets(
    source, current_rel_path, registry, modules, targets,
  )
  for reference in references {
    for binding in aliases {
      let requested_item = wgsl_semantic_alias_requested_item_name(
        reference,
        binding.alias_name,
      )
      if requested_item != "" {
        resolved_references.push(WgslSemanticResolvedReference::{
          reference_path: reference.text,
          alias_name: binding.alias_name,
          module_path: binding.module_path,
          rel_path: binding.rel_path,
          item_path: requested_item,
          is_alias_reference: true,
        })
      }
    }
    guard resolve_wgsl_semantic_import_module(
        current_rel_path,
        reference.text,
        registry,
        modules,
      )
      is Some(resolved_module) else {
      continue
    }
    let requested_item = wgsl_semantic_requested_item_name(
      reference.text,
      resolved_module.module_path,
    )
    if requested_item != "" {
      resolved_references.push(WgslSemanticResolvedReference::{
        reference_path: reference.text,
        alias_name: resolved_module.module_path,
        module_path: resolved_module.module_path,
        rel_path: resolved_module.rel_path,
        item_path: requested_item,
        is_alias_reference: false,
      })
    }
  }
  WgslSemanticImportGraph::{ references, aliases, resolved_references, targets }
}
