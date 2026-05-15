///|
fn WgslIrLowerer::lower_global_expression_ref(
  self : WgslIrLowerer,
  expr_ref : @ast.WgslExprRef,
) -> Handle raise WgslIrLowerError {
  self.lower_global_expression_ref_with_expected(expr_ref, None)
}

///|
fn WgslIrLowerer::lower_global_expression_ref_with_expected(
  self : WgslIrLowerer,
  expr_ref : @ast.WgslExprRef,
  expected_ty : Handle?,
) -> Handle raise WgslIrLowerError {
  guard expr_ref.root() is Some(root) else {
    raise WgslIrLowerError::UnsupportedExpression("empty global expression")
  }
  self.lower_global_expression_node_with_expected(root, expected_ty)
}

///|
fn WgslIrLowerer::lower_global_expression_node(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
) -> Handle raise WgslIrLowerError {
  self.lower_global_expression_node_with_expected(node, None)
}

///|
fn WgslIrLowerer::lower_global_expression_node_with_expected(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  expected_ty : Handle?,
) -> Handle raise WgslIrLowerError {
  self.shader_module.append_global_expression(
    self.lower_expression_node_to_global_expression_with_expected(
      node, expected_ty,
    ),
  )
}

///|
fn WgslIrLowerer::lower_expression_node_to_global_expression_with_expected(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  expected_ty : Handle?,
) -> Expression raise WgslIrLowerError {
  match node.kind() {
    Literal(token) =>
      Expression::Literal(
        self.literal_from_token_with_expected(token, expected_ty),
      )
    Identifier(name) => self.global_identifier_expression(name)
    Unary(op, expr) =>
      if op == @ast.WgslExprOperator::Subtract {
        match expr.kind() {
          Literal(token) =>
            match
              self.negated_literal_from_token_with_expected(token, expected_ty) {
              Some(literal) => Expression::Literal(literal)
              None =>
                Expression::Unary(
                  wgsl_ir_unary_operator(op),
                  self.lower_global_expression_node(expr),
                )
            }
          _ =>
            Expression::Unary(
              wgsl_ir_unary_operator(op),
              self.lower_global_expression_node(expr),
            )
        }
      } else {
        Expression::Unary(
          wgsl_ir_unary_operator(op),
          self.lower_global_expression_node(expr),
        )
      }
    Binary(op, left, right) => {
      let binary_op = wgsl_ir_binary_operator(op)
      let left_handle = self.lower_global_expression_node(left)
      let right_handle = self.lower_global_expression_node(right)
      let (left_handle, right_handle) = self.normalize_global_binary_operands(
        binary_op, left_handle, right_handle,
      )
      Expression::Binary(binary_op, left_handle, right_handle)
    }
    Group(expr) =>
      self.lower_expression_node_to_global_expression_with_expected(
        expr, expected_ty,
      )
    Sequence([single]) =>
      self.lower_expression_node_to_global_expression_with_expected(
        single, expected_ty,
      )
    Member(base, member_name) => {
      let base_handle = self.lower_global_expression_node(base)
      Expression::AccessIndex(
        base_handle,
        self.member_index_for_global_expression(base_handle, member_name.name()),
      )
    }
    Index(base, index) =>
      Expression::Access(
        self.lower_global_expression_node(base),
        self.lower_global_expression_node(index),
      )
    Call(callee, arguments) => {
      let arguments = wgsl_ir_call_arguments(arguments)
      match self.lower_bitcast_callee_type(callee) {
        Some(ty) => self.lower_global_bitcast_call(ty, arguments)
        None =>
          match callee.kind() {
            Identifier(name) =>
              if name.name() == "select" {
                self.lower_global_select_call(arguments)
              } else if wgsl_ir_barrier_builtin_from_name(name.name())
                is Some(_) {
                raise wgsl_ir_barrier_value_error(name.name())
              } else {
                match wgsl_ir_math_function_from_name(name.name()) {
                  Some(math_function) =>
                    self.lower_global_math_call(math_function, arguments)
                  None =>
                    match wgsl_ir_relational_function_from_name(name.name()) {
                      Some(relational_function) =>
                        self.lower_global_relational_call(
                          relational_function, arguments,
                        )
                      None =>
                        if name.name() == "array" {
                          self.lower_global_array_constructor_call(
                            expected_ty, arguments,
                          )
                        } else {
                          let ty = match
                            self.expected_constructor_type(
                              name.name(),
                              expected_ty,
                            ) {
                            Some(ty) => ty
                            None =>
                              self.lower_untemplated_constructor_type_from_ast(
                                name.name(),
                                arguments,
                                name.name(),
                              )
                          }
                          Expression::Compose(
                            ty,
                            self.lower_global_expression_arguments(arguments),
                          )
                        }
                    }
                }
              }
            _ =>
              match self.lower_templated_callee_type(callee) {
                Some(ty) =>
                  Expression::Compose(
                    ty,
                    self.lower_global_constructor_arguments(ty, arguments),
                  )
                None =>
                  raise WgslIrLowerError::UnsupportedExpression(
                    "non-identifier global call expression: \{wgsl_ir_expr_node_shape(callee)}",
                  )
              }
          }
      }
    }
    _ =>
      raise WgslIrLowerError::UnsupportedExpression(
        "global expression kind is not constant-lowerable",
      )
  }
}

///|
fn WgslIrLowerer::normalize_global_binary_operands(
  self : WgslIrLowerer,
  op : BinaryOperator,
  left : Handle,
  right : Handle,
) -> (Handle, Handle) {
  guard wgsl_ir_binary_operator_requires_vector_splat(op) else {
    return (left, right)
  }
  guard self.global_expression_type(left) is Some(left_ty) else {
    return (left, right)
  }
  guard self.global_expression_type(right) is Some(right_ty) else {
    return (left, right)
  }
  match self.vector_size_from_type(left_ty) {
    Some(size) if self.type_is_scalar(right_ty) =>
      (
        left,
        self.shader_module.global_expressions.append(
          Expression::Splat(size, right),
        ),
      )
    _ =>
      match self.vector_size_from_type(right_ty) {
        Some(size) if self.type_is_scalar(left_ty) =>
          (
            self.shader_module.global_expressions.append(
              Expression::Splat(size, left),
            ),
            right,
          )
        _ => (left, right)
      }
  }
}

///|
fn WgslIrLowerer::lower_global_select_call(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
) -> Expression raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments is [reject, accept, condition] else {
    raise WgslIrLowerError::UnsupportedExpression(
      "select expects three arguments",
    )
  }
  Expression::Select(
    self.lower_global_expression_node(condition),
    self.lower_global_expression_node(accept),
    self.lower_global_expression_node(reject),
  )
}

///|
fn WgslIrLowerer::lower_global_bitcast_call(
  self : WgslIrLowerer,
  ty : Handle,
  arguments : Array[@ast.WgslExprNode],
) -> Expression raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments is [expr] else {
    raise WgslIrLowerError::UnsupportedExpression(
      "bitcast expects one argument",
    )
  }
  Expression::Bitcast(ty, self.lower_global_expression_node(expr))
}

///|
fn WgslIrLowerer::lower_global_array_constructor_call(
  self : WgslIrLowerer,
  expected_ty : Handle?,
  arguments : Array[@ast.WgslExprNode],
) -> Expression raise WgslIrLowerError {
  let ty = match expected_ty {
    Some(ty) => ty
    None => self.infer_array_constructor_type_from_ast(arguments, "array")
  }
  guard self.array_element_type(ty) is Some(element_ty) else {
    raise WgslIrLowerError::UnsupportedType("array")
  }
  Expression::Compose(
    ty,
    self.lower_global_expression_arguments_with_expected(
      arguments,
      Some(element_ty),
    ),
  )
}

///|
fn WgslIrLowerer::lower_global_expression_arguments(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
) -> Array[Handle] raise WgslIrLowerError {
  self.lower_global_expression_arguments_with_expected(arguments, None)
}

///|
fn WgslIrLowerer::lower_global_expression_arguments_with_expected(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  expected_ty : Handle?,
) -> Array[Handle] raise WgslIrLowerError {
  let handles : Array[Handle] = []
  for argument in wgsl_ir_flatten_expression_arguments(arguments) {
    handles.push(
      self.lower_global_expression_node_with_expected(argument, expected_ty),
    )
  }
  handles
}

///|
fn WgslIrLowerer::lower_global_constructor_arguments(
  self : WgslIrLowerer,
  ty : Handle,
  arguments : Array[@ast.WgslExprNode],
) -> Array[Handle] raise WgslIrLowerError {
  self.lower_global_expression_arguments_with_expected(
    arguments,
    self.constructor_component_expected_type(ty),
  )
}

///|
fn WgslIrLowerer::lower_global_math_call(
  self : WgslIrLowerer,
  math_function : MathFunction,
  arguments : Array[@ast.WgslExprNode],
) -> Expression raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments is [first, .. rest] else {
    raise WgslIrLowerError::UnsupportedExpression(
      "math call requires at least one argument",
    )
  }
  let a = self.lower_global_expression_node(first)
  let b = match rest {
    [value, ..] => Some(self.lower_global_expression_node(value))
    [] => None
  }
  let c = match rest {
    [_, value, ..] => Some(self.lower_global_expression_node(value))
    _ => None
  }
  let d = match rest {
    [_, _, value, ..] => Some(self.lower_global_expression_node(value))
    _ => None
  }
  Expression::Math(math_function, a, b, c, d)
}

///|
fn WgslIrLowerer::lower_global_relational_call(
  self : WgslIrLowerer,
  relational_function : RelationalFunction,
  arguments : Array[@ast.WgslExprNode],
) -> Expression raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments is [expr] else {
    raise WgslIrLowerError::UnsupportedExpression(
      "\{wgsl_ir_relational_function_name(relational_function)} expects one argument",
    )
  }
  Expression::Relational(
    relational_function,
    self.lower_global_expression_node(expr),
  )
}
