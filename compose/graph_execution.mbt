///|
fn WgslComposeSession::record_graph_planned_request(
  self : WgslComposeSession,
  importer_rel_path : String,
  request : WgslImportRequest,
) -> Unit {
  self.graph_planned_requests.set(
    wgsl_import_request_visit_key(importer_rel_path, request),
    true,
  )
}

///|
fn WgslComposeSession::graph_request_is_planned(
  self : WgslComposeSession,
  importer_rel_path : String,
  request : WgslImportRequest,
) -> Bool {
  self.graph_planned_requests.contains(
    wgsl_import_request_visit_key(importer_rel_path, request),
  )
}

///|
fn WgslComposeSession::record_graph_planned_full_module(
  self : WgslComposeSession,
  rel_path : String,
  alias_name : String,
) -> Unit {
  self.graph_planned_requests.set(
    wgsl_full_module_visit_key(rel_path, alias_name),
    true,
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
) -> String {
  match self.modules.get(module_path) {
    Some(rel_path) => rel_path
    None => ""
  }
}

///|
fn WgslComposeSession::module_path_for_rel_path(
  self : WgslComposeSession,
  rel_path : String,
) -> String {
  let normalized_rel = normalize_shader_rel_path(rel_path)
  for entry in self.modules.iter() {
    let (module_path, module_rel_path) = entry
    if normalize_shader_rel_path(module_rel_path) == normalized_rel {
      return module_path
    }
  }
  ""
}

///|
fn record_wgsl_virtual_override_final_names_from_source(
  session : WgslComposeSession,
  rel_path : String,
  source : String,
) -> Unit {
  let composing_root = session.graph_planning_rel_paths.length() <= 1 &&
    session.active_rel_paths.length() <= 1
  let override_module_path = if composing_root {
    ""
  } else {
    session.module_path_for_rel_path(rel_path)
  }
  let targets = collect_wgsl_virtual_override_targets_strict(source) catch {
    _ => return
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
    if target_module_path != "" &&
      session.module_rel_path_for_module_path(target_module_path) == "" {
      continue
    }
    let target_name = wgsl_naga_oil_decorated_final_name(
      target_module_path, original_name,
    )
    let override_name = wgsl_naga_oil_virtual_override_final_name(
      target_module_path, override_module_path, original_name,
    )
    session.record_virtual_override_final_name(
      raw_target, target_name, override_name,
    )
  }
}

///|
fn record_wgsl_planned_final_names_from_extraction(
  session : WgslComposeSession,
  rel_path : String,
  alias_prefixes : Array[String],
  extraction : WgslModuleItemExtraction,
) -> Unit {
  if rel_path == "" {
    return
  }
  for origin in extraction.origins() {
    let identity = WgslIrSymbolIdentity::new(rel_path, origin.name())
    let final_name = wgsl_compose_assigned_final_name(
      session.module_path_for_rel_path(rel_path),
      alias_prefixes,
      origin.name(),
    )
    if alias_prefixes.length() == 0 {
      session.assign_canonical_final_name(identity, final_name)
    } else {
      session.assign_alias_final_name(
        WgslIrAliasSymbolIdentity::new(
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
    session, rel_path, alias_prefixes, extraction,
  )
}

///|
fn Composer::plan_wgsl_compose_graph_with_path(
  self : Composer,
  current_rel_path : String,
  source : String,
  session : WgslComposeSession,
  inherited_defs : WgslActiveComposeDefs?,
  alias_prefixes : Array[String],
) -> Unit raise ComposerError {
  let active_defs = self.active_compose_defs_for_rel_path(
    current_rel_path, session, inherited_defs,
  )
  merge_wgsl_source_local_shader_defs(active_defs, source)
  let prepared = prepare_wgsl_compose_source(source, session, active_defs)
  record_wgsl_planned_final_names_from_source(
    session,
    current_rel_path,
    prepared.active_source,
    alias_prefixes,
  )
  let implicit_requests = self.build_wgsl_implicit_import_requests(
    current_rel_path,
    prepared.active_scan_source,
    session,
    active_defs,
  )
  self.plan_wgsl_import_request_batch(
    current_rel_path, implicit_requests, session, active_defs, alias_prefixes,
  )
  for
    item in parse_wgsl_directive_scan_items(
      prepared.active_source,
      include_glsl_version=false,
    ) {
    match item.kind() {
      WgslDirectiveScanItemKind::Directive(import_directive) if import_directive.kind() ==
        WgslDirectiveKind::Import => {
        let requests = self.build_wgsl_import_requests(
          current_rel_path,
          import_directive.tail(),
          prepared.active_scan_source,
          session,
          active_defs,
        )
        self.plan_wgsl_import_request_batch(
          current_rel_path, requests, session, active_defs, alias_prefixes,
        )
      }
      _ => ()
    }
  }
}

///|
fn Composer::plan_wgsl_import_request_batch(
  self : Composer,
  current_rel_path : String,
  requests : Array[WgslImportRequest],
  session : WgslComposeSession,
  importer_defs : WgslActiveComposeDefs,
  alias_prefixes : Array[String],
) -> Unit raise ComposerError {
  record_wgsl_import_request_batch_link_edges(
    session.link_graph,
    current_rel_path,
    requests,
  )
  for request in requests {
    if session.graph_request_is_planned(current_rel_path, request) {
      continue
    }
    session.record_graph_planned_request(current_rel_path, request)
    let request_alias_prefixes = alias_prefixes.copy()
    if request.alias_name != "" {
      request_alias_prefixes.push(
        wgsl_semantic_import_alias_prefix(request.alias_name),
      )
    }
    let request_alias_scope = request_alias_prefixes.join("__")
    if request.import_full_module &&
      session.graph_full_module_is_planned(
        request.rel_path,
        request_alias_scope,
      ) {
      continue
    }
    if wgsl_path_stack_contains(
        session.graph_planning_rel_paths,
        request.rel_path,
      ) {
      raise ComposerError::ImportCycle(
        wgsl_import_cycle_string(
          session.graph_planning_rel_paths,
          request.rel_path,
        ),
      )
    }
    if request.import_full_module {
      session.record_graph_planned_full_module(
        request.rel_path,
        request_alias_scope,
      )
    }
    let raw_source = self.load_wgsl_source_required_raw(request.rel_path)
    session.graph_planning_rel_paths.push(request.rel_path)
    if request.import_full_module {
      self.plan_wgsl_compose_graph_with_path(
        request.rel_path,
        raw_source,
        session,
        Some(importer_defs),
        request_alias_prefixes,
      )
    } else {
      let import_defs = self.active_compose_defs_for_rel_path(
        request.rel_path,
        session,
        Some(importer_defs),
      )
      let prepared_source = apply_wgsl_template_consts(
        apply_wgsl_ifdefs_strict_for_compose(raw_source, import_defs),
        import_defs.value_defines,
      )
      let extraction = extract_wgsl_module_item_origins_strict(
        prepared_source,
        request.requested_items,
      ) catch {
        error => raise composer_error_from_wgsl_parse_error(error)
      }
      record_wgsl_planned_final_names_from_extraction(
        session,
        request.rel_path,
        request_alias_prefixes,
        extraction,
      )
      self.plan_wgsl_compose_graph_with_path(
        request.rel_path,
        extraction.source(),
        session,
        Some(importer_defs),
        request_alias_prefixes,
      )
    }
    session.graph_planning_rel_paths.pop() |> ignore
  }
}

///|
fn Composer::complete_wgsl_compose_graph_execution(
  self : Composer,
  current_rel_path : String,
  source : String,
  session : WgslComposeSession,
  inherited_defs : WgslActiveComposeDefs?,
) -> Unit raise ComposerError {
  if session.graph_execution_complete {
    return
  }
  session.graph_planning_rel_paths.push(current_rel_path)
  self.plan_wgsl_compose_graph_with_path(
    current_rel_path,
    source,
    session,
    inherited_defs,
    [],
  )
  session.graph_planning_rel_paths.pop() |> ignore
  session.graph_execution_complete = true
}
