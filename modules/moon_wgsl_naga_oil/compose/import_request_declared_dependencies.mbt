///|
fn Composer::build_wgsl_declared_import_requests(
  self : Composer,
  current_rel_path : String,
  spec : String,
  session : WgslComposeSession,
  importer_defs : WgslActiveComposeDefs,
) -> Array[WgslImportRequest] raise ComposerError {
  let targets : Array[WgslImportTarget] = []
  if !parse_wgsl_import_spec_is_empty_or_final_semicolon(spec) {
    parse_wgsl_import_targets(spec, "", targets) catch {
      Parse(message, _) => raise FailedToResolveImport(message)
    }
  }
  self.build_wgsl_declared_import_requests_from_targets(
    current_rel_path, targets, session, importer_defs,
  )
}

///|
fn Composer::build_wgsl_declared_import_requests_from_source_directives(
  self : Composer,
  current_rel_path : String,
  active_source : String,
  session : WgslComposeSession,
  importer_defs : WgslActiveComposeDefs,
) -> Array[WgslImportRequest] raise ComposerError {
  let targets : Array[WgslImportTarget] = []
  collect_wgsl_import_targets_from_source_directives(
    session, active_source, targets,
  )
  self.build_wgsl_declared_import_requests_from_targets(
    current_rel_path, targets, session, importer_defs,
  )
}

///|
fn Composer::build_wgsl_declared_import_requests_from_targets(
  self : Composer,
  current_rel_path : String,
  targets : Array[WgslImportTarget],
  session : WgslComposeSession,
  importer_defs : WgslActiveComposeDefs,
) -> Array[WgslImportRequest] raise ComposerError {
  let requests : Array[WgslImportRequest] = []
  for target in targets {
    guard resolve_wgsl_semantic_import_module(
        current_rel_path,
        target.raw_path,
        self.registry,
        session.modules,
      )
      is Some(base_resolved_module) else {
      raise FailedToResolveImport(target.raw_path)
    }
    let module_path = base_resolved_module.module_path()
    let requested_items : Array[String] = []
    let requested_item = wgsl_semantic_requested_item_name(
      target.raw_path,
      module_path,
    )
    let import_full_module = requested_item == ""
    if requested_item != "" {
      requested_items.push(requested_item)
    }
    let module_alias = if target.alias_name != "" {
      target.alias_name
    } else if import_full_module && module_path == target.raw_path {
      wgsl_semantic_import_default_alias(module_path)
    } else {
      ""
    }
    let selected_rel_path = self.select_wgsl_import_candidate_rel_path(
      module_path,
      base_resolved_module.rel_path(),
      requested_items,
      session,
      importer_defs,
    )
    if find_wgsl_import_request_index(
        requests, module_path, selected_rel_path, module_alias,
      )
      is Some(request_index) {
      let request = requests[request_index]
      if import_full_module {
        request.import_full_module = true
      }
      if requested_items.length() > 0 {
        request.keep_requested_items = true
      }
      for requested_item in requested_items {
        composer_string_list_push_unique(
          request.requested_items,
          requested_item,
        )
        composer_string_list_push_unique(request.declared_items, requested_item)
      }
    } else {
      requests.push({
        module_path,
        rel_path: selected_rel_path,
        import_full_module,
        keep_requested_items: requested_items.length() > 0,
        requested_items,
        declared_items: wgsl_import_request_copy_items(requested_items),
        alias_name: module_alias,
      })
    }
  }
  requests
}

///|
fn Composer::record_declared_leaf_import_local_spelling(
  self : Composer,
  current_rel_path : String,
  targets : Array[WgslImportTarget],
  session : WgslComposeSession,
  importer_defs : WgslActiveComposeDefs,
) -> Unit raise ComposerError {
  for target in targets {
    if target.alias_name != "" {
      continue
    }
    guard resolve_wgsl_semantic_import_module(
        current_rel_path,
        target.raw_path,
        self.registry,
        session.modules,
      )
      is Some(base_resolved_module) else {
      continue
    }
    let module_path = base_resolved_module.module_path()
    let requested_item = wgsl_semantic_requested_item_name(
      target.raw_path,
      module_path,
    )
    if requested_item == "" {
      continue
    }
    let selected_rel_path = self.select_wgsl_import_candidate_rel_path(
      module_path,
      base_resolved_module.rel_path(),
      [requested_item],
      session,
      importer_defs,
    )
    session.record_local_spelling_final_name(
      current_rel_path, selected_rel_path, requested_item, "",
    )
  }
}

///|
fn wgsl_import_request_contains_item(
  request : WgslImportRequest,
  item : String,
) -> Bool {
  for requested_item in request.requested_items {
    if requested_item == item {
      return true
    }
  }
  false
}

///|
fn wgsl_import_request_satisfies_dependency(
  candidate : WgslImportRequest,
  dependency : WgslImportRequest,
) -> Bool {
  if candidate.module_path != dependency.module_path ||
    candidate.rel_path != dependency.rel_path ||
    candidate.alias_name != dependency.alias_name {
    return false
  }
  if dependency.import_full_module {
    return candidate.import_full_module
  }
  if candidate.import_full_module {
    return true
  }
  if dependency.requested_items.length() == 0 {
    return false
  }
  for requested_item in dependency.requested_items {
    if !wgsl_import_request_contains_item(candidate, requested_item) {
      return false
    }
  }
  true
}

///|
fn wgsl_import_request_declared_dependency_indexes(
  requests : Array[WgslImportRequest],
  request_index : Int,
  declared_dependencies : Array[WgslImportRequest],
) -> Array[Int] {
  let indexes : Array[Int] = []
  for dependency in declared_dependencies {
    for i in 0..<requests.length() {
      if i == request_index {
        continue
      }
      if wgsl_import_request_satisfies_dependency(requests[i], dependency) {
        if !indexes.contains(i) {
          indexes.push(i)
        }
      }
    }
  }
  indexes
}

///|
fn Composer::declared_dependency_requests_for_import_request(
  self : Composer,
  request : WgslImportRequest,
  session : WgslComposeSession,
  importer_defs : WgslActiveComposeDefs,
) -> Array[WgslImportRequest] raise ComposerError {
  if !request.import_full_module {
    return []
  }
  let processed = self.processed_registered_wgsl_compose_module(
    request.rel_path,
    session,
    Some(importer_defs),
  )
  self.build_wgsl_declared_import_requests_from_source_directives(
    request.rel_path,
    processed.prepared.active_source,
    session,
    processed.active_defs,
  )
}

///|
fn push_wgsl_import_request_with_declared_dependencies(
  requests : Array[WgslImportRequest],
  dependency_indexes : Array[Array[Int]],
  index : Int,
  visiting : @set.Set[Int],
  emitted : @set.Set[Int],
  ordered : Array[WgslImportRequest],
) -> Unit {
  if emitted.contains(index) {
    return
  }
  if visiting.contains(index) {
    return
  }
  visiting.add(index)
  for dependency_index in dependency_indexes[index] {
    push_wgsl_import_request_with_declared_dependencies(
      requests, dependency_indexes, dependency_index, visiting, emitted, ordered,
    )
  }
  visiting.remove(index)
  if !emitted.contains(index) {
    emitted.add(index)
    ordered.push(requests[index])
  }
}

///|
fn Composer::order_wgsl_import_requests_by_declared_dependencies(
  self : Composer,
  requests : Array[WgslImportRequest],
  session : WgslComposeSession,
  importer_defs : WgslActiveComposeDefs,
) -> Array[WgslImportRequest] raise ComposerError {
  let dependency_indexes : Array[Array[Int]] = []
  for i in 0..<requests.length() {
    let declared_dependencies = self.declared_dependency_requests_for_import_request(
      requests[i],
      session,
      importer_defs,
    )
    dependency_indexes.push(
      wgsl_import_request_declared_dependency_indexes(
        requests, i, declared_dependencies,
      ),
    )
  }
  let ordered : Array[WgslImportRequest] = []
  let visiting : @set.Set[Int] = Set([])
  let emitted : @set.Set[Int] = Set([])
  for i in 0..<requests.length() {
    push_wgsl_import_request_with_declared_dependencies(
      requests, dependency_indexes, i, visiting, emitted, ordered,
    )
  }
  requests.clear()
  for request in ordered {
    requests.push(request)
  }
  requests
}
