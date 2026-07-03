///|
fn collect_wgsl_bound_rewrite_nodes_from_identifiers(
  identifiers : Array[WgslIdent],
  plan : WgslReferenceRewritePlan,
  nodes : Array[WgslTokenReplacement],
) -> Unit {
  plan
  .bound_identifier_rewrite_plan(identifiers)
  .collect_token_replacements(nodes)
}

///|
fn collect_wgsl_bound_block_rewrite_nodes(
  data : WgslGlobalDeclData,
  plan : WgslReferenceRewritePlan,
  rewrite_declarations : Bool,
  nodes : Array[WgslTokenReplacement],
) -> Unit {
  let identifiers : Array[WgslIdent] = []
  if rewrite_declarations {
    collect_wgsl_decl_global_declared_identifier_nodes(data, identifiers)
    collect_wgsl_bound_rewrite_nodes_from_identifiers(identifiers, plan, nodes)
    identifiers.clear()
  }
  collect_wgsl_decl_identifier_nodes(data, identifiers)
  collect_wgsl_bound_rewrite_nodes_from_identifiers(identifiers, plan, nodes)
}

///|
fn collect_wgsl_function_body_bound_rewrite_nodes(
  data : WgslGlobalDeclData,
  plan : WgslReferenceRewritePlan,
  nodes : Array[WgslTokenReplacement],
) -> Unit {
  match data {
    Function(function) => {
      let identifiers : Array[WgslIdent] = []
      collect_wgsl_function_body_identifier_nodes(function, identifiers)
      collect_wgsl_bound_rewrite_nodes_from_identifiers(
        identifiers, plan, nodes,
      )
    }
    _ => ()
  }
}
