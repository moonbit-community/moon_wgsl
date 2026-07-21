///|
priv struct WgslPreparedComposeSource {
  active_source : String
  directive_scan_items : Array[WgslDirectiveScanItem]
  importless_source : String
  cache_id : Int
  mut unit : WgslTranslationUnit?
  mut semantic_facts : WgslComposeSemanticFacts?
  mut importless_semantic_facts : WgslComposeSemanticFacts?
}

///|
fn wgsl_redirect_direct_target(
  redirects : Array[WgslSymbolRedirect],
  name : String,
) -> String? {
  let mut target : String? = None
  for redirect in redirects {
    let from_name = redirect.from_name.trim().to_owned()
    let to_name = redirect.to_name.trim().to_owned()
    if from_name == name && to_name != "" && from_name != to_name {
      target = Some(to_name)
    }
  }
  target
}

///|
fn wgsl_redirect_final_target(
  redirects : Array[WgslSymbolRedirect],
  from_name : String,
) -> String? {
  let seen : Array[String] = []
  let mut current = from_name
  let mut target : String? = None
  while true {
    if seen.contains(current) {
      break
    }
    seen.push(current)
    match wgsl_redirect_direct_target(redirects, current) {
      Some(next) => {
        target = Some(next)
        current = next
      }
      None => break
    }
  }
  target
}

///|
fn build_wgsl_redirect_reference_plan(
  redirects : Array[WgslSymbolRedirect],
) -> WgslReferenceRewritePlan {
  let plan = WgslReferenceRewritePlan()
  for redirect in redirects {
    let from_name = redirect.from_name.trim().to_owned()
    if from_name == "" {
      continue
    }
    match wgsl_redirect_final_target(redirects, from_name) {
      Some(to_name) =>
        if to_name != "" && to_name != from_name {
          match WgslReferencePath::from_text(from_name) {
            Some(reference_path) =>
              plan.add_symbol_reference_binding(
                WgslComposeSymbolIdentity("", from_name),
                reference_path,
                to_name,
              )
            None => ()
          }
        }
      None => ()
    }
  }
  plan
}

///|
fn prepare_wgsl_compose_source(
  source : String,
  rel_path : String,
  session : WgslComposeSession,
  active_defs : WgslActiveComposeDefs,
) -> WgslPreparedComposeSource raise ComposerError {
  if session.redirects.length() > 0 {
    let source_facts = collect_wgsl_compose_semantic_facts(session, source)
    record_wgsl_redirect_matches(source_facts, session)
  }
  let redirect_plan = build_wgsl_redirect_reference_plan(session.redirects)
  let redirected_source = rewrite_wgsl_references_with_binding_plan(
    source, redirect_plan,
  ) catch {
    error => raise composer_error_from_wgsl_parse_error(error)
  }
  let preprocessed_source = apply_wgsl_template_consts(
    apply_wgsl_ifdefs_strict_for_compose(redirected_source, active_defs),
    active_defs.value_defines,
  )
  let relevant_specializations : Array[WgslImmediateSpecialization] = []
  let normalized_rel_path = normalize_shader_rel_path(rel_path)
  for specialization in session.immediate_specializations {
    if normalize_shader_rel_path(specialization.rel_path) == normalized_rel_path {
      relevant_specializations.push(specialization)
    }
  }
  let active_source = specialize_wgsl_immediate_globals(
    preprocessed_source, relevant_specializations,
  ) catch {
    error => raise ImmediateSpecializationFailed(error.message())
  }
  ignore(get_preprocessor_metadata(active_source, collect_import_uses=false)) catch {
    error => raise composer_error_from_metadata_error(error)
  }
  prepare_active_wgsl_compose_source(active_source, session)
}

///|
fn parse_wgsl_compose_translation_unit(
  source : String,
) -> WgslTranslationUnit raise ComposerError {
  parse_wgsl_translation_unit_strict(mask_naga_oil_directives_for_wgsl(source)) catch {
    error => raise composer_error_from_wgsl_parse_error(error)
  }
}

///|
fn wgsl_compose_semantic_facts_from_unit(
  unit : WgslTranslationUnit,
) -> WgslComposeSemanticFacts {
  let declarations = collect_wgsl_semantic_declaration_names_from_unit(unit)
  let global_variables = collect_wgsl_semantic_global_variable_names_from_unit(
    unit,
  )
  let references : Array[WgslReferencePath] = []
  collect_wgsl_semantic_reference_paths_from_unit(unit, references)
  WgslComposeSemanticFacts(declarations, global_variables, references)
}

///|
fn prepare_active_wgsl_compose_source(
  active_source : String,
  session : WgslComposeSession,
) -> WgslPreparedComposeSource {
  let directive_scan_items = parse_wgsl_directive_scan_items(
    active_source,
    include_glsl_version=false,
  )
  let importless_source = drop_wgsl_import_directives_from_scan_items(
    directive_scan_items, active_source,
  )
  let cache_id = session.source_cache_id(active_source)
  ignore(session.source_cache_id(importless_source))
  session.directive_scans.set(active_source, directive_scan_items)
  session.importless_sources.set(active_source, importless_source)
  {
    active_source,
    directive_scan_items,
    importless_source,
    cache_id,
    unit: None,
    semantic_facts: None,
    importless_semantic_facts: None,
  }
}

///|
fn WgslPreparedComposeSource::translation_unit(
  self : WgslPreparedComposeSource,
) -> WgslTranslationUnit raise ComposerError {
  match self.unit {
    Some(unit) => unit
    None => {
      let unit = parse_wgsl_compose_translation_unit(self.active_source)
      self.unit = Some(unit)
      unit
    }
  }
}

///|
fn WgslPreparedComposeSource::active_semantic_facts(
  self : WgslPreparedComposeSource,
  session : WgslComposeSession,
) -> WgslComposeSemanticFacts raise ComposerError {
  match self.semantic_facts {
    Some(facts) => facts
    None =>
      match session.semantic_facts.get(self.active_source) {
        Some(facts) => {
          self.semantic_facts = Some(facts)
          facts
        }
        None => {
          let facts = wgsl_compose_semantic_facts_from_unit(
            self.translation_unit(),
          )
          self.semantic_facts = Some(facts)
          session.semantic_facts.set(self.active_source, facts)
          facts
        }
      }
  }
}

///|
fn WgslPreparedComposeSource::reference_scan_semantic_facts(
  self : WgslPreparedComposeSource,
  session : WgslComposeSession,
) -> WgslComposeSemanticFacts raise ComposerError {
  match self.importless_semantic_facts {
    Some(facts) => facts
    None =>
      match session.semantic_facts.get(self.importless_source) {
        Some(facts) => {
          self.importless_semantic_facts = Some(facts)
          facts
        }
        None =>
          if self.importless_source == self.active_source {
            let facts = self.active_semantic_facts(session)
            self.importless_semantic_facts = Some(facts)
            facts
          } else {
            let unit = parse_wgsl_compose_translation_unit(
              self.importless_source,
            )
            let facts = wgsl_compose_semantic_facts_from_unit(unit)
            self.importless_semantic_facts = Some(facts)
            session.semantic_facts.set(self.importless_source, facts)
            facts
          }
      }
  }
}

///|
fn collect_wgsl_compose_semantic_facts(
  session : WgslComposeSession,
  source : String,
) -> WgslComposeSemanticFacts raise ComposerError {
  match session.semantic_facts.get(source) {
    Some(facts) => facts
    None => {
      let facts = wgsl_compose_semantic_facts_from_unit(
        parse_wgsl_compose_translation_unit(source),
      )
      session.semantic_facts.set(source, facts)
      facts
    }
  }
}

///|
fn WgslComposeSession::directive_scan_items(
  self : WgslComposeSession,
  source : String,
) -> Array[WgslDirectiveScanItem] {
  match self.directive_scans.get(source) {
    Some(items) => items
    None => {
      let items = parse_wgsl_directive_scan_items(
        source,
        include_glsl_version=false,
      )
      self.directive_scans.set(source, items)
      items
    }
  }
}
