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
  let shader_defs : @hashmap.HashMap[String, ShaderDefValue] = @hashmap.HashMap::new()
  let (defines, value_defines) = match inherited_defs {
    Some(parent_defs) => {
      for entry in parent_defs.shader_defs.iter() {
        let (name, value) = entry
        shader_defs.set(name, value)
      }
      (
        copy_bool_defs(parent_defs.defines),
        copy_int_defs(parent_defs.value_defines),
      )
    }
    None => {
      for entry in session.defines.iter() {
        let (name, value) = entry
        shader_defs.set(name, ShaderDefValue::Bool(value))
      }
      for entry in session.value_defines.iter() {
        let (name, value) = entry
        shader_defs.set(name, ShaderDefValue::Int(value))
      }
      (copy_bool_defs(session.defines), copy_int_defs(session.value_defines))
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
  WgslActiveComposeDefs::{ defines, value_defines, shader_defs }
}

///|
fn merge_wgsl_source_local_shader_defs(
  active_defs : WgslActiveComposeDefs,
  source : String,
) -> Unit raise ComposerError {
  let metadata = get_preprocessor_metadata(source) catch {
    error => raise composer_error_from_metadata_error(error)
  }
  for entry in metadata.defines.iter() {
    let (name, value) = entry
    merge_shader_def_value_into_compose_defs(
      active_defs.defines,
      active_defs.value_defines,
      active_defs.shader_defs,
      name,
      value,
    )
  }
}

///|
fn collect_wgsl_cached_import_redirects(
  session : WgslComposeSession,
  rel_path : String,
  alias_name : String,
  redirects : WgslScopedAliasRedirectSet,
) -> Int {
  let mut count = 0
  if alias_name == "" {
    for entry in session.final_names.canonical_entries {
      if entry.identity.rel_path != rel_path {
        continue
      }
      redirects.push(
        WgslScopedAliasRedirect::for_unqualified_symbol(
          entry.identity.rel_path,
          entry.identity.original_name,
          entry.generated_name,
          UnqualifiedItemBinding,
        ),
      )
      count = count + 1
    }
  } else {
    for entry in session.final_names.alias_entries {
      if entry.identity.alias_name != alias_name ||
        entry.identity.symbol.rel_path != rel_path {
        continue
      }
      redirects.push(
        WgslScopedAliasRedirect::for_alias_symbol(
          entry.identity.symbol.rel_path,
          alias_name,
          entry.identity.symbol.original_name,
          entry.generated_name,
          CachedQualifiedAliasReference,
        ),
      )
      count = count + 1
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
  session.final_names.canonical_get(
    WgslSymbolIdentity::new(rel_path, item_name),
  )
}

///|
fn find_wgsl_visible_alias_imported_item_binding(
  alias_redirects : WgslScopedAliasRedirectSet,
  module_path : String,
  item_name : String,
) -> WgslScopedAliasRedirect? {
  let default_alias = wgsl_semantic_import_default_alias(module_path)
  if default_alias == "" || item_name == "" {
    return None
  }
  let from_name = "\{default_alias}::\{item_name}"
  for scoped_redirect in alias_redirects.redirects {
    if scoped_redirect.redirect.from_name == from_name {
      return Some(scoped_redirect.as_unqualified_binding(item_name))
    }
  }
  None
}

///|
fn record_wgsl_redirect_matches(
  source : String,
  session : WgslComposeSession,
) -> Unit raise ComposerError {
  for redirect in session.redirects {
    let from_name = redirect.from_name.trim().to_owned()
    let to_name = redirect.to_name.trim().to_owned()
    if from_name == "" || to_name == "" || from_name == to_name {
      continue
    }
    let contains_reference = wgsl_semantic_source_contains_reference_path(
      source, from_name,
    ) catch {
      error => raise composer_error_from_wgsl_parse_error(error)
    }
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
