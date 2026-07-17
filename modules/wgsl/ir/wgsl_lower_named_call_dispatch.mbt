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
pub fn wgsl_ir_subgroup_function_name(function : SubgroupFunction) -> String {
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
    name, arguments, lowered_arguments, function, scope, expected_ty, expression_mark,
  )
}

///|
fn WgslIrLowerer::finish_function_constructor_call(
  self : WgslIrLowerer,
  name : String,
  arguments : Array[@ast.WgslExprNode],
  lowered_arguments : Array[Handle],
  function : Function,
  scope : WgslIrFunctionScope,
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
  let folded_scalar_constructor = if wgsl_ir_constructor_arguments_reference_source_local_let(
      arguments, scope,
    ) {
    (None : Literal?)
  } else {
    self.fold_function_scalar_constructor(ty, lowered_arguments, function) catch {
      _ => (None : Literal?)
    }
  }
  match folded_scalar_constructor {
    Some(literal) => {
      wgsl_ir_rewind_function_expressions(function, expression_mark)
      wgsl_ir_invalidate_local_constant_aliases_after_expression_rewind(
        scope.local_constants,
        expression_mark,
      )
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
  self.contextualize_function_struct_constructor_arguments(
    function, ty, lowered_arguments,
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
fn wgsl_ir_constructor_arguments_reference_source_local_let(
  arguments : Array[@ast.WgslExprNode],
  scope : WgslIrFunctionScope,
) -> Bool {
  for argument in arguments {
    if wgsl_ir_expr_node_references_source_local_let(argument, scope) {
      return true
    }
  }
  false
}

///|
fn wgsl_ir_expr_node_references_source_local_let(
  node : @ast.WgslExprNode,
  scope : WgslIrFunctionScope,
) -> Bool {
  match node.kind() {
    Identifier(name) =>
      match scope.local_constants.get(name.name()) {
        Some({ source: LocalLet, .. }) => true
        _ => false
      }
    Group(inner) => wgsl_ir_expr_node_references_source_local_let(inner, scope)
    Unary(_, inner) =>
      wgsl_ir_expr_node_references_source_local_let(inner, scope)
    Binary(_, left, right) =>
      wgsl_ir_expr_node_references_source_local_let(left, scope) ||
      wgsl_ir_expr_node_references_source_local_let(right, scope)
    Call(_, arguments) => {
      for argument in wgsl_ir_call_arguments(arguments) {
        if wgsl_ir_expr_node_references_source_local_let(argument, scope) {
          return true
        }
      }
      false
    }
    Member(base, _) =>
      wgsl_ir_expr_node_references_source_local_let(base, scope)
    Index(base, index) =>
      wgsl_ir_expr_node_references_source_local_let(base, scope) ||
      wgsl_ir_expr_node_references_source_local_let(index, scope)
    Sequence(items) => {
      for item in items {
        if wgsl_ir_expr_node_references_source_local_let(item, scope) {
          return true
        }
      }
      false
    }
    _ => false
  }
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
  ignore(argument_scalar)
  Some(
    function.expressions.append(
      As(argument, target_scalar.kind, Some(target_scalar.width)),
    ),
  )
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
    Some({ value: LazyConstant(local_constant), source }) => {
      let handle = match local_constant.normalized {
        Some(normalized) =>
          function.expressions.append_with_origin(
            normalized.expression,
            if source == LocalLet {
              RetainedSourceLetExpression
            } else {
              normalized.origin
            },
          )
        None =>
          self.lower_function_expression_ref_with_expected(
            local_constant.expr_ref,
            function,
            scope,
            local_constant.explicit_ty,
          )
      }
      if source == LocalLet {
        function.expressions.set_origin(handle, RetainedSourceLetExpression)
      }
      match scope.local_constants.get(name) {
        Some(cell) => cell.value = ExpressionAlias(handle, Some(local_constant))
        None => ()
      }
      return handle
    }
    Some(cell) =>
      match cell.value {
        ExpressionAlias(handle, fallback) => {
          if handle.index() >= function.expressions.items.length() {
            match fallback {
              Some(local_constant) => {
                cell.value = LazyConstant(local_constant)
                return self.lower_identifier_expression(name, function, scope)
              }
              None =>
                raise UnsupportedExpression(
                  "stale local constant alias after expression rewind: \{name}",
                )
            }
          }
          if cell.source == LocalLet {
            function.expressions.set_origin(handle, RetainedSourceLetExpression)
          }
          return handle
        }
        _ => ()
      }
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
        let (base_handle, index_handle) = if wgsl_ir_expr_node_contains_function_argument_value(
            index, scope,
          ) {
          self.predeclare_function_argument_values_in_source_order(
            index, function, scope,
          )
          let base_handle = self.lower_function_static_member_access_chain(
            root_handle, members, function,
          )
          let index_handle = self.lower_function_expression_node(
            index, function, scope,
          )
          (base_handle, index_handle)
        } else if self.expression_node_contains_mutable_local_reference(
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
        let access = function.expressions.append(
          Access(base_handle, index_handle),
        )
        match scope.pending_compound_assignment_rhs_local_root {
          Some(name) => {
            self.predeclare_identifier_reference_root(name, function, scope)
            scope.pending_compound_assignment_rhs_local_root = None
          }
          None => ()
        }
        Some(access)
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
