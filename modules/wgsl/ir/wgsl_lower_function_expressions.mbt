///|
fn WgslIrLowerer::lower_function_expression_ref(
  self : WgslIrLowerer,
  expr_ref : @ast.WgslExprRef,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  self.lower_function_expression_ref_with_expected(
    expr_ref,
    function,
    scope,
    None,
  )
}

///|
fn WgslIrLowerer::lower_function_expression_ref_with_expected(
  self : WgslIrLowerer,
  expr_ref : @ast.WgslExprRef,
  function : Function,
  scope : WgslIrFunctionScope,
  expected_ty : Handle?,
) -> Handle raise WgslIrLowerError {
  guard expr_ref.root() is Some(root) else {
    raise UnsupportedExpression("empty function expression")
  }
  self.lower_function_expression_node_with_expected(
    root, function, scope, expected_ty,
  ) catch {
    UnsupportedExpression(message) =>
      raise UnsupportedExpression(
        "\{message} at \{expr_ref.start()}..\{expr_ref.end()}: \{wgsl_ir_expr_ref_token_text(expr_ref)}",
      )
    error => raise error
  }
}

///|
fn wgsl_ir_expr_ref_token_text(expr_ref : @ast.WgslExprRef) -> String {
  let parts : Array[String] = []
  for token in expr_ref.tokens() {
    parts.push(token.text())
  }
  parts.join(" ")
}

///|
fn WgslIrLowerer::lower_function_lvalue_ref(
  self : WgslIrLowerer,
  expr_ref : @ast.WgslExprRef,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  guard expr_ref.root() is Some(root) else {
    raise UnsupportedExpression("empty lvalue")
  }
  self.lower_function_lvalue_node(root, function, scope)
}

///|
fn WgslIrLowerer::append_foldable_function_binary_expression(
  self : WgslIrLowerer,
  function : Function,
  scope : WgslIrFunctionScope,
  local_constant_snapshot : Map[String, WgslIrLocalValue],
  expression_mark : Int,
  op : BinaryOperator,
  left : Handle,
  right : Handle,
  allow_fold : Bool,
) -> Handle raise WgslIrLowerError {
  let handle = function.expressions.append(Binary(op, left, right))
  if !allow_fold {
    return handle
  }
  self.fold_function_binary_expression_at_mark(
    function, scope, local_constant_snapshot, expression_mark, handle,
  )
}

///|
fn WgslIrLowerer::fold_function_binary_expression_at_mark(
  self : WgslIrLowerer,
  function : Function,
  scope : WgslIrFunctionScope,
  local_constant_snapshot : Map[String, WgslIrLocalValue],
  expression_mark : Int,
  handle : Handle,
) -> Handle raise WgslIrLowerError {
  if self.function_binary_expression_should_retain_generated_import_constant(
      function, handle,
    ) {
    return handle
  }
  match self.fold_function_constant_typed_literal_expression(function, handle) {
    Some(literal) => {
      wgsl_ir_rewind_function_expressions_and_local_constant_values(
        function, expression_mark, scope, local_constant_snapshot,
      )
      function.expressions.append_with_origin(
        Literal(literal),
        FoldedLocalConstant,
      )
    }
    None => handle
  }
}

///|
fn WgslIrLowerer::function_argument_is_pointer(
  self : WgslIrLowerer,
  function : Function,
  index : Int,
) -> Bool {
  match function.arguments.get(index) {
    Some(argument) =>
      match self.shader_module.types.get(argument.ty) {
        Some(type_) =>
          match type_.inner {
            Pointer(_, _) => true
            _ => false
          }
        None => false
      }
    None => false
  }
}

///|
fn WgslIrLowerer::lower_function_lvalue_node(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  match node.kind() {
    Identifier(name) => {
      match scope.local_constants.get(name.name()) {
        Some(_) => raise UnsupportedExpression("local const is not assignable")
        None => ()
      }
      match scope.locals.get(name.name()) {
        Some(handle) => {
          match function.local_variables.items.get(handle.index()) {
            Some(local_var) =>
              if local_var.kind == Let {
                raise UnsupportedExpression("local let is not assignable")
              }
            None => ()
          }
          return scope.local_pointer_expression(name.name(), handle, function)
        }
        None => ()
      }
      match scope.arguments.get(name.name()) {
        Some(index) =>
          if self.function_argument_is_pointer(function, index) {
            return scope.argument_pointer_expression(
              name.name(),
              index,
              function,
            )
          } else {
            raise UnsupportedExpression("function argument is not assignable")
          }
        None => ()
      }
      match self.global_names.get(name.name()) {
        Some(handle) =>
          match scope.consume_pending_global_pointer_expression(name.name()) {
            Some(predeclared) => predeclared
            None =>
              scope.global_pointer_expression(
                name.name(),
                handle,
                function,
                self.global_variable_reuses_pointer_expression(handle),
              )
          }
        None => raise UnknownIdentifier(name.name())
      }
    }
    Group(inner) => self.lower_function_lvalue_node(inner, function, scope)
    Unary(op, expr) =>
      if op == Multiply {
        self.lower_function_expression_node(expr, function, scope)
      } else {
        raise UnsupportedExpression("unsupported lvalue shape")
      }
    Member(base, member_name) => {
      let base_handle = self.lower_function_member_lvalue_base(
        base, function, scope,
      )
      function.expressions.append(
        AccessIndex(
          base_handle,
          self.member_index_for_expression(
            function,
            base_handle,
            member_name.name(),
          ),
        ),
      )
    }
    Index(base, index) => {
      match
        self.lower_function_direct_addressable_lvalue_binary_index(
          base, index, function, scope,
        ) {
        Some(handle) => return handle
        None => ()
      }
      match
        self.lower_function_dynamic_member_index_access(
          base, index, function, scope,
        ) {
        Some(handle) => return handle
        None => ()
      }
      match self.static_index_value_from_expr_node(index) {
        Some(_) => ()
        None => {
          if wgsl_ir_expr_node_contains_member_access(base) {
            self.predeclare_function_member_root_expression(
              base, function, scope,
            )
            self.predeclare_function_argument_values_in_source_order(
              index, function, scope,
            )
          } else {
            self.predeclare_function_reference_roots_in_source_order(
              index, function, scope,
            )
          }
          let base_handle = self.lower_function_lvalue_node(
            base, function, scope,
          )
          let index_handle = self.lower_function_expression_node(
            index, function, scope,
          )
          return function.expressions.append(Access(base_handle, index_handle))
        }
      }
      let base_handle = self.lower_function_lvalue_node(base, function, scope)
      self.lower_function_static_or_dynamic_index(
        base_handle, index, function, scope,
      )
    }
    _ => raise UnsupportedExpression("unsupported lvalue shape")
  }
}

///|
fn WgslIrLowerer::lower_function_direct_addressable_lvalue_binary_index(
  self : WgslIrLowerer,
  base : @ast.WgslExprNode,
  index : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle? raise WgslIrLowerError {
  match self.static_index_value_from_expr_node(index) {
    Some(_) => return None
    None => ()
  }
  guard !wgsl_ir_expr_node_contains_member_access(index) else { return None }
  let name = match base.kind() {
    Identifier(name) => name.name()
    _ => return None
  }
  guard !self.expression_node_contains_mutable_local_reference(
      index, function, scope,
    ) ||
    self.expression_identifier_is_direct_local_var_base(name, function, scope) else {
    return None
  }
  guard self.expression_identifier_is_direct_addressable_base(
    name, function, scope,
  ) else {
    return None
  }
  let (op, left, right) = match index.kind() {
    Binary(_, _, _) =>
      self.lower_binary_expression_children(index, function, scope)
    _ => return None
  }
  let base_handle = self.lower_function_lvalue_node(base, function, scope)
  let binary_op = wgsl_ir_binary_operator(op)
  let (left, right) = self.normalize_function_binary_operands(
    function, binary_op, left, right,
  )
  let index_handle = function.expressions.append(Binary(binary_op, left, right))
  Some(function.expressions.append(Access(base_handle, index_handle)))
}

///|
fn WgslIrLowerer::lower_function_direct_addressable_value_binary_index(
  self : WgslIrLowerer,
  base : @ast.WgslExprNode,
  index : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle? raise WgslIrLowerError {
  match self.static_index_value_from_expr_node(index) {
    Some(_) => return None
    None => ()
  }
  guard !wgsl_ir_expr_node_contains_member_access(index) else { return None }
  let name = match base.kind() {
    Identifier(name) => name.name()
    _ => return None
  }
  guard !self.expression_node_contains_mutable_local_reference(
      index, function, scope,
    ) ||
    self.expression_identifier_is_direct_local_var_base(name, function, scope) else {
    return None
  }
  guard self.expression_identifier_is_direct_addressable_base(
    name, function, scope,
  ) else {
    return None
  }
  let (op, left, right) = match index.kind() {
    Binary(_, _, _) =>
      self.lower_binary_expression_children(index, function, scope)
    _ => return None
  }
  let base_handle = self.lower_function_index_value_base(base, function, scope)
  let binary_op = wgsl_ir_binary_operator(op)
  let (left, right) = self.normalize_function_binary_operands(
    function, binary_op, left, right,
  )
  let index_handle = function.expressions.append(Binary(binary_op, left, right))
  Some(
    self.apply_function_load_rule(
      function,
      function.expressions.append(Access(base_handle, index_handle)),
    ),
  )
}

///|
fn WgslIrLowerer::expression_identifier_is_direct_addressable_base(
  self : WgslIrLowerer,
  name : String,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Bool {
  match scope.locals.get(name) {
    Some(handle) =>
      match function.local_variables.items.get(handle.index()) {
        Some(local_var) =>
          local_var.kind == Var ||
          self.local_variable_is_handle_value(function, handle)
        None => false
      }
    None =>
      match self.global_names.get(name) {
        Some(_) => true
        None => false
      }
  }
}

///|
fn WgslIrLowerer::expression_identifier_is_direct_local_var_base(
  self : WgslIrLowerer,
  name : String,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Bool {
  match scope.locals.get(name) {
    Some(handle) =>
      match function.local_variables.items.get(handle.index()) {
        Some(local_var) =>
          local_var.kind == Var ||
          self.local_variable_is_handle_value(function, handle)
        None => false
      }
    None => false
  }
}

///|
fn WgslIrLowerer::lower_function_member_lvalue_base(
  self : WgslIrLowerer,
  base : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  match wgsl_ir_deref_operand(base) {
    Some(operand) =>
      self.lower_function_expression_node(operand, function, scope)
    None => self.lower_function_lvalue_node(base, function, scope)
  }
}

///|
fn WgslIrLowerer::lower_function_member_value_base(
  self : WgslIrLowerer,
  base : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  match wgsl_ir_deref_operand(base) {
    Some(operand) =>
      self.lower_function_expression_node(operand, function, scope)
    None =>
      if self.function_access_base_is_addressable(base, function, scope) {
        self.lower_function_access_base_pointer_node(base, function, scope)
      } else {
        self.lower_function_expression_node(base, function, scope)
      }
  }
}

///|
fn wgsl_ir_deref_operand(node : @ast.WgslExprNode) -> @ast.WgslExprNode? {
  match node.kind() {
    Group(inner) => wgsl_ir_deref_operand(inner)
    Unary(op, expr) => if op == Multiply { Some(expr) } else { None }
    _ => None
  }
}

///|
fn WgslIrLowerer::lower_function_expression_node(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  self.lower_function_expression_node_with_expected(node, function, scope, None)
}

///|
fn WgslIrLowerer::lower_function_expression_node_with_expected(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
  expected_ty : Handle?,
) -> Handle raise WgslIrLowerError {
  match node.kind() {
    Literal(token) =>
      self.lower_function_literal_node_with_expected(
        token, function, scope, expected_ty,
      )
    ShaderDefTemplate(text) =>
      raise UnsupportedExpression(
        "shader-def template expression requires preprocessing: \{text}",
      )
    Identifier(name) =>
      self.lower_identifier_expression(name.name(), function, scope)
    PostfixUpdate(_, _) =>
      raise UnsupportedExpression("update expression outside statement context")
    Assignment(_, _, _) =>
      raise UnsupportedExpression(
        "assignment expression outside statement context",
      )
    Unary(op, expr) =>
      if op == BitAnd {
        let target = self.lower_function_lvalue_node(expr, function, scope)
        function.expressions.append(
          AddressOf(self.pointer_type_for_lvalue(function, target), target),
        )
      } else if op == Multiply {
        function.expressions.append(
          Load(self.lower_function_expression_node(expr, function, scope)),
        )
      } else if op == Subtract {
        match expr.kind() {
          Literal(token) =>
            match
              self.negated_literal_from_token_with_expected(token, expected_ty) {
              Some(literal) => function.expressions.append(Literal(literal))
              None =>
                function.expressions.append(
                  Unary(
                    wgsl_ir_unary_operator(op),
                    self.lower_function_expression_node(expr, function, scope),
                  ),
                )
            }
          _ =>
            function.expressions.append(
              Unary(
                wgsl_ir_unary_operator(op),
                self.lower_function_expression_node(expr, function, scope),
              ),
            )
        }
      } else {
        function.expressions.append(
          Unary(
            wgsl_ir_unary_operator(op),
            self.lower_function_expression_node(expr, function, scope),
          ),
        )
      }
    Binary(op, left, right) => {
      let scheduler = self.expression_arena_scheduler(function, scope)
      let expression_mark = function.expressions.items.length()
      let local_constant_snapshot = wgsl_ir_snapshot_local_constant_values(
        scope.local_constants,
      )
      if scheduler.binary_predeclares_left_associative_reference_roots(
          op, left, right,
        ) {
        self.predeclare_function_binary_chain_reference_roots_in_source_order(
          node, function, scope,
        )
      }
      match
        self.plan_binary_sibling_arguments_before_parent(
          op, left, right, function, scope,
        ) {
        Some(handle) => return handle
        None => ()
      }
      match
        self.plan_binary_const_left_before_math_parent(
          op, left, right, function, scope,
        ) {
        Some(handle) => return handle
        None => ()
      }
      match
        self.plan_binary_declared_constant_before_call_product(
          op, left, right, function, scope,
        ) {
        Some(handle) => return handle
        None => ()
      }
      match
        self.plan_binary_trailing_source_let_initializer(
          op, left, right, function, scope,
        ) {
        Some(handle) => return handle
        None => ()
      }
      match
        self.plan_binary_trailing_source_let_literal(
          op, left, right, function, scope,
        ) {
        Some(handle) => return handle
        None => ()
      }
      match
        self.plan_binary_folded_right_const_vector_operand(
          op, left, right, function, scope,
        ) {
        Some(handle) => return handle
        None => ()
      }
      match
        self.plan_binary_parent_argument_after_member_root(
          op, left, right, function, scope,
        ) {
        Some(handle) => return handle
        None => ()
      }
      match
        self.plan_binary_parent_argument_after_named_root(
          op, left, right, function, scope,
        ) {
        Some(handle) => return handle
        None => ()
      }
      match
        self.plan_binary_parent_argument_root_projection(
          op, left, right, function, scope,
        ) {
        Some(handle) => return handle
        None => ()
      }
      match
        self.plan_binary_left_argument_after_global_product(
          op, left, right, function, scope,
        ) {
        Some(handle) => return handle
        None => ()
      }
      let member_bases_lower_in_source_order = scheduler.binary_predeclares_sibling_member_roots(
        left, right,
      )
      if member_bases_lower_in_source_order {
        self.predeclare_function_member_base_expressions(left, function, scope)
        self.predeclare_function_member_base_expressions(right, function, scope)
      } else if wgsl_ir_expr_node_is_function_argument_value(left, scope) &&
        wgsl_ir_expr_node_is_direct_access_chain(right) {
        self.predeclare_function_member_base_expressions(right, function, scope)
      } else if wgsl_ir_expr_node_is_direct_access_chain(left) &&
        wgsl_ir_expr_node_is_function_argument_value(right, scope) {
        self.predeclare_function_reference_roots_in_source_order(
          left, function, scope,
        )
        self.predeclare_function_argument_value(right, function, scope)
      } else if scheduler.binary_predeclares_right_subtree_arguments_before_left_access_projection(
          op, left, right,
        ) {
        self.predeclare_function_reference_roots_in_source_order(
          left, function, scope,
        )
        self.predeclare_function_argument_values_in_source_order(
          right, function, scope,
        )
      } else if scheduler.binary_predeclares_right_subtree_arguments_before_left_associative_call_chain(
          op, left, right,
        ) {
        self.predeclare_function_argument_values_in_source_order(
          right, function, scope,
        )
      } else if scheduler.binary_predeclares_right_constructor_argument_member_root(
          left, right,
        ) {
        self.predeclare_function_reference_roots_in_source_order(
          left, function, scope,
        )
        self.predeclare_function_member_base_expressions(right, function, scope)
      } else if wgsl_ir_expr_node_contains_member_access(left) &&
        wgsl_ir_expr_node_contains_function_argument_math_call(right, scope) {
        self.predeclare_function_reference_roots_in_source_order(
          left, function, scope,
        )
        self.predeclare_function_reference_roots_in_source_order(
          right, function, scope,
        )
      } else if scheduler.binary_right_subtree_has_higher_precedence(op, right) &&
        !wgsl_ir_expr_node_is_function_argument_value(left, scope) &&
        wgsl_ir_expr_node_is_direct_access_chain(left) &&
        wgsl_ir_expr_node_contains_call(left) &&
        !wgsl_ir_expr_node_contains_non_math_call(left) &&
        !wgsl_ir_expr_node_contains_non_math_call(right) &&
        wgsl_ir_expr_node_contains_function_argument_value(right, scope) {
        self.predeclare_function_argument_values_in_source_order(
          right, function, scope,
        )
      }
      let (left_handle, right_handle) = if !member_bases_lower_in_source_order &&
        (
          scheduler.binary_right_subtree_has_higher_precedence(op, right) ||
          scheduler.binary_lowers_right_children_before_left_access(
            op, left, right,
          )
        ) {
        match
          self.plan_binary_const_parent_with_right_local_reference(
            op, left, right, function, scope,
          ) {
          Some(result) => result
          None =>
            if scheduler.binary_preserves_left_first_across_higher_precedence_right(
                op, left, right,
              ) {
              let left_handle = self.lower_function_expression_node(
                left, function, scope,
              )
              let right_mark = function.expressions.items.length()
              let (right_op, right_left, right_right) = self.lower_binary_expression_children(
                right, function, scope,
              )
              let right_binary_op = wgsl_ir_binary_operator(right_op)
              let (right_left, right_right) = self.normalize_function_binary_operands(
                function, right_binary_op, right_left, right_right,
              )
              let right_handle = self.append_foldable_function_binary_expression(
                function,
                scope,
                local_constant_snapshot,
                right_mark,
                right_binary_op,
                right_left,
                right_right,
                !wgsl_ir_expr_node_references_local_let_constant(right, scope),
              )
              (left_handle, right_handle)
            } else if scheduler.binary_lowers_right_children_before_left_access(
                op, left, right,
              ) {
              let right_mark = function.expressions.items.length()
              let (right_op, right_left, right_right) = self.lower_binary_expression_children(
                right, function, scope,
              )
              let right_binary_op = wgsl_ir_binary_operator(right_op)
              let (right_left, right_right) = self.normalize_function_binary_operands(
                function, right_binary_op, right_left, right_right,
              )
              let left_handle = self.lower_function_expression_node(
                left, function, scope,
              )
              let right_handle = self.append_foldable_function_binary_expression(
                function,
                scope,
                local_constant_snapshot,
                right_mark,
                right_binary_op,
                right_left,
                right_right,
                !wgsl_ir_expr_node_references_local_let_constant(right, scope),
              )
              (left_handle, right_handle)
            } else if wgsl_ir_expr_node_is_direct_access_chain(left) ||
              self.expression_node_is_mutable_local_value(left, function, scope) {
              let left_handle = self.lower_function_expression_node(
                left, function, scope,
              )
              let right_mark = function.expressions.items.length()
              let (right_op, right_left, right_right) = self.lower_binary_expression_children(
                right, function, scope,
              )
              let right_binary_op = wgsl_ir_binary_operator(right_op)
              let (right_left, right_right) = self.normalize_function_binary_operands(
                function, right_binary_op, right_left, right_right,
              )
              let right_handle = self.append_foldable_function_binary_expression(
                function,
                scope,
                local_constant_snapshot,
                right_mark,
                right_binary_op,
                right_left,
                right_right,
                !wgsl_ir_expr_node_references_local_let_constant(right, scope),
              )
              (left_handle, right_handle)
            } else {
              let right_binary_lowers_before_left = wgsl_ir_expr_node_contains_non_math_call(
                  right,
                ) ||
                wgsl_ir_expr_node_is_literal_like(left)
              let right_children_lower_before_left = wgsl_ir_expr_node_is_function_argument_value(
                  left, scope,
                ) &&
                !wgsl_ir_expr_node_contains_call(right)
              let (left_handle, right_handle) = if right_binary_lowers_before_left {
                let right_mark = function.expressions.items.length()
                let (right_op, right_left, right_right) = self.lower_binary_expression_children(
                  right, function, scope,
                )
                let right_binary_op = wgsl_ir_binary_operator(right_op)
                let (right_left, right_right) = self.normalize_function_binary_operands(
                  function, right_binary_op, right_left, right_right,
                )
                let right_handle = self.append_foldable_function_binary_expression(
                  function,
                  scope,
                  local_constant_snapshot,
                  right_mark,
                  right_binary_op,
                  right_left,
                  right_right,
                  !wgsl_ir_expr_node_references_local_let_constant(right, scope),
                )
                let left_handle = self.lower_function_expression_node(
                  left, function, scope,
                )
                (left_handle, right_handle)
              } else if right_children_lower_before_left {
                let right_mark = function.expressions.items.length()
                let (right_op, right_left, right_right) = self.lower_binary_expression_children(
                  right, function, scope,
                )
                let right_binary_op = wgsl_ir_binary_operator(right_op)
                let (right_left, right_right) = self.normalize_function_binary_operands(
                  function, right_binary_op, right_left, right_right,
                )
                let left_handle = self.lower_function_expression_node(
                  left, function, scope,
                )
                let right_handle = self.append_foldable_function_binary_expression(
                  function,
                  scope,
                  local_constant_snapshot,
                  right_mark,
                  right_binary_op,
                  right_left,
                  right_right,
                  !wgsl_ir_expr_node_references_local_let_constant(right, scope),
                )
                (left_handle, right_handle)
              } else {
                let left_handle = self.lower_function_expression_node(
                  left, function, scope,
                )
                let right_mark = function.expressions.items.length()
                let (right_op, right_left, right_right) = self.lower_binary_expression_children(
                  right, function, scope,
                )
                let right_binary_op = wgsl_ir_binary_operator(right_op)
                let (right_left, right_right) = self.normalize_function_binary_operands(
                  function, right_binary_op, right_left, right_right,
                )
                let right_handle = self.append_foldable_function_binary_expression(
                  function,
                  scope,
                  local_constant_snapshot,
                  right_mark,
                  right_binary_op,
                  right_left,
                  right_right,
                  !wgsl_ir_expr_node_references_local_let_constant(right, scope),
                )
                (left_handle, right_handle)
              }
              (left_handle, right_handle)
            }
        }
      } else if wgsl_ir_expr_node_is_binary_source_let_arithmetic(left, scope) &&
        wgsl_ir_expr_node_is_direct_access_chain(right) &&
        !wgsl_ir_expr_node_contains_call(left) &&
        !wgsl_ir_expr_node_contains_call(right) {
        let (left_op, left_left, left_right) = self.lower_binary_expression_children(
          left, function, scope,
        )
        self.predeclare_function_member_root_expression(right, function, scope)
        let left_binary_op = wgsl_ir_binary_operator(left_op)
        let (left_left, left_right) = self.normalize_function_binary_operands(
          function, left_binary_op, left_left, left_right,
        )
        let left_handle = function.expressions.append(
          Binary(left_binary_op, left_left, left_right),
        )
        let right_handle = self.lower_function_expression_node(
          right, function, scope,
        )
        (left_handle, right_handle)
      } else if scheduler.binary_lowers_right_argument_before_left_access(
          left, right,
        ) {
        let right_handle = self.lower_function_expression_node(
          right, function, scope,
        )
        let left_handle = self.lower_function_expression_node(
          left, function, scope,
        )
        (left_handle, right_handle)
      } else if scheduler.binary_delays_left_constructor_commit_until_right_argument(
          left, right,
        ) {
        match
          self.plan_binary_left_constructor_after_right_argument_root(
            left, right, function, scope,
          ) {
          Some(result) => result
          None => {
            let left_handle = self.lower_function_expression_node(
              left, function, scope,
            )
            let right_handle = self.lower_function_expression_node(
              right, function, scope,
            )
            (left_handle, right_handle)
          }
        }
      } else {
        match
          self.plan_binary_right_constructor_after_arguments_before_left(
            op, left, right, function, scope,
          ) {
          Some(result) => result
          None =>
            if op == Divide &&
              wgsl_ir_expr_node_is_literal_like(left) &&
              wgsl_ir_expr_node_contains_non_math_call(right) {
              let right_handle = self.lower_function_expression_node(
                right, function, scope,
              )
              let left_handle = self.lower_function_expression_node(
                left, function, scope,
              )
              (left_handle, right_handle)
            } else if scheduler.binary_lowers_right_before_left(op, left, right) {
              self.lower_function_right_operand_before_left(
                op, left, right, function, scope,
              )
            } else {
              let left_handle = self.lower_function_expression_node(
                left, function, scope,
              )
              let right_handle = self.lower_function_expression_node(
                right, function, scope,
              )
              (left_handle, right_handle)
            }
        }
      }
      let binary_op = wgsl_ir_binary_operator(op)
      let (left_handle, right_handle) = self.normalize_function_binary_operands(
        function, binary_op, left_handle, right_handle,
      )
      let handle = function.expressions.append(
        Binary(binary_op, left_handle, right_handle),
      )
      if wgsl_ir_expr_node_references_local_let_constant(node, scope) {
        function.expressions.set_origin(handle, RetainedSourceLetExpression)
        return handle
      }
      self.fold_function_binary_expression_at_mark(
        function, scope, local_constant_snapshot, expression_mark, handle,
      )
    }
    Group(expr) =>
      self.lower_function_expression_node_with_expected(
        expr, function, scope, expected_ty,
      )
    Sequence([single]) =>
      self.lower_function_expression_node_with_expected(
        single, function, scope, expected_ty,
      )
    Member(base, member_name) => {
      let base_handle = self.lower_function_member_value_base(
        base, function, scope,
      )
      self.apply_function_load_rule(
        function,
        self.lower_member_expression(function, base_handle, member_name.name()),
      )
    }
    Index(base, index) => {
      match
        self.lower_function_const_array_static_index_value(
          base, index, function,
        ) {
        Some(handle) => return handle
        None => ()
      }
      match
        self.lower_function_direct_addressable_value_binary_index(
          base, index, function, scope,
        ) {
        Some(handle) => return handle
        None => ()
      }
      match self.static_index_value_from_expr_node(index) {
        Some(_) => ()
        None => {
          self.predeclare_function_reference_roots_in_source_order(
            index, function, scope,
          )
          let base_handle = self.lower_function_index_value_base(
            base, function, scope,
          )
          let index_handle = self.lower_function_expression_node(
            index, function, scope,
          )
          return self.apply_function_load_rule(
            function,
            function.expressions.append(Access(base_handle, index_handle)),
          )
        }
      }
      let base_handle = self.lower_function_index_value_base(
        base, function, scope,
      )
      self.apply_function_load_rule(
        function,
        self.lower_function_static_or_dynamic_index(
          base_handle, index, function, scope,
        ),
      )
    }
    Call(callee, arguments) => {
      let arguments = wgsl_ir_call_arguments(arguments)
      self.lower_function_call_expression(
        callee, arguments, function, scope, expected_ty,
      )
    }
    Template(base, _) =>
      raise UnsupportedExpression(
        "standalone template expression: \{wgsl_ir_expr_node_shape(base)}",
      )
    PathAccess(_, _) =>
      raise UnsupportedExpression(
        "unresolved qualified path expression: \{wgsl_ir_expr_node_shape(node)}",
      )
    Sequence(items) =>
      raise UnsupportedExpression(
        "expression sequence with \{items.length()} item(s) outside argument context: \{wgsl_ir_expr_node_shape(node)}",
      )
  }
}

///|
fn WgslIrLowerer::lower_function_literal_node_with_expected(
  self : WgslIrLowerer,
  token : @ast.WgslExprToken,
  function : Function,
  scope : WgslIrFunctionScope,
  expected_ty : Handle?,
) -> Handle raise WgslIrLowerError {
  let text_key = wgsl_ir_source_local_const_literal_key(token, expected_ty)
  match scope.runtime_source_local_const_initializer_expressions.get(text_key) {
    Some(handle) => return handle
    None => ()
  }
  match scope.source_local_const_initializer_expressions.get(text_key) {
    Some(handle) => return handle
    None => ()
  }
  match self.source_local_const_literal_semantic_key(token, expected_ty) {
    Some(semantic_key) => {
      match
        scope.runtime_source_local_const_initializer_expressions.get(
          semantic_key,
        ) {
        Some(handle) => return handle
        None => ()
      }
      match scope.source_local_const_initializer_expressions.get(semantic_key) {
        Some(handle) => return handle
        None => ()
      }
    }
    None => ()
  }
  match self.source_local_const_literal_concrete_storage_type(expected_ty) {
    Some(concrete_ty) =>
      match
        self.source_local_const_literal_semantic_key(token, Some(concrete_ty)) {
        Some(semantic_key) => {
          match
            scope.runtime_source_local_const_initializer_expressions.get(
              semantic_key,
            ) {
            Some(handle) => return handle
            None => ()
          }
          match
            scope.source_local_const_initializer_expressions.get(semantic_key) {
            Some(handle) => return handle
            None => ()
          }
        }
        None => ()
      }
    None => ()
  }
  function.expressions.append(
    Literal(self.literal_from_token_with_expected(token, expected_ty)),
  )
}

///|
fn WgslIrLowerer::lower_function_fresh_literal_node_with_expected(
  self : WgslIrLowerer,
  token : @ast.WgslExprToken,
  function : Function,
  expected_ty : Handle?,
) -> Handle raise WgslIrLowerError {
  function.expressions.append(
    Literal(self.literal_from_token_with_expected(token, expected_ty)),
  )
}

///|
fn WgslIrLowerer::source_local_const_literal_concrete_storage_type(
  self : WgslIrLowerer,
  expected_ty : Handle?,
) -> Handle? {
  guard expected_ty is Some(ty) else { return None }
  match self.shader_module.types.get(ty) {
    Some({ inner: Scalar(scalar), .. })
    | Some({ inner: Vector(_, scalar), .. })
    | Some({ inner: Matrix(_, _, scalar), .. }) =>
      match self.concretize_abstract_storage_scalar(scalar) {
        Some(concrete) => Some(self.scalar_type_handle(concrete))
        None => None
      }
    _ => None
  }
}

///|
fn WgslIrLowerer::lower_function_const_array_static_index_value(
  self : WgslIrLowerer,
  base : @ast.WgslExprNode,
  index : @ast.WgslExprNode,
  function : Function,
) -> Handle? raise WgslIrLowerError {
  let base = match base.kind() {
    Group(inner) => inner
    _ => base
  }
  guard base.kind() is Identifier(name) else { return None }
  guard self.static_index_value_from_expr_node(index) is Some(static_index) else {
    return None
  }
  guard static_index >= 0 else { return None }
  guard self.ensure_constant_declaration_lowered(name.name())
    is Some(constant_handle) else {
    return None
  }
  guard self.shader_module.constants.items.get(constant_handle.index())
    is Some(constant) else {
    return None
  }
  guard self.shader_module.types.get(
      self.deref_pointer_type_handle(constant.ty),
    )
    is Some(type_) else {
    return None
  }
  match type_.inner {
    Array(_, Constant(count), _) => if static_index >= count { return None }
    _ => return None
  }
  guard self.shader_module.global_expressions.items.get(constant.init.index())
    is Some(init) else {
    return None
  }
  match init {
    Compose(_, components) =>
      match components.get(static_index) {
        Some(component) =>
          Some(
            self.clone_global_const_expression_to_function(component, function),
          )
        None => None
      }
    _ => None
  }
}

///|
fn WgslIrLowerer::clone_global_const_expression_to_function(
  self : WgslIrLowerer,
  handle : Handle,
  function : Function,
) -> Handle raise WgslIrLowerError {
  guard self.shader_module.global_expressions.items.get(handle.index())
    is Some(expression) else {
    raise UnsupportedExpression("missing global const expression")
  }
  match expression {
    Literal(literal) => function.expressions.append(Literal(literal))
    ZeroValue(ty) => function.expressions.append(ZeroValue(ty))
    Constant(constant) =>
      match self.shader_module.constants.items.get(constant.index()) {
        Some(nested) =>
          self.clone_global_const_expression_to_function(nested.init, function)
        None => function.expressions.append(Constant(constant))
      }
    Compose(ty, components) => {
      let cloned : Array[Handle] = []
      for component in components {
        cloned.push(
          self.clone_global_const_expression_to_function(component, function),
        )
      }
      function.expressions.append(Compose(ty, cloned))
    }
    Splat(size, inner) =>
      function.expressions.append(
        Splat(
          size,
          self.clone_global_const_expression_to_function(inner, function),
        ),
      )
    Unary(op, inner) =>
      function.expressions.append(
        Unary(
          op,
          self.clone_global_const_expression_to_function(inner, function),
        ),
      )
    Binary(op, left, right) => {
      let left = self.clone_global_const_expression_to_function(left, function)
      let right = self.clone_global_const_expression_to_function(
        right, function,
      )
      function.expressions.append(Binary(op, left, right))
    }
    Select(condition, accept, reject) => {
      let condition = self.clone_global_const_expression_to_function(
        condition, function,
      )
      let accept = self.clone_global_const_expression_to_function(
        accept, function,
      )
      let reject = self.clone_global_const_expression_to_function(
        reject, function,
      )
      function.expressions.append(Select(condition, accept, reject))
    }
    Bitcast(ty, inner) =>
      function.expressions.append(
        Bitcast(
          ty,
          self.clone_global_const_expression_to_function(inner, function),
        ),
      )
    Relational(relational, inner) =>
      function.expressions.append(
        Relational(
          relational,
          self.clone_global_const_expression_to_function(inner, function),
        ),
      )
    Math(math, a, b, c, d) => {
      let a = self.clone_global_const_expression_to_function(a, function)
      let b = match b {
        Some(handle) =>
          Some(self.clone_global_const_expression_to_function(handle, function))
        None => None
      }
      let c = match c {
        Some(handle) =>
          Some(self.clone_global_const_expression_to_function(handle, function))
        None => None
      }
      let d = match d {
        Some(handle) =>
          Some(self.clone_global_const_expression_to_function(handle, function))
        None => None
      }
      function.expressions.append(Math(math, a, b, c, d))
    }
    As(inner, kind, width) =>
      function.expressions.append(
        As(
          self.clone_global_const_expression_to_function(inner, function),
          kind,
          width,
        ),
      )
    AccessIndex(base, index) =>
      function.expressions.append(
        AccessIndex(
          self.clone_global_const_expression_to_function(base, function),
          index,
        ),
      )
    Access(base, index) => {
      let base = self.clone_global_const_expression_to_function(base, function)
      let index = self.clone_global_const_expression_to_function(
        index, function,
      )
      function.expressions.append(Access(base, index))
    }
    Swizzle(size, base, components) =>
      function.expressions.append(
        Swizzle(
          size,
          self.clone_global_const_expression_to_function(base, function),
          components,
        ),
      )
    Component(base, component) =>
      function.expressions.append(
        Component(
          self.clone_global_const_expression_to_function(base, function),
          component,
        ),
      )
    _ =>
      raise UnsupportedExpression(
        "global const expression is not function-cloneable",
      )
  }
}
