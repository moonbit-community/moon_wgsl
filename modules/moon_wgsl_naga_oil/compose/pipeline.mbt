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
fn drop_wgsl_import_directives_from_scan_items(
  items : Array[WgslDirectiveScanItem],
  source : String,
) -> String {
  let out = StringBuilder::new(size_hint=source.length())
  for item in items {
    match item.kind() {
      Directive(directive) if directive.kind() == Import => ()
      _ => out.write_string(item.source().original_text())
    }
  }
  out.to_string()
}

///|
fn drop_wgsl_import_directives_from_compose_source_cached(
  session : WgslComposeSession,
  source : String,
) -> String {
  match session.importless_sources.get(source) {
    Some(importless_source) => importless_source
    None => {
      let importless_source = drop_wgsl_import_directives_from_scan_items(
        session.directive_scan_items(source),
        source,
      )
      session.importless_sources.set(source, importless_source)
      importless_source
    }
  }
}

///|
fn wgsl_compose_scan_has_import_directive(
  items : Array[WgslDirectiveScanItem],
) -> Bool {
  for item in items {
    match item.kind() {
      Directive(directive) if directive.kind() == Import => return true
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
    DefineImportPath | Define => DropDirective
    Other =>
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
    Directive(import_directive) if import_directive.kind() == Import => {
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
    Directive(directive) =>
      compose_emit_scanned_item(
        wgsl_compose_directive_emission_kind(item, directive),
        item,
      )
    Source => compose_emit_scanned_item(KeepTrivia, item)
    GlslVersion(_) => compose_emit_scanned_item(KeepTrivia, item)
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
  validate_output : Bool,
) -> String raise ComposerError {
  let maybe_registered_processed = match
    self.composer.registry.registered_source(current_rel_path) {
    Some(registered_source) if registered_source == source =>
      Some(
        self.composer.processed_registered_wgsl_compose_module(
          current_rel_path,
          self.session,
          inherited_defs,
        ),
      )
    _ => None
  }
  let (active_defs, prepared) = match maybe_registered_processed {
    Some(processed) => (processed.active_defs, processed.prepared)
    None => {
      let active_defs = self.composer.active_compose_defs_for_rel_path(
        current_rel_path,
        self.session,
        inherited_defs,
      )
      merge_wgsl_source_local_shader_defs(
        active_defs,
        source,
        self.session,
        normalize_shader_rel_path(current_rel_path),
      )
      let prepared = prepare_wgsl_compose_source(
        source,
        self.session,
        active_defs,
      )
      (active_defs, prepared)
    }
  }
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
  match maybe_registered_processed {
    Some(processed) => self.session.record_processed_semantic_facts(processed)
    None => ()
  }
  match maybe_registered_processed {
    Some(processed) =>
      if processed.imports_for_virtual_side_effect() {
        self.session.emitted_virtual_functions = true
      }
    None => self.session.emitted_virtual_functions = true
  }
  if record_current_origins {
    match maybe_registered_processed {
      Some(processed) =>
        record_wgsl_source_origins_from_extraction(
          self.session,
          current_rel_path,
          processed.item_extraction([]),
        )
      None =>
        record_wgsl_source_origins_from_source(
          self.session,
          current_rel_path,
          prepared.active_source,
        )
    }
  }
  let merged = StringBuilder::new(size_hint=prepared.active_source.length())
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
  let mut explicit_imports_emitted = false
  let mut implicit_imports_emitted = false
  let scan_items = self.session.directive_scan_items(prepared.active_source)
  let has_import_directive = wgsl_compose_scan_has_import_directive(scan_items)
  let mut saw_import_directive = false
  for item in scan_items {
    match item.kind() {
      Directive(import_directive) if import_directive.kind() == Import => {
        saw_import_directive = true
        if !explicit_imports_emitted {
          explicit_imports_emitted = true
          merged.write_string(
            self.composer.compose_wgsl_import_requests(
              current_rel_path,
              explicit_requests,
              prepared.active_scan_source,
              bindings,
              self.session,
              active_defs,
              alias_prefixes,
            ),
          )
        }
      }
      _ => {
        if !implicit_imports_emitted &&
          (!has_import_directive || saw_import_directive) {
          implicit_imports_emitted = true
          merged.write_string(implicit_imports)
        }
        merged.write_string(
          self.composer.compose_wgsl_scanned_item(
            current_rel_path,
            item,
            prepared.active_scan_source,
            bindings,
            self.session,
            active_defs,
            alias_prefixes,
            declared_imports,
          ),
        )
      }
    }
  }
  if !implicit_imports_emitted {
    merged.write_string(implicit_imports)
  }
  finalize_wgsl_composed_source(
    merged.to_string(),
    bindings,
    active_defs,
    self.session,
    apply_virtual_overrides,
    validate_output,
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
    true,
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
          Warn,
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
  let root_source = self.emit_root(rel)
  let composed = if self.session.emitted_virtual_functions {
    strip_wgsl_virtual_functions(root_source)
  } else {
    root_source
  }
  let prepared_source = finalize_wgsl_output_source(composed)
  {
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
        WgslIrGeneratedImportProvenance(
          name,
          binding.rel_path,
          binding.target_name,
          VirtualOverrideSymbol,
          false,
        ),
      )
    }
  }
  let generated_symbol_import_sequences : Map[String, Int] = Map([])
  for event in self.import_arena_events {
    for generated_symbol_name in event.generated_symbol_names() {
      if !generated_symbol_import_sequences.contains(generated_symbol_name) {
        generated_symbol_import_sequences.set(
          generated_symbol_name,
          event.sequence(),
        )
      }
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
        WgslIrGeneratedImportProvenance(
          name,
          origin.rel_path(),
          origin.source_symbol_name(),
          ImportedSourceSymbol,
          root_rel_path.has_suffix(".glsl") ||
          origin.rel_path().has_suffix(".glsl"),
          local_spelling=self.generated_import_has_local_spelling(
            origin.rel_path(),
            origin.source_symbol_name(),
            name,
          ),
          root_local_spelling=self.generated_import_has_local_spelling_visible(
            root_rel_path,
            origin.rel_path(),
            origin.source_symbol_name(),
            name,
          ),
          local_spelling_visible_rel_paths=self.generated_import_local_spelling_visible_rel_paths(
            origin.rel_path(),
            origin.source_symbol_name(),
            name,
          ),
          import_sequence=generated_symbol_import_sequences
            .get(name)
            .unwrap_or(-1),
          source_start=origin.source_start,
          source_end=origin.source_end,
        ),
      )
    }
  }
  provenance
}

///|
fn WgslComposeSymbolTable::generated_import_has_local_spelling(
  self : WgslComposeSymbolTable,
  symbol_rel_path : String,
  source_name : String,
  final_name : String,
) -> Bool {
  let symbol_rel_path = normalize_shader_rel_path(symbol_rel_path)
  for binding in self.local_spelling_final_names {
    if binding.symbol_rel_path == symbol_rel_path &&
      binding.source_name == source_name &&
      (binding.final_name == "" || binding.final_name == final_name) {
      return true
    }
  }
  false
}

///|
fn WgslComposeSymbolTable::generated_import_local_spelling_visible_rel_paths(
  self : WgslComposeSymbolTable,
  symbol_rel_path : String,
  source_name : String,
  final_name : String,
) -> Array[String] {
  let symbol_rel_path = normalize_shader_rel_path(symbol_rel_path)
  let paths : Array[String] = []
  for binding in self.local_spelling_final_names {
    if binding.symbol_rel_path == symbol_rel_path &&
      binding.source_name == source_name &&
      (binding.final_name == "" || binding.final_name == final_name) &&
      !paths.contains(binding.visible_rel_path) {
      paths.push(binding.visible_rel_path)
    }
  }
  paths
}

///|
fn WgslComposeSymbolTable::generated_import_has_local_spelling_visible(
  self : WgslComposeSymbolTable,
  visible_rel_path : String,
  symbol_rel_path : String,
  source_name : String,
  final_name : String,
) -> Bool {
  let visible_rel_path = normalize_shader_rel_path(visible_rel_path)
  let symbol_rel_path = normalize_shader_rel_path(symbol_rel_path)
  for binding in self.local_spelling_final_names {
    if binding.visible_rel_path == visible_rel_path &&
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
  @ir.roundtrip_wgsl_source_via_ir_with_generated_imports_and_import_arena_events_entry_roots(
    source,
    symbols.generated_import_provenance(root_rel_path),
    symbols.import_arena_events,
  ) catch {
    error =>
      match error {
        UnknownIdentifier(name) =>
          if name.contains("::") {
            raise FailedToResolveImport(name)
          } else {
            raise InvalidIr(error.message())
          }
        _ => raise InvalidIr(error.message())
      }
  }
}

///|
fn compose_wgsl_source_via_compat_writer_ir(
  source : String,
  symbols : WgslComposeSymbolTable,
  root_rel_path : String,
) -> String raise ComposerError {
  @moon_wgsl_naga.roundtrip_wgsl_source_via_ir_with_generated_imports_and_import_arena_events_compat_writer(
    source,
    symbols.generated_import_provenance(root_rel_path),
    symbols.import_arena_events,
    root_visible_rel_path=root_rel_path,
  ) catch {
    error =>
      match error {
        UnknownIdentifier(name) =>
          if name.contains("::") {
            raise FailedToResolveImport(name)
          } else {
            raise InvalidIr(error.message())
          }
        _ => raise InvalidIr(error.message())
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
  let ir_source = compose_wgsl_source_via_compat_writer_ir(
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
  let resolved = self.resolve_wgsl_compose_source(rel, options)
  finalize_wgsl_output_source(
    compose_wgsl_source_via_compat_writer_ir(
      resolved.source,
      resolved.symbols,
      normalize_shader_rel_path(rel),
    ),
  )
}

///|
pub fn Composer::compose_wgsl_runtime_valid(
  self : Composer,
  rel : String,
  options : WgslComposeOptions,
) -> String raise ComposerError {
  let resolved = self.resolve_wgsl_compose_source(rel, options)
  finalize_wgsl_output_source(
    compose_wgsl_source_via_ir(
      resolved.source,
      resolved.symbols,
      normalize_shader_rel_path(rel),
    ),
  )
}

///|
pub fn Composer::compose_wgsl_for_naga_oil_writer_parity(
  self : Composer,
  rel : String,
  options : WgslComposeOptions,
) -> String raise ComposerError {
  let resolved = self.resolve_wgsl_compose_source(rel, options)
  compose_wgsl_source_via_compat_writer_ir(
    resolved.source,
    resolved.symbols,
    normalize_shader_rel_path(rel),
  )
}

///|
pub fn Composer::trace_naga_oil_writer_function_plan(
  self : Composer,
  rel : String,
  options : WgslComposeOptions,
  function_name_prefix : String,
) -> String raise ComposerError {
  let resolved = self.resolve_wgsl_compose_source(rel, options)
  @moon_wgsl_naga.trace_compat_writer_function_plan_for_source_with_generated_imports_and_import_arena_events(
    resolved.source,
    resolved.symbols.generated_import_provenance(normalize_shader_rel_path(rel)),
    resolved.symbols.import_arena_events,
    function_name_prefix,
    root_visible_rel_path=normalize_shader_rel_path(rel),
  ) catch {
    error =>
      match error {
        UnknownIdentifier(name) =>
          if name.contains("::") {
            raise FailedToResolveImport(name)
          } else {
            raise InvalidIr(error.message())
          }
        _ => raise InvalidIr(error.message())
      }
  }
}

///|
pub fn Composer::trace_naga_oil_writer_module_plan(
  self : Composer,
  rel : String,
  options : WgslComposeOptions,
) -> String raise ComposerError {
  let resolved = self.resolve_wgsl_compose_source(rel, options)
  @moon_wgsl_naga.trace_compat_writer_module_plan_for_source_with_generated_imports_and_import_arena_events(
    resolved.source,
    resolved.symbols.generated_import_provenance(normalize_shader_rel_path(rel)),
    resolved.symbols.import_arena_events,
    root_visible_rel_path=normalize_shader_rel_path(rel),
  ) catch {
    error =>
      match error {
        UnknownIdentifier(name) =>
          if name.contains("::") {
            raise FailedToResolveImport(name)
          } else {
            raise InvalidIr(error.message())
          }
        _ => raise InvalidIr(error.message())
      }
  }
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
      true,
    ),
  )
  compose_wgsl_source_via_ir(
    finalize_wgsl_output_source(composed),
    session.symbols,
    "",
  )
}
