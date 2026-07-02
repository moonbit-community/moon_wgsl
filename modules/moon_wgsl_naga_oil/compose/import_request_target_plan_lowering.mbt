///|
priv struct WgslImportTargetPlanBuildContext {
  current_rel_path : String
  active_scan_facts : WgslComposeSemanticFacts
  target_plans : Array[WgslSemanticImportTargetPlan]
  session : WgslComposeSession
  importer_defs : WgslActiveComposeDefs
  prune_requested_items_by_active_usage : Bool
  mut full_module_dependency_scan_facts : WgslComposeSemanticFacts?
}

///|
fn Composer::unqualified_live_items_for_wgsl_import_target_plan(
  self : Composer,
  context : WgslImportTargetPlanBuildContext,
  target_plan : WgslSemanticImportTargetPlan,
  import_module : WgslProcessedComposeModule,
) -> Array[String] raise ComposerError {
  if !target_plan.import_full_module || target_plan.alias_is_used {
    return []
  }
  let reference_scan_facts = match context.full_module_dependency_scan_facts {
    Some(facts) => context.active_scan_facts.merge(facts)
    None => {
      let facts = self.active_wgsl_full_module_import_dependency_scan_facts(
        context.target_plans,
        context.active_scan_facts,
        context.session,
        context.importer_defs,
      )
      context.full_module_dependency_scan_facts = Some(facts)
      context.active_scan_facts.merge(facts)
    }
  }
  collect_wgsl_unqualified_live_module_items(
    import_module.semantic_declaration_names(),
    context.active_scan_facts,
    reference_scan_facts,
  )
}

///|
fn wgsl_filter_live_requested_import_items(
  requested_items : Array[String],
  active_scan_facts : WgslComposeSemanticFacts,
  import_module : WgslProcessedComposeModule,
  prune_requested_items_by_active_usage : Bool,
) -> Unit {
  let live_requested_items : Array[String] = []
  for requested_item in requested_items {
    let requested_item_is_live = active_scan_facts.contains_reference_path(
      requested_item,
    )
    let leaf_item_is_live = match split_last_wgsl_semantic_path(requested_item) {
      Some((_, leaf_name)) => active_scan_facts.contains_reference_path(
        leaf_name,
      )
      None => false
    }
    if requested_item_is_live || leaf_item_is_live {
      live_requested_items.push(requested_item)
    } else if !prune_requested_items_by_active_usage &&
      import_module.declares_non_resource_dependency_item(
        requested_item, false,
      ) {
      live_requested_items.push(requested_item)
    }
  }
  requested_items.clear()
  for requested_item in live_requested_items {
    requested_items.push(requested_item)
  }
}

///|
fn Composer::build_wgsl_import_request_from_target_plan(
  self : Composer,
  context : WgslImportTargetPlanBuildContext,
  target_plan : WgslSemanticImportTargetPlan,
) -> WgslImportRequest? raise ComposerError {
  let requested_items = target_plan.requested_items
  let declared_items = wgsl_import_request_copy_items(requested_items)
  let base_resolved_module = target_plan.resolved_module
  let module_path = base_resolved_module.module_path()
  let import_module = self.processed_registered_wgsl_compose_module(
    base_resolved_module.rel_path(),
    context.session,
    Some(context.importer_defs),
  )
  let imports_for_override_side_effect = import_module.imports_for_override_side_effect()
  let imports_for_virtual_side_effect = import_module.imports_for_virtual_side_effect()
  let unqualified_live_module_items = self.unqualified_live_items_for_wgsl_import_target_plan(
    context, target_plan, import_module,
  )
  let mut module_alias = target_plan.module_alias
  let glsl_frontend_import = wgsl_import_rel_path_is_glsl_frontend(
    base_resolved_module.rel_path(),
  )
  let mut import_full_module = target_plan.import_full_module
  if target_plan.alias_is_used &&
    !target_plan.default_module_alias_candidate &&
    requested_items.length() > 0 &&
    !imports_for_override_side_effect &&
    !imports_for_virtual_side_effect {
    import_full_module = false
  }
  if target_plan.default_module_alias_candidate {
    if !target_plan.alias_is_used &&
      !imports_for_override_side_effect &&
      !imports_for_virtual_side_effect &&
      unqualified_live_module_items.length() == 0 {
      return None
    }
    if (imports_for_override_side_effect || imports_for_virtual_side_effect) &&
      !target_plan.alias_is_used {
      module_alias = ""
    }
    if requested_items.length() > 0 {
      if !imports_for_virtual_side_effect {
        import_full_module = false
      }
    } else if !imports_for_override_side_effect &&
      !imports_for_virtual_side_effect &&
      unqualified_live_module_items.length() == 0 {
      return None
    }
  }
  for item in unqualified_live_module_items {
    composer_string_list_push_unique(requested_items, item)
    composer_string_list_push_unique(declared_items, item)
  }
  if !import_full_module {
    if target_plan.keep_requested_items && requested_items.length() > 0 {
      wgsl_filter_live_requested_import_items(
        requested_items,
        context.active_scan_facts,
        import_module,
        context.prune_requested_items_by_active_usage,
      )
    }
    if requested_items.length() == 0 &&
      !imports_for_override_side_effect &&
      !imports_for_virtual_side_effect {
      return None
    }
    if imports_for_override_side_effect || imports_for_virtual_side_effect {
      import_full_module = true
    }
  }
  if glsl_frontend_import {
    import_full_module = true
  }
  let selected_rel_path = self.select_wgsl_import_candidate_rel_path(
    module_path,
    base_resolved_module.rel_path(),
    requested_items,
    context.session,
    context.importer_defs,
  )
  if module_alias == "" {
    for declared_item in declared_items {
      context.session.record_local_spelling_final_name(
        context.current_rel_path, selected_rel_path, declared_item, "",
      )
    }
  }
  Some({
    module_path,
    rel_path: selected_rel_path,
    import_full_module,
    keep_requested_items: target_plan.keep_requested_items,
    requested_items,
    declared_items,
    alias_name: module_alias,
  })
}

///|
fn merge_wgsl_import_request(
  requests : Array[WgslImportRequest],
  request : WgslImportRequest,
) -> Unit {
  if find_wgsl_import_request_index(
      requests,
      request.module_path,
      request.rel_path,
      request.alias_name,
    )
    is Some(request_index) {
    let existing_request = requests[request_index]
    if request.import_full_module {
      existing_request.import_full_module = true
    }
    if request.keep_requested_items {
      existing_request.keep_requested_items = true
    }
    for requested_item in request.requested_items {
      composer_string_list_push_unique(
        existing_request.requested_items,
        requested_item,
      )
    }
    for declared_item in request.declared_items {
      composer_string_list_push_unique(
        existing_request.declared_items,
        declared_item,
      )
    }
  } else {
    requests.push(request)
  }
}
