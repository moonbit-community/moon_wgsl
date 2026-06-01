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
    raise WgslIrLowerError::UnsupportedExpression("empty function expression")
  }
  self.lower_function_expression_node_with_expected(
    root, function, scope, expected_ty,
  ) catch {
    UnsupportedExpression(message) =>
      raise WgslIrLowerError::UnsupportedExpression(
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
    raise WgslIrLowerError::UnsupportedExpression("empty lvalue")
  }
  self.lower_function_lvalue_node(root, function, scope)
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
        Some(_) =>
          raise WgslIrLowerError::UnsupportedExpression(
            "local const is not assignable",
          )
        None => ()
      }
      match scope.locals.get(name.name()) {
        Some(handle) => {
          match function.local_variables.items.get(handle.index()) {
            Some(local_var) =>
              if local_var.kind == Let {
                raise WgslIrLowerError::UnsupportedExpression(
                  "local let is not assignable",
                )
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
            raise WgslIrLowerError::UnsupportedExpression(
              "function argument is not assignable",
            )
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
        None => raise WgslIrLowerError::UnknownIdentifier(name.name())
      }
    }
    Group(inner) => self.lower_function_lvalue_node(inner, function, scope)
    Unary(op, expr) =>
      if op == @ast.WgslExprOperator::Multiply {
        self.lower_function_expression_node(expr, function, scope)
      } else {
        raise WgslIrLowerError::UnsupportedExpression(
          "unsupported lvalue shape",
        )
      }
    Member(base, member_name) => {
      let base_handle = self.lower_function_member_lvalue_base(
        base, function, scope,
      )
      function.expressions.append(
        Expression::AccessIndex(
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
        self.lower_function_dynamic_member_index_access(
          base, index, function, scope,
        ) {
        Some(handle) => return handle
        None => ()
      }
      let base_handle = self.lower_function_lvalue_node(base, function, scope)
      self.lower_function_static_or_dynamic_index(
        base_handle, index, function, scope,
      )
    }
    _ =>
      raise WgslIrLowerError::UnsupportedExpression("unsupported lvalue shape")
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
    Unary(op, expr) =>
      if op == @ast.WgslExprOperator::Multiply {
        Some(expr)
      } else {
        None
      }
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
      function.expressions.append(
        Expression::Literal(
          self.literal_from_token_with_expected(token, expected_ty),
        ),
      )
    ShaderDefTemplate(text) =>
      raise WgslIrLowerError::UnsupportedExpression(
        "shader-def template expression requires preprocessing: \{text}",
      )
    Identifier(name) =>
      self.lower_identifier_expression(name.name(), function, scope)
    PostfixUpdate(_, _) =>
      raise WgslIrLowerError::UnsupportedExpression(
        "update expression outside statement context",
      )
    Assignment(_, _, _) =>
      raise WgslIrLowerError::UnsupportedExpression(
        "assignment expression outside statement context",
      )
    Unary(op, expr) =>
      if op == @ast.WgslExprOperator::BitAnd {
        let target = self.lower_function_lvalue_node(expr, function, scope)
        function.expressions.append(
          Expression::AddressOf(
            self.pointer_type_for_lvalue(function, target),
            target,
          ),
        )
      } else if op == @ast.WgslExprOperator::Multiply {
        function.expressions.append(
          Expression::Load(
            self.lower_function_expression_node(expr, function, scope),
          ),
        )
      } else if op == @ast.WgslExprOperator::Subtract {
        match expr.kind() {
          Literal(token) =>
            match
              self.negated_literal_from_token_with_expected(token, expected_ty) {
              Some(literal) =>
                function.expressions.append(Expression::Literal(literal))
              None =>
                function.expressions.append(
                  Expression::Unary(
                    wgsl_ir_unary_operator(op),
                    self.lower_function_expression_node(expr, function, scope),
                  ),
                )
            }
          _ =>
            function.expressions.append(
              Expression::Unary(
                wgsl_ir_unary_operator(op),
                self.lower_function_expression_node(expr, function, scope),
              ),
            )
        }
      } else {
        function.expressions.append(
          Expression::Unary(
            wgsl_ir_unary_operator(op),
            self.lower_function_expression_node(expr, function, scope),
          ),
        )
      }
    Binary(op, left, right) => {
      match
        self.lower_function_binary_chain_with_parent_argument_after_member_root(
          op, left, right, function, scope,
        ) {
        Some(handle) => return handle
        None => ()
      }
      let member_bases_lower_in_source_order = wgsl_ir_binary_predeclares_sibling_member_roots(
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
        self.predeclare_function_member_base_expressions(left, function, scope)
        self.predeclare_function_argument_value(right, function, scope)
      }
      let (left_handle, right_handle) = if !member_bases_lower_in_source_order &&
        wgsl_ir_binary_right_subtree_has_higher_precedence(op, right) {
        let (right_op, right_left, right_right) = self.lower_binary_expression_children(
          right, function, scope,
        )
        let left_handle = self.lower_function_expression_node(
          left, function, scope,
        )
        let right_binary_op = wgsl_ir_binary_operator(right_op)
        let (right_left, right_right) = self.normalize_function_binary_operands(
          function, right_binary_op, right_left, right_right,
        )
        let right_handle = function.expressions.append(
          Expression::Binary(right_binary_op, right_left, right_right),
        )
        (left_handle, right_handle)
      } else if self.binary_expression_lowers_right_before_left(
          left, right, function, scope,
        ) {
        let right_handle = self.lower_function_expression_node(
          right, function, scope,
        )
        let left_handle = self.lower_function_expression_node(
          left, function, scope,
        )
        (left_handle, right_handle)
      } else {
        let left_handle = self.lower_function_expression_node(
          left, function, scope,
        )
        let right_handle = self.lower_function_expression_node(
          right, function, scope,
        )
        (left_handle, right_handle)
      }
      let binary_op = wgsl_ir_binary_operator(op)
      let (left_handle, right_handle) = self.normalize_function_binary_operands(
        function, binary_op, left_handle, right_handle,
      )
      let handle = function.expressions.append(
        Expression::Binary(binary_op, left_handle, right_handle),
      )
      handle
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
    Call(callee, arguments) =>
      self.lower_function_call_expression(
        callee, arguments, function, scope, expected_ty,
      )
    Template(base, _) =>
      raise WgslIrLowerError::UnsupportedExpression(
        "standalone template expression: \{wgsl_ir_expr_node_shape(base)}",
      )
    PathAccess(_, _) =>
      raise WgslIrLowerError::UnsupportedExpression(
        "unresolved qualified path expression: \{wgsl_ir_expr_node_shape(node)}",
      )
    Sequence(items) =>
      raise WgslIrLowerError::UnsupportedExpression(
        "expression sequence with \{items.length()} item(s) outside argument context: \{wgsl_ir_expr_node_shape(node)}",
      )
  }
}

///|
fn WgslIrLowerer::lower_function_binary_chain_with_parent_argument_after_member_root(
  self : WgslIrLowerer,
  op : @ast.WgslExprOperator,
  left : @ast.WgslExprNode,
  right : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle? raise WgslIrLowerError {
  guard wgsl_ir_expr_node_is_function_argument_value(right, scope) else {
    return None
  }
  guard left.kind() is Binary(left_op, left_left, left_right) else {
    return None
  }
  guard wgsl_ir_expr_node_is_direct_access_chain(left_right) else {
    return None
  }
  let left_left_handle = self.lower_function_expression_node(
    left_left, function, scope,
  )
  self.predeclare_function_member_base_expressions(left_right, function, scope)
  self.predeclare_function_argument_value(right, function, scope)
  let left_right_handle = self.lower_function_expression_node(
    left_right, function, scope,
  )
  let left_binary_op = wgsl_ir_binary_operator(left_op)
  let (left_left_handle, left_right_handle) = self.normalize_function_binary_operands(
    function, left_binary_op, left_left_handle, left_right_handle,
  )
  let left_handle = function.expressions.append(
    Expression::Binary(left_binary_op, left_left_handle, left_right_handle),
  )
  let right_handle = self.lower_function_expression_node(right, function, scope)
  let binary_op = wgsl_ir_binary_operator(op)
  let (left_handle, right_handle) = self.normalize_function_binary_operands(
    function, binary_op, left_handle, right_handle,
  )
  Some(
    function.expressions.append(
      Expression::Binary(binary_op, left_handle, right_handle),
    ),
  )
}

///|
fn WgslIrLowerer::predeclare_function_argument_value(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Unit raise WgslIrLowerError {
  ignore(self)
  match node.kind() {
    Identifier(name) =>
      match scope.arguments.get(name.name()) {
        Some(index) =>
          ignore(scope.argument_expression(name.name(), index, function))
        None => ()
      }
    Group(inner) =>
      self.predeclare_function_argument_value(inner, function, scope)
    _ => ()
  }
}

///|
fn WgslIrLowerer::predeclare_function_member_base_expressions(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Unit raise WgslIrLowerError {
  match node.kind() {
    Member(base, _) =>
      self.predeclare_function_member_root_expression(base, function, scope)
    Group(inner) =>
      self.predeclare_function_member_base_expressions(inner, function, scope)
    Unary(_, expr) =>
      self.predeclare_function_member_base_expressions(expr, function, scope)
    Binary(_, left, right) => {
      self.predeclare_function_member_base_expressions(left, function, scope)
      self.predeclare_function_member_base_expressions(right, function, scope)
    }
    Call(_, arguments) | Sequence(arguments) =>
      for argument in arguments {
        self.predeclare_function_member_base_expressions(
          argument, function, scope,
        )
      }
    Index(base, index) => {
      self.predeclare_function_member_base_expressions(base, function, scope)
      self.predeclare_function_member_base_expressions(index, function, scope)
    }
    Template(base, _) =>
      self.predeclare_function_member_base_expressions(base, function, scope)
    _ => ()
  }
}

///|
fn WgslIrLowerer::predeclare_function_member_root_expression(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Unit raise WgslIrLowerError {
  match node.kind() {
    Identifier(name) =>
      self.predeclare_identifier_named_expression(name.name(), function, scope)
    Group(inner) =>
      self.predeclare_function_member_root_expression(inner, function, scope)
    Member(base, _) =>
      self.predeclare_function_member_root_expression(base, function, scope)
    Index(base, _) =>
      self.predeclare_function_member_root_expression(base, function, scope)
    _ => ()
  }
}

///|
fn WgslIrLowerer::predeclare_identifier_named_expression(
  self : WgslIrLowerer,
  name : String,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Unit raise WgslIrLowerError {
  match scope.arguments.get(name) {
    Some(index) => {
      ignore(scope.argument_expression(name, index, function))
      return
    }
    None => ()
  }
  match scope.local_constants.get(name) {
    Some(_) => {
      ignore(self.lower_identifier_expression(name, function, scope))
      return
    }
    None => ()
  }
  match self.global_names.get(name) {
    Some(handle) => {
      ignore(scope.predeclare_global_pointer_expression(name, handle, function))
      return
    }
    None => ()
  }
}

///|
fn WgslIrLowerer::lower_binary_expression_children(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> (@ast.WgslExprOperator, Handle, Handle) raise WgslIrLowerError {
  match node.kind() {
    Binary(op, left, right) => {
      let (left_handle, right_handle) = if self.binary_expression_lowers_right_before_left(
          left, right, function, scope,
        ) {
        let right_handle = self.lower_function_expression_node(
          right, function, scope,
        )
        let left_handle = self.lower_function_expression_node(
          left, function, scope,
        )
        (left_handle, right_handle)
      } else {
        let left_handle = self.lower_function_expression_node(
          left, function, scope,
        )
        let right_handle = self.lower_function_expression_node(
          right, function, scope,
        )
        (left_handle, right_handle)
      }
      (op, left_handle, right_handle)
    }
    _ =>
      raise WgslIrLowerError::UnsupportedExpression(
        "expected binary expression subtree",
      )
  }
}

///|
fn WgslIrLowerer::binary_expression_lowers_right_before_left(
  self : WgslIrLowerer,
  left : @ast.WgslExprNode,
  right : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Bool {
  if wgsl_ir_expr_node_is_literal_like(left) {
    return self.expression_node_contains_naga_reference_value(
      right, function, scope,
    )
  }
  self.expression_node_is_mutable_local_value(left, function, scope) &&
  wgsl_ir_expr_node_is_function_argument_value(right, scope)
}

///|
fn wgsl_ir_binary_right_subtree_has_higher_precedence(
  op : @ast.WgslExprOperator,
  right : @ast.WgslExprNode,
) -> Bool {
  match right.kind() {
    Binary(right_op, _, _) =>
      right_op.binary_precedence() > op.binary_precedence()
    _ => false
  }
}

///|
fn wgsl_ir_binary_predeclares_sibling_member_roots(
  left : @ast.WgslExprNode,
  right : @ast.WgslExprNode,
) -> Bool {
  wgsl_ir_expr_node_is_direct_access_chain(left) &&
  wgsl_ir_expr_node_contains_member_access(right)
}

///|
fn wgsl_ir_expr_node_contains_member_access(node : @ast.WgslExprNode) -> Bool {
  match node.kind() {
    Member(_, _) => true
    Group(inner) => wgsl_ir_expr_node_contains_member_access(inner)
    Unary(_, expr) => wgsl_ir_expr_node_contains_member_access(expr)
    Binary(_, left, right) =>
      wgsl_ir_expr_node_contains_member_access(left) ||
      wgsl_ir_expr_node_contains_member_access(right)
    Call(_, arguments) | Sequence(arguments) =>
      arguments.any(fn(argument) {
        wgsl_ir_expr_node_contains_member_access(argument)
      })
    Index(base, index) =>
      wgsl_ir_expr_node_contains_member_access(base) ||
      wgsl_ir_expr_node_contains_member_access(index)
    Template(base, _) => wgsl_ir_expr_node_contains_member_access(base)
    _ => false
  }
}

///|
fn wgsl_ir_expr_node_is_direct_access_chain(node : @ast.WgslExprNode) -> Bool {
  match node.kind() {
    Group(inner) => wgsl_ir_expr_node_is_direct_access_chain(inner)
    Member(_, _) | Index(_, _) => true
    _ => false
  }
}

///|
fn WgslIrLowerer::expression_node_contains_naga_reference_value(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Bool {
  if self.expression_node_is_mutable_local_value(node, function, scope) ||
    self.expression_node_is_global_reference_value(node) {
    return true
  }
  match node.kind() {
    Group(inner) | Unary(_, inner) | PostfixUpdate(_, inner) =>
      self.expression_node_contains_naga_reference_value(inner, function, scope)
    Identifier(name) => scope.local_constants.contains(name.name())
    Binary(_, left, right) | Assignment(_, left, right) | Index(left, right) =>
      self.expression_node_contains_naga_reference_value(left, function, scope) ||
      self.expression_node_contains_naga_reference_value(right, function, scope)
    Member(base, _) | PathAccess(base, _) | Template(base, _) =>
      self.expression_node_contains_naga_reference_value(base, function, scope)
    Call(callee, arguments) =>
      self.expression_node_contains_naga_reference_value(
        callee, function, scope,
      ) ||
      arguments.any(fn(argument) {
        self.expression_node_contains_naga_reference_value(
          argument, function, scope,
        )
      })
    Sequence(items) =>
      items.any(fn(item) {
        self.expression_node_contains_naga_reference_value(
          item, function, scope,
        )
      })
    Literal(_) | ShaderDefTemplate(_) => false
  }
}

///|
fn WgslIrLowerer::expression_node_is_global_reference_value(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
) -> Bool {
  match node.kind() {
    Group(inner) => self.expression_node_is_global_reference_value(inner)
    Identifier(name) => self.global_names.get(name.name()) != None
    _ => false
  }
}

///|
fn wgsl_ir_expr_node_is_literal_like(node : @ast.WgslExprNode) -> Bool {
  match node.kind() {
    Literal(_) => true
    Group(inner) => wgsl_ir_expr_node_is_literal_like(inner)
    _ => false
  }
}

///|
fn WgslIrLowerer::expression_node_is_mutable_local_value(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Bool {
  match node.kind() {
    Group(inner) =>
      self.expression_node_is_mutable_local_value(inner, function, scope)
    Identifier(name) =>
      match scope.locals.get(name.name()) {
        Some(handle) =>
          match function.local_variables.items.get(handle.index()) {
            Some(local_var) =>
              local_var.kind == Var &&
              !self.local_variable_is_handle_value(function, handle)
            None => false
          }
        None => false
      }
    _ => false
  }
}

///|
fn wgsl_ir_expr_node_is_function_argument_value(
  node : @ast.WgslExprNode,
  scope : WgslIrFunctionScope,
) -> Bool {
  match node.kind() {
    Group(inner) => wgsl_ir_expr_node_is_function_argument_value(inner, scope)
    Identifier(name) => scope.arguments.contains(name.name())
    _ => false
  }
}

///|
fn WgslIrLowerer::normalize_function_binary_operands(
  self : WgslIrLowerer,
  function : Function,
  op : BinaryOperator,
  left : Handle,
  right : Handle,
) -> (Handle, Handle) raise WgslIrLowerError {
  guard self.function_expression_type(function, left) is Some(left_ty) else {
    return (left, right)
  }
  guard self.function_expression_type(function, right) is Some(right_ty) else {
    return (left, right)
  }
  self.contextualize_function_binary_operand_pair(
    function, op, left, left_ty, right, right_ty,
  )
  guard wgsl_ir_binary_operator_requires_vector_splat(op) else {
    return (left, right)
  }
  match self.vector_size_from_type(left_ty) {
    Some(size) if self.type_is_scalar(right_ty) =>
      (left, function.expressions.append(Expression::Splat(size, right)))
    _ =>
      match self.vector_size_from_type(right_ty) {
        Some(size) if self.type_is_scalar(left_ty) =>
          (function.expressions.append(Expression::Splat(size, left)), right)
        _ => (left, right)
      }
  }
}

///|
fn WgslIrLowerer::contextualize_function_binary_operand_pair(
  self : WgslIrLowerer,
  function : Function,
  op : BinaryOperator,
  left : Handle,
  left_ty : Handle,
  right : Handle,
  right_ty : Handle,
) -> Unit raise WgslIrLowerError {
  if wgsl_ir_binary_operator_has_asymmetric_integer_context(op) {
    return
  }
  if op == BinaryOperator::Multiply {
    match self.matrix_multiply_operand_context(left_ty, right_ty) {
      Some((left_expected, right_expected)) => {
        match left_expected {
          Some(ty) =>
            self.contextualize_function_expression_for_type(function, left, ty)
          None => ()
        }
        match right_expected {
          Some(ty) =>
            self.contextualize_function_expression_for_type(function, right, ty)
          None => ()
        }
      }
      None => ()
    }
  }
  match self.contextualized_constructor_type(right_ty, left_ty) {
    Some(_) =>
      self.contextualize_function_expression_for_type(function, right, left_ty)
    None => ()
  }
  match self.contextualized_constructor_type(left_ty, right_ty) {
    Some(_) =>
      self.contextualize_function_expression_for_type(function, left, right_ty)
    None => ()
  }
}

///|
fn wgsl_ir_binary_operator_has_asymmetric_integer_context(
  op : BinaryOperator,
) -> Bool {
  match op {
    ShiftLeft | ShiftRight => true
    _ => false
  }
}

///|
fn WgslIrLowerer::lower_function_call_expression(
  self : WgslIrLowerer,
  callee : @ast.WgslExprNode,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
  expected_ty : Handle?,
) -> Handle raise WgslIrLowerError {
  let arguments = wgsl_ir_call_arguments(arguments)
  match
    self.lower_templated_builtin_function_call(
      callee, arguments, function, scope,
    ) {
    Some(handle) => handle
    None =>
      match self.lower_bitcast_callee_type(callee) {
        Some(ty) =>
          self.lower_function_bitcast_call(ty, arguments, function, scope)
        None =>
          match callee.kind() {
            Identifier(name) =>
              self.lower_named_function_call_expression(
                name.name(),
                arguments,
                function,
                scope,
                expected_ty,
              )
            _ =>
              match self.lower_templated_callee_type(callee) {
                Some(ty) =>
                  self.lower_function_constructor_expression_from_handles(
                    ty,
                    self.lower_function_constructor_arguments(
                      ty, arguments, function, scope,
                    ),
                    function,
                  )
                None =>
                  raise WgslIrLowerError::UnsupportedExpression(
                    "non-identifier call expression: \{wgsl_ir_expr_node_shape(callee)}",
                  )
              }
          }
      }
  }
}

///|
fn WgslIrLowerer::lower_named_function_call_expression(
  self : WgslIrLowerer,
  name : String,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
  expected_ty : Handle?,
) -> Handle raise WgslIrLowerError {
  match self.function_names.get(name) {
    Some(handle) =>
      function.expressions.append(
        Expression::FunctionCall(
          handle,
          self.lower_user_function_call_arguments(
            handle, arguments, function, scope,
          ),
        ),
      )
    None =>
      match wgsl_ir_math_function_from_name(name) {
        Some(math_function) =>
          self.lower_function_math_call(
            math_function, arguments, function, scope,
          )
        None =>
          match wgsl_ir_derivative_function_from_name(name) {
            Some((axis, control)) =>
              self.lower_function_derivative_call(
                axis, control, arguments, function, scope,
              )
            None =>
              match wgsl_ir_relational_function_from_name(name) {
                Some(relational_function) =>
                  self.lower_function_relational_call(
                    relational_function, arguments, function, scope,
                  )
                None =>
                  self.lower_unclassified_named_function_call_expression(
                    name, arguments, function, scope, expected_ty,
                  )
              }
          }
      }
  }
}

///|
fn WgslIrLowerer::lower_unclassified_named_function_call_expression(
  self : WgslIrLowerer,
  name : String,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
  expected_ty : Handle?,
) -> Handle raise WgslIrLowerError {
  if name == "select" {
    self.lower_function_select_call(arguments, function, scope)
  } else if wgsl_ir_barrier_builtin_from_name(name) is Some(_) {
    raise wgsl_ir_barrier_value_error(name)
  } else {
    match wgsl_ir_atomic_function_from_name(name) {
      Some(atomic_function) =>
        self.lower_function_atomic_call(
          atomic_function, arguments, function, scope,
        )
      None =>
        match
          self.lower_texture_expression_call(name, arguments, function, scope) {
          Some(handle) => handle
          None =>
            match
              self.lower_ray_query_expression_call(
                name, arguments, function, scope,
              ) {
              Some(handle) => handle
              None =>
                match wgsl_ir_subgroup_function_from_name(name) {
                  Some(subgroup_function) =>
                    self.lower_function_subgroup_call(
                      subgroup_function, arguments, function, scope,
                    )
                  None =>
                    if name == "arrayLength" {
                      self.lower_function_array_length_call(
                        arguments, function, scope,
                      )
                    } else if name == "coopMultiplyAdd" {
                      self.lower_function_cooperative_multiply_add_call(
                        arguments, function, scope,
                      )
                    } else if name == "workgroupUniformLoad" {
                      self.lower_function_workgroup_uniform_load_call(
                        arguments, function, scope,
                      )
                    } else if name == "array" {
                      self.lower_function_array_constructor_call(
                        expected_ty, arguments, function, scope,
                      )
                    } else {
                      self.lower_function_constructor_call(
                        name, arguments, function, scope, expected_ty,
                      )
                    }
                }
            }
        }
    }
  }
}

///|
fn wgsl_ir_subgroup_function_from_name(name : String) -> SubgroupFunction? {
  match name {
    "subgroupBallot" => Some(Ballot)
    "subgroupAll" => Some(All)
    "subgroupAny" => Some(Any)
    "subgroupAdd" => Some(Add)
    "subgroupMul" => Some(Mul)
    "subgroupMax" => Some(Max)
    "subgroupMin" => Some(Min)
    "subgroupAnd" => Some(And)
    "subgroupOr" => Some(Or)
    "subgroupXor" => Some(Xor)
    "subgroupExclusiveAdd" => Some(ExclusiveAdd)
    "subgroupExclusiveMul" => Some(ExclusiveMul)
    "subgroupInclusiveAdd" => Some(InclusiveAdd)
    "subgroupInclusiveMul" => Some(InclusiveMul)
    "subgroupBroadcastFirst" => Some(BroadcastFirst)
    "subgroupBroadcast" => Some(Broadcast)
    "subgroupShuffle" => Some(Shuffle)
    "subgroupShuffleDown" => Some(ShuffleDown)
    "subgroupShuffleUp" => Some(ShuffleUp)
    "subgroupShuffleXor" => Some(ShuffleXor)
    "quadBroadcast" => Some(QuadBroadcast)
    "quadSwapX" => Some(QuadSwapX)
    "quadSwapY" => Some(QuadSwapY)
    "quadSwapDiagonal" => Some(QuadSwapDiagonal)
    _ => None
  }
}

///|
fn wgsl_ir_subgroup_function_name(function : SubgroupFunction) -> String {
  match function {
    Ballot => "subgroupBallot"
    All => "subgroupAll"
    Any => "subgroupAny"
    Add => "subgroupAdd"
    Mul => "subgroupMul"
    Max => "subgroupMax"
    Min => "subgroupMin"
    And => "subgroupAnd"
    Or => "subgroupOr"
    Xor => "subgroupXor"
    ExclusiveAdd => "subgroupExclusiveAdd"
    ExclusiveMul => "subgroupExclusiveMul"
    InclusiveAdd => "subgroupInclusiveAdd"
    InclusiveMul => "subgroupInclusiveMul"
    BroadcastFirst => "subgroupBroadcastFirst"
    Broadcast => "subgroupBroadcast"
    Shuffle => "subgroupShuffle"
    ShuffleDown => "subgroupShuffleDown"
    ShuffleUp => "subgroupShuffleUp"
    ShuffleXor => "subgroupShuffleXor"
    QuadBroadcast => "quadBroadcast"
    QuadSwapX => "quadSwapX"
    QuadSwapY => "quadSwapY"
    QuadSwapDiagonal => "quadSwapDiagonal"
  }
}

///|
fn WgslIrLowerer::lower_function_subgroup_call(
  self : WgslIrLowerer,
  subgroup_function : SubgroupFunction,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  let expected = match subgroup_function {
    Ballot
    | All
    | Any
    | Add
    | Mul
    | Max
    | Min
    | And
    | Or
    | Xor
    | ExclusiveAdd
    | ExclusiveMul
    | InclusiveAdd
    | InclusiveMul
    | BroadcastFirst
    | QuadSwapX
    | QuadSwapY
    | QuadSwapDiagonal => 1
    Broadcast
    | Shuffle
    | ShuffleDown
    | ShuffleUp
    | ShuffleXor
    | QuadBroadcast => 2
  }
  guard arguments.length() == expected else {
    raise WgslIrLowerError::UnsupportedExpression(
      "\{wgsl_ir_subgroup_function_name(subgroup_function)} expects \{expected} argument(s)",
    )
  }
  let lowered = self.lower_function_expression_arguments(
    arguments, function, scope,
  )
  function.expressions.append(
    Expression::SubgroupCall(subgroup_function, lowered),
  )
}

///|
fn WgslIrLowerer::lower_function_constructor_call(
  self : WgslIrLowerer,
  name : String,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
  expected_ty : Handle?,
) -> Handle raise WgslIrLowerError {
  let lowered_arguments = self.lower_function_expression_arguments(
    arguments, function, scope,
  )
  let ty = match self.expected_constructor_type(name, expected_ty) {
    Some(ty) => ty
    None =>
      self.lower_untemplated_constructor_type_from_handles(
        name, arguments, lowered_arguments, function,
      )
  }
  match wgsl_ir_vector_size_from_constructor_name(name) {
    Some(_) =>
      match
        self.identity_vector_constructor_argument(
          ty, lowered_arguments, function,
        ) {
        Some(handle) => return handle
        None => ()
      }
    None => ()
  }
  let handle = self.lower_function_constructor_expression_from_handles(
    ty, lowered_arguments, function,
  )
  match self.contextualized_component_constructor_type(name, ty, expected_ty) {
    Some(target_ty) =>
      self.contextualize_function_constructor_expression(
        function, handle, ty, lowered_arguments, target_ty,
      )
    None => ()
  }
  handle
}

///|
fn WgslIrLowerer::lower_function_derivative_call(
  self : WgslIrLowerer,
  axis : DerivativeAxis,
  control : DerivativeControl,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments is [expr] else {
    raise WgslIrLowerError::UnsupportedExpression(
      "derivative call expects one argument",
    )
  }
  let argument = self.lower_function_expression_node(expr, function, scope)
  function.expressions.append(
    Expression::Derivative(
      axis,
      control,
      self.apply_function_load_rule(function, argument),
    ),
  )
}

///|
fn WgslIrLowerer::lower_identifier_expression(
  self : WgslIrLowerer,
  name : String,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  match scope.local_constants.get(name) {
    Some({ value: LazyConstant(local_constant) }) => {
      let handle = match local_constant.normalized {
        Some(normalized) =>
          function.expressions.append_with_origin(
            normalized.expression,
            normalized.origin,
          )
        None =>
          self.lower_function_expression_ref_with_expected(
            local_constant.expr_ref,
            function,
            scope,
            local_constant.explicit_ty,
          )
      }
      match scope.local_constants.get(name) {
        Some(cell) => cell.value = ExpressionAlias(handle)
        None => ()
      }
      return handle
    }
    Some({ value: ExpressionAlias(handle) }) => return handle
    None => ()
  }
  match scope.locals.get(name) {
    Some(handle) =>
      match function.local_variables.items.get(handle.index()) {
        Some(local_var) =>
          if local_var.kind == Let ||
            self.local_variable_is_handle_value(function, handle) {
            return scope.local_pointer_expression(name, handle, function)
          } else {
            return function.expressions.append(
              Expression::Load(
                scope.local_pointer_expression(name, handle, function),
              ),
            )
          }
        None => raise WgslIrLowerError::UnknownIdentifier(name)
      }
    None => ()
  }
  match scope.arguments.get(name) {
    Some(index) => return scope.argument_expression(name, index, function)
    None => ()
  }
  match self.ensure_constant_declaration_lowered(name) {
    Some(handle) =>
      return function.expressions.append(Expression::Constant(handle))
    None => ()
  }
  match self.ensure_override_declaration_predeclared(name) {
    Some(handle) =>
      return function.expressions.append(Expression::Override(handle))
    None => ()
  }
  match self.global_names.get(name) {
    Some(handle) =>
      if self.global_variable_is_handle_value(handle) {
        scope.global_pointer_expression(name, handle, function, false)
      } else {
        function.expressions.append(
          Expression::Load(
            scope.global_pointer_expression(
              name,
              handle,
              function,
              self.global_variable_reuses_pointer_expression(handle),
            ),
          ),
        )
      }
    None =>
      match wgsl_ir_predeclared_u32_constant_literal(name) {
        Some(literal) =>
          function.expressions.append(Expression::Literal(literal))
        None => raise WgslIrLowerError::UnknownIdentifier(name)
      }
  }
}

///|
fn WgslIrLowerer::local_variable_is_handle_value(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle,
) -> Bool {
  match function.local_variables.items.get(handle.index()) {
    Some(local_var) =>
      match self.shader_module.types.get(local_var.ty) {
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
fn WgslIrLowerer::global_variable_is_handle_value(
  self : WgslIrLowerer,
  handle : Handle,
) -> Bool {
  match self.shader_module.global_variables.items.get(handle.index()) {
    Some(global) => self.type_is_global_handle_value(global.ty)
    None => false
  }
}

///|
fn WgslIrLowerer::type_is_global_handle_value(
  self : WgslIrLowerer,
  handle : Handle,
) -> Bool {
  match self.shader_module.types.get(handle) {
    Some(type_) =>
      match type_.inner {
        Image(_, _, _) | Sampler(_) | AccelerationStructure(_) | RayQuery(_) =>
          true
        BindingArray(element, _) => self.type_is_global_handle_value(element)
        _ => false
      }
    None => false
  }
}

///|
fn WgslIrLowerer::global_variable_reuses_pointer_expression(
  self : WgslIrLowerer,
  handle : Handle,
) -> Bool {
  match self.shader_module.global_variables.items.get(handle.index()) {
    Some(_) => false
    None => false
  }
}

///|
fn WgslIrLowerer::lower_function_index_value_base(
  self : WgslIrLowerer,
  base : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  if self.function_access_base_is_addressable(base, function, scope) {
    self.lower_function_access_base_pointer_node(base, function, scope)
  } else {
    self.lower_function_expression_node(base, function, scope)
  }
}

///|
fn WgslIrLowerer::lower_function_access_base_pointer_node(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  match node.kind() {
    Identifier(name) => {
      match scope.local_constants.get(name.name()) {
        Some(_) =>
          raise WgslIrLowerError::UnsupportedExpression(
            "local const is not addressable",
          )
        None => ()
      }
      match scope.locals.get(name.name()) {
        Some(handle) =>
          match function.local_variables.items.get(handle.index()) {
            Some(local_var) =>
              if local_var.kind == Var ||
                self.local_variable_is_handle_value(function, handle) {
                return scope.local_pointer_expression(
                  name.name(),
                  handle,
                  function,
                )
              } else {
                raise WgslIrLowerError::UnsupportedExpression(
                  "local let is not addressable",
                )
              }
            None => raise WgslIrLowerError::UnknownIdentifier(name.name())
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
            raise WgslIrLowerError::UnsupportedExpression(
              "function argument is not addressable",
            )
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
        None => raise WgslIrLowerError::UnknownIdentifier(name.name())
      }
    }
    Group(inner) =>
      self.lower_function_access_base_pointer_node(inner, function, scope)
    Unary(op, expr) =>
      if op == @ast.WgslExprOperator::Multiply {
        self.lower_function_expression_node(expr, function, scope)
      } else {
        raise WgslIrLowerError::UnsupportedExpression(
          "unsupported addressable access base",
        )
      }
    Member(base, member_name) => {
      let base_handle = self.lower_function_access_base_pointer_node(
        base, function, scope,
      )
      function.expressions.append(
        Expression::AccessIndex(
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
        self.lower_function_dynamic_member_index_access(
          base, index, function, scope,
        ) {
        Some(handle) => return handle
        None => ()
      }
      let base_handle = self.lower_function_access_base_pointer_node(
        base, function, scope,
      )
      self.lower_function_static_or_dynamic_index(
        base_handle, index, function, scope,
      )
    }
    _ =>
      raise WgslIrLowerError::UnsupportedExpression(
        "unsupported addressable access base",
      )
  }
}

///|
fn WgslIrLowerer::lower_function_dynamic_member_index_access(
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
  match wgsl_ir_static_member_access_chain(base) {
    Some((root, members)) =>
      if members.length() == 0 {
        None
      } else {
        let root_handle = self.lower_function_access_base_pointer_node(
          root, function, scope,
        )
        let index_handle = self.lower_function_expression_node(
          index, function, scope,
        )
        let base_handle = self.lower_function_static_member_access_chain(
          root_handle, members, function,
        )
        Some(
          function.expressions.append(
            Expression::Access(base_handle, index_handle),
          ),
        )
      }
    None => None
  }
}

///|
fn WgslIrLowerer::lower_function_static_member_access_chain(
  self : WgslIrLowerer,
  root_handle : Handle,
  members : Array[String],
  function : Function,
) -> Handle raise WgslIrLowerError {
  let mut base_handle = root_handle
  for field_name in members {
    base_handle = function.expressions.append(
      Expression::AccessIndex(
        base_handle,
        self.member_index_for_expression(function, base_handle, field_name),
      ),
    )
  }
  base_handle
}

///|
fn wgsl_ir_static_member_access_chain(
  node : @ast.WgslExprNode,
) -> (@ast.WgslExprNode, Array[String])? {
  match node.kind() {
    Group(inner) => wgsl_ir_static_member_access_chain(inner)
    Member(base, field_name) =>
      match wgsl_ir_static_member_access_chain(base) {
        Some((root, members)) => {
          members.push(field_name.name())
          Some((root, members))
        }
        None => None
      }
    Index(_, _) => None
    _ => Some((node, []))
  }
}

///|
fn WgslIrLowerer::function_access_base_is_addressable(
  self : WgslIrLowerer,
  base : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Bool {
  match base.kind() {
    Group(inner) =>
      self.function_access_base_is_addressable(inner, function, scope)
    Identifier(name) =>
      match scope.local_constants.get(name.name()) {
        Some(_) => false
        None =>
          match scope.locals.get(name.name()) {
            Some(handle) =>
              match function.local_variables.items.get(handle.index()) {
                Some(local_var) =>
                  local_var.kind == Var ||
                  self.local_variable_is_handle_value(function, handle)
                None => false
              }
            None =>
              match scope.arguments.get(name.name()) {
                Some(index) =>
                  self.function_argument_is_pointer(function, index)
                None => self.global_names.get(name.name()) is Some(_)
              }
          }
      }
    Index(inner, _) | Member(inner, _) =>
      self.function_access_base_is_addressable(inner, function, scope)
    Unary(op, _) => op == @ast.WgslExprOperator::Multiply
    _ => false
  }
}

///|
fn WgslIrLowerer::lower_ray_query_expression_call(
  self : WgslIrLowerer,
  name : String,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle? raise WgslIrLowerError {
  match name {
    "rayQueryInitialize" => {
      guard arguments is [query, acceleration, ray_desc] else { return None }
      Some(
        function.expressions.append(
          Expression::RayQueryInitialize(
            self.lower_function_expression_node(query, function, scope),
            self.lower_function_expression_node(acceleration, function, scope),
            self.lower_function_expression_node(ray_desc, function, scope),
          ),
        ),
      )
    }
    "rayQueryProceed" => {
      guard arguments is [query] else { return None }
      Some(
        function.expressions.append(
          Expression::RayQueryProceed(
            self.lower_function_expression_node(query, function, scope),
          ),
        ),
      )
    }
    "rayQueryGenerateIntersection" => {
      guard arguments is [query, intersection_t] else { return None }
      Some(
        function.expressions.append(
          Expression::RayQueryGenerateIntersection(
            self.lower_function_expression_node(query, function, scope),
            self.lower_function_expression_node(intersection_t, function, scope),
          ),
        ),
      )
    }
    "rayQueryConfirmIntersection" => {
      guard arguments is [query] else { return None }
      Some(
        function.expressions.append(
          Expression::RayQueryConfirmIntersection(
            self.lower_function_expression_node(query, function, scope),
          ),
        ),
      )
    }
    "rayQueryTerminate" => {
      guard arguments is [query] else { return None }
      Some(
        function.expressions.append(
          Expression::RayQueryTerminate(
            self.lower_function_expression_node(query, function, scope),
          ),
        ),
      )
    }
    "rayQueryGetCommittedIntersection" => {
      guard arguments is [query] else { return None }
      Some(
        function.expressions.append(
          Expression::RayQueryGetIntersection(
            self.lower_function_expression_node(query, function, scope),
            true,
          ),
        ),
      )
    }
    "rayQueryGetCandidateIntersection" => {
      guard arguments is [query] else { return None }
      Some(
        function.expressions.append(
          Expression::RayQueryGetIntersection(
            self.lower_function_expression_node(query, function, scope),
            false,
          ),
        ),
      )
    }
    "getCommittedHitVertexPositions" => {
      guard arguments is [query] else { return None }
      Some(
        function.expressions.append(
          Expression::RayQueryVertexPositions(
            self.lower_function_expression_node(query, function, scope),
            true,
          ),
        ),
      )
    }
    "getCandidateHitVertexPositions" => {
      guard arguments is [query] else { return None }
      Some(
        function.expressions.append(
          Expression::RayQueryVertexPositions(
            self.lower_function_expression_node(query, function, scope),
            false,
          ),
        ),
      )
    }
    _ => None
  }
}

///|
fn WgslIrLowerer::lower_function_expression_arguments(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Array[Handle] raise WgslIrLowerError {
  self.lower_function_expression_arguments_with_expected(
    arguments,
    function,
    scope,
    None,
  )
}

///|
fn WgslIrLowerer::lower_function_expression_arguments_with_expected(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
  expected_ty : Handle?,
) -> Array[Handle] raise WgslIrLowerError {
  let handles : Array[Handle] = []
  for argument in wgsl_ir_flatten_expression_arguments(arguments) {
    let lowered = self.lower_function_expression_node_with_expected(
      argument, function, scope, expected_ty,
    )
    handles.push(self.apply_function_load_rule(function, lowered))
  }
  handles
}

///|
fn WgslIrLowerer::lower_function_constructor_arguments(
  self : WgslIrLowerer,
  ty : Handle,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Array[Handle] raise WgslIrLowerError {
  let flattened = wgsl_ir_flatten_expression_arguments(arguments)
  let expected_ty = self.constructor_argument_expected_type(
    ty,
    flattened.length(),
  )
  let handles : Array[Handle] = []
  for argument in flattened {
    let lowered = self.lower_function_constructor_argument(
      argument, function, scope, expected_ty,
    )
    handles.push(self.apply_function_load_rule(function, lowered))
  }
  handles
}

///|
fn WgslIrLowerer::lower_function_constructor_argument(
  self : WgslIrLowerer,
  argument : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
  expected_ty : Handle?,
) -> Handle raise WgslIrLowerError {
  let expression_mark = function.expressions.items.length()
  let lowered = self.lower_function_expression_node_with_expected(
    argument, function, scope, expected_ty,
  )
  guard self.fold_function_constant_float_expression(function, lowered)
    is Some(literal) else {
    return lowered
  }
  function.expressions.truncate(expression_mark)
  function.expressions.append_with_origin(
    Expression::Literal(literal),
    FoldedLocalConstant,
  )
}

///|
fn WgslIrLowerer::lower_function_constructor_expression_from_handles(
  self : WgslIrLowerer,
  ty : Handle,
  lowered_arguments : Array[Handle],
  function : Function,
) -> Handle {
  match self.vector_size_from_type(ty) {
    Some(size) =>
      match lowered_arguments {
        [argument] =>
          match self.function_expression_type(function, argument) {
            Some(argument_ty) if self.type_is_scalar(argument_ty) =>
              return function.expressions.append(
                Expression::Splat(size, argument),
              )
            _ => ()
          }
        _ => ()
      }
    None => ()
  }
  function.expressions.append(Expression::Compose(ty, lowered_arguments))
}

///|
fn WgslIrLowerer::lower_function_array_constructor_call(
  self : WgslIrLowerer,
  expected_ty : Handle?,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  let lowered_arguments = self.lower_function_expression_arguments(
    arguments, function, scope,
  )
  let ty = match expected_ty {
    Some(ty) => ty
    None =>
      self.infer_array_constructor_type_from_handles(
        lowered_arguments, function, "array",
      )
  }
  guard self.array_element_type(ty) is Some(element_ty) else {
    raise WgslIrLowerError::UnsupportedType("array")
  }
  let components = match expected_ty {
    Some(_) =>
      self.lower_function_expression_arguments_with_expected(
        arguments,
        function,
        scope,
        Some(element_ty),
      )
    None => lowered_arguments
  }
  function.expressions.append(Expression::Compose(ty, components))
}

///|
fn WgslIrLowerer::lower_function_array_length_call(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments is [argument] else {
    raise WgslIrLowerError::UnsupportedExpression(
      "arrayLength expects one argument",
    )
  }
  let pointer = self.lower_atomic_pointer_argument(argument, function, scope)
  function.expressions.append(Expression::ArrayLength(pointer))
}

///|
fn WgslIrLowerer::lower_function_workgroup_uniform_load_call(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments is [argument] else {
    raise WgslIrLowerError::UnsupportedExpression(
      "workgroupUniformLoad expects one argument",
    )
  }
  let pointer = self.lower_atomic_pointer_argument(argument, function, scope)
  function.expressions.append(Expression::WorkGroupUniformLoad(pointer))
}

///|
fn WgslIrLowerer::lower_function_math_call(
  self : WgslIrLowerer,
  math_function : MathFunction,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments.length() > 0 else {
    raise WgslIrLowerError::UnsupportedExpression(
      "math call requires at least one argument",
    )
  }
  let deferred_constructors = self.prelower_homogeneous_math_constructor_arguments(
    math_function, arguments, function, scope,
  )
  let handles : Array[Handle] = []
  if self.math_call_lowers_second_argument_before_first(
      math_function, arguments, function, scope,
    ) {
    let second = self.lower_function_math_argument_at(
      1, arguments, deferred_constructors, function, scope,
    )
    let first = self.lower_function_math_argument_at(
      0, arguments, deferred_constructors, function, scope,
    )
    handles.push(first)
    handles.push(second)
    for index in 2..<arguments.length() {
      handles.push(
        self.lower_function_math_argument_at(
          index, arguments, deferred_constructors, function, scope,
        ),
      )
    }
  } else {
    for index in 0..<arguments.length() {
      handles.push(
        self.lower_function_math_argument_at(
          index, arguments, deferred_constructors, function, scope,
        ),
      )
    }
  }
  self.contextualize_homogeneous_math_arguments(
    math_function, function, handles,
  )
  guard handles is [a, .. rest] else {
    abort("math call argument guard already checked")
  }
  let b = match rest {
    [value, ..] => Some(value)
    [] => None
  }
  let c = match rest {
    [_, value, ..] => Some(value)
    _ => None
  }
  let d = match rest {
    [_, _, value, ..] => Some(value)
    _ => None
  }
  function.expressions.append(Expression::Math(math_function, a, b, c, d))
}

///|
fn WgslIrLowerer::lower_function_math_argument_at(
  self : WgslIrLowerer,
  index : Int,
  arguments : Array[@ast.WgslExprNode],
  deferred_constructors : Map[Int, WgslIrDeferredConstructorArgument],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  let argument = arguments[index]
  let lowered = match deferred_constructors.get(index) {
    Some(deferred) =>
      self.lower_function_constructor_expression_from_handles(
        deferred.ty,
        [deferred.component],
        function,
      )
    None => self.lower_function_expression_node(argument, function, scope)
  }
  self.apply_function_load_rule(function, lowered)
}

///|
fn WgslIrLowerer::math_call_lowers_second_argument_before_first(
  self : WgslIrLowerer,
  math_function : MathFunction,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Bool {
  guard wgsl_ir_math_function_has_homogeneous_arguments(math_function) else {
    return false
  }
  guard arguments.length() >= 2 else { return false }
  wgsl_ir_expr_node_is_literal_like(arguments[0]) &&
  self.expression_node_contains_naga_reference_value(
    arguments[1],
    function,
    scope,
  )
}

///|
priv struct WgslIrDeferredConstructorArgument {
  ty : Handle
  component : Handle
}

///|
fn WgslIrLowerer::prelower_homogeneous_math_constructor_arguments(
  self : WgslIrLowerer,
  math_function : MathFunction,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Map[Int, WgslIrDeferredConstructorArgument] raise WgslIrLowerError {
  let deferred : Map[Int, WgslIrDeferredConstructorArgument] = Map([])
  guard wgsl_ir_math_function_has_homogeneous_arguments(math_function) else {
    return deferred
  }
  for index in 0..<arguments.length() {
    match
      self.prelower_foldable_vector_constructor_argument(
        arguments[index],
        function,
        scope,
      ) {
      Some(value) => deferred.set(index, value)
      None => ()
    }
  }
  deferred
}

///|
fn WgslIrLowerer::prelower_foldable_vector_constructor_argument(
  self : WgslIrLowerer,
  argument : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> WgslIrDeferredConstructorArgument? raise WgslIrLowerError {
  guard argument.kind() is Call(callee, constructor_arguments) else {
    return None
  }
  guard wgsl_ir_flatten_expression_arguments(constructor_arguments)
    is [component] else {
    return None
  }
  guard wgsl_ir_expr_node_is_foldable_float_arena_candidate(component) else {
    return None
  }
  guard self.lower_foldable_vector_constructor_callee_type(
      callee, constructor_arguments, component,
    )
    is Some(ty) else {
    return None
  }
  guard self.vector_size_from_type(ty) is Some(_) else { return None }
  let expected_ty = self.constructor_component_expected_type(ty)
  let expression_mark = function.expressions.items.length()
  let lowered = self.lower_function_expression_node_with_expected(
    component, function, scope, expected_ty,
  )
  match self.fold_function_constant_float_expression(function, lowered) {
    Some(literal) => {
      function.expressions.truncate(expression_mark)
      let component = function.expressions.append_with_origin(
        Expression::Literal(literal),
        FoldedLocalConstant,
      )
      Some(WgslIrDeferredConstructorArgument::{ ty, component })
    }
    None => {
      function.expressions.truncate(expression_mark)
      None
    }
  }
}

///|
fn WgslIrLowerer::lower_foldable_vector_constructor_callee_type(
  self : WgslIrLowerer,
  callee : @ast.WgslExprNode,
  constructor_arguments : Array[@ast.WgslExprNode],
  component : @ast.WgslExprNode,
) -> Handle? raise WgslIrLowerError {
  match self.lower_templated_callee_type(callee) {
    Some(ty) => return Some(ty)
    None => ()
  }
  match callee.kind() {
    Identifier(name) => {
      let constructor_name = name.name()
      guard wgsl_ir_vector_size_from_constructor_name(constructor_name)
        is Some(_) else {
        return None
      }
      guard wgsl_ir_expr_node_requires_float_arena_fold(component) else {
        return None
      }
      Some(
        self.lower_untemplated_constructor_type_from_ast(
          constructor_name, constructor_arguments, constructor_name,
        ),
      )
    }
    _ => None
  }
}

///|
fn wgsl_ir_expr_node_requires_float_arena_fold(
  node : @ast.WgslExprNode,
) -> Bool {
  match node.kind() {
    Group(inner) => wgsl_ir_expr_node_requires_float_arena_fold(inner)
    Sequence([single]) => wgsl_ir_expr_node_requires_float_arena_fold(single)
    Unary(_, inner) =>
      wgsl_ir_expr_node_is_foldable_float_arena_candidate(inner)
    Binary(_, left, right) =>
      wgsl_ir_expr_node_is_foldable_float_arena_candidate(left) ||
      wgsl_ir_expr_node_is_foldable_float_arena_candidate(right)
    _ => false
  }
}

///|
fn wgsl_ir_expr_node_is_foldable_float_arena_candidate(
  node : @ast.WgslExprNode,
) -> Bool {
  match node.kind() {
    Literal(_) => true
    Group(inner) => wgsl_ir_expr_node_is_foldable_float_arena_candidate(inner)
    Sequence([single]) =>
      wgsl_ir_expr_node_is_foldable_float_arena_candidate(single)
    Unary(op, inner) =>
      op == @ast.WgslExprOperator::Subtract &&
      wgsl_ir_expr_node_is_foldable_float_arena_candidate(inner)
    Binary(_, left, right) =>
      wgsl_ir_expr_node_is_foldable_float_arena_candidate(left) &&
      wgsl_ir_expr_node_is_foldable_float_arena_candidate(right)
    _ => false
  }
}

///|
fn WgslIrLowerer::contextualize_homogeneous_math_arguments(
  self : WgslIrLowerer,
  math_function : MathFunction,
  function : Function,
  handles : Array[Handle],
) -> Unit raise WgslIrLowerError {
  guard wgsl_ir_math_function_has_homogeneous_arguments(math_function) else {
    return
  }
  guard self.concrete_math_argument_type(function, handles) is Some(expected_ty) else {
    return
  }
  for handle in handles {
    self.contextualize_function_literal_expression(
      function, handle, expected_ty,
    )
  }
}

///|
fn wgsl_ir_math_function_has_homogeneous_arguments(
  math_function : MathFunction,
) -> Bool {
  match math_function {
    Min
    | Max
    | Clamp
    | Step
    | SmoothStep
    | Mix
    | Dot
    | Distance
    | Reflect
    | FaceForward
    | Refract
    | Fma
    | Pow
    | Atan2 => true
    _ => false
  }
}

///|
fn WgslIrLowerer::concrete_math_argument_type(
  self : WgslIrLowerer,
  function : Function,
  handles : Array[Handle],
) -> Handle? {
  for handle in handles {
    match self.function_expression_type(function, handle) {
      Some(ty) =>
        if self.type_is_concrete_numeric_literal_context(ty) {
          return Some(ty)
        }
      None => ()
    }
  }
  None
}

///|
fn WgslIrLowerer::type_is_concrete_numeric_literal_context(
  self : WgslIrLowerer,
  ty : Handle,
) -> Bool {
  match self.scalar_for_literal_context_type(ty) {
    Some(scalar) =>
      match scalar.kind {
        Sint | Uint | Float => true
        _ => false
      }
    None => false
  }
}

///|
fn WgslIrLowerer::lower_function_relational_call(
  self : WgslIrLowerer,
  relational_function : RelationalFunction,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments is [expr] else {
    raise WgslIrLowerError::UnsupportedExpression(
      "\{wgsl_ir_relational_function_name(relational_function)} expects one argument",
    )
  }
  let argument = self.lower_function_expression_node(expr, function, scope)
  function.expressions.append(
    Expression::Relational(
      relational_function,
      self.apply_function_load_rule(function, argument),
    ),
  )
}

///|
fn WgslIrLowerer::lower_function_select_call(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments is [reject, accept, condition] else {
    raise WgslIrLowerError::UnsupportedExpression(
      "select expects three arguments",
    )
  }
  let (condition, accept, reject) = if wgsl_ir_expr_node_is_literal_like(reject) &&
    wgsl_ir_expr_node_is_literal_like(accept) {
    let condition = self.lower_function_expression_node(
      condition, function, scope,
    )
    let accept = self.lower_function_expression_node(accept, function, scope)
    let reject = self.lower_function_expression_node(reject, function, scope)
    (condition, accept, reject)
  } else {
    let reject = self.lower_function_expression_node(reject, function, scope)
    let accept = self.lower_function_expression_node(accept, function, scope)
    let condition = self.lower_function_expression_node(
      condition, function, scope,
    )
    (condition, accept, reject)
  }
  function.expressions.append(Expression::Select(condition, accept, reject))
}

///|
fn WgslIrLowerer::lower_function_bitcast_call(
  self : WgslIrLowerer,
  ty : Handle,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments is [expr] else {
    raise WgslIrLowerError::UnsupportedExpression(
      "bitcast expects one argument",
    )
  }
  function.expressions.append(
    Expression::Bitcast(
      ty,
      self.lower_function_expression_node(expr, function, scope),
    ),
  )
}

///|
fn WgslIrLowerer::lower_function_atomic_call(
  self : WgslIrLowerer,
  atomic_function : AtomicFunction,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  let expected = match atomic_function {
    Load => 1
    Store => 2
    Add | Subtract | And | ExclusiveOr | InclusiveOr | Min | Max | Exchange => 2
    CompareExchangeWeak => 3
  }
  if arguments.length() != expected {
    raise WgslIrLowerError::UnsupportedExpression(
      "\{wgsl_ir_atomic_function_name(atomic_function)} expects \{expected} arguments",
    )
  }
  let handles : Array[Handle] = []
  for index in 0..<arguments.length() {
    let argument = arguments[index]
    if index == 0 {
      handles.push(
        self.lower_atomic_pointer_argument(argument, function, scope),
      )
    } else {
      handles.push(
        self.lower_function_expression_node(argument, function, scope),
      )
    }
  }
  function.expressions.append(Expression::AtomicCall(atomic_function, handles))
}

///|
fn WgslIrLowerer::lower_atomic_pointer_argument(
  self : WgslIrLowerer,
  argument : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  match wgsl_ir_address_of_operand_node(argument) {
    Some(target) => self.lower_function_lvalue_node(target, function, scope)
    None => self.lower_function_expression_node(argument, function, scope)
  }
}

///|
fn wgsl_ir_expr_ref_is_phony(expr_ref : @ast.WgslExprRef) -> Bool {
  match expr_ref.root() {
    Some(root) =>
      match root.kind() {
        Identifier(name) => name.name() == "_"
        _ => false
      }
    None => false
  }
}

///|
fn wgsl_ir_expr_tokens_are_phony(tokens : Array[@ast.WgslExprToken]) -> Bool {
  match tokens {
    [token] =>
      match token.kind() {
        Identifier => token.text() == "_"
        _ => false
      }
    _ => false
  }
}

///|
fn wgsl_ir_flatten_expression_arguments(
  arguments : Array[@ast.WgslExprNode],
) -> Array[@ast.WgslExprNode] {
  match arguments {
    [single] =>
      match single.kind() {
        Sequence(items) => items
        _ => arguments
      }
    _ => arguments
  }
}

///|
fn wgsl_ir_expr_node_shape(node : @ast.WgslExprNode) -> String {
  match node.kind() {
    Identifier(name) => "identifier \{name.name()}"
    Literal(token) => "literal \{token.text()}"
    ShaderDefTemplate(text) => "shader-def template \{text}"
    Unary(op, inner) => "unary \{op.text()}(\{wgsl_ir_expr_node_shape(inner)})"
    PostfixUpdate(op, inner) =>
      "postfix \{op}(\{wgsl_ir_expr_node_shape(inner)})"
    Assignment(op, left, right) =>
      "assignment \{op}(\{wgsl_ir_expr_node_shape(left)}, \{wgsl_ir_expr_node_shape(right)})"
    Binary(op, left, right) =>
      "binary \{op.text()}(\{wgsl_ir_expr_node_shape(left)}, \{wgsl_ir_expr_node_shape(right)})"
    Call(callee, _) => "call(\{wgsl_ir_expr_node_shape(callee)})"
    Template(base, _) => "template(\{wgsl_ir_expr_node_shape(base)})"
    PathAccess(base, segment) =>
      "path(\{wgsl_ir_expr_node_shape(base)}::\{segment.name()})"
    Member(base, segment) =>
      "member(\{wgsl_ir_expr_node_shape(base)}.\{segment.name()})"
    Index(base, _) => "index(\{wgsl_ir_expr_node_shape(base)})"
    Group(inner) => "group(\{wgsl_ir_expr_node_shape(inner)})"
    Sequence(items) => {
      let parts : Array[String] = []
      let limit = if items.length() < 4 { items.length() } else { 4 }
      for i in 0..<limit {
        parts.push(wgsl_ir_expr_node_shape(items[i]))
      }
      if items.length() > limit {
        parts.push("...")
      }
      let text = parts.join(", ")
      "sequence(\{items.length()}: \{text})"
    }
  }
}
