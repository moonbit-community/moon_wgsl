///|
fn wgsl_source_origin_kind_to_ir_declaration_kind(
  kind : WgslSourceOriginKind,
) -> @ir.WgslIrDeclarationKind? {
  match kind {
    Type => Some(Type)
    Constant => Some(Constant)
    Override => Some(Override)
    GlobalVariable => Some(GlobalVariable)
    Function => Some(Function)
    Other => None
  }
}

///|
fn wgsl_compare_import_arena_symbols_by_dependency_pull(
  lhs : @ir.WgslIrImportArenaSymbol,
  rhs : @ir.WgslIrImportArenaSymbol,
) -> Int {
  let lhs_pull = lhs.source_order_rank()
  let rhs_pull = rhs.source_order_rank()
  if lhs_pull >= 0 && rhs_pull >= 0 && lhs_pull != rhs_pull {
    return lhs_pull - rhs_pull
  }
  let lhs_decl = lhs.source_decl_rank()
  let rhs_decl = rhs.source_decl_rank()
  if lhs_pull >= 0 && rhs_pull >= 0 && lhs_decl != rhs_decl {
    return lhs_decl - rhs_decl
  }
  if lhs_pull >= 0 && rhs_decl >= 0 && lhs_pull != rhs_decl {
    return lhs_pull - rhs_decl
  }
  if rhs_pull >= 0 && lhs_decl >= 0 && lhs_decl != rhs_pull {
    return lhs_decl - rhs_pull
  }
  0
}

///|
fn Composer::compose_wgsl_import_requests(
  self : Composer,
  current_rel_path : String,
  requests : Array[WgslImportRequest],
  importer_scan_source : String,
  bindings : WgslComposeBindingSet,
  session : WgslComposeSession,
  importer_defs : WgslActiveComposeDefs,
  alias_prefixes : Array[String],
) -> String raise ComposerError {
  let merged = StringBuilder::new()
  record_wgsl_import_request_batch_link_edges(
    session.link_graph,
    current_rel_path,
    requests,
  )
  let importer_facts = collect_wgsl_compose_semantic_facts(
    session, importer_scan_source,
  )
  for request in requests {
    if !session.graph_request_is_planned(current_rel_path, request) {
      session.record_graph_planned_request(current_rel_path, request)
    }
    let request_alias_prefixes = alias_prefixes.copy()
    if request.alias_name != "" {
      request_alias_prefixes.push(
        wgsl_semantic_import_alias_prefix(request.alias_name),
      )
    }
    let request_alias_scope = request_alias_prefixes.join("__")
    let full_module_key = wgsl_full_module_visit_key(request.rel_path, "")
    if wgsl_path_stack_contains(session.active_rel_paths, request.rel_path) {
      raise ImportCycle(
        wgsl_import_cycle_string(session.active_rel_paths, request.rel_path),
      )
    }
    if request.import_full_module {
      if session.visited.contains(full_module_key) {
        collect_wgsl_cached_import_bindings(
          session,
          request.rel_path,
          request.alias_name,
          request_alias_scope,
          bindings,
        )
        |> ignore
        continue
      }
    }
    let emission_requested_items : Array[String] = []
    if !request.import_full_module && request.alias_name == "" {
      for requested_item in request.requested_items {
        match
          find_wgsl_visible_alias_imported_item_binding(
            bindings,
            request.module_path,
            requested_item,
          ) {
          Some(binding) =>
            push_wgsl_unqualified_import_binding_respecting_locals(
              bindings, binding,
            )
          None =>
            match
              find_wgsl_visible_identity_imported_item_binding(
                bindings,
                request.rel_path,
                requested_item,
              ) {
              Some(binding) =>
                push_wgsl_unqualified_import_binding_respecting_locals(
                  bindings, binding,
                )
              None =>
                match
                  find_wgsl_cached_imported_item_name(
                    session,
                    request.rel_path,
                    requested_item,
                  ) {
                  Some(imported_name) =>
                    match
                      WgslComposeBinding::for_unqualified_symbol(
                        request.rel_path,
                        requested_item,
                        imported_name,
                        UnqualifiedItemBinding,
                      ) {
                      Some(binding) => {
                        push_wgsl_unqualified_import_binding_respecting_locals(
                          bindings, binding,
                        )
                        if !session.visited.contains(
                            wgsl_imported_item_emission_key(
                              request.rel_path,
                              requested_item,
                            ),
                          ) &&
                          !session.visited.contains(full_module_key) {
                          emission_requested_items.push(requested_item)
                        }
                      }
                      None => emission_requested_items.push(requested_item)
                    }
                  None => emission_requested_items.push(requested_item)
                }
            }
        }
      }
      if request.requested_items.length() > 0 &&
        emission_requested_items.length() == 0 {
        continue
      }
    } else if !request.import_full_module {
      for requested_item in request.requested_items {
        match
          find_wgsl_cached_imported_item_name(
            session,
            request.rel_path,
            requested_item,
          ) {
          Some(imported_name) =>
            match
              WgslComposeBinding::for_alias_symbol(
                request.rel_path,
                request.alias_name,
                requested_item,
                imported_name,
                QualifiedAliasBinding,
              ) {
              Some(binding) => {
                bindings.push(binding)
                if !session.visited.contains(
                    wgsl_imported_item_emission_key(
                      request.rel_path,
                      requested_item,
                    ),
                  ) &&
                  !session.visited.contains(full_module_key) {
                  emission_requested_items.push(requested_item)
                }
              }
              None => emission_requested_items.push(requested_item)
            }
          None => emission_requested_items.push(requested_item)
        }
      }
      if request.requested_items.length() > 0 &&
        emission_requested_items.length() == 0 {
        continue
      }
    } else {
      for requested_item in request.requested_items {
        emission_requested_items.push(requested_item)
      }
    }
    let visit_key = wgsl_import_request_visit_key(current_rel_path, request)
    if session.visited.contains(visit_key) {
      continue
    }
    session.visited.add(visit_key)
    let emitted_selected_items : Array[String] = []
    let processed = self.processed_registered_wgsl_compose_module(
      request.rel_path,
      session,
      Some(importer_defs),
    )
    session.record_processed_semantic_facts(processed)
    let raw_source = processed.raw_source
    let origin_start_index = session.symbols.source_origins.length()
    let request_import_defs = processed.active_defs
    let naga_pull_ranks = processed.naga_dependency_pull_ranks()
    let source_decl_ranks = processed.declaration_source_ranks()
    session.active_rel_paths.push(request.rel_path)
    let module_source = if request.import_full_module {
      record_wgsl_planned_final_names_from_processed(
        session,
        request.rel_path,
        Some(request.module_path),
        request_alias_prefixes,
        processed,
      )
      WgslComposeEmitter(self, session).emit_source_with_path(
        request.rel_path,
        raw_source,
        Some(importer_defs),
        bindings,
        false,
        true,
        request_alias_prefixes,
        true,
        false,
      )
    } else {
      let import_defs = request_import_defs
      let prepared = processed.prepared
      let extraction = processed.item_extraction(emission_requested_items)
      let has_missing_local_fallback = record_wgsl_missing_item_local_import_final_names(
        current_rel_path, request, importer_facts, emission_requested_items, extraction,
        session,
      )
      let extracted_source = extraction.source()
      if extracted_source == "" {
        if has_missing_local_fallback {
          self.compose_wgsl_missing_item_local_dependency_imports(
            request.rel_path,
            prepared.active_source,
            session,
            import_defs,
            request_alias_prefixes,
          )
        } else {
          ""
        }
      } else {
        for origin in extraction.origins() {
          if origin.name() != "" {
            composer_string_list_push_unique(
              emitted_selected_items,
              origin.name(),
            )
          }
        }
        record_wgsl_source_origins_from_extraction(
          session,
          request.rel_path,
          extraction,
        )
        record_wgsl_planned_final_names_from_extraction(
          session,
          request.rel_path,
          Some(request.module_path),
          request_alias_prefixes,
          extraction,
        )
        let requests = self.build_wgsl_import_requests_from_emitted_item_slice(
          request.rel_path,
          extracted_source,
          prepared.active_source,
          Some(extraction),
          session,
          import_defs,
        )
        let item_bindings = WgslComposeBindingSet()
        seed_wgsl_local_declaration_bindings(
          item_bindings, current_rel_path, importer_facts,
        )
        let imported_prefix = self.compose_wgsl_import_requests(
          request.rel_path,
          requests,
          extracted_source,
          item_bindings,
          session,
          import_defs,
          request_alias_prefixes,
        )
        let local_source = drop_wgsl_import_directives_from_compose_source_cached(
          session, extracted_source,
        )
        let emitted_slice = imported_prefix +
          finalize_wgsl_composed_source(
            local_source, item_bindings, import_defs, session, false, false,
          )
        for binding in item_bindings.bindings {
          let referenced_by_importer = importer_facts.contains_reference_path(
            binding.reference_path.text(),
          )
          if referenced_by_importer {
            push_wgsl_unqualified_import_binding_respecting_locals(
              bindings, binding,
            )
          }
        }
        emitted_slice
      }
    }
    session.active_rel_paths.pop() |> ignore
    if module_source == "" {
      continue
    }
    let final_name_plan = WgslFinalNameAllocator(session, request_alias_prefixes).application_plan(
      origin_start_index,
    )
    let final_module_source = if !final_name_plan.is_empty() {
      rewrite_wgsl_declarations_with_binding_plan(
        module_source,
        final_name_plan.reference_rewrite_plan(),
      ) catch {
        error => raise composer_error_from_wgsl_parse_error(error)
      }
    } else {
      module_source
    }
    final_name_plan.apply_to_origins(session.symbols.source_origins)
    let event_generated_symbols : Array[@ir.WgslIrImportArenaSymbol] = []
    let event_item_names = if request.import_full_module {
      let names : Array[String] = []
      for i in origin_start_index..<session.symbols.source_origins.length() {
        let origin = session.symbols.source_origins[i]
        if origin.rel_path == request.rel_path &&
          origin.source_symbol_name != "" &&
          origin.generated_symbol_name != "" {
          composer_string_list_push_unique(names, origin.source_symbol_name)
        }
      }
      names
    } else {
      wgsl_import_request_copy_items(emission_requested_items)
    }
    let emitted_source_starts : @set.Set[Int] = Set([])
    for i in origin_start_index..<session.symbols.source_origins.length() {
      let origin = session.symbols.source_origins[i]
      if origin.rel_path == request.rel_path {
        emitted_source_starts.add(origin.source_start)
      }
    }
    for i in origin_start_index..<session.symbols.source_origins.length() {
      let origin = session.symbols.source_origins[i]
      if origin.rel_path == request.rel_path &&
        origin.generated_symbol_name != "" {
        match wgsl_source_origin_kind_to_ir_declaration_kind(origin.kind) {
          Some(kind) => {
            let source_decl_rank = source_decl_ranks
              .get(origin.source_symbol_name)
              .unwrap_or(-1)
            let source_pull_rank = naga_pull_ranks
              .get(origin.source_symbol_name)
              .unwrap_or(-1)
            let source_order_rank = if emitted_source_starts.contains(
                source_pull_rank,
              ) {
              -1
            } else {
              source_pull_rank
            }
            event_generated_symbols.push(
              WgslIrImportArenaSymbol(
                kind,
                origin.source_symbol_name,
                origin.generated_symbol_name,
                source_decl_rank~,
                source_order_rank~,
              ),
            )
          }
          None => ()
        }
      }
    }
    wgsl_sort_import_arena_function_symbols_by_dependency_pull(
      event_generated_symbols,
    )
    let event_kind = if request.import_full_module {
      if request.alias_name == "" {
        @ir.WgslIrImportEdgeKind::FullModule
      } else {
        AliasModule
      }
    } else {
      ItemBinding
    }
    session.link_graph.record_import_arena_event(
      current_rel_path,
      request.rel_path,
      request.module_path,
      request.alias_name,
      event_item_names,
      event_kind,
      event_generated_symbols,
    )
    session.symbols.import_arena_events.push(
      WgslIrImportArenaEvent(
        session.symbols.import_arena_events.length(),
        current_rel_path,
        request.rel_path,
        request.module_path,
        request.alias_name,
        event_item_names,
        event_kind,
        event_generated_symbols,
      ),
    )
    if request.alias_name == "" {
      for i in origin_start_index..<session.symbols.source_origins.length() {
        let origin = session.symbols.source_origins[i]
        if origin.rel_path == request.rel_path &&
          origin.source_symbol_name != "" &&
          origin.generated_symbol_name != "" &&
          wgsl_requested_items_contains(
            request.declared_items,
            origin.source_symbol_name,
          ) {
          session.record_local_spelling_final_name(
            current_rel_path,
            origin.rel_path,
            origin.source_symbol_name,
            origin.generated_symbol_name,
          )
        }
      }
    }
    if request.import_full_module {
      for i in origin_start_index..<session.symbols.source_origins.length() {
        let origin = session.symbols.source_origins[i]
        if origin.rel_path != request.rel_path ||
          origin.source_symbol_name == "" ||
          origin.generated_symbol_name == "" ||
          !wgsl_requested_items_contains(
            request.declared_items,
            origin.source_symbol_name,
          ) ||
          bindings.has_unqualified_local_name(origin.source_symbol_name) {
          continue
        }
        match
          WgslComposeBinding::for_unqualified_symbol(
            origin.rel_path,
            origin.source_symbol_name,
            origin.generated_symbol_name,
            UnqualifiedItemBinding,
          ) {
          Some(binding) => {
            push_wgsl_unqualified_import_binding_respecting_locals(
              bindings, binding,
            )
            session.record_local_spelling_final_name(
              current_rel_path,
              origin.rel_path,
              origin.source_symbol_name,
              origin.generated_symbol_name,
            )
          }
          None => ()
        }
      }
    }
    if request.alias_name != "" {
      for i in origin_start_index..<session.symbols.source_origins.length() {
        let origin = session.symbols.source_origins[i]
        if origin.rel_path == request.rel_path &&
          origin.source_symbol_name != "" &&
          origin.generated_symbol_name != "" {
          match
            WgslComposeBinding::for_alias_symbol(
              origin.rel_path,
              request.alias_name,
              origin.source_symbol_name,
              origin.generated_symbol_name,
              QualifiedAliasBinding,
            ) {
            Some(binding) => {
              bindings.push(binding)
              session.global_alias_bindings.push(binding)
            }
            None => ()
          }
        }
      }
    } else if !request.import_full_module {
      for i in origin_start_index..<session.symbols.source_origins.length() {
        let origin = session.symbols.source_origins[i]
        if origin.source_symbol_name != "" && origin.generated_symbol_name != "" {
          let directly_requested = origin.rel_path == request.rel_path &&
            wgsl_requested_items_contains(
              emission_requested_items,
              origin.source_symbol_name,
            )
          if !directly_requested {
            continue
          }
          if bindings.has_unqualified_local_name(origin.source_symbol_name) {
            continue
          }
          match
            WgslComposeBinding::for_unqualified_symbol(
              origin.rel_path,
              origin.source_symbol_name,
              origin.generated_symbol_name,
              UnqualifiedItemBinding,
            ) {
            Some(binding) => {
              bindings.push(binding)
              session.record_local_spelling_final_name(
                current_rel_path,
                origin.rel_path,
                origin.source_symbol_name,
                origin.generated_symbol_name,
              )
            }
            None => ()
          }
        }
      }
    }
    for i in origin_start_index..<session.symbols.source_origins.length() {
      let origin = session.symbols.source_origins[i]
      if origin.rel_path != "" &&
        origin.source_symbol_name != "" &&
        origin.generated_symbol_name != "" {
        if request.alias_name == "" {
          session.record_canonical_final_name_if_absent(
            WgslIrSymbolIdentity(origin.rel_path, origin.source_symbol_name),
            origin.generated_symbol_name,
          )
        } else if origin.rel_path == request.rel_path {
          let identity = WgslIrAliasSymbolIdentity(
            origin.rel_path,
            request_alias_scope,
            origin.source_symbol_name,
          )
          session.record_alias_final_name_if_absent(
            identity,
            origin.generated_symbol_name,
          )
        }
      }
    }
    if request.import_full_module {
      session.visited.add(full_module_key)
    } else {
      for requested_item in emitted_selected_items {
        session.visited.add(
          wgsl_imported_item_emission_key(request.rel_path, requested_item),
        )
      }
    }
    merged.write_string(final_module_source)
    if !final_module_source.has_suffix("\n") {
      merged.write_string("\n")
    }
  }
  merged.to_string()
}

///|
fn wgsl_sort_import_arena_function_symbols_by_dependency_pull(
  symbols : Array[@ir.WgslIrImportArenaSymbol],
) -> Unit {
  let functions : Array[@ir.WgslIrImportArenaSymbol] = []
  for symbol in symbols {
    if symbol.kind() == Function {
      functions.push(symbol)
    }
  }
  functions.sort_by(wgsl_compare_import_arena_symbols_by_dependency_pull)
  let mut next_function = 0
  for i in 0..<symbols.length() {
    if symbols[i].kind() == Function {
      symbols[i] = functions[next_function]
      next_function = next_function + 1
    }
  }
}

///|
fn seed_wgsl_local_declaration_bindings(
  bindings : WgslComposeBindingSet,
  rel_path : String,
  facts : WgslComposeSemanticFacts,
) -> Unit {
  for name in facts.global_variable_names() {
    if name == "" {
      continue
    }
    match
      WgslComposeBinding::for_unqualified_symbol(
        rel_path,
        name,
        name,
        UnqualifiedItemBinding,
      ) {
      Some(binding) => bindings.push(binding)
      None => ()
    }
  }
}

///|
fn push_wgsl_unqualified_import_binding_respecting_locals(
  bindings : WgslComposeBindingSet,
  binding : WgslComposeBinding,
) -> Unit {
  let reference_name = binding.reference_path.text()
  if binding.scope == UnqualifiedItemBinding &&
    binding.target.final_name != reference_name &&
    bindings.has_unqualified_reference_name(reference_name) {
    return
  }
  bindings.push(binding)
}

///|
fn record_wgsl_missing_item_local_import_final_names(
  current_rel_path : String,
  request : WgslImportRequest,
  importer_facts : WgslComposeSemanticFacts,
  emission_requested_items : Array[String],
  extraction : WgslModuleItemExtraction,
  session : WgslComposeSession,
) -> Bool {
  let mut recorded = false
  for requested_item in emission_requested_items {
    if wgsl_item_extraction_contains_requested_item(extraction, requested_item) {
      continue
    }
    let declares_local = importer_facts.declares_name(requested_item)
    if !declares_local {
      continue
    }
    let references_local = importer_facts.contains_reference_path(
      requested_item,
    )
    if !references_local {
      continue
    }
    session.record_local_import_final_name(
      current_rel_path,
      requested_item,
      wgsl_naga_oil_decorated_final_name(request.module_path, requested_item),
    )
    recorded = true
  }
  recorded
}

///|
fn Composer::compose_wgsl_missing_item_local_dependency_imports(
  self : Composer,
  current_rel_path : String,
  dependency_scan_source : String,
  session : WgslComposeSession,
  importer_defs : WgslActiveComposeDefs,
  alias_prefixes : Array[String],
) -> String raise ComposerError {
  let targets : Array[WgslImportTarget] = []
  collect_wgsl_import_targets_from_source_directives(
    session, dependency_scan_source, targets,
  )
  if targets.length() == 0 {
    return ""
  }
  let dependency_requests = self.build_wgsl_import_requests_from_targets(
    current_rel_path, targets, dependency_scan_source, session, importer_defs, false,
  )
  let requests : Array[WgslImportRequest] = []
  let dependency_facts = collect_wgsl_compose_semantic_facts(
    session, dependency_scan_source,
  )
  self.merge_wgsl_non_resource_dependency_requests(
    requests, dependency_requests, dependency_facts, session, importer_defs,
  )
  if requests.length() == 0 {
    return ""
  }
  self.compose_wgsl_import_requests(
    current_rel_path,
    requests,
    dependency_scan_source,
    WgslComposeBindingSet(),
    session,
    importer_defs,
    alias_prefixes,
  )
}
