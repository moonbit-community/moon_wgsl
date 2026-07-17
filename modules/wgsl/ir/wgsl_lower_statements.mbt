///|
pub fn wgsl_ir_block_ends_with_return(block : Block) -> Bool {
  match block.statements {
    [.., Return(_)] | [.., ImplicitReturn] => true
    _ => false
  }
}

///|
fn wgsl_ir_block_accepts_implicit_tail_return(block : Block) -> Bool {
  if wgsl_ir_block_ends_with_return(block) {
    true
  } else {
    block.statements.push(ImplicitReturn)
    true
  }
}

///|
fn wgsl_ir_absorb_implicit_tail_return(block : Block) -> Bool {
  match block.statements {
    [.., If(_, accept, reject)] => {
      let accept_absorbed = wgsl_ir_block_accepts_implicit_tail_return(accept)
      let reject_absorbed = wgsl_ir_block_accepts_implicit_tail_return(reject)
      accept_absorbed && reject_absorbed
    }
    [.., Switch(_, cases)] => {
      for case in cases {
        ignore(wgsl_ir_block_accepts_implicit_tail_return(case.body))
      }
      true
    }
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
    [],
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
  if wgsl_ir_statement_is_source_var_declaration(statement) {
    self.predeclare_source_var_suffix_locals(
      statements, statement_index, function, scope,
    )
  }
  let placement = match statement.payload() {
    LocalDeclaration(_) =>
      wgsl_ir_local_constant_arena_placement_for_statement(
        statement, statements, statement_index, scope,
      )
    _ => UseSiteLazyLocalConstant
  }
  let source_var_store_initializers = match statement.payload() {
    LocalDeclaration(locals) =>
      wgsl_ir_source_var_store_initializers_for_statement(
        locals, statements, statement_index, self, scope,
      )
    _ => []
  }
  self.lower_statement_with_local_constant_placement(
    statement, function, scope, block, placement, source_var_store_initializers,
  )
}

///|
fn WgslIrLowerer::predeclare_source_var_suffix_locals(
  self : WgslIrLowerer,
  statements : Array[@ast.WgslStatement],
  statement_index : Int,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Unit raise WgslIrLowerError {
  for index in statement_index..<statements.length() {
    for local_decl in statements[index].local_bindings() {
      if local_decl.kind() == Var {
        self.predeclare_source_local_placeholder(local_decl, function, scope)
      }
    }
  }
}

///|
fn wgsl_ir_statement_is_source_var_declaration(
  statement : @ast.WgslStatement,
) -> Bool {
  statement.local_bindings().any(fn(local_decl) { local_decl.kind() == Var })
}

///|
fn WgslIrLowerer::lower_statement_with_local_constant_placement(
  self : WgslIrLowerer,
  statement : @ast.WgslStatement,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
  local_constant_placement : WgslIrLocalConstantArenaPlacement,
  source_var_store_initializers : Array[String],
) -> Unit raise WgslIrLowerError {
  match statement.payload() {
    Empty => ()
    Compound =>
      match statement.blocks() {
        [child, ..] =>
          block.push(Block(self.lower_child_block(child, function, scope)))
        [] => ()
      }
    LocalDeclaration(locals) =>
      for local_decl in locals {
        self.lower_local_declaration(
          local_decl, function, scope, block, local_constant_placement, source_var_store_initializers,
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
          guard expr_ref.root() is Some(_) else {
            raise UnsupportedExpression("empty return expression")
          }
          let handle = match expr_ref.root() {
            Some(root) if wgsl_ir_expr_node_literal_token(root) is Some(token) =>
              self.lower_function_fresh_literal_node_with_expected(
                token, function, expected_ty,
              )
            Some(root) if wgsl_ir_expr_node_is_short_circuit_binary(root) =>
              self
              .short_circuit_planner(function, scope, block)
              .materialize_return_value_node(root)
            _ =>
              self.lower_expression_ref_with_materialized_short_circuit_inputs(
                expr_ref, function, scope, block, expected_ty,
              )
          }
          let handle = self.materialize_return_expression_if_needed(
            function, scope, block, handle,
          )
          if wgsl_ir_return_expression_should_emit_before_return(
              function, expression_mark, handle,
            ) {
            BodyEmissionPlanner::push_named_expression_emit_ranges(
              block, function, expression_mark, handle,
            )
          } else if !BodyEmissionPlanner::block_contains_expression_emit(
              block, handle,
            ) &&
            !wgsl_ir_function_expression_is_emit_leaf(function, handle) {
            block.push(Emit(HandleRange(handle, handle)))
          }
          Some(handle)
        }
        None => None
      }
      block.push(Return(value))
    }
    If(condition) => {
      guard condition is Some(condition_ref) else {
        raise UnsupportedStatement("if without condition")
      }
      let expression_mark = function.expressions.items.length()
      let condition_handle = self.lower_control_flow_condition_ref(
        condition_ref, function, scope, block,
      )
      let condition_refs = wgsl_ir_statement_condition_refs(
        statement.expressions(),
      )
      guard condition_refs.length() > 0 else {
        raise UnsupportedStatement("if without condition")
      }
      let blocks = statement.blocks()
      let then_block = match statement.blocks() {
        [then_child, ..] => self.lower_child_block(then_child, function, scope)
        [] => Block()
      }
      let else_block = self.lower_if_reject_chain(
        blocks, condition_refs, 1, function, scope,
      )
      let condition_emitted_by_short_circuit = match condition_ref.root() {
        Some(root) => wgsl_ir_expr_node_is_short_circuit_binary(root)
        None => false
      }
      if !condition_emitted_by_short_circuit {
        BodyEmissionPlanner::push_statement_emit_ranges(
          block, function, expression_mark, condition_handle,
        )
      }
      block.push(If(condition_handle, then_block, else_block))
    }
    While(condition) => {
      guard condition is Some(condition_ref) else {
        raise UnsupportedStatement("while without condition")
      }
      let body_statements : Array[Statement] = []
      let guard_block = Block::{ statements: body_statements }
      let cond = self.lower_control_flow_condition_ref(
        condition_ref, function, scope, guard_block,
      )
      body_statements.push(If(cond, Block(), { statements: [Break] }))
      let lowered_body = match statement.blocks() {
        [body_block, ..] => self.lower_child_block(body_block, function, scope)
        [] => Block()
      }
      if lowered_body.statements.length() > 0 {
        body_statements.push(Block(lowered_body))
      }
      block.push(Loop(guard_block, Block(), None))
    }
    Loop => {
      let (body, continuing, break_if) = self.lower_loop_blocks(
        statement, function, scope,
      )
      block.push(Loop(body, continuing, break_if))
    }
    Break(_) => block.push(Break)
    Continue => block.push(Continue)
    Discard => block.push(Kill)
    Assignment(op, lhs, rhs) => {
      guard lhs is Some(lhs_ref) else {
        raise UnsupportedStatement("assignment without lhs")
      }
      guard rhs is Some(rhs_ref) else {
        raise UnsupportedStatement("assignment without rhs")
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
        let rhs_value = self.lower_expression_ref_with_materialized_short_circuit_inputs(
          rhs_ref,
          function,
          scope,
          block,
          None,
        )
        block.push(Phony(rhs_value))
        return
      }
      let (target, value) = match wgsl_ir_compound_assignment_operator(op) {
        Some(binary_op) => {
          scope.pending_compound_assignment_rhs_local_root = match
            rhs_ref.root() {
            Some(root) =>
              wgsl_ir_expr_node_plain_mutable_local_identifier_name(root, scope)
            None => None
          }
          match rhs_ref.root() {
            Some(root) =>
              if wgsl_ir_direct_access_chain_root_is_function_argument(
                  root, scope,
                ) {
                self.predeclare_function_reference_roots_in_source_order(
                  root, function, scope,
                )
              }
            None => ()
          }
          let raw_target = self.lower_function_lvalue_ref(
            lhs_ref, function, scope,
          )
          scope.pending_compound_assignment_rhs_local_root = None
          let target = self.materialize_store_pointer_if_needed(
            function, scope, block, raw_target,
          )
          if wgsl_ir_expr_ref_plain_local_identifier(lhs_ref, scope) {
            match rhs_ref.root() {
              Some(root) =>
                if wgsl_ir_compound_assignment_rhs_predeclares_reference_roots(
                    root, scope,
                  ) {
                  self.predeclare_function_binary_chain_reference_roots_in_source_order(
                    root, function, scope,
                  )
                }
              None => ()
            }
          }
          match rhs_ref.root() {
            Some(root) =>
              if wgsl_ir_direct_access_chain_root_is_function_argument(
                  root, scope,
                ) {
                self.predeclare_function_reference_roots_in_source_order(
                  root, function, scope,
                )
              }
            None => ()
          }
          let target_value = self.compound_assignment_target_value(
            function, target,
          )
          let materialized_target = self.materialize_function_expression(
            function, scope, block, target_value,
          )
          scope.compound_assignment_rhs_depth += 1
          let rhs_value = self.lower_expression_ref_with_materialized_short_circuit_inputs(
            rhs_ref,
            function,
            scope,
            block,
            None,
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
        None =>
          if wgsl_ir_expr_ref_plain_local_identifier(lhs_ref, scope) {
            let early_raw_target : Handle? = if wgsl_ir_expr_ref_root_is_literal_like(
                rhs_ref,
              ) {
              Some(self.lower_function_lvalue_ref(lhs_ref, function, scope))
            } else {
              None
            }
            let rhs_value = self.lower_expression_ref_with_materialized_short_circuit_inputs(
              rhs_ref,
              function,
              scope,
              block,
              None,
            )
            let raw_target = match early_raw_target {
              Some(target) => target
              None => self.lower_function_lvalue_ref(lhs_ref, function, scope)
            }
            let target = self.materialize_store_pointer_if_needed(
              function, scope, block, raw_target,
            )
            let value = self.materialize_store_value_for_pointer_if_needed(
              function, scope, block, target, rhs_value,
            )
            (target, value)
          } else if self.wgsl_ir_expr_ref_is_function_argument_pointer_deref(
              lhs_ref, function, scope,
            ) {
            let store_pointer_root = self.function_argument_pointer_deref_name_ref(
              lhs_ref, function, scope,
            )
            if store_pointer_root is Some(name) &&
              self.rhs_user_call_reads_pointer_argument(rhs_ref, name) {
              ignore(
                scope.argument_pointer_expression(
                  name,
                  scope.arguments[name],
                  function,
                ),
              )
            }
            let previous_pending = scope.pending_store_pointer_argument_root
            scope.pending_store_pointer_argument_root = store_pointer_root
            let rhs_value = self.lower_expression_ref_with_materialized_short_circuit_inputs(
              rhs_ref,
              function,
              scope,
              block,
              None,
            )
            scope.pending_store_pointer_argument_root = previous_pending
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
            predeclare_assignment_rhs_root_before_target_if_needed(
              rhs_ref, function, scope,
            )
            let raw_target = self.lower_function_lvalue_ref(
              lhs_ref, function, scope,
            )
            let target = self.materialize_store_pointer_if_needed(
              function, scope, block, raw_target,
            )
            let rhs_value = self.lower_expression_ref_with_materialized_short_circuit_inputs(
              rhs_ref,
              function,
              scope,
              block,
              None,
            )
            let value = self.materialize_store_value_for_pointer_if_needed(
              function, scope, block, target, rhs_value,
            )
            (target, value)
          }
      }
      wgsl_ir_record_store_value_temporary_references(function, value)
      BodyEmissionPlanner::push_statement_emit_ranges(
        block,
        function,
        expression_mark,
        wgsl_ir_max_handle(target, value),
      )
      block.push(Store(target, value))
    }
    Increment(target) =>
      self.lower_update_statement(target, function, scope, block, true)
    Decrement(target) =>
      self.lower_update_statement(target, function, scope, block, false)
    FunctionCall(expr) => {
      guard expr is Some(expr_ref) else {
        raise UnsupportedStatement("function call without expression")
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
            block.push(Emit(HandleRange(handle, handle)))
          }
        None => ()
      }
    ConstAssert(expr) => {
      guard expr is Some(expr_ref) else {
        raise UnsupportedStatement("const_assert without expression")
      }
      block.push(
        ConstAssert(
          self.lower_function_expression_ref(expr_ref, function, scope),
        ),
      )
    }
    For(expressions) =>
      self.lower_for_statement(statement, expressions, function, scope, block)
    Switch(selector) => {
      guard selector is Some(selector_ref) else {
        raise UnsupportedStatement("switch without selector")
      }
      let expression_mark = function.expressions.items.length()
      let lowered_selector = self.lower_function_expression_ref(
        selector_ref, function, scope,
      )
      let selector_handle = self.materialize_control_flow_condition_if_needed(
        function, scope, block, lowered_selector,
      )
      let cases : Array[SwitchCase] = []
      match statement.blocks() {
        [switch_block, ..] =>
          self.lower_switch_cases(
            switch_block, function, scope, selector_handle, cases,
          )
        [] => ()
      }
      BodyEmissionPlanner::push_statement_emit_ranges(
        block, function, expression_mark, selector_handle,
      )
      block.push(Switch(selector_handle, cases))
    }
    Case(_) | DefaultCase =>
      raise UnsupportedStatement(
        "structured statement not yet representable by this WGSL IR lowerer",
      )
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
  source_var_store_initializers : Array[String],
) -> Unit raise WgslIrLowerError {
  if local_decl.kind() == Const {
    self.lower_local_const_declaration(
      local_decl, function, scope, local_constant_placement,
    )
    return
  }
  if local_decl.kind() == Var &&
    source_var_store_initializers.any(fn(name) {
      name == local_decl.name().name()
    }) {
    self.lower_local_var_store_declaration(local_decl, function, scope, block)
    return
  }
  if local_decl.kind() == Var &&
    !scope.predeclared_source_locals.contains(
      wgsl_ir_local_declaration_key(local_decl),
    ) &&
    !self.local_var_initializer_uses_store(local_decl) {
    self.predeclare_source_local_placeholder(local_decl, function, scope)
  }
  if local_decl.kind() == Var &&
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
            let declaration_placement = match local_constant_placement {
              DeclarationArenaLocalConstant => true
              UseSiteLazyLocalConstant => false
            }
            if scope.loop_depth == 0 || declaration_placement {
              self.lower_predeclared_source_var_const_initializer(
                local_decl, expr_ref, function, scope, block,
              )
            } else {
              self.lower_local_var_store_declaration(
                local_decl, function, scope, block,
              )
            }
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
  if local_decl.kind() == Var &&
    self.local_var_initializer_uses_store(local_decl) {
    self.lower_local_var_store_declaration(local_decl, function, scope, block)
    return
  }
  if local_decl.kind() == Var &&
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
          if local_decl.kind() == Let {
            Some(target)
          } else {
            Some(function.expressions.append(AddressOf(pointer_ty, target)))
          }
        }
        None => {
          let init_is_const = if local_decl.kind() == Var {
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
            } else if local_decl.kind() == Let &&
              wgsl_ir_expr_ref_references_local_let_constant(expr_ref, scope) {
              scope.source_let_initializer_preserve_depth += 1
              let handle = self.lower_function_expression_ref_with_expected(
                expr_ref, function, scope, explicit_ty,
              )
              scope.source_let_initializer_preserve_depth -= 1
              handle
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
  if local_decl.kind() == Let {
    match init {
      Some(init_handle) => {
        if self.local_let_const_scalar_initializer_should_fold(
            local_decl, init_handle, function, scope,
          ) {
          let normalized = self.normalized_local_constant_initializer(
            function, init_handle, explicit_ty,
          )
          function.expressions.set_origin(normalized, FoldedLocalConstant)
          ignore(scope.locals.remove(local_decl.name().name()))
          ignore(
            scope.local_pointer_expressions.remove(local_decl.name().name()),
          )
          match local_constant_placement {
            DeclarationArenaLocalConstant =>
              scope.local_constants.set(
                local_decl.name().name(),
                wgsl_ir_local_let_value_cell(ExpressionAlias(normalized, None)),
              )
            UseSiteLazyLocalConstant => {
              let normalized_expression = wgsl_ir_lazy_local_constant_expression(
                function, normalized,
              )
              wgsl_ir_rewind_function_expressions_and_local_constant_values(
                function, expression_mark, scope, local_constant_snapshot,
              )
              match local_decl.initializer_ref() {
                Some(expr_ref) =>
                  scope.local_constants.set(
                    local_decl.name().name(),
                    wgsl_ir_local_let_value_cell(
                      LazyConstant({
                        expr_ref,
                        explicit_ty,
                        normalized: normalized_expression,
                      }),
                    ),
                  )
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
              scope.local_constants.set(
                local_decl.name().name(),
                wgsl_ir_local_let_value_cell(
                  ExpressionAlias(materialized_value, None),
                ),
              )
              return
            } else if wgsl_ir_function_expression_is_materialized_temporary(
                function, normalized,
              ) {
              ignore(scope.locals.remove(local_decl.name().name()))
              ignore(
                scope.local_pointer_expressions.remove(local_decl.name().name()),
              )
              scope.local_constants.set(
                local_decl.name().name(),
                wgsl_ir_local_let_value_cell(ExpressionAlias(normalized, None)),
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
  if local_decl.kind() == Var {
    match local_decl.initializer_ref() {
      Some(expr_ref) =>
        match expr_ref.root() {
          Some(root) =>
            if self.expression_node_is_const_initializer(root) {
              self.record_source_local_const_initializer_literals(
                expr_ref,
                expression_mark,
                function,
                scope,
                Some(ty),
              )
            }
          None => ()
        }
      None => ()
    }
  }
  if local_decl.kind() == Let {
    match init {
      Some(init_handle) =>
        if self.function_expression_is_handle_resource_value(
            function, init_handle,
          ) {
          ignore(scope.locals.remove(local_decl.name().name()))
          ignore(
            scope.local_pointer_expressions.remove(local_decl.name().name()),
          )
          scope.local_constants.set(
            local_decl.name().name(),
            wgsl_ir_local_let_value_cell(ExpressionAlias(init_handle, None)),
          )
          return
        }
      None => ()
    }
  }
  let lowered_name = local_decl.name().name()
  if local_decl.kind() == Let {
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
            scope.local_constants.set(
              local_decl.name().name(),
              wgsl_ir_local_let_value_cell(ExpressionAlias(init_handle, None)),
            )
            return
          }
          function.named_expressions.push({
            handle: init_handle,
            name: lowered_name,
            ty,
          })
          ignore(scope.locals.remove(local_decl.name().name()))
          ignore(
            scope.local_pointer_expressions.remove(local_decl.name().name()),
          )
          scope.local_constants.set(
            local_decl.name().name(),
            wgsl_ir_local_let_value_cell(ExpressionAlias(init_handle, None)),
          )
          BodyEmissionPlanner::push_named_expression_emit_ranges(
            block, function, expression_mark, init_handle,
          )
          return
        }
      None => ()
    }
  }
  let var_init_in_declaration = if local_decl.kind() == Var {
    match init {
      Some(init_handle) =>
        self.function_expression_is_const_expression(function, init_handle)
      None => false
    }
  } else {
    false
  }
  let handle = function.local_variables.append({
    name: Some(lowered_name),
    kind: wgsl_ir_local_variable_kind(local_decl.kind()),
    generated_temporary: false,
    generated_temporary_store_value_reference: false,
    short_circuit_result: false,
    ty,
    init: if local_decl.kind() == Var {
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
  block.push(Declare(handle))
  if local_decl.kind() == Var {
    match init {
      Some(init_handle) =>
        if !var_init_in_declaration {
          let materialized = self.materialize_store_value_if_needed(
            function, scope, block, init_handle,
          )
          wgsl_ir_record_store_value_temporary_references(
            function, materialized,
          )
          BodyEmissionPlanner::push_statement_emit_ranges(
            block, function, expression_mark, materialized,
          )
          block.push(
            Store(
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
  self.lower_predeclared_source_var_const_initializer_to_handle(
    local_decl, expr_ref, function, scope, handle,
  )
  ignore(
    wgsl_ir_lower_predeclared_source_var_declaration(local_decl, scope, block),
  )
}

///|
fn WgslIrLowerer::lower_predeclared_source_var_const_initializer_to_handle(
  self : WgslIrLowerer,
  local_decl : @ast.WgslLocalDeclaration,
  expr_ref : @ast.WgslExprRef,
  function : Function,
  scope : WgslIrFunctionScope,
  handle : Handle,
) -> Unit raise WgslIrLowerError {
  let lowered_name = local_decl.name().name()
  let explicit_ty = match local_decl.ty_ref() {
    Some(ty_ref) => Some(self.lower_function_type_ref(ty_ref, function, scope))
    None => None
  }
  let expected_ty = self.source_local_const_initializer_expected_type(
    local_decl, explicit_ty,
  )
  let init = self.lower_source_local_const_initializer(
    expr_ref, expected_ty, function, scope,
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
  function.local_variables.set(handle, {
    name: Some(lowered_name),
    kind: Var,
    generated_temporary: false,
    generated_temporary_store_value_reference: false,
    short_circuit_result: false,
    ty,
    init: Some(init),
  })
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
      block.push(Declare(handle))
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
      self.type_cache.contains(ident.name()) ||
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
  let lowered_name = local_decl.name().name()
  let handle = match
    scope.predeclared_source_locals.get(
      wgsl_ir_local_declaration_key(local_decl),
    ) {
    Some(predeclared) => predeclared
    None =>
      function.local_variables.append({
        name: Some(lowered_name),
        kind: Var,
        generated_temporary: false,
        generated_temporary_store_value_reference: false,
        short_circuit_result: false,
        ty: placeholder_ty,
        init: None,
      })
  }
  function.local_variables.set(handle, {
    name: Some(lowered_name),
    kind: Var,
    generated_temporary: false,
    generated_temporary_store_value_reference: false,
    short_circuit_result: false,
    ty: placeholder_ty,
    init: None,
  })
  block.push(Declare(handle))
  let predeclare_pointer = self.local_var_store_initializer_predeclares_pointer(
    local_decl, scope,
  )
  let mut pointer : Handle? = if predeclare_pointer {
    Some(function.expressions.append(LocalVariable(handle)))
  } else {
    None
  }
  guard local_decl.initializer_ref() is Some(expr_ref) else { return }
  let expression_mark = function.expressions.items.length()
  let init = match wgsl_ir_address_of_operand_ref(expr_ref) {
    Some(target_ref) => {
      let target = self.lower_function_lvalue_node(target_ref, function, scope)
      function.expressions.append(
        AddressOf(self.pointer_type_for_lvalue(function, target), target),
      )
    }
    None =>
      match expr_ref.root() {
        Some(root) if wgsl_ir_expr_node_literal_token(root) is Some(token) =>
          self.lower_function_fresh_literal_node_with_expected(
            token, function, explicit_ty,
          )
        _ =>
          self.lower_expression_ref_with_materialized_short_circuit_inputs(
            expr_ref, function, scope, block, explicit_ty,
          )
      }
  }
  if pointer == None {
    pointer = Some(function.expressions.append(LocalVariable(handle)))
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
  function.local_variables.set(handle, {
    name: Some(lowered_name),
    kind: Var,
    generated_temporary: false,
    generated_temporary_store_value_reference: false,
    short_circuit_result: false,
    ty,
    init: None,
  })
  ignore(scope.local_constants.remove(local_decl.name().name()))
  ignore(scope.local_pointer_expressions.remove(local_decl.name().name()))
  scope.locals.set(local_decl.name().name(), handle)
  guard pointer is Some(pointer) else {
    raise UnsupportedStatement(
      "missing local pointer for var \{local_decl.name().name()}",
    )
  }
  scope.local_pointer_expressions.set(local_decl.name().name(), pointer)
  self.contextualize_function_expression_for_type(function, init, ty)
  let materialized = self.materialize_store_value_if_needed(
    function, scope, block, init,
  )
  wgsl_ir_record_store_value_temporary_references(function, materialized)
  BodyEmissionPlanner::push_statement_emit_ranges(
    block, function, expression_mark, materialized,
  )
  block.push(Store(pointer, materialized))
}

///|
fn WgslIrLowerer::local_var_store_initializer_predeclares_pointer(
  self : WgslIrLowerer,
  local_decl : @ast.WgslLocalDeclaration,
  scope : WgslIrFunctionScope,
) -> Bool raise WgslIrLowerError {
  match local_decl.initializer_ref() {
    Some(expr_ref) =>
      match expr_ref.root() {
        Some(root) =>
          self.expression_node_is_const_initializer(root) ||
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
