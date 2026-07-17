///|
fn WgslComposeSession::record_graph_planned_request(
  self : WgslComposeSession,
  importer_rel_path : String,
  request : WgslImportRequest,
) -> Unit {
  self.graph_planned_requests.add(
    wgsl_import_request_visit_key(importer_rel_path, request),
  )
  if !request.import_full_module {
    for item in request.requested_items {
      self.graph_planned_requests.add(
        wgsl_import_request_item_visit_key(importer_rel_path, request, item),
      )
    }
  }
}

///|
fn WgslComposeSession::graph_request_is_planned(
  self : WgslComposeSession,
  importer_rel_path : String,
  request : WgslImportRequest,
) -> Bool {
  if self.graph_planned_requests.contains(
      wgsl_import_request_visit_key(importer_rel_path, request),
    ) {
    return true
  }
  if request.import_full_module {
    return false
  }
  if request.requested_items.length() == 0 {
    return false
  }
  for item in request.requested_items {
    if !self.graph_planned_requests.contains(
        wgsl_import_request_item_visit_key(importer_rel_path, request, item),
      ) {
      return false
    }
  }
  true
}

///|
fn WgslComposeSession::record_graph_planned_full_module(
  self : WgslComposeSession,
  rel_path : String,
  alias_name : String,
) -> Unit {
  self.graph_planned_requests.add(
    wgsl_full_module_visit_key(rel_path, alias_name),
  )
}

///|
fn WgslComposeSession::graph_full_module_is_planned(
  self : WgslComposeSession,
  rel_path : String,
  alias_name : String,
) -> Bool {
  self.graph_planned_requests.contains(
    wgsl_full_module_visit_key(rel_path, alias_name),
  )
}

///|
fn wgsl_compose_assigned_final_name(
  module_path : String,
  alias_prefixes : Array[String],
  original_name : String,
) -> String {
  if module_path != "" {
    wgsl_naga_oil_decorated_final_name(module_path, original_name)
  } else if alias_prefixes.length() == 0 {
    original_name
  } else {
    let prefix = alias_prefixes.join("__")
    "\{prefix}__\{original_name}"
  }
}

///|
fn WgslComposeSession::module_rel_path_for_module_path(
  self : WgslComposeSession,
  module_path : String,
) -> String? {
  self.modules.get(module_path)
}

///|
fn WgslComposeSession::module_path_for_rel_path(
  self : WgslComposeSession,
  rel_path : String,
) -> String? {
  let normalized_rel = normalize_shader_rel_path(rel_path)
  for entry in self.modules.iter() {
    let (module_path, module_rel_path) = entry
    if normalize_shader_rel_path(module_rel_path) == normalized_rel {
      return Some(module_path)
    }
  }
  None
}

///|
fn record_wgsl_virtual_override_final_names_from_source(
  session : WgslComposeSession,
  rel_path : String,
  source : String,
) -> Unit {
  let targets = collect_wgsl_virtual_override_targets_strict(source) catch {
    _ => return
  }
  record_wgsl_virtual_override_final_names_from_targets(
    session, rel_path, targets,
  )
}

///|
fn record_wgsl_virtual_override_final_names_from_targets(
  session : WgslComposeSession,
  rel_path : String,
  targets : Array[String],
) -> Unit {
  let composing_root = session.graph_planning_rel_paths.length() <= 1 &&
    session.active_rel_paths.length() <= 1
  let override_module_path = match session.module_path_for_rel_path(rel_path) {
    Some(module_path) if !composing_root => module_path
    _ => ""
  }
  for raw_target in targets {
    let (target_module_path, original_name) = match
      split_last_identifier(raw_target) {
      Some((module_path, name)) => (module_path, name)
      None => (override_module_path, raw_target)
    }
    if original_name == "" {
      continue
    }
    let target_rel_path = if target_module_path == "" {
      rel_path
    } else {
      match session.module_rel_path_for_module_path(target_module_path) {
        Some(resolved_rel_path) => resolved_rel_path
        None => continue
      }
    }
    let target_name = wgsl_naga_oil_decorated_final_name(
      target_module_path, original_name,
    )
    let override_name = wgsl_naga_oil_virtual_override_final_name(
      target_module_path, override_module_path, original_name,
    )
    session.record_virtual_override_final_name(
      raw_target, target_rel_path, target_name, override_name,
    )
  }
}

///|
fn record_wgsl_planned_final_names_from_extraction(
  session : WgslComposeSession,
  rel_path : String,
  module_path_override : String?,
  alias_prefixes : Array[String],
  extraction : WgslModuleItemExtraction,
) -> Unit {
  if rel_path == "" {
    return
  }
  for origin in extraction.origins() {
    let identity = WgslComposeSymbolIdentity(rel_path, origin.name())
    let module_path = match module_path_override {
      Some(value) => value
      None =>
        match session.module_path_for_rel_path(rel_path) {
          Some(value) => value
          None => ""
        }
    }
    let final_name = wgsl_compose_assigned_final_name(
      module_path,
      alias_prefixes,
      origin.name(),
    )
    if alias_prefixes.length() == 0 {
      session.assign_canonical_final_name(identity, final_name)
    } else {
      session.assign_alias_final_name(
        WgslComposeAliasSymbolIdentity(
          rel_path,
          alias_prefixes.join("__"),
          origin.name(),
        ),
        final_name,
      )
    }
  }
}

///|
fn record_wgsl_planned_final_names_from_source(
  session : WgslComposeSession,
  rel_path : String,
  module_path_override : String?,
  source : String,
  alias_prefixes : Array[String],
) -> Unit {
  record_wgsl_virtual_override_final_names_from_source(
    session, rel_path, source,
  )
  let extraction = extract_wgsl_module_item_origins_strict(source, []) catch {
    _ => return
  }
  record_wgsl_planned_final_names_from_extraction(
    session, rel_path, module_path_override, alias_prefixes, extraction,
  )
}

///|
fn record_wgsl_planned_final_names_from_processed(
  session : WgslComposeSession,
  rel_path : String,
  module_path_override : String?,
  alias_prefixes : Array[String],
  processed : WgslProcessedComposeModule,
) -> Unit {
  let targets = processed.virtual_override_target_names() catch { _ => [] }
  record_wgsl_virtual_override_final_names_from_targets(
    session, rel_path, targets,
  )
  let extraction = processed.item_extraction([]) catch { _ => return }
  record_wgsl_planned_final_names_from_extraction(
    session, rel_path, module_path_override, alias_prefixes, extraction,
  )
}

///|
fn WgslImportGraphBuilder::plan_with_path(
  self : WgslImportGraphBuilder,
  current_rel_path : String,
  current_module_path : String?,
  source : String,
  inherited_defs : WgslActiveComposeDefs?,
  alias_prefixes : Array[String],
  declared_imports : Bool,
  source_already_prepared : Bool,
) -> Unit raise ComposerError {
  let maybe_registered_processed = match
    self.composer.registry.registered_source(current_rel_path) {
    Some(registered_source) if registered_source == source =>
      Some(
        self.composer.processed_registered_wgsl_compose_module(
          current_rel_path,
          self.session,
          inherited_defs,
        ),
      )
    _ => None
  }
  let (active_defs, prepared) = match maybe_registered_processed {
    Some(processed) => (processed.active_defs, processed.prepared)
    None => {
      let active_defs = self.composer.active_compose_defs_for_rel_path(
        current_rel_path,
        self.session,
        inherited_defs,
      )
      let prepared = if source_already_prepared {
        prepare_active_wgsl_compose_source(source, self.session)
      } else {
        merge_wgsl_source_local_shader_defs(
          active_defs,
          source,
          self.session,
          normalize_shader_rel_path(current_rel_path),
        )
        prepare_wgsl_compose_source(source, self.session, active_defs)
      }
      (active_defs, prepared)
    }
  }
  let explicit_requests = if declared_imports {
    self.composer.build_wgsl_declared_import_requests_from_source_directives(
      current_rel_path,
      prepared.active_source,
      self.session,
      active_defs,
    )
  } else {
    self.composer.build_wgsl_import_requests_from_source_directives(
      current_rel_path,
      prepared,
      self.session,
      active_defs,
    )
  }
  match maybe_registered_processed {
    Some(processed) => {
      self.session.record_processed_semantic_facts(processed)
      record_wgsl_planned_final_names_from_processed(
        self.session,
        current_rel_path,
        current_module_path,
        alias_prefixes,
        processed,
      )
    }
    None =>
      record_wgsl_planned_final_names_from_source(
        self.session,
        current_rel_path,
        current_module_path,
        prepared.active_source,
        alias_prefixes,
      )
  }
  let implicit_requests = self.composer.build_wgsl_implicit_import_requests(
    current_rel_path,
    prepared,
    self.session,
    active_defs,
  )
  self.plan_import_request_batch(
    current_rel_path, implicit_requests, active_defs, alias_prefixes,
  )
  self.plan_import_request_batch(
    current_rel_path, explicit_requests, active_defs, alias_prefixes,
  )
}

///|
fn WgslImportGraphBuilder::plan_import_request_batch(
  self : WgslImportGraphBuilder,
  current_rel_path : String,
  requests : Array[WgslImportRequest],
  importer_defs : WgslActiveComposeDefs,
  alias_prefixes : Array[String],
) -> Unit raise ComposerError {
  record_wgsl_import_request_batch_link_edges(
    self.session.link_graph,
    current_rel_path,
    requests,
  )
  for request in requests {
    if self.session.graph_request_is_planned(current_rel_path, request) {
      continue
    }
    self.session.record_graph_planned_request(current_rel_path, request)
    let request_alias_prefixes = alias_prefixes.copy()
    if request.alias_name != "" {
      request_alias_prefixes.push(
        wgsl_semantic_import_alias_prefix(request.alias_name),
      )
    }
    let request_alias_scope = request_alias_prefixes.join("__")
    if request.import_full_module &&
      self.session.graph_full_module_is_planned(
        request.rel_path,
        request_alias_scope,
      ) {
      continue
    }
    if wgsl_path_stack_contains(
        self.session.graph_planning_rel_paths,
        request.rel_path,
      ) {
      raise ImportCycle(
        wgsl_import_cycle_string(
          self.session.graph_planning_rel_paths,
          request.rel_path,
        ),
      )
    }
    if request.import_full_module {
      self.session.record_graph_planned_full_module(
        request.rel_path,
        request_alias_scope,
      )
    }
    let processed = self.composer.processed_registered_wgsl_compose_module(
      request.rel_path,
      self.session,
      Some(importer_defs),
    )
    self.session.record_processed_semantic_facts(processed)
    let raw_source = processed.raw_source
    self.session.graph_planning_rel_paths.push(request.rel_path)
    if request.import_full_module {
      self.plan_with_path(
        request.rel_path,
        Some(request.module_path),
        raw_source,
        Some(importer_defs),
        request_alias_prefixes,
        true,
        false,
      )
    } else {
      let import_defs = processed.active_defs
      let prepared = processed.prepared
      let extraction = processed.item_extraction(request.requested_items)
      let extracted_source = extraction.source()
      if extracted_source != "" {
        record_wgsl_planned_final_names_from_extraction(
          self.session,
          request.rel_path,
          Some(request.module_path),
          request_alias_prefixes,
          extraction,
        )
        let requests = self.composer.build_wgsl_import_requests_from_emitted_item_slice(
          request.rel_path,
          extracted_source,
          prepared.active_source,
          Some(extraction),
          self.session,
          import_defs,
        )
        self.plan_import_request_batch(
          request.rel_path,
          requests,
          import_defs,
          request_alias_prefixes,
        )
      } else {
        let targets : Array[WgslImportTarget] = []
        collect_wgsl_import_targets_from_source_directives(
          self.session,
          prepared.active_source,
          targets,
        )
        let dependency_requests = self.composer.build_wgsl_import_requests_from_targets(
          request.rel_path,
          targets,
          prepared,
          self.session,
          import_defs,
          false,
        )
        let requests : Array[WgslImportRequest] = []
        let dependency_facts = prepared.active_semantic_facts(self.session)
        self.composer.merge_wgsl_non_resource_dependency_requests(
          requests,
          dependency_requests,
          dependency_facts,
          self.session,
          import_defs,
        )
        self.plan_import_request_batch(
          request.rel_path,
          requests,
          import_defs,
          request_alias_prefixes,
        )
      }
    }
    self.session.graph_planning_rel_paths.pop() |> ignore
  }
}

///|
fn WgslImportGraphBuilder::complete_execution(
  self : WgslImportGraphBuilder,
  current_rel_path : String,
  source : String,
  inherited_defs : WgslActiveComposeDefs?,
) -> Unit raise ComposerError {
  if self.session.graph_execution_complete {
    return
  }
  self.session.graph_planning_rel_paths.push(current_rel_path)
  self.plan_with_path(
    current_rel_path,
    None,
    source,
    inherited_defs,
    [],
    false,
    false,
  )
  self.session.graph_planning_rel_paths.pop() |> ignore
  self.session.graph_execution_complete = true
}
