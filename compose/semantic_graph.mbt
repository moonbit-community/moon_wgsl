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
priv struct WgslSemanticReferencePath {
  text : String
  segments : Array[String]
}

///|
priv struct WgslSemanticImportTargetPlan {
  resolved_module : WgslResolvedImportModule
  module_alias : String
  requested_items : Array[String]
  import_full_module : Bool
  keep_requested_items : Bool
  explicit_item_binding : Bool
  default_module_alias_candidate : Bool
  alias_is_used : Bool
}

///|
priv struct WgslSemanticImportTargetPlans {
  plans : Array[WgslSemanticImportTargetPlan]
  unresolved_targets : Array[String]
}

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
fn wgsl_semantic_path_segments(path : String) -> Array[String] {
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
fn wgsl_semantic_reference_path_from_identifier(
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
fn collect_wgsl_semantic_reference_paths(
  source : String,
  paths : Array[WgslSemanticReferencePath],
) -> Unit raise WgslParseError {
  let nodes : Array[WgslIdent] = []
  for decl in parse_wgsl_translation_unit_strict(source).declarations() {
    collect_wgsl_decl_identifier_nodes(decl.data(), nodes)
  }
  for node in nodes {
    match wgsl_semantic_reference_path_from_identifier(node.name) {
      Some(path) => paths.push(path)
      None => ()
    }
  }
}

///|
fn wgsl_semantic_requested_item_name(
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
fn split_last_wgsl_semantic_path(path : String) -> (String, String)? {
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
fn wgsl_semantic_import_default_alias(module_path : String) -> String {
  match split_last_identifier(module_path.trim().to_owned()) {
    Some((_, suffix)) => suffix.trim().to_owned()
    None => module_path.trim().to_owned()
  }
}

///|
fn wgsl_semantic_alias_requested_item_name(
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
fn collect_wgsl_semantic_alias_requested_paths(
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
fn wgsl_semantic_source_uses_alias(
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
fn wgsl_semantic_source_contains_reference_path(
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
fn unresolved_wgsl_semantic_namespace_reference(
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
fn resolve_wgsl_semantic_import_module(
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
    return Some(WgslResolvedImportModule::new(module_path, rel_path))
  }
  if split_last_identifier(import_path) is Some((module_path, _)) {
    if resolve_wgsl_import_file_path_from_registry(
        registry, importer_rel_path, module_path,
      )
      is Some(rel_path) {
      return Some(WgslResolvedImportModule::new(module_path, rel_path))
    }
  }
  resolve_wgsl_import_module_in_registry(registry, import_path, modules)
}

///|
fn collect_wgsl_semantic_qualified_module_targets(
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
      resolved_module.module_path(),
    )
    if requested_item == "" {
      continue
    }
    semantic_import_targets_push_unique(targets, WgslImportTarget::{
      raw_path: resolved_module.module_path(),
      alias_name: resolved_module.module_path(),
    })
  }
}

///|
fn wgsl_semantic_collect_alias_plan_items(
  source : String,
  target : WgslImportTarget,
  pending_targets : Array[WgslImportTarget],
  requested_items : Array[String],
) -> Bool raise WgslParseError {
  let requested_paths : Array[String] = []
  collect_wgsl_semantic_alias_requested_paths(
    source,
    target.alias_name,
    requested_paths,
  )
  for requested_path in requested_paths {
    if split_last_wgsl_semantic_path(requested_path) is Some((nested_prefix, _)) {
      semantic_import_targets_push_unique(pending_targets, WgslImportTarget::{
        raw_path: "\{target.raw_path}::\{nested_prefix}",
        alias_name: "\{target.alias_name}::\{nested_prefix}",
      })
    } else {
      semantic_string_list_push_unique(requested_items, requested_path)
    }
  }
  requested_items.length() > 0
}

///|
fn wgsl_semantic_collect_default_alias_plan_items(
  source : String,
  request_module_prefix : String,
  module_alias : String,
  pending_targets : Array[WgslImportTarget],
  requested_items : Array[String],
) -> Bool raise WgslParseError {
  let requested_paths : Array[String] = []
  collect_wgsl_semantic_alias_requested_paths(
    source, module_alias, requested_paths,
  )
  for requested_path in requested_paths {
    if split_last_wgsl_semantic_path(requested_path) is Some((nested_prefix, _)) {
      semantic_import_targets_push_unique(pending_targets, WgslImportTarget::{
        raw_path: "\{request_module_prefix}::\{nested_prefix}",
        alias_name: "\{module_alias}::\{nested_prefix}",
      })
    } else {
      semantic_string_list_push_unique(requested_items, requested_path)
    }
  }
  requested_items.length() > 0
}

///|
fn unresolved_wgsl_semantic_import_target_plan() -> WgslSemanticImportTargetPlan {
  WgslSemanticImportTargetPlan::{
    resolved_module: WgslResolvedImportModule::new("", ""),
    module_alias: "",
    requested_items: [],
    import_full_module: false,
    keep_requested_items: false,
    explicit_item_binding: false,
    default_module_alias_candidate: false,
    alias_is_used: false,
  }
}

///|
fn build_wgsl_semantic_import_target_plan(
  source : String,
  current_rel_path : String,
  target : WgslImportTarget,
  registry : WgslSourceRegistry,
  modules : @hashmap.HashMap[String, String],
  pending_targets : Array[WgslImportTarget],
) -> WgslSemanticImportTargetPlan? raise WgslParseError {
  let requested_items : Array[String] = []
  let resolved_module_opt = resolve_wgsl_semantic_import_module(
    current_rel_path,
    target.raw_path,
    registry,
    modules,
  )
  if target.alias_name != "" && resolved_module_opt is None {
    let mut alias_parse_failed = false
    ignore(
      wgsl_semantic_collect_alias_plan_items(
        source, target, pending_targets, requested_items,
      ),
    ) catch {
      _ => alias_parse_failed = true
    }
    if alias_parse_failed || requested_items.length() > 0 {
      return Some(unresolved_wgsl_semantic_import_target_plan())
    }
    return None
  }
  if target.alias_name != "" &&
    !wgsl_semantic_collect_alias_plan_items(
      source, target, pending_targets, requested_items,
    ) {
    return None
  }
  guard resolved_module_opt is Some(resolved_module) else {
    return Some(unresolved_wgsl_semantic_import_target_plan())
  }
  let request_module_prefix = if target.alias_name == "" {
    resolved_module.module_path()
  } else {
    target.raw_path
  }
  let module_alias = if target.alias_name != "" {
    target.alias_name
  } else if resolved_module.module_path() == target.raw_path {
    wgsl_semantic_import_default_alias(resolved_module.module_path())
  } else {
    ""
  }
  let mut import_full_module = resolved_module.module_path() == target.raw_path
  let mut keep_requested_items = false
  let mut explicit_item_binding = false
  let mut default_module_alias_candidate = false
  let mut alias_is_used = false
  if target.alias_name != "" {
    alias_is_used = true
  } else if module_alias != "" {
    default_module_alias_candidate = true
    alias_is_used = wgsl_semantic_source_uses_alias(source, module_alias)
    if alias_is_used {
      ignore(
        wgsl_semantic_collect_default_alias_plan_items(
          source, request_module_prefix, module_alias, pending_targets, requested_items,
        ),
      )
    }
  } else if resolved_module.module_path() != target.raw_path {
    import_full_module = false
    keep_requested_items = true
    explicit_item_binding = true
    let requested_item = wgsl_semantic_requested_item_name(
      target.raw_path,
      resolved_module.module_path(),
    )
    if requested_item == "" {
      import_full_module = true
    } else {
      requested_items.push(requested_item)
    }
  }
  Some(WgslSemanticImportTargetPlan::{
    resolved_module,
    module_alias,
    requested_items,
    import_full_module,
    keep_requested_items,
    explicit_item_binding,
    default_module_alias_candidate,
    alias_is_used,
  })
}

///|
fn build_wgsl_semantic_import_target_plans(
  source : String,
  current_rel_path : String,
  initial_targets : Array[WgslImportTarget],
  registry : WgslSourceRegistry,
  modules : @hashmap.HashMap[String, String],
) -> WgslSemanticImportTargetPlans raise WgslParseError {
  let pending_targets : Array[WgslImportTarget] = []
  for target in initial_targets {
    semantic_import_targets_push_unique(pending_targets, target)
  }
  let plans : Array[WgslSemanticImportTargetPlan] = []
  let unresolved_targets : Array[String] = []
  let mut target_index = 0
  while target_index < pending_targets.length() {
    let target = pending_targets[target_index]
    target_index = target_index + 1
    match
      build_wgsl_semantic_import_target_plan(
        source, current_rel_path, target, registry, modules, pending_targets,
      ) {
      Some(plan) =>
        if plan.resolved_module.is_empty() {
          semantic_string_list_push_unique(unresolved_targets, target.raw_path)
        } else {
          plans.push(plan)
        }
      None => ()
    }
  }
  WgslSemanticImportTargetPlans::{ plans, unresolved_targets }
}

///|
fn build_wgsl_semantic_import_rename_map(
  source : String,
  alias_name : String,
) -> @hashmap.HashMap[String, String] raise WgslParseError {
  let rename_map : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
  let alias_prefix = parse_wgsl_import_alias_prefix(alias_name)
  for declaration in parse_wgsl_translation_unit_strict(source).declarations() {
    if declaration.name() != "" {
      rename_map.set(
        declaration.name(),
        "\{alias_prefix}__\{declaration.name()}",
      )
    }
  }
  rename_map
}

///|
fn collect_wgsl_semantic_import_alias_redirects(
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
