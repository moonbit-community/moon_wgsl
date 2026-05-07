///|
fn copy_wgsl_source_registry_map(
  source_registry : @hashmap.HashMap[String, String],
) -> @hashmap.HashMap[String, String] {
  let copied : @hashmap.HashMap[String, String] = @hashmap.HashMap([])
  for entry in source_registry.iter() {
    let (rel_path, source) = entry
    copied.set(rel_path, source)
  }
  copied
}

///|
fn copy_wgsl_import_module_map(
  module_paths : @hashmap.HashMap[String, String],
) -> @hashmap.HashMap[String, String] {
  let copied : @hashmap.HashMap[String, String] = @hashmap.HashMap([])
  for entry in module_paths.iter() {
    let (module_path, rel_path) = entry
    copied.set(module_path, rel_path)
  }
  copied
}

///|
fn wgsl_module_path_from_rel_path(rel_path : String) -> String? {
  let normalized_rel = normalize_shader_rel_path(rel_path)
  if normalized_rel == "" || !normalized_rel.has_suffix(".wgsl") {
    return None
  }
  let without_extension = normalized_rel[:normalized_rel.length() - 5].to_owned()
  let trimmed_prefix = if without_extension.has_prefix("shaders/") {
    without_extension[8:without_extension.length()].to_owned()
  } else {
    without_extension
  }
  let segments : Array[String] = []
  for segment in trimmed_prefix.split("/") {
    let text = segment.to_owned().trim().to_owned()
    if text != "" {
      segments.push(text)
    }
  }
  if segments.length() == 0 {
    None
  } else {
    Some(segments.join("::"))
  }
}

///|
fn clear_wgsl_source_registry(
  source_registry : @hashmap.HashMap[String, String],
  module_paths : @hashmap.HashMap[String, String],
) -> Unit {
  source_registry.clear()
  module_paths.clear()
}

///|
fn register_source_into(
  source_registry : @hashmap.HashMap[String, String],
  module_paths : @hashmap.HashMap[String, String],
  rel_path : String,
  source : String,
  explicit_module_path : String?,
) -> String? {
  let normalized_rel = normalize_shader_rel_path(rel_path)
  if normalized_rel == "" {
    return None
  }
  source_registry.set(normalized_rel, source)
  let mut module_path : String? = explicit_module_path
  if module_path is None {
    module_path = wgsl_source_define_import_path(source)
  }
  if module_path is None {
    module_path = wgsl_module_path_from_rel_path(normalized_rel)
  }
  if module_path is Some(path) && path != "" {
    module_paths.set(path, normalized_rel)
  }
  Some(normalized_rel)
}

///|
fn push_wgsl_registry_diagnostic(
  diagnostics : Array[WgslDiagnostic],
  severity : WgslDiagnosticSeverity,
  message : String,
  rel_path : String?,
  symbol_name : String?,
) -> Unit {
  diagnostics.push(WgslDiagnostic(severity, message, rel_path, symbol_name))
}

///|
fn wgsl_diagnostics_has_error(diagnostics : Array[WgslDiagnostic]) -> Bool {
  for diagnostic in diagnostics {
    if diagnostic.severity == WgslDiagnosticSeverity::Error {
      return true
    }
  }
  false
}

///|
fn analyze_source_files_against(
  existing_rel_to_source : @hashmap.HashMap[String, String],
  existing_modules : @hashmap.HashMap[String, String],
  files : Array[WgslSourceFile],
  diagnostics : Array[WgslDiagnostic],
) -> Unit {
  let batch_rel_to_source : @hashmap.HashMap[String, String] = @hashmap.HashMap([],
  )
  let batch_module_to_rel : @hashmap.HashMap[String, String] = @hashmap.HashMap([],
  )

  for source_file in files {
    let normalized_rel = normalize_shader_rel_path(source_file.rel_path)
    if normalized_rel == "" {
      push_wgsl_registry_diagnostic(
        diagnostics,
        WgslDiagnosticSeverity::Error,
        "registry source file path resolves to an empty normalized path",
        Some(source_file.rel_path),
        None,
      )
      continue
    }

    if batch_rel_to_source.get(normalized_rel) is Some(existing_source) {
      if existing_source != source_file.source {
        push_wgsl_registry_diagnostic(
          diagnostics,
          WgslDiagnosticSeverity::Error,
          "multiple WGSL source files normalize to the same rel_path with different contents",
          Some(normalized_rel),
          None,
        )
      }
    } else if existing_rel_to_source.get(normalized_rel)
      is Some(existing_source) {
      if existing_source != source_file.source {
        push_wgsl_registry_diagnostic(
          diagnostics,
          WgslDiagnosticSeverity::Error,
          "bulk registry would overwrite an existing rel_path with different contents",
          Some(normalized_rel),
          None,
        )
      }
    }
    batch_rel_to_source.set(normalized_rel, source_file.source)

    let import_path = wgsl_source_define_import_path(source_file.source)
    let module_path = match import_path {
      Some(path) if path != "" => path
      _ =>
        match wgsl_module_path_from_rel_path(normalized_rel) {
          Some(path) => path
          None => continue
        }
    }
    if module_path == "" {
      continue
    }

    if batch_module_to_rel.get(module_path) is Some(existing_rel) {
      if existing_rel != normalized_rel {
        push_wgsl_registry_diagnostic(
          diagnostics,
          WgslDiagnosticSeverity::Error,
          "multiple WGSL source files define the same #define_import_path in one batch",
          Some(normalized_rel),
          Some(module_path),
        )
      }
    } else if existing_modules.get(module_path) is Some(existing_rel) {
      if existing_rel != normalized_rel {
        push_wgsl_registry_diagnostic(
          diagnostics,
          WgslDiagnosticSeverity::Error,
          "bulk registry would overwrite an existing #define_import_path with a different rel_path",
          Some(normalized_rel),
          Some(module_path),
        )
      }
    }
    batch_module_to_rel.set(module_path, normalized_rel)
  }
}

///|
fn register_source_files_checked_into(
  source_registry : @hashmap.HashMap[String, String],
  module_paths : @hashmap.HashMap[String, String],
  files : Array[WgslSourceFile],
  diagnostics : Array[WgslDiagnostic],
) -> Unit {
  let existing_rel_to_source = copy_wgsl_source_registry_map(source_registry)
  let existing_modules = copy_wgsl_import_module_map(module_paths)
  analyze_source_files_against(
    existing_rel_to_source, existing_modules, files, diagnostics,
  )
  if wgsl_diagnostics_has_error(diagnostics) {
    return
  }
  register_source_files_into(source_registry, module_paths, files)
}

///|
fn register_source_files_into(
  source_registry : @hashmap.HashMap[String, String],
  module_paths : @hashmap.HashMap[String, String],
  files : Array[WgslSourceFile],
) -> Unit {
  for file in files {
    ignore(
      register_source_into(
        source_registry,
        module_paths,
        file.rel_path,
        file.source,
        None,
      ),
    )
  }
}

///|
fn registered_source_from_registry(
  source_registry : @hashmap.HashMap[String, String],
  rel_path : String,
) -> String? {
  let normalized_rel = normalize_shader_rel_path(rel_path)
  if normalized_rel == "" {
    return None
  }
  source_registry.get(normalized_rel)
}
