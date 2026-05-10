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
fn collect_wgsl_rewrite_nodes_from_identifiers(
  identifiers : Array[WgslIdent],
  rules : Array[WgslRenameRule],
  nodes : Array[WgslTokenReplacement],
) -> Unit {
  for identifier in identifiers {
    match wgsl_rename_rules_target(rules, identifier.name()) {
      Some(replacement) =>
        nodes.push(
          WgslTokenReplacement(
            identifier.start(),
            identifier.end(),
            replacement,
          ),
        )
      None => ()
    }
  }
}

///|
fn collect_wgsl_rewrite_nodes_from_expr_ref(
  expr_ref : WgslExprRef?,
  rules : Array[WgslRenameRule],
  nodes : Array[WgslTokenReplacement],
) -> Unit {
  match expr_ref {
    Some(expr) =>
      collect_wgsl_rewrite_nodes_from_identifiers(
        expr.identifiers(),
        rules,
        nodes,
      )
    None => ()
  }
}

///|
fn collect_wgsl_rewrite_nodes_from_type_ref(
  ty_ref : WgslTypeRef?,
  rules : Array[WgslRenameRule],
  nodes : Array[WgslTokenReplacement],
) -> Unit {
  match ty_ref {
    Some(ty) => {
      match ty.atom().identifier() {
        Some(identifier) =>
          match wgsl_rename_rules_target(rules, identifier.name()) {
            Some(replacement) =>
              nodes.push(
                WgslTokenReplacement(
                  identifier.start(),
                  identifier.end(),
                  replacement,
                ),
              )
            None => ()
          }
        None => ()
      }
      for argument in ty.template_arguments() {
        match argument {
          Type(ty) =>
            collect_wgsl_rewrite_nodes_from_type_ref(Some(ty), rules, nodes)
          Expression(expr) =>
            collect_wgsl_rewrite_nodes_from_expr_ref(Some(expr), rules, nodes)
        }
      }
    }
    None => ()
  }
}

///|
fn collect_wgsl_local_binding_rewrite_node(
  binding : WgslLocalDeclaration,
  source_rules : Array[WgslRenameRule],
  active_rules : Array[WgslRenameRule],
  nodes : Array[WgslTokenReplacement],
) -> Unit {
  match wgsl_rename_rules_target(source_rules, binding.name().name()) {
    Some(replacement) => {
      active_rules.push(WgslRenameRule::{
        from_name: binding.name().name(),
        to_name: replacement,
        kind: FunctionLocal,
      })
      nodes.push(
        WgslTokenReplacement(
          binding.name().start(),
          binding.name().end(),
          replacement,
        ),
      )
    }
    None => ()
  }
}

///|
fn collect_wgsl_statement_local_rewrite_nodes(
  statement : WgslStatement,
  active_rules : Array[WgslRenameRule],
  source_rules : Array[WgslRenameRule],
  nodes : Array[WgslTokenReplacement],
) -> Unit {
  let block_rules = active_rules.copy()
  for binding in statement.local_bindings() {
    collect_wgsl_rewrite_nodes_from_type_ref(
      binding.ty_ref(),
      block_rules,
      nodes,
    )
    collect_wgsl_rewrite_nodes_from_expr_ref(
      binding.initializer_ref(),
      block_rules,
      nodes,
    )
    collect_wgsl_local_binding_rewrite_node(
      binding, source_rules, block_rules, nodes,
    )
  }
  for expr_ref in statement.expression_refs() {
    collect_wgsl_rewrite_nodes_from_expr_ref(Some(expr_ref), block_rules, nodes)
  }
  for block in statement.blocks() {
    collect_wgsl_block_local_rewrite_nodes(
      block, block_rules, source_rules, nodes,
    )
  }
}

///|
fn collect_wgsl_block_local_rewrite_nodes(
  block : WgslBlock,
  inherited_rules : Array[WgslRenameRule],
  source_rules : Array[WgslRenameRule],
  nodes : Array[WgslTokenReplacement],
) -> Unit {
  let active_rules = inherited_rules.copy()
  for statement in block.statements() {
    collect_wgsl_statement_local_rewrite_nodes(
      statement, active_rules, source_rules, nodes,
    )
    for binding in statement.exported_local_bindings() {
      match wgsl_rename_rules_target(source_rules, binding.name().name()) {
        Some(replacement) =>
          active_rules.push(WgslRenameRule::{
            from_name: binding.name().name(),
            to_name: replacement,
            kind: FunctionLocal,
          })
        None => ()
      }
    }
  }
}

///|
fn collect_wgsl_function_local_rewrite_nodes(
  data : WgslGlobalDeclData,
  rules : Array[WgslRenameRule],
  nodes : Array[WgslTokenReplacement],
) -> Unit {
  match data {
    WgslGlobalDeclData::Function(function) => {
      let active_rules : Array[WgslRenameRule] = []
      for argument in function.arguments() {
        match wgsl_rename_rules_target(rules, argument.name().name()) {
          Some(replacement) => {
            active_rules.push(WgslRenameRule::{
              from_name: argument.name().name(),
              to_name: replacement,
              kind: FunctionLocal,
            })
            nodes.push(
              WgslTokenReplacement(
                argument.name().start(),
                argument.name().end(),
                replacement,
              ),
            )
          }
          None => ()
        }
      }
      collect_wgsl_block_local_rewrite_nodes(
        function.body(),
        active_rules,
        rules,
        nodes,
      )
    }
    _ => ()
  }
}

///|
fn collect_wgsl_function_body_reference_rewrite_nodes(
  data : WgslGlobalDeclData,
  rules : Array[WgslRenameRule],
  nodes : Array[WgslTokenReplacement],
) -> Unit {
  match data {
    WgslGlobalDeclData::Function(function) => {
      let identifiers : Array[WgslIdent] = []
      collect_wgsl_function_body_identifier_nodes(function, identifiers)
      collect_wgsl_rewrite_nodes_from_identifiers(identifiers, rules, nodes)
    }
    _ => ()
  }
}

///|
fn collect_wgsl_block_rewrite_nodes(
  data : WgslGlobalDeclData,
  maps : WgslRenameMaps,
  nodes : Array[WgslTokenReplacement],
) -> Unit {
  let identifiers : Array[WgslIdent] = []
  collect_wgsl_decl_global_declared_identifier_nodes(data, identifiers)
  collect_wgsl_rewrite_nodes_from_identifiers(
    identifiers,
    maps.global_declaration_rules,
    nodes,
  )
  identifiers.clear()
  collect_wgsl_decl_identifier_nodes(data, identifiers)
  collect_wgsl_rewrite_nodes_from_identifiers(
    identifiers,
    maps.reference_rules,
    nodes,
  )
  collect_wgsl_function_body_reference_rewrite_nodes(
    data,
    maps.function_body_reference_rules,
    nodes,
  )
  collect_wgsl_function_local_rewrite_nodes(
    data,
    maps.function_local_rules,
    nodes,
  )
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
