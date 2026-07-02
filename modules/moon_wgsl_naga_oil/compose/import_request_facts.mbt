///|
fn wgsl_item_extraction_contains_requested_item(
  extraction : WgslModuleItemExtraction,
  requested_item : String,
) -> Bool {
  for origin in extraction.origins() {
    if origin.name() == requested_item {
      return true
    }
  }
  false
}

///|
fn wgsl_requested_items_contains(
  requested_items : Array[String],
  item_name : String,
) -> Bool {
  for requested_item in requested_items {
    if requested_item == item_name {
      return true
    }
  }
  false
}

///|
fn collect_wgsl_unqualified_live_module_items(
  declaration_names : Array[String],
  local_facts : WgslComposeSemanticFacts,
  reference_facts : WgslComposeSemanticFacts,
) -> Array[String] {
  let items : Array[String] = []
  for name in declaration_names {
    if local_facts.declares_name(name) {
      continue
    }
    let referenced = reference_facts.contains_unqualified_reference_name(name)
    if referenced {
      composer_string_list_push_unique(items, name)
    }
  }
  items
}

///|
fn wgsl_compose_semantic_facts_from_extraction(
  extraction : WgslModuleItemExtraction,
) -> WgslComposeSemanticFacts {
  let declarations : Array[String] = []
  let global_variables : Array[String] = []
  for declaration in extraction.declarations() {
    let name = declaration.name()
    if name != "" && !declarations.contains(name) {
      declarations.push(name)
    }
  }
  for origin in extraction.origins() {
    let name = origin.name()
    if origin.kind() == GlobalVariable &&
      name != "" &&
      !global_variables.contains(name) {
      global_variables.push(name)
    }
  }
  WgslComposeSemanticFacts(
    declarations,
    global_variables,
    extraction.references(),
  )
}

///|
fn record_wgsl_emitted_item_extraction_facts(
  session : WgslComposeSession,
  directive_source : String,
  extraction : WgslModuleItemExtraction?,
) -> Unit {
  match extraction {
    Some(value) => {
      let extraction_facts = wgsl_compose_semantic_facts_from_extraction(value)
      session.semantic_facts.set(directive_source, extraction_facts)
      session.record_semantic_reference_first_ranks(
        directive_source,
        value.references(),
      )
      let importless_source = drop_wgsl_import_directives_from_compose_source_cached(
        session, directive_source,
      )
      session.semantic_facts.set(importless_source, extraction_facts)
      session.record_semantic_reference_first_ranks(
        importless_source,
        value.references(),
      )
    }
    None => ()
  }
}
