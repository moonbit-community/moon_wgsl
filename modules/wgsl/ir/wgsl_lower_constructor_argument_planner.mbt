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
  let local_constant_snapshot = wgsl_ir_snapshot_local_constant_values(
    scope.local_constants,
  )
  let lowered = self.lower_function_expression_node_with_expected(
    argument, function, scope, expected_ty,
  )
  if wgsl_ir_expr_node_references_local_let_constant(argument, scope) {
    return lowered
  }
  guard self.fold_function_constant_float_expression(function, lowered)
    is Some(literal) else {
    return lowered
  }
  wgsl_ir_rewind_function_expressions_and_local_constant_values(
    function, expression_mark, scope, local_constant_snapshot,
  )
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
        Vector(argument_size, _) =>
          if argument_size != size {
            None
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
