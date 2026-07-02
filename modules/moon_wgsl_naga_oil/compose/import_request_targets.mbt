///|
fn wgsl_import_rel_path_is_glsl_frontend(rel_path : String) -> Bool {
  normalize_shader_rel_path(rel_path).has_suffix(".glsl")
}

///|
fn wgsl_import_target_array_copy(
  targets : Array[WgslImportTarget],
) -> Array[WgslImportTarget] {
  let copied : Array[WgslImportTarget] = []
  for target in targets {
    copied.push(target)
  }
  copied
}

///|
fn wgsl_import_targets_append(
  out : Array[WgslImportTarget],
  targets : Array[WgslImportTarget],
) -> Unit {
  for target in targets {
    out.push(target)
  }
}

///|
fn collect_wgsl_import_targets_from_source_directives(
  session : WgslComposeSession,
  source : String,
  targets : Array[WgslImportTarget],
) -> Unit raise ComposerError {
  match session.directive_import_targets.get(source) {
    Some(cached_targets) => {
      wgsl_import_targets_append(targets, cached_targets)
      return
    }
    None => ()
  }
  let parsed_targets : Array[WgslImportTarget] = []
  for item in session.directive_scan_items(source) {
    match item.kind() {
      Directive(import_directive) if import_directive.kind() == Import =>
        if !parse_wgsl_import_spec_is_empty_or_final_semicolon(
            import_directive.tail(),
          ) {
          parse_wgsl_import_targets(import_directive.tail(), "", parsed_targets) catch {
            Parse(message, _) => raise FailedToResolveImport(message)
          }
        }
      _ => ()
    }
  }
  session.directive_import_targets.set(
    source,
    wgsl_import_target_array_copy(parsed_targets),
  )
  wgsl_import_targets_append(targets, parsed_targets)
}

///|
fn collect_wgsl_single_target_import_targets_from_source_directives(
  session : WgslComposeSession,
  source : String,
  targets : Array[WgslImportTarget],
) -> Unit raise ComposerError {
  match session.directive_single_import_targets.get(source) {
    Some(cached_targets) => {
      wgsl_import_targets_append(targets, cached_targets)
      return
    }
    None => ()
  }
  let parsed_targets : Array[WgslImportTarget] = []
  for item in session.directive_scan_items(source) {
    match item.kind() {
      Directive(import_directive) if import_directive.kind() == Import =>
        if !parse_wgsl_import_spec_is_empty_or_final_semicolon(
            import_directive.tail(),
          ) {
          let directive_targets : Array[WgslImportTarget] = []
          parse_wgsl_import_targets(
            import_directive.tail(),
            "",
            directive_targets,
          ) catch {
            Parse(message, _) => raise FailedToResolveImport(message)
          }
          if directive_targets.length() == 1 &&
            directive_targets[0].alias_name == "" {
            parsed_targets.push(directive_targets[0])
          }
        }
      _ => ()
    }
  }
  session.directive_single_import_targets.set(
    source,
    wgsl_import_target_array_copy(parsed_targets),
  )
  wgsl_import_targets_append(targets, parsed_targets)
}
