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
fn drop_wgsl_import_directives_from_compose_source(source : String) -> String {
  let mut out = ""
  for
    item in parse_wgsl_directive_scan_items(source, include_glsl_version=false) {
    match item.kind() {
      WgslDirectiveScanItemKind::Directive(directive) if directive.kind() ==
        WgslDirectiveKind::Import => ()
      _ => out = out + item.source().original_text()
    }
  }
  out
}

///|
fn wgsl_compose_scan_has_import_directive(
  items : Array[WgslDirectiveScanItem],
) -> Bool {
  for item in items {
    match item.kind() {
      WgslDirectiveScanItemKind::Directive(directive) if directive.kind() ==
        WgslDirectiveKind::Import => return true
      _ => ()
    }
  }
  false
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
  declared_imports : Bool,
) -> String raise ComposerError {
  match item.kind() {
    WgslDirectiveScanItemKind::Directive(import_directive) if import_directive.kind() ==
      WgslDirectiveKind::Import => {
      let requests = if declared_imports {
        self.build_wgsl_declared_import_requests(
          current_rel_path,
          import_directive.tail(),
          session,
          active_defs,
        )
      } else {
        self.build_wgsl_import_requests(
          current_rel_path,
          import_directive.tail(),
          active_scan_source,
          session,
          active_defs,
        )
      }
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
fn WgslComposeEmitter::emit_source_with_path(
  self : WgslComposeEmitter,
  current_rel_path : String,
  source : String,
  inherited_defs : WgslActiveComposeDefs?,
  inherited_bindings : WgslComposeBindingSet,
  apply_virtual_overrides : Bool,
  record_current_origins : Bool,
  alias_prefixes : Array[String],
  declared_imports : Bool,
) -> String raise ComposerError {
  let active_defs = self.composer.active_compose_defs_for_rel_path(
    current_rel_path,
    self.session,
    inherited_defs,
  )
  merge_wgsl_source_local_shader_defs(active_defs, source)
  let prepared = prepare_wgsl_compose_source(source, self.session, active_defs)
  if record_current_origins {
    record_wgsl_source_origins_from_source(
      self.session,
      current_rel_path,
      prepared.active_source,
    )
  }
  let mut merged = ""
  let bindings = WgslComposeBindingSet()
  for binding in inherited_bindings.bindings {
    bindings.push(binding)
  }
  let implicit_requests = self.composer.build_wgsl_implicit_import_requests(
    current_rel_path,
    prepared.active_scan_source,
    self.session,
    active_defs,
  )
  let implicit_imports = self.composer.compose_wgsl_import_requests(
    current_rel_path,
    implicit_requests,
    prepared.active_scan_source,
    bindings,
    self.session,
    active_defs,
    alias_prefixes,
  )
  let explicit_requests = if declared_imports {
    self.composer.build_wgsl_declared_import_requests_from_source_directives(
      current_rel_path,
      prepared.active_source,
      self.session,
      active_defs,
    )
  } else {
    self.composer.build_wgsl_import_requests_from_source_directives(
      current_rel_path,
      prepared.active_source,
      prepared.active_scan_source,
      self.session,
      active_defs,
    )
  }
  let mut explicit_imports_emitted = false
  let mut implicit_imports_emitted = false
  let scan_items = parse_wgsl_directive_scan_items(
    prepared.active_source,
    include_glsl_version=false,
  )
  let has_import_directive = wgsl_compose_scan_has_import_directive(scan_items)
  let mut saw_import_directive = false
  for item in scan_items {
    match item.kind() {
      WgslDirectiveScanItemKind::Directive(import_directive) if import_directive.kind() ==
        WgslDirectiveKind::Import => {
        saw_import_directive = true
        if !explicit_imports_emitted {
          explicit_imports_emitted = true
          merged = merged +
            self.composer.compose_wgsl_import_requests(
              current_rel_path,
              explicit_requests,
              prepared.active_scan_source,
              bindings,
              self.session,
              active_defs,
              alias_prefixes,
            )
        }
      }
      _ => {
        if !implicit_imports_emitted &&
          (!has_import_directive || saw_import_directive) {
          implicit_imports_emitted = true
          merged = merged + implicit_imports
        }
        merged = merged +
          self.composer.compose_wgsl_scanned_item(
            current_rel_path,
            item,
            prepared.active_scan_source,
            bindings,
            self.session,
            active_defs,
            alias_prefixes,
            declared_imports,
          )
      }
    }
  }
  if !implicit_imports_emitted {
    merged = merged + implicit_imports
  }
  finalize_wgsl_composed_source(
    merged,
    bindings,
    active_defs,
    self.session,
    apply_virtual_overrides,
  )
}

///|
fn WgslComposeEmitter::emit_root(
  self : WgslComposeEmitter,
  rel : String,
) -> String raise ComposerError {
  let normalized_rel = normalize_shader_rel_path(rel)
  if normalized_rel == "" {
    return ""
  }
  if self.session.visited.contains(normalized_rel) {
    return ""
  }
  let source = self.composer.load_wgsl_source_required_raw(normalized_rel)
  let root_source = prepend_wgsl_additional_imports(
    source,
    self.session.additional_imports,
  )
  WgslImportGraphBuilder(self.composer, self.session).complete_execution(
    normalized_rel,
    root_source,
    None,
  )
  self.session.visited.add(normalized_rel)
  self.session.active_rel_paths.push(normalized_rel)
  let composed = self.emit_source_with_path(
    normalized_rel,
    root_source,
    None,
    WgslComposeBindingSet(),
    true,
    true,
    [],
    false,
  )
  self.session.active_rel_paths.pop() |> ignore
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
fn WgslComposeEmitter::resolve_compose_source(
  self : WgslComposeEmitter,
  rel : String,
) -> WgslResolvedComposeSource raise ComposerError {
  let composed = strip_wgsl_virtual_functions(self.emit_root(rel))
  let prepared_source = finalize_wgsl_output_source(composed)
  WgslResolvedComposeSource::{
    source: prepared_source,
    symbols: self.session.symbols,
    diagnostics: collect_wgsl_unused_redirect_diagnostics(self.session),
  }
}

///|
fn Composer::resolve_wgsl_compose_source(
  self : Composer,
  rel : String,
  options : WgslComposeOptions,
) -> WgslResolvedComposeSource raise ComposerError {
  let session = self.new_wgsl_compose_session(options)
  WgslComposeEmitter(self, session).resolve_compose_source(rel)
}

///|
fn WgslComposeSymbolTable::generated_import_provenance(
  self : WgslComposeSymbolTable,
  root_rel_path : String,
) -> Array[@ir.WgslIrGeneratedImportProvenance] {
  let seen = @set.Set([])
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
          false,
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
          root_rel_path.has_suffix(".glsl") ||
          origin.rel_path().has_suffix(".glsl"),
          local_spelling=self.generated_import_has_local_spelling(
            root_rel_path,
            origin.rel_path(),
            origin.source_symbol_name(),
            name,
          ),
        ),
      )
    }
  }
  provenance
}

///|
fn WgslComposeSymbolTable::generated_import_has_local_spelling(
  self : WgslComposeSymbolTable,
  root_rel_path : String,
  symbol_rel_path : String,
  source_name : String,
  final_name : String,
) -> Bool {
  let root_rel_path = normalize_shader_rel_path(root_rel_path)
  let symbol_rel_path = normalize_shader_rel_path(symbol_rel_path)
  for binding in self.local_spelling_final_names {
    if binding.visible_rel_path == root_rel_path &&
      binding.symbol_rel_path == symbol_rel_path &&
      binding.source_name == source_name &&
      (binding.final_name == "" || binding.final_name == final_name) {
      return true
    }
  }
  false
}

///|
fn compose_wgsl_source_via_ir(
  source : String,
  symbols : WgslComposeSymbolTable,
  root_rel_path : String,
) -> String raise ComposerError {
  @ir.roundtrip_wgsl_source_via_ir_with_generated_imports_entry_roots(
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
  WgslImportGraphBuilder(self, session).complete_execution(
    "",
    root_source,
    None,
  )
  let composed = strip_wgsl_virtual_functions(
    WgslComposeEmitter(self, session).emit_source_with_path(
      "",
      root_source,
      None,
      WgslComposeBindingSet(),
      true,
      false,
      [],
      false,
    ),
  )
  compose_wgsl_source_via_ir(
    finalize_wgsl_output_source(composed),
    session.symbols,
    "",
  )
}
