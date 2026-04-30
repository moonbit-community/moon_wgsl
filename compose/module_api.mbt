///|
pub fn Composer::add_composable_module(
  self : Composer,
  desc : ComposableModuleDescriptor,
) -> ComposableModuleDefinition raise ComposerError {
  let metadata = get_preprocessor_metadata_checked(
    desc.source,
    allow_defines=false,
  ) catch {
    error => raise composer_error_from_metadata_error(error)
  }
  let module_name = composable_module_name_from_descriptor(desc, metadata.name) catch {
    err => raise err
  }
  let registry_rel_path = composable_module_registry_rel_path(desc, module_name)

  let shader_defs = copy_shader_def_values(desc.shader_defs)
  let effective_defs = metadata.effective_defs.copy()
  let all_imports : @hashset.HashSet[String] = @hashset.HashSet::new()
  let additional_imports = copy_import_definitions(desc.additional_imports)
  let import_names : Array[String] = []
  for import_binding in metadata.imports {
    let import_name = import_binding.definition.import_path
    if import_name != "" {
      import_names.push(import_name)
    }
  }
  for import_definition in additional_imports {
    let import_name = import_definition.import_path
    if import_name != "" {
      import_names.push(import_name)
    }
  }

  for import_name in import_names {
    guard resolve_wgsl_import_request_module(
        registry_rel_path,
        import_name,
        self.registry,
        self.registry.copy_import_module_paths(),
      )
      is Some(resolved_module) else {
      raise ComposerError::FailedToResolveImport(import_name)
    }
    all_imports.add(resolved_module.module_path)
    if self.module_sets.get(resolved_module.module_path)
      is Some(imported_module) {
      for effective_def in imported_module.effective_defs {
        effective_defs.add(effective_def)
      }
      for entry in imported_module.shader_defs.iter() {
        let (def_name, def_value) = entry
        shader_defs.set(def_name, def_value)
      }
    }
  }

  for entry in shader_defs.iter() {
    let (def_name, _) = entry
    effective_defs.remove(def_name)
  }

  let source_with_additional_imports = prepend_wgsl_additional_imports(
    desc.source,
    additional_imports,
  )
  let definition = ComposableModuleDefinition::{
    name: module_name,
    sanitized_source: prepend_wgsl_additional_imports(
      metadata.cleaned_source,
      additional_imports,
    ),
    file_path: desc.file_path,
    shader_defs,
    effective_defs: hashset_strings_to_array(effective_defs),
    all_imports,
    additional_imports,
  }

  composer_remove_composable_module_recursive(self, module_name)
  ignore(
    self.registry.register_source(
      registry_rel_path,
      source_with_additional_imports,
      Some(module_name),
    ),
  )
  self.composable_module_registry_paths.set(module_name, registry_rel_path)
  self.module_sets.set(module_name, definition)
  match self.module_sets.get(module_name) {
    Some(module_definition) => module_definition
    None => abort("expected just-inserted composable module to exist")
  }
}

///|
pub fn Composer::remove_composable_module(
  self : Composer,
  module_name : String,
) -> Unit {
  composer_remove_composable_module_recursive(self, module_name)
}

///|
fn Composer::load_wgsl_source_required_raw(
  self : Composer,
  rel : String,
) -> String raise ComposerError {
  let normalized_rel = normalize_shader_rel_path(rel)
  if normalized_rel == "" {
    return ""
  }
  match self.registry.registered_source(normalized_rel) {
    Some(source) => source
    None => raise ComposerError::MissingStartupRegisteredSource(normalized_rel)
  }
}

///|
fn composer_error_from_preprocess_error(
  error : PreprocessError,
) -> ComposerError {
  match error {
    UnknownShaderDef(name, _) => UnknownShaderDef(name)
    UnknownShaderDefOperator(operator, _) => UnknownShaderDefOperator(operator)
    InvalidShaderDefComparisonValue(name, value, expected, _) =>
      InvalidShaderDefComparisonValue(name, value, expected)
    ElseWithoutCondition(_) => ElseWithoutCondition
    TooManyEndIfs(_) => TooManyEndIfs
    NotEnoughEndIfs(_) => NotEnoughEndIfs
    ImportParseError(message, _) => FailedToResolveImport(message)
    InvalidWgslDirective(line, _, reason) =>
      UnknownShaderDefOperator("\{line}: \{reason}")
    GlslInvalidVersion(_) | DefineInModule(_) => UnknownShaderDefOperator("")
  }
}

///|
fn composer_error_from_metadata_error(error : MetadataError) -> ComposerError {
  match error {
    ImportParseError(message, _) => FailedToResolveImport(message)
    InvalidWgslDirective(line, _, reason) =>
      UnknownShaderDefOperator("\{line}: \{reason}")
    DefineInModule(_) => DefineInModule
  }
}

///|
fn apply_wgsl_ifdefs_strict_for_compose(
  source : String,
  active_defs : WgslActiveComposeDefs,
) -> String raise ComposerError {
  apply_wgsl_ifdefs_strict(source, active_defs.shader_defs) catch {
    error => raise composer_error_from_preprocess_error(error)
  }
}

///|
fn active_wgsl_ifdef_line_flags_strict_for_compose(
  source : String,
  active_defs : WgslActiveComposeDefs,
) -> Array[Bool] raise ComposerError {
  active_wgsl_ifdef_line_flags_strict(source, active_defs.shader_defs) catch {
    error => raise composer_error_from_preprocess_error(error)
  }
}
