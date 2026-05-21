///|
fn wgsl_ir_block_ends_with_return(block : Block) -> Bool {
  match block.statements {
    [.., Return(_)] | [.., ImplicitReturn] => true
    _ => false
  }
}

///|
fn WgslIrLowerer::lower_block(
  self : WgslIrLowerer,
  block : @ast.WgslBlock,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Block raise WgslIrLowerError {
  let ir_block = Block::Block()
  for statement in block.statements() {
    self.lower_statement(statement, function, scope, ir_block)
  }
  ir_block
}

///|
fn WgslIrLowerer::lower_child_block(
  self : WgslIrLowerer,
  block : @ast.WgslBlock,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Block raise WgslIrLowerError {
  let child_scope = scope.child()
  let lowered = self.lower_block(block, function, child_scope)
  lowered
}

///|
fn WgslIrLowerer::lower_statement(
  self : WgslIrLowerer,
  statement : @ast.WgslStatement,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
) -> Unit raise WgslIrLowerError {
  match statement.payload() {
    Empty => ()
    Compound =>
      match statement.blocks() {
        [child, ..] =>
          block.push(
            Statement::Block(self.lower_child_block(child, function, scope)),
          )
        [] => ()
      }
    LocalDeclaration(locals) =>
      for local_decl in locals {
        self.lower_local_declaration(local_decl, function, scope, block)
      }
    Return(expr) => {
      let value = match expr {
        Some(expr_ref) => {
          let expected_ty = match function.result {
            Some(result) => Some(result.ty)
            None => None
          }
          let handle = self.lower_function_expression_ref_with_expected(
            expr_ref, function, scope, expected_ty,
          )
          Some(
            self.materialize_return_expression_if_needed(
              function, scope, block, handle,
            ),
          )
        }
        None => None
      }
      block.push(Statement::Return(value))
    }
    If(condition) => {
      guard condition is Some(condition_ref) else {
        raise WgslIrLowerError::UnsupportedStatement("if without condition")
      }
      let condition_handle = self.lower_function_expression_ref(
        condition_ref, function, scope,
      )
      let condition_handle = self.materialize_control_flow_condition_if_needed(
        function, scope, block, condition_handle,
      )
      let condition_refs = wgsl_ir_statement_condition_refs(
        statement.expressions(),
      )
      guard condition_refs.length() > 0 else {
        raise WgslIrLowerError::UnsupportedStatement("if without condition")
      }
      let blocks = statement.blocks()
      let then_block = match statement.blocks() {
        [then_child, ..] => self.lower_child_block(then_child, function, scope)
        [] => Block::Block()
      }
      let else_block = self.lower_if_reject_chain(
        blocks, condition_refs, 1, function, scope,
      )
      block.push(Statement::If(condition_handle, then_block, else_block))
    }
    While(condition) => {
      guard condition is Some(condition_ref) else {
        raise WgslIrLowerError::UnsupportedStatement("while without condition")
      }
      let cond = self.lower_function_expression_ref(
        condition_ref, function, scope,
      )
      let lowered_body = match statement.blocks() {
        [body_block, ..] => self.lower_child_block(body_block, function, scope)
        [] => Block::Block()
      }
      let body_statements : Array[Statement] = []
      let guard_block = Block::{ statements: body_statements }
      let cond = self.materialize_control_flow_condition_if_needed(
        function, scope, guard_block, cond,
      )
      body_statements.push(
        Statement::If(cond, Block::Block(), Block::{
          statements: [Statement::Break],
        }),
      )
      for body_statement in lowered_body.statements {
        body_statements.push(body_statement)
      }
      block.push(Statement::Loop(guard_block, Block::Block(), None))
    }
    Loop => {
      let (body, continuing, break_if) = self.lower_loop_blocks(
        statement, function, scope,
      )
      block.push(Statement::Loop(body, continuing, break_if))
    }
    Break(_) => block.push(Statement::Break)
    Continue => block.push(Statement::Continue)
    Discard => block.push(Statement::Kill)
    Assignment(op, lhs, rhs) => {
      guard lhs is Some(lhs_ref) else {
        raise WgslIrLowerError::UnsupportedStatement("assignment without lhs")
      }
      guard rhs is Some(rhs_ref) else {
        raise WgslIrLowerError::UnsupportedStatement("assignment without rhs")
      }
      if wgsl_ir_expr_ref_is_phony(lhs_ref) {
        if self.lower_ray_query_statement_expr_ref(
            rhs_ref, function, scope, block,
          ) {
          return
        }
        let rhs_value = self.lower_function_expression_ref(
          rhs_ref, function, scope,
        )
        block.push(Statement::Emit(HandleRange(rhs_value, rhs_value)))
        return
      }
      let raw_target = self.lower_function_lvalue_ref(lhs_ref, function, scope)
      let target = self.materialize_store_pointer_if_needed(
        function, scope, block, raw_target,
      )
      let value = match wgsl_ir_compound_assignment_operator(op) {
        Some(binary_op) => {
          let target_value = self.compound_assignment_target_value(
            function, target,
          )
          let materialized_target = self.materialize_function_expression(
            function, scope, block, target_value,
          )
          let rhs_value = self.lower_function_expression_ref(
            rhs_ref, function, scope,
          )
          let rhs_value = self.materialize_store_value_if_needed(
            function, scope, block, rhs_value,
          )
          function.expressions.append(
            Expression::Binary(binary_op, materialized_target, rhs_value),
          )
        }
        None => {
          let rhs_value = self.lower_function_expression_ref(
            rhs_ref, function, scope,
          )
          self.materialize_store_value_if_needed(
            function, scope, block, rhs_value,
          )
        }
      }
      wgsl_ir_record_store_value_temporary_references(function, value)
      block.push(Statement::Store(target, value))
    }
    Increment(target) =>
      self.lower_update_statement(target, function, scope, block, true)
    Decrement(target) =>
      self.lower_update_statement(target, function, scope, block, false)
    FunctionCall(expr) => {
      guard expr is Some(expr_ref) else {
        raise WgslIrLowerError::UnsupportedStatement(
          "function call without expression",
        )
      }
      self.lower_call_statement(expr_ref, function, scope, block)
    }
    Expression(expr) =>
      match expr {
        Some(expr_ref) =>
          if self.lower_ray_query_statement_expr_ref(
              expr_ref, function, scope, block,
            ) {
            ()
          } else if wgsl_ir_expr_ref_is_call(expr_ref) {
            self.lower_call_statement(expr_ref, function, scope, block)
          } else {
            let handle = self.lower_function_expression_ref(
              expr_ref, function, scope,
            )
            block.push(Statement::Emit(HandleRange(handle, handle)))
          }
        None => ()
      }
    ConstAssert(expr) => {
      guard expr is Some(expr_ref) else {
        raise WgslIrLowerError::UnsupportedStatement(
          "const_assert without expression",
        )
      }
      block.push(
        Statement::ConstAssert(
          self.lower_function_expression_ref(expr_ref, function, scope),
        ),
      )
    }
    For(expressions) =>
      self.lower_for_statement(statement, expressions, function, scope, block)
    Switch(selector) => {
      guard selector is Some(selector_ref) else {
        raise WgslIrLowerError::UnsupportedStatement("switch without selector")
      }
      let selector_handle = self.lower_function_expression_ref(
        selector_ref, function, scope,
      )
      let cases : Array[SwitchCase] = []
      match statement.blocks() {
        [switch_block, ..] =>
          self.lower_switch_cases(
            switch_block, function, scope, selector_handle, cases,
          )
        [] => ()
      }
      block.push(Statement::Switch(selector_handle, cases))
    }
    Case(_) | DefaultCase =>
      raise WgslIrLowerError::UnsupportedStatement(
        "structured statement not yet representable by this WGSL IR lowerer",
      )
  }
}

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
      let child_scope = scope.child()
      let mut saw_continuing = false
      for child in body_block.statements() {
        match child.kind() {
          Continuing => {
            saw_continuing = true
            match child.blocks() {
              [continuing_block, ..] => {
                let continuing_scope = child_scope.child()
                let result = self.lower_continuing_block(
                  continuing_block, function, continuing_scope,
                )
                continuing = result.0
                break_if = result.1
              }
              [] => continuing = Block::Block()
            }
          }
          _ =>
            if !saw_continuing {
              self.lower_statement(child, function, child_scope, body)
            } else {
              raise WgslIrLowerError::UnsupportedStatement(
                "statement after continuing in loop",
              )
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
          None => ir_block.push(Statement::Break)
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
  let loop_scope = scope.child()
  for local_decl in statement.local_bindings() {
    self.lower_local_declaration(local_decl, function, loop_scope, block)
  }
  for expr in expressions {
    if expr.role() == @ast.WgslStatementExpressionRole::ForInitializer {
      self.lower_for_header_statement(
        expr.expression(),
        function,
        loop_scope,
        block,
      )
    }
  }
  let loop_body = Block::Block()
  match
    wgsl_ir_for_expression_by_role(
      expressions,
      @ast.WgslStatementExpressionRole::ForCondition,
    ) {
    Some(condition_ref) => {
      let condition = self.lower_function_expression_ref(
        condition_ref, function, loop_scope,
      )
      let condition = self.materialize_for_loop_condition_if_needed(
        function, loop_scope, loop_body, condition,
      )
      loop_body.push(
        Statement::If(condition, Block::Block(), Block::{
          statements: [Statement::Break],
        }),
      )
    }
    None => ()
  }
  match statement.blocks() {
    [body_block, ..] => {
      let body = self.lower_child_block(body_block, function, loop_scope)
      if body.statements.length() > 0 {
        loop_body.push(Statement::Block(body))
      }
    }
    [] => ()
  }
  let continuing = Block::Block()
  for expr in expressions {
    if expr.role() == @ast.WgslStatementExpressionRole::ForUpdate {
      self.lower_for_header_statement(
        expr.expression(),
        function,
        loop_scope,
        continuing,
      )
    }
  }
  block.push(Statement::Loop(loop_body, continuing, None))
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
          [] => Block::Block()
        }
        for selector in selectors {
          match selector {
            DefaultSelector =>
              cases.push(SwitchCase::{
                value: Default,
                body,
                fall_through: false,
              })
            ExpressionSelector(expr) => {
              let case_selector_handle = self.lower_function_expression_ref(
                expr, function, scope,
              )
              cases.push(SwitchCase::{
                value: wgsl_ir_switch_value_from_expression(
                  self, function, selector_handle, case_selector_handle,
                ),
                body,
                fall_through: false,
              })
            }
          }
        }
      }
      DefaultCase => {
        let body = match statement.blocks() {
          [case_block, ..] =>
            self.lower_child_block(case_block, function, scope)
          [] => Block::Block()
        }
        cases.push(SwitchCase::{ value: Default, body, fall_through: false })
      }
      Empty => ()
      _ =>
        raise WgslIrLowerError::UnsupportedStatement(
          "switch body contains non-case statement",
        )
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
        block.push(Statement::Emit(HandleRange(rhs_value, rhs_value)))
        return
      }
      let raw_target = self.lower_function_lvalue_node(
        wgsl_ir_expr_node_from_tokens(lhs_tokens),
        function,
        scope,
      )
      let target = self.materialize_store_pointer_if_needed(
        function, scope, block, raw_target,
      )
      let value = match wgsl_ir_compound_assignment_operator(op) {
        Some(binary_op) => {
          let target_value = self.compound_assignment_target_value(
            function, target,
          )
          let materialized_target = self.materialize_function_expression(
            function, scope, block, target_value,
          )
          let rhs_value = self.lower_function_expression_node(
            wgsl_ir_expr_node_from_tokens(rhs_tokens),
            function,
            scope,
          )
          let rhs_value = self.materialize_store_value_if_needed(
            function, scope, block, rhs_value,
          )
          function.expressions.append(
            Expression::Binary(binary_op, materialized_target, rhs_value),
          )
        }
        None => {
          let rhs_value = self.lower_function_expression_node(
            wgsl_ir_expr_node_from_tokens(rhs_tokens),
            function,
            scope,
          )
          self.materialize_store_value_if_needed(
            function, scope, block, rhs_value,
          )
        }
      }
      wgsl_ir_record_store_value_temporary_references(function, value)
      block.push(Statement::Store(target, value))
      return
    }
    None => ()
  }
  ignore(self.lower_function_expression_ref(expr_ref, function, scope))
}

///|
fn WgslIrLowerer::lower_local_declaration(
  self : WgslIrLowerer,
  local_decl : @ast.WgslLocalDeclaration,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
) -> Unit raise WgslIrLowerError {
  if local_decl.kind() == @ast.WgslLocalDeclarationKind::Const {
    self.lower_local_const_declaration(local_decl, function, scope)
    return
  }
  let explicit_ty = match local_decl.ty_ref() {
    Some(ty_ref) => Some(self.lower_function_type_ref(ty_ref, function, scope))
    None => None
  }
  let mut address_of_ty : Handle? = None
  let mut init = match local_decl.initializer_ref() {
    Some(expr_ref) =>
      match wgsl_ir_address_of_operand_ref(expr_ref) {
        Some(target_ref) => {
          let target = self.lower_function_lvalue_node(
            target_ref, function, scope,
          )
          let pointer_ty = self.pointer_type_for_lvalue(function, target)
          address_of_ty = Some(pointer_ty)
          Some(
            function.expressions.append(
              Expression::AddressOf(pointer_ty, target),
            ),
          )
        }
        None =>
          Some(
            self.lower_function_expression_ref_with_expected(
              expr_ref, function, scope, explicit_ty,
            ),
          )
      }
    None => None
  }
  if local_decl.kind() == @ast.WgslLocalDeclarationKind::Let {
    match init {
      Some(init_handle) => {
        if self.function_expression_is_const_expression(function, init_handle) &&
          self.function_expression_has_scalar_type(function, init_handle) {
          let init_handle = self.normalized_local_constant_initializer(
            function, init_handle,
          )
          ignore(scope.locals.remove(local_decl.name().name()))
          ignore(
            scope.local_pointer_expressions.remove(local_decl.name().name()),
          )
          scope.local_constants.set(local_decl.name().name(), init_handle)
          return
        }
        let materialized = self.materialize_return_subexpressions(
          function, scope, block, init_handle,
        )
        if materialized != init_handle {
          init = Some(materialized)
        }
        match init {
          Some(normalized) =>
            if self.function_expression_should_materialize_as_let_initializer(
                function, normalized,
              ) {
              let materialized_value = self.materialize_function_expression(
                function, scope, block, normalized,
              )
              ignore(scope.locals.remove(local_decl.name().name()))
              ignore(
                scope.local_pointer_expressions.remove(local_decl.name().name()),
              )
              scope.local_constants.set(
                local_decl.name().name(),
                materialized_value,
              )
              return
            }
          _ => ()
        }
      }
      None => ()
    }
  }
  let ty = match explicit_ty {
    Some(ty) => ty
    None =>
      match address_of_ty {
        Some(pointer_ty) => pointer_ty
        None =>
          match init {
            Some(init_handle) =>
              match self.address_of_expression_type(function, init_handle) {
                Some(inferred) => inferred
                None =>
                  match self.function_expression_type(function, init_handle) {
                    Some(inferred) => inferred
                    None =>
                      self.infer_local_type_from_initializer(
                        local_decl.name().name(),
                        local_decl.initializer_ref(),
                      )
                  }
              }
            None =>
              self.infer_local_type_from_initializer(
                local_decl.name().name(),
                local_decl.initializer_ref(),
              )
          }
      }
  }
  let ty = self.local_declaration_storage_type(local_decl.kind(), ty)
  match init {
    Some(init_handle) =>
      self.contextualize_function_expression_for_type(function, init_handle, ty)
    None => ()
  }
  let lowered_name = self.naga_oil_generated_import_local_spelling_for_scope(
    local_decl.name().name(),
    scope,
  )
  let var_init_in_declaration = if local_decl.kind() ==
    @ast.WgslLocalDeclarationKind::Var {
    match init {
      Some(init_handle) =>
        self.function_expression_is_const_expression(function, init_handle)
      None => false
    }
  } else {
    false
  }
  let handle = function.local_variables.append(LocalVariable::{
    name: Some(lowered_name),
    kind: wgsl_ir_local_variable_kind(local_decl.kind()),
    generated_temporary: false,
    generated_temporary_store_value_reference: false,
    ty,
    init: if local_decl.kind() == @ast.WgslLocalDeclarationKind::Var {
      if var_init_in_declaration {
        init
      } else {
        None
      }
    } else {
      init
    },
  })
  ignore(scope.local_constants.remove(local_decl.name().name()))
  ignore(scope.local_pointer_expressions.remove(local_decl.name().name()))
  scope.locals.set(local_decl.name().name(), handle)
  block.push(Statement::Declare(handle))
  if local_decl.kind() == @ast.WgslLocalDeclarationKind::Var {
    match init {
      Some(init_handle) =>
        if !var_init_in_declaration {
          let materialized = self.materialize_store_value_if_needed(
            function, scope, block, init_handle,
          )
          wgsl_ir_record_store_value_temporary_references(
            function, materialized,
          )
          block.push(
            Statement::Store(
              scope.local_pointer_expression(
                local_decl.name().name(),
                handle,
                function,
              ),
              materialized,
            ),
          )
        }
      _ => ()
    }
  }
}

///|
fn WgslIrLowerer::function_expression_should_materialize_as_let_initializer(
  self : WgslIrLowerer,
  function : Function,
  value : Handle,
) -> Bool {
  ignore(self)
  match function.expressions.items.get(value.index()) {
    Some(FunctionCall(_, _))
    | Some(AtomicCall(_, _))
    | Some(WorkGroupUniformLoad(_)) => true
    _ => false
  }
}

///|
fn WgslIrLowerer::lower_local_const_declaration(
  self : WgslIrLowerer,
  local_decl : @ast.WgslLocalDeclaration,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Unit raise WgslIrLowerError {
  let explicit_ty = match local_decl.ty_ref() {
    Some(ty_ref) => Some(self.lower_function_type_ref(ty_ref, function, scope))
    None => None
  }
  let init = match local_decl.initializer_ref() {
    Some(expr_ref) =>
      self.lower_function_expression_ref_with_expected(
        expr_ref, function, scope, explicit_ty,
      )
    None => raise WgslIrLowerError::MissingType(local_decl.name().name())
  }
  if !self.function_expression_is_const_expression(function, init) {
    raise WgslIrLowerError::UnsupportedExpression(
      "local const initializer is not a const expression",
    )
  }
  let init = self.normalized_local_constant_initializer(function, init)
  ignore(scope.locals.remove(local_decl.name().name()))
  scope.local_constants.set(local_decl.name().name(), init)
}

///|
fn WgslIrLowerer::function_expression_has_scalar_type(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle,
) -> Bool {
  match self.function_expression_type(function, handle) {
    Some(ty_handle) =>
      match self.shader_module.types.get(ty_handle) {
        Some(type_) =>
          match type_.inner {
            Scalar(_) => true
            _ => false
          }
        None => false
      }
    None => false
  }
}

///|
fn WgslIrLowerer::function_expression_is_const_expression(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle,
) -> Bool {
  match function.expressions.items.get(handle.index()) {
    Some(expression) =>
      self.function_expression_inner_is_const_expression(function, expression)
    None => false
  }
}

///|
fn WgslIrLowerer::function_expression_inner_is_const_expression(
  self : WgslIrLowerer,
  function : Function,
  expression : Expression,
) -> Bool {
  match expression {
    Literal(_) | Constant(_) | ZeroValue(_) => true
    Override(_)
    | FunctionArgument(_)
    | GlobalVariable(_)
    | LocalVariable(_)
    | Load(_)
    | AddressOf(_, _)
    | FunctionCall(_, _)
    | AtomicCall(_, _)
    | ImageSample(_, _, _, _, _, _, _, _, _)
    | ImageLoad(_, _, _, _, _)
    | ImageQuery(_, _)
    | CallResult(_)
    | AtomicResult(_, _)
    | WorkGroupUniformLoadResult(_)
    | WorkGroupUniformLoad(_)
    | ArrayLength(_)
    | RayQueryInitialize(_, _, _)
    | RayQueryProceed(_)
    | RayQueryGenerateIntersection(_, _)
    | RayQueryConfirmIntersection(_)
    | RayQueryTerminate(_)
    | RayQueryVertexPositions(_, _)
    | RayQueryProceedResult
    | RayQueryGetIntersection(_, _)
    | SubgroupCall(_, _)
    | SubgroupBallotResult
    | SubgroupOperationResult(_)
    | CooperativeLoad(_, _, _, _)
    | CooperativeMultiplyAdd(_, _, _) => false
    Compose(_, components) =>
      self.function_expression_list_is_const_expression(function, components)
    Access(base, index) =>
      self.function_expression_is_const_expression(function, base) &&
      self.function_expression_is_const_expression(function, index)
    AccessIndex(base, _) | Splat(_, base) | Swizzle(_, base, _) =>
      self.function_expression_is_const_expression(function, base)
    Unary(_, inner)
    | Bitcast(_, inner)
    | Relational(_, inner)
    | As(inner, _, _) =>
      self.function_expression_is_const_expression(function, inner)
    Binary(_, left, right) =>
      self.function_expression_is_const_expression(function, left) &&
      self.function_expression_is_const_expression(function, right)
    Select(left, right, condition) =>
      self.function_expression_is_const_expression(function, left) &&
      self.function_expression_is_const_expression(function, right) &&
      self.function_expression_is_const_expression(function, condition)
    Derivative(_, _, _) => false
    Math(_, first, second, third, fourth) =>
      self.function_expression_is_const_expression(function, first) &&
      self.optional_function_expression_is_const_expression(function, second) &&
      self.optional_function_expression_is_const_expression(function, third) &&
      self.optional_function_expression_is_const_expression(function, fourth)
  }
}

///|
fn WgslIrLowerer::function_expression_list_is_const_expression(
  self : WgslIrLowerer,
  function : Function,
  handles : Array[Handle],
) -> Bool {
  for handle in handles {
    if !self.function_expression_is_const_expression(function, handle) {
      return false
    }
  }
  true
}

///|
fn WgslIrLowerer::optional_function_expression_is_const_expression(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle?,
) -> Bool {
  match handle {
    Some(value) => self.function_expression_is_const_expression(function, value)
    None => true
  }
}
