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
        self.lower_function_dynamic_member_index_access(
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
      match
        scope.runtime_source_local_const_initializer_expressions.get(
          wgsl_ir_source_local_const_literal_key(token, expected_ty),
        ) {
        Some(handle) => handle
        None =>
          function.expressions.append(
            Literal(self.literal_from_token_with_expected(token, expected_ty)),
          )
      }
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
      if scheduler.binary_predeclares_left_associative_reference_roots(
          op, left, right,
        ) {
        self.predeclare_function_binary_chain_reference_roots_in_source_order(
          node, function, scope,
        )
      }
      match
        self.lower_function_binary_chain_with_parent_argument_after_member_root(
          op, left, right, function, scope,
        ) {
        Some(handle) => return handle
        None => ()
      }
      match
        self.lower_function_binary_chain_with_parent_argument_after_named_root(
          op, left, right, function, scope,
        ) {
        Some(handle) => return handle
        None => ()
      }
      match
        self.lower_function_binary_chain_with_parent_argument_root_projection(
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
        wgsl_ir_expr_node_contains_call(left) &&
        !wgsl_ir_expr_node_contains_non_math_call(left) &&
        !wgsl_ir_expr_node_contains_non_math_call(right) &&
        wgsl_ir_expr_node_contains_function_argument_value(right, scope) {
        self.predeclare_function_argument_values_in_source_order(
          right, function, scope,
        )
      }
      let (left_handle, right_handle) = if !member_bases_lower_in_source_order &&
        scheduler.binary_right_subtree_has_higher_precedence(op, right) {
        if scheduler.binary_preserves_left_first_across_higher_precedence_right(
            op, left, right,
          ) {
          let left_handle = self.lower_function_expression_node(
            left, function, scope,
          )
          let (right_op, right_left, right_right) = self.lower_binary_expression_children(
            right, function, scope,
          )
          let right_binary_op = wgsl_ir_binary_operator(right_op)
          let (right_left, right_right) = self.normalize_function_binary_operands(
            function, right_binary_op, right_left, right_right,
          )
          let right_handle = function.expressions.append(
            Binary(right_binary_op, right_left, right_right),
          )
          (left_handle, right_handle)
        } else if wgsl_ir_expr_node_is_direct_access_chain(left) ||
          self.expression_node_is_mutable_local_value(left, function, scope) {
          let left_handle = self.lower_function_expression_node(
            left, function, scope,
          )
          let (right_op, right_left, right_right) = self.lower_binary_expression_children(
            right, function, scope,
          )
          let right_binary_op = wgsl_ir_binary_operator(right_op)
          let (right_left, right_right) = self.normalize_function_binary_operands(
            function, right_binary_op, right_left, right_right,
          )
          let right_handle = function.expressions.append(
            Binary(right_binary_op, right_left, right_right),
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
            let (right_op, right_left, right_right) = self.lower_binary_expression_children(
              right, function, scope,
            )
            let right_binary_op = wgsl_ir_binary_operator(right_op)
            let (right_left, right_right) = self.normalize_function_binary_operands(
              function, right_binary_op, right_left, right_right,
            )
            let right_handle = function.expressions.append(
              Binary(right_binary_op, right_left, right_right),
            )
            let left_handle = self.lower_function_expression_node(
              left, function, scope,
            )
            (left_handle, right_handle)
          } else if right_children_lower_before_left {
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
            let right_handle = function.expressions.append(
              Binary(right_binary_op, right_left, right_right),
            )
            (left_handle, right_handle)
          } else {
            let left_handle = self.lower_function_expression_node(
              left, function, scope,
            )
            let (right_op, right_left, right_right) = self.lower_binary_expression_children(
              right, function, scope,
            )
            let right_binary_op = wgsl_ir_binary_operator(right_op)
            let (right_left, right_right) = self.normalize_function_binary_operands(
              function, right_binary_op, right_left, right_right,
            )
            let right_handle = function.expressions.append(
              Binary(right_binary_op, right_left, right_right),
            )
            (left_handle, right_handle)
          }
          (left_handle, right_handle)
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
      let binary_op = wgsl_ir_binary_operator(op)
      let (left_handle, right_handle) = self.normalize_function_binary_operands(
        function, binary_op, left_handle, right_handle,
      )
      let handle = function.expressions.append(
        Binary(binary_op, left_handle, right_handle),
      )
      if scope.source_let_initializer_preserve_depth > 0 &&
        wgsl_ir_expr_node_references_local_let_constant(node, scope) {
        return handle
      }
      match self.fold_function_constant_float_expression(function, handle) {
        Some(literal) => {
          function.expressions.truncate(expression_mark)
          function.expressions.append_with_origin(
            Literal(literal),
            FoldedLocalConstant,
          )
        }
        None => handle
      }
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
fn WgslIrLowerer::lower_function_binary_chain_with_parent_argument_after_named_root(
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
fn WgslIrLowerer::lower_function_binary_chain_with_parent_argument_root_projection(
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
        Some({ value: ExpressionAlias(handle), .. }) =>
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
    let (right_op, right_left, right_right) = self.lower_binary_expression_children(
      right, function, scope,
    )
    let right_binary_op = wgsl_ir_binary_operator(right_op)
    let (right_left, right_right) = self.normalize_function_binary_operands(
      function, right_binary_op, right_left, right_right,
    )
    if parent_op == Divide && wgsl_ir_expr_node_is_literal_like(left) {
      let right_handle = function.expressions.append(
        Binary(right_binary_op, right_left, right_right),
      )
      let left_handle = self.lower_function_expression_node(
        left, function, scope,
      )
      return (left_handle, right_handle)
    }
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
fn WgslIrLowerer::expression_node_is_naga_deferred_const_like(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  scope : WgslIrFunctionScope,
) -> Bool {
  match node.kind() {
    Group(inner) =>
      self.expression_node_is_naga_deferred_const_like(inner, scope)
    Literal(_) => true
    Identifier(_) =>
      self.expression_node_is_inline_constant_reference(node, scope)
    Binary(_, left, right) =>
      self.expression_node_is_naga_deferred_const_like(left, scope) &&
      self.expression_node_is_naga_deferred_const_like(right, scope)
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
    _ => self.expression_node_is_naga_deferred_const_like(node, scope)
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
      self.constant_names.contains(name.name()) ||
      self.generated_import_symbol_is_constant_reference(name.name())
    _ => false
  }
}

///|
fn WgslIrLowerer::generated_import_symbol_is_constant_reference(
  self : WgslIrLowerer,
  name : String,
) -> Bool {
  match self.generated_import_provenance.get(name) {
    Some(provenance) =>
      self.constant_declarations.contains(provenance.source_symbol_name) ||
      self.constant_names.contains(provenance.source_symbol_name)
    None => false
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
    Identifier(name) =>
      scope.arguments.contains(name.name()) ||
      scope.local_constants.contains(name.name())
    Binary(_, left, right) | Assignment(_, left, right) | Index(left, right) =>
      self.expression_node_contains_naga_reference_value(left, function, scope) ||
      self.expression_node_contains_naga_reference_value(right, function, scope)
    Member(base, _) | PathAccess(base, _) | Template(base, _) =>
      self.expression_node_contains_naga_reference_value(base, function, scope)
    Call(callee, arguments) => {
      let arguments = wgsl_ir_call_arguments(arguments)
      self.expression_node_contains_naga_reference_value(
        callee, function, scope,
      ) ||
      arguments.any(fn(argument) {
        self.expression_node_contains_naga_reference_value(
          argument, function, scope,
        )
      })
    }
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
                  raise UnsupportedExpression(
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
        FunctionCall(
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
    raise UnsupportedExpression(
      "\{wgsl_ir_subgroup_function_name(subgroup_function)} expects \{expected} argument(s)",
    )
  }
  let lowered = self.lower_function_expression_arguments(
    arguments, function, scope,
  )
  function.expressions.append(SubgroupCall(subgroup_function, lowered))
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
  let expression_mark = function.expressions.items.length()
  let lowered_arguments = self.lower_function_constructor_arguments_with_expected(
    arguments,
    function,
    scope,
    None,
  )
  self.finish_function_constructor_call(
    name, arguments, lowered_arguments, function, expected_ty, expression_mark,
  )
}

///|
fn WgslIrLowerer::finish_function_constructor_call(
  self : WgslIrLowerer,
  name : String,
  arguments : Array[@ast.WgslExprNode],
  lowered_arguments : Array[Handle],
  function : Function,
  expected_ty : Handle?,
  expression_mark : Int,
) -> Handle raise WgslIrLowerError {
  let ty = match self.expected_constructor_type(name, expected_ty) {
    Some(ty) => ty
    None =>
      self.lower_untemplated_constructor_type_from_handles(
        name, arguments, lowered_arguments, function,
      )
  }
  let folded_scalar_constructor = self.fold_function_scalar_constructor(
    ty, lowered_arguments, function,
  ) catch {
    _ => (None : Literal?)
  }
  match folded_scalar_constructor {
    Some(literal) => {
      wgsl_ir_rewind_function_expressions(function, expression_mark)
      return function.expressions.append(Literal(literal))
    }
    None => ()
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
  match
    self.lower_function_scalar_constructor_expression_from_handles(
      ty, lowered_arguments, function,
    ) {
    Some(handle) => return handle
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
fn WgslIrLowerer::lower_function_scalar_constructor_expression_from_handles(
  self : WgslIrLowerer,
  ty : Handle,
  lowered_arguments : Array[Handle],
  function : Function,
) -> Handle? {
  guard lowered_arguments is [argument] else { return None }
  guard self.scalar_from_numeric_type_handle(ty) is Some(target_scalar) else {
    return None
  }
  guard self.function_expression_type(function, argument) is Some(argument_ty) else {
    return None
  }
  guard self.shader_module.types.get(argument_ty) is Some(type_) else {
    return None
  }
  guard type_.inner is Scalar(argument_scalar) else { return None }
  if target_scalar == argument_scalar {
    None
  } else {
    Some(
      function.expressions.append(
        As(argument, target_scalar.kind, Some(target_scalar.width)),
      ),
    )
  }
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
    raise UnsupportedExpression("derivative call expects one argument")
  }
  let argument = self.lower_function_expression_node(expr, function, scope)
  function.expressions.append(
    Derivative(axis, control, self.apply_function_load_rule(function, argument)),
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
    Some({ value: LazyConstant(local_constant), .. }) => {
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
    Some({ value: ExpressionAlias(handle), .. }) => return handle
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
              Load(scope.local_pointer_expression(name, handle, function)),
            )
          }
        None => raise UnknownIdentifier(name)
      }
    None => ()
  }
  match scope.arguments.get(name) {
    Some(index) => return scope.argument_expression(name, index, function)
    None => ()
  }
  match self.ensure_constant_declaration_lowered(name) {
    Some(handle) =>
      match self.inline_constant_literal_for_function(handle) {
        Some(literal) =>
          return function.expressions.append_with_origin(
            Literal(literal),
            FoldedLocalConstant,
          )
        None => return function.expressions.append(Constant(handle))
      }
    None => ()
  }
  match self.ensure_override_declaration_predeclared(name) {
    Some(handle) => return function.expressions.append(Override(handle))
    None => ()
  }
  match self.global_names.get(name) {
    Some(handle) =>
      if self.global_variable_is_handle_value(handle) {
        scope.global_pointer_expression(name, handle, function, false)
      } else {
        function.expressions.append(
          Load(
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
        Some(literal) => function.expressions.append(Literal(literal))
        None => raise UnknownIdentifier(name)
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
        Some(_) => raise UnsupportedExpression("local const is not addressable")
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
                raise UnsupportedExpression("local let is not addressable")
              }
            None => raise UnknownIdentifier(name.name())
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
            raise UnsupportedExpression("function argument is not addressable")
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
    Group(inner) =>
      self.lower_function_access_base_pointer_node(inner, function, scope)
    Unary(op, expr) =>
      if op == Multiply {
        self.lower_function_expression_node(expr, function, scope)
      } else {
        raise UnsupportedExpression("unsupported addressable access base")
      }
    Member(base, member_name) => {
      let base_handle = self.lower_function_access_base_pointer_node(
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
        self.lower_function_dynamic_member_index_access(
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
          let base_handle = self.lower_function_access_base_pointer_node(
            base, function, scope,
          )
          let index_handle = self.lower_function_expression_node(
            index, function, scope,
          )
          return function.expressions.append(Access(base_handle, index_handle))
        }
      }
      let base_handle = self.lower_function_access_base_pointer_node(
        base, function, scope,
      )
      self.lower_function_static_or_dynamic_index(
        base_handle, index, function, scope,
      )
    }
    _ => raise UnsupportedExpression("unsupported addressable access base")
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
        let (base_handle, index_handle) = if self.expression_node_is_mutable_local_value(
            index, function, scope,
          ) {
          let base_handle = self.lower_function_static_member_access_chain(
            root_handle, members, function,
          )
          let index_handle = self.lower_function_expression_node(
            index, function, scope,
          )
          (base_handle, index_handle)
        } else {
          let index_handle = self.lower_function_expression_node(
            index, function, scope,
          )
          let base_handle = self.lower_function_static_member_access_chain(
            root_handle, members, function,
          )
          (base_handle, index_handle)
        }
        Some(function.expressions.append(Access(base_handle, index_handle)))
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
      AccessIndex(
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
    Unary(op, _) => op == Multiply
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
          RayQueryInitialize(
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
          RayQueryProceed(
            self.lower_function_expression_node(query, function, scope),
          ),
        ),
      )
    }
    "rayQueryGenerateIntersection" => {
      guard arguments is [query, intersection_t] else { return None }
      Some(
        function.expressions.append(
          RayQueryGenerateIntersection(
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
          RayQueryConfirmIntersection(
            self.lower_function_expression_node(query, function, scope),
          ),
        ),
      )
    }
    "rayQueryTerminate" => {
      guard arguments is [query] else { return None }
      Some(
        function.expressions.append(
          RayQueryTerminate(
            self.lower_function_expression_node(query, function, scope),
          ),
        ),
      )
    }
    "rayQueryGetCommittedIntersection" => {
      guard arguments is [query] else { return None }
      Some(
        function.expressions.append(
          RayQueryGetIntersection(
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
          RayQueryGetIntersection(
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
          RayQueryVertexPositions(
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
          RayQueryVertexPositions(
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
  self.lower_function_flattened_constructor_arguments(
    flattened, function, scope, expected_ty,
  )
}

///|
fn WgslIrLowerer::lower_function_constructor_arguments_with_expected(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
  expected_ty : Handle?,
) -> Array[Handle] raise WgslIrLowerError {
  self.lower_function_flattened_constructor_arguments(
    wgsl_ir_flatten_expression_arguments(arguments),
    function,
    scope,
    expected_ty,
  )
}

///|
fn WgslIrLowerer::lower_function_flattened_constructor_arguments(
  self : WgslIrLowerer,
  flattened : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
  expected_ty : Handle?,
) -> Array[Handle] raise WgslIrLowerError {
  let scheduler = self.expression_arena_scheduler(function, scope)
  match
    self.lower_function_constructor_arguments_with_later_local_root_after_first_global_root(
      flattened, function, scope, expected_ty,
    ) {
    Some(handles) => return handles
    None => ()
  }
  if scheduler.constructor_arguments_delay_literals(flattened) {
    return self.lower_function_constructor_arguments_with_delayed_literals(
      flattened, function, scope, expected_ty,
    )
  }
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
fn WgslIrLowerer::lower_function_constructor_arguments_with_later_local_root_after_first_global_root(
  self : WgslIrLowerer,
  flattened : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
  expected_ty : Handle?,
) -> Array[Handle]? raise WgslIrLowerError {
  guard flattened.length() >= 2 else { return None }
  let scheduler = self.expression_arena_scheduler(function, scope)
  guard !scheduler.constructor_argument_has_ordered_effect(flattened[0]) else {
    return None
  }
  guard self.first_global_static_member_root_end(flattened[0]) is Some(root_end) else {
    return None
  }
  guard self.expression_node_contains_mutable_local_root_after(
    flattened[0],
    root_end,
    function,
    scope,
  ) else {
    return None
  }
  guard self.predeclare_first_global_static_member_root(
    flattened[0],
    function,
    scope,
  ) else {
    return None
  }
  guard self.predeclare_first_mutable_local_root_after(
    flattened[0],
    root_end,
    function,
    scope,
  ) else {
    return None
  }
  let handles : Array[Handle] = []
  for index in 0..<flattened.length() {
    handles.push(
      self.lower_function_constructor_argument_value(
        flattened[index],
        function,
        scope,
        expected_ty,
      ),
    )
  }
  Some(handles)
}

///|
fn WgslIrLowerer::first_global_static_member_root_end(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
) -> Int? {
  match node.kind() {
    Member(_, _) =>
      match wgsl_ir_static_member_access_chain(node) {
        Some((root, members)) =>
          if members.length() > 0 &&
            self.expression_node_is_global_reference_value(root) {
            Some(node.end())
          } else {
            None
          }
        None => None
      }
    Group(inner) | Unary(_, inner) | PostfixUpdate(_, inner) =>
      self.first_global_static_member_root_end(inner)
    Binary(_, left, right) | Assignment(_, left, right) | Index(left, right) =>
      match self.first_global_static_member_root_end(left) {
        Some(end_) => Some(end_)
        None => self.first_global_static_member_root_end(right)
      }
    Call(callee, arguments) => {
      let arguments = wgsl_ir_call_arguments(arguments)
      match self.first_global_static_member_root_end(callee) {
        Some(end_) => Some(end_)
        None => {
          for argument in arguments {
            match self.first_global_static_member_root_end(argument) {
              Some(end_) => return Some(end_)
              None => ()
            }
          }
          None
        }
      }
    }
    Sequence(arguments) => {
      for argument in arguments {
        match self.first_global_static_member_root_end(argument) {
          Some(end_) => return Some(end_)
          None => ()
        }
      }
      None
    }
    Template(base, _) | PathAccess(base, _) =>
      self.first_global_static_member_root_end(base)
    Identifier(_) | Literal(_) | ShaderDefTemplate(_) => None
  }
}

///|
fn WgslIrLowerer::predeclare_first_global_static_member_root(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Bool raise WgslIrLowerError {
  match node.kind() {
    Member(_, _) =>
      match wgsl_ir_static_member_access_chain(node) {
        Some((root, members)) =>
          if members.length() > 0 &&
            self.predeclare_global_identifier_root(root, function, scope) {
            true
          } else {
            false
          }
        None => false
      }
    Group(inner) | Unary(_, inner) | PostfixUpdate(_, inner) =>
      self.predeclare_first_global_static_member_root(inner, function, scope)
    Binary(_, left, right) | Assignment(_, left, right) | Index(left, right) =>
      if self.predeclare_first_global_static_member_root(left, function, scope) {
        true
      } else {
        self.predeclare_first_global_static_member_root(right, function, scope)
      }
    Call(callee, arguments) =>
      if self.predeclare_first_global_static_member_root(
          callee, function, scope,
        ) {
        true
      } else {
        let arguments = wgsl_ir_call_arguments(arguments)
        let mut found = false
        for argument in arguments {
          if !found &&
            self.predeclare_first_global_static_member_root(
              argument, function, scope,
            ) {
            found = true
          }
        }
        found
      }
    Sequence(arguments) => {
      let mut found = false
      for argument in arguments {
        if !found &&
          self.predeclare_first_global_static_member_root(
            argument, function, scope,
          ) {
          found = true
        }
      }
      found
    }
    Template(base, _) | PathAccess(base, _) =>
      self.predeclare_first_global_static_member_root(base, function, scope)
    Identifier(_) | Literal(_) | ShaderDefTemplate(_) => false
  }
}

///|
fn WgslIrLowerer::predeclare_global_identifier_root(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Bool {
  match node.kind() {
    Group(inner) =>
      self.predeclare_global_identifier_root(inner, function, scope)
    Identifier(name) =>
      match self.global_names.get(name.name()) {
        Some(handle) => {
          ignore(
            scope.predeclare_global_pointer_expression(
              name.name(),
              handle,
              function,
            ),
          )
          true
        }
        None => false
      }
    _ => false
  }
}

///|
fn WgslIrLowerer::expression_node_contains_mutable_local_root_after(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  after_offset : Int,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Bool {
  match node.kind() {
    Identifier(name) =>
      if node.start() >= after_offset {
        match scope.locals.get(name.name()) {
          Some(handle) =>
            match function.local_variables.items.get(handle.index()) {
              Some(local_var) => local_var.kind == Var
              None => false
            }
          None => false
        }
      } else {
        false
      }
    Group(inner) =>
      self.expression_node_contains_mutable_local_root_after(
        inner, after_offset, function, scope,
      )
    Member(base, _) | PathAccess(base, _) | Template(base, _) =>
      self.expression_node_contains_mutable_local_root_after(
        base, after_offset, function, scope,
      )
    Unary(_, expr) | PostfixUpdate(_, expr) =>
      self.expression_node_contains_mutable_local_root_after(
        expr, after_offset, function, scope,
      )
    Binary(_, left, right) | Assignment(_, left, right) | Index(left, right) =>
      self.expression_node_contains_mutable_local_root_after(
        left, after_offset, function, scope,
      ) ||
      self.expression_node_contains_mutable_local_root_after(
        right, after_offset, function, scope,
      )
    Call(callee, arguments) =>
      if self.expression_node_contains_mutable_local_root_after(
          callee, after_offset, function, scope,
        ) {
        true
      } else {
        let call_args = wgsl_ir_call_arguments(arguments)
        call_args.any(fn(argument) {
          self.expression_node_contains_mutable_local_root_after(
            argument, after_offset, function, scope,
          )
        })
      }
    Sequence(arguments) =>
      arguments.any(fn(argument) {
        self.expression_node_contains_mutable_local_root_after(
          argument, after_offset, function, scope,
        )
      })
    Literal(_) | ShaderDefTemplate(_) => false
  }
}

///|
fn WgslIrLowerer::predeclare_first_mutable_local_root_after(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  after_offset : Int,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Bool {
  match node.kind() {
    Identifier(name) =>
      if node.start() >= after_offset {
        match scope.locals.get(name.name()) {
          Some(handle) =>
            match function.local_variables.items.get(handle.index()) {
              Some(local_var) =>
                if local_var.kind == Var {
                  ignore(
                    scope.predeclare_local_pointer_expression(
                      name.name(),
                      handle,
                      function,
                    ),
                  )
                  true
                } else {
                  false
                }
              None => false
            }
          None => false
        }
      } else {
        false
      }
    Group(inner) =>
      self.predeclare_first_mutable_local_root_after(
        inner, after_offset, function, scope,
      )
    Member(base, _) | PathAccess(base, _) | Template(base, _) =>
      self.predeclare_first_mutable_local_root_after(
        base, after_offset, function, scope,
      )
    Unary(_, expr) | PostfixUpdate(_, expr) =>
      self.predeclare_first_mutable_local_root_after(
        expr, after_offset, function, scope,
      )
    Binary(_, left, right) | Assignment(_, left, right) | Index(left, right) =>
      if self.predeclare_first_mutable_local_root_after(
          left, after_offset, function, scope,
        ) {
        true
      } else {
        self.predeclare_first_mutable_local_root_after(
          right, after_offset, function, scope,
        )
      }
    Call(callee, arguments) =>
      if self.predeclare_first_mutable_local_root_after(
          callee, after_offset, function, scope,
        ) {
        true
      } else {
        let call_args = wgsl_ir_call_arguments(arguments)
        let mut found = false
        for argument in call_args {
          if !found &&
            self.predeclare_first_mutable_local_root_after(
              argument, after_offset, function, scope,
            ) {
            found = true
          }
        }
        found
      }
    Sequence(arguments) => {
      let mut found = false
      for argument in arguments {
        if !found &&
          self.predeclare_first_mutable_local_root_after(
            argument, after_offset, function, scope,
          ) {
          found = true
        }
      }
      found
    }
    Literal(_) | ShaderDefTemplate(_) => false
  }
}

///|
fn WgslIrLowerer::lower_function_constructor_arguments_with_delayed_literals(
  self : WgslIrLowerer,
  flattened : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
  expected_ty : Handle?,
) -> Array[Handle] raise WgslIrLowerError {
  let scheduler = self.expression_arena_scheduler(function, scope)
  let lowered : Array[Handle?] = []
  for _ in 0..<flattened.length() {
    lowered.push(None)
  }
  for index in 0..<flattened.length() {
    if !scheduler.constructor_argument_is_literal_like(flattened[index]) {
      lowered[index] = Some(
        self.lower_function_constructor_argument_value(
          flattened[index],
          function,
          scope,
          expected_ty,
        ),
      )
    }
  }
  for index in 0..<flattened.length() {
    if scheduler.constructor_argument_is_literal_like(flattened[index]) {
      lowered[index] = Some(
        self.lower_function_constructor_argument_value(
          flattened[index],
          function,
          scope,
          expected_ty,
        ),
      )
    }
  }
  let handles : Array[Handle] = []
  for handle in lowered {
    match handle {
      Some(handle) => handles.push(handle)
      None => raise UnsupportedExpression("unlowered constructor argument")
    }
  }
  handles
}

///|
fn WgslIrLowerer::lower_function_constructor_argument_value(
  self : WgslIrLowerer,
  argument : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
  expected_ty : Handle?,
) -> Handle raise WgslIrLowerError {
  let lowered = self.lower_function_constructor_argument(
    argument, function, scope, expected_ty,
  )
  self.apply_function_load_rule(function, lowered)
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
  function.expressions.append_with_origin(Literal(literal), FoldedLocalConstant)
}

///|
fn WgslIrLowerer::lower_function_constructor_expression_from_handles(
  self : WgslIrLowerer,
  ty : Handle,
  lowered_arguments : Array[Handle],
  function : Function,
) -> Handle {
  match
    self.lower_function_matrix_constructor_expression_from_handles(
      ty, lowered_arguments, function,
    ) {
    Some(handle) => return handle
    None => ()
  }
  match self.vector_size_from_type(ty) {
    Some(size) =>
      match lowered_arguments {
        [argument] =>
          match
            self.lower_function_single_vector_constructor_argument(
              ty, size, argument, function,
            ) {
            Some(handle) => return handle
            None => ()
          }
        _ => ()
      }
    None => ()
  }
  function.expressions.append(Compose(ty, lowered_arguments))
}

///|
fn WgslIrLowerer::lower_function_matrix_constructor_expression_from_handles(
  self : WgslIrLowerer,
  ty : Handle,
  lowered_arguments : Array[Handle],
  function : Function,
) -> Handle? {
  guard self.shader_module.types.get(ty) is Some(type_) else { return None }
  guard type_.inner is Matrix(columns, rows, scalar) else { return None }
  let columns_len = columns.width()
  let rows_len = rows.width()
  guard lowered_arguments.length() == columns_len * rows_len else {
    return None
  }
  let column_ty = self.vector_type_handle(rows, scalar)
  let column_handles : Array[Handle] = []
  for column in 0..<columns_len {
    let column_components : Array[Handle] = []
    for row in 0..<rows_len {
      column_components.push(lowered_arguments[column * rows_len + row])
    }
    column_handles.push(
      function.expressions.append(Compose(column_ty, column_components)),
    )
  }
  Some(function.expressions.append(Compose(ty, column_handles)))
}

///|
fn WgslIrLowerer::lower_function_single_vector_constructor_argument(
  self : WgslIrLowerer,
  ty : Handle,
  size : VectorSize,
  argument : Handle,
  function : Function,
) -> Handle? {
  guard self.shader_module.types.get(ty) is Some(target_type) else {
    return None
  }
  guard target_type.inner is Vector(_, target_scalar) else { return None }
  guard self.function_expression_type(function, argument) is Some(argument_ty) else {
    return None
  }
  if self.type_is_scalar(argument_ty) {
    return Some(function.expressions.append(Splat(size, argument)))
  }
  match self.shader_module.types.get(argument_ty) {
    Some(argument_type) =>
      match argument_type.inner {
        Vector(argument_size, argument_scalar) =>
          if argument_size != size {
            None
          } else if argument_scalar == target_scalar {
            Some(argument)
          } else {
            Some(
              function.expressions.append(
                As(argument, target_scalar.kind, Some(target_scalar.width)),
              ),
            )
          }
        _ => None
      }
    None => None
  }
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
    raise UnsupportedType("array")
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
  function.expressions.append(Compose(ty, components))
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
    raise UnsupportedExpression("arrayLength expects one argument")
  }
  let pointer = self.lower_atomic_pointer_argument(argument, function, scope)
  function.expressions.append(ArrayLength(pointer))
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
    raise UnsupportedExpression("workgroupUniformLoad expects one argument")
  }
  let pointer = self.lower_atomic_pointer_argument(argument, function, scope)
  function.expressions.append(WorkGroupUniformLoad(pointer))
}

///|
fn WgslIrLowerer::lower_function_math_call(
  self : WgslIrLowerer,
  math_function : MathFunction,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  let expression_mark = function.expressions.items.length()
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments.length() > 0 else {
    raise UnsupportedExpression("math call requires at least one argument")
  }
  if wgsl_ir_math_call_predeclares_function_argument_values(arguments, scope) {
    for argument in arguments {
      self.predeclare_function_argument_values_in_source_order(
        argument, function, scope,
      )
    }
  }
  match
    self.lower_function_math_call_with_later_splat_constructors_before_first_direct(
      math_function, arguments, function, scope,
    ) {
    Some(handle) => return handle
    None => ()
  }
  let deferred_constructors = self.prelower_homogeneous_math_constructor_arguments(
    math_function, arguments, function, scope,
  )
  let handles : Array[Handle] = []
  if self.math_call_lowers_second_argument_before_first(
      math_function, arguments, function, scope,
    ) {
    let prelowered_later : Array[Handle?] = []
    for _ in 0..<arguments.length() {
      prelowered_later.push(None)
    }
    let second = self.lower_function_math_argument_at(
      1, arguments, deferred_constructors, function, scope,
    )
    for index in 2..<arguments.length() {
      if self.math_call_later_argument_lowers_before_deferred_first(
          arguments[index],
          function,
          scope,
        ) {
        prelowered_later[index] = Some(
          self.lower_function_math_argument_at(
            index, arguments, deferred_constructors, function, scope,
          ),
        )
      }
    }
    let first = self.lower_function_foldable_const_math_argument_at(
      0, arguments, deferred_constructors, function, scope,
    )
    handles.push(first)
    handles.push(second)
    for index in 2..<arguments.length() {
      match prelowered_later[index] {
        Some(handle) => handles.push(handle)
        None =>
          handles.push(
            self.lower_function_math_argument_at(
              index, arguments, deferred_constructors, function, scope,
            ),
          )
      }
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
  let handle = function.expressions.append(Math(math_function, a, b, c, d))
  match self.fold_function_constant_float_expression(function, handle) {
    Some(literal) => {
      function.expressions.truncate(expression_mark)
      function.expressions.append_with_origin(
        Literal(literal),
        FoldedLocalConstant,
      )
    }
    None => handle
  }
}

///|
fn WgslIrLowerer::lower_function_math_call_with_later_splat_constructors_before_first_direct(
  self : WgslIrLowerer,
  math_function : MathFunction,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle? raise WgslIrLowerError {
  guard math_function == Clamp else { return None }
  guard wgsl_ir_math_function_has_homogeneous_arguments(math_function) else {
    return None
  }
  guard arguments.length() >= 2 else { return None }
  guard wgsl_ir_expr_node_is_function_argument_value(arguments[0], scope) else {
    return None
  }
  guard self.prelower_math_splat_constructor_argument(
      arguments[1],
      function,
      scope,
    )
    is Some(first_later) else {
    return None
  }
  let second = self.lower_function_constructor_expression_from_handles(
    first_later.ty,
    [first_later.component],
    function,
  )
  let deferred : Map[Int, WgslIrDeferredConstructorArgument] = Map([])
  for index in 2..<arguments.length() {
    match
      self.prelower_math_splat_constructor_argument(
        arguments[index],
        function,
        scope,
      ) {
      Some(value) => deferred.set(index, value)
      None => return None
    }
  }
  let first = self.lower_function_math_argument_at(
    0, arguments, deferred, function, scope,
  )
  let handles : Array[Handle] = [first, second]
  for index in 2..<arguments.length() {
    handles.push(
      self.lower_function_math_argument_at(
        index, arguments, deferred, function, scope,
      ),
    )
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
  Some(function.expressions.append(Math(math_function, a, b, c, d)))
}

///|
fn WgslIrLowerer::math_call_later_argument_lowers_before_deferred_first(
  self : WgslIrLowerer,
  argument : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Bool {
  wgsl_ir_expr_node_is_direct_access_chain(argument) &&
  self.expression_node_contains_naga_reference_value(argument, function, scope)
}

///|
fn wgsl_ir_math_call_predeclares_function_argument_values(
  arguments : Array[@ast.WgslExprNode],
  scope : WgslIrFunctionScope,
) -> Bool {
  arguments.length() > 1 &&
  arguments.any(fn(argument) {
    wgsl_ir_expr_node_contains_function_argument_math_call(argument, scope)
  })
}

///|
fn WgslIrLowerer::predeclare_function_argument_values_in_source_order(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Unit raise WgslIrLowerError {
  match node.kind() {
    Identifier(_) =>
      self.predeclare_function_argument_value(node, function, scope)
    Group(inner) | Unary(_, inner) | PostfixUpdate(_, inner) =>
      self.predeclare_function_argument_values_in_source_order(
        inner, function, scope,
      )
    Binary(_, left, right) | Assignment(_, left, right) | Index(left, right) => {
      self.predeclare_function_argument_values_in_source_order(
        left, function, scope,
      )
      self.predeclare_function_argument_values_in_source_order(
        right, function, scope,
      )
    }
    Member(base, _) | PathAccess(base, _) | Template(base, _) =>
      self.predeclare_function_argument_values_in_source_order(
        base, function, scope,
      )
    Call(_, arguments) | Sequence(arguments) =>
      for argument in arguments {
        self.predeclare_function_argument_values_in_source_order(
          argument, function, scope,
        )
      }
    Literal(_) | ShaderDefTemplate(_) => ()
  }
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
fn WgslIrLowerer::lower_function_foldable_const_math_argument_at(
  self : WgslIrLowerer,
  index : Int,
  arguments : Array[@ast.WgslExprNode],
  deferred_constructors : Map[Int, WgslIrDeferredConstructorArgument],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  guard self.expression_node_is_foldable_math_const_like(
    arguments[index],
    scope,
  ) else {
    return self.lower_function_math_argument_at(
      index, arguments, deferred_constructors, function, scope,
    )
  }
  let expression_mark = function.expressions.items.length()
  let lowered = self.lower_function_math_argument_at(
    index, arguments, deferred_constructors, function, scope,
  )
  match self.fold_function_constant_literal_expression(function, lowered) {
    Some(literal) => {
      function.expressions.truncate(expression_mark)
      function.expressions.append_with_origin(
        Literal(literal),
        FoldedLocalConstant,
      )
    }
    None => lowered
  }
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
  (
    wgsl_ir_expr_node_is_literal_like(arguments[0]) &&
    self.expression_node_contains_naga_reference_value(
      arguments[1],
      function,
      scope,
    )
  ) ||
  (
    self.expression_node_is_foldable_math_const_like(arguments[0], scope) &&
    self.expression_node_contains_user_function_call(arguments[1])
  )
}

///|
fn WgslIrLowerer::prelower_math_splat_constructor_argument(
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
  guard self.expression_node_is_naga_deferred_const_like(component, scope) else {
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
  let expression_mark = function.expressions.items.length()
  let lowered = self.lower_function_expression_node_with_expected(
    component, function, scope, expected_ty,
  )
  match self.fold_function_constant_float_expression(function, lowered) {
    Some(literal) => {
      function.expressions.truncate(expression_mark)
      let component = function.expressions.append_with_origin(
        Literal(literal),
        FoldedLocalConstant,
      )
      Some({ ty, component })
    }
    None => {
      function.expressions.truncate(expression_mark)
      None
    }
  }
}

///|
fn WgslIrLowerer::lower_math_splat_constructor_callee_type(
  self : WgslIrLowerer,
  callee : @ast.WgslExprNode,
  constructor_arguments : Array[@ast.WgslExprNode],
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
        Literal(literal),
        FoldedLocalConstant,
      )
      Some({ ty, component })
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
      op == Subtract &&
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
    raise UnsupportedExpression(
      "\{wgsl_ir_relational_function_name(relational_function)} expects one argument",
    )
  }
  let argument = self.lower_function_expression_node(expr, function, scope)
  function.expressions.append(
    Relational(
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
    raise UnsupportedExpression("select expects three arguments")
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
  let accept_handle = self.lower_function_expression_node(
    accept, function, scope,
  )
  let reject_handle = self.lower_function_expression_node(
    reject, function, scope,
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
  self.expression_node_contains_naga_reference_value(accept, function, scope) &&
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
    raise UnsupportedExpression(
      "\{wgsl_ir_atomic_function_name(atomic_function)} expects \{expected} arguments",
    )
  }
  if atomic_function == Load {
    guard arguments is [pointer_argument] else {
      raise UnsupportedExpression("atomicLoad expects 1 argument")
    }
    return function.expressions.append(
      Load(
        self.lower_atomic_pointer_argument(pointer_argument, function, scope),
      ),
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
  if atomic_function == CompareExchangeWeak {
    match self.atomic_call_result_scalar_type(function, handles) {
      Some(scalar) =>
        ignore(
          self.predeclared_struct_type(AtomicCompareExchangeWeakResult(scalar)),
        )
      None => ()
    }
  }
  function.expressions.append(AtomicCall(atomic_function, handles))
}

///|
fn WgslIrLowerer::atomic_call_result_scalar_type(
  self : WgslIrLowerer,
  function : Function,
  arguments : Array[Handle],
) -> Scalar? {
  guard arguments is [pointer, .. rest] else { return None }
  match self.atomic_pointer_scalar_type(function, pointer) {
    Some(scalar) => Some(scalar)
    None =>
      match rest {
        [value, ..] =>
          match self.function_expression_type(function, value) {
            Some(ty) => self.scalar_from_numeric_type_handle(ty)
            None => None
          }
        [] => None
      }
  }
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
