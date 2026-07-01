///|
fn wgsl_ir_local_constant_arena_placement_for_statement(
  statement : @ast.WgslStatement,
  statements : Array[@ast.WgslStatement],
  statement_index : Int,
  scope : WgslIrFunctionScope,
) -> WgslIrLocalConstantArenaPlacement {
  match statement.payload() {
    LocalDeclaration(locals) => {
      for local_decl in locals {
        if (local_decl.kind() == Let || local_decl.kind() == Const) &&
          wgsl_ir_local_const_initializer_uses_declaration_arena(
            local_decl, statements, statement_index, scope,
          ) &&
          wgsl_ir_local_name_has_same_block_use_before_nested_flow(
            local_decl.name().name(),
            statements,
            statement_index,
          ) {
          return DeclarationArenaLocalConstant
        }
      }
      UseSiteLazyLocalConstant
    }
    _ => UseSiteLazyLocalConstant
  }
}

///|
fn wgsl_ir_source_var_store_initializers_for_statement(
  locals : Array[@ast.WgslLocalDeclaration],
  statements : Array[@ast.WgslStatement],
  statement_index : Int,
  lowerer : WgslIrLowerer,
  scope : WgslIrFunctionScope,
) -> Array[String] raise WgslIrLowerError {
  let names : Array[String] = []
  for local_decl in locals {
    if wgsl_ir_source_var_initializer_uses_store_before_next_for(
        local_decl, statements, statement_index, lowerer, scope,
      ) {
      names.push(local_decl.name().name())
    }
  }
  names
}

///|
fn wgsl_ir_source_var_initializer_uses_store_before_next_for(
  local_decl : @ast.WgslLocalDeclaration,
  statements : Array[@ast.WgslStatement],
  statement_index : Int,
  lowerer : WgslIrLowerer,
  scope : WgslIrFunctionScope,
) -> Bool raise WgslIrLowerError {
  guard local_decl.kind() == Var else { return false }
  guard local_decl.initializer_ref() is Some(expr_ref) else { return false }
  guard expr_ref.root() is Some(root) else { return false }
  guard lowerer.expression_node_is_const_initializer(root) else { return false }
  let next_index = statement_index + 1
  guard next_index < statements.length() else { return false }
  guard statements[next_index].kind() == For else { return false }
  ignore(scope)
  wgsl_ir_statement_direct_expressions_mention_identifier(
    statements[next_index],
    local_decl.name().name(),
  )
}

///|
fn wgsl_ir_local_const_initializer_uses_declaration_arena(
  local_decl : @ast.WgslLocalDeclaration,
  statements : Array[@ast.WgslStatement],
  statement_index : Int,
  scope : WgslIrFunctionScope,
) -> Bool {
  if wgsl_ir_local_const_initializer_references_local_let(local_decl, scope) {
    return true
  }
  if wgsl_ir_local_const_initializer_is_literal(local_decl) &&
    wgsl_ir_next_assignment_rhs_mentions_identifier(
      local_decl.name().name(),
      statements,
      statement_index,
    ) {
    return false
  }
  !wgsl_ir_local_const_initializer_is_bool_literal(local_decl) &&
  wgsl_ir_next_statement_mentions_identifier(
    local_decl.name().name(),
    statements,
    statement_index,
  )
}

///|
fn wgsl_ir_local_const_initializer_references_local_let(
  local_decl : @ast.WgslLocalDeclaration,
  scope : WgslIrFunctionScope,
) -> Bool {
  match local_decl.initializer_ref() {
    Some(expr_ref) =>
      match expr_ref.root() {
        Some(root) =>
          wgsl_ir_expr_node_references_local_let_constant(root, scope)
        None => false
      }
    None => false
  }
}

///|
fn wgsl_ir_local_const_initializer_is_literal(
  local_decl : @ast.WgslLocalDeclaration,
) -> Bool {
  match local_decl.initializer_ref() {
    Some(expr_ref) =>
      match expr_ref.root() {
        Some(root) => wgsl_ir_expr_node_is_literal(root)
        None => false
      }
    None => false
  }
}

///|
fn wgsl_ir_local_const_initializer_is_bool_literal(
  local_decl : @ast.WgslLocalDeclaration,
) -> Bool {
  match local_decl.initializer_ref() {
    Some(expr_ref) =>
      match expr_ref.root() {
        Some(root) => wgsl_ir_expr_node_is_bool_literal(root)
        None => false
      }
    None => false
  }
}

///|
fn wgsl_ir_expr_node_is_literal(node : @ast.WgslExprNode) -> Bool {
  match node.kind() {
    Literal(_) => true
    Group(inner) => wgsl_ir_expr_node_is_literal(inner)
    _ => false
  }
}

///|
fn wgsl_ir_expr_node_is_bool_literal(node : @ast.WgslExprNode) -> Bool {
  match node.kind() {
    Literal(token) => token.text() == "true" || token.text() == "false"
    Group(inner) => wgsl_ir_expr_node_is_bool_literal(inner)
    _ => false
  }
}

///|
fn wgsl_ir_next_assignment_rhs_mentions_identifier(
  name : String,
  statements : Array[@ast.WgslStatement],
  statement_index : Int,
) -> Bool {
  let next_index = statement_index + 1
  if next_index >= statements.length() {
    return false
  }
  match statements[next_index].payload() {
    Assignment(_, _, Some(rhs)) =>
      wgsl_ir_expr_ref_mentions_identifier(rhs, name)
    _ => false
  }
}

///|
fn wgsl_ir_next_statement_mentions_identifier(
  name : String,
  statements : Array[@ast.WgslStatement],
  statement_index : Int,
) -> Bool {
  let next_index = statement_index + 1
  if next_index >= statements.length() {
    return false
  }
  wgsl_ir_statement_direct_expressions_mention_identifier(
    statements[next_index],
    name,
  )
}

///|
fn wgsl_ir_local_name_has_same_block_use_before_nested_flow(
  name : String,
  statements : Array[@ast.WgslStatement],
  statement_index : Int,
) -> Bool {
  for index in (statement_index + 1)..<statements.length() {
    let statement = statements[index]
    if wgsl_ir_statement_direct_expressions_mention_identifier(statement, name) {
      return true
    }
    if statement.blocks().length() > 0 {
      return false
    }
  }
  false
}

///|
fn wgsl_ir_statement_direct_expressions_mention_identifier(
  statement : @ast.WgslStatement,
  name : String,
) -> Bool {
  for local_decl in statement.local_bindings() {
    match local_decl.initializer_ref() {
      Some(expr_ref) =>
        if wgsl_ir_expr_ref_mentions_identifier(expr_ref, name) {
          return true
        }
      None => ()
    }
  }
  for expr_ref in statement.expression_refs() {
    if wgsl_ir_expr_ref_mentions_identifier(expr_ref, name) {
      return true
    }
  }
  false
}

///|
fn wgsl_ir_expr_ref_mentions_identifier(
  expr_ref : @ast.WgslExprRef,
  name : String,
) -> Bool {
  match expr_ref.root() {
    Some(root) => wgsl_ir_expr_node_mentions_identifier(root, name)
    None => expr_ref.identifiers().any(fn(ident) { ident.name() == name })
  }
}

///|
fn wgsl_ir_expr_node_mentions_identifier(
  node : @ast.WgslExprNode,
  name : String,
) -> Bool {
  match node.kind() {
    Identifier(ident) => ident.name() == name
    Literal(_) | ShaderDefTemplate(_) => false
    Unary(_, expr) | PostfixUpdate(_, expr) | Group(expr) =>
      wgsl_ir_expr_node_mentions_identifier(expr, name)
    Assignment(_, lhs, rhs) | Binary(_, lhs, rhs) | Index(lhs, rhs) =>
      wgsl_ir_expr_node_mentions_identifier(lhs, name) ||
      wgsl_ir_expr_node_mentions_identifier(rhs, name)
    Call(callee, args) =>
      wgsl_ir_expr_node_mentions_identifier(callee, name) ||
      args.any(fn(arg) { wgsl_ir_expr_node_mentions_identifier(arg, name) })
    Template(callee, args) =>
      wgsl_ir_expr_node_mentions_identifier(callee, name) ||
      args.any(fn(arg) {
        match arg {
          Expression(expr) => wgsl_ir_expr_ref_mentions_identifier(expr, name)
          Type(_) => false
        }
      })
    PathAccess(base, segment) =>
      wgsl_ir_expr_node_mentions_identifier(base, name) ||
      segment.name() == name
    Member(base, _) => wgsl_ir_expr_node_mentions_identifier(base, name)
    Sequence(items) =>
      items.any(fn(item) { wgsl_ir_expr_node_mentions_identifier(item, name) })
  }
}

///|
fn wgsl_ir_expr_ref_plain_local_identifier(
  expr_ref : @ast.WgslExprRef,
  scope : WgslIrFunctionScope,
) -> Bool {
  match expr_ref.root() {
    Some(root) => wgsl_ir_expr_node_plain_local_identifier(root, scope)
    None => false
  }
}

///|
fn WgslIrLowerer::wgsl_ir_expr_ref_is_function_argument_pointer_deref(
  self : WgslIrLowerer,
  expr_ref : @ast.WgslExprRef,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Bool {
  match expr_ref.root() {
    Some(root) =>
      self.wgsl_ir_expr_node_is_function_argument_pointer_deref(
        root, function, scope,
      )
    None => false
  }
}

///|
fn WgslIrLowerer::wgsl_ir_expr_node_is_function_argument_pointer_deref(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Bool {
  match node.kind() {
    Group(inner) =>
      self.wgsl_ir_expr_node_is_function_argument_pointer_deref(
        inner, function, scope,
      )
    Unary(op, inner) =>
      if op == Multiply {
        self.wgsl_ir_expr_node_is_function_argument_pointer(
          inner, function, scope,
        )
      } else {
        false
      }
    _ => false
  }
}

///|
fn WgslIrLowerer::wgsl_ir_expr_node_is_function_argument_pointer(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Bool {
  match node.kind() {
    Group(inner) =>
      self.wgsl_ir_expr_node_is_function_argument_pointer(
        inner, function, scope,
      )
    Identifier(ident) =>
      match scope.arguments.get(ident.name()) {
        Some(index) =>
          match function.arguments.get(index) {
            Some(argument) => self.lowerer_type_is_pointer(argument.ty)
            None => false
          }
        None => false
      }
    _ => false
  }
}

///|
fn wgsl_ir_expr_node_plain_local_identifier(
  node : @ast.WgslExprNode,
  scope : WgslIrFunctionScope,
) -> Bool {
  match node.kind() {
    Identifier(ident) => scope.locals.contains(ident.name())
    Group(inner) => wgsl_ir_expr_node_plain_local_identifier(inner, scope)
    _ => false
  }
}

///|
fn wgsl_ir_expr_node_references_local_let_constant(
  node : @ast.WgslExprNode,
  scope : WgslIrFunctionScope,
) -> Bool {
  match node.kind() {
    Identifier(name) =>
      match scope.local_constants.get(name.name()) {
        Some(cell) => cell.source == LocalLet
        None => false
      }
    Literal(_) | ShaderDefTemplate(_) => false
    Unary(_, inner) | PostfixUpdate(_, inner) | Group(inner) =>
      wgsl_ir_expr_node_references_local_let_constant(inner, scope)
    Assignment(_, left, right) | Binary(_, left, right) | Index(left, right) =>
      wgsl_ir_expr_node_references_local_let_constant(left, scope) ||
      wgsl_ir_expr_node_references_local_let_constant(right, scope)
    Call(callee, arguments) => {
      let arguments = wgsl_ir_call_arguments(arguments)
      wgsl_ir_expr_node_references_local_let_constant(callee, scope) ||
      wgsl_ir_expr_node_list_references_local_let_constant(arguments, scope)
    }
    Template(callee, arguments) =>
      wgsl_ir_expr_node_references_local_let_constant(callee, scope) ||
      arguments.any(fn(argument) {
        match argument {
          Expression(expr_ref) =>
            match expr_ref.root() {
              Some(root) =>
                wgsl_ir_expr_node_references_local_let_constant(root, scope)
              None => false
            }
          Type(_) => false
        }
      })
    PathAccess(base, _) | Member(base, _) =>
      wgsl_ir_expr_node_references_local_let_constant(base, scope)
    Sequence(items) =>
      wgsl_ir_expr_node_list_references_local_let_constant(items, scope)
  }
}

///|
fn wgsl_ir_expr_node_list_references_local_let_constant(
  items : Array[@ast.WgslExprNode],
  scope : WgslIrFunctionScope,
) -> Bool {
  for item in items {
    if wgsl_ir_expr_node_references_local_let_constant(item, scope) {
      return true
    }
  }
  false
}

///|
fn wgsl_ir_expr_ref_references_local_let_constant(
  expr_ref : @ast.WgslExprRef,
  scope : WgslIrFunctionScope,
) -> Bool {
  match expr_ref.root() {
    Some(root) => wgsl_ir_expr_node_references_local_let_constant(root, scope)
    None => false
  }
}

///|
fn wgsl_ir_expr_node_plain_mutable_local_identifier_name(
  node : @ast.WgslExprNode,
  scope : WgslIrFunctionScope,
) -> String? {
  match node.kind() {
    Identifier(ident) =>
      if scope.locals.contains(ident.name()) {
        Some(ident.name())
      } else {
        None
      }
    Group(inner) =>
      wgsl_ir_expr_node_plain_mutable_local_identifier_name(inner, scope)
    _ => None
  }
}
