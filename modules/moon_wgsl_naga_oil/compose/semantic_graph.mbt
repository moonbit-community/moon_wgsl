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
priv struct WgslSemanticImportTargetPlan {
  resolved_module : WgslResolvedImportModule
  module_alias : String
  requested_items : Array[String]
  import_full_module : Bool
  keep_requested_items : Bool
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
) -> WgslReferencePath? {
  WgslReferencePath::from_text(name)
}

///|
fn collect_wgsl_semantic_reference_paths(
  source : String,
  paths : Array[WgslReferencePath],
) -> Unit raise WgslParseError {
  let nodes : Array[WgslIdent] = []
  collect_wgsl_semantic_reference_identifier_nodes(source, nodes)
  for node in nodes {
    match wgsl_semantic_reference_path_from_identifier(node.name()) {
      Some(path) => paths.push(path)
      None => ()
    }
  }
}

///|
fn collect_wgsl_semantic_reference_identifier_nodes(
  source : String,
  nodes : Array[WgslIdent],
) -> Unit raise WgslParseError {
  for decl in parse_wgsl_translation_unit_strict(source).declarations() {
    collect_wgsl_decl_identifier_nodes(decl.data(), nodes)
  }
  sort_wgsl_semantic_identifier_nodes_by_source(nodes)
}

///|
fn sort_wgsl_semantic_identifier_nodes_by_source(
  nodes : Array[WgslIdent],
) -> Unit {
  nodes.sort_by(fn(lhs, rhs) {
    let start_compare = lhs.start() - rhs.start()
    if start_compare != 0 {
      return start_compare
    }
    let end_compare = lhs.end() - rhs.end()
    if end_compare != 0 {
      return end_compare
    }
    String::compare(lhs.name(), rhs.name())
  })
}

///|
fn collect_wgsl_naga_oil_import_use_identifier_nodes(
  source : String,
  nodes : Array[WgslIdent],
) -> Unit {
  let body_source = @lex.replace_comments_preserving_byte_width(
    drop_wgsl_import_directives_from_compose_source(source),
  )
  let tokens = tokenize(body_source, true)
  let mut in_substitution_position = true
  for token in tokens {
    match token.identifier_text() {
      Some(name) =>
        if in_substitution_position {
          nodes.push(WgslIdent(name, token.pos(), token.end()))
        }
      None => ()
    }
    match token.punctuation_code() {
      Some(code) if code == 46 || code == 64 => {
        in_substitution_position = false
        continue
      }
      _ => in_substitution_position = true
    }
  }
  sort_wgsl_semantic_identifier_nodes_by_source(nodes)
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
fn wgsl_semantic_import_alias_prefix_separator(prefix : String) -> String {
  if prefix == "" || prefix.has_suffix("_") {
    prefix
  } else {
    "\{prefix}_"
  }
}

///|
fn wgsl_semantic_import_alias_prefix(alias_name : String) -> String {
  let mut prefix = ""
  let segments : Array[String] = []
  for segment in alias_name.trim().split("::") {
    segments.push(segment.to_owned())
  }
  for i in 0..<segments.length() {
    if i > 0 {
      prefix = wgsl_semantic_import_alias_prefix_separator(prefix)
    }
    for token in tokenize(segments[i], true) {
      match token.identifier_text() {
        Some(text) if !text.contains("\"") => prefix = "\{prefix}\{text}"
        _ => prefix = wgsl_semantic_import_alias_prefix_separator(prefix)
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
fn wgsl_semantic_alias_requested_item_name(
  reference_path : WgslReferencePath,
  alias_name : String,
) -> String {
  let alias_segments = wgsl_semantic_path_segments(alias_name)
  let reference_segments = reference_path.segments()
  if alias_segments.length() == 0 ||
    reference_segments.length() <= alias_segments.length() {
    return ""
  }
  for i in 0..<alias_segments.length() {
    if reference_segments[i] != alias_segments[i] {
      return ""
    }
  }
  let suffix : Array[String] = []
  for i in alias_segments.length()..<reference_segments.length() {
    suffix.push(reference_segments[i])
  }
  suffix.join("::")
}

///|
fn collect_wgsl_semantic_alias_requested_paths_from_references(
  references : Array[WgslReferencePath],
  alias_name : String,
  requested_paths : Array[String],
) -> Unit {
  if alias_name == "" {
    return
  }
  for path in references {
    let requested_item = wgsl_semantic_alias_requested_item_name(
      path, alias_name,
    )
    semantic_string_list_push_unique(requested_paths, requested_item)
  }
}

///|
fn WgslComposeSemanticFacts::contains_reference_path(
  self : WgslComposeSemanticFacts,
  reference_path : String,
) -> Bool {
  match wgsl_semantic_reference_path_from_identifier(reference_path) {
    Some(expected) => {
      for path in self.references {
        if path.text() == expected.text() {
          return true
        }
      }
      false
    }
    None => false
  }
}

///|
fn WgslComposeSemanticFacts::contains_unqualified_reference_name(
  self : WgslComposeSemanticFacts,
  name : String,
) -> Bool {
  let name = name.trim().to_owned()
  if name == "" {
    return false
  }
  for path in self.references {
    let segments = path.segments()
    if segments.length() == 1 && segments[0] == name {
      return true
    }
  }
  false
}

///|
fn WgslComposeSemanticFacts::merge(
  self : WgslComposeSemanticFacts,
  other : WgslComposeSemanticFacts,
) -> WgslComposeSemanticFacts {
  let declarations = self.declarations.copy()
  for declaration in other.declarations {
    declarations.push(declaration)
  }
  let references = self.references.copy()
  for reference in other.references {
    let reference_text = reference.text()
    if !references.any(fn(existing) { existing.text() == reference_text }) {
      references.push(reference)
    }
  }
  { declarations, references }
}

///|
fn WgslComposeSemanticFacts::declares_name(
  self : WgslComposeSemanticFacts,
  name : String,
) -> Bool {
  let name = name.trim().to_owned()
  if name == "" {
    return false
  }
  for declaration in self.declarations {
    if declaration.name() == name {
      return true
    }
  }
  false
}

///|
fn WgslComposeSemanticFacts::collect_alias_requested_paths(
  self : WgslComposeSemanticFacts,
  alias_name : String,
  requested_paths : Array[String],
) -> Unit {
  collect_wgsl_semantic_alias_requested_paths_from_references(
    self.references,
    alias_name,
    requested_paths,
  )
}

///|
fn wgsl_semantic_facts_use_alias(
  facts : WgslComposeSemanticFacts,
  alias_name : String,
) -> Bool {
  let requested_paths : Array[String] = []
  facts.collect_alias_requested_paths(alias_name, requested_paths)
  requested_paths.length() > 0
}

///|
fn wgsl_semantic_reference_nodes_first_start(
  nodes : Array[WgslIdent],
  reference_path : String,
) -> Int? {
  match wgsl_semantic_reference_path_from_identifier(reference_path) {
    Some(expected) => {
      for node in nodes {
        match wgsl_semantic_reference_path_from_identifier(node.name()) {
          Some(path) if path.text() == expected.text() =>
            return Some(node.start())
          _ => ()
        }
      }
      None
    }
    None => None
  }
}

///|
fn wgsl_semantic_import_order_consider_path(
  nodes : Array[WgslIdent],
  reference_path : String,
  current_best : Int,
) -> Int {
  match wgsl_semantic_reference_nodes_first_start(nodes, reference_path) {
    Some(start) if current_best < 0 || start < current_best => start
    _ => current_best
  }
}

///|
fn wgsl_semantic_import_target_plan_order_key(
  nodes : Array[WgslIdent],
  plan : WgslSemanticImportTargetPlan,
  fallback : Int,
) -> Int {
  let mut best = -1
  if plan.requested_items.length() == 0 {
    if plan.module_alias != "" {
      best = wgsl_semantic_import_order_consider_path(
        nodes,
        plan.module_alias,
        best,
      )
    }
    best = wgsl_semantic_import_order_consider_path(
      nodes,
      plan.resolved_module.module_path(),
      best,
    )
  } else {
    for requested_item in plan.requested_items {
      best = wgsl_semantic_import_order_consider_path(
        nodes, requested_item, best,
      )
      if plan.module_alias != "" {
        best = wgsl_semantic_import_order_consider_path(
          nodes,
          "\{plan.module_alias}::\{requested_item}",
          best,
        )
      }
      match split_last_wgsl_semantic_path(requested_item) {
        Some((_, leaf_name)) =>
          best = wgsl_semantic_import_order_consider_path(
            nodes, leaf_name, best,
          )
        None => ()
      }
    }
  }
  if best < 0 {
    fallback
  } else {
    best
  }
}

///|
fn wgsl_semantic_order_import_target_plans_by_reference(
  source : String,
  plans : Array[WgslSemanticImportTargetPlan],
) -> Array[WgslSemanticImportTargetPlan] {
  let nodes : Array[WgslIdent] = []
  collect_wgsl_naga_oil_import_use_identifier_nodes(source, nodes)
  let ordered : Array[WgslSemanticImportTargetPlan] = []
  let picked : @set.Set[Int] = Set([])
  let fallback_base = source.length() + 1
  while ordered.length() < plans.length() {
    let mut best_index = -1
    let mut best_key = 0
    for i in 0..<plans.length() {
      if picked.contains(i) {
        continue
      }
      let key = wgsl_semantic_import_target_plan_order_key(
        nodes,
        plans[i],
        fallback_base + i,
      )
      if best_index < 0 || key < best_key {
        best_index = i
        best_key = key
      }
    }
    if best_index < 0 {
      return ordered
    }
    picked.add(best_index)
    ordered.push(plans[best_index])
  }
  ordered
}

///|
fn resolve_wgsl_semantic_import_module(
  importer_rel_path : String,
  import_path : String,
  registry : WgslSourceRegistry,
  modules : Map[String, String],
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
      None => return None
    }
    return Some(WgslResolvedImportModule(module_path, rel_path))
  }
  match resolve_wgsl_import_module_in_registry(registry, import_path, modules) {
    Some(resolved_module) => return Some(resolved_module)
    None => ()
  }
  if split_last_identifier(import_path) is Some((module_path, _)) {
    if resolve_wgsl_import_file_path_from_registry(
        registry, importer_rel_path, module_path,
      )
      is Some(rel_path) {
      return Some(WgslResolvedImportModule(module_path, rel_path))
    }
  }
  None
}

///|
fn collect_wgsl_semantic_qualified_module_targets_from_facts(
  facts : WgslComposeSemanticFacts,
  current_rel_path : String,
  registry : WgslSourceRegistry,
  modules : Map[String, String],
  targets : Array[WgslImportTarget],
) -> Unit {
  for path in facts.references {
    if path.segments().length() < 3 {
      continue
    }
    guard resolve_wgsl_semantic_import_module(
        current_rel_path,
        path.text(),
        registry,
        modules,
      )
      is Some(resolved_module) else {
      continue
    }
    let requested_item = wgsl_semantic_requested_item_name(
      path.text(),
      resolved_module.module_path(),
    )
    if requested_item == "" {
      continue
    }
    semantic_import_targets_push_unique(targets, {
      raw_path: resolved_module.module_path(),
      alias_name: resolved_module.module_path(),
    })
  }
}

///|
fn wgsl_semantic_collect_alias_plan_items(
  facts : WgslComposeSemanticFacts,
  target : WgslImportTarget,
  pending_targets : Array[WgslImportTarget],
  requested_items : Array[String],
) -> Bool {
  let requested_paths : Array[String] = []
  facts.collect_alias_requested_paths(target.alias_name, requested_paths)
  for requested_path in requested_paths {
    if split_last_wgsl_semantic_path(requested_path) is Some((nested_prefix, _)) {
      semantic_import_targets_push_unique(pending_targets, {
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
  facts : WgslComposeSemanticFacts,
  request_module_prefix : String,
  module_alias : String,
  pending_targets : Array[WgslImportTarget],
  requested_items : Array[String],
) -> Bool {
  let requested_paths : Array[String] = []
  facts.collect_alias_requested_paths(module_alias, requested_paths)
  for requested_path in requested_paths {
    if split_last_wgsl_semantic_path(requested_path) is Some((nested_prefix, _)) {
      semantic_import_targets_push_unique(pending_targets, {
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
  {
    resolved_module: WgslResolvedImportModule("", ""),
    module_alias: "",
    requested_items: [],
    import_full_module: false,
    keep_requested_items: false,
    default_module_alias_candidate: false,
    alias_is_used: false,
  }
}

///|
fn build_wgsl_semantic_import_target_plan(
  facts : WgslComposeSemanticFacts,
  current_rel_path : String,
  target : WgslImportTarget,
  registry : WgslSourceRegistry,
  modules : Map[String, String],
  pending_targets : Array[WgslImportTarget],
) -> WgslSemanticImportTargetPlan? {
  let requested_items : Array[String] = []
  let resolved_module_opt = resolve_wgsl_semantic_import_module(
    current_rel_path,
    target.raw_path,
    registry,
    modules,
  )
  if target.alias_name != "" && resolved_module_opt is None {
    ignore(
      wgsl_semantic_collect_alias_plan_items(
        facts, target, pending_targets, requested_items,
      ),
    )
    if requested_items.length() > 0 {
      return Some(unresolved_wgsl_semantic_import_target_plan())
    }
    return None
  }
  if target.alias_name != "" &&
    !wgsl_semantic_collect_alias_plan_items(
      facts, target, pending_targets, requested_items,
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
  let mut default_module_alias_candidate = false
  let mut alias_is_used = false
  if target.alias_name != "" {
    alias_is_used = true
  } else if module_alias != "" {
    default_module_alias_candidate = true
    alias_is_used = wgsl_semantic_facts_use_alias(facts, module_alias)
    if alias_is_used {
      ignore(
        wgsl_semantic_collect_default_alias_plan_items(
          facts, request_module_prefix, module_alias, pending_targets, requested_items,
        ),
      )
    }
  } else if resolved_module.module_path() != target.raw_path {
    import_full_module = false
    keep_requested_items = true
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
  Some({
    resolved_module,
    module_alias,
    requested_items,
    import_full_module,
    keep_requested_items,
    default_module_alias_candidate,
    alias_is_used,
  })
}

///|
fn build_wgsl_semantic_import_target_plans(
  source : String,
  facts : WgslComposeSemanticFacts,
  current_rel_path : String,
  initial_targets : Array[WgslImportTarget],
  registry : WgslSourceRegistry,
  modules : Map[String, String],
) -> WgslSemanticImportTargetPlans {
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
        facts, current_rel_path, target, registry, modules, pending_targets,
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
  if unresolved_targets.length() > 0 {
    return { plans, unresolved_targets }
  }
  let ordered_plans = wgsl_semantic_order_import_target_plans_by_reference(
    source, plans,
  )
  { plans: ordered_plans, unresolved_targets }
}

///|
