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
          scope.global_pointer_expression(name.name(), handle, function)
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
      let base_handle = self.lower_function_lvalue_node(base, function, scope)
      let index_handle = self.lower_function_expression_node(
        index, function, scope,
      )
      function.expressions.append(Expression::Access(base_handle, index_handle))
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
    None => self.lower_function_expression_node(base, function, scope)
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
      } else {
        function.expressions.append(
          Expression::Unary(
            wgsl_ir_unary_operator(op),
            self.lower_function_expression_node(expr, function, scope),
          ),
        )
      }
    Binary(op, left, right) => {
      let left_handle = self.lower_function_expression_node(
        left, function, scope,
      )
      let right_handle = self.lower_function_expression_node(
        right, function, scope,
      )
      let handle = function.expressions.append(
        Expression::Binary(
          wgsl_ir_binary_operator(op),
          left_handle,
          right_handle,
        ),
      )
      match self.fold_function_constant_float_expression(function, handle) {
        Some(literal) =>
          function.expressions.append(Expression::Literal(literal))
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
      self.lower_member_expression(function, base_handle, member_name.name())
    }
    Index(base, index) => {
      let base_handle = self.lower_function_index_value_base(
        base, function, scope,
      )
      let index_handle = self.lower_function_expression_node(
        index, function, scope,
      )
      function.expressions.append(Expression::Access(base_handle, index_handle))
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
                  function.expressions.append(
                    Expression::Compose(
                      ty,
                      self.lower_function_constructor_arguments(
                        ty, arguments, function, scope,
                      ),
                    ),
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
  function.expressions.append(Expression::Compose(ty, lowered_arguments))
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
  function.expressions.append(
    Expression::Derivative(
      axis,
      control,
      self.lower_function_expression_node(expr, function, scope),
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
    Some(handle) => return handle
    None => ()
  }
  match scope.locals.get(name) {
    Some(handle) =>
      if self.local_variable_is_handle_value(function, handle) {
        return scope.local_pointer_expression(name, handle, function)
      } else {
        return function.expressions.append(
          Expression::Load(
            scope.local_pointer_expression(name, handle, function),
          ),
        )
      }
    None => ()
  }
  match scope.arguments.get(name) {
    Some(index) =>
      return function.expressions.append(Expression::FunctionArgument(index))
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
        scope.global_pointer_expression(name, handle, function)
      } else {
        function.expressions.append(
          Expression::Load(
            scope.global_pointer_expression(name, handle, function),
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
    Some(global) =>
      match self.shader_module.types.get(global.ty) {
        Some(type_) =>
          match type_.inner {
            Image(_, _, _)
            | Sampler(_)
            | AccelerationStructure(_)
            | RayQuery(_) => true
            _ => false
          }
        None => false
      }
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
  if self.function_index_base_is_addressable(base, function, scope) {
    self.lower_function_lvalue_node(base, function, scope)
  } else {
    self.lower_function_expression_node(base, function, scope)
  }
}

///|
fn WgslIrLowerer::function_index_base_is_addressable(
  self : WgslIrLowerer,
  base : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Bool {
  match base.kind() {
    Group(inner) =>
      self.function_index_base_is_addressable(inner, function, scope)
    Identifier(name) =>
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
            Some(index) => self.function_argument_is_pointer(function, index)
            None => self.global_names.get(name.name()) is Some(_)
          }
      }
    Index(inner, _) | Member(inner, _) =>
      self.function_index_base_is_addressable(inner, function, scope)
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
    handles.push(
      self.lower_function_expression_node_with_expected(
        argument, function, scope, expected_ty,
      ),
    )
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
  self.lower_function_expression_arguments_with_expected(
    arguments,
    function,
    scope,
    self.constructor_component_expected_type(ty),
  )
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
  guard arguments is [first, .. rest] else {
    raise WgslIrLowerError::UnsupportedExpression(
      "math call requires at least one argument",
    )
  }
  let a = self.lower_function_expression_node(first, function, scope)
  let b = match rest {
    [value, ..] =>
      Some(self.lower_function_expression_node(value, function, scope))
    [] => None
  }
  let c = match rest {
    [_, value, ..] =>
      Some(self.lower_function_expression_node(value, function, scope))
    _ => None
  }
  let d = match rest {
    [_, _, value, ..] =>
      Some(self.lower_function_expression_node(value, function, scope))
    _ => None
  }
  function.expressions.append(Expression::Math(math_function, a, b, c, d))
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
  function.expressions.append(
    Expression::Relational(
      relational_function,
      self.lower_function_expression_node(expr, function, scope),
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
  function.expressions.append(
    Expression::Select(
      self.lower_function_expression_node(condition, function, scope),
      self.lower_function_expression_node(accept, function, scope),
      self.lower_function_expression_node(reject, function, scope),
    ),
  )
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
