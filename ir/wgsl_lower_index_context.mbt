///|
fn WgslIrLowerer::matrix_multiply_operand_context(
  self : WgslIrLowerer,
  left_ty : Handle,
  right_ty : Handle,
) -> (Handle?, Handle?)? {
  guard self.shader_module.types.get(left_ty) is Some(left) else { return None }
  guard self.shader_module.types.get(right_ty) is Some(right) else {
    return None
  }
  match (left.inner, right.inner) {
    (Matrix(columns, _, scalar), Vector(size, _)) =>
      if columns == size {
        Some((None, Some(self.vector_type_handle(size, scalar))))
      } else {
        None
      }
    (Vector(size, _), Matrix(_, rows, scalar)) =>
      if rows == size {
        Some((Some(self.vector_type_handle(size, scalar)), None))
      } else {
        None
      }
    _ => None
  }
}

///|
fn WgslIrLowerer::lower_function_static_or_dynamic_index(
  self : WgslIrLowerer,
  base_handle : Handle,
  index : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  match self.static_index_for_naga_access_index(base_handle, index, function) {
    Some(static_index) =>
      function.expressions.append(AccessIndex(base_handle, static_index))
    None => {
      let index_handle = self.lower_function_expression_node(
        index, function, scope,
      )
      function.expressions.append(Access(base_handle, index_handle))
    }
  }
}

///|
fn WgslIrLowerer::static_index_for_naga_access_index(
  self : WgslIrLowerer,
  base_handle : Handle,
  index : @ast.WgslExprNode,
  function : Function,
) -> Int? raise WgslIrLowerError {
  guard self.static_index_value_from_expr_node(index) is Some(static_index) else {
    return None
  }
  guard static_index >= 0 else { return None }
  guard self.function_expression_type(function, base_handle) is Some(ty) else {
    return None
  }
  match self.shader_module.types.get(self.deref_pointer_type_handle(ty)) {
    Some(type_) =>
      match type_.inner {
        Vector(size, _) =>
          if static_index < size.width() {
            Some(static_index)
          } else {
            None
          }
        Matrix(columns, _, _) =>
          if static_index < columns.width() {
            Some(static_index)
          } else {
            None
          }
        Array(_, Constant(count), _) =>
          if static_index < count {
            Some(static_index)
          } else {
            None
          }
        Array(_, Dynamic, _) => Some(static_index)
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrLowerer::static_index_value_from_expr_node(
  self : WgslIrLowerer,
  index : @ast.WgslExprNode,
) -> Int? raise WgslIrLowerError {
  match wgsl_ir_int_literal_from_expr_node(index) {
    Some(static_index) => return Some(static_index)
    None => ()
  }
  match index.kind() {
    Group(inner) => self.static_index_value_from_expr_node(inner)
    Identifier(name) =>
      match self.ensure_constant_declaration_lowered(name.name()) {
        Some(handle) =>
          match self.shader_module.constants.items.get(handle.index()) {
            Some(constant) => {
              let evaluated = Some(
                self.eval_global_integer_expression(constant.init),
              ) catch {
                _ => None
              }
              match evaluated {
                Some(value) => Some(value.to_signed_int())
                None => None
              }
            }
            None => None
          }
        None => None
      }
    _ => None
  }
}
