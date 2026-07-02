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
fn wgsl_import_candidate_selection_cache_key(
  module_path : String,
  default_rel_path : String,
  requested_items : Array[String],
  importer_defs : WgslActiveComposeDefs,
) -> String {
  let sorted_items = requested_items.copy()
  sorted_items.sort()
  "\{module_path}|\{normalize_shader_rel_path(default_rel_path)}|\{wgsl_active_defs_cache_key(default_rel_path, importer_defs)}|\{sorted_items.join("|")}"
}

///|
fn Composer::preflight_wgsl_import_targets_without_source_parse(
  self : Composer,
  current_rel_path : String,
  targets : Array[WgslImportTarget],
  session : WgslComposeSession,
) -> Unit raise ComposerError {
  for target in targets {
    if target.alias_name != "" {
      continue
    }
    if resolve_wgsl_semantic_import_module(
        current_rel_path,
        target.raw_path,
        self.registry,
        session.modules,
      )
      is None {
      raise FailedToResolveImport(target.raw_path)
    }
  }
}

///|
fn Composer::collect_wgsl_declared_const_side_effect_items(
  self : Composer,
  request : WgslImportRequest,
  candidate_items : Array[String],
  session : WgslComposeSession,
  importer_defs : WgslActiveComposeDefs,
) -> Array[String] raise ComposerError {
  let processed = self.processed_registered_wgsl_compose_module(
    request.rel_path,
    session,
    Some(importer_defs),
  )
  processed.const_side_effect_items(candidate_items)
}

///|
fn Composer::collect_wgsl_declared_full_module_side_effect_items(
  self : Composer,
  request : WgslImportRequest,
  candidate_items : Array[String],
  session : WgslComposeSession,
  importer_defs : WgslActiveComposeDefs,
) -> Array[String] raise ComposerError {
  let processed = self.processed_registered_wgsl_compose_module(
    request.rel_path,
    session,
    Some(importer_defs),
  )
  processed.resource_side_effect_items(candidate_items)
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
  let selection_cache_key = wgsl_import_candidate_selection_cache_key(
    module_path, default_rel_path, requested_items, importer_defs,
  )
  match session.selected_import_candidate_rel_paths.get(selection_cache_key) {
    Some(cached_rel_path) => return cached_rel_path
    None => ()
  }
  let candidate_rel_paths = self.registry.candidate_rel_paths_for_module_path(
    module_path,
  )
  if candidate_rel_paths.length() == 0 {
    session.selected_import_candidate_rel_paths.set(
      selection_cache_key, default_rel_path,
    )
    return default_rel_path
  }
  if candidate_rel_paths.length() == 1 &&
    normalize_shader_rel_path(candidate_rel_paths[0]) ==
    normalize_shader_rel_path(default_rel_path) {
    session.selected_import_candidate_rel_paths.set(
      selection_cache_key, default_rel_path,
    )
    return default_rel_path
  }
  let supporting_rel_paths : Array[String] = []
  for candidate_rel_path in candidate_rel_paths {
    let candidate = self.processed_registered_wgsl_compose_module(
      candidate_rel_path,
      session,
      Some(importer_defs),
    )
    if candidate.declares_all_items(requested_items) {
      supporting_rel_paths.push(candidate_rel_path)
    }
  }
  if supporting_rel_paths.length() == 1 {
    let selected_rel_path = supporting_rel_paths[0]
    session.selected_import_candidate_rel_paths.set(
      selection_cache_key, selected_rel_path,
    )
    return selected_rel_path
  }
  if supporting_rel_paths.length() == 0 {
    session.selected_import_candidate_rel_paths.set(
      selection_cache_key, default_rel_path,
    )
    return default_rel_path
  }
  let import_path = wgsl_import_candidate_error_path(
    module_path, requested_items,
  )
  let rel_path_list = supporting_rel_paths.join(", ")
  raise AmbiguousImportBinding(
    "multiple registered WGSL modules define \{import_path}: \{rel_path_list}",
  )
}
