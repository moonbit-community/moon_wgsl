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
fn wgsl_source_declares_non_resource_dependency_item(
  source : String,
  item_name : String,
  referenced : Bool,
) -> Bool raise ComposerError {
  let unit = parse_wgsl_translation_unit_strict(source) catch {
    error => raise composer_error_from_wgsl_parse_error(error)
  }
  for decl in unit.declarations() {
    if decl.name() == item_name {
      match decl.data() {
        WgslGlobalDeclData::Struct(_) | WgslGlobalDeclData::TypeAlias(_) =>
          return true
        WgslGlobalDeclData::Const(_)
        | WgslGlobalDeclData::Override(_)
        | WgslGlobalDeclData::Function(_) => return referenced
        _ => return false
      }
    }
  }
  false
}

///|
fn wgsl_global_variable_has_resource_binding(
  global : @ast.WgslGlobalVariable,
) -> Bool {
  let mut has_group = false
  let mut has_binding = false
  for attribute in global.attributes() {
    match attribute.name().name() {
      "group" => has_group = true
      "binding" => has_binding = true
      _ => ()
    }
  }
  has_group && has_binding
}

///|
fn wgsl_compose_parse_decimal_u32(text : String) -> Int? {
  guard text.length() > 0 else { return None }
  let mut value = 0
  for i in 0..<text.length() {
    let code = text.code_unit_at(i).to_int()
    guard code >= 48 && code <= 57 else { return None }
    value = value * 10 + (code - 48)
  }
  Some(value)
}

///|
fn wgsl_compose_hex_digit_value(code : Int) -> Int? {
  if code >= 48 && code <= 57 {
    Some(code - 48)
  } else if code >= 65 && code <= 70 {
    Some(code - 55)
  } else if code >= 97 && code <= 102 {
    Some(code - 87)
  } else {
    None
  }
}

///|
fn wgsl_compose_parse_hex_u32(text : String) -> Int? {
  guard text.length() > 2 else { return None }
  guard text.code_unit_at(0).to_int() == 48 else { return None }
  let marker = text.code_unit_at(1).to_int()
  guard marker == 120 || marker == 88 else { return None }
  let mut value = 0
  for i in 2..<text.length() {
    match wgsl_compose_hex_digit_value(text.code_unit_at(i).to_int()) {
      Some(digit) => value = value * 16 + digit
      None => return None
    }
  }
  Some(value)
}

///|
fn wgsl_compose_attribute_literal_int_value(
  literal : @ast.WgslNumericLiteral,
) -> Int? {
  match literal.category {
    AbstractIntLiteral | I32Literal | U32Literal =>
      match literal.base {
        Decimal => wgsl_compose_parse_decimal_u32(literal.raw_text)
        Hexadecimal => wgsl_compose_parse_hex_u32(literal.raw_text)
      }
    _ => None
  }
}

///|
fn wgsl_compose_attribute_int_value(attribute : @ast.WgslAttribute) -> Int? {
  match attribute.arguments_ref() {
    Some(expr_ref) =>
      match expr_ref.root() {
        Some(node) =>
          match node.kind() {
            Literal(token) =>
              match token.kind() {
                NumericLiteral(literal) =>
                  wgsl_compose_attribute_literal_int_value(literal)
                _ => None
              }
            _ => None
          }
        None => None
      }
    None => None
  }
}

///|
fn wgsl_compose_attribute_named(
  attributes : Array[@ast.WgslAttribute],
  name : String,
) -> @ast.WgslAttribute? {
  for attribute in attributes {
    if attribute.name().name() == name {
      return Some(attribute)
    }
  }
  None
}

///|
fn wgsl_compose_resource_binding_key(group : Int, binding : Int) -> String {
  "\{group}:\{binding}"
}

///|
fn wgsl_global_variable_resource_binding_key(
  global : @ast.WgslGlobalVariable,
) -> String? {
  let attributes = global.attributes()
  match wgsl_compose_attribute_named(attributes, "group") {
    Some(group_attribute) =>
      match wgsl_compose_attribute_named(attributes, "binding") {
        Some(binding_attribute) =>
          match
            (
              wgsl_compose_attribute_int_value(group_attribute),
              wgsl_compose_attribute_int_value(binding_attribute),
            ) {
            (Some(group), Some(binding)) =>
              Some(wgsl_compose_resource_binding_key(group, binding))
            _ => None
          }
        None => None
      }
    None => None
  }
}

///|
fn WgslComposeSession::record_wgsl_source_resource_bindings(
  self : WgslComposeSession,
  source : String,
) -> Unit raise ComposerError {
  let unit = parse_wgsl_translation_unit_strict(source) catch {
    error => raise composer_error_from_wgsl_parse_error(error)
  }
  for decl in unit.declarations() {
    match decl.data() {
      WgslGlobalDeclData::GlobalVariable(global) =>
        match wgsl_global_variable_resource_binding_key(global) {
          Some(key) => self.occupied_resource_bindings.add(key)
          None => ()
        }
      _ => ()
    }
  }
}

///|
fn collect_wgsl_resource_side_effect_items(
  source : String,
  candidate_items : Array[String],
  occupied_resource_bindings : @set.Set[String],
) -> Array[String] raise ComposerError {
  let unit = parse_wgsl_translation_unit_strict(source) catch {
    error => raise composer_error_from_wgsl_parse_error(error)
  }
  let items : Array[String] = []
  for decl in unit.declarations() {
    match decl.data() {
      WgslGlobalDeclData::GlobalVariable(global) =>
        if wgsl_global_variable_has_resource_binding(global) &&
          wgsl_requested_items_contains(candidate_items, global.name().name()) {
          match wgsl_global_variable_resource_binding_key(global) {
            Some(key) if occupied_resource_bindings.contains(key) => ()
            _ => composer_string_list_push_unique(items, global.name().name())
          }
        }
      _ => ()
    }
  }
  items
}

///|
fn merge_wgsl_resource_side_effect_request(
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
      "",
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
      requests.push(WgslImportRequest::{
        module_path: source_request.module_path,
        rel_path: source_request.rel_path,
        import_full_module: false,
        keep_requested_items: true,
        requested_items: wgsl_import_request_copy_items(side_effect_items),
        declared_items: wgsl_import_request_copy_items(side_effect_items),
        alias_name: "",
      })
  }
}

///|
fn Composer::collect_wgsl_declared_full_module_side_effect_items(
  self : Composer,
  request : WgslImportRequest,
  candidate_items : Array[String],
  session : WgslComposeSession,
  importer_defs : WgslActiveComposeDefs,
) -> Array[String] raise ComposerError {
  let import_source = match self.registry.registered_source(request.rel_path) {
    Some(source) => source
    None => raise ComposerError::MissingRegisteredSource(request.rel_path)
  }
  let import_defs = self.active_compose_defs_for_rel_path(
    request.rel_path,
    session,
    Some(importer_defs),
  )
  let active_import_source = apply_wgsl_template_consts(
    apply_wgsl_ifdefs_strict_for_compose(import_source, import_defs),
    import_defs.value_defines,
  )
  collect_wgsl_resource_side_effect_items(
    active_import_source,
    candidate_items,
    session.occupied_resource_bindings,
  )
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
    current_rel_path, targets, active_scan_source, session, importer_defs, true,
  )
}

///|
fn collect_wgsl_import_targets_from_source_directives(
  source : String,
  targets : Array[WgslImportTarget],
) -> Unit raise ComposerError {
  for
    item in parse_wgsl_directive_scan_items(source, include_glsl_version=false) {
    match item.kind() {
      WgslDirectiveScanItemKind::Directive(import_directive) if import_directive.kind() ==
        WgslDirectiveKind::Import =>
        if !parse_wgsl_import_spec_is_empty_or_final_semicolon(
            import_directive.tail(),
          ) {
          parse_wgsl_import_targets(import_directive.tail(), "", targets) catch {
            Parse(message, _) =>
              raise ComposerError::FailedToResolveImport(message)
          }
        }
      _ => ()
    }
  }
}

///|
fn collect_wgsl_single_target_import_targets_from_source_directives(
  source : String,
  targets : Array[WgslImportTarget],
) -> Unit raise ComposerError {
  for
    item in parse_wgsl_directive_scan_items(source, include_glsl_version=false) {
    match item.kind() {
      WgslDirectiveScanItemKind::Directive(import_directive) if import_directive.kind() ==
        WgslDirectiveKind::Import =>
        if !parse_wgsl_import_spec_is_empty_or_final_semicolon(
            import_directive.tail(),
          ) {
          let directive_targets : Array[WgslImportTarget] = []
          parse_wgsl_import_targets(
            import_directive.tail(),
            "",
            directive_targets,
          ) catch {
            Parse(message, _) =>
              raise ComposerError::FailedToResolveImport(message)
          }
          if directive_targets.length() == 1 &&
            directive_targets[0].alias_name == "" {
            targets.push(directive_targets[0])
          }
        }
      _ => ()
    }
  }
}

///|
fn Composer::build_wgsl_import_requests_from_source_directives(
  self : Composer,
  current_rel_path : String,
  active_source : String,
  active_scan_source : String,
  session : WgslComposeSession,
  importer_defs : WgslActiveComposeDefs,
) -> Array[WgslImportRequest] raise ComposerError {
  let targets : Array[WgslImportTarget] = []
  collect_wgsl_import_targets_from_source_directives(active_source, targets)
  self.build_wgsl_import_requests_from_targets(
    current_rel_path, targets, active_scan_source, session, importer_defs, true,
  )
}

///|
fn Composer::build_wgsl_import_requests_from_emitted_item_slice(
  self : Composer,
  current_rel_path : String,
  directive_source : String,
  dependency_scan_source : String,
  session : WgslComposeSession,
  importer_defs : WgslActiveComposeDefs,
) -> Array[WgslImportRequest] raise ComposerError {
  let targets : Array[WgslImportTarget] = []
  collect_wgsl_import_targets_from_source_directives(directive_source, targets)
  let requests = self.build_wgsl_import_requests_from_targets(
    current_rel_path, targets, directive_source, session, importer_defs, true,
  )
  if dependency_scan_source != directive_source {
    let dependency_targets : Array[WgslImportTarget] = []
    collect_wgsl_import_targets_from_source_directives(
      dependency_scan_source, dependency_targets,
    )
    let side_effect_targets : Array[WgslImportTarget] = []
    collect_wgsl_single_target_import_targets_from_source_directives(
      dependency_scan_source, side_effect_targets,
    )
    let dependency_requests = self.build_wgsl_import_requests_from_targets(
      current_rel_path, dependency_targets, dependency_scan_source, session, importer_defs,
      false,
    )
    let declared_dependency_requests = self.build_wgsl_declared_import_requests_from_targets(
      current_rel_path, side_effect_targets, session, importer_defs,
    )
    for declared_request in declared_dependency_requests {
      if declared_request.import_full_module {
        let candidate_items = match
          find_wgsl_import_request_index(
            dependency_requests,
            declared_request.module_path,
            declared_request.rel_path,
            declared_request.alias_name,
          ) {
          Some(request_index) =>
            dependency_requests[request_index].requested_items
          None => []
        }
        if candidate_items.length() == 0 {
          continue
        }
        let side_effect_items = self.collect_wgsl_declared_full_module_side_effect_items(
          declared_request, candidate_items, session, importer_defs,
        )
        if side_effect_items.length() == 0 {
          continue
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
              composer_string_list_push_unique(
                request.declared_items,
                declared_item,
              )
            }
          }
          None =>
            requests.push(WgslImportRequest::{
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
    }
    for dependency_request in dependency_requests {
      if dependency_request.requested_items.length() == 0 {
        continue
      }
      let side_effect_items = self.collect_wgsl_declared_full_module_side_effect_items(
        dependency_request,
        dependency_request.requested_items,
        session,
        importer_defs,
      )
      merge_wgsl_resource_side_effect_request(
        requests, dependency_request, side_effect_items,
      )
    }
    self.merge_wgsl_non_resource_dependency_requests(
      requests, dependency_requests, dependency_scan_source, session, importer_defs,
    )
  }
  requests
}

///|
fn Composer::merge_wgsl_non_resource_dependency_requests(
  self : Composer,
  requests : Array[WgslImportRequest],
  dependency_requests : Array[WgslImportRequest],
  dependency_scan_source : String,
  session : WgslComposeSession,
  importer_defs : WgslActiveComposeDefs,
) -> Unit raise ComposerError {
  let ordered_requests : Array[WgslImportRequest] = []
  let ordered_base_indexes : @set.Set[Int] = @set.Set([])
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
      dependency_request, dependency_scan_source, session, importer_defs,
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
      ordered_requests.push(WgslImportRequest::{
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
  dependency_scan_source : String,
  session : WgslComposeSession,
  importer_defs : WgslActiveComposeDefs,
) -> Array[String] raise ComposerError {
  let filtered_items : Array[String] = []
  if dependency_request.requested_items.length() == 0 {
    return filtered_items
  }
  let import_source = match
    self.registry.registered_source(dependency_request.rel_path) {
    Some(source) => source
    None =>
      raise ComposerError::MissingRegisteredSource(dependency_request.rel_path)
  }
  let import_defs = self.active_compose_defs_for_rel_path(
    dependency_request.rel_path,
    session,
    Some(importer_defs),
  )
  let active_import_source = apply_wgsl_template_consts(
    apply_wgsl_ifdefs_strict_for_compose(import_source, import_defs),
    import_defs.value_defines,
  )
  for requested_item in dependency_request.requested_items {
    let requested_item_is_referenced = wgsl_semantic_source_contains_reference_path(
      dependency_scan_source, requested_item,
    ) catch {
      error => raise composer_error_from_wgsl_parse_error(error)
    }
    let leaf_item_is_referenced = match
      split_last_wgsl_semantic_path(requested_item) {
      Some((_, leaf_name)) =>
        wgsl_semantic_source_contains_reference_path(
          dependency_scan_source, leaf_name,
        ) catch {
          error => raise composer_error_from_wgsl_parse_error(error)
        }
      None => false
    }
    if wgsl_source_declares_non_resource_dependency_item(
        active_import_source,
        requested_item,
        requested_item_is_referenced || leaf_item_is_referenced,
      ) {
      composer_string_list_push_unique(filtered_items, requested_item)
    }
  }
  filtered_items
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
fn Composer::build_wgsl_declared_import_requests_from_source_directives(
  self : Composer,
  current_rel_path : String,
  active_source : String,
  session : WgslComposeSession,
  importer_defs : WgslActiveComposeDefs,
) -> Array[WgslImportRequest] raise ComposerError {
  let targets : Array[WgslImportTarget] = []
  collect_wgsl_import_targets_from_source_directives(active_source, targets)
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
      requests.push(WgslImportRequest::{
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
fn Composer::build_wgsl_import_requests_from_targets(
  self : Composer,
  current_rel_path : String,
  targets : Array[WgslImportTarget],
  active_scan_source : String,
  session : WgslComposeSession,
  importer_defs : WgslActiveComposeDefs,
  prune_requested_items_by_active_usage : Bool,
) -> Array[WgslImportRequest] raise ComposerError {
  let requests : Array[WgslImportRequest] = []
  self.record_declared_leaf_import_local_spelling(
    current_rel_path, targets, session, importer_defs,
  )
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
    let declared_items = wgsl_import_request_copy_items(requested_items)
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
          } else if !prune_requested_items_by_active_usage &&
            wgsl_source_declares_non_resource_dependency_item(
              active_import_source, requested_item, false,
            ) {
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
    if module_alias == "" {
      for declared_item in declared_items {
        session.record_local_spelling_final_name(
          current_rel_path, selected_rel_path, declared_item, "",
        )
      }
    }
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
      for declared_item in declared_items {
        composer_string_list_push_unique(request.declared_items, declared_item)
      }
    } else {
      requests.push(WgslImportRequest::{
        module_path,
        rel_path: resolved_module.rel_path(),
        import_full_module,
        keep_requested_items: target_plan.keep_requested_items,
        requested_items,
        declared_items,
        alias_name: module_alias,
      })
    }
  }
  self.order_wgsl_import_requests_by_declared_dependencies(
    requests, session, importer_defs,
  )
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
  let import_source = match self.registry.registered_source(request.rel_path) {
    Some(source) => source
    None => raise ComposerError::MissingRegisteredSource(request.rel_path)
  }
  let import_defs = self.active_compose_defs_for_rel_path(
    request.rel_path,
    session,
    Some(importer_defs),
  )
  let active_import_source = apply_wgsl_template_consts(
    apply_wgsl_ifdefs_strict_for_compose(import_source, import_defs),
    import_defs.value_defines,
  )
  self.build_wgsl_declared_import_requests_from_source_directives(
    request.rel_path,
    active_import_source,
    session,
    import_defs,
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
  let visiting : @set.Set[Int] = @set.Set([])
  let emitted : @set.Set[Int] = @set.Set([])
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
    true,
  )
}
