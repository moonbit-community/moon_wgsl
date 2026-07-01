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
    raise UnsupportedExpression(
      "\{wgsl_ir_relational_function_name(relational_function)} expects one argument",
    )
  }
  let argument = self.lower_function_relational_argument(expr, function, scope)
  function.expressions.append(
    Relational(
      relational_function,
      self.apply_function_load_rule(function, argument),
    ),
  )
}

///|
fn WgslIrLowerer::lower_function_relational_argument(
  self : WgslIrLowerer,
  expr : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  match wgsl_ir_expr_node_without_groups(expr).kind() {
    Binary(op, left, right) if wgsl_ir_ast_binary_operator_is_comparison(op) => {
      let expression_mark = function.expressions.items.length()
      let local_constant_snapshot = wgsl_ir_snapshot_local_constant_values(
        scope.local_constants,
      )
      let left_handle = self.lower_function_expression_node(
        left, function, scope,
      )
      let right_handle = self.lower_function_expression_node(
        right, function, scope,
      )
      let binary_op = wgsl_ir_binary_operator(op)
      let (left_handle, right_handle) = self.normalize_function_binary_operands(
        function, binary_op, left_handle, right_handle,
      )
      let handle = function.expressions.append(
        Binary(binary_op, left_handle, right_handle),
      )
      self.fold_function_binary_expression_at_mark(
        function, scope, local_constant_snapshot, expression_mark, handle,
      )
    }
    _ => self.lower_function_expression_node(expr, function, scope)
  }
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
    raise UnsupportedExpression("select expects three arguments")
  }
  match
    self.lower_function_select_with_splat_values_and_binary_splat_condition(
      reject, accept, condition, function, scope,
    ) {
    Some(handle) => return handle
    None => ()
  }
  match
    self.lower_function_select_with_constant_constructor_values_and_binary_condition(
      reject, accept, condition, function, scope,
    ) {
    Some(handle) => return handle
    None => ()
  }
  match
    self.lower_function_select_with_constant_values_and_binary_condition(
      reject, accept, condition, function, scope,
    ) {
    Some(handle) => return handle
    None => ()
  }
  let (condition, accept, reject) = if wgsl_ir_expr_node_is_deferred_select_value(
      reject,
    ) &&
    wgsl_ir_expr_node_is_deferred_select_value(accept) {
    let condition = self.lower_function_expression_node(
      condition, function, scope,
    )
    let accept = self.lower_function_expression_node(accept, function, scope)
    let reject = self.lower_function_expression_node(reject, function, scope)
    (condition, accept, reject)
  } else if self.select_accept_predeclares_reference_root(
      accept, function, scope,
    ) {
    self.predeclare_function_member_root_expression(accept, function, scope)
    let condition = self.lower_function_expression_node(
      condition, function, scope,
    )
    let reject = self.lower_function_expression_node(reject, function, scope)
    let accept = self.lower_function_expression_node(accept, function, scope)
    (condition, accept, reject)
  } else {
    let reject = self.lower_function_expression_node(reject, function, scope)
    let accept = self.lower_function_expression_node(accept, function, scope)
    let condition = self.lower_function_expression_node(
      condition, function, scope,
    )
    (condition, accept, reject)
  }
  function.expressions.append(Select(condition, accept, reject))
}

///|
fn WgslIrLowerer::lower_function_select_with_splat_values_and_binary_splat_condition(
  self : WgslIrLowerer,
  reject : @ast.WgslExprNode,
  accept : @ast.WgslExprNode,
  condition : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle? raise WgslIrLowerError {
  guard self.expression_node_is_select_constant_vector_splat_value(reject) else {
    return None
  }
  guard self.expression_node_is_select_constant_vector_splat_value(accept) else {
    return None
  }
  let (condition_op, condition_left, condition_right) = match condition.kind() {
    Binary(op, left, right) => (op, left, right)
    Group(inner) =>
      match inner.kind() {
        Binary(op, left, right) => (op, left, right)
        _ => return None
      }
    _ => return None
  }
  guard self.expression_node_is_select_constant_vector_splat_value(
    condition_right,
  ) else {
    return None
  }
  let reject_handle = self.lower_function_expression_node(
    reject, function, scope,
  )
  let accept_handle = self.lower_function_expression_node(
    accept, function, scope,
  )
  guard self.prelower_select_constant_vector_splat_component(
      condition_right, function, scope,
    )
    is Some(right_splat) else {
    return None
  }
  let left_handle = self.lower_function_expression_node(
    condition_left, function, scope,
  )
  let right_handle = self.lower_function_constructor_expression_from_handles(
    right_splat.ty,
    [right_splat.component],
    function,
  )
  let binary_op = wgsl_ir_binary_operator(condition_op)
  let (left_handle, right_handle) = self.normalize_function_binary_operands(
    function, binary_op, left_handle, right_handle,
  )
  let condition_handle = function.expressions.append(
    Binary(binary_op, left_handle, right_handle),
  )
  Some(
    function.expressions.append(
      Select(condition_handle, accept_handle, reject_handle),
    ),
  )
}

///|
fn WgslIrLowerer::prelower_select_constant_vector_splat_component(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> WgslIrDeferredConstructorArgument? raise WgslIrLowerError {
  match node.kind() {
    Group(inner) =>
      self.prelower_select_constant_vector_splat_component(
        inner, function, scope,
      )
    Call(callee, constructor_arguments) => {
      guard wgsl_ir_flatten_expression_arguments(
          wgsl_ir_call_arguments(constructor_arguments),
        )
        is [component] else {
        return None
      }
      guard self.expression_node_is_select_constant_value(component) else {
        return None
      }
      guard self.lower_math_splat_constructor_callee_type(
          callee, constructor_arguments,
        )
        is Some(ty) else {
        return None
      }
      guard self.vector_size_from_type(ty) is Some(_) else { return None }
      let expected_ty = self.constructor_component_expected_type(ty)
      let component = self.lower_function_constructor_argument(
        component, function, scope, expected_ty,
      )
      Some({ ty, component })
    }
    _ => None
  }
}

///|
fn WgslIrLowerer::lower_function_select_with_constant_constructor_values_and_binary_condition(
  self : WgslIrLowerer,
  reject : @ast.WgslExprNode,
  accept : @ast.WgslExprNode,
  condition : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle? raise WgslIrLowerError {
  guard self.expression_node_is_select_constant_constructor_value(reject) else {
    return None
  }
  guard self.expression_node_is_select_constant_constructor_value(accept) else {
    return None
  }
  match condition.kind() {
    Binary(_, _, _) => ()
    Group(inner) =>
      match inner.kind() {
        Binary(_, _, _) => ()
        _ => return None
      }
    _ => return None
  }
  let condition_handle = self.lower_function_expression_node(
    condition, function, scope,
  )
  let reject_handle = self.lower_function_expression_node(
    reject, function, scope,
  )
  let accept_handle = self.lower_function_expression_node(
    accept, function, scope,
  )
  Some(
    function.expressions.append(
      Select(condition_handle, accept_handle, reject_handle),
    ),
  )
}

///|
fn WgslIrLowerer::lower_function_select_with_constant_values_and_binary_condition(
  self : WgslIrLowerer,
  reject : @ast.WgslExprNode,
  accept : @ast.WgslExprNode,
  condition : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle? raise WgslIrLowerError {
  guard self.expression_node_is_select_constant_value(reject) else {
    return None
  }
  guard self.expression_node_is_select_constant_value(accept) else {
    return None
  }
  let (condition_op, condition_left, condition_right) = match condition.kind() {
    Binary(op, left, right) => (op, left, right)
    Group(inner) =>
      match inner.kind() {
        Binary(op, left, right) => (op, left, right)
        _ => return None
      }
    _ => return None
  }
  let left_handle = self.lower_function_expression_node(
    condition_left, function, scope,
  )
  let right_handle = self.lower_function_expression_node(
    condition_right, function, scope,
  )
  let binary_op = wgsl_ir_binary_operator(condition_op)
  let (left_handle, right_handle) = self.normalize_function_binary_operands(
    function, binary_op, left_handle, right_handle,
  )
  let condition_handle = function.expressions.append(
    Binary(binary_op, left_handle, right_handle),
  )
  let accept_handle = self.lower_function_expression_node(
    accept, function, scope,
  )
  let reject_handle = self.lower_function_expression_node(
    reject, function, scope,
  )
  Some(
    function.expressions.append(
      Select(condition_handle, accept_handle, reject_handle),
    ),
  )
}

///|
fn WgslIrLowerer::expression_node_is_select_constant_constructor_value(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
) -> Bool {
  match node.kind() {
    Group(inner) =>
      self.expression_node_is_select_constant_constructor_value(inner)
    Call(callee, arguments) => {
      guard self.expression_callee_is_constructor_call_value(callee) else {
        return false
      }
      let arguments = wgsl_ir_flatten_expression_arguments(
        wgsl_ir_call_arguments(arguments),
      )
      arguments.all(fn(argument) {
        self.expression_node_is_select_constant_value(argument)
      })
    }
    _ => false
  }
}

///|
fn WgslIrLowerer::expression_node_is_select_constant_vector_splat_value(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
) -> Bool {
  match node.kind() {
    Group(inner) =>
      self.expression_node_is_select_constant_vector_splat_value(inner)
    Call(callee, arguments) => {
      guard wgsl_ir_flatten_expression_arguments(
          wgsl_ir_call_arguments(arguments),
        )
        is [argument] else {
        return false
      }
      guard self.expression_node_is_select_constant_value(argument) else {
        return false
      }
      match callee.kind() {
        Identifier(name) =>
          wgsl_ir_vector_size_from_constructor_name(name.name()) != None
        Template(base, _) =>
          self.expression_node_is_select_constant_vector_splat_callee(base)
        Group(inner) =>
          self.expression_node_is_select_constant_vector_splat_callee(inner)
        _ => false
      }
    }
    _ => false
  }
}

///|
fn WgslIrLowerer::expression_node_is_select_constant_vector_splat_callee(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
) -> Bool {
  ignore(self)
  match node.kind() {
    Identifier(name) =>
      wgsl_ir_vector_size_from_constructor_name(name.name()) != None
    Template(base, _) =>
      match base.kind() {
        Identifier(name) =>
          wgsl_ir_vector_size_from_constructor_name(name.name()) != None
        _ => false
      }
    Group(inner) =>
      match inner.kind() {
        Identifier(name) =>
          wgsl_ir_vector_size_from_constructor_name(name.name()) != None
        _ => false
      }
    _ => false
  }
}

///|
fn WgslIrLowerer::expression_node_is_select_constant_value(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
) -> Bool {
  match node.kind() {
    Literal(_) => return true
    Group(inner) => return self.expression_node_is_select_constant_value(inner)
    Unary(op, inner) =>
      return op == Subtract &&
        self.expression_node_is_select_constant_value(inner)
    Identifier(name) =>
      return self.constant_names.contains(name.name()) ||
        wgsl_ir_predeclared_u32_constant_literal(name.name()) != None
    _ => return false
  }
}

///|
fn WgslIrLowerer::select_accept_predeclares_reference_root(
  self : WgslIrLowerer,
  accept : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Bool {
  guard wgsl_ir_expr_node_is_direct_access_chain(accept) else { return false }
  guard self.direct_access_chain_root_is_global_reference(accept) else {
    return false
  }
  self.expression_node_contains_writer_reference_value(accept, function, scope) &&
  !wgsl_ir_expr_node_is_function_argument_value(accept, scope)
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
    raise UnsupportedExpression("bitcast expects one argument")
  }
  function.expressions.append(
    Bitcast(ty, self.lower_function_expression_node(expr, function, scope)),
  )
}
