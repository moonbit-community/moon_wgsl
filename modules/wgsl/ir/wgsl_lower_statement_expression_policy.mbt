///|
fn wgsl_ir_function_expression_should_use_named_let(
  function : Function,
  handle : Handle,
) -> Bool {
  match function.expressions.items.get(handle.index()) {
    Some(Literal(_))
    | Some(Constant(_))
    | Some(Override(_))
    | Some(ZeroValue(_))
    | Some(FunctionArgument(_))
    | Some(GlobalVariable(_))
    | Some(LocalVariable(_))
    | Some(AddressOf(_, _))
    | Some(FunctionCall(_, _))
    | Some(AtomicCall(_, _))
    | Some(WorkGroupUniformLoad(_)) => false
    Some(_) => true
    None => false
  }
}

///|
fn wgsl_ir_function_expression_is_materialized_temporary(
  function : Function,
  handle : Handle,
) -> Bool {
  match function.expressions.items.get(handle.index()) {
    Some(CallResult(_)) => true
    _ => false
  }
}

///|
fn wgsl_ir_max_handle(left : Handle, right : Handle) -> Handle {
  if left.index() >= right.index() {
    left
  } else {
    right
  }
}

///|
fn wgsl_ir_function_expression_is_emit_leaf(
  function : Function,
  handle : Handle,
) -> Bool {
  match function.expressions.items.get(handle.index()) {
    Some(expression) => wgsl_ir_expression_is_emit_leaf(expression)
    None => false
  }
}

///|
fn wgsl_ir_return_expression_should_emit_before_return(
  function : Function,
  expression_mark : Int,
  value : Handle,
) -> Bool {
  if wgsl_ir_function_expression_has_arena_name(function, value) {
    return false
  }
  for index in expression_mark..<=value.index() {
    match function.expressions.items.get(index) {
      Some(FunctionCall(_, _))
      | Some(CallResult(_))
      | Some(AtomicCall(_, _))
      | Some(ImageSample(_, _, _, _, _, _, _, _, _))
      | Some(ImageLoad(_, _, _, _, _))
      | Some(ImageQuery(_, _))
      | Some(WorkGroupUniformLoad(_)) => return false
      _ => ()
    }
  }
  match function.expressions.items.get(value.index()) {
    Some(expression) => !wgsl_ir_expression_is_emit_leaf(expression)
    None => false
  }
}

///|
fn wgsl_ir_expression_is_emit_leaf(expression : Expression) -> Bool {
  match expression {
    Literal(_)
    | Constant(_)
    | Override(_)
    | FunctionArgument(_)
    | CallResult(_)
    | AtomicResult(_, _)
    | GlobalVariable(_)
    | LocalVariable(_) => true
    _ => false
  }
}

///|
fn WgslIrLowerer::function_expression_should_materialize_as_let_initializer(
  self : WgslIrLowerer,
  function : Function,
  value : Handle,
) -> Bool {
  ignore(self)
  match function.expressions.items.get(value.index()) {
    Some(FunctionCall(_, _))
    | Some(AtomicCall(_, _))
    | Some(WorkGroupUniformLoad(_)) => true
    _ => false
  }
}

///|
fn WgslIrLowerer::lower_local_const_declaration(
  self : WgslIrLowerer,
  local_decl : @ast.WgslLocalDeclaration,
  function : Function,
  scope : WgslIrFunctionScope,
  local_constant_placement : WgslIrLocalConstantArenaPlacement,
) -> Unit raise WgslIrLowerError {
  let expression_mark = function.expressions.items.length()
  let local_constant_snapshot = wgsl_ir_snapshot_local_constant_values(
    scope.local_constants,
  )
  let explicit_ty = match local_decl.ty_ref() {
    Some(ty_ref) => Some(self.lower_function_type_ref(ty_ref, function, scope))
    None => None
  }
  let init = match local_decl.initializer_ref() {
    Some(expr_ref) =>
      self.lower_function_expression_ref_with_expected(
        expr_ref, function, scope, explicit_ty,
      )
    None => raise MissingType(local_decl.name().name())
  }
  if !self.function_expression_is_const_expression(function, init) {
    raise UnsupportedExpression(
      "local const initializer is not a const expression",
    )
  }
  let const_ty = match explicit_ty {
    Some(ty) => ty
    None =>
      match self.function_expression_type(function, init) {
        Some(ty) => ty
        None =>
          self.infer_local_type_from_initializer(
            local_decl.name().name(),
            local_decl.initializer_ref(),
          )
      }
  }
  let normalized = self.normalized_local_constant_initializer(
    function,
    init,
    Some(const_ty),
  )
  function.expressions.set_origin(normalized, FoldedLocalConstant)
  ignore(scope.locals.remove(local_decl.name().name()))
  match local_constant_placement {
    DeclarationArenaLocalConstant =>
      scope.local_constants.set(
        local_decl.name().name(),
        wgsl_ir_local_const_value_cell(ExpressionAlias(normalized, None)),
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
            wgsl_ir_local_const_value_cell(
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
}

///|
fn wgsl_ir_lazy_local_constant_expression(
  function : Function,
  handle : Handle,
) -> WgslIrLazyLocalConstantExpression? {
  match function.expressions.items.get(handle.index()) {
    Some(Literal(literal)) =>
      Some({ expression: Literal(literal), origin: FoldedLocalConstant })
    _ => None
  }
}

///|
fn wgsl_ir_rewind_function_expressions(
  function : Function,
  length : Int,
) -> Unit {
  function.expressions.truncate(length)
}

///|
fn wgsl_ir_rewind_function_expressions_and_local_constant_values(
  function : Function,
  length : Int,
  scope : WgslIrFunctionScope,
  local_constant_snapshot : Map[String, WgslIrLocalValue],
) -> Unit {
  wgsl_ir_rewind_function_expressions(function, length)
  wgsl_ir_restore_local_constant_values(
    scope.local_constants,
    local_constant_snapshot,
  )
  wgsl_ir_invalidate_local_constant_aliases_after_expression_rewind(
    scope.local_constants,
    length,
  )
}

///|
fn WgslIrLowerer::local_let_const_scalar_initializer_should_fold(
  self : WgslIrLowerer,
  local_decl : @ast.WgslLocalDeclaration,
  init_handle : Handle,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Bool {
  if !self.function_expression_is_const_expression(function, init_handle) ||
    !self.function_expression_has_scalar_type(function, init_handle) {
    return false
  }
  if wgsl_ir_function_expression_should_use_named_let(function, init_handle) {
    match local_decl.initializer_ref() {
      Some(expr_ref) =>
        match expr_ref.root() {
          Some(root) =>
            if wgsl_ir_expr_node_references_local_let_constant(root, scope) {
              return false
            }
          None => ()
        }
      None => ()
    }
  }
  true
}

///|
fn WgslIrLowerer::function_expression_has_scalar_type(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle,
) -> Bool {
  match self.function_expression_type(function, handle) {
    Some(ty_handle) =>
      match self.shader_module.types.get(ty_handle) {
        Some(type_) =>
          match type_.inner {
            Scalar(_) => true
            _ => false
          }
        None => false
      }
    None => false
  }
}

///|
fn WgslIrLowerer::function_expression_is_handle_resource_value(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle,
) -> Bool {
  match self.function_expression_type(function, handle) {
    Some(ty) => self.type_is_global_handle_value(ty)
    None => false
  }
}

///|
fn WgslIrLowerer::function_expression_is_const_expression(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle,
) -> Bool {
  match function.expressions.items.get(handle.index()) {
    Some(expression) =>
      self.function_expression_inner_is_const_expression(function, expression)
    None => false
  }
}

///|
fn WgslIrLowerer::function_expression_inner_is_const_expression(
  self : WgslIrLowerer,
  function : Function,
  expression : Expression,
) -> Bool {
  match expression {
    Literal(_) | Constant(_) | ZeroValue(_) => true
    Override(_)
    | FunctionArgument(_)
    | GlobalVariable(_)
    | LocalVariable(_)
    | Load(_)
    | AddressOf(_, _)
    | FunctionCall(_, _)
    | AtomicCall(_, _)
    | ImageSample(_, _, _, _, _, _, _, _, _)
    | ImageLoad(_, _, _, _, _)
    | ImageQuery(_, _)
    | CallResult(_)
    | AtomicResult(_, _)
    | WorkGroupUniformLoadResult(_)
    | WorkGroupUniformLoad(_)
    | ArrayLength(_)
    | RayQueryInitialize(_, _, _)
    | RayQueryProceed(_)
    | RayQueryGenerateIntersection(_, _)
    | RayQueryConfirmIntersection(_)
    | RayQueryTerminate(_)
    | RayQueryVertexPositions(_, _)
    | RayQueryProceedResult
    | RayQueryGetIntersection(_, _)
    | SubgroupCall(_, _)
    | SubgroupBallotResult
    | SubgroupOperationResult(_)
    | CooperativeLoad(_, _, _, _)
    | CooperativeMultiplyAdd(_, _, _) => false
    Compose(_, components) =>
      self.function_expression_list_is_const_expression(function, components)
    Access(base, index) =>
      self.function_expression_is_const_expression(function, base) &&
      self.function_expression_is_const_expression(function, index)
    AccessIndex(base, _)
    | Component(base, _)
    | Splat(_, base)
    | Swizzle(_, base, _) =>
      self.function_expression_is_const_expression(function, base)
    Unary(_, inner)
    | Bitcast(_, inner)
    | Relational(_, inner)
    | As(inner, _, _) =>
      self.function_expression_is_const_expression(function, inner)
    Binary(_, left, right) =>
      self.function_expression_is_const_expression(function, left) &&
      self.function_expression_is_const_expression(function, right)
    Select(left, right, condition) =>
      self.function_expression_is_const_expression(function, left) &&
      self.function_expression_is_const_expression(function, right) &&
      self.function_expression_is_const_expression(function, condition)
    Derivative(_, _, _) => false
    Math(_, first, second, third, fourth) =>
      self.function_expression_is_const_expression(function, first) &&
      self.optional_function_expression_is_const_expression(function, second) &&
      self.optional_function_expression_is_const_expression(function, third) &&
      self.optional_function_expression_is_const_expression(function, fourth)
  }
}

///|
fn WgslIrLowerer::function_expression_list_is_const_expression(
  self : WgslIrLowerer,
  function : Function,
  handles : Array[Handle],
) -> Bool {
  for handle in handles {
    if !self.function_expression_is_const_expression(function, handle) {
      return false
    }
  }
  true
}

///|
fn WgslIrLowerer::optional_function_expression_is_const_expression(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle?,
) -> Bool {
  match handle {
    Some(value) => self.function_expression_is_const_expression(function, value)
    None => true
  }
}
