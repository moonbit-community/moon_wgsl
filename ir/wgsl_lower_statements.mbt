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
  let statements = block.statements()
  for index in 0..<statements.length() {
    self.lower_statement_with_block_context(
      statements[index],
      statements,
      index,
      function,
      scope,
      ir_block,
    )
  }
  ir_block
}

///|
fn WgslIrLowerer::predeclare_function_source_local_prefix(
  self : WgslIrLowerer,
  block : @ast.WgslBlock,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Unit raise WgslIrLowerError {
  let mut in_source_local_prefix = true
  for statement in block.statements() {
    guard in_source_local_prefix else { break }
    match statement.payload() {
      LocalDeclaration(locals) => {
        for local_decl in locals {
          self.predeclare_source_local(local_decl, function, scope)
        }
        continue
      }
      _ => {
        for local_decl in statement.local_bindings() {
          self.predeclare_source_local(local_decl, function, scope)
        }
        in_source_local_prefix = false
      }
    }
  }
  self.predeclare_function_const_initializer_locals(block, function, scope)
}

///|
fn WgslIrLowerer::predeclare_function_const_initializer_locals(
  self : WgslIrLowerer,
  block : @ast.WgslBlock,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Unit raise WgslIrLowerError {
  for statement in block.statements() {
    for local_decl in statement.local_bindings() {
      if self.source_var_has_const_initializer(local_decl) {
        self.predeclare_source_local(local_decl, function, scope)
      }
    }
    for child in statement.blocks() {
      self.predeclare_function_const_initializer_locals(child, function, scope)
    }
  }
}

///|
fn WgslIrLowerer::source_var_has_const_initializer(
  self : WgslIrLowerer,
  local_decl : @ast.WgslLocalDeclaration,
) -> Bool raise WgslIrLowerError {
  guard local_decl.kind() == @ast.WgslLocalDeclarationKind::Var else {
    return false
  }
  match local_decl.initializer_ref() {
    Some(expr_ref) =>
      match expr_ref.root() {
        Some(root) => self.expression_node_is_const_initializer(root)
        None => false
      }
    None => false
  }
}

///|
fn WgslIrLowerer::predeclare_source_local(
  self : WgslIrLowerer,
  local_decl : @ast.WgslLocalDeclaration,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Unit raise WgslIrLowerError {
  guard local_decl.kind() == @ast.WgslLocalDeclarationKind::Var else { return }
  let key = wgsl_ir_local_declaration_key(local_decl)
  if scope.predeclared_source_locals.contains(key) {
    return
  }
  let explicit_ty = match local_decl.ty_ref() {
    Some(ty_ref) => Some(self.lower_function_type_ref(ty_ref, function, scope))
    None => None
  }
  let mut init : Handle? = None
  let initializer_is_const = match local_decl.initializer_ref() {
    Some(expr_ref) =>
      match expr_ref.root() {
        Some(root) => self.expression_node_is_const_initializer(root)
        None => false
      }
    None => false
  }
  if initializer_is_const {
    match local_decl.initializer_ref() {
      Some(expr_ref) =>
        init = Some(
          self.lower_source_local_const_initializer(
            expr_ref, explicit_ty, function, scope,
          ),
        )
      None => ()
    }
  }
  let ty = match explicit_ty {
    Some(ty) => ty
    None =>
      match init {
        Some(init_handle) =>
          match self.function_expression_type(function, init_handle) {
            Some(inferred) => inferred
            None =>
              self.infer_local_type_from_initializer(
                local_decl.name().name(),
                local_decl.initializer_ref(),
              )
          }
        None =>
          match local_decl.initializer_ref() {
            None =>
              self.infer_local_type_from_initializer(
                local_decl.name().name(),
                local_decl.initializer_ref(),
              )
            Some(_) => self.lower_builtin_type_name("i32")
          }
      }
  }
  let ty = self.local_declaration_storage_type(local_decl.kind(), ty)
  match init {
    Some(init_handle) =>
      self.contextualize_function_expression_for_type(function, init_handle, ty)
    None => ()
  }
  let handle = function.local_variables.append(LocalVariable::{
    name: Some(
      self.naga_oil_generated_import_local_spelling_for_scope(
        local_decl.name().name(),
        scope,
      ),
    ),
    kind: LocalVariableKind::Var,
    generated_temporary: false,
    generated_temporary_store_value_reference: false,
    ty,
    init,
  })
  scope.predeclared_source_locals.set(key, handle)
}

///|
fn WgslIrLowerer::predeclare_source_local_placeholder(
  self : WgslIrLowerer,
  local_decl : @ast.WgslLocalDeclaration,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Unit raise WgslIrLowerError {
  guard local_decl.kind() == @ast.WgslLocalDeclarationKind::Var else { return }
  let key = wgsl_ir_local_declaration_key(local_decl)
  if scope.predeclared_source_locals.contains(key) {
    return
  }
  let explicit_ty = match local_decl.ty_ref() {
    Some(ty_ref) => Some(self.lower_function_type_ref(ty_ref, function, scope))
    None => None
  }
  let ty = match explicit_ty {
    Some(ty) => ty
    None =>
      match local_decl.initializer_ref() {
        None =>
          self.infer_local_type_from_initializer(
            local_decl.name().name(),
            local_decl.initializer_ref(),
          )
        Some(_) => self.lower_builtin_type_name("i32")
      }
  }
  let ty = self.local_declaration_storage_type(local_decl.kind(), ty)
  let handle = function.local_variables.append(LocalVariable::{
    name: Some(
      self.naga_oil_generated_import_local_spelling_for_scope(
        local_decl.name().name(),
        scope,
      ),
    ),
    kind: LocalVariableKind::Var,
    generated_temporary: false,
    generated_temporary_store_value_reference: false,
    ty,
    init: None,
  })
  scope.predeclared_source_locals.set(key, handle)
}

///|
fn WgslIrLowerer::lower_source_local_const_initializer(
  self : WgslIrLowerer,
  expr_ref : @ast.WgslExprRef,
  explicit_ty : Handle?,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  match expr_ref.root() {
    Some(root) =>
      match wgsl_ir_expr_node_literal_token(root) {
        Some(token) =>
          match
            scope.source_local_const_initializer_expressions.get(
              wgsl_ir_source_local_const_literal_key(token, explicit_ty),
            ) {
            Some(handle) => return handle
            None => ()
          }
        None => ()
      }
    None => ()
  }
  let key = wgsl_ir_source_local_const_initializer_key(expr_ref, explicit_ty)
  match scope.source_local_const_initializer_expressions.get(key) {
    Some(handle) => handle
    None => {
      let expression_mark = function.expressions.items.length()
      let handle = self.lower_function_expression_ref_with_expected(
        expr_ref, function, scope, explicit_ty,
      )
      scope.source_local_const_initializer_expressions.set(key, handle)
      wgsl_ir_record_source_local_const_initializer_literals(
        expr_ref, expression_mark, function, scope, explicit_ty,
      )
      handle
    }
  }
}

///|
fn wgsl_ir_expr_node_literal_token(
  node : @ast.WgslExprNode,
) -> @ast.WgslExprToken? {
  match node.kind() {
    Literal(token) => Some(token)
    Group(inner) => wgsl_ir_expr_node_literal_token(inner)
    Sequence([single]) => wgsl_ir_expr_node_literal_token(single)
    _ => None
  }
}

///|
fn wgsl_ir_record_source_local_const_initializer_literals(
  expr_ref : @ast.WgslExprRef,
  expression_mark : Int,
  function : Function,
  scope : WgslIrFunctionScope,
  explicit_ty : Handle?,
) -> Unit {
  let literal_tokens : Array[@ast.WgslExprToken] = []
  match expr_ref.root() {
    Some(root) => wgsl_ir_collect_expr_node_literal_tokens(root, literal_tokens)
    None => ()
  }
  guard !literal_tokens.is_empty() else { return }
  let mut token_index = 0
  for expression_index in expression_mark..<function.expressions.items.length() {
    guard token_index < literal_tokens.length() else { break }
    match function.expressions.items.get(expression_index) {
      Some(Literal(_)) => {
        let key = wgsl_ir_source_local_const_literal_key(
          literal_tokens[token_index],
          explicit_ty,
        )
        if !scope.source_local_const_initializer_expressions.contains(key) {
          scope.source_local_const_initializer_expressions.set(
            key,
            Handle::Handle(expression_index),
          )
        }
        token_index = token_index + 1
      }
      _ => ()
    }
  }
}

///|
fn wgsl_ir_collect_expr_node_literal_tokens(
  node : @ast.WgslExprNode,
  out : Array[@ast.WgslExprToken],
) -> Unit {
  match node.kind() {
    Literal(token) => out.push(token)
    Group(inner) => wgsl_ir_collect_expr_node_literal_tokens(inner, out)
    Unary(_, inner) => wgsl_ir_collect_expr_node_literal_tokens(inner, out)
    Binary(_, left, right) => {
      wgsl_ir_collect_expr_node_literal_tokens(left, out)
      wgsl_ir_collect_expr_node_literal_tokens(right, out)
    }
    Call(callee, arguments) => {
      wgsl_ir_collect_expr_node_literal_tokens(callee, out)
      for argument in arguments {
        wgsl_ir_collect_expr_node_literal_tokens(argument, out)
      }
    }
    Template(base, _) => wgsl_ir_collect_expr_node_literal_tokens(base, out)
    Member(base, _) => wgsl_ir_collect_expr_node_literal_tokens(base, out)
    PathAccess(base, _) => wgsl_ir_collect_expr_node_literal_tokens(base, out)
    Sequence(items) =>
      for item in items {
        wgsl_ir_collect_expr_node_literal_tokens(item, out)
      }
    _ => ()
  }
}

///|
fn WgslIrLowerer::lower_runtime_source_local_const_initializer(
  self : WgslIrLowerer,
  expr_ref : @ast.WgslExprRef,
  explicit_ty : Handle?,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  let key = wgsl_ir_source_local_const_initializer_key(expr_ref, explicit_ty)
  match scope.runtime_source_local_const_initializer_expressions.get(key) {
    Some(handle) => handle
    None => {
      let handle = self.lower_function_expression_ref_with_expected(
        expr_ref, function, scope, explicit_ty,
      )
      scope.runtime_source_local_const_initializer_expressions.set(key, handle)
      handle
    }
  }
}

///|
fn wgsl_ir_source_local_const_initializer_key(
  expr_ref : @ast.WgslExprRef,
  explicit_ty : Handle?,
) -> String {
  wgsl_ir_source_local_const_token_text_key(
    wgsl_ir_expr_ref_token_text(expr_ref),
    explicit_ty,
  )
}

///|
fn wgsl_ir_source_local_const_literal_key(
  token : @ast.WgslExprToken,
  explicit_ty : Handle?,
) -> String {
  wgsl_ir_source_local_const_token_text_key(token.text(), explicit_ty)
}

///|
fn wgsl_ir_source_local_const_token_text_key(
  token_text : String,
  explicit_ty : Handle?,
) -> String {
  let ty_key = match explicit_ty {
    Some(ty) => "\{ty.index()}"
    None => "-"
  }
  "\{ty_key}:\{token_text}"
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
  self.lower_statement_with_local_constant_placement(
    statement,
    function,
    scope,
    block,
    UseSiteLazyLocalConstant,
  )
}

///|
fn WgslIrLowerer::lower_statement_with_block_context(
  self : WgslIrLowerer,
  statement : @ast.WgslStatement,
  statements : Array[@ast.WgslStatement],
  statement_index : Int,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
) -> Unit raise WgslIrLowerError {
  let placement = match statement.payload() {
    LocalDeclaration(_) =>
      wgsl_ir_local_constant_arena_placement_for_statement(
        statement, statements, statement_index,
      )
    _ => UseSiteLazyLocalConstant
  }
  self.lower_statement_with_local_constant_placement(
    statement, function, scope, block, placement,
  )
}

///|
fn WgslIrLowerer::lower_statement_with_local_constant_placement(
  self : WgslIrLowerer,
  statement : @ast.WgslStatement,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
  local_constant_placement : WgslIrLocalConstantArenaPlacement,
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
        self.lower_local_declaration(
          local_decl, function, scope, block, local_constant_placement,
        )
      }
    Return(expr) => {
      let value = match expr {
        Some(expr_ref) => {
          let expression_mark = function.expressions.items.length()
          let expected_ty = match function.result {
            Some(result) => Some(result.ty)
            None => None
          }
          guard expr_ref.root() is Some(root) else {
            raise WgslIrLowerError::UnsupportedExpression(
              "empty return expression",
            )
          }
          let handle = if wgsl_ir_expr_node_is_short_circuit_binary(root) {
            let handle = self.materialize_short_circuit_expression_node(
              function, scope, block, root,
            )
            self.materialize_return_expression_if_needed(
              function, scope, block, handle,
            )
          } else {
            let handle = self.lower_function_expression_ref_with_expected(
              expr_ref, function, scope, expected_ty,
            )
            self.materialize_return_expression_if_needed(
              function, scope, block, handle,
            )
          }
          if wgsl_ir_return_expression_should_emit_before_return(
              function, expression_mark, handle,
            ) {
            wgsl_ir_push_naga_named_expression_emit_ranges(
              block, function, expression_mark, handle,
            )
          } else if !wgsl_ir_block_contains_expression_emit(block, handle) &&
            !wgsl_ir_function_expression_is_naga_emit_leaf(function, handle) {
            block.push(Statement::Emit(HandleRange(handle, handle)))
          }
          Some(handle)
        }
        None => None
      }
      block.push(Statement::Return(value))
    }
    If(condition) => {
      guard condition is Some(condition_ref) else {
        raise WgslIrLowerError::UnsupportedStatement("if without condition")
      }
      let expression_mark = function.expressions.items.length()
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
      wgsl_ir_push_naga_statement_emit_ranges(
        block, function, expression_mark, condition_handle,
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
      let expression_mark = function.expressions.items.length()
      if wgsl_ir_expr_ref_is_phony(lhs_ref) {
        if self.lower_ray_query_statement_expr_ref(
            rhs_ref, function, scope, block,
          ) {
          return
        }
        if self.wgsl_ir_expr_ref_is_user_function_call(rhs_ref) {
          self.lower_call_statement(rhs_ref, function, scope, block)
          return
        }
        let rhs_value = self.lower_function_expression_ref(
          rhs_ref, function, scope,
        )
        block.push(Statement::Phony(rhs_value))
        return
      }
      let (target, value) = match wgsl_ir_compound_assignment_operator(op) {
        Some(binary_op) => {
          let raw_target = self.lower_function_lvalue_ref(
            lhs_ref, function, scope,
          )
          let target = self.materialize_store_pointer_if_needed(
            function, scope, block, raw_target,
          )
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
          let (materialized_target, rhs_value) = self.normalize_function_binary_operands(
            function, binary_op, materialized_target, rhs_value,
          )
          let value = function.expressions.append(
            Expression::Binary(binary_op, materialized_target, rhs_value),
          )
          (target, value)
        }
        None =>
          if wgsl_ir_expr_ref_plain_local_identifier(lhs_ref, scope) {
            let rhs_value = self.lower_function_expression_ref(
              rhs_ref, function, scope,
            )
            let raw_target = self.lower_function_lvalue_ref(
              lhs_ref, function, scope,
            )
            let target = self.materialize_store_pointer_if_needed(
              function, scope, block, raw_target,
            )
            let value = self.materialize_store_value_for_pointer_if_needed(
              function, scope, block, target, rhs_value,
            )
            (target, value)
          } else {
            let raw_target = self.lower_function_lvalue_ref(
              lhs_ref, function, scope,
            )
            let target = self.materialize_store_pointer_if_needed(
              function, scope, block, raw_target,
            )
            let rhs_value = self.lower_function_expression_ref(
              rhs_ref, function, scope,
            )
            let value = self.materialize_store_value_for_pointer_if_needed(
              function, scope, block, target, rhs_value,
            )
            (target, value)
          }
      }
      wgsl_ir_record_store_value_temporary_references(function, value)
      wgsl_ir_push_naga_statement_emit_ranges(
        block,
        function,
        expression_mark,
        wgsl_ir_max_handle(target, value),
      )
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
      let expression_mark = function.expressions.items.length()
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
      wgsl_ir_push_naga_statement_emit_ranges(
        block, function, expression_mark, selector_handle,
      )
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
      let body_statements = body_block.statements()
      for index in 0..<body_statements.length() {
        let child = body_statements[index]
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
              self.lower_statement_with_block_context(
                child, body_statements, index, function, child_scope, body,
              )
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
  let loop_scope = scope.child()
  for local_decl in statement.local_bindings() {
    self.lower_local_declaration(
      local_decl,
      function,
      loop_scope,
      block,
      UseSiteLazyLocalConstant,
    )
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
      let (target, value) = match wgsl_ir_compound_assignment_operator(op) {
        Some(binary_op) => {
          let raw_target = self.lower_function_lvalue_node(
            wgsl_ir_expr_node_from_tokens(lhs_tokens),
            function,
            scope,
          )
          let target = self.materialize_store_pointer_if_needed(
            function, scope, block, raw_target,
          )
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
          let (materialized_target, rhs_value) = self.normalize_function_binary_operands(
            function, binary_op, materialized_target, rhs_value,
          )
          let value = function.expressions.append(
            Expression::Binary(binary_op, materialized_target, rhs_value),
          )
          (target, value)
        }
        None => {
          let lhs_node = wgsl_ir_expr_node_from_tokens(lhs_tokens)
          if wgsl_ir_expr_node_plain_local_identifier(lhs_node, scope) {
            let rhs_value = self.lower_function_expression_node(
              wgsl_ir_expr_node_from_tokens(rhs_tokens),
              function,
              scope,
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
            let raw_target = self.lower_function_lvalue_node(
              lhs_node, function, scope,
            )
            let target = self.materialize_store_pointer_if_needed(
              function, scope, block, raw_target,
            )
            let rhs_value = self.lower_function_expression_node(
              wgsl_ir_expr_node_from_tokens(rhs_tokens),
              function,
              scope,
            )
            let value = self.materialize_store_value_for_pointer_if_needed(
              function, scope, block, target, rhs_value,
            )
            (target, value)
          }
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
fn wgsl_ir_local_constant_arena_placement_for_statement(
  statement : @ast.WgslStatement,
  statements : Array[@ast.WgslStatement],
  statement_index : Int,
) -> WgslIrLocalConstantArenaPlacement {
  match statement.payload() {
    LocalDeclaration(locals) => {
      for local_decl in locals {
        if (
            local_decl.kind() == @ast.WgslLocalDeclarationKind::Let ||
            local_decl.kind() == @ast.WgslLocalDeclarationKind::Const
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
fn WgslIrLowerer::lower_local_declaration(
  self : WgslIrLowerer,
  local_decl : @ast.WgslLocalDeclaration,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
  local_constant_placement : WgslIrLocalConstantArenaPlacement,
) -> Unit raise WgslIrLowerError {
  if local_decl.kind() == @ast.WgslLocalDeclarationKind::Const {
    self.lower_local_const_declaration(
      local_decl, function, scope, local_constant_placement,
    )
    return
  }
  if local_decl.kind() == @ast.WgslLocalDeclarationKind::Var &&
    !scope.predeclared_source_locals.contains(
      wgsl_ir_local_declaration_key(local_decl),
    ) &&
    !self.local_var_initializer_uses_store(local_decl) {
    self.predeclare_source_local_placeholder(local_decl, function, scope)
  }
  if local_decl.kind() == @ast.WgslLocalDeclarationKind::Var &&
    scope.predeclared_source_locals.contains(
      wgsl_ir_local_declaration_key(local_decl),
    ) {
    if wgsl_ir_predeclared_source_var_has_init(local_decl, function, scope) {
      ignore(
        wgsl_ir_lower_predeclared_source_var_declaration(
          local_decl, scope, block,
        ),
      )
    } else {
      match local_decl.initializer_ref() {
        Some(expr_ref) => {
          let initializer_is_const = match expr_ref.root() {
            Some(root) => self.expression_node_is_const_initializer(root)
            None => false
          }
          if initializer_is_const {
            self.lower_predeclared_source_var_const_initializer(
              local_decl, expr_ref, function, scope, block,
            )
          } else {
            self.lower_local_var_store_declaration(
              local_decl, function, scope, block,
            )
          }
        }
        None =>
          ignore(
            wgsl_ir_lower_predeclared_source_var_declaration(
              local_decl, scope, block,
            ),
          )
      }
    }
    return
  }
  if local_decl.kind() == @ast.WgslLocalDeclarationKind::Var &&
    self.local_var_initializer_uses_store(local_decl) {
    self.lower_local_var_store_declaration(local_decl, function, scope, block)
    return
  }
  if local_decl.kind() == @ast.WgslLocalDeclarationKind::Var &&
    wgsl_ir_lower_predeclared_source_var_declaration(local_decl, scope, block) {
    return
  }
  let expression_mark = function.expressions.items.length()
  let local_constant_snapshot = wgsl_ir_snapshot_local_constant_values(
    scope.local_constants,
  )
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
          if local_decl.kind() == @ast.WgslLocalDeclarationKind::Let {
            Some(target)
          } else {
            Some(
              function.expressions.append(
                Expression::AddressOf(pointer_ty, target),
              ),
            )
          }
        }
        None => {
          let init_is_const = if local_decl.kind() ==
            @ast.WgslLocalDeclarationKind::Var {
            match expr_ref.root() {
              Some(root) => self.expression_node_is_const_initializer(root)
              None => false
            }
          } else {
            false
          }
          Some(
            if init_is_const {
              self.lower_runtime_source_local_const_initializer(
                expr_ref, explicit_ty, function, scope,
              )
            } else {
              self.lower_function_expression_ref_with_expected(
                expr_ref, function, scope, explicit_ty,
              )
            },
          )
        }
      }
    None => None
  }
  if local_decl.kind() == @ast.WgslLocalDeclarationKind::Let {
    match init {
      Some(init_handle) => {
        if self.function_expression_is_const_expression(function, init_handle) &&
          self.function_expression_has_scalar_type(function, init_handle) {
          let normalized = self.normalized_local_constant_initializer(
            function, init_handle,
          )
          function.expressions.set_origin(normalized, FoldedLocalConstant)
          ignore(scope.locals.remove(local_decl.name().name()))
          ignore(
            scope.local_pointer_expressions.remove(local_decl.name().name()),
          )
          match local_constant_placement {
            DeclarationArenaLocalConstant =>
              scope.local_constants.set(local_decl.name().name(), WgslIrLocalValueCell::{
                value: ExpressionAlias(normalized),
              })
            UseSiteLazyLocalConstant => {
              let normalized_expression = wgsl_ir_lazy_local_constant_expression(
                function, normalized,
              )
              wgsl_ir_rewind_function_expressions(function, expression_mark)
              wgsl_ir_restore_local_constant_values(
                scope.local_constants,
                local_constant_snapshot,
              )
              match local_decl.initializer_ref() {
                Some(expr_ref) =>
                  scope.local_constants.set(local_decl.name().name(), WgslIrLocalValueCell::{
                    value: LazyConstant(WgslIrLazyLocalConstant::{
                      expr_ref,
                      explicit_ty,
                      normalized: normalized_expression,
                    }),
                  })
                None => ()
              }
            }
          }
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
              scope.local_constants.set(local_decl.name().name(), WgslIrLocalValueCell::{
                value: ExpressionAlias(materialized_value),
              })
              return
            } else if wgsl_ir_function_expression_is_materialized_temporary(
                function, normalized,
              ) {
              ignore(scope.locals.remove(local_decl.name().name()))
              ignore(
                scope.local_pointer_expressions.remove(local_decl.name().name()),
              )
              scope.local_constants.set(local_decl.name().name(), WgslIrLocalValueCell::{
                value: ExpressionAlias(normalized),
              })
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
  if local_decl.kind() == @ast.WgslLocalDeclarationKind::Let {
    match init {
      Some(init_handle) =>
        if wgsl_ir_function_expression_should_use_named_let(
            function, init_handle,
          ) {
          if wgsl_ir_function_replace_named_expression(
              function, init_handle, lowered_name, ty,
            ) {
            ignore(scope.locals.remove(local_decl.name().name()))
            ignore(
              scope.local_pointer_expressions.remove(local_decl.name().name()),
            )
            scope.local_constants.set(local_decl.name().name(), WgslIrLocalValueCell::{
              value: ExpressionAlias(init_handle),
            })
            return
          }
          function.named_expressions.push(NamedExpression::{
            handle: init_handle,
            name: lowered_name,
            ty,
          })
          ignore(scope.locals.remove(local_decl.name().name()))
          ignore(
            scope.local_pointer_expressions.remove(local_decl.name().name()),
          )
          scope.local_constants.set(local_decl.name().name(), WgslIrLocalValueCell::{
            value: ExpressionAlias(init_handle),
          })
          wgsl_ir_push_naga_named_expression_emit_ranges(
            block, function, expression_mark, init_handle,
          )
          return
        }
      None => ()
    }
  }
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
          wgsl_ir_push_naga_statement_emit_ranges(
            block, function, expression_mark, materialized,
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
fn wgsl_ir_predeclared_source_var_has_init(
  local_decl : @ast.WgslLocalDeclaration,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Bool {
  match
    scope.predeclared_source_locals.get(
      wgsl_ir_local_declaration_key(local_decl),
    ) {
    Some(handle) =>
      match function.local_variables.items.get(handle.index()) {
        Some(local_var) => local_var.init != None
        None => false
      }
    None => false
  }
}

///|
fn WgslIrLowerer::lower_predeclared_source_var_const_initializer(
  self : WgslIrLowerer,
  local_decl : @ast.WgslLocalDeclaration,
  expr_ref : @ast.WgslExprRef,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
) -> Unit raise WgslIrLowerError {
  guard scope.predeclared_source_locals.get(
      wgsl_ir_local_declaration_key(local_decl),
    )
    is Some(handle) else {
    return
  }
  let lowered_name = self.naga_oil_generated_import_local_spelling_for_scope(
    local_decl.name().name(),
    scope,
  )
  let explicit_ty = match local_decl.ty_ref() {
    Some(ty_ref) => Some(self.lower_function_type_ref(ty_ref, function, scope))
    None => None
  }
  let init = self.lower_source_local_const_initializer(
    expr_ref, explicit_ty, function, scope,
  )
  let ty = match explicit_ty {
    Some(ty) => ty
    None =>
      match self.function_expression_type(function, init) {
        Some(inferred) => inferred
        None =>
          self.infer_local_type_from_initializer(
            local_decl.name().name(),
            local_decl.initializer_ref(),
          )
      }
  }
  let ty = self.local_declaration_storage_type(local_decl.kind(), ty)
  self.contextualize_function_expression_for_type(function, init, ty)
  function.local_variables.set(handle, LocalVariable::{
    name: Some(lowered_name),
    kind: LocalVariableKind::Var,
    generated_temporary: false,
    generated_temporary_store_value_reference: false,
    ty,
    init: Some(init),
  })
  ignore(
    wgsl_ir_lower_predeclared_source_var_declaration(local_decl, scope, block),
  )
}

///|
fn WgslIrLowerer::local_var_initializer_uses_store(
  self : WgslIrLowerer,
  local_decl : @ast.WgslLocalDeclaration,
) -> Bool raise WgslIrLowerError {
  match local_decl.initializer_ref() {
    Some(expr_ref) =>
      match expr_ref.root() {
        Some(root) =>
          !self.expression_node_is_const_initializer(root) &&
          !wgsl_ir_expression_node_contains_call(root)
        None => false
      }
    None => false
  }
}

///|
fn wgsl_ir_lower_predeclared_source_var_declaration(
  local_decl : @ast.WgslLocalDeclaration,
  scope : WgslIrFunctionScope,
  block : Block,
) -> Bool {
  let key = wgsl_ir_local_declaration_key(local_decl)
  match scope.predeclared_source_locals.get(key) {
    Some(handle) => {
      ignore(scope.local_constants.remove(local_decl.name().name()))
      ignore(scope.local_pointer_expressions.remove(local_decl.name().name()))
      scope.locals.set(local_decl.name().name(), handle)
      block.push(Statement::Declare(handle))
      true
    }
    None => false
  }
}

///|
fn WgslIrLowerer::expression_node_is_const_initializer(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
) -> Bool raise WgslIrLowerError {
  match node.kind() {
    Literal(_) => true
    Identifier(name) =>
      self.constant_declarations.contains(name.name()) ||
      self.constant_names.contains(name.name())
    Group(inner) => self.expression_node_is_const_initializer(inner)
    Unary(_, inner) => self.expression_node_is_const_initializer(inner)
    Binary(_, left, right) =>
      self.expression_node_is_const_initializer(left) &&
      self.expression_node_is_const_initializer(right)
    Call(callee, arguments) =>
      self.call_expression_is_const_initializer(callee, arguments)
    Sequence([single]) => self.expression_node_is_const_initializer(single)
    _ => false
  }
}

///|
fn WgslIrLowerer::call_expression_is_const_initializer(
  self : WgslIrLowerer,
  callee : @ast.WgslExprNode,
  arguments : Array[@ast.WgslExprNode],
) -> Bool raise WgslIrLowerError {
  guard self.expression_callee_is_const_constructor(callee) else {
    return false
  }
  let arguments = wgsl_ir_call_arguments(arguments)
  for argument in arguments {
    if !self.expression_node_is_const_initializer(argument) {
      return false
    }
  }
  true
}

///|
fn WgslIrLowerer::expression_callee_is_const_constructor(
  self : WgslIrLowerer,
  callee : @ast.WgslExprNode,
) -> Bool raise WgslIrLowerError {
  match callee.kind() {
    Identifier(ident) =>
      self.lower_bitcast_callee_type(callee) != None ||
      self.lower_templated_callee_type(callee) != None ||
      wgsl_ir_untemplated_constructor_name_is_const(ident.name())
    Template(base, _) => self.expression_callee_is_const_constructor(base)
    _ => false
  }
}

///|
fn wgsl_ir_untemplated_constructor_name_is_const(name : String) -> Bool {
  name == "bool" ||
  name == "i32" ||
  name == "u32" ||
  name == "f32" ||
  name == "f16" ||
  name == "vec2" ||
  name == "vec3" ||
  name == "vec4" ||
  name == "mat2x2" ||
  name == "mat2x3" ||
  name == "mat2x4" ||
  name == "mat3x2" ||
  name == "mat3x3" ||
  name == "mat3x4" ||
  name == "mat4x2" ||
  name == "mat4x3" ||
  name == "mat4x4" ||
  name == "array"
}

///|
fn wgsl_ir_expression_node_contains_call(node : @ast.WgslExprNode) -> Bool {
  match node.kind() {
    Call(_, _) => true
    Group(inner) => wgsl_ir_expression_node_contains_call(inner)
    Unary(_, inner) => wgsl_ir_expression_node_contains_call(inner)
    Binary(_, left, right) =>
      wgsl_ir_expression_node_contains_call(left) ||
      wgsl_ir_expression_node_contains_call(right)
    Member(base, _) => wgsl_ir_expression_node_contains_call(base)
    Index(base, index) =>
      wgsl_ir_expression_node_contains_call(base) ||
      wgsl_ir_expression_node_contains_call(index)
    Sequence(items) => {
      for item in items {
        if wgsl_ir_expression_node_contains_call(item) {
          return true
        }
      }
      false
    }
    Template(base, _) => wgsl_ir_expression_node_contains_call(base)
    _ => false
  }
}

///|
fn WgslIrLowerer::lower_local_var_store_declaration(
  self : WgslIrLowerer,
  local_decl : @ast.WgslLocalDeclaration,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
) -> Unit raise WgslIrLowerError {
  let explicit_ty = match local_decl.ty_ref() {
    Some(ty_ref) => Some(self.lower_function_type_ref(ty_ref, function, scope))
    None => None
  }
  let placeholder_ty = match explicit_ty {
    Some(ty) => ty
    None => self.lower_builtin_type_name("i32")
  }
  let placeholder_ty = self.local_declaration_storage_type(
    local_decl.kind(),
    placeholder_ty,
  )
  let lowered_name = self.naga_oil_generated_import_local_spelling_for_scope(
    local_decl.name().name(),
    scope,
  )
  let handle = match
    scope.predeclared_source_locals.get(
      wgsl_ir_local_declaration_key(local_decl),
    ) {
    Some(predeclared) => predeclared
    None =>
      function.local_variables.append(LocalVariable::{
        name: Some(lowered_name),
        kind: LocalVariableKind::Var,
        generated_temporary: false,
        generated_temporary_store_value_reference: false,
        ty: placeholder_ty,
        init: None,
      })
  }
  function.local_variables.set(handle, LocalVariable::{
    name: Some(lowered_name),
    kind: LocalVariableKind::Var,
    generated_temporary: false,
    generated_temporary_store_value_reference: false,
    ty: placeholder_ty,
    init: None,
  })
  block.push(Statement::Declare(handle))
  let predeclare_pointer = wgsl_ir_local_var_store_initializer_predeclares_pointer(
    local_decl, scope,
  )
  let mut pointer : Handle? = if predeclare_pointer {
    Some(function.expressions.append(Expression::LocalVariable(handle)))
  } else {
    None
  }
  guard local_decl.initializer_ref() is Some(expr_ref) else { return }
  let expression_mark = function.expressions.items.length()
  let init = match wgsl_ir_address_of_operand_ref(expr_ref) {
    Some(target_ref) => {
      let target = self.lower_function_lvalue_node(target_ref, function, scope)
      function.expressions.append(
        Expression::AddressOf(
          self.pointer_type_for_lvalue(function, target),
          target,
        ),
      )
    }
    None =>
      self.lower_function_expression_ref_with_expected(
        expr_ref, function, scope, explicit_ty,
      )
  }
  if pointer == None {
    pointer = Some(
      function.expressions.append(Expression::LocalVariable(handle)),
    )
  }
  let ty = match explicit_ty {
    Some(ty) => ty
    None =>
      match self.address_of_expression_type(function, init) {
        Some(inferred) => inferred
        None =>
          match self.function_expression_type(function, init) {
            Some(inferred) => inferred
            None =>
              self.infer_local_type_from_initializer(
                local_decl.name().name(),
                local_decl.initializer_ref(),
              )
          }
      }
  }
  let ty = self.local_declaration_storage_type(local_decl.kind(), ty)
  function.local_variables.set(handle, LocalVariable::{
    name: Some(lowered_name),
    kind: LocalVariableKind::Var,
    generated_temporary: false,
    generated_temporary_store_value_reference: false,
    ty,
    init: None,
  })
  ignore(scope.local_constants.remove(local_decl.name().name()))
  ignore(scope.local_pointer_expressions.remove(local_decl.name().name()))
  scope.locals.set(local_decl.name().name(), handle)
  guard pointer is Some(pointer) else {
    raise WgslIrLowerError::UnsupportedStatement(
      "missing local pointer for var \{local_decl.name().name()}",
    )
  }
  scope.local_pointer_expressions.set(local_decl.name().name(), pointer)
  self.contextualize_function_expression_for_type(function, init, ty)
  let materialized = self.materialize_store_value_if_needed(
    function, scope, block, init,
  )
  wgsl_ir_record_store_value_temporary_references(function, materialized)
  wgsl_ir_push_naga_statement_emit_ranges(
    block, function, expression_mark, materialized,
  )
  block.push(Statement::Store(pointer, materialized))
}

///|
fn wgsl_ir_local_var_store_initializer_predeclares_pointer(
  local_decl : @ast.WgslLocalDeclaration,
  scope : WgslIrFunctionScope,
) -> Bool {
  match local_decl.initializer_ref() {
    Some(expr_ref) =>
      match expr_ref.root() {
        Some(root) =>
          wgsl_ir_expr_node_is_direct_function_argument_value(root, scope)
        None => false
      }
    None => false
  }
}

///|
fn wgsl_ir_expr_node_is_direct_function_argument_value(
  node : @ast.WgslExprNode,
  scope : WgslIrFunctionScope,
) -> Bool {
  match node.kind() {
    Group(inner) =>
      wgsl_ir_expr_node_is_direct_function_argument_value(inner, scope)
    Identifier(name) => scope.arguments.contains(name.name())
    _ => false
  }
}

///|
fn wgsl_ir_function_expression_should_use_named_let(
  function : Function,
  handle : Handle,
) -> Bool {
  match function.expressions.items.get(handle.index()) {
    Some(Literal(_))
    | Some(Constant(_))
    | Some(Override(_))
    | Some(ZeroValue(_))
    | Some(FunctionArgument(_))
    | Some(GlobalVariable(_))
    | Some(LocalVariable(_))
    | Some(AddressOf(_, _))
    | Some(FunctionCall(_, _))
    | Some(AtomicCall(_, _))
    | Some(WorkGroupUniformLoad(_)) => false
    Some(_) => true
    None => false
  }
}

///|
fn wgsl_ir_function_expression_is_materialized_temporary(
  function : Function,
  handle : Handle,
) -> Bool {
  match function.expressions.items.get(handle.index()) {
    Some(CallResult(_)) => true
    _ => false
  }
}

///|
fn wgsl_ir_push_naga_named_expression_emit_ranges(
  block : Block,
  function : Function,
  expression_mark : Int,
  init_handle : Handle,
) -> Unit {
  wgsl_ir_push_naga_statement_emit_ranges(
    block, function, expression_mark, init_handle,
  )
}

///|
fn wgsl_ir_push_naga_statement_emit_ranges(
  block : Block,
  function : Function,
  expression_mark : Int,
  init_handle : Handle,
) -> Unit {
  let mut range_start : Handle? = None
  let mut range_end : Handle? = None
  for index in expression_mark..<=init_handle.index() {
    match function.expressions.items.get(index) {
      Some(expression) =>
        if wgsl_ir_expression_is_naga_emit_leaf(expression) {
          wgsl_ir_flush_naga_named_expression_emit_range(
            block, range_start, range_end,
          )
          range_start = None
          range_end = None
        } else {
          let handle = Handle::Handle(index)
          if range_start == None {
            range_start = Some(handle)
          }
          range_end = Some(handle)
        }
      None => ()
    }
  }
  wgsl_ir_flush_naga_named_expression_emit_range(block, range_start, range_end)
}

///|
fn wgsl_ir_max_handle(left : Handle, right : Handle) -> Handle {
  if left.index() >= right.index() {
    left
  } else {
    right
  }
}

///|
fn wgsl_ir_flush_naga_named_expression_emit_range(
  block : Block,
  range_start : Handle?,
  range_end : Handle?,
) -> Unit {
  match (range_start, range_end) {
    (Some(start), Some(end)) =>
      if !wgsl_ir_block_contains_emit_range(block, start, end) {
        block.push(Statement::Emit(HandleRange(start, end)))
      }
    _ => ()
  }
}

///|
fn wgsl_ir_block_contains_emit_range(
  block : Block,
  start : Handle,
  end : Handle,
) -> Bool {
  for statement in block.statements {
    match statement {
      Statement::Emit(range) =>
        if range.start == start && range.end == end {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn wgsl_ir_block_contains_expression_emit(
  block : Block,
  handle : Handle,
) -> Bool {
  for statement in block.statements {
    match statement {
      Statement::Emit(range) =>
        if range.start.index() <= handle.index() &&
          handle.index() <= range.end.index() {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn wgsl_ir_function_expression_is_naga_emit_leaf(
  function : Function,
  handle : Handle,
) -> Bool {
  match function.expressions.items.get(handle.index()) {
    Some(expression) => wgsl_ir_expression_is_naga_emit_leaf(expression)
    None => false
  }
}

///|
fn wgsl_ir_return_expression_should_emit_before_return(
  function : Function,
  expression_mark : Int,
  value : Handle,
) -> Bool {
  if wgsl_ir_function_expression_has_arena_name(function, value) {
    return false
  }
  for index in expression_mark..<=value.index() {
    match function.expressions.items.get(index) {
      Some(FunctionCall(_, _))
      | Some(CallResult(_))
      | Some(AtomicCall(_, _))
      | Some(ImageSample(_, _, _, _, _, _, _, _, _))
      | Some(ImageLoad(_, _, _, _, _))
      | Some(ImageQuery(_, _))
      | Some(WorkGroupUniformLoad(_)) => return false
      _ => ()
    }
  }
  match function.expressions.items.get(value.index()) {
    Some(expression) => !wgsl_ir_expression_is_naga_emit_leaf(expression)
    None => false
  }
}

///|
fn wgsl_ir_expression_is_naga_emit_leaf(expression : Expression) -> Bool {
  match expression {
    Literal(_)
    | Constant(_)
    | Override(_)
    | FunctionArgument(_)
    | CallResult(_)
    | AtomicResult(_, _)
    | GlobalVariable(_)
    | LocalVariable(_) => true
    _ => false
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
  local_constant_placement : WgslIrLocalConstantArenaPlacement,
) -> Unit raise WgslIrLowerError {
  let expression_mark = function.expressions.items.length()
  let local_constant_snapshot = wgsl_ir_snapshot_local_constant_values(
    scope.local_constants,
  )
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
  let normalized = self.normalized_local_constant_initializer(function, init)
  function.expressions.set_origin(normalized, FoldedLocalConstant)
  ignore(scope.locals.remove(local_decl.name().name()))
  match local_constant_placement {
    DeclarationArenaLocalConstant =>
      scope.local_constants.set(local_decl.name().name(), WgslIrLocalValueCell::{
        value: ExpressionAlias(normalized),
      })
    UseSiteLazyLocalConstant => {
      let normalized_expression = wgsl_ir_lazy_local_constant_expression(
        function, normalized,
      )
      wgsl_ir_rewind_function_expressions(function, expression_mark)
      wgsl_ir_restore_local_constant_values(
        scope.local_constants,
        local_constant_snapshot,
      )
      match local_decl.initializer_ref() {
        Some(expr_ref) =>
          scope.local_constants.set(local_decl.name().name(), WgslIrLocalValueCell::{
            value: LazyConstant(WgslIrLazyLocalConstant::{
              expr_ref,
              explicit_ty,
              normalized: normalized_expression,
            }),
          })
        None => ()
      }
    }
  }
}

///|
fn wgsl_ir_lazy_local_constant_expression(
  function : Function,
  handle : Handle,
) -> WgslIrLazyLocalConstantExpression? {
  match function.expressions.items.get(handle.index()) {
    Some(Literal(literal)) =>
      Some(WgslIrLazyLocalConstantExpression::{
        expression: Expression::Literal(literal),
        origin: FoldedLocalConstant,
      })
    _ => None
  }
}

///|
fn wgsl_ir_rewind_function_expressions(
  function : Function,
  length : Int,
) -> Unit {
  function.expressions.truncate(length)
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
    AccessIndex(base, _)
    | Component(base, _)
    | Splat(_, base)
    | Swizzle(_, base, _) =>
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
