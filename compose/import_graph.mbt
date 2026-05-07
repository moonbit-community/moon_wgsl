///|
priv struct WgslPreparedComposeSource {
  active_source : String
  active_scan_source : String
}

///|
priv struct WgslModuleFinalNameApplication {
  origin_index : Int
  rel_path : String
  original_name : String
  current_name : String
  final_name : String
}

///|
priv struct WgslModuleFinalNameApplicationPlan {
  entries : Array[WgslModuleFinalNameApplication]
}

///|
fn WgslModuleFinalNameApplicationPlan::WgslModuleFinalNameApplicationPlan() -> WgslModuleFinalNameApplicationPlan {
  WgslModuleFinalNameApplicationPlan::{ entries: [] }
}

///|
fn WgslModuleFinalNameApplicationPlan::is_empty(
  self : WgslModuleFinalNameApplicationPlan,
) -> Bool {
  self.entries.length() == 0
}

///|
fn WgslModuleFinalNameApplicationPlan::push(
  self : WgslModuleFinalNameApplicationPlan,
  origin_index : Int,
  origin : WgslSourceOriginEntry,
  final_name : String,
) -> Unit {
  if final_name == "" || final_name == origin.generated_symbol_name {
    return
  }
  self.entries.push(WgslModuleFinalNameApplication::{
    origin_index,
    rel_path: origin.rel_path,
    original_name: origin.source_symbol_name,
    current_name: origin.generated_symbol_name,
    final_name,
  })
}

///|
fn WgslModuleFinalNameApplicationPlan::reference_rewrite_plan(
  self : WgslModuleFinalNameApplicationPlan,
) -> WgslReferenceRewritePlan {
  let plan = WgslReferenceRewritePlan()
  for entry in self.entries {
    plan.add_symbol_binding(
      entry.rel_path,
      entry.original_name,
      entry.current_name,
      entry.final_name,
    )
  }
  plan
}

///|
fn WgslModuleFinalNameApplicationPlan::apply_to_origins(
  self : WgslModuleFinalNameApplicationPlan,
  origins : Array[WgslSourceOriginEntry],
) -> Unit {
  for entry in self.entries {
    let origin = origins[entry.origin_index]
    origins[entry.origin_index] = WgslSourceOriginEntry(
      entry.final_name,
      origin.rel_path,
      origin.source_symbol_name,
      origin.source_start,
      origin.source_end,
    )
  }
}

///|
fn WgslComposeSession::assigned_final_name_for_origin(
  self : WgslComposeSession,
  origin : WgslSourceOriginEntry,
  alias_prefixes : Array[String],
) -> String? {
  if origin.rel_path == "" ||
    origin.source_symbol_name == "" ||
    origin.generated_symbol_name == "" {
    return None
  }
  let identity = WgslIrSymbolIdentity(
    origin.rel_path,
    origin.source_symbol_name,
  )
  if alias_prefixes.length() == 0 {
    self.assigned_canonical_final_name(identity)
  } else {
    self.assigned_final_names.alias_get(
      WgslIrAliasSymbolIdentity(
        origin.rel_path,
        alias_prefixes.join("__"),
        origin.source_symbol_name,
      ),
    )
  }
}

///|
fn collect_wgsl_module_final_name_application_plan(
  session : WgslComposeSession,
  start_index : Int,
  alias_prefixes : Array[String],
) -> WgslModuleFinalNameApplicationPlan {
  let plan = WgslModuleFinalNameApplicationPlan()
  for i in start_index..<session.source_origins.length() {
    let origin = session.source_origins[i]
    match session.assigned_final_name_for_origin(origin, alias_prefixes) {
      Some(final_name) => plan.push(i, origin, final_name)
      None => ()
    }
  }
  plan
}

///|
fn wgsl_redirect_direct_target(
  redirects : Array[WgslSymbolRedirect],
  name : String,
) -> String? {
  let mut target : String? = None
  for redirect in redirects {
    let from_name = redirect.from_name.trim().to_owned()
    let to_name = redirect.to_name.trim().to_owned()
    if from_name == name && to_name != "" && from_name != to_name {
      target = Some(to_name)
    }
  }
  target
}

///|
fn wgsl_redirect_final_target(
  redirects : Array[WgslSymbolRedirect],
  from_name : String,
) -> String? {
  let seen : Array[String] = []
  let mut current = from_name
  let mut target : String? = None
  while true {
    if seen.contains(current) {
      break
    }
    seen.push(current)
    match wgsl_redirect_direct_target(redirects, current) {
      Some(next) => {
        target = Some(next)
        current = next
      }
      None => break
    }
  }
  target
}

///|
fn build_wgsl_redirect_reference_plan(
  redirects : Array[WgslSymbolRedirect],
) -> WgslReferenceRewritePlan {
  let plan = WgslReferenceRewritePlan()
  for redirect in redirects {
    let from_name = redirect.from_name.trim().to_owned()
    if from_name == "" {
      continue
    }
    match wgsl_redirect_final_target(redirects, from_name) {
      Some(to_name) =>
        if to_name != "" && to_name != from_name {
          plan.add(from_name, to_name)
        }
      None => ()
    }
  }
  plan
}

///|
fn prepare_wgsl_compose_source(
  source : String,
  session : WgslComposeSession,
  active_defs : WgslActiveComposeDefs,
) -> WgslPreparedComposeSource raise ComposerError {
  record_wgsl_redirect_matches(source, session)
  let redirect_plan = build_wgsl_redirect_reference_plan(session.redirects)
  let redirected_source = rewrite_wgsl_references_with_binding_plan(
    source, redirect_plan,
  ) catch {
    error => raise composer_error_from_wgsl_parse_error(error)
  }
  let active_source = apply_wgsl_template_consts(
    apply_wgsl_ifdefs_strict_for_compose(redirected_source, active_defs),
    active_defs.value_defines,
  )
  let active_scan_source = active_source
  WgslPreparedComposeSource::{ active_source, active_scan_source }
}

///|
fn collect_wgsl_compose_semantic_facts(
  session : WgslComposeSession,
  source : String,
) -> WgslComposeSemanticFacts raise ComposerError {
  match session.semantic_facts.get(source) {
    Some(facts) => facts
    None => {
      let declarations = collect_wgsl_named_declarations_strict(source) catch {
        error => raise composer_error_from_wgsl_parse_error(error)
      }
      let reference_paths = collect_wgsl_semantic_reference_path_set(source) catch {
        error => raise composer_error_from_wgsl_parse_error(error)
      }
      let facts = WgslComposeSemanticFacts::{ declarations, reference_paths }
      session.semantic_facts.set(source, facts)
      facts
    }
  }
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
      Parse(message, _) => raise ComposerError::FailedToResolveImport(message)
    }
  }
  self.build_wgsl_import_requests_from_targets(
    current_rel_path, targets, active_scan_source, session, importer_defs,
  )
}

///|
fn Composer::build_wgsl_import_requests_from_targets(
  self : Composer,
  current_rel_path : String,
  targets : Array[WgslImportTarget],
  active_scan_source : String,
  session : WgslComposeSession,
  importer_defs : WgslActiveComposeDefs,
) -> Array[WgslImportRequest] raise ComposerError {
  let requests : Array[WgslImportRequest] = []
  let target_plans = build_wgsl_semantic_import_target_plans(
    active_scan_source,
    current_rel_path,
    targets,
    self.registry,
    session.modules,
  ) catch {
    error => raise composer_error_from_wgsl_parse_error(error)
  }
  if target_plans.unresolved_targets.length() > 0 {
    raise ComposerError::FailedToResolveImport(
      target_plans.unresolved_targets[0],
    )
  }
  for target_plan in target_plans.plans {
    let requested_items = target_plan.requested_items
    let resolved_module = target_plan.resolved_module
    let module_path = resolved_module.module_path()
    let import_source = match
      self.registry.registered_source(resolved_module.rel_path()) {
      Some(source) => source
      None => ""
    }
    let import_defs = self.active_compose_defs_for_rel_path(
      resolved_module.rel_path(),
      session,
      Some(importer_defs),
    )
    let active_import_source = apply_wgsl_template_consts(
      apply_wgsl_ifdefs_strict_for_compose(import_source, import_defs),
      import_defs.value_defines,
    )
    let imports_for_override_side_effect = wgsl_source_contains_override_directive(
      active_import_source,
    )
    let imports_for_virtual_side_effect = wgsl_source_contains_virtual_directive(
      active_import_source,
    )
    let mut module_alias = target_plan.module_alias
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
        !imports_for_virtual_side_effect {
        continue
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
        !imports_for_virtual_side_effect {
        continue
      }
    }
    if !import_full_module {
      let active_facts = collect_wgsl_compose_semantic_facts(
        session, active_scan_source,
      )
      let used_requested_items : Array[String] = []
      for requested_item in requested_items {
        let item_is_live = if target_plan.explicit_item_binding {
          wgsl_semantic_reference_path_set_contains(
            active_facts.reference_paths,
            requested_item,
          )
        } else {
          true
        }
        if item_is_live {
          used_requested_items.push(requested_item)
        }
      }
      requested_items.clear()
      for requested_item in used_requested_items {
        requested_items.push(requested_item)
      }
      if requested_items.length() == 0 &&
        !imports_for_override_side_effect &&
        !imports_for_virtual_side_effect {
        continue
      }
      if imports_for_override_side_effect || imports_for_virtual_side_effect {
        import_full_module = true
      }
    }
    if find_wgsl_import_request_index(
        requests,
        module_path,
        resolved_module.rel_path(),
        module_alias,
      )
      is Some(request_index) {
      let request = requests[request_index]
      if import_full_module {
        request.import_full_module = true
      }
      if target_plan.keep_requested_items {
        request.keep_requested_items = true
      }
      for requested_item in requested_items {
        composer_string_list_push_unique(
          request.requested_items,
          requested_item,
        )
      }
    } else {
      requests.push(WgslImportRequest::{
        module_path,
        rel_path: resolved_module.rel_path(),
        import_full_module,
        keep_requested_items: target_plan.keep_requested_items,
        requested_items,
        alias_name: module_alias,
      })
    }
  }
  requests
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
  collect_wgsl_semantic_qualified_module_targets(
    active_scan_source,
    current_rel_path,
    self.registry,
    session.modules,
    qualified_targets,
  ) catch {
    _ => return []
  }
  self.build_wgsl_import_requests_from_targets(
    current_rel_path, qualified_targets, active_scan_source, session, importer_defs,
  )
}

///|
fn Composer::compose_wgsl_import_requests(
  self : Composer,
  current_rel_path : String,
  requests : Array[WgslImportRequest],
  bindings : WgslComposeBindingSet,
  session : WgslComposeSession,
  importer_defs : WgslActiveComposeDefs,
  alias_prefixes : Array[String],
) -> String raise ComposerError {
  let mut merged = ""
  for request in requests {
    if !session.graph_request_is_planned(current_rel_path, request) {
      raise ComposerError::FailedToResolveImport(
        "internal compose graph is missing planned request \{wgsl_import_request_visit_key(current_rel_path, request)}",
      )
    }
    let request_alias_prefixes = alias_prefixes.copy()
    if request.alias_name != "" {
      request_alias_prefixes.push(
        wgsl_semantic_import_alias_prefix(request.alias_name),
      )
    }
    let request_alias_scope = request_alias_prefixes.join("__")
    let full_module_key = wgsl_full_module_visit_key(
      request.rel_path,
      request_alias_scope,
    )
    if wgsl_path_stack_contains(session.active_rel_paths, request.rel_path) {
      raise ComposerError::ImportCycle(
        wgsl_import_cycle_string(session.active_rel_paths, request.rel_path),
      )
    }
    if request.import_full_module {
      if session.visited.contains(full_module_key) {
        collect_wgsl_cached_import_bindings(
          session,
          request.rel_path,
          request.alias_name,
          request_alias_scope,
          bindings,
        )
        |> ignore
        continue
      }
    }
    if !request.import_full_module && request.alias_name == "" {
      let mut resolved_requested_items = 0
      for requested_item in request.requested_items {
        match
          find_wgsl_visible_alias_imported_item_binding(
            bindings,
            request.module_path,
            requested_item,
          ) {
          Some(binding) => {
            bindings.push(binding)
            resolved_requested_items = resolved_requested_items + 1
          }
          None =>
            match
              find_wgsl_visible_identity_imported_item_binding(
                bindings,
                request.rel_path,
                requested_item,
              ) {
              Some(binding) => {
                bindings.push(binding)
                resolved_requested_items = resolved_requested_items + 1
              }
              None =>
                match
                  find_wgsl_cached_imported_item_name(
                    session,
                    request.rel_path,
                    requested_item,
                  ) {
                  Some(imported_name) => {
                    bindings.push(
                      WgslComposeBinding::for_unqualified_symbol(
                        request.rel_path,
                        requested_item,
                        imported_name,
                        UnqualifiedItemBinding,
                      ),
                    )
                    resolved_requested_items = resolved_requested_items + 1
                  }
                  None => ()
                }
            }
        }
      }
      if request.requested_items.length() > 0 &&
        resolved_requested_items == request.requested_items.length() {
        continue
      }
    }
    let visit_key = wgsl_import_request_visit_key(current_rel_path, request)
    if session.visited.contains(visit_key) {
      continue
    }
    session.visited.set(visit_key, true)
    let raw_source = self.load_wgsl_source_required_raw(request.rel_path)
    let origin_start_index = session.source_origins.length()
    session.active_rel_paths.push(request.rel_path)
    let module_source = if request.import_full_module {
      self.preprocess_wgsl_source_with_path(
        request.rel_path,
        raw_source,
        session,
        Some(importer_defs),
        bindings,
        false,
        true,
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
      record_wgsl_source_origins_from_extraction(
        session,
        request.rel_path,
        extraction,
      )
      self.preprocess_wgsl_source_with_path(
        request.rel_path,
        extraction.source(),
        session,
        Some(importer_defs),
        bindings,
        false,
        false,
        request_alias_prefixes,
      )
    }
    session.active_rel_paths.pop() |> ignore
    if module_source == "" {
      continue
    }
    let final_name_plan = collect_wgsl_module_final_name_application_plan(
      session, origin_start_index, request_alias_prefixes,
    )
    let final_module_source = if !final_name_plan.is_empty() {
      rewrite_wgsl_declarations_with_binding_plan(
        module_source,
        final_name_plan.reference_rewrite_plan(),
      ) catch {
        error => raise composer_error_from_wgsl_parse_error(error)
      }
    } else {
      module_source
    }
    final_name_plan.apply_to_origins(session.source_origins)
    if request.alias_name != "" {
      for i in origin_start_index..<session.source_origins.length() {
        let origin = session.source_origins[i]
        if origin.rel_path == request.rel_path &&
          origin.source_symbol_name != "" &&
          origin.generated_symbol_name != "" {
          bindings.push(
            WgslComposeBinding::for_alias_symbol(
              origin.rel_path,
              request.alias_name,
              origin.source_symbol_name,
              origin.generated_symbol_name,
              QualifiedAliasBinding,
            ),
          )
        }
      }
    } else if !request.import_full_module {
      for i in origin_start_index..<session.source_origins.length() {
        let origin = session.source_origins[i]
        if origin.rel_path == request.rel_path &&
          origin.source_symbol_name != "" &&
          origin.generated_symbol_name != "" {
          bindings.push(
            WgslComposeBinding::for_unqualified_symbol(
              origin.rel_path,
              origin.source_symbol_name,
              origin.generated_symbol_name,
              UnqualifiedItemBinding,
            ),
          )
        }
      }
    }
    for i in origin_start_index..<session.source_origins.length() {
      let origin = session.source_origins[i]
      if origin.rel_path != "" &&
        origin.source_symbol_name != "" &&
        origin.generated_symbol_name != "" {
        if request.alias_name == "" {
          session.record_canonical_final_name_if_absent(
            WgslIrSymbolIdentity(origin.rel_path, origin.source_symbol_name),
            origin.generated_symbol_name,
          )
        } else if origin.rel_path == request.rel_path {
          let identity = WgslIrAliasSymbolIdentity(
            origin.rel_path,
            request_alias_scope,
            origin.source_symbol_name,
          )
          session.record_alias_final_name_if_absent(
            identity,
            origin.generated_symbol_name,
          )
        }
      }
    }
    if request.import_full_module {
      session.visited.set(full_module_key, true)
    }
    merged = "\{merged}\{final_module_source}"
    if !merged.has_suffix("\n") {
      merged = "\{merged}\n"
    }
  }
  merged
}

///|
fn collect_wgsl_live_binding_plan(
  facts : WgslComposeSemanticFacts,
  bindings : WgslComposeBindingSet,
) -> WgslLiveBindingPlan {
  WgslComposeSemanticIr::from_facts_and_bindings(facts, bindings).live_binding_plan()
}

///|
fn finalize_wgsl_composed_source(
  merged : String,
  bindings : WgslComposeBindingSet,
  active_defs : WgslActiveComposeDefs,
  session : WgslComposeSession,
  apply_virtual_overrides : Bool,
) -> String raise ComposerError {
  let mut out = apply_wgsl_ifdefs_strict_for_compose(merged, active_defs)
  out = apply_wgsl_template_consts(out, active_defs.value_defines)
  session.composed_bindings.extend(bindings)
  let effective_bindings = if apply_virtual_overrides {
    session.composed_bindings
  } else {
    bindings
  }
  let out_facts = collect_wgsl_compose_semantic_facts(session, out)
  let live_bindings = collect_wgsl_live_binding_plan(
    out_facts, effective_bindings,
  )
  let rewrite_plan = live_bindings.reference_rewrite_plan(session)
  if apply_virtual_overrides {
    out = rewrite_wgsl_references_with_binding_plan(out, rewrite_plan) catch {
      error => raise composer_error_from_wgsl_parse_error(error)
    }
    out = apply_wgsl_virtual_overrides_with_binding_plan(out, rewrite_plan)
  } else {
    out = rewrite_wgsl_override_targets_with_binding_plan(out, rewrite_plan)
    out = rewrite_wgsl_references_with_binding_plan(out, rewrite_plan) catch {
      error => raise composer_error_from_wgsl_parse_error(error)
    }
  }
  if !apply_virtual_overrides {
    validate_wgsl_translation_unit_strict(out)
    return out
  }
  out = normalize_wgsl_composed_declarations_with_binding_plan(
    out, rewrite_plan,
  ) catch {
    error => raise composer_error_from_wgsl_parse_error(error)
  }
  let unresolved_namespace = unresolved_wgsl_semantic_namespace_reference(out) catch {
    error => raise composer_error_from_wgsl_parse_error(error)
  }
  if unresolved_namespace is Some(path) {
    raise ComposerError::FailedToResolveImport(path)
  }
  validate_wgsl_translation_unit_strict(out)
  out
}
