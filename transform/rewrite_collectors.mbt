///|
fn collect_wgsl_bound_rewrite_nodes_from_identifiers(
  identifiers : Array[WgslIdent],
  bindings : Array[WgslReferenceRewriteBinding],
  nodes : Array[WgslTokenReplacement],
) -> Unit {
  for identifier in identifiers {
    match WgslReferencePath::from_text(identifier.name()) {
      Some(reference_path) =>
        match wgsl_symbol_binding_for_reference(bindings, reference_path) {
          Some(binding) =>
            nodes.push(
              WgslTokenReplacement(
                identifier.start(),
                identifier.end(),
                binding.final_name,
              ),
            )
          None => ()
        }
      None => ()
    }
  }
}

///|
fn collect_wgsl_bound_block_rewrite_nodes(
  data : WgslGlobalDeclData,
  bindings : Array[WgslReferenceRewriteBinding],
  rewrite_declarations : Bool,
  nodes : Array[WgslTokenReplacement],
) -> Unit {
  let identifiers : Array[WgslIdent] = []
  if rewrite_declarations {
    collect_wgsl_decl_global_declared_identifier_nodes(data, identifiers)
    collect_wgsl_bound_rewrite_nodes_from_identifiers(
      identifiers, bindings, nodes,
    )
    identifiers.clear()
  }
  collect_wgsl_decl_identifier_nodes(data, identifiers)
  collect_wgsl_bound_rewrite_nodes_from_identifiers(
    identifiers, bindings, nodes,
  )
}

///|
fn collect_wgsl_function_body_bound_rewrite_nodes(
  data : WgslGlobalDeclData,
  bindings : Array[WgslReferenceRewriteBinding],
  nodes : Array[WgslTokenReplacement],
) -> Unit {
  match data {
    WgslGlobalDeclData::Function(function) => {
      let identifiers : Array[WgslIdent] = []
      collect_wgsl_function_body_identifier_nodes(function, identifiers)
      collect_wgsl_bound_rewrite_nodes_from_identifiers(
        identifiers, bindings, nodes,
      )
    }
    _ => ()
  }
}
