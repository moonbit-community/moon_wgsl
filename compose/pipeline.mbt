///|

///|
priv enum WgslComposeSourceEmissionKind {
  DropDirective
  KeepTrivia
}

///|
fn compose_emit_scanned_item(
  kind : WgslComposeSourceEmissionKind,
  item : WgslDirectiveScanItem,
) -> String {
  match kind {
    DropDirective => ""
    KeepTrivia => item.source().original_text()
  }
}

///|
fn wgsl_compose_directive_emission_kind(
  item : WgslDirectiveScanItem,
  directive : WgslDirective,
) -> WgslComposeSourceEmissionKind {
  match directive.kind() {
    WgslDirectiveKind::DefineImportPath | WgslDirectiveKind::Define =>
      DropDirective
    WgslDirectiveKind::Other =>
      if parse_glsl_version_directive(item.source().cleaned_text()) is None {
        KeepTrivia
      } else {
        DropDirective
      }
    _ => KeepTrivia
  }
}

///|
fn Composer::compose_wgsl_scanned_item(
  self : Composer,
  current_rel_path : String,
  item : WgslDirectiveScanItem,
  active_scan_source : String,
  bindings : WgslComposeBindingSet,
  session : WgslComposeSession,
  active_defs : WgslActiveComposeDefs,
  alias_prefixes : Array[String],
) -> String raise ComposerError {
  match item.kind() {
    WgslDirectiveScanItemKind::Directive(import_directive) if import_directive.kind() ==
      WgslDirectiveKind::Import => {
      let requests = self.build_wgsl_import_requests(
        current_rel_path,
        import_directive.tail(),
        active_scan_source,
        session,
        active_defs,
      )
      self.compose_wgsl_import_requests(
        current_rel_path, requests, bindings, session, active_defs, alias_prefixes,
      )
    }
    WgslDirectiveScanItemKind::Directive(directive) =>
      compose_emit_scanned_item(
        wgsl_compose_directive_emission_kind(item, directive),
        item,
      )
    WgslDirectiveScanItemKind::Source =>
      compose_emit_scanned_item(KeepTrivia, item)
    WgslDirectiveScanItemKind::GlslVersion(_) =>
      compose_emit_scanned_item(KeepTrivia, item)
  }
}

///|
fn Composer::preprocess_wgsl_source_with_path(
  self : Composer,
  current_rel_path : String,
  source : String,
  session : WgslComposeSession,
  inherited_defs : WgslActiveComposeDefs?,
  inherited_bindings : WgslComposeBindingSet,
  apply_virtual_overrides : Bool,
  record_current_origins : Bool,
  alias_prefixes : Array[String],
) -> String raise ComposerError {
  let active_defs = self.active_compose_defs_for_rel_path(
    current_rel_path, session, inherited_defs,
  )
  merge_wgsl_source_local_shader_defs(active_defs, source)
  let prepared = prepare_wgsl_compose_source(source, session, active_defs)
  if record_current_origins {
    record_wgsl_source_origins_from_source(
      session,
      current_rel_path,
      prepared.active_source,
    )
  }
  let mut merged = ""
  let bindings = WgslComposeBindingSet::new()
  bindings.extend(inherited_bindings)
  let implicit_requests = self.build_wgsl_implicit_import_requests(
    current_rel_path,
    prepared.active_scan_source,
    session,
    active_defs,
  )
  let implicit_imports = self.compose_wgsl_import_requests(
    current_rel_path, implicit_requests, bindings, session, active_defs, alias_prefixes,
  )
  merged = merged + implicit_imports
  for
    item in parse_wgsl_directive_scan_items(
      prepared.active_source,
      include_glsl_version=false,
    ) {
    merged = merged +
      self.compose_wgsl_scanned_item(
        current_rel_path,
        item,
        prepared.active_scan_source,
        bindings,
        session,
        active_defs,
        alias_prefixes,
      )
  }
  finalize_wgsl_composed_source(
    merged, bindings, active_defs, session, apply_virtual_overrides,
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
  let source = self.load_wgsl_source_required_raw(normalized_rel)
  let root_source = prepend_wgsl_additional_imports(
    source,
    session.additional_imports,
  )
  self.complete_wgsl_compose_graph_execution(
    normalized_rel,
    root_source,
    session,
    None,
  )
  session.visited.set(normalized_rel, true)
  session.active_rel_paths.push(normalized_rel)
  let composed = self.preprocess_wgsl_source_with_path(
    normalized_rel,
    root_source,
    session,
    None,
    WgslComposeBindingSet::new(),
    true,
    true,
    [],
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
      diagnostics.push(
        WgslDiagnostic::new(
          WgslDiagnosticSeverity::Warn,
          "symbol redirect did not match any source identifier",
          None,
          Some(from_name),
        ),
      )
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
  let prepared_source = finalize_wgsl_output_source(composed)
  let source_files : Array[WgslSourceFile] = [
    { rel_path: normalize_shader_rel_path(rel), source: prepared_source },
  ]
  PreparedWgslSource::new(
    prepared_source,
    source_files,
    build_prepared_wgsl_source_catalog(source_files.copy()),
    session.source_origins.copy(),
    collect_wgsl_unused_redirect_diagnostics(session),
  )
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
fn compose_wgsl_source_via_ir(source : String) -> String raise ComposerError {
  let module_ = @ir.parse_wgsl_module_to_ir(source) catch {
    error => raise ComposerError::InvalidIr(error.message())
  }
  @ir.emit_wgsl_module_from_ir(module_) catch {
    error => raise ComposerError::InvalidIr(error.message())
  }
}

///|
pub fn Composer::compose_wgsl_ir(
  self : Composer,
  rel : String,
  options : WgslComposeOptions,
) -> String raise ComposerError {
  compose_wgsl_source_via_ir(self.compose_wgsl(rel, options))
}

///|
pub fn Composer::compose_wgsl_source(
  self : Composer,
  source : String,
  options : WgslComposeOptions,
) -> String raise ComposerError {
  let session = self.new_wgsl_compose_session(options)
  let root_source = prepend_wgsl_additional_imports(
    source,
    session.additional_imports,
  )
  self.complete_wgsl_compose_graph_execution("", root_source, session, None)
  let composed = strip_wgsl_virtual_functions(
    self.preprocess_wgsl_source_with_path(
      "",
      root_source,
      session,
      None,
      WgslComposeBindingSet::new(),
      true,
      false,
      [],
    ),
  )
  finalize_wgsl_output_source(composed)
}

///|
pub fn Composer::compose_wgsl_source_ir(
  self : Composer,
  source : String,
  options : WgslComposeOptions,
) -> String raise ComposerError {
  compose_wgsl_source_via_ir(self.compose_wgsl_source(source, options))
}

///|
