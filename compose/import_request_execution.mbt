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
  let mut merged = ""
  for request in requests {
    if !session.graph_request_is_planned(current_rel_path, request) {
      raise ComposerError::FailedToResolveImport(
        "internal compose graph is missing planned request \{wgsl_import_request_visit_key(current_rel_path, request)}",
      )
    }
    let request_alias_scope = if request.alias_name != "" {
      wgsl_semantic_import_alias_prefix(request.alias_name)
    } else {
      ""
    }
    let full_module_key = wgsl_full_module_visit_key(request.rel_path, "")
    if wgsl_path_stack_contains(session.active_rel_paths, request.rel_path) {
      raise ComposerError::ImportCycle(
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
          Some(binding) => bindings.push(binding)
          None =>
            match
              find_wgsl_visible_identity_imported_item_binding(
                bindings,
                request.rel_path,
                requested_item,
              ) {
              Some(binding) => bindings.push(binding)
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
                      Some(binding) => bindings.push(binding)
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
    let raw_source = self.load_wgsl_source_required_raw(request.rel_path)
    let origin_start_index = session.symbols.source_origins.length()
    session.active_rel_paths.push(request.rel_path)
    let module_source = if request.import_full_module {
      WgslComposeEmitter(self, session).emit_source_with_path(
        request.rel_path,
        raw_source,
        Some(importer_defs),
        bindings,
        false,
        true,
        alias_prefixes,
        false,
      )
    } else {
      let import_defs = self.active_compose_defs_for_rel_path(
        request.rel_path,
        session,
        Some(importer_defs),
      )
      merge_wgsl_source_local_shader_defs(import_defs, raw_source)
      let prepared = prepare_wgsl_compose_source(
        raw_source, session, import_defs,
      )
      let extraction = extract_wgsl_module_item_origins_strict(
        prepared.active_source,
        emission_requested_items,
      ) catch {
        error => raise composer_error_from_wgsl_parse_error(error)
      }
      record_wgsl_missing_item_local_import_final_names(
        current_rel_path, request, importer_scan_source, emission_requested_items,
        extraction, session,
      )
      let extracted_source = extraction.source()
      if extracted_source == "" {
        ""
      } else {
        record_wgsl_source_origins_from_extraction(
          session,
          request.rel_path,
          extraction,
        )
        let requests = self.build_wgsl_import_requests_from_emitted_item_slice(
          request.rel_path,
          extracted_source,
          prepared.active_source,
          session,
          import_defs,
        )
        let item_bindings = WgslComposeBindingSet()
        let imported_prefix = self.compose_wgsl_import_requests(
          request.rel_path,
          requests,
          extracted_source,
          item_bindings,
          session,
          import_defs,
          alias_prefixes,
        )
        let emitted_slice = imported_prefix +
          WgslComposeEmitter(self, session).emit_source_with_path(
            request.rel_path,
            drop_wgsl_import_directives_from_compose_source(extracted_source),
            Some(importer_defs),
            item_bindings,
            false,
            false,
            alias_prefixes,
            false,
          )
        for binding in item_bindings.bindings {
          let referenced_by_importer = wgsl_semantic_source_contains_reference_path(
            importer_scan_source,
            binding.reference_path.text(),
          ) catch {
            error => raise composer_error_from_wgsl_parse_error(error)
          }
          if referenced_by_importer {
            bindings.push(binding)
          }
        }
        emitted_slice
      }
    }
    session.active_rel_paths.pop() |> ignore
    if module_source == "" {
      continue
    }
    let final_name_plan = WgslFinalNameAllocator(session, alias_prefixes).application_plan(
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
          match
            WgslComposeBinding::for_unqualified_symbol(
              origin.rel_path,
              origin.source_symbol_name,
              origin.generated_symbol_name,
              UnqualifiedItemBinding,
            ) {
            Some(binding) => bindings.push(binding)
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
    }
    merged = "\{merged}\{final_module_source}"
    if !merged.has_suffix("\n") {
      merged = "\{merged}\n"
    }
  }
  merged
}

///|
fn record_wgsl_missing_item_local_import_final_names(
  current_rel_path : String,
  request : WgslImportRequest,
  importer_scan_source : String,
  emission_requested_items : Array[String],
  extraction : WgslModuleItemExtraction,
  session : WgslComposeSession,
) -> Unit raise ComposerError {
  for requested_item in emission_requested_items {
    if wgsl_item_extraction_contains_requested_item(extraction, requested_item) {
      continue
    }
    let declares_local = wgsl_semantic_source_declares_global_name(
      importer_scan_source, requested_item,
    ) catch {
      error => raise composer_error_from_wgsl_parse_error(error)
    }
    if !declares_local {
      continue
    }
    let references_local = wgsl_semantic_source_contains_reference_path(
      importer_scan_source, requested_item,
    ) catch {
      error => raise composer_error_from_wgsl_parse_error(error)
    }
    if !references_local {
      continue
    }
    session.record_local_import_final_name(
      current_rel_path,
      requested_item,
      wgsl_naga_oil_decorated_final_name(request.module_path, requested_item),
    )
  }
}
