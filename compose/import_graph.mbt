///|
priv struct WgslPreparedComposeSource {
  active_source : String
  active_scan_source : String
}

///|
fn record_wgsl_nested_flattened_item_names(
  session : WgslComposeSession,
  declarations : Array[WgslEmittedDeclaration],
) -> Unit {
  for declaration in declarations {
    let generated_name = declaration.name()
    if generated_name == "" {
      continue
    }
    if !declaration.is_type_declaration() {
      continue
    }
    for entry in session.modules.iter() {
      let (module_path, rel_path) = entry
      let module_alias_name = wgsl_semantic_import_default_alias(module_path)
      if module_alias_name == "" {
        continue
      }
      let marker = "__\{module_alias_name}__"
      let mut saw_marker = false
      let mut item_name = ""
      for part in generated_name.split(marker) {
        if saw_marker {
          item_name = part.to_owned()
        }
        saw_marker = true
      }
      if item_name != "" {
        session.record_canonical_final_name_if_absent(
          WgslSymbolIdentity::new(rel_path, item_name),
          generated_name,
        )
      }
    }
  }
}

///|
fn prepare_wgsl_compose_source(
  source : String,
  session : WgslComposeSession,
  active_defs : WgslActiveComposeDefs,
) -> WgslPreparedComposeSource raise ComposerError {
  record_wgsl_redirect_matches(source, session)
  let redirect_map = build_wgsl_symbol_redirect_map(session.redirects)
  let redirected_source = rewrite_wgsl_references_with_rename_map(
    source, redirect_map,
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
) -> String raise ComposerError {
  let mut merged = ""
  for request in requests {
    if !session.graph_request_is_planned(current_rel_path, request) {
      raise ComposerError::FailedToResolveImport(
        "internal compose graph is missing planned request \{wgsl_import_request_visit_key(current_rel_path, request)}",
      )
    }
    let full_module_key = wgsl_full_module_visit_key(
      request.rel_path,
      request.alias_name,
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
      )
    }
    session.active_rel_paths.pop() |> ignore
    if module_source == "" {
      continue
    }
    let rename_alias = if request.alias_name != "" {
      request.alias_name
    } else {
      ""
    }
    let rename_map : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
    let final_module_source = if rename_alias != "" {
      let request_rename_map = build_wgsl_semantic_import_rename_map(
        module_source, rename_alias,
      ) catch {
        error => raise composer_error_from_wgsl_parse_error(error)
      }
      for entry in request_rename_map.iter() {
        let (from_name, to_name) = entry
        rename_map.set(from_name, to_name)
      }
      if request.alias_name != "" {
        for entry in rename_map.iter() {
          let (original_name, generated_name) = entry
          bindings.push(
            WgslComposeBinding::for_alias_symbol(
              request.rel_path,
              request.alias_name,
              original_name,
              generated_name,
              QualifiedAliasBinding,
            ),
          )
        }
      }
      rewrite_wgsl_declarations_with_global_rename_map(
        module_source, request_rename_map,
      ) catch {
        error => raise composer_error_from_wgsl_parse_error(error)
      }
    } else {
      module_source
    }
    apply_wgsl_origin_renames(
      session.source_origins,
      origin_start_index,
      rename_map,
    )
    for i in origin_start_index..<session.source_origins.length() {
      let origin = session.source_origins[i]
      if origin.rel_path != "" &&
        origin.source_symbol_name != "" &&
        origin.generated_symbol_name != "" {
        if request.alias_name == "" {
          session.record_canonical_final_name_if_absent(
            WgslSymbolIdentity::new(origin.rel_path, origin.source_symbol_name),
            origin.generated_symbol_name,
          )
        } else {
          let identity = WgslAliasSymbolIdentity::new(
            origin.rel_path,
            request.alias_name,
            origin.source_symbol_name,
          )
          session.record_alias_final_name_if_absent(
            identity,
            origin.generated_symbol_name,
          )
        }
      }
    }
    let final_facts = collect_wgsl_compose_semantic_facts(
      session, final_module_source,
    )
    let final_declarations = final_facts.declarations
    if rename_map.is_empty() {
      record_wgsl_nested_flattened_item_names(session, final_declarations)
      for declaration in final_declarations {
        let declaration_name = declaration.name()
        session.record_canonical_final_name(
          WgslSymbolIdentity::new(request.rel_path, declaration_name),
          declaration_name,
        )
      }
    } else {
      for entry in rename_map.iter() {
        let (from_name, to_name) = entry
        session.record_alias_final_name(
          WgslAliasSymbolIdentity::new(
            request.rel_path,
            request.alias_name,
            from_name,
          ),
          to_name,
        )
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
  let declared_names : @hashmap.HashMap[String, Bool] = @hashmap.HashMap::new()
  for declaration in facts.declarations {
    let declaration_name = declaration.name()
    if declaration_name != "" {
      declared_names.set(declaration_name, true)
    }
  }
  let plan = WgslLiveBindingPlan::new()
  let seen_binding_keys : @hashset.HashSet[String] = @hashset.HashSet::new()
  for binding in bindings.bindings {
    let from_name = binding.from_name.trim().to_owned()
    let to_name = binding.to_name.trim().to_owned()
    let binding_key = wgsl_compose_binding_key(binding)
    if seen_binding_keys.contains(binding_key) {
      continue
    }
    seen_binding_keys.add(binding_key)
    let source_contains_cached_alias = if binding.scope ==
      CachedQualifiedAliasBinding {
      wgsl_semantic_reference_path_set_contains(
        facts.reference_paths,
        from_name,
      )
    } else {
      false
    }
    if to_name != "" &&
      (
        declared_names.contains(to_name) ||
        binding.scope == UnqualifiedItemBinding ||
        source_contains_cached_alias
      ) {
      plan.push(binding)
    }
  }
  plan
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
  let rewrite_plan = live_bindings.reference_rewrite_plan()
  if apply_virtual_overrides {
    out = apply_wgsl_virtual_overrides_with_binding_plan(out, rewrite_plan)
  } else {
    out = rewrite_wgsl_override_targets_with_binding_plan(out, rewrite_plan)
  }
  out = rewrite_wgsl_references_with_binding_plan(out, rewrite_plan) catch {
    error => raise composer_error_from_wgsl_parse_error(error)
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
