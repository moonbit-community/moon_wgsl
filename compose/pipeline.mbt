///|
fn Composer::preprocess_wgsl_source_with_path(
  self : Composer,
  current_rel_path : String,
  source : String,
  session : WgslComposeSession,
  inherited_defs : WgslActiveComposeDefs?,
  inherited_alias_redirects : Array[WgslScopedAliasRedirect],
  apply_virtual_overrides : Bool,
) -> String raise ComposerError {
  let active_defs = self.active_compose_defs_for_rel_path(
    current_rel_path, session, inherited_defs,
  )
  merge_wgsl_source_local_shader_defs(active_defs, source)
  let prepared = prepare_wgsl_compose_source(source, session, active_defs)
  let mut merged = ""
  let alias_redirects : Array[WgslScopedAliasRedirect] = []
  for redirect in inherited_alias_redirects {
    alias_redirects.push(redirect)
  }
  let implicit_requests = self.build_wgsl_implicit_import_requests(
    current_rel_path,
    prepared.active_scan_source,
    session,
    active_defs,
  )
  let implicit_imports = self.compose_wgsl_import_requests(
    current_rel_path, implicit_requests, alias_redirects, session, active_defs,
  )
  merged = merged + implicit_imports
  for
    item in parse_wgsl_directive_scan_items(
      prepared.active_source,
      include_glsl_version=false,
    ) {
    match item.kind {
      WgslDirectiveScanItemKind::Directive(import_directive) if import_directive.kind ==
        WgslDirectiveKind::Import => {
        let requests = self.build_wgsl_import_requests(
          current_rel_path,
          import_directive.tail,
          prepared.active_scan_source,
          session,
          active_defs,
        )
        let composed_imports = self.compose_wgsl_import_requests(
          current_rel_path, requests, alias_redirects, session, active_defs,
        )
        merged = "\{merged}\{composed_imports}"
      }
      WgslDirectiveScanItemKind::Directive(directive) =>
        match directive.kind {
          WgslDirectiveKind::DefineImportPath | WgslDirectiveKind::Define => ()
          WgslDirectiveKind::Other(_) =>
            if parse_glsl_version_directive(item.cleaned_text) is None {
              merged = "\{merged}\{item.original_text}"
            }
          _ => merged = "\{merged}\{item.original_text}"
        }
      WgslDirectiveScanItemKind::Source =>
        merged = "\{merged}\{item.original_text}"
      WgslDirectiveScanItemKind::GlslVersion(_) =>
        merged = "\{merged}\{item.original_text}"
    }
  }
  finalize_wgsl_composed_source(
    merged, alias_redirects, active_defs, session, apply_virtual_overrides,
  )
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
  session.active_rel_paths.push(normalized_rel)
  let composed = self.preprocess_wgsl_source_with_path(
    normalized_rel,
    prepend_wgsl_additional_imports(source, session.additional_imports),
    session,
    None,
    [],
    true,
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
pub fn Composer::prepare_wgsl_source(
  self : Composer,
  rel : String,
  options : WgslComposeOptions,
) -> PreparedWgslSource raise ComposerError {
  let session = self.new_wgsl_compose_session(options)
  let composed = strip_wgsl_virtual_functions(
    self.load_root_wgsl_preprocessed_into_session(rel, session),
  )
  let prepared_source = finalize_wgsl_writeback_source(composed)
  let source_files : Array[WgslSourceFile] = [
    { rel_path: normalize_shader_rel_path(rel), source: prepared_source },
  ]
  PreparedWgslSource::{
    source: prepared_source,
    source_files,
    source_catalog: build_prepared_wgsl_source_catalog(source_files.copy()),
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
      [],
      true,
    ),
  )
  finalize_wgsl_writeback_source(composed)
}

///|
