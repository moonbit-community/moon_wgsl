///|
priv struct WgslPreparedComposeSource {
  active_source : String
  active_scan_source : String
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
                WgslIrSymbolIdentity("", from_name),
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
  session : WgslComposeSession,
  active_defs : WgslActiveComposeDefs,
) -> WgslPreparedComposeSource raise ComposerError {
  record_wgsl_redirect_matches(source, session)
  let redirect_plan = build_wgsl_redirect_reference_plan(session.redirects)
  let redirected_source = rewrite_wgsl_references_with_binding_plan(
    source, redirect_plan,
  ) catch {
    error => raise composer_error_from_wgsl_parse_error(error)
  }
  let active_source = apply_wgsl_template_consts(
    apply_wgsl_ifdefs_strict_for_compose(redirected_source, active_defs),
    active_defs.value_defines,
  )
  let active_scan_source = active_source
  { active_source, active_scan_source }
}

///|
fn collect_wgsl_compose_semantic_facts(
  session : WgslComposeSession,
  source : String,
) -> WgslComposeSemanticFacts raise ComposerError {
  match session.semantic_facts.get(source) {
    Some(facts) => facts
    None => {
      let declarations = collect_wgsl_named_declarations_strict(source) catch {
        error => raise composer_error_from_wgsl_parse_error(error)
      }
      let references : Array[WgslReferencePath] = []
      collect_wgsl_semantic_reference_paths(source, references) catch {
        error => raise composer_error_from_wgsl_parse_error(error)
      }
      let facts = WgslComposeSemanticFacts::{ declarations, references }
      session.semantic_facts.set(source, facts)
      facts
    }
  }
}
