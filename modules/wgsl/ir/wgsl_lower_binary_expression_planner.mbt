///|
fn WgslIrLowerer::plan_binary_const_parent_with_right_local_reference(
  self : WgslIrLowerer,
  parent_op : @ast.WgslExprOperator,
  left : @ast.WgslExprNode,
  right : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> (Handle, Handle)? raise WgslIrLowerError {
  match parent_op {
    Add | Subtract => ()
    _ => return None
  }
  guard self.expression_node_is_writer_deferred_const_like(left, scope) else {
    return None
  }
  guard wgsl_ir_expr_node_without_groups(left).kind() is Binary(_, _, _) else {
    return None
  }
  guard !wgsl_ir_expr_node_contains_non_math_call(right) else { return None }
  let (right_op, right_left_node, right_right_node) = match
    wgsl_ir_expr_node_without_groups(right).kind() {
    Binary(op, right_left, right_right) => (op, right_left, right_right)
    _ => return None
  }
  guard wgsl_ir_ast_binary_operator_is_multiplicative(right_op) else {
    return None
  }
  guard self.expression_node_is_writer_deferred_const_like(
    right_left_node, scope,
  ) else {
    return None
  }
  guard wgsl_ir_expr_node_without_groups(right_left_node).kind()
    is Binary(_, _, _) else {
    return None
  }
  guard self.expression_node_contains_mutable_local_reference(
    right_right_node, function, scope,
  ) else {
    return None
  }
  let right_left = self.lower_function_expression_node(
    right_left_node, function, scope,
  )
  let left_handle = self.lower_function_expression_node(left, function, scope)
  let right_right = self.lower_function_expression_node(
    right_right_node, function, scope,
  )
  let right_binary_op = wgsl_ir_binary_operator(right_op)
  let (right_left, right_right) = self.normalize_function_binary_operands(
    function, right_binary_op, right_left, right_right,
  )
  let right_handle = function.expressions.append(
    Binary(right_binary_op, right_left, right_right),
  )
  Some((left_handle, right_handle))
}

///|
fn WgslIrLowerer::plan_binary_declared_constant_before_call_product(
  self : WgslIrLowerer,
  op : @ast.WgslExprOperator,
  left : @ast.WgslExprNode,
  right : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle? raise WgslIrLowerError {
  guard op == Subtract else { return None }
  guard self.expr_node_is_declared_or_generated_constant_reference(left) else {
    return None
  }
  guard wgsl_ir_expr_node_without_groups(right).kind()
    is Binary(right_op, right_left, right_right) else {
    return None
  }
  guard wgsl_ir_ast_binary_operator_is_multiplicative(right_op) else {
    return None
  }
  guard wgsl_ir_expr_node_contains_call(right) else { return None }
  let right_left_handle = self.lower_function_expression_node(
    right_left, function, scope,
  )
  let right_right_handle = self.lower_function_expression_node(
    right_right, function, scope,
  )
  let left_handle = self.lower_function_expression_node(left, function, scope)
  let right_binary_op = wgsl_ir_binary_operator(right_op)
  let (right_left_handle, right_right_handle) = self.normalize_function_binary_operands(
    function, right_binary_op, right_left_handle, right_right_handle,
  )
  let right_handle = function.expressions.append(
    Binary(right_binary_op, right_left_handle, right_right_handle),
  )
  let binary_op = wgsl_ir_binary_operator(op)
  let (left_handle, right_handle) = self.normalize_function_binary_operands(
    function, binary_op, left_handle, right_handle,
  )
  Some(
    function.expressions.append(Binary(binary_op, left_handle, right_handle)),
  )
}

///|
fn WgslIrLowerer::expr_node_is_declared_or_generated_constant_reference(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
) -> Bool {
  match node.kind() {
    Group(inner) =>
      self.expr_node_is_declared_or_generated_constant_reference(inner)
    Identifier(name) =>
      self.constant_declarations.contains(name.name()) ||
      self.constant_names.contains(name.name())
    _ => false
  }
}

///|
fn WgslIrLowerer::plan_binary_parent_argument_after_member_root(
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
    Binary(left_binary_op, left_left_handle, left_right_handle),
  )
  let right_handle = self.lower_function_expression_node(right, function, scope)
  let binary_op = wgsl_ir_binary_operator(op)
  let (left_handle, right_handle) = self.normalize_function_binary_operands(
    function, binary_op, left_handle, right_handle,
  )
  Some(
    function.expressions.append(Binary(binary_op, left_handle, right_handle)),
  )
}

///|
fn WgslIrLowerer::plan_binary_const_left_before_math_parent(
  self : WgslIrLowerer,
  op : @ast.WgslExprOperator,
  left : @ast.WgslExprNode,
  right : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle? raise WgslIrLowerError {
  guard wgsl_ir_ast_binary_operator_is_multiplicative(op) else { return None }
  guard self.expression_node_is_foldable_math_const_like(left, scope) else {
    return None
  }
  guard !wgsl_ir_expr_node_references_local_let_constant(left, scope) else {
    return None
  }
  let (math_function, argument) = match
    wgsl_ir_expr_node_without_groups(right).kind() {
    Call(callee, arguments) =>
      match callee.kind() {
        Identifier(name) =>
          match wgsl_ir_math_function_from_name(name.name()) {
            Some(math_function) => {
              let arguments = wgsl_ir_call_arguments(arguments)
              guard arguments is [argument] else { return None }
              (math_function, argument)
            }
            None => return None
          }
        _ => return None
      }
    _ => return None
  }
  guard wgsl_ir_expr_node_without_groups(argument).kind() is Binary(_, _, _) else {
    return None
  }
  let (argument_op, argument_left, argument_right) = self.lower_binary_expression_children_for_const_left_math_argument(
    argument, function, scope,
  )
  let left_handle = self.lower_function_expression_node(left, function, scope)
  let argument_binary_op = wgsl_ir_binary_operator(argument_op)
  let (argument_left, argument_right) = self.normalize_function_binary_operands(
    function, argument_binary_op, argument_left, argument_right,
  )
  let argument_handle = function.expressions.append(
    Binary(argument_binary_op, argument_left, argument_right),
  )
  let right_handle = function.expressions.append(
    Math(math_function, argument_handle, None, None, None),
  )
  let binary_op = wgsl_ir_binary_operator(op)
  let (left_handle, right_handle) = self.normalize_function_binary_operands(
    function, binary_op, left_handle, right_handle,
  )
  Some(
    function.expressions.append(Binary(binary_op, left_handle, right_handle)),
  )
}

///|
fn WgslIrLowerer::plan_binary_folded_right_const_vector_operand(
  self : WgslIrLowerer,
  op : @ast.WgslExprOperator,
  left : @ast.WgslExprNode,
  right : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle? raise WgslIrLowerError {
  match op {
    Add | Subtract => ()
    _ => return None
  }
  guard self.expression_node_is_float_vector_const_fold_candidate(right, scope) else {
    return None
  }
  guard self.expression_node_contains_constructor_call_value(right) else {
    return None
  }
  let mark = function.expressions.items.length()
  let lowered_right = self.lower_function_expression_node(
    right, function, scope,
  )
  let folded = self.fold_function_constant_float_vector_expression(
    function, lowered_right,
  )
  function.expressions.truncate(mark)
  guard folded is Some((right_ty, values)) else { return None }
  let right_handle = self.append_function_float_vector_literal_compose(
    function, right_ty, values,
  )
  let left_handle = self.lower_function_expression_node(left, function, scope)
  let binary_op = wgsl_ir_binary_operator(op)
  let (left_handle, right_handle) = self.normalize_function_binary_operands(
    function, binary_op, left_handle, right_handle,
  )
  Some(
    function.expressions.append(Binary(binary_op, left_handle, right_handle)),
  )
}

///|
fn WgslIrLowerer::lower_binary_expression_children_for_const_left_math_argument(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> (@ast.WgslExprOperator, Handle, Handle) raise WgslIrLowerError {
  match wgsl_ir_expr_node_without_groups(node).kind() {
    Binary(op, left, right) =>
      if wgsl_ir_expr_node_is_literal_like(left) &&
        wgsl_ir_expr_node_without_groups(right).kind() is Binary(_, _, _) {
        let right_handle = self.lower_function_expression_node(
          right, function, scope,
        )
        let left_handle = self.lower_function_expression_node(
          left, function, scope,
        )
        (op, left_handle, right_handle)
      } else {
        self.lower_binary_expression_children(node, function, scope)
      }
    _ => self.lower_binary_expression_children(node, function, scope)
  }
}

///|
fn WgslIrLowerer::plan_binary_trailing_source_let_initializer(
  self : WgslIrLowerer,
  op : @ast.WgslExprOperator,
  left : @ast.WgslExprNode,
  right : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle? raise WgslIrLowerError {
  guard wgsl_ir_ast_binary_operator_is_multiplicative(op) else { return None }
  guard wgsl_ir_expr_node_without_groups(left).kind() is Binary(_, _, _) else {
    return None
  }
  guard wgsl_ir_expr_node_without_groups(right).kind() is Identifier(name) else {
    return None
  }
  guard self.local_let_identifier_has_literal_initializer(name.name(), scope) else {
    return None
  }
  guard self.expression_node_contains_mutable_local_reference(
    left, function, scope,
  ) else {
    return None
  }
  let right_handle = self.lower_identifier_expression(
    name.name(),
    function,
    scope,
  )
  let left_handle = self.lower_function_expression_node(left, function, scope)
  let binary_op = wgsl_ir_binary_operator(op)
  let (left_handle, right_handle) = self.normalize_function_binary_operands(
    function, binary_op, left_handle, right_handle,
  )
  Some(
    function.expressions.append(Binary(binary_op, left_handle, right_handle)),
  )
}

///|
fn WgslIrLowerer::plan_binary_trailing_source_let_literal(
  self : WgslIrLowerer,
  op : @ast.WgslExprOperator,
  left : @ast.WgslExprNode,
  right : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle? raise WgslIrLowerError {
  guard wgsl_ir_ast_binary_operator_is_multiplicative(op) else { return None }
  guard wgsl_ir_expr_node_without_groups(right).kind() is Identifier(name) else {
    return None
  }
  guard self.local_let_identifier_has_literal_initializer(name.name(), scope) else {
    return None
  }
  guard self.expression_node_is_mutable_local_value(left, function, scope) else {
    return None
  }
  guard !wgsl_ir_expr_node_contains_call(left) else { return None }
  let right_handle = self.lower_identifier_expression(
    name.name(),
    function,
    scope,
  )
  let left_handle = self.lower_function_expression_node(left, function, scope)
  let binary_op = wgsl_ir_binary_operator(op)
  let (left_handle, right_handle) = self.normalize_function_binary_operands(
    function, binary_op, left_handle, right_handle,
  )
  let handle = function.expressions.append(
    Binary(binary_op, left_handle, right_handle),
  )
  function.expressions.set_origin(handle, RetainedSourceLetExpression)
  Some(handle)
}

///|
fn WgslIrLowerer::local_let_identifier_has_literal_initializer(
  self : WgslIrLowerer,
  name : String,
  scope : WgslIrFunctionScope,
) -> Bool {
  ignore(self)
  match scope.local_constants.get(name) {
    Some({ value: LazyConstant(local_constant), source: LocalLet }) =>
      match local_constant.expr_ref.root() {
        Some(root) => wgsl_ir_expr_node_is_literal_like(root)
        None => false
      }
    _ => false
  }
}

///|
fn WgslIrLowerer::plan_binary_sibling_arguments_before_parent(
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
  let left = wgsl_ir_expr_node_without_groups(left)
  guard left.kind() is Binary(left_op, left_left, left_right) else {
    return None
  }
  guard wgsl_ir_expr_node_is_function_argument_value(left_right, scope) else {
    return None
  }
  let left_left_handle = self.lower_function_expression_node(
    left_left, function, scope,
  )
  self.predeclare_function_argument_value(left_right, function, scope)
  self.predeclare_function_argument_value(right, function, scope)
  let left_right_handle = self.lower_function_expression_node(
    left_right, function, scope,
  )
  let left_binary_op = wgsl_ir_binary_operator(left_op)
  let (left_left_handle, left_right_handle) = self.normalize_function_binary_operands(
    function, left_binary_op, left_left_handle, left_right_handle,
  )
  let left_handle = function.expressions.append(
    Binary(left_binary_op, left_left_handle, left_right_handle),
  )
  let right_handle = self.lower_function_expression_node(right, function, scope)
  let binary_op = wgsl_ir_binary_operator(op)
  let (left_handle, right_handle) = self.normalize_function_binary_operands(
    function, binary_op, left_handle, right_handle,
  )
  Some(
    function.expressions.append(Binary(binary_op, left_handle, right_handle)),
  )
}

///|
fn WgslIrLowerer::plan_binary_parent_argument_after_named_root(
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
  let left = wgsl_ir_expr_node_without_groups(left)
  guard left.kind() is Binary(left_op, left_left, left_right) else {
    return None
  }
  guard self.expression_node_is_named_expression_alias(
    left_left, function, scope,
  ) else {
    return None
  }
  let left_left_handle = self.lower_function_expression_node(
    left_left, function, scope,
  )
  let left_right_handle = self.lower_function_expression_node(
    left_right, function, scope,
  )
  self.predeclare_function_argument_value(right, function, scope)
  let left_binary_op = wgsl_ir_binary_operator(left_op)
  let (left_left_handle, left_right_handle) = self.normalize_function_binary_operands(
    function, left_binary_op, left_left_handle, left_right_handle,
  )
  let left_handle = function.expressions.append(
    Binary(left_binary_op, left_left_handle, left_right_handle),
  )
  let right_handle = self.lower_function_expression_node(right, function, scope)
  let binary_op = wgsl_ir_binary_operator(op)
  let (left_handle, right_handle) = self.normalize_function_binary_operands(
    function, binary_op, left_handle, right_handle,
  )
  Some(
    function.expressions.append(Binary(binary_op, left_handle, right_handle)),
  )
}

///|
fn WgslIrLowerer::plan_binary_parent_argument_root_projection(
  self : WgslIrLowerer,
  op : @ast.WgslExprOperator,
  left : @ast.WgslExprNode,
  right : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle? raise WgslIrLowerError {
  guard wgsl_ir_direct_access_chain_root_is_function_argument(right, scope) else {
    return None
  }
  guard !wgsl_ir_expr_node_is_function_argument_value(right, scope) else {
    return None
  }
  let left = wgsl_ir_expr_node_without_groups(left)
  guard left.kind() is Binary(left_op, left_left, left_right) else {
    return None
  }
  guard wgsl_ir_expr_node_is_direct_access_chain(left_left) else { return None }
  guard self.expression_node_is_named_expression_alias(
    left_right, function, scope,
  ) else {
    return None
  }
  self.predeclare_function_argument_values_in_source_order(
    right, function, scope,
  )
  let left_left_handle = self.lower_function_expression_node(
    left_left, function, scope,
  )
  let left_right_handle = self.lower_function_expression_node(
    left_right, function, scope,
  )
  let left_binary_op = wgsl_ir_binary_operator(left_op)
  let (left_left_handle, left_right_handle) = self.normalize_function_binary_operands(
    function, left_binary_op, left_left_handle, left_right_handle,
  )
  let left_handle = function.expressions.append(
    Binary(left_binary_op, left_left_handle, left_right_handle),
  )
  let right_handle = self.lower_function_expression_node(right, function, scope)
  let binary_op = wgsl_ir_binary_operator(op)
  let (left_handle, right_handle) = self.normalize_function_binary_operands(
    function, binary_op, left_handle, right_handle,
  )
  Some(
    function.expressions.append(Binary(binary_op, left_handle, right_handle)),
  )
}

///|
fn wgsl_ir_expr_node_without_groups(
  node : @ast.WgslExprNode,
) -> @ast.WgslExprNode {
  match node.kind() {
    Group(inner) => wgsl_ir_expr_node_without_groups(inner)
    _ => node
  }
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
fn WgslIrLowerer::expression_node_is_named_expression_alias(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Bool {
  match node.kind() {
    Group(inner) =>
      self.expression_node_is_named_expression_alias(inner, function, scope)
    Identifier(name) =>
      match scope.local_constants.get(name.name()) {
        Some({ value: ExpressionAlias(handle, _), .. }) =>
          wgsl_ir_function_expression_has_arena_name(function, handle)
        _ => false
      }
    _ => false
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
fn WgslIrLowerer::predeclare_function_reference_roots_in_source_order(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Unit raise WgslIrLowerError {
  match node.kind() {
    Identifier(_) =>
      self.predeclare_function_argument_value(node, function, scope)
    Group(inner) =>
      self.predeclare_function_reference_roots_in_source_order(
        inner, function, scope,
      )
    Member(base, _) =>
      self.predeclare_function_member_root_expression(base, function, scope)
    Unary(_, expr) | PostfixUpdate(_, expr) =>
      self.predeclare_function_reference_roots_in_source_order(
        expr, function, scope,
      )
    Assignment(_, left, right) => {
      self.predeclare_function_reference_roots_in_source_order(
        left, function, scope,
      )
      self.predeclare_function_reference_roots_in_source_order(
        right, function, scope,
      )
    }
    Binary(_, left, right) => {
      self.predeclare_function_reference_roots_in_source_order(
        left, function, scope,
      )
      self.predeclare_function_reference_roots_in_source_order(
        right, function, scope,
      )
    }
    Call(_, arguments) | Sequence(arguments) =>
      for argument in arguments {
        self.predeclare_function_reference_roots_in_source_order(
          argument, function, scope,
        )
      }
    Index(base, index) => {
      self.predeclare_function_reference_roots_in_source_order(
        base, function, scope,
      )
      self.predeclare_function_reference_roots_in_source_order(
        index, function, scope,
      )
    }
    Template(base, _) =>
      self.predeclare_function_reference_roots_in_source_order(
        base, function, scope,
      )
    Literal(_) | ShaderDefTemplate(_) | PathAccess(_, _) => ()
  }
}

///|
fn WgslIrLowerer::plan_binary_left_argument_after_global_product(
  self : WgslIrLowerer,
  op : @ast.WgslExprOperator,
  left : @ast.WgslExprNode,
  right : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle? raise WgslIrLowerError {
  guard op == Subtract else { return None }
  guard wgsl_ir_expr_node_is_function_argument_value(left, scope) else {
    return None
  }
  guard wgsl_ir_expr_node_without_groups(right).kind()
    is Binary(right_op, right_left, right_right) else {
    return None
  }
  guard wgsl_ir_ast_binary_operator_is_multiplicative(right_op) else {
    return None
  }
  guard wgsl_ir_expr_node_is_function_argument_value(right_left, scope) else {
    return None
  }
  guard wgsl_ir_expr_node_without_groups(right_right).kind()
    is Identifier(global_name) else {
    return None
  }
  let global_handle = match self.global_names.get(global_name.name()) {
    Some(handle) => handle
    None => return None
  }
  guard !self.global_variable_is_handle_value(global_handle) else {
    return None
  }
  let global_pointer = function.expressions.append(
    GlobalVariable(global_handle),
  )
  let right_left_handle = self.lower_function_expression_node(
    right_left, function, scope,
  )
  let left_handle = self.lower_function_expression_node(left, function, scope)
  let right_right_handle = function.expressions.append(Load(global_pointer))
  let right_binary_op = wgsl_ir_binary_operator(right_op)
  let (right_left_handle, right_right_handle) = self.normalize_function_binary_operands(
    function, right_binary_op, right_left_handle, right_right_handle,
  )
  let right_handle = function.expressions.append(
    Binary(right_binary_op, right_left_handle, right_right_handle),
  )
  let binary_op = wgsl_ir_binary_operator(op)
  let (left_handle, right_handle) = self.normalize_function_binary_operands(
    function, binary_op, left_handle, right_handle,
  )
  Some(
    function.expressions.append(Binary(binary_op, left_handle, right_handle)),
  )
}

///|
fn WgslIrLowerer::predeclare_function_binary_chain_reference_roots_in_source_order(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Unit raise WgslIrLowerError {
  match node.kind() {
    Identifier(name) =>
      self.predeclare_identifier_reference_root(name.name(), function, scope)
    Group(inner) =>
      self.predeclare_function_binary_chain_reference_roots_in_source_order(
        inner, function, scope,
      )
    Member(base, _) =>
      self.predeclare_function_member_root_expression(base, function, scope)
    Unary(_, expr) | PostfixUpdate(_, expr) =>
      self.predeclare_function_binary_chain_reference_roots_in_source_order(
        expr, function, scope,
      )
    Assignment(_, left, right) | Binary(_, left, right) => {
      self.predeclare_function_binary_chain_reference_roots_in_source_order(
        left, function, scope,
      )
      self.predeclare_function_binary_chain_reference_roots_in_source_order(
        right, function, scope,
      )
    }
    Index(base, index) => {
      self.predeclare_function_binary_chain_reference_roots_in_source_order(
        base, function, scope,
      )
      self.predeclare_function_binary_chain_reference_roots_in_source_order(
        index, function, scope,
      )
    }
    Template(base, _) =>
      self.predeclare_function_binary_chain_reference_roots_in_source_order(
        base, function, scope,
      )
    Call(_, arguments) =>
      match wgsl_ir_call_arguments(arguments) {
        [first, ..] =>
          self.predeclare_function_binary_chain_reference_roots_in_source_order(
            first, function, scope,
          )
        [] => ()
      }
    Sequence(arguments) =>
      for argument in arguments {
        self.predeclare_function_binary_chain_reference_roots_in_source_order(
          argument, function, scope,
        )
      }
    Literal(_) | ShaderDefTemplate(_) | PathAccess(_, _) => ()
  }
}

///|
fn WgslIrLowerer::predeclare_identifier_reference_root(
  self : WgslIrLowerer,
  name : String,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Unit raise WgslIrLowerError {
  match scope.local_constants.get(name) {
    Some(_) => {
      ignore(self.lower_identifier_expression(name, function, scope))
      return
    }
    None => ()
  }
  match scope.locals.get(name) {
    Some(handle) => {
      ignore(scope.local_pointer_expression(name, handle, function))
      return
    }
    None => ()
  }
  match scope.arguments.get(name) {
    Some(index) => {
      ignore(scope.argument_expression(name, index, function))
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
fn WgslIrLowerer::lower_function_right_operand_before_left(
  self : WgslIrLowerer,
  parent_op : @ast.WgslExprOperator,
  left : @ast.WgslExprNode,
  right : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> (Handle, Handle) raise WgslIrLowerError {
  let scheduler = self.expression_arena_scheduler(function, scope)
  if scheduler.binary_right_root_is_delayed_after_parent_left(parent_op, right) &&
    !wgsl_ir_expr_node_contains_call(right) {
    if (parent_op == Divide || parent_op == Subtract) &&
      (
        wgsl_ir_expr_node_is_literal_like(left) ||
        wgsl_ir_expr_node_is_negative_literal_like(left)
      ) {
      let right_handle = self.lower_function_expression_node(
        right, function, scope,
      )
      let left_handle = self.lower_function_expression_node(
        left, function, scope,
      )
      return (left_handle, right_handle)
    }
    let (right_op, right_left, right_right) = self.lower_binary_expression_children(
      right, function, scope,
    )
    let right_binary_op = wgsl_ir_binary_operator(right_op)
    let (right_left, right_right) = self.normalize_function_binary_operands(
      function, right_binary_op, right_left, right_right,
    )
    let left_handle = self.lower_function_expression_node(left, function, scope)
    let right_handle = function.expressions.append(
      Binary(right_binary_op, right_left, right_right),
    )
    return (left_handle, right_handle)
  }
  let right_handle = self.lower_function_expression_node(right, function, scope)
  let left_handle = self.lower_function_expression_node(left, function, scope)
  (left_handle, right_handle)
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
      let scheduler = self.expression_arena_scheduler(function, scope)
      match
        self.lower_binary_expression_children_with_parent_argument_after_child(
          op, left, right, function, scope,
        ) {
        Some(result) => return result
        None => ()
      }
      if scheduler.binary_lowers_right_argument_before_left_access(left, right) {
        self.predeclare_function_reference_roots_in_source_order(
          left, function, scope,
        )
        self.predeclare_function_argument_value(right, function, scope)
      }
      let (left_handle, right_handle) = if scheduler.binary_lowers_right_before_left(
          op, left, right,
        ) {
        self.lower_function_right_operand_before_left(
          op, left, right, function, scope,
        )
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
    Group(inner) =>
      self.lower_binary_expression_children(inner, function, scope)
    _ => raise UnsupportedExpression("expected binary expression subtree")
  }
}

///|
fn WgslIrLowerer::lower_binary_expression_children_with_parent_argument_after_child(
  self : WgslIrLowerer,
  op : @ast.WgslExprOperator,
  left : @ast.WgslExprNode,
  right : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> (@ast.WgslExprOperator, Handle, Handle)? raise WgslIrLowerError {
  guard wgsl_ir_expr_node_is_function_argument_value(right, scope) else {
    return None
  }
  let left = wgsl_ir_expr_node_without_groups(left)
  guard left.kind() is Binary(left_op, left_left, left_right) else {
    return None
  }
  let left_left_handle = self.lower_function_expression_node(
    left_left, function, scope,
  )
  let left_right_handle = self.lower_function_expression_node(
    left_right, function, scope,
  )
  self.predeclare_function_argument_value(right, function, scope)
  let left_binary_op = wgsl_ir_binary_operator(left_op)
  let (left_left_handle, left_right_handle) = self.normalize_function_binary_operands(
    function, left_binary_op, left_left_handle, left_right_handle,
  )
  let left_handle = function.expressions.append(
    Binary(left_binary_op, left_left_handle, left_right_handle),
  )
  let right_handle = self.lower_function_expression_node(right, function, scope)
  Some((op, left_handle, right_handle))
}

///|
fn WgslIrLowerer::plan_binary_left_constructor_after_right_argument_root(
  self : WgslIrLowerer,
  left : @ast.WgslExprNode,
  right : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> (Handle, Handle)? raise WgslIrLowerError {
  let left_handle = match
    self.lower_function_constructor_call_after_predeclared_argument(
      left, right, function, scope,
    ) {
    Some(handle) => handle
    None => return None
  }
  let right_handle = self.lower_function_expression_node(right, function, scope)
  Some((left_handle, right_handle))
}

///|
fn WgslIrLowerer::plan_binary_right_constructor_after_arguments_before_left(
  self : WgslIrLowerer,
  op : @ast.WgslExprOperator,
  left : @ast.WgslExprNode,
  right : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> (Handle, Handle)? raise WgslIrLowerError {
  guard op == Multiply else { return None }
  guard wgsl_ir_expr_node_is_function_argument_value(left, scope) else {
    return None
  }
  match wgsl_ir_expr_node_without_groups(right).kind() {
    Call(callee, arguments) => {
      let arguments = wgsl_ir_call_arguments(arguments)
      guard self.expression_callee_is_constructor_call_value(callee) else {
        return None
      }
      let flattened = wgsl_ir_flatten_expression_arguments(arguments)
      guard !flattened.is_empty() else { return None }
      let scheduler = self.expression_arena_scheduler(function, scope)
      for argument in flattened {
        if scheduler.constructor_argument_has_ordered_effect(argument) {
          return None
        }
      }
      let expression_mark = function.expressions.items.length()
      let lowered_arguments = self.lower_function_constructor_arguments_with_expected(
        arguments,
        function,
        scope,
        None,
      )
      let left_handle = self.lower_function_expression_node(
        left, function, scope,
      )
      let right_handle = match callee.kind() {
        Identifier(name) => {
          guard wgsl_ir_vector_size_from_constructor_name(name.name()) != None else {
            return None
          }
          self.finish_function_constructor_call(
            name.name(),
            arguments,
            lowered_arguments,
            function,
            scope,
            None,
            expression_mark,
          )
        }
        Template(_, _) =>
          match self.lower_templated_callee_type(callee) {
            Some(ty) =>
              self.lower_function_constructor_expression_from_handles(
                ty, lowered_arguments, function,
              )
            None => return None
          }
        _ => return None
      }
      Some((left_handle, right_handle))
    }
    _ => None
  }
}

///|
fn WgslIrLowerer::lower_function_constructor_call_after_predeclared_argument(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  sibling_argument : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle? raise WgslIrLowerError {
  match node.kind() {
    Group(inner) =>
      self.lower_function_constructor_call_after_predeclared_argument(
        inner, sibling_argument, function, scope,
      )
    Call(callee, arguments) => {
      let arguments = wgsl_ir_call_arguments(arguments)
      match callee.kind() {
        Identifier(name) => {
          guard self.expression_callee_is_constructor_call_value(callee) else {
            return None
          }
          let expression_mark = function.expressions.items.length()
          let lowered_arguments = self.lower_function_constructor_arguments_with_expected(
            arguments,
            function,
            scope,
            None,
          )
          self.predeclare_function_argument_value(
            sibling_argument, function, scope,
          )
          Some(
            self.finish_function_constructor_call(
              name.name(),
              arguments,
              lowered_arguments,
              function,
              scope,
              None,
              expression_mark,
            ),
          )
        }
        _ =>
          match self.lower_templated_callee_type(callee) {
            Some(ty) => {
              let lowered_arguments = self.lower_function_constructor_arguments(
                ty, arguments, function, scope,
              )
              self.predeclare_function_argument_value(
                sibling_argument, function, scope,
              )
              Some(
                self.lower_function_constructor_expression_from_handles(
                  ty, lowered_arguments, function,
                ),
              )
            }
            None => None
          }
      }
    }
    _ => None
  }
}

///|
fn WgslIrLowerer::expression_node_is_writer_deferred_const_like(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  scope : WgslIrFunctionScope,
) -> Bool {
  match node.kind() {
    Group(inner) =>
      self.expression_node_is_writer_deferred_const_like(inner, scope)
    Literal(_) => true
    Identifier(_) =>
      self.expression_node_is_inline_constant_reference(node, scope)
    Binary(_, left, right) =>
      self.expression_node_is_writer_deferred_const_like(left, scope) &&
      self.expression_node_is_writer_deferred_const_like(right, scope)
    _ => false
  }
}

///|
fn WgslIrLowerer::expression_node_is_foldable_math_const_like(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  scope : WgslIrFunctionScope,
) -> Bool {
  match node.kind() {
    Group(inner) =>
      self.expression_node_is_foldable_math_const_like(inner, scope)
    Unary(_, inner) =>
      self.expression_node_is_foldable_math_const_like(inner, scope)
    Binary(_, left, right) =>
      self.expression_node_is_foldable_math_const_like(left, scope) &&
      self.expression_node_is_foldable_math_const_like(right, scope)
    _ => self.expression_node_is_writer_deferred_const_like(node, scope)
  }
}

///|
fn WgslIrLowerer::expression_node_is_float_vector_const_fold_candidate(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  scope : WgslIrFunctionScope,
) -> Bool {
  match node.kind() {
    Group(inner) =>
      self.expression_node_is_float_vector_const_fold_candidate(inner, scope)
    Literal(_) => true
    Identifier(_) =>
      self.expression_node_is_inline_constant_reference(node, scope)
    Unary(op, inner) =>
      op == Subtract &&
      self.expression_node_is_float_vector_const_fold_candidate(inner, scope)
    Binary(_, left, right) =>
      self.expression_node_is_float_vector_const_fold_candidate(left, scope) &&
      self.expression_node_is_float_vector_const_fold_candidate(right, scope)
    Call(callee, arguments) =>
      self.expression_callee_is_constructor_call_value(callee) &&
      wgsl_ir_call_arguments(arguments).all(fn(argument) {
        self.expression_node_is_float_vector_const_fold_candidate(
          argument, scope,
        )
      })
    _ => false
  }
}

///|
fn WgslIrLowerer::expression_node_contains_constructor_call_value(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
) -> Bool {
  match node.kind() {
    Group(inner) | Unary(_, inner) =>
      self.expression_node_contains_constructor_call_value(inner)
    Binary(_, left, right) =>
      self.expression_node_contains_constructor_call_value(left) ||
      self.expression_node_contains_constructor_call_value(right)
    Call(callee, arguments) =>
      self.expression_callee_is_constructor_call_value(callee) ||
      wgsl_ir_call_arguments(arguments).any(fn(argument) {
        self.expression_node_contains_constructor_call_value(argument)
      })
    _ => false
  }
}

///|
fn WgslIrLowerer::expression_node_is_inline_constant_reference(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  scope : WgslIrFunctionScope,
) -> Bool {
  match node.kind() {
    Group(inner) =>
      self.expression_node_is_inline_constant_reference(inner, scope)
    Identifier(name) =>
      scope.local_constants.contains(name.name()) ||
      self.constant_declarations.contains(name.name()) ||
      self.constant_names.contains(name.name())
    _ => false
  }
}

///|
fn wgsl_ir_ast_binary_operator_is_multiplicative(
  op : @ast.WgslExprOperator,
) -> Bool {
  match op {
    Multiply | Divide | Modulo => true
    _ => false
  }
}

///|
fn wgsl_ir_ast_binary_operator_is_comparison(
  op : @ast.WgslExprOperator,
) -> Bool {
  match op {
    Equal | NotEqual | Less | LessEqual | Greater | GreaterEqual => true
    _ => false
  }
}

///|
fn wgsl_ir_direct_access_chain_root_is_function_argument(
  node : @ast.WgslExprNode,
  scope : WgslIrFunctionScope,
) -> Bool {
  match node.kind() {
    Group(inner) =>
      wgsl_ir_direct_access_chain_root_is_function_argument(inner, scope)
    Member(base, _) | Index(base, _) =>
      wgsl_ir_direct_access_chain_root_is_function_argument(base, scope)
    Identifier(name) => scope.arguments.contains(name.name())
    _ => false
  }
}

///|
fn WgslIrLowerer::direct_access_chain_root_is_global_reference(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
) -> Bool {
  match node.kind() {
    Group(inner) => self.direct_access_chain_root_is_global_reference(inner)
    Member(base, _) | Index(base, _) =>
      self.direct_access_chain_root_is_global_reference(base)
    Identifier(name) => self.global_names.get(name.name()) != None
    _ => false
  }
}

///|
fn wgsl_ir_expr_node_contains_call_member_access(
  node : @ast.WgslExprNode,
) -> Bool {
  match node.kind() {
    Group(inner) | Unary(_, inner) | PostfixUpdate(_, inner) =>
      wgsl_ir_expr_node_contains_call_member_access(inner)
    Binary(_, left, right) | Assignment(_, left, right) | Index(left, right) =>
      wgsl_ir_expr_node_contains_call_member_access(left) ||
      wgsl_ir_expr_node_contains_call_member_access(right)
    Member(base, _) | PathAccess(base, _) | Template(base, _) =>
      wgsl_ir_expr_node_contains_call_member_access(base)
    Call(callee, arguments) => {
      let arguments = wgsl_ir_call_arguments(arguments)
      wgsl_ir_expr_node_contains_member_access(callee) ||
      arguments.any(fn(argument) {
        wgsl_ir_expr_node_contains_member_access(argument)
      })
    }
    Sequence(items) =>
      items.any(fn(item) { wgsl_ir_expr_node_contains_call_member_access(item) })
    Identifier(_) | Literal(_) | ShaderDefTemplate(_) => false
  }
}

///|
fn WgslIrLowerer::expression_node_is_constructor_call_value(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
) -> Bool {
  match node.kind() {
    Group(inner) => self.expression_node_is_constructor_call_value(inner)
    Call(callee, _) => self.expression_callee_is_constructor_call_value(callee)
    _ => false
  }
}

///|
fn WgslIrLowerer::expression_callee_is_constructor_call_value(
  self : WgslIrLowerer,
  callee : @ast.WgslExprNode,
) -> Bool {
  match callee.kind() {
    Group(inner) => self.expression_callee_is_constructor_call_value(inner)
    Identifier(name) =>
      self.type_cache.contains(name.name()) ||
      wgsl_ir_untemplated_constructor_name_is_const(name.name())
    Template(base, _) => self.expression_callee_is_constructor_call_value(base)
    _ => false
  }
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
fn wgsl_ir_expr_node_contains_function_argument_value(
  node : @ast.WgslExprNode,
  scope : WgslIrFunctionScope,
) -> Bool {
  match node.kind() {
    Identifier(name) => scope.arguments.contains(name.name())
    Group(inner) =>
      wgsl_ir_expr_node_contains_function_argument_value(inner, scope)
    Unary(_, expr) | PostfixUpdate(_, expr) =>
      wgsl_ir_expr_node_contains_function_argument_value(expr, scope)
    Binary(_, left, right) | Assignment(_, left, right) | Index(left, right) =>
      wgsl_ir_expr_node_contains_function_argument_value(left, scope) ||
      wgsl_ir_expr_node_contains_function_argument_value(right, scope)
    Member(base, _) | PathAccess(base, _) | Template(base, _) =>
      wgsl_ir_expr_node_contains_function_argument_value(base, scope)
    Call(_, arguments) | Sequence(arguments) =>
      arguments.any(fn(argument) {
        wgsl_ir_expr_node_contains_function_argument_value(argument, scope)
      })
    Literal(_) | ShaderDefTemplate(_) => false
  }
}

///|
fn wgsl_ir_expr_node_contains_function_argument_math_call(
  node : @ast.WgslExprNode,
  scope : WgslIrFunctionScope,
) -> Bool {
  match node.kind() {
    Call(callee, arguments) => {
      let arguments = wgsl_ir_call_arguments(arguments)
      match callee.kind() {
        Identifier(name) if wgsl_ir_math_function_from_name(name.name()) != None =>
          arguments.any(fn(argument) {
            wgsl_ir_expr_node_contains_function_argument_value(argument, scope)
          })
        _ =>
          arguments.any(fn(argument) {
            wgsl_ir_expr_node_contains_function_argument_math_call(
              argument, scope,
            )
          })
      }
    }
    Group(inner) | Unary(_, inner) | PostfixUpdate(_, inner) =>
      wgsl_ir_expr_node_contains_function_argument_math_call(inner, scope)
    Binary(_, left, right) | Assignment(_, left, right) | Index(left, right) =>
      wgsl_ir_expr_node_contains_function_argument_math_call(left, scope) ||
      wgsl_ir_expr_node_contains_function_argument_math_call(right, scope)
    Member(base, _) | PathAccess(base, _) | Template(base, _) =>
      wgsl_ir_expr_node_contains_function_argument_math_call(base, scope)
    Sequence(items) =>
      items.any(fn(item) {
        wgsl_ir_expr_node_contains_function_argument_math_call(item, scope)
      })
    Identifier(_) | Literal(_) | ShaderDefTemplate(_) => false
  }
}

///|
fn wgsl_ir_expr_node_contains_call(node : @ast.WgslExprNode) -> Bool {
  match node.kind() {
    Call(_, _) => true
    Group(inner) | Unary(_, inner) | PostfixUpdate(_, inner) =>
      wgsl_ir_expr_node_contains_call(inner)
    Binary(_, left, right) | Assignment(_, left, right) | Index(left, right) =>
      wgsl_ir_expr_node_contains_call(left) ||
      wgsl_ir_expr_node_contains_call(right)
    Member(base, _) | PathAccess(base, _) | Template(base, _) =>
      wgsl_ir_expr_node_contains_call(base)
    Sequence(items) =>
      items.any(fn(item) { wgsl_ir_expr_node_contains_call(item) })
    Identifier(_) | Literal(_) | ShaderDefTemplate(_) => false
  }
}

///|
fn wgsl_ir_expr_node_contains_non_math_call(node : @ast.WgslExprNode) -> Bool {
  match node.kind() {
    Call(callee, arguments) => {
      let arguments = wgsl_ir_call_arguments(arguments)
      let callee_is_math = match callee.kind() {
        Identifier(name) => wgsl_ir_math_function_from_name(name.name()) != None
        _ => false
      }
      !callee_is_math ||
      arguments.any(fn(argument) {
        wgsl_ir_expr_node_contains_non_math_call(argument)
      })
    }
    Group(inner) | Unary(_, inner) | PostfixUpdate(_, inner) =>
      wgsl_ir_expr_node_contains_non_math_call(inner)
    Binary(_, left, right) | Assignment(_, left, right) | Index(left, right) =>
      wgsl_ir_expr_node_contains_non_math_call(left) ||
      wgsl_ir_expr_node_contains_non_math_call(right)
    Member(base, _) | PathAccess(base, _) | Template(base, _) =>
      wgsl_ir_expr_node_contains_non_math_call(base)
    Sequence(items) =>
      items.any(fn(item) { wgsl_ir_expr_node_contains_non_math_call(item) })
    Identifier(_) | Literal(_) | ShaderDefTemplate(_) => false
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
fn WgslIrLowerer::expression_node_contains_writer_reference_value(
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
      self.expression_node_contains_writer_reference_value(
        inner, function, scope,
      )
    Identifier(name) =>
      scope.arguments.contains(name.name()) ||
      scope.local_constants.contains(name.name())
    Binary(_, left, right) | Assignment(_, left, right) | Index(left, right) =>
      self.expression_node_contains_writer_reference_value(
        left, function, scope,
      ) ||
      self.expression_node_contains_writer_reference_value(
        right, function, scope,
      )
    Member(base, _) | PathAccess(base, _) | Template(base, _) =>
      self.expression_node_contains_writer_reference_value(
        base, function, scope,
      )
    Call(callee, arguments) => {
      let arguments = wgsl_ir_call_arguments(arguments)
      self.expression_node_contains_writer_reference_value(
        callee, function, scope,
      ) ||
      arguments.any(fn(argument) {
        self.expression_node_contains_writer_reference_value(
          argument, function, scope,
        )
      })
    }
    Sequence(items) =>
      items.any(fn(item) {
        self.expression_node_contains_writer_reference_value(
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
    Sequence([single]) => wgsl_ir_expr_node_is_literal_like(single)
    _ => false
  }
}

///|
fn wgsl_ir_expr_node_is_negative_literal_like(node : @ast.WgslExprNode) -> Bool {
  match node.kind() {
    Group(inner) | Sequence([inner]) =>
      wgsl_ir_expr_node_is_negative_literal_like(inner)
    Unary(Subtract, inner) => wgsl_ir_expr_node_is_literal_like(inner)
    _ => false
  }
}

///|
fn wgsl_ir_expr_node_is_binary_source_let_arithmetic(
  node : @ast.WgslExprNode,
  scope : WgslIrFunctionScope,
) -> Bool {
  match wgsl_ir_expr_node_without_groups(node).kind() {
    Binary(_, _, _) =>
      wgsl_ir_expr_node_references_local_let_constant(node, scope)
    _ => false
  }
}

///|
fn wgsl_ir_expr_node_is_deferred_select_value(node : @ast.WgslExprNode) -> Bool {
  match node.kind() {
    Literal(_) => true
    Group(inner) => wgsl_ir_expr_node_is_deferred_select_value(inner)
    Unary(op, inner) =>
      op == Subtract && wgsl_ir_expr_node_is_deferred_select_value(inner)
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
fn WgslIrLowerer::expression_node_contains_mutable_local_reference(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Bool {
  if self.expression_node_is_mutable_local_value(node, function, scope) {
    return true
  }
  match node.kind() {
    Group(inner) | Unary(_, inner) | PostfixUpdate(_, inner) =>
      self.expression_node_contains_mutable_local_reference(
        inner, function, scope,
      )
    Binary(_, left, right) | Assignment(_, left, right) | Index(left, right) =>
      self.expression_node_contains_mutable_local_reference(
        left, function, scope,
      ) ||
      self.expression_node_contains_mutable_local_reference(
        right, function, scope,
      )
    Member(base, _) | PathAccess(base, _) | Template(base, _) =>
      self.expression_node_contains_mutable_local_reference(
        base, function, scope,
      )
    Call(callee, arguments) => {
      if self.expression_node_contains_mutable_local_reference(
          callee, function, scope,
        ) {
        return true
      }
      for argument in wgsl_ir_call_arguments(arguments) {
        if self.expression_node_contains_mutable_local_reference(
            argument, function, scope,
          ) {
          return true
        }
      }
      false
    }
    Sequence(items) => {
      for item in items {
        if self.expression_node_contains_mutable_local_reference(
            item, function, scope,
          ) {
          return true
        }
      }
      false
    }
    Identifier(_) | Literal(_) | ShaderDefTemplate(_) => false
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
  match self.shift_amount_expected_type(op, left_ty) {
    Some(expected_ty) =>
      self.contextualize_function_expression_for_type(
        function, right, expected_ty,
      )
    None => ()
  }
  self.contextualize_function_binary_operand_pair(
    function, op, left, left_ty, right, right_ty,
  )
  guard wgsl_ir_binary_operator_requires_vector_splat(op) else {
    return (left, right)
  }
  match self.vector_size_from_type(left_ty) {
    Some(size) if self.type_is_scalar(right_ty) =>
      (left, function.expressions.append(Splat(size, right)))
    _ =>
      match self.vector_size_from_type(right_ty) {
        Some(size) if self.type_is_scalar(left_ty) =>
          (function.expressions.append(Splat(size, left)), right)
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
  if op == Multiply {
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
fn WgslIrLowerer::shift_amount_expected_type(
  self : WgslIrLowerer,
  op : BinaryOperator,
  left_ty : Handle,
) -> Handle? {
  match op {
    ShiftLeft | ShiftRight => {
      let u32_ty = match self.type_cache.get("u32") {
        Some(ty) => ty
        None => return None
      }
      match self.vector_size_from_type(left_ty) {
        Some(size) => self.vector_type_from_scalar_type_handle(size, u32_ty)
        None => Some(u32_ty)
      }
    }
    _ => None
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
