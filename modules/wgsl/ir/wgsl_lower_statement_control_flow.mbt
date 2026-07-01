///|
fn WgslIrLowerer::lower_loop_blocks(
  self : WgslIrLowerer,
  statement : @ast.WgslStatement,
  function : Function,
  scope : WgslIrFunctionScope,
) -> (Block, Block, Handle?) raise WgslIrLowerError {
  let body = Block::Block()
  let mut continuing = Block::Block()
  let mut break_if : Handle? = None
  match statement.blocks() {
    [body_block, ..] => {
      let child_scope = scope.loop_child()
      let mut saw_continuing = false
      let body_statements = body_block.statements()
      for index in 0..<body_statements.length() {
        let child = body_statements[index]
        match child.kind() {
          Continuing => {
            saw_continuing = true
            match child.blocks() {
              [continuing_block, ..] => {
                let continuing_scope = child_scope.loop_child()
                let result = self.lower_continuing_block(
                  continuing_block, function, continuing_scope,
                )
                continuing = result.0
                break_if = result.1
              }
              [] => continuing = Block()
            }
          }
          _ =>
            if !saw_continuing {
              self.lower_statement_with_block_context(
                child, body_statements, index, function, child_scope, body,
              )
            } else {
              raise UnsupportedStatement("statement after continuing in loop")
            }
        }
      }
    }
    [] => ()
  }
  (body, continuing, break_if)
}

///|
fn WgslIrLowerer::lower_continuing_block(
  self : WgslIrLowerer,
  block : @ast.WgslBlock,
  function : Function,
  scope : WgslIrFunctionScope,
) -> (Block, Handle?) raise WgslIrLowerError {
  let ir_block = Block::Block()
  let mut break_if : Handle? = None
  for statement in block.statements() {
    match statement.payload() {
      Break(condition) =>
        match condition {
          Some(expr_ref) =>
            break_if = Some(
              self.lower_function_expression_ref(expr_ref, function, scope),
            )
          None => ir_block.push(Break)
        }
      _ => self.lower_statement(statement, function, scope, ir_block)
    }
  }
  (ir_block, break_if)
}

///|
fn WgslIrLowerer::lower_ray_query_statement_expr_ref(
  self : WgslIrLowerer,
  expr_ref : @ast.WgslExprRef,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
) -> Bool raise WgslIrLowerError {
  match expr_ref.root() {
    Some(root) =>
      self.lower_ray_query_statement_node(root, function, scope, block)
    None => false
  }
}

///|
fn WgslIrLowerer::lower_ray_query_statement_node(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
) -> Bool raise WgslIrLowerError {
  match node.kind() {
    Group(inner) =>
      self.lower_ray_query_statement_node(inner, function, scope, block)
    Sequence([single]) =>
      self.lower_ray_query_statement_node(single, function, scope, block)
    Call(callee, arguments) => {
      let arguments = wgsl_ir_call_arguments(arguments)
      match callee.kind() {
        Identifier(name) =>
          self.lower_ray_query_statement_call(
            name.name(),
            arguments,
            function,
            scope,
            block,
          )
        _ => false
      }
    }
    _ => false
  }
}

///|
fn wgsl_ir_expr_ref_is_call(expr_ref : @ast.WgslExprRef) -> Bool {
  match expr_ref.root() {
    Some(root) => wgsl_ir_expr_node_is_call(root)
    None => false
  }
}

///|
fn WgslIrLowerer::wgsl_ir_expr_ref_is_user_function_call(
  self : WgslIrLowerer,
  expr_ref : @ast.WgslExprRef,
) -> Bool {
  match expr_ref.root() {
    Some(root) => self.wgsl_ir_expr_node_is_user_function_call(root)
    None => false
  }
}

///|
fn WgslIrLowerer::wgsl_ir_expr_node_is_user_function_call(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
) -> Bool {
  match node.kind() {
    Group(inner) => self.wgsl_ir_expr_node_is_user_function_call(inner)
    Sequence([single]) => self.wgsl_ir_expr_node_is_user_function_call(single)
    Call(callee, _) =>
      match callee.kind() {
        Identifier(name) => self.function_names.get(name.name()) != None
        _ => false
      }
    _ => false
  }
}

///|
fn wgsl_ir_expr_node_is_call(node : @ast.WgslExprNode) -> Bool {
  match node.kind() {
    Call(_, _) => true
    Group(inner) => wgsl_ir_expr_node_is_call(inner)
    Sequence([single]) => wgsl_ir_expr_node_is_call(single)
    _ => false
  }
}

///|
fn WgslIrLowerer::lower_for_statement(
  self : WgslIrLowerer,
  statement : @ast.WgslStatement,
  expressions : Array[@ast.WgslStatementExpression],
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
) -> Unit raise WgslIrLowerError {
  let loop_scope = scope.loop_child()
  let source_var_store_initializers = wgsl_ir_for_source_var_store_initializers(
    statement.local_bindings(),
    scope,
  )
  for local_decl in statement.local_bindings() {
    self.lower_local_declaration(
      local_decl,
      function,
      loop_scope,
      block,
      DeclarationArenaLocalConstant,
      source_var_store_initializers,
    )
  }
  for expr in expressions {
    if expr.role() == ForInitializer {
      self.lower_for_header_statement(
        expr.expression(),
        function,
        loop_scope,
        block,
      )
    }
  }
  let loop_body = Block::Block()
  match wgsl_ir_for_expression_by_role(expressions, ForCondition) {
    Some(condition_ref) => {
      let condition = self.lower_for_loop_condition_ref(
        condition_ref, function, loop_scope, loop_body,
      )
      loop_body.push(If(condition, Block(), { statements: [Break] }))
    }
    None => ()
  }
  match statement.blocks() {
    [body_block, ..] => {
      let body = self.lower_child_block(body_block, function, loop_scope)
      if body.statements.length() > 0 {
        loop_body.push(Block(body))
      }
    }
    [] => ()
  }
  let continuing = Block::Block()
  for expr in expressions {
    if expr.role() == ForUpdate {
      self.lower_for_header_statement(
        expr.expression(),
        function,
        loop_scope,
        continuing,
      )
    }
  }
  block.push(Loop(loop_body, continuing, None))
}

///|
fn wgsl_ir_for_source_var_store_initializers(
  locals : Array[@ast.WgslLocalDeclaration],
  parent_scope : WgslIrFunctionScope,
) -> Array[String] {
  let names : Array[String] = []
  guard parent_scope.loop_depth > 0 else { return names }
  for local_decl in locals {
    guard local_decl.kind() == Var else { continue }
    guard local_decl.initializer_ref() is Some(_) else { continue }
    names.push(local_decl.name().name())
  }
  names
}

///|
fn wgsl_ir_for_expression_by_role(
  expressions : Array[@ast.WgslStatementExpression],
  role : @ast.WgslStatementExpressionRole,
) -> @ast.WgslExprRef? {
  for expr in expressions {
    if expr.role() == role {
      return Some(expr.expression())
    }
  }
  None
}

///|
fn WgslIrLowerer::lower_switch_cases(
  self : WgslIrLowerer,
  switch_block : @ast.WgslBlock,
  function : Function,
  scope : WgslIrFunctionScope,
  selector_handle : Handle,
  cases : Array[SwitchCase],
) -> Unit raise WgslIrLowerError {
  for statement in switch_block.statements() {
    match statement.payload() {
      Case(selectors) => {
        let body = match statement.blocks() {
          [case_block, ..] =>
            self.lower_child_block(case_block, function, scope)
          [] => Block()
        }
        for selector in selectors {
          match selector {
            DefaultSelector =>
              cases.push({
                value: Default,
                body,
                fall_through: false,
                constant_dependencies: [],
              })
            ExpressionSelector(expr) =>
              cases.push({
                value: wgsl_ir_switch_value_from_ast_expression(
                  self, function, scope, selector_handle, expr,
                ),
                body,
                fall_through: false,
                constant_dependencies: self.switch_case_constant_dependencies(
                  expr, function, scope,
                ),
              })
          }
        }
      }
      DefaultCase => {
        let body = match statement.blocks() {
          [case_block, ..] =>
            self.lower_child_block(case_block, function, scope)
          [] => Block()
        }
        cases.push({
          value: Default,
          body,
          fall_through: false,
          constant_dependencies: [],
        })
      }
      Empty => ()
      _ => raise UnsupportedStatement("switch body contains non-case statement")
    }
  }
}

///|
fn WgslIrLowerer::lower_for_header_statement(
  self : WgslIrLowerer,
  expr_ref : @ast.WgslExprRef,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
) -> Unit raise WgslIrLowerError {
  let tokens = expr_ref.tokens()
  match wgsl_ir_expr_tokens_update_operator(tokens) {
    Some((target_tokens, increment)) => {
      let target = self.lower_function_lvalue_node(
        wgsl_ir_expr_node_from_tokens(target_tokens),
        function,
        scope,
      )
      self.lower_update_handle(target, function, scope, block, increment)
      return
    }
    None => ()
  }
  match wgsl_ir_expr_tokens_assignment(tokens) {
    Some((op, lhs_tokens, rhs_tokens)) => {
      if wgsl_ir_expr_tokens_are_phony(lhs_tokens) {
        let rhs_value = self.lower_function_expression_node(
          wgsl_ir_expr_node_from_tokens(rhs_tokens),
          function,
          scope,
        )
        block.push(Emit(HandleRange(rhs_value, rhs_value)))
        return
      }
      let (target, value) = match wgsl_ir_compound_assignment_operator(op) {
        Some(binary_op) => {
          let rhs_node = wgsl_ir_expr_node_from_tokens(rhs_tokens)
          if wgsl_ir_direct_access_chain_root_is_function_argument(
              rhs_node, scope,
            ) {
            self.predeclare_function_reference_roots_in_source_order(
              rhs_node, function, scope,
            )
          }
          let raw_target = self.lower_function_lvalue_node(
            wgsl_ir_expr_node_from_tokens(lhs_tokens),
            function,
            scope,
          )
          let target = self.materialize_store_pointer_if_needed(
            function, scope, block, raw_target,
          )
          let lhs_node = wgsl_ir_expr_node_from_tokens(lhs_tokens)
          if wgsl_ir_expr_node_plain_local_identifier(lhs_node, scope) {
            if wgsl_ir_compound_assignment_rhs_predeclares_reference_roots(
                rhs_node, scope,
              ) {
              self.predeclare_function_binary_chain_reference_roots_in_source_order(
                rhs_node, function, scope,
              )
            }
          }
          if wgsl_ir_direct_access_chain_root_is_function_argument(
              rhs_node, scope,
            ) {
            self.predeclare_function_reference_roots_in_source_order(
              rhs_node, function, scope,
            )
          }
          let target_value = self.compound_assignment_target_value(
            function, target,
          )
          let materialized_target = self.materialize_function_expression(
            function, scope, block, target_value,
          )
          scope.compound_assignment_rhs_depth += 1
          let rhs_value = self.lower_function_expression_node(
            wgsl_ir_expr_node_from_tokens(rhs_tokens),
            function,
            scope,
          )
          scope.compound_assignment_rhs_depth -= 1
          let rhs_value = self.materialize_store_value_if_needed(
            function, scope, block, rhs_value,
          )
          let (materialized_target, rhs_value) = self.normalize_function_binary_operands(
            function, binary_op, materialized_target, rhs_value,
          )
          let value = function.expressions.append(
            Binary(binary_op, materialized_target, rhs_value),
          )
          (target, value)
        }
        None => {
          let lhs_node = wgsl_ir_expr_node_from_tokens(lhs_tokens)
          let rhs_node = wgsl_ir_expr_node_from_tokens(rhs_tokens)
          if wgsl_ir_expr_node_plain_local_identifier(lhs_node, scope) {
            let early_raw_target : Handle? = if wgsl_ir_expr_node_is_literal_like(
                rhs_node,
              ) {
              Some(self.lower_function_lvalue_node(lhs_node, function, scope))
            } else {
              None
            }
            let rhs_value = self.lower_function_expression_node(
              rhs_node, function, scope,
            )
            let raw_target = match early_raw_target {
              Some(target) => target
              None => self.lower_function_lvalue_node(lhs_node, function, scope)
            }
            let target = self.materialize_store_pointer_if_needed(
              function, scope, block, raw_target,
            )
            let value = self.materialize_store_value_for_pointer_if_needed(
              function, scope, block, target, rhs_value,
            )
            (target, value)
          } else if self.wgsl_ir_expr_node_is_function_argument_pointer_deref(
              lhs_node, function, scope,
            ) {
            let rhs_value = self.lower_function_expression_node(
              rhs_node, function, scope,
            )
            let raw_target = self.lower_function_lvalue_node(
              lhs_node, function, scope,
            )
            let target = self.materialize_store_pointer_if_needed(
              function, scope, block, raw_target,
            )
            let value = self.materialize_store_value_for_pointer_if_needed(
              function, scope, block, target, rhs_value,
            )
            (target, value)
          } else {
            predeclare_assignment_rhs_node_root_before_target_if_needed(
              rhs_node, function, scope,
            )
            let raw_target = self.lower_function_lvalue_node(
              lhs_node, function, scope,
            )
            let target = self.materialize_store_pointer_if_needed(
              function, scope, block, raw_target,
            )
            let rhs_value = self.lower_function_expression_node(
              rhs_node, function, scope,
            )
            let value = self.materialize_store_value_for_pointer_if_needed(
              function, scope, block, target, rhs_value,
            )
            (target, value)
          }
        }
      }
      wgsl_ir_record_store_value_temporary_references(function, value)
      block.push(Store(target, value))
      return
    }
    None => ()
  }
  ignore(self.lower_function_expression_ref(expr_ref, function, scope))
}

///|
fn wgsl_ir_expr_ref_root_is_literal_like(expr_ref : @ast.WgslExprRef) -> Bool {
  match expr_ref.root() {
    Some(root) => wgsl_ir_expr_node_is_literal_like(root)
    None => false
  }
}

///|
fn predeclare_assignment_rhs_root_before_target_if_needed(
  rhs_ref : @ast.WgslExprRef,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Unit {
  match rhs_ref.root() {
    Some(root) =>
      predeclare_assignment_rhs_node_root_before_target_if_needed(
        root, function, scope,
      )
    None => ()
  }
}

///|
fn WgslIrLowerer::rhs_user_call_reads_pointer_argument(
  self : WgslIrLowerer,
  rhs_ref : @ast.WgslExprRef,
  argument_name : String,
) -> Bool {
  match rhs_ref.root() {
    Some(root) =>
      self.expression_node_contains_user_function_call(root) &&
      wgsl_ir_expr_node_contains_pointer_deref_of_argument_name(
        root, argument_name,
      )
    None => false
  }
}

///|
fn WgslIrLowerer::function_argument_pointer_deref_name_ref(
  self : WgslIrLowerer,
  expr_ref : @ast.WgslExprRef,
  function : Function,
  scope : WgslIrFunctionScope,
) -> String? {
  match expr_ref.root() {
    Some(root) =>
      self.function_argument_pointer_deref_name_node(root, function, scope)
    None => None
  }
}

///|
fn WgslIrLowerer::function_argument_pointer_deref_name_node(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> String? {
  match node.kind() {
    Group(inner) =>
      self.function_argument_pointer_deref_name_node(inner, function, scope)
    Unary(op, inner) =>
      if op == Multiply {
        self.function_argument_pointer_name_node(inner, function, scope)
      } else {
        None
      }
    _ => None
  }
}

///|
fn WgslIrLowerer::function_argument_pointer_name_node(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> String? {
  match node.kind() {
    Group(inner) =>
      self.function_argument_pointer_name_node(inner, function, scope)
    Identifier(name) =>
      match scope.arguments.get(name.name()) {
        Some(index) =>
          if self.function_argument_is_pointer(function, index) {
            Some(name.name())
          } else {
            None
          }
        None => None
      }
    _ => None
  }
}

///|
fn wgsl_ir_expr_node_contains_pointer_deref_of_argument_name(
  node : @ast.WgslExprNode,
  argument_name : String,
) -> Bool {
  if wgsl_ir_expr_node_is_pointer_deref_of_argument_name(node, argument_name) {
    return true
  }
  match node.kind() {
    Group(inner) | Unary(_, inner) | PostfixUpdate(_, inner) =>
      wgsl_ir_expr_node_contains_pointer_deref_of_argument_name(
        inner, argument_name,
      )
    Binary(_, left, right) | Assignment(_, left, right) | Index(left, right) =>
      wgsl_ir_expr_node_contains_pointer_deref_of_argument_name(
        left, argument_name,
      ) ||
      wgsl_ir_expr_node_contains_pointer_deref_of_argument_name(
        right, argument_name,
      )
    Member(base, _) | Template(base, _) =>
      wgsl_ir_expr_node_contains_pointer_deref_of_argument_name(
        base, argument_name,
      )
    Call(callee, arguments) => {
      if wgsl_ir_expr_node_contains_pointer_deref_of_argument_name(
          callee, argument_name,
        ) {
        return true
      }
      let arguments = wgsl_ir_call_arguments(arguments)
      arguments.any(fn(argument) {
        wgsl_ir_expr_node_contains_pointer_deref_of_argument_name(
          argument, argument_name,
        )
      })
    }
    Sequence(items) =>
      items.any(fn(item) {
        wgsl_ir_expr_node_contains_pointer_deref_of_argument_name(
          item, argument_name,
        )
      })
    PathAccess(base, _) =>
      wgsl_ir_expr_node_contains_pointer_deref_of_argument_name(
        base, argument_name,
      )
    Identifier(_) | Literal(_) | ShaderDefTemplate(_) => false
  }
}

///|
fn wgsl_ir_expr_node_is_pointer_deref_of_argument_name(
  node : @ast.WgslExprNode,
  argument_name : String,
) -> Bool {
  match node.kind() {
    Group(inner) =>
      wgsl_ir_expr_node_is_pointer_deref_of_argument_name(inner, argument_name)
    Unary(op, inner) =>
      op == Multiply &&
      wgsl_ir_expr_node_is_identifier_name(inner, argument_name)
    _ => false
  }
}

///|
fn wgsl_ir_expr_node_is_identifier_name(
  node : @ast.WgslExprNode,
  name : String,
) -> Bool {
  match node.kind() {
    Group(inner) => wgsl_ir_expr_node_is_identifier_name(inner, name)
    Identifier(ident) => ident.name() == name
    _ => false
  }
}

///|
fn predeclare_assignment_rhs_node_root_before_target_if_needed(
  rhs_node : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Unit {
  match wgsl_ir_expr_node_plain_mutable_local_identifier_name(rhs_node, scope) {
    Some(name) =>
      match scope.locals.get(name) {
        Some(handle) =>
          ignore(scope.local_pointer_expression(name, handle, function))
        None => ()
      }
    None => ()
  }
}

///|
fn wgsl_ir_compound_assignment_rhs_predeclares_reference_roots(
  root : @ast.WgslExprNode,
  scope : WgslIrFunctionScope,
) -> Bool {
  (
    wgsl_ir_expr_node_contains_member_access(root) &&
    wgsl_ir_expr_node_contains_plain_local_identifier(root, scope)
  ) ||
  wgsl_ir_binary_expr_node_contains_plain_local_identifier(root, scope) ||
  wgsl_ir_expr_node_is_root_call_with_function_argument_value(root, scope)
}

///|
fn wgsl_ir_binary_expr_node_contains_plain_local_identifier(
  root : @ast.WgslExprNode,
  scope : WgslIrFunctionScope,
) -> Bool {
  match wgsl_ir_expr_node_without_groups(root).kind() {
    Binary(_, _, _) =>
      wgsl_ir_expr_node_contains_plain_local_identifier(root, scope)
    _ => false
  }
}

///|
fn wgsl_ir_expr_node_is_root_call_with_function_argument_value(
  node : @ast.WgslExprNode,
  scope : WgslIrFunctionScope,
) -> Bool {
  match node.kind() {
    Group(inner) =>
      wgsl_ir_expr_node_is_root_call_with_function_argument_value(inner, scope)
    Call(_, arguments) => {
      let arguments = wgsl_ir_call_arguments(arguments)
      arguments.any(fn(argument) {
        wgsl_ir_expr_node_contains_function_argument_value(argument, scope)
      })
    }
    _ => false
  }
}

///|
fn wgsl_ir_expr_node_contains_plain_local_identifier(
  node : @ast.WgslExprNode,
  scope : WgslIrFunctionScope,
) -> Bool {
  match node.kind() {
    Identifier(ident) => scope.locals.contains(ident.name())
    Group(inner) | Unary(_, inner) | PostfixUpdate(_, inner) =>
      wgsl_ir_expr_node_contains_plain_local_identifier(inner, scope)
    Binary(_, left, right) | Assignment(_, left, right) | Index(left, right) =>
      wgsl_ir_expr_node_contains_plain_local_identifier(left, scope) ||
      wgsl_ir_expr_node_contains_plain_local_identifier(right, scope)
    Member(base, _) | Template(base, _) =>
      wgsl_ir_expr_node_contains_plain_local_identifier(base, scope)
    Call(callee, arguments) => {
      if wgsl_ir_expr_node_contains_plain_local_identifier(callee, scope) {
        return true
      }
      let arguments = wgsl_ir_call_arguments(arguments)
      arguments.any(fn(argument) {
        wgsl_ir_expr_node_contains_plain_local_identifier(argument, scope)
      })
    }
    Sequence(items) =>
      items.any(fn(item) {
        wgsl_ir_expr_node_contains_plain_local_identifier(item, scope)
      })
    Literal(_) | ShaderDefTemplate(_) | PathAccess(_, _) => false
  }
}
