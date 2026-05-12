///|
fn copy_wgsl_source_registry_map(
  source_registry : Map[String, String],
) -> Map[String, String] {
  let copied : Map[String, String] = Map([])
  for entry in source_registry.iter() {
    let (rel_path, source) = entry
    copied.set(rel_path, source)
  }
  copied
}

///|
fn copy_wgsl_import_module_map(
  module_paths : Map[String, String],
) -> Map[String, String] {
  let copied : Map[String, String] = Map([])
  for entry in module_paths.iter() {
    let (module_path, rel_path) = entry
    copied.set(module_path, rel_path)
  }
  copied
}

///|
fn copy_wgsl_import_module_candidates_for_path(
  module_candidates : Map[String, Array[String]],
  module_path : String,
) -> Array[String] {
  match module_candidates.get(module_path.trim().to_owned()) {
    Some(rel_paths) => rel_paths.copy()
    None => []
  }
}

///|
fn clear_wgsl_source_registry(
  source_registry : Map[String, String],
  module_paths : Map[String, String],
  module_candidates : Map[String, Array[String]],
) -> Unit {
  source_registry.clear()
  module_paths.clear()
  module_candidates.clear()
}

///|
fn register_source_into(
  source_registry : Map[String, String],
  module_paths : Map[String, String],
  module_candidates : Map[String, Array[String]],
  rel_path : String,
  source : String,
  explicit_module_path : String?,
) -> String? {
  let normalized_rel = normalize_shader_rel_path(rel_path)
  if normalized_rel == "" {
    return None
  }
  remove_module_paths_for_rel_path(module_paths, normalized_rel)
  remove_module_candidates_for_rel_path(module_candidates, normalized_rel)
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
    register_module_candidate_rel_path(module_candidates, path, normalized_rel)
  }
  Some(normalized_rel)
}

///|
fn remove_module_paths_for_rel_path(
  module_paths : Map[String, String],
  rel_path : String,
) -> Unit {
  let stale_modules : Array[String] = []
  for entry in module_paths.iter() {
    let (module_path, module_rel_path) = entry
    if normalize_shader_rel_path(module_rel_path) == rel_path {
      stale_modules.push(module_path)
    }
  }
  for module_path in stale_modules {
    ignore(module_paths.remove(module_path))
  }
}

///|
fn remove_wgsl_import_module_candidate(
  module_candidates : Map[String, Array[String]],
  module_path : String,
  rel_path : String,
) -> Unit {
  let normalized_rel = normalize_shader_rel_path(rel_path)
  if normalized_rel == "" {
    return
  }
  match module_candidates.get(module_path) {
    Some(rel_paths) => {
      let kept : Array[String] = []
      for candidate_rel in rel_paths {
        if normalize_shader_rel_path(candidate_rel) != normalized_rel {
          kept.push(candidate_rel)
        }
      }
      if kept.length() == 0 {
        ignore(module_candidates.remove(module_path))
      } else {
        module_candidates.set(module_path, kept)
      }
    }
    None => ()
  }
}

///|
fn remove_module_candidates_for_rel_path(
  module_candidates : Map[String, Array[String]],
  rel_path : String,
) -> Unit {
  let normalized_rel = normalize_shader_rel_path(rel_path)
  let module_paths_to_prune : Array[String] = []
  for entry in module_candidates.iter() {
    let (module_path, rel_paths) = entry
    let kept : Array[String] = []
    for candidate_rel in rel_paths {
      if normalize_shader_rel_path(candidate_rel) != normalized_rel {
        kept.push(candidate_rel)
      }
    }
    if kept.length() == 0 {
      module_paths_to_prune.push(module_path)
    } else if kept.length() != rel_paths.length() {
      module_candidates.set(module_path, kept)
    }
  }
  for module_path in module_paths_to_prune {
    ignore(module_candidates.remove(module_path))
  }
}

///|
fn register_module_candidate_rel_path(
  module_candidates : Map[String, Array[String]],
  module_path : String,
  rel_path : String,
) -> Unit {
  let normalized_rel = normalize_shader_rel_path(rel_path)
  if module_path == "" || normalized_rel == "" {
    return
  }
  match module_candidates.get(module_path) {
    Some(rel_paths) => {
      for existing_rel in rel_paths {
        if normalize_shader_rel_path(existing_rel) == normalized_rel {
          return
        }
      }
      rel_paths.push(normalized_rel)
    }
    None => module_candidates.set(module_path, [normalized_rel])
  }
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
  existing_rel_to_source : Map[String, String],
  files : Array[WgslSourceFile],
  diagnostics : Array[WgslDiagnostic],
) -> Unit {
  let batch_rel_to_source : Map[String, String] = Map([])

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
  }
}

///|
fn register_source_files_checked_into(
  source_registry : Map[String, String],
  module_paths : Map[String, String],
  module_candidates : Map[String, Array[String]],
  files : Array[WgslSourceFile],
  diagnostics : Array[WgslDiagnostic],
) -> Unit {
  let existing_rel_to_source = copy_wgsl_source_registry_map(source_registry)
  analyze_source_files_against(existing_rel_to_source, files, diagnostics)
  if wgsl_diagnostics_has_error(diagnostics) {
    return
  }
  register_source_files_into(
    source_registry, module_paths, module_candidates, files,
  )
}

///|
fn register_source_files_into(
  source_registry : Map[String, String],
  module_paths : Map[String, String],
  module_candidates : Map[String, Array[String]],
  files : Array[WgslSourceFile],
) -> Unit {
  for file in files {
    ignore(
      register_source_into(
        source_registry,
        module_paths,
        module_candidates,
        file.rel_path,
        file.source,
        None,
      ),
    )
  }
}

///|
fn registered_source_from_registry(
  source_registry : Map[String, String],
  rel_path : String,
) -> String? {
  let normalized_rel = normalize_shader_rel_path(rel_path)
  if normalized_rel == "" {
    return None
  }
  source_registry.get(normalized_rel)
}
