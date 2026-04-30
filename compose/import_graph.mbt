///|
priv struct WgslPreparedComposeSource {
  active_source : String
  active_scan_source : String
}

///|
fn prepare_wgsl_compose_source(
  source : String,
  session : WgslComposeSession,
  active_defs : WgslActiveComposeDefs,
) -> WgslPreparedComposeSource raise ComposerError {
  record_wgsl_redirect_matches(source, session)
  let redirected_source = rewrite_wgsl_symbol_redirects(
    source,
    session.redirects,
  )
  let active_source = apply_wgsl_template_consts(
    apply_wgsl_ifdefs_strict_for_compose(redirected_source, active_defs),
    active_defs.value_defines,
  )
  WgslPreparedComposeSource::{
    active_source,
    active_scan_source: strip_wgsl_import_declarations(active_source),
  }
}

///|
fn compose_import_spec_is_empty_or_final_semicolon(spec : String) -> Bool {
  let tokens = tokenize(spec, false)
  if tokens.length() == 0 {
    return true
  }
  if tokens.length() == 1 && tokens[0] is WgslToken::Other(59, _) {
    return true
  }
  false
}

///|
fn Composer::build_wgsl_import_requests(
  self : Composer,
  current_rel_path : String,
  spec : String,
  active_scan_source : String,
  session : WgslComposeSession,
) -> Array[WgslImportRequest] raise ComposerError {
  let targets : Array[WgslImportTarget] = []
  if !compose_import_spec_is_empty_or_final_semicolon(spec) {
    parse_wgsl_import_targets(spec, "", targets) catch {
      Parse(message, _) => raise ComposerError::FailedToResolveImport(message)
    }
  }
  self.build_wgsl_import_requests_from_targets(
    current_rel_path, targets, active_scan_source, session,
  )
}

///|
fn Composer::build_wgsl_import_requests_from_targets(
  self : Composer,
  current_rel_path : String,
  targets : Array[WgslImportTarget],
  active_scan_source : String,
  session : WgslComposeSession,
) -> Array[WgslImportRequest] raise ComposerError {
  let requests : Array[WgslImportRequest] = []
  let mut target_index = 0
  while target_index < targets.length() {
    let target = targets[target_index]
    target_index = target_index + 1
    let requested_items : Array[String] = []
    let mut request_module_prefix = target.raw_path
    let mut keep_requested_items = false
    if target.alias_name != "" {
      if !wgsl_source_uses_import_alias(active_scan_source, target.alias_name) {
        continue
      }
      let requested_paths : Array[String] = []
      collect_wgsl_alias_requested_paths(
        active_scan_source,
        target.alias_name,
        requested_paths,
      )
      for requested_path in requested_paths {
        if split_last_wgsl_path(requested_path) is Some((nested_prefix, _)) {
          wgsl_import_targets_push_unique(targets, WgslImportTarget::{
            raw_path: "\{target.raw_path}::\{nested_prefix}",
            alias_name: "\{target.alias_name}::\{nested_prefix}",
          })
          continue
        }
        composer_string_list_push_unique(requested_items, requested_path)
      }
      if requested_items.length() == 0 {
        continue
      }
    }
    guard resolve_wgsl_import_request_module(
        current_rel_path,
        target.raw_path,
        self.registry,
        session.modules,
      )
      is Some(resolved_module) else {
      raise ComposerError::FailedToResolveImport(target.raw_path)
    }
    let module_path = resolved_module.module_path
    if target.alias_name == "" {
      request_module_prefix = module_path
    }
    let import_source = match
      self.registry.registered_source(resolved_module.rel_path) {
      Some(source) => source
      None => ""
    }
    let imports_for_override_side_effect = wgsl_source_contains_override_directive(
      import_source,
    )
    let imports_for_virtual_side_effect = wgsl_source_contains_virtual_directive(
      import_source,
    )
    let mut module_alias = if target.alias_name != "" {
      target.alias_name
    } else if module_path == target.raw_path {
      wgsl_import_default_alias(module_path)
    } else {
      ""
    }
    let mut import_full_module = module_path == target.raw_path
    if target.alias_name == "" && module_alias != "" {
      let module_alias_is_used = wgsl_source_uses_import_alias(
        active_scan_source, module_alias,
      )
      if !module_alias_is_used &&
        !imports_for_override_side_effect &&
        !imports_for_virtual_side_effect {
        continue
      }
      if (imports_for_override_side_effect || imports_for_virtual_side_effect) &&
        !module_alias_is_used {
        module_alias = ""
      }
      let requested_paths : Array[String] = []
      collect_wgsl_alias_requested_paths(
        active_scan_source, module_alias, requested_paths,
      )
      for requested_path in requested_paths {
        if split_last_wgsl_path(requested_path) is Some((nested_prefix, _)) {
          wgsl_import_targets_push_unique(targets, WgslImportTarget::{
            raw_path: "\{request_module_prefix}::\{nested_prefix}",
            alias_name: "\{module_alias}::\{nested_prefix}",
          })
          continue
        }
        composer_string_list_push_unique(requested_items, requested_path)
      }
      if requested_items.length() > 0 {
        if !imports_for_virtual_side_effect {
          import_full_module = false
        }
      } else if !imports_for_override_side_effect &&
        !imports_for_virtual_side_effect {
        continue
      }
    } else if module_path != target.raw_path {
      import_full_module = false
      keep_requested_items = true
      let requested_item = wgsl_import_requested_item_name(
        target.raw_path,
        module_path,
      )
      if requested_item == "" {
        import_full_module = true
      } else {
        requested_items.push(requested_item)
      }
    }
    if !import_full_module {
      let used_requested_items : Array[String] = []
      for requested_item in requested_items {
        if wgsl_source_contains_identifier(active_scan_source, requested_item) {
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
        resolved_module.rel_path,
        module_alias,
      )
      is Some(request_index) {
      let request = requests[request_index]
      if import_full_module {
        request.import_full_module = true
      }
      if keep_requested_items {
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
        rel_path: resolved_module.rel_path,
        import_full_module,
        keep_requested_items,
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
) -> Array[WgslImportRequest] raise ComposerError {
  let qualified_targets : Array[WgslImportTarget] = []
  collect_wgsl_qualified_module_targets(
    active_scan_source,
    current_rel_path,
    self.registry,
    session.modules,
    qualified_targets,
  )
  self.build_wgsl_import_requests_from_targets(
    current_rel_path, qualified_targets, active_scan_source, session,
  )
}

///|
fn Composer::compose_wgsl_import_requests(
  self : Composer,
  current_rel_path : String,
  requests : Array[WgslImportRequest],
  alias_redirects : Array[WgslSymbolRedirect],
  session : WgslComposeSession,
  importer_defs : WgslActiveComposeDefs,
) -> String raise ComposerError {
  let mut merged = ""
  for request in requests {
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
        collect_wgsl_cached_import_redirects(
          session,
          request.rel_path,
          request.alias_name,
          alias_redirects,
        )
        |> ignore
        continue
      }
    }
    if !request.import_full_module && request.alias_name == "" {
      let mut resolved_requested_items = 0
      for requested_item in request.requested_items {
        match
          find_wgsl_cached_imported_item_name(
            session,
            request.rel_path,
            requested_item,
          ) {
          Some(imported_name) => {
            alias_redirects.push(WgslSymbolRedirect::{
              from_name: requested_item,
              to_name: imported_name,
            })
            resolved_requested_items = resolved_requested_items + 1
          }
          None => ()
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
    session.resolved_source_files.set(request.rel_path, raw_source)
    session.active_rel_paths.push(request.rel_path)
    let module_source = if request.import_full_module {
      self.preprocess_wgsl_source_with_path(
        request.rel_path,
        raw_source,
        session,
        Some(importer_defs),
        false,
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
      let filtered_source = extract_wgsl_module_items(
        prepared_source,
        request.requested_items,
      )
      self.preprocess_wgsl_source_with_path(
        request.rel_path,
        filtered_source,
        session,
        Some(importer_defs),
        false,
      )
    }
    session.active_rel_paths.pop() |> ignore
    if module_source == "" {
      continue
    }
    let rename_map : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
    let final_module_source = if request.alias_name != "" {
      let request_rename_map = build_wgsl_import_rename_map(
        module_source,
        request.alias_name,
      )
      for entry in request_rename_map.iter() {
        let (from_name, to_name) = entry
        rename_map.set(from_name, to_name)
      }
      collect_wgsl_import_alias_redirects(
        request.alias_name,
        request_rename_map,
        alias_redirects,
      )
      rewrite_wgsl_declarations_with_rename_plan(
        module_source,
        build_wgsl_rename_plan_from_redirect_map(
          request_rename_map,
          GlobalDeclarationAndReferences,
        ),
      )
    } else {
      module_source
    }
    if rename_map.is_empty() {
      for declaration in collect_wgsl_named_declarations(final_module_source) {
        session.imported_item_names.set(
          wgsl_imported_item_name_key(request.rel_path, declaration.name),
          declaration.name,
        )
      }
    } else {
      for entry in rename_map.iter() {
        let (from_name, to_name) = entry
        session.imported_item_names.set(
          wgsl_imported_item_name_key(request.rel_path, from_name),
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
fn finalize_wgsl_composed_source(
  merged : String,
  alias_redirects : Array[WgslSymbolRedirect],
  active_defs : WgslActiveComposeDefs,
  session : WgslComposeSession,
  apply_virtual_overrides : Bool,
) -> String raise ComposerError {
  let mut out = apply_wgsl_ifdefs_strict_for_compose(merged, active_defs)
  out = apply_wgsl_template_consts(out, active_defs.value_defines)
  for redirect in alias_redirects {
    session.composed_alias_redirects.push(redirect)
  }
  let effective_alias_redirects = if apply_virtual_overrides {
    session.composed_alias_redirects
  } else {
    alias_redirects
  }
  let alias_redirect_map = build_wgsl_symbol_redirect_map(
    effective_alias_redirects,
  )
  if apply_virtual_overrides {
    out = apply_wgsl_virtual_overrides(out, alias_redirect_map)
  } else {
    out = rewrite_wgsl_override_targets_with_redirects(out, alias_redirect_map)
  }
  out = rewrite_wgsl_declarations_with_rename_plan(
    out,
    build_wgsl_rename_plan_from_redirect_map(alias_redirect_map, ReferencesOnly),
  )
  if !apply_virtual_overrides {
    return out
  }
  out = normalize_wgsl_composed_declarations(out, effective_alias_redirects)
  if unresolved_wgsl_namespace_reference(out) is Some(path) {
    raise ComposerError::FailedToResolveImport(path)
  }
  out
}
