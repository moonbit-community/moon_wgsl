///|
fn Composer::composable_module_definition_for_rel_path(
  self : Composer,
  rel_path : String,
) -> ComposableModuleDefinition? {
  let normalized_rel = normalize_shader_rel_path(rel_path)
  for entry in self.composable_module_registry_paths.iter() {
    let (module_name, module_rel_path) = entry
    if normalize_shader_rel_path(module_rel_path) == normalized_rel {
      return self.module_sets.get(module_name)
    }
  }
  None
}

///|
fn Composer::active_compose_defs_for_rel_path(
  self : Composer,
  rel_path : String,
  session : WgslComposeSession,
  inherited_defs : WgslActiveComposeDefs?,
) -> WgslActiveComposeDefs {
  let shader_defs : Map[String, ShaderDefValue] = Map([])
  let (defines, value_defines) = match inherited_defs {
    Some(parent_defs) => {
      for entry in parent_defs.shader_defs.iter() {
        let (name, value) = entry
        shader_defs.set(name, value)
      }
      (
        copy_bool_defs(parent_defs.defines),
        copy_value_defs(parent_defs.value_defines),
      )
    }
    None => {
      for entry in session.defines.iter() {
        let (name, value) = entry
        shader_defs.set(name, Bool(value))
      }
      for entry in session.value_defines.iter() {
        let (name, value) = entry
        shader_defs.set(name, value)
      }
      (copy_bool_defs(session.defines), copy_value_defs(session.value_defines))
    }
  }
  if self.composable_module_definition_for_rel_path(rel_path)
    is Some(module_definition) {
    for entry in module_definition.shader_defs.iter() {
      let (name, value) = entry
      merge_shader_def_value_into_compose_defs(
        defines, value_defines, shader_defs, name, value,
      )
    }
  }
  { defines, value_defines, shader_defs, cache_text: None }
}

///|
fn merge_wgsl_source_local_shader_defs(
  active_defs : WgslActiveComposeDefs,
  source : String,
  session : WgslComposeSession,
  source_key : String,
) -> Unit {
  let cache_key = if source_key == "" { source } else { source_key }
  let local_defs = match session.source_local_shader_defs.get(cache_key) {
    Some(cached_defs) => cached_defs
    None => {
      let cached_defs = collect_wgsl_source_local_shader_defines(source)
      session.source_local_shader_defs.set(cache_key, cached_defs)
      cached_defs
    }
  }
  for entry in local_defs.iter() {
    let (name, value) = entry
    merge_shader_def_value_into_compose_defs(
      active_defs.defines,
      active_defs.value_defines,
      active_defs.shader_defs,
      name,
      value,
    )
  }
  active_defs.cache_text = None
}

///|
fn collect_wgsl_cached_import_bindings(
  session : WgslComposeSession,
  rel_path : String,
  source_alias_name : String,
  final_alias_scope : String,
  bindings : WgslComposeBindingSet,
) -> Int {
  let mut count = 0
  if source_alias_name == "" {
    for
      entry in session.symbols.emitted_final_names.canonical_entries_for_rel_path(
        rel_path,
      ) {
      match
        WgslComposeBinding::for_unqualified_symbol(
          entry.identity().rel_path(),
          entry.identity().original_name(),
          entry.final_name(),
          UnqualifiedItemBinding,
        ) {
        Some(binding) => {
          bindings.push(binding)
          count = count + 1
        }
        None => ()
      }
    }
  } else {
    for
      entry in session.symbols.emitted_final_names.alias_entries_for_scope(
        rel_path, final_alias_scope,
      ) {
      match
        WgslComposeBinding::for_alias_symbol(
          entry.identity().symbol().rel_path(),
          source_alias_name,
          entry.identity().symbol().original_name(),
          entry.final_name(),
          QualifiedAliasBinding,
        ) {
        Some(binding) => {
          bindings.push(binding)
          count = count + 1
        }
        None => ()
      }
    }
    if count == 0 {
      for
        entry in session.symbols.emitted_final_names.canonical_entries_for_rel_path(
          rel_path,
        ) {
        match
          WgslComposeBinding::for_alias_symbol(
            entry.identity().rel_path(),
            source_alias_name,
            entry.identity().original_name(),
            entry.final_name(),
            QualifiedAliasBinding,
          ) {
          Some(binding) => {
            bindings.push(binding)
            count = count + 1
          }
          None => ()
        }
      }
    }
  }
  count
}

///|
fn find_wgsl_cached_imported_item_name(
  session : WgslComposeSession,
  rel_path : String,
  item_name : String,
) -> String? {
  session.symbols.emitted_final_names.canonical_get(
    WgslComposeSymbolIdentity(rel_path, item_name),
  )
}

///|
fn find_wgsl_visible_alias_imported_item_binding(
  bindings : WgslComposeBindingSet,
  module_path : String,
  item_name : String,
) -> WgslComposeBinding? {
  let default_alias = wgsl_semantic_import_default_alias(module_path)
  if default_alias == "" || item_name == "" {
    return None
  }
  let reference_path = match
    WgslReferencePath::from_text("\{default_alias}::\{item_name}") {
    Some(path) => path
    None => return None
  }
  for binding in bindings.bindings {
    if binding.reference_path.matches(reference_path) {
      return binding.as_unqualified_binding(item_name)
    }
  }
  None
}

///|
fn find_wgsl_visible_identity_imported_item_binding(
  bindings : WgslComposeBindingSet,
  rel_path : String,
  item_name : String,
) -> WgslComposeBinding? {
  let identity_key = WgslComposeIrIdentityKey(
    WgslComposeSymbolIdentity(rel_path, item_name),
  ).text()
  let mut found : WgslComposeBinding? = None
  for binding in bindings.bindings {
    if binding.target.identity_key != identity_key {
      continue
    }
    match found {
      Some(existing) if existing.target.final_name != binding.target.final_name =>
        return None
      Some(_) => ()
      None =>
        match binding.as_unqualified_binding(item_name) {
          Some(unqualified_binding) => found = Some(unqualified_binding)
          None => ()
        }
    }
  }
  found
}

///|
fn record_wgsl_redirect_matches(
  facts : WgslComposeSemanticFacts,
  session : WgslComposeSession,
) -> Unit {
  for redirect in session.redirects {
    let from_name = redirect.from_name.trim().to_owned()
    let to_name = redirect.to_name.trim().to_owned()
    if from_name == "" || to_name == "" || from_name == to_name {
      continue
    }
    let contains_reference = facts.contains_reference_path(from_name)
    if contains_reference {
      let current = match session.redirect_match_counts.get(from_name) {
        Some(count) => count
        None => 0
      }
      session.redirect_match_counts.set(from_name, current + 1)
    }
  }
}

///|
fn composer_remove_composable_module_recursive(
  composer : Composer,
  module_name : String,
) -> Unit {
  if !composer.module_sets.contains(module_name) {
    return
  }
  if composer.composable_module_registry_paths.get(module_name)
    is Some(rel_path) {
    ignore(composer.composable_module_registry_paths.remove(module_name))
    composer.registry.remove_source_and_module(rel_path, module_name)
  }
  ignore(composer.module_sets.remove(module_name))
  let dependent_modules : Array[String] = []
  for entry in composer.module_sets.iter() {
    let (dependent_name, module_set) = entry
    if module_set.all_imports.contains(module_name) {
      dependent_modules.push(dependent_name)
    }
  }
  for dependent_name in dependent_modules {
    composer_remove_composable_module_recursive(composer, dependent_name)
  }
}

///|
pub fn Composer::contains_module(self : Composer, module_name : String) -> Bool {
  self.module_sets.contains(module_name)
}
