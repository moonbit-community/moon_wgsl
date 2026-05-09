///|

///|
priv enum WgslComposeSourceEmissionKind {
  DropDirective
  KeepTrivia
}

///|
priv struct WgslResolvedComposeSource {
  source : String
  symbols : WgslComposeSymbolTable
  diagnostics : Array[WgslDiagnostic]
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
        current_rel_path, requests, active_scan_source, bindings, session, active_defs,
        alias_prefixes,
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
fn Composer::resolve_wgsl_source_with_path(
  self : Composer,
  current_rel_path : String,
  source : String,
  session : WgslComposeSession,
  inherited_defs : WgslActiveComposeDefs?,
  _inherited_bindings : WgslComposeBindingSet,
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
  let bindings = WgslComposeBindingSet()
  let implicit_requests = self.build_wgsl_implicit_import_requests(
    current_rel_path,
    prepared.active_scan_source,
    session,
    active_defs,
  )
  let implicit_imports = self.compose_wgsl_import_requests(
    current_rel_path,
    implicit_requests,
    prepared.active_scan_source,
    bindings,
    session,
    active_defs,
    alias_prefixes,
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
fn Composer::resolve_root_wgsl_source_into_session(
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
  let composed = self.resolve_wgsl_source_with_path(
    normalized_rel,
    root_source,
    session,
    None,
    WgslComposeBindingSet(),
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
        WgslDiagnostic(
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
fn Composer::resolve_wgsl_compose_source(
  self : Composer,
  rel : String,
  options : WgslComposeOptions,
) -> WgslResolvedComposeSource raise ComposerError {
  let session = self.new_wgsl_compose_session(options)
  let composed = strip_wgsl_virtual_functions(
    self.resolve_root_wgsl_source_into_session(rel, session),
  )
  let prepared_source = finalize_wgsl_output_source(composed)
  WgslResolvedComposeSource::{
    source: prepared_source,
    symbols: session.symbols,
    diagnostics: collect_wgsl_unused_redirect_diagnostics(session),
  }
}

///|
fn WgslComposeSymbolTable::generated_import_provenance(
  self : WgslComposeSymbolTable,
  root_rel_path : String,
) -> Array[@ir.WgslIrGeneratedImportProvenance] {
  let seen = @hashset.HashSet([])
  let provenance : Array[@ir.WgslIrGeneratedImportProvenance] = []
  for binding in self.virtual_override_final_names {
    let name = binding.override_name
    if !seen.contains(name) {
      seen.add(name)
      provenance.push(
        @ir.WgslIrGeneratedImportProvenance(
          name,
          binding.rel_path,
          binding.target_name,
          @ir.WgslIrGeneratedImportProvenanceKind::VirtualOverrideSymbol,
        ),
      )
    }
  }
  for origin in self.source_origins {
    if origin.rel_path() == root_rel_path {
      continue
    }
    let name = origin.generated_symbol_name()
    if !seen.contains(name) {
      seen.add(name)
      provenance.push(
        @ir.WgslIrGeneratedImportProvenance(
          name,
          origin.rel_path(),
          origin.source_symbol_name(),
          @ir.WgslIrGeneratedImportProvenanceKind::ImportedSourceSymbol,
        ),
      )
    }
  }
  provenance
}

///|
fn compose_wgsl_source_via_ir(
  source : String,
  symbols : WgslComposeSymbolTable,
  root_rel_path : String,
) -> String raise ComposerError {
  @ir.roundtrip_wgsl_source_via_ir_with_generated_imports(
    source,
    symbols.generated_import_provenance(root_rel_path),
  ) catch {
    error =>
      match error {
        @ir.WgslIrPipelineError::UnknownIdentifier(name) =>
          if name.contains("::") {
            raise ComposerError::FailedToResolveImport(name)
          } else {
            raise ComposerError::InvalidIr(error.message())
          }
        _ => raise ComposerError::InvalidIr(error.message())
      }
  }
}

///|
fn compose_wgsl_source_via_naga_oil_writer_compatible_ir(
  source : String,
  symbols : WgslComposeSymbolTable,
  root_rel_path : String,
) -> String raise ComposerError {
  @ir.roundtrip_wgsl_source_via_ir_with_generated_imports_naga_oil_writer_compatible(
    source,
    symbols.generated_import_provenance(root_rel_path),
  ) catch {
    error =>
      match error {
        @ir.WgslIrPipelineError::UnknownIdentifier(name) =>
          if name.contains("::") {
            raise ComposerError::FailedToResolveImport(name)
          } else {
            raise ComposerError::InvalidIr(error.message())
          }
        _ => raise ComposerError::InvalidIr(error.message())
      }
  }
}

///|
pub fn Composer::compose_wgsl_before_ir(
  self : Composer,
  rel : String,
  options : WgslComposeOptions,
) -> String raise ComposerError {
  self.resolve_wgsl_compose_source(rel, options).source
}

///|
pub fn Composer::prepare_wgsl_source(
  self : Composer,
  rel : String,
  options : WgslComposeOptions,
) -> PreparedWgslSource raise ComposerError {
  let resolved = self.resolve_wgsl_compose_source(rel, options)
  let ir_source = compose_wgsl_source_via_naga_oil_writer_compatible_ir(
    resolved.source,
    resolved.symbols,
    normalize_shader_rel_path(rel),
  )
  let source_files : Array[WgslSourceFile] = [
    { rel_path: normalize_shader_rel_path(rel), source: ir_source },
  ]
  PreparedWgslSource(
    ir_source,
    source_files,
    build_prepared_wgsl_source_catalog(source_files.copy()),
    resolved.symbols.source_origins.copy(),
    resolved.diagnostics,
  )
}

///|
pub fn Composer::prepare_wgsl_source_runtime_valid(
  self : Composer,
  rel : String,
  options : WgslComposeOptions,
) -> PreparedWgslSource raise ComposerError {
  let resolved = self.resolve_wgsl_compose_source(rel, options)
  let ir_source = compose_wgsl_source_via_ir(
    resolved.source,
    resolved.symbols,
    normalize_shader_rel_path(rel),
  )
  let source_files : Array[WgslSourceFile] = [
    { rel_path: normalize_shader_rel_path(rel), source: ir_source },
  ]
  PreparedWgslSource(
    ir_source,
    source_files,
    build_prepared_wgsl_source_catalog(source_files.copy()),
    resolved.symbols.source_origins.copy(),
    resolved.diagnostics,
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
pub fn Composer::compose_wgsl_runtime_valid(
  self : Composer,
  rel : String,
  options : WgslComposeOptions,
) -> String raise ComposerError {
  self.prepare_wgsl_source_runtime_valid(rel, options).source
}

///|
pub fn Composer::compose_wgsl_for_naga_oil_writer_parity(
  self : Composer,
  rel : String,
  options : WgslComposeOptions,
) -> String raise ComposerError {
  let resolved = self.resolve_wgsl_compose_source(rel, options)
  compose_wgsl_source_via_naga_oil_writer_compatible_ir(
    resolved.source,
    resolved.symbols,
    normalize_shader_rel_path(rel),
  )
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
    self.resolve_wgsl_source_with_path(
      "",
      root_source,
      session,
      None,
      WgslComposeBindingSet(),
      true,
      false,
      [],
    ),
  )
  compose_wgsl_source_via_ir(
    finalize_wgsl_output_source(composed),
    session.symbols,
    "",
  )
}
