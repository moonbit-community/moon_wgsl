///|
fn wgsl_item_extraction_contains_requested_item(
  extraction : WgslModuleItemExtraction,
  requested_item : String,
) -> Bool {
  for origin in extraction.origins() {
    if origin.name() == requested_item {
      return true
    }
  }
  false
}

///|
fn wgsl_requested_items_contains(
  requested_items : Array[String],
  item_name : String,
) -> Bool {
  for requested_item in requested_items {
    if requested_item == item_name {
      return true
    }
  }
  false
}

///|
fn wgsl_import_rel_path_is_glsl_frontend(rel_path : String) -> Bool {
  normalize_shader_rel_path(rel_path).has_suffix(".glsl")
}

///|
fn wgsl_item_extraction_contains_all_requested_items(
  extraction : WgslModuleItemExtraction,
  requested_items : Array[String],
) -> Bool {
  for requested_item in requested_items {
    if !wgsl_item_extraction_contains_requested_item(extraction, requested_item) {
      return false
    }
  }
  true
}

///|
fn wgsl_import_candidate_error_path(
  module_path : String,
  requested_items : Array[String],
) -> String {
  if requested_items.length() == 0 {
    return module_path
  }
  let item_list = requested_items.join(",")
  "\{module_path}::{\{item_list}}"
}

///|
fn Composer::select_wgsl_import_candidate_rel_path(
  self : Composer,
  module_path : String,
  default_rel_path : String,
  requested_items : Array[String],
  session : WgslComposeSession,
  importer_defs : WgslActiveComposeDefs,
) -> String raise ComposerError {
  if requested_items.length() == 0 {
    return default_rel_path
  }
  let candidate_rel_paths = self.registry.candidate_rel_paths_for_module_path(
    module_path,
  )
  if candidate_rel_paths.length() == 0 {
    return default_rel_path
  }
  let supporting_rel_paths : Array[String] = []
  for candidate_rel_path in candidate_rel_paths {
    let candidate_source = match
      self.registry.registered_source(candidate_rel_path) {
      Some(source) => source
      None => raise ComposerError::MissingRegisteredSource(candidate_rel_path)
    }
    let candidate_defs = self.active_compose_defs_for_rel_path(
      candidate_rel_path,
      session,
      Some(importer_defs),
    )
    let active_candidate_source = apply_wgsl_template_consts(
      apply_wgsl_ifdefs_strict_for_compose(candidate_source, candidate_defs),
      candidate_defs.value_defines,
    )
    let extraction = extract_wgsl_module_item_origins_strict(
      active_candidate_source, requested_items,
    ) catch {
      error => raise composer_error_from_wgsl_parse_error(error)
    }
    if wgsl_item_extraction_contains_all_requested_items(
        extraction, requested_items,
      ) {
      supporting_rel_paths.push(candidate_rel_path)
    }
  }
  if supporting_rel_paths.length() == 1 {
    return supporting_rel_paths[0]
  }
  if supporting_rel_paths.length() == 0 {
    return default_rel_path
  }
  let import_path = wgsl_import_candidate_error_path(
    module_path, requested_items,
  )
  let rel_path_list = supporting_rel_paths.join(", ")
  raise ComposerError::AmbiguousImportBinding(
    "multiple registered WGSL modules define \{import_path}: \{rel_path_list}",
  )
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
      Parse(message, _) => raise ComposerError::FailedToResolveImport(message)
    }
  }
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
    guard
      resolve_wgsl_semantic_import_module(
        current_rel_path,
        target.raw_path,
        self.registry,
        session.modules,
      )
      is Some(base_resolved_module) else {
      raise ComposerError::FailedToResolveImport(target.raw_path)
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
        requests,
        module_path,
        selected_rel_path,
        module_alias,
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
      }
    } else {
      requests.push(WgslImportRequest::{
        module_path,
        rel_path: selected_rel_path,
        import_full_module,
        keep_requested_items: requested_items.length() > 0,
        requested_items,
        alias_name: module_alias,
      })
    }
  }
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
    let base_resolved_module = target_plan.resolved_module
    let module_path = base_resolved_module.module_path()
    let import_source = match
      self.registry.registered_source(base_resolved_module.rel_path()) {
      Some(source) => source
      None =>
        raise ComposerError::MissingRegisteredSource(
          base_resolved_module.rel_path(),
        )
    }
    let import_defs = self.active_compose_defs_for_rel_path(
      base_resolved_module.rel_path(),
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
      if target_plan.keep_requested_items && requested_items.length() > 0 {
        let live_requested_items : Array[String] = []
        for requested_item in requested_items {
          let requested_item_is_live = wgsl_semantic_source_contains_reference_path(
            active_scan_source, requested_item,
          ) catch {
            error => raise composer_error_from_wgsl_parse_error(error)
          }
          let leaf_item_is_live = match
            split_last_wgsl_semantic_path(requested_item) {
            Some((_, leaf_name)) =>
              wgsl_semantic_source_contains_reference_path(
                active_scan_source, leaf_name,
              ) catch {
                error => raise composer_error_from_wgsl_parse_error(error)
              }
            None => false
          }
          if requested_item_is_live || leaf_item_is_live {
            live_requested_items.push(requested_item)
          }
        }
        requested_items.clear()
        for requested_item in live_requested_items {
          requested_items.push(requested_item)
        }
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
    if glsl_frontend_import {
      import_full_module = true
    }
    let selected_rel_path = self.select_wgsl_import_candidate_rel_path(
      module_path,
      base_resolved_module.rel_path(),
      requested_items,
      session,
      importer_defs,
    )
    let resolved_module = WgslResolvedImportModule(
      module_path, selected_rel_path,
    )
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
