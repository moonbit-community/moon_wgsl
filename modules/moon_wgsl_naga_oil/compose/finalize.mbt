///|
fn collect_wgsl_live_binding_plan(
  facts : WgslComposeSemanticFacts,
  bindings : WgslComposeBindingSet,
) -> WgslLiveBindingPlan {
  WgslReachabilityPlan(facts, bindings).live_binding_plan()
}

///|
fn collect_wgsl_effective_reference_bindings(
  session : WgslComposeSession,
  bindings : WgslComposeBindingSet,
) -> WgslComposeBindingSet {
  let effective = WgslComposeBindingSet()
  for binding in bindings.bindings {
    effective.push(binding)
  }
  for binding in session.global_alias_bindings.bindings {
    effective.push(binding)
  }
  for entry in session.symbols.emitted_final_names.alias_entries() {
    let identity = entry.identity()
    let symbol = identity.symbol()
    match
      WgslComposeBinding::for_alias_symbol(
        symbol.rel_path(),
        identity.alias_name(),
        symbol.original_name(),
        entry.final_name(),
        QualifiedAliasBinding,
      ) {
      Some(binding) => effective.push(binding)
      None => ()
    }
  }
  effective
}

///|
fn collect_wgsl_local_import_final_name_rewrite_plan(
  session : WgslComposeSession,
) -> WgslReferenceRewritePlan {
  let plan = WgslReferenceRewritePlan()
  for binding in session.symbols.local_import_final_names {
    match WgslReferencePath::from_text(binding.source_name) {
      Some(reference_path) =>
        plan.add_symbol_reference_binding(
          WgslIrSymbolIdentity(binding.rel_path, binding.source_name),
          reference_path,
          binding.final_name,
        )
      None => ()
    }
  }
  plan
}

///|
fn finalize_wgsl_composed_source(
  merged : String,
  bindings : WgslComposeBindingSet,
  active_defs : WgslActiveComposeDefs,
  session : WgslComposeSession,
  apply_virtual_overrides : Bool,
) -> String raise ComposerError {
  let mut out = apply_wgsl_ifdefs_strict_for_compose(merged, active_defs)
  out = apply_wgsl_template_consts(out, active_defs.value_defines)
  out = rewrite_wgsl_declarations_with_binding_plan(
    out,
    collect_wgsl_local_import_final_name_rewrite_plan(session),
  ) catch {
    error => raise composer_error_from_wgsl_parse_error(error)
  }
  let out_facts = collect_wgsl_compose_semantic_facts(session, out)
  let effective_bindings = collect_wgsl_effective_reference_bindings(
    session, bindings,
  )
  let live_bindings = collect_wgsl_live_binding_plan(
    out_facts, effective_bindings,
  )
  match live_bindings.first_conflict() {
    Some(message) => raise AmbiguousImportBinding(message)
    None => ()
  }
  let rewrite_plan = live_bindings.reference_rewrite_plan(session)
  if apply_virtual_overrides {
    out = apply_wgsl_virtual_overrides_with_binding_plan(out, rewrite_plan)
    out = rewrite_wgsl_references_with_binding_plan(out, rewrite_plan) catch {
      error => raise composer_error_from_wgsl_parse_error(error)
    }
  } else {
    out = rewrite_wgsl_override_targets_with_binding_plan(out, rewrite_plan)
    out = rewrite_wgsl_references_with_binding_plan(out, rewrite_plan) catch {
      error => raise composer_error_from_wgsl_parse_error(error)
    }
  }
  if !apply_virtual_overrides {
    validate_wgsl_translation_unit_strict(out)
    return out
  }
  validate_wgsl_translation_unit_strict(out)
  out
}
