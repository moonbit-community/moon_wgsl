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
fn Composer::plan_wgsl_compose_graph_with_path(
  self : Composer,
  current_rel_path : String,
  source : String,
  session : WgslComposeSession,
  inherited_defs : WgslActiveComposeDefs?,
) -> Unit raise ComposerError {
  let active_defs = self.active_compose_defs_for_rel_path(
    current_rel_path, session, inherited_defs,
  )
  merge_wgsl_source_local_shader_defs(active_defs, source)
  let prepared = prepare_wgsl_compose_source(source, session, active_defs)
  let implicit_requests = self.build_wgsl_implicit_import_requests(
    current_rel_path,
    prepared.active_scan_source,
    session,
    active_defs,
  )
  self.plan_wgsl_import_request_batch(
    current_rel_path, implicit_requests, session, active_defs,
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
          current_rel_path, requests, session, active_defs,
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
) -> Unit raise ComposerError {
  session.symbol_graph.record_request_batch_edges(current_rel_path, requests)
  for request in requests {
    if session.graph_request_is_planned(current_rel_path, request) {
      continue
    }
    session.record_graph_planned_request(current_rel_path, request)
    if request.import_full_module &&
      session.graph_full_module_is_planned(request.rel_path, request.alias_name) {
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
        request.alias_name,
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
      self.plan_wgsl_compose_graph_with_path(
        request.rel_path,
        extraction.source(),
        session,
        Some(importer_defs),
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
    current_rel_path, source, session, inherited_defs,
  )
  session.graph_planning_rel_paths.pop() |> ignore
  session.graph_execution_complete = true
}
