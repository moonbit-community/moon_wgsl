///|
fn wgsl_line_is_conditional_directive(trimmed : String) -> Bool {
  wgsl_directive_tail(trimmed, WgslDirectiveKind::Ifdef) is Some(_) ||
  wgsl_directive_tail(trimmed, WgslDirectiveKind::Ifndef) is Some(_) ||
  wgsl_directive_tail(trimmed, WgslDirectiveKind::If) is Some(_) ||
  wgsl_directive_prefix_tail(trimmed, WgslDirectiveKind::Else) is Some(_) ||
  wgsl_directive_prefix_tail(trimmed, WgslDirectiveKind::Endif) is Some(_)
}

///|
fn Composer::preprocess_wgsl_source_with_path(
  self : Composer,
  current_rel_path : String,
  source : String,
  session : WgslComposeSession,
  inherited_defs : WgslActiveComposeDefs?,
) -> String raise ComposerError {
  let active_defs = self.active_compose_defs_for_rel_path(
    current_rel_path, session, inherited_defs,
  )
  merge_wgsl_source_local_shader_defs(active_defs, source)
  if current_rel_path != "" {
    session.resolved_source_defs.set(
      current_rel_path,
      copy_active_compose_defs(active_defs),
    )
  }
  let prepared = prepare_wgsl_compose_source(source, session, active_defs)
  let mut merged = ""
  let alias_redirects : Array[WgslSymbolRedirect] = []
  let lines = self.seed_wgsl_compose_lines(current_rel_path, prepared, session)
  let active_line_flags = active_wgsl_ifdef_line_flags_strict_for_compose(
    lines.join("\n"),
    active_defs,
  )
  let mut line_index = 0
  while line_index < lines.length() {
    let line = lines[line_index]
    let trimmed = line.trim().to_owned()
    if parse_glsl_version_directive(trimmed) is Some(version) {
      validate_glsl_version_for_compose(version)
      line_index = line_index + 1
      continue
    }
    if wgsl_line_is_conditional_directive(trimmed) {
      merged = "\{merged}\{line}\n"
      line_index = line_index + 1
      continue
    }
    if wgsl_directive_tail(trimmed, WgslDirectiveKind::DefineImportPath)
      is Some(_) {
      line_index = line_index + 1
      continue
    }
    if wgsl_directive_tail(trimmed, WgslDirectiveKind::Define) is Some(_) {
      line_index = line_index + 1
      continue
    }
    if wgsl_directive_tail(trimmed, WgslDirectiveKind::Import)
      is Some(import_tail) {
      if line_index >= active_line_flags.length() ||
        !active_line_flags[line_index] {
        merged = "\{merged}\{line}\n"
        line_index = line_index + 1
        continue
      }
      let mut spec = import_tail
      let mut brace_balance = wgsl_token_brace_balance(spec)
      while brace_balance > 0 && line_index + 1 < lines.length() {
        line_index = line_index + 1
        let next_line = lines[line_index]
        spec = "\{spec}\n\{next_line}"
        brace_balance = brace_balance + wgsl_token_brace_balance(next_line)
      }
      let requests = self.build_wgsl_import_requests(
        current_rel_path,
        spec,
        prepared.active_scan_source,
        session,
      )
      let composed_imports = self.compose_wgsl_import_requests(
        current_rel_path, requests, alias_redirects, session, active_defs,
      )
      merged = "\{merged}\{composed_imports}"
      line_index = line_index + 1
      continue
    }
    merged = "\{merged}\{line}\n"
    line_index = line_index + 1
  }
  finalize_wgsl_composed_source(merged, alias_redirects, active_defs)
}

///|
fn Composer::load_root_wgsl_preprocessed_into_session(
  self : Composer,
  rel : String,
  session : WgslComposeSession,
) -> String raise ComposerError {
  let normalized_rel = normalize_shader_rel_path(rel)
  if normalized_rel == "" {
    return ""
  }
  if session.visited.contains(normalized_rel) {
    return ""
  }
  session.visited.set(normalized_rel, true)
  let source = self.load_wgsl_source_required_raw(normalized_rel)
  session.resolved_source_files.set(normalized_rel, source)
  session.active_rel_paths.push(normalized_rel)
  let composed = self.preprocess_wgsl_source_with_path(
    normalized_rel,
    prepend_wgsl_additional_imports(source, session.additional_imports),
    session,
    None,
  )
  session.active_rel_paths.pop() |> ignore
  composed
}

///|
fn collect_wgsl_unused_redirect_diagnostics(
  session : WgslComposeSession,
) -> Array[WgslDiagnostic] {
  let diagnostics : Array[WgslDiagnostic] = []
  for redirect in session.redirects {
    let from_name = redirect.from_name.trim().to_owned()
    let to_name = redirect.to_name.trim().to_owned()
    if from_name == "" || to_name == "" || from_name == to_name {
      continue
    }
    let matched = match session.redirect_match_counts.get(from_name) {
      Some(count) => count > 0
      None => false
    }
    if !matched {
      diagnostics.push(WgslDiagnostic::{
        severity: WgslDiagnosticSeverity::Warn,
        message: "symbol redirect did not match any source identifier",
        rel_path: None,
        symbol_name: Some(from_name),
        generated_start: None,
        source_start: None,
      })
    }
  }
  diagnostics
}

///|
fn copy_composed_source_files(
  source_registry : @hashmap.HashMap[String, String],
) -> Array[WgslSourceFile] {
  let files : Array[WgslSourceFile] = []
  for entry in source_registry.iter() {
    let (rel_path, source) = entry
    files.push(WgslSourceFile::{ rel_path, source })
  }
  files
}

///|
pub fn Composer::prepare_wgsl_source(
  self : Composer,
  rel : String,
  options : WgslComposeOptions,
) -> PreparedWgslSource raise ComposerError {
  let session = self.new_wgsl_compose_session(options)
  let composed = strip_wgsl_virtual_functions(
    self.load_root_wgsl_preprocessed_into_session(rel, session),
  )
  let source_files = copy_composed_source_files(session.resolved_source_files)
  PreparedWgslSource::{
    source: finalize_wgsl_writeback_source(composed),
    source_files,
    source_catalog: build_prepared_wgsl_source_catalog(
      source_files.copy(),
      session.resolved_source_defs,
    ),
    defines: session.defines,
    value_defines: session.value_defines,
    diagnostics: collect_wgsl_unused_redirect_diagnostics(session),
  }
}

///|
pub fn Composer::compose_wgsl(
  self : Composer,
  rel : String,
  options : WgslComposeOptions,
) -> String raise ComposerError {
  self.prepare_wgsl_source(rel, options).source
}

///|
pub fn Composer::compose_wgsl_source(
  self : Composer,
  source : String,
  options : WgslComposeOptions,
) -> String raise ComposerError {
  let session = self.new_wgsl_compose_session(options)
  let composed = strip_wgsl_virtual_functions(
    self.preprocess_wgsl_source_with_path(
      "",
      prepend_wgsl_additional_imports(source, session.additional_imports),
      session,
      None,
    ),
  )
  finalize_wgsl_writeback_source(composed)
}

///|
