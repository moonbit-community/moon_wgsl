///|
fn wgsl_import_target_plan_cache_key(
  current_rel_path : String,
  targets : Array[WgslImportTarget],
  active_scan_source : String,
  session : WgslComposeSession,
  importer_defs : WgslActiveComposeDefs,
  prune_requested_items_by_active_usage : Bool,
) -> String {
  let target_entries : Array[String] = []
  for target in targets {
    target_entries.push("\{target.raw_path} as \{target.alias_name}")
  }
  let prune = if prune_requested_items_by_active_usage {
    "prune"
  } else {
    "keep"
  }
  let source_id = session.source_cache_id(active_scan_source)
  "\{current_rel_path}|\{prune}|\{wgsl_active_defs_cache_key(current_rel_path, importer_defs)}|\{target_entries.join("|")}|source:\{source_id}"
}

///|
fn Composer::build_wgsl_import_requests(
  self : Composer,
  current_rel_path : String,
  spec : String,
  active_scan_source : String,
  session : WgslComposeSession,
  importer_defs : WgslActiveComposeDefs,
) -> Array[WgslImportRequest] raise ComposerError {
  let targets : Array[WgslImportTarget] = []
  if !parse_wgsl_import_spec_is_empty_or_final_semicolon(spec) {
    parse_wgsl_import_targets(spec, "", targets) catch {
      Parse(message, _) => raise FailedToResolveImport(message)
    }
  }
  self.build_wgsl_import_requests_from_targets(
    current_rel_path, targets, active_scan_source, session, importer_defs, true,
  )
}

///|
fn Composer::build_wgsl_import_requests_from_source_directives(
  self : Composer,
  current_rel_path : String,
  active_source : String,
  active_scan_source : String,
  session : WgslComposeSession,
  importer_defs : WgslActiveComposeDefs,
) -> Array[WgslImportRequest] raise ComposerError {
  let targets : Array[WgslImportTarget] = []
  collect_wgsl_import_targets_from_source_directives(
    session, active_source, targets,
  )
  self.build_wgsl_import_requests_from_targets(
    current_rel_path, targets, active_scan_source, session, importer_defs, true,
  )
}

///|
fn wgsl_emitted_item_import_request_cache_key(
  current_rel_path : String,
  directive_source : String,
  dependency_scan_source : String,
  session : WgslComposeSession,
  importer_defs : WgslActiveComposeDefs,
) -> String {
  let directive_source_id = session.source_cache_id(directive_source)
  let dependency_scan_source_id = session.source_cache_id(
    dependency_scan_source,
  )
  "\{current_rel_path}|\{wgsl_active_defs_cache_key(current_rel_path, importer_defs)}|directive:\{directive_source_id}|dependency:\{dependency_scan_source_id}"
}

///|
fn Composer::build_wgsl_import_requests_from_emitted_item_slice(
  self : Composer,
  current_rel_path : String,
  directive_source : String,
  dependency_scan_source : String,
  extraction : WgslModuleItemExtraction?,
  session : WgslComposeSession,
  importer_defs : WgslActiveComposeDefs,
) -> Array[WgslImportRequest] raise ComposerError {
  let cache_key = wgsl_emitted_item_import_request_cache_key(
    current_rel_path, directive_source, dependency_scan_source, session, importer_defs,
  )
  match session.emitted_item_import_requests.get(cache_key) {
    Some(cached_requests) =>
      return wgsl_import_request_array_copy(cached_requests)
    None => ()
  }
  record_wgsl_emitted_item_extraction_facts(
    session, directive_source, extraction,
  )
  let targets : Array[WgslImportTarget] = []
  collect_wgsl_import_targets_from_source_directives(
    session, directive_source, targets,
  )
  let requests = self.build_wgsl_import_requests_from_targets(
    current_rel_path, targets, directive_source, session, importer_defs, true,
  )
  if dependency_scan_source != directive_source {
    self.merge_wgsl_dependency_scan_import_requests(
      current_rel_path, requests, dependency_scan_source, session, importer_defs,
    )
  }
  session.emitted_item_import_requests.set(
    cache_key,
    wgsl_import_request_array_copy(requests),
  )
  requests
}

///|
fn Composer::build_wgsl_import_requests_from_targets(
  self : Composer,
  current_rel_path : String,
  targets : Array[WgslImportTarget],
  active_scan_source : String,
  session : WgslComposeSession,
  importer_defs : WgslActiveComposeDefs,
  prune_requested_items_by_active_usage : Bool,
) -> Array[WgslImportRequest] raise ComposerError {
  if targets.length() == 0 {
    return []
  }
  let requests : Array[WgslImportRequest] = []
  let plan_cache_key = wgsl_import_target_plan_cache_key(
    current_rel_path, targets, active_scan_source, session, importer_defs, prune_requested_items_by_active_usage,
  )
  match session.import_request_plans.get(plan_cache_key) {
    Some(cached_requests) =>
      return wgsl_import_request_array_copy(cached_requests)
    None => ()
  }
  self.record_declared_leaf_import_local_spelling(
    current_rel_path, targets, session, importer_defs,
  )
  self.preflight_wgsl_import_targets_without_source_parse(
    current_rel_path, targets, session,
  )
  let reference_scan_base_source = drop_wgsl_import_directives_from_compose_source_cached(
    session, active_scan_source,
  )
  let active_scan_facts = collect_wgsl_compose_semantic_facts(
    session, reference_scan_base_source,
  )
  let target_plans = build_wgsl_semantic_import_target_plans(
    session,
    reference_scan_base_source,
    active_scan_facts,
    current_rel_path,
    targets,
    self.registry,
    session.modules,
  )
  if target_plans.unresolved_targets.length() > 0 {
    raise FailedToResolveImport(target_plans.unresolved_targets[0])
  }
  let context = WgslImportTargetPlanBuildContext::{
    current_rel_path,
    active_scan_facts,
    target_plans: target_plans.plans,
    session,
    importer_defs,
    prune_requested_items_by_active_usage,
    full_module_dependency_scan_facts: None,
  }
  for target_plan in target_plans.plans {
    match self.build_wgsl_import_request_from_target_plan(
      context, target_plan,
    ) {
      Some(request) => merge_wgsl_import_request(requests, request)
      None => ()
    }
  }
  let ordered_requests = self.order_wgsl_import_requests_by_declared_dependencies(
    requests, session, importer_defs,
  )
  session.import_request_plans.set(
    plan_cache_key,
    wgsl_import_request_array_copy(ordered_requests),
  )
  ordered_requests
}

///|
fn Composer::build_wgsl_implicit_import_requests(
  self : Composer,
  current_rel_path : String,
  active_scan_source : String,
  session : WgslComposeSession,
  importer_defs : WgslActiveComposeDefs,
) -> Array[WgslImportRequest] raise ComposerError {
  let qualified_targets : Array[WgslImportTarget] = []
  let reference_scan_base_source = drop_wgsl_import_directives_from_compose_source_cached(
    session, active_scan_source,
  )
  let active_scan_facts = collect_wgsl_compose_semantic_facts(
    session, reference_scan_base_source,
  ) catch {
    _ => return []
  }
  collect_wgsl_semantic_qualified_module_targets_from_facts(
    active_scan_facts,
    current_rel_path,
    self.registry,
    session.modules,
    qualified_targets,
  )
  self.build_wgsl_import_requests_from_targets(
    current_rel_path, qualified_targets, active_scan_source, session, importer_defs,
    true,
  )
}
