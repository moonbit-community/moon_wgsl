///|
fn WgslIrEmitter::eval_float_expression_for_writer(
  self : WgslIrEmitter,
  function : Function?,
  handle : Handle,
) -> Double? raise WgslIrEmitError {
  match self.required_expression(function, handle) {
    Literal(literal) => wgsl_ir_float_value_from_numeric_literal(literal)
    Constant(constant) =>
      self.eval_constant_float_expression_for_writer(constant)
    Compose(ty, [component]) =>
      match self.shader_module.types.items.get(ty.index()) {
        Some({ inner: Scalar({ kind: Float | AbstractFloat, .. }), .. }) =>
          self.eval_float_expression_for_writer(function, component)
        _ => None
      }
    Unary(Negate, inner) =>
      match self.eval_float_expression_for_writer(function, inner) {
        Some(value) => Some(-value)
        None => None
      }
    Binary(op, left, right) => {
      guard self.eval_float_expression_for_writer(function, left)
        is Some(left_value) else {
        return None
      }
      guard self.eval_float_expression_for_writer(function, right)
        is Some(right_value) else {
        return None
      }
      wgsl_ir_emit_eval_float_binary(op, left_value, right_value)
    }
    _ => None
  }
}

///|
fn WgslIrEmitter::expression_tree_contains_folded_local_constant(
  self : WgslIrEmitter,
  function : Function?,
  handle : Handle,
) -> Bool raise WgslIrEmitError {
  match function {
    Some(function) =>
      match function.expressions.origin(handle) {
        Some(
          FoldedLocalConstant
          | RetainedSourceLetExpression
          | SourceLocalConstInitializer
        ) => return true
        _ => ()
      }
    None => ()
  }
  match self.required_expression(function, handle) {
    Compose(_, components) => {
      for component in components {
        if self.expression_tree_contains_folded_local_constant(
            function, component,
          ) {
          return true
        }
      }
      false
    }
    Splat(_, inner)
    | Swizzle(_, inner, _)
    | Unary(_, inner)
    | As(inner, _, _)
    | Bitcast(_, inner) =>
      self.expression_tree_contains_folded_local_constant(function, inner)
    Binary(_, left, right) =>
      self.expression_tree_contains_folded_local_constant(function, left) ||
      self.expression_tree_contains_folded_local_constant(function, right)
    _ => false
  }
}

///|
fn WgslIrEmitter::folded_scalar_constructor_expression(
  self : WgslIrEmitter,
  ty : Handle,
  components : Array[Handle],
  function : Function?,
) -> String? raise WgslIrEmitError {
  if !self.options.fold_numeric_constant_expressions() ||
    components.length() != 1 {
    return None
  }
  guard self.shader_module.types.items.get(ty.index()) is Some(type_) else {
    raise MissingHandle("type \{ty.index()}")
  }
  guard type_.inner is Scalar(target) else { return None }
  guard target.kind == Float else { return None }
  let expression = self.required_expression(function, components[0])
  match expression {
    Literal(literal) =>
      match wgsl_ir_float_value_from_numeric_literal(literal) {
        Some(value) => self.float_value_literal_for_width(value, target.width)
        None => None
      }
    Constant(handle) =>
      match self.eval_constant_float_expression_for_constructor(handle) {
        Some(value) => self.float_value_literal_for_width(value, target.width)
        None =>
          match self.eval_constant_integer_expression_for_constructor(handle) {
            Some(value) =>
              match value.to_double() {
                Some(value) =>
                  self.float_value_literal_for_width(value, target.width)
                None => None
              }
            None => None
          }
      }
    _ =>
      match
        self.eval_float_expression_with_retained_constants(
          function,
          components[0],
        ) {
        Some(value) => self.float_value_literal_for_width(value, target.width)
        None => None
      }
  }
}

///|
fn wgsl_ir_float_value_from_numeric_literal(literal : Literal) -> Double? {
  match literal {
    F16(value) | F64(value) | AbstractFloat(value) => Some(value)
    F32(value) | F32Exact(value) => Some(value.to_double())
    I32(value) => Some(Double::from_int(value))
    U32(value) => Some(value.to_double())
    AbstractInt(value) => Some(value.to_double())
    _ => None
  }
}

///|
fn WgslIrEmitIntegerValue::to_double(self : WgslIrEmitIntegerValue) -> Double? {
  match self {
    Signed(value) => Some(Double::from_int(value))
    Unsigned(value) => Some(value.to_double())
    Abstract(value) => Some(value.to_double())
  }
}

///|
fn WgslIrEmitter::compose_component_scalar_context(
  self : WgslIrEmitter,
  ty : Handle,
  components : Array[Handle],
  function : Function?,
) -> Scalar? {
  guard self.shader_module.types.items.get(ty.index()) is Some(type_) else {
    return None
  }
  match type_.inner {
    Scalar(scalar) => Some(scalar)
    Vector(_, scalar) => {
      let scalar = if wgsl_ir_scalar_kind_is_abstract(scalar.kind) {
        match self.concrete_component_scalar_context(function, components) {
          Some(value) => value
          None => scalar
        }
      } else {
        scalar
      }
      for component in components {
        if !self.expression_is_scalar_type(function, component, scalar) {
          return None
        }
      }
      Some(scalar)
    }
    _ => None
  }
}

///|
fn WgslIrEmitter::concrete_component_scalar_context(
  self : WgslIrEmitter,
  function : Function?,
  components : Array[Handle],
) -> Scalar? {
  let mut scalar : Scalar? = None
  for component in components {
    guard self.expression_component_scalar(function, component) is Some(value) else {
      return None
    }
    if wgsl_ir_scalar_kind_is_abstract(value.kind) {
      return None
    }
    match scalar {
      Some(existing) => if existing != value { return None }
      None => scalar = Some(value)
    }
  }
  scalar
}

///|
fn WgslIrEmitter::compose_component_expression(
  self : WgslIrEmitter,
  function : Function?,
  component : Handle,
  scalar_context : Scalar?,
) -> String raise WgslIrEmitError {
  match scalar_context {
    Some(scalar) =>
      match self.contextual_scalar_literal(function, component, scalar) {
        Some(value) => value
        None =>
          match
            self.constructor_scalar_folded_expression(
              function, component, scalar,
            ) {
            Some(value) => value
            None => self.required_function_expression(function, component)
          }
      }
    None =>
      match self.constructor_component_folded_expression(function, component) {
        Some(value) => value
        None => self.required_function_expression(function, component)
      }
  }
}

///|
fn WgslIrEmitter::constructor_component_folded_expression(
  self : WgslIrEmitter,
  function : Function?,
  operand : Handle,
) -> String? raise WgslIrEmitError {
  match self.expression_component_scalar(function, operand) {
    Some({ kind: AbstractFloat, .. }) =>
      self.constructor_scalar_folded_expression(function, operand, {
        kind: Float,
        width: 4,
      })
    Some(scalar) if !wgsl_ir_scalar_kind_is_abstract(scalar.kind) =>
      self.constructor_scalar_folded_expression(function, operand, scalar)
    _ =>
      self.constructor_scalar_folded_expression(function, operand, {
        kind: Float,
        width: 4,
      })
  }
}

///|
fn WgslIrEmitter::constructor_scalar_folded_expression(
  self : WgslIrEmitter,
  function : Function?,
  operand : Handle,
  scalar : Scalar,
) -> String? raise WgslIrEmitError {
  guard self.options.fold_numeric_constant_expressions() else { return None }
  if self.expression_tree_contains_folded_local_constant(function, operand) {
    return None
  }
  match scalar.kind {
    Float | AbstractFloat =>
      match self.eval_float_expression_for_writer(function, operand) {
        Some(value) => self.float_value_literal_for_width(value, scalar.width)
        None =>
          match
            self.eval_float_expression_with_retained_constants(
              function, operand,
            ) {
            Some(value) =>
              self.float_value_literal_for_width(value, scalar.width)
            None => None
          }
      }
    _ => None
  }
}
