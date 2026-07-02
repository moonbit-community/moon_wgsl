///|
fn merge_wgsl_side_effect_request(
  requests : Array[WgslImportRequest],
  source_request : WgslImportRequest,
  side_effect_items : Array[String],
) -> Unit {
  if side_effect_items.length() == 0 {
    return
  }
  match
    find_wgsl_import_request_index(
      requests,
      source_request.module_path,
      source_request.rel_path,
      source_request.alias_name,
    ) {
    Some(request_index) => {
      let request = requests[request_index]
      request.keep_requested_items = true
      for item in side_effect_items {
        composer_string_list_push_unique(request.requested_items, item)
        composer_string_list_push_unique(request.declared_items, item)
      }
    }
    None =>
      requests.push({
        module_path: source_request.module_path,
        rel_path: source_request.rel_path,
        import_full_module: false,
        keep_requested_items: true,
        requested_items: wgsl_import_request_copy_items(side_effect_items),
        declared_items: wgsl_import_request_copy_items(side_effect_items),
        alias_name: source_request.alias_name,
      })
  }
}

///|
fn widen_wgsl_dependency_requests_with_alias_side_effects(
  dependency_requests : Array[WgslImportRequest],
  dependency_scan_facts : WgslComposeSemanticFacts,
) -> Unit {
  for dependency_request in dependency_requests {
    if dependency_request.alias_name == "" {
      continue
    }
    let alias_requested_paths : Array[String] = []
    dependency_scan_facts.collect_alias_requested_paths(
      dependency_request.alias_name,
      alias_requested_paths,
    )
    for requested_path in alias_requested_paths {
      if split_last_wgsl_semantic_path(requested_path) is Some(_) {
        continue
      }
      composer_string_list_push_unique(
        dependency_request.requested_items,
        requested_path,
      )
      composer_string_list_push_unique(
        dependency_request.declared_items,
        requested_path,
      )
    }
  }
}

///|
fn merge_wgsl_declared_full_module_side_effect_request(
  requests : Array[WgslImportRequest],
  declared_request : WgslImportRequest,
  side_effect_items : Array[String],
) -> Unit {
  if side_effect_items.length() == 0 {
    return
  }
  match
    find_wgsl_import_request_index(
      requests,
      declared_request.module_path,
      declared_request.rel_path,
      declared_request.alias_name,
    ) {
    Some(request_index) => {
      let request = requests[request_index]
      request.keep_requested_items = true
      for side_effect_item in side_effect_items {
        composer_string_list_push_unique(
          request.requested_items,
          side_effect_item,
        )
      }
      for declared_item in declared_request.declared_items {
        composer_string_list_push_unique(request.declared_items, declared_item)
      }
    }
    None =>
      requests.push({
        module_path: declared_request.module_path,
        rel_path: declared_request.rel_path,
        import_full_module: false,
        keep_requested_items: true,
        requested_items: side_effect_items,
        declared_items: wgsl_import_request_copy_items(
          declared_request.declared_items,
        ),
        alias_name: declared_request.alias_name,
      })
  }
}

///|
fn Composer::merge_wgsl_declared_full_module_side_effect_requests(
  self : Composer,
  requests : Array[WgslImportRequest],
  dependency_requests : Array[WgslImportRequest],
  declared_dependency_requests : Array[WgslImportRequest],
  session : WgslComposeSession,
  importer_defs : WgslActiveComposeDefs,
) -> Unit raise ComposerError {
  for declared_request in declared_dependency_requests {
    if !declared_request.import_full_module {
      continue
    }
    let candidate_items = match
      find_wgsl_import_request_index(
        dependency_requests,
        declared_request.module_path,
        declared_request.rel_path,
        declared_request.alias_name,
      ) {
      Some(request_index) => dependency_requests[request_index].requested_items
      None => []
    }
    if candidate_items.length() == 0 {
      continue
    }
    let side_effect_items = self.collect_wgsl_declared_full_module_side_effect_items(
      declared_request, candidate_items, session, importer_defs,
    )
    merge_wgsl_declared_full_module_side_effect_request(
      requests, declared_request, side_effect_items,
    )
  }
}

///|
fn Composer::merge_wgsl_dependency_side_effect_requests(
  self : Composer,
  requests : Array[WgslImportRequest],
  dependency_requests : Array[WgslImportRequest],
  session : WgslComposeSession,
  importer_defs : WgslActiveComposeDefs,
) -> Unit raise ComposerError {
  for dependency_request in dependency_requests {
    if dependency_request.requested_items.length() == 0 {
      continue
    }
    let const_side_effect_items = self.collect_wgsl_declared_const_side_effect_items(
      dependency_request,
      dependency_request.requested_items,
      session,
      importer_defs,
    )
    merge_wgsl_side_effect_request(
      requests, dependency_request, const_side_effect_items,
    )
    let side_effect_items = self.collect_wgsl_declared_full_module_side_effect_items(
      dependency_request,
      dependency_request.requested_items,
      session,
      importer_defs,
    )
    merge_wgsl_side_effect_request(
      requests, dependency_request, side_effect_items,
    )
  }
}

///|
fn Composer::merge_wgsl_dependency_scan_import_requests(
  self : Composer,
  current_rel_path : String,
  requests : Array[WgslImportRequest],
  dependency_scan_source : String,
  session : WgslComposeSession,
  importer_defs : WgslActiveComposeDefs,
) -> Unit raise ComposerError {
  let dependency_targets : Array[WgslImportTarget] = []
  collect_wgsl_import_targets_from_source_directives(
    session, dependency_scan_source, dependency_targets,
  )
  let side_effect_targets : Array[WgslImportTarget] = []
  collect_wgsl_single_target_import_targets_from_source_directives(
    session, dependency_scan_source, side_effect_targets,
  )
  let dependency_requests = self.build_wgsl_import_requests_from_targets(
    current_rel_path, dependency_targets, dependency_scan_source, session, importer_defs,
    false,
  )
  let dependency_scan_facts = collect_wgsl_compose_semantic_facts(
    session, dependency_scan_source,
  )
  widen_wgsl_dependency_requests_with_alias_side_effects(
    dependency_requests, dependency_scan_facts,
  )
  let declared_dependency_requests = self.build_wgsl_declared_import_requests_from_targets(
    current_rel_path, side_effect_targets, session, importer_defs,
  )
  self.merge_wgsl_declared_full_module_side_effect_requests(
    requests, dependency_requests, declared_dependency_requests, session, importer_defs,
  )
  self.merge_wgsl_dependency_side_effect_requests(
    requests, dependency_requests, session, importer_defs,
  )
  self.merge_wgsl_non_resource_dependency_requests(
    requests, dependency_requests, dependency_scan_facts, session, importer_defs,
  )
}

///|
fn Composer::active_wgsl_full_module_import_dependency_scan_facts(
  self : Composer,
  target_plans : Array[WgslSemanticImportTargetPlan],
  active_scan_facts : WgslComposeSemanticFacts,
  session : WgslComposeSession,
  importer_defs : WgslActiveComposeDefs,
) -> WgslComposeSemanticFacts raise ComposerError {
  let mut facts = WgslComposeSemanticFacts([], [], [])
  for target_plan in target_plans {
    if !target_plan.import_full_module {
      continue
    }
    let rel_path = target_plan.resolved_module.rel_path()
    let processed = self.processed_registered_wgsl_compose_module(
      rel_path,
      session,
      Some(importer_defs),
    )
    let requested_items : Array[String] = []
    for declaration_name in processed.semantic_declaration_names() {
      let referenced = active_scan_facts.contains_unqualified_reference_name(
        declaration_name,
      )
      if referenced {
        composer_string_list_push_unique(requested_items, declaration_name)
      }
    }
    if requested_items.length() == 0 {
      continue
    }
    let extraction = processed.item_extraction(requested_items)
    let extraction_facts = wgsl_compose_semantic_facts_from_extraction(
      extraction,
    )
    session.semantic_facts.set(extraction.source(), extraction_facts)
    facts = facts.merge(extraction_facts)
  }
  facts
}

///|
fn Composer::merge_wgsl_non_resource_dependency_requests(
  self : Composer,
  requests : Array[WgslImportRequest],
  dependency_requests : Array[WgslImportRequest],
  dependency_scan_facts : WgslComposeSemanticFacts,
  session : WgslComposeSession,
  importer_defs : WgslActiveComposeDefs,
) -> Unit raise ComposerError {
  let ordered_requests : Array[WgslImportRequest] = []
  let ordered_base_indexes : @set.Set[Int] = Set([])
  for dependency_request in dependency_requests {
    if dependency_request.import_full_module {
      match
        find_wgsl_import_request_index(
          requests,
          dependency_request.module_path,
          dependency_request.rel_path,
          dependency_request.alias_name,
        ) {
        Some(request_index) => {
          let request = requests[request_index]
          ordered_base_indexes.add(request_index)
          request.import_full_module = true
          ordered_requests.push(request)
        }
        None => ordered_requests.push(dependency_request)
      }
      continue
    }
    let filtered_items = self.filtered_wgsl_non_resource_dependency_items(
      dependency_request, dependency_scan_facts, session, importer_defs,
    )
    if find_wgsl_import_request_index(
        requests,
        dependency_request.module_path,
        dependency_request.rel_path,
        dependency_request.alias_name,
      )
      is Some(request_index) {
      let request = requests[request_index]
      ordered_base_indexes.add(request_index)
      if filtered_items.length() > 0 {
        request.keep_requested_items = true
      }
      for requested_item in filtered_items {
        composer_string_list_push_unique(
          request.requested_items,
          requested_item,
        )
      }
      for declared_item in dependency_request.declared_items {
        composer_string_list_push_unique(request.declared_items, declared_item)
      }
      ordered_requests.push(request)
    } else if filtered_items.length() > 0 {
      ordered_requests.push({
        module_path: dependency_request.module_path,
        rel_path: dependency_request.rel_path,
        import_full_module: false,
        keep_requested_items: true,
        requested_items: filtered_items,
        declared_items: wgsl_import_request_copy_items(
          dependency_request.declared_items,
        ),
        alias_name: dependency_request.alias_name,
      })
    }
  }
  for i in 0..<requests.length() {
    if !ordered_base_indexes.contains(i) {
      ordered_requests.push(requests[i])
    }
  }
  requests.clear()
  for request in ordered_requests {
    requests.push(request)
  }
}

///|
fn Composer::filtered_wgsl_non_resource_dependency_items(
  self : Composer,
  dependency_request : WgslImportRequest,
  dependency_scan_facts : WgslComposeSemanticFacts,
  session : WgslComposeSession,
  importer_defs : WgslActiveComposeDefs,
) -> Array[String] raise ComposerError {
  let filtered_items : Array[String] = []
  if dependency_request.requested_items.length() == 0 {
    return filtered_items
  }
  let processed = self.processed_registered_wgsl_compose_module(
    dependency_request.rel_path,
    session,
    Some(importer_defs),
  )
  for requested_item in dependency_request.requested_items {
    let requested_item_is_referenced = dependency_scan_facts.contains_reference_path(
      requested_item,
    )
    let leaf_item_is_referenced = match
      split_last_wgsl_semantic_path(requested_item) {
      Some((_, leaf_name)) =>
        dependency_scan_facts.contains_reference_path(leaf_name)
      None => false
    }
    let alias_item_is_referenced = if dependency_request.alias_name == "" {
      false
    } else {
      dependency_scan_facts.contains_reference_path(
        "\{dependency_request.alias_name}::\{requested_item}",
      )
    }
    if processed.declares_non_resource_dependency_item(
        requested_item,
        requested_item_is_referenced ||
        leaf_item_is_referenced ||
        alias_item_is_referenced,
      ) {
      composer_string_list_push_unique(filtered_items, requested_item)
    }
  }
  filtered_items
}
