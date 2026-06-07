///|
fn wgsl_ir_switch_value_from_ast_expression(
  lowerer : WgslIrLowerer,
  function : Function,
  scope : WgslIrFunctionScope,
  selector : Handle,
  expr_ref : @ast.WgslExprRef,
) -> SwitchValue raise WgslIrLowerError {
  guard expr_ref.root() is Some(root) else {
    raise UnsupportedExpression("empty switch case selector")
  }
  let selector_is_unsigned = lowerer.switch_selector_is_unsigned(
    function, selector,
  )
  lowerer
  .eval_ast_integer_expression(root, function, scope)
  .to_switch_value(
    selector_is_unsigned,
    wgsl_ir_switch_case_label_style_from_ast_expression(root),
  )
}

///|
fn wgsl_ir_switch_case_label_style_from_ast_expression(
  node : @ast.WgslExprNode,
) -> SwitchCaseLabelStyle {
  match node.kind() {
    Group(inner) | Sequence([inner]) =>
      wgsl_ir_switch_case_label_style_from_ast_expression(inner)
    Literal(token) =>
      match token.numeric_literal() {
        Some({ category: AbstractIntLiteral, suffix: NoSuffix, .. }) =>
          SourceAbstractInt
        _ => Typed
      }
    _ => Typed
  }
}

///|
fn WgslIrLowerer::switch_selector_is_unsigned(
  self : WgslIrLowerer,
  function : Function,
  selector : Handle,
) -> Bool {
  match self.function_expression_type(function, selector) {
    Some(ty_handle) =>
      match self.shader_module.types.get(ty_handle) {
        Some(ty) =>
          match ty.inner {
            Scalar(scalar) => scalar.kind == Uint
            _ => false
          }
        None => false
      }
    None => false
  }
}

///|
fn WgslIrLowerer::eval_ast_integer_expression(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> WgslIrIntegerValue raise WgslIrLowerError {
  match node.kind() {
    Literal(token) => wgsl_ir_eval_ast_integer_literal(token)
    Identifier(name) =>
      self.eval_ast_integer_identifier(name.name(), function, scope)
    Unary(op, inner) =>
      match wgsl_ir_unary_operator(op) {
        Negate => {
          let value = self
            .eval_ast_integer_expression(inner, function, scope)
            .to_signed_int()
          Signed(-value)
        }
        BitwiseNot =>
          match self.eval_ast_integer_expression(inner, function, scope) {
            Unsigned(value) => Unsigned(value.lnot())
            Signed(value) => Signed(value.lnot())
            Abstract(value) => Abstract(value.lnot())
          }
        LogicalNot =>
          raise UnsupportedExpression(
            "switch case const selector uses non-integer unary operator",
          )
      }
    Binary(op, left, right) =>
      wgsl_ir_eval_integer_binary(
        wgsl_ir_binary_operator(op),
        self.eval_ast_integer_expression(left, function, scope),
        self.eval_ast_integer_expression(right, function, scope),
      )
    Call(callee, arguments) => {
      let arguments = wgsl_ir_call_arguments(arguments)
      self.eval_ast_integer_call(callee, arguments, function, scope)
    }
    Group(inner) => self.eval_ast_integer_expression(inner, function, scope)
    Sequence([single]) =>
      self.eval_ast_integer_expression(single, function, scope)
    _ =>
      raise UnsupportedExpression(
        "switch case const selector must initialize to an integer expression",
      )
  }
}

///|
fn wgsl_ir_eval_ast_integer_literal(
  token : @ast.WgslExprToken,
) -> WgslIrIntegerValue raise WgslIrLowerError {
  match wgsl_ir_literal_from_token(token) {
    I32(value) => Signed(value)
    U32(value) => Unsigned(value)
    AbstractInt(value) => Abstract(value)
    _ =>
      raise UnsupportedExpression(
        "switch case const selector must initialize to an integer expression",
      )
  }
}

///|
fn WgslIrLowerer::eval_ast_integer_identifier(
  self : WgslIrLowerer,
  name : String,
  function : Function,
  scope : WgslIrFunctionScope,
) -> WgslIrIntegerValue raise WgslIrLowerError {
  match scope.local_constants.get(name) {
    Some({ value: LazyConstant(local_constant), .. }) =>
      match local_constant.expr_ref.root() {
        Some(root) =>
          return self.eval_ast_integer_expression(root, function, scope)
        None => raise UnsupportedExpression("empty local const selector")
      }
    Some({ value: ExpressionAlias(handle, _), .. }) =>
      return self.eval_function_integer_expression(function, handle)
    None => ()
  }
  match self.ensure_constant_declaration_lowered(name) {
    Some(handle) =>
      match self.shader_module.constants.items.get(handle.index()) {
        Some(constant) => self.eval_global_integer_expression(constant.init)
        None =>
          raise UnsupportedExpression(
            "switch case selector references missing const",
          )
      }
    None => raise UnknownIdentifier(name)
  }
}

///|
fn WgslIrLowerer::eval_ast_integer_call(
  self : WgslIrLowerer,
  callee : @ast.WgslExprNode,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> WgslIrIntegerValue raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard callee.kind() is Identifier(name) else {
    raise UnsupportedExpression("switch case selector uses non-identifier call")
  }
  match name.name() {
    "i32" => {
      guard arguments is [argument] else {
        raise UnsupportedExpression(
          "i32 switch selector cast expects one argument",
        )
      }
      Signed(
        self
        .eval_ast_integer_expression(argument, function, scope)
        .to_signed_int(),
      )
    }
    "u32" => {
      guard arguments is [argument] else {
        raise UnsupportedExpression(
          "u32 switch selector cast expects one argument",
        )
      }
      Unsigned(
        self
        .eval_ast_integer_expression(argument, function, scope)
        .to_unsigned(),
      )
    }
    _ =>
      match wgsl_ir_math_function_from_name(name.name()) {
        Some(Min) => {
          guard arguments is [left, right] else {
            raise UnsupportedExpression(
              "min switch selector expects two arguments",
            )
          }
          wgsl_ir_eval_integer_min(
            self.eval_ast_integer_expression(left, function, scope),
            self.eval_ast_integer_expression(right, function, scope),
          )
        }
        Some(Max) => {
          guard arguments is [left, right] else {
            raise UnsupportedExpression(
              "max switch selector expects two arguments",
            )
          }
          wgsl_ir_eval_integer_max(
            self.eval_ast_integer_expression(left, function, scope),
            self.eval_ast_integer_expression(right, function, scope),
          )
        }
        Some(Clamp) => {
          guard arguments is [value, low, high] else {
            raise UnsupportedExpression(
              "clamp switch selector expects three arguments",
            )
          }
          wgsl_ir_eval_integer_clamp(
            self.eval_ast_integer_expression(value, function, scope),
            self.eval_ast_integer_expression(low, function, scope),
            self.eval_ast_integer_expression(high, function, scope),
          )
        }
        _ =>
          raise UnsupportedExpression(
            "switch case selector uses non-integer const call",
          )
      }
  }
}

///|
fn WgslIrLowerer::switch_case_constant_dependencies(
  self : WgslIrLowerer,
  expr_ref : @ast.WgslExprRef,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Array[Handle] raise WgslIrLowerError {
  let dependencies : Array[Handle] = []
  match expr_ref.root() {
    Some(root) =>
      self.collect_ast_integer_constant_dependencies(
        root, function, scope, dependencies,
      )
    None => ()
  }
  dependencies
}

///|
fn WgslIrLowerer::collect_ast_integer_constant_dependencies(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
  dependencies : Array[Handle],
) -> Unit raise WgslIrLowerError {
  match node.kind() {
    Identifier(name) =>
      self.collect_ast_identifier_constant_dependencies(
        name.name(),
        function,
        scope,
        dependencies,
      )
    Unary(_, inner) | Group(inner) =>
      self.collect_ast_integer_constant_dependencies(
        inner, function, scope, dependencies,
      )
    Binary(_, left, right) => {
      self.collect_ast_integer_constant_dependencies(
        left, function, scope, dependencies,
      )
      self.collect_ast_integer_constant_dependencies(
        right, function, scope, dependencies,
      )
    }
    Call(_, arguments) =>
      for argument in wgsl_ir_flatten_expression_arguments(arguments) {
        self.collect_ast_integer_constant_dependencies(
          argument, function, scope, dependencies,
        )
      }
    Sequence(items) =>
      for item in items {
        self.collect_ast_integer_constant_dependencies(
          item, function, scope, dependencies,
        )
      }
    Literal(_) | ShaderDefTemplate(_) => ()
    _ =>
      raise UnsupportedExpression(
        "switch case const selector must initialize to an integer expression",
      )
  }
}

///|
fn WgslIrLowerer::collect_ast_identifier_constant_dependencies(
  self : WgslIrLowerer,
  name : String,
  function : Function,
  scope : WgslIrFunctionScope,
  dependencies : Array[Handle],
) -> Unit raise WgslIrLowerError {
  match scope.local_constants.get(name) {
    Some({ value: LazyConstant(local_constant), .. }) => {
      match local_constant.expr_ref.root() {
        Some(root) =>
          self.collect_ast_integer_constant_dependencies(
            root, function, scope, dependencies,
          )
        None => ()
      }
      return
    }
    Some({ value: ExpressionAlias(handle, _), .. }) => {
      self.collect_function_expression_constant_dependencies(
        function, handle, dependencies,
      )
      return
    }
    None => ()
  }
  match self.ensure_constant_declaration_lowered(name) {
    Some(handle) => dependencies.push(handle)
    None => ()
  }
}

///|
fn WgslIrLowerer::collect_function_expression_constant_dependencies(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle,
  dependencies : Array[Handle],
) -> Unit {
  match function.expressions.items.get(handle.index()) {
    Some(expression) =>
      match expression {
        Constant(handle) => dependencies.push(handle)
        Unary(_, inner) | As(inner, _, _) | Bitcast(_, inner) =>
          self.collect_function_expression_constant_dependencies(
            function, inner, dependencies,
          )
        Binary(_, left, right) => {
          self.collect_function_expression_constant_dependencies(
            function, left, dependencies,
          )
          self.collect_function_expression_constant_dependencies(
            function, right, dependencies,
          )
        }
        Math(_, a, b, c, d) => {
          self.collect_function_expression_constant_dependencies(
            function, a, dependencies,
          )
          wgsl_ir_collect_optional_function_expression_constant_dependencies(
            self, function, b, dependencies,
          )
          wgsl_ir_collect_optional_function_expression_constant_dependencies(
            self, function, c, dependencies,
          )
          wgsl_ir_collect_optional_function_expression_constant_dependencies(
            self, function, d, dependencies,
          )
        }
        _ => ()
      }
    None => ()
  }
}

///|
fn wgsl_ir_collect_optional_function_expression_constant_dependencies(
  lowerer : WgslIrLowerer,
  function : Function,
  handle : Handle?,
  dependencies : Array[Handle],
) -> Unit {
  match handle {
    Some(handle) =>
      lowerer.collect_function_expression_constant_dependencies(
        function, handle, dependencies,
      )
    None => ()
  }
}

///|
fn WgslIrLowerer::eval_global_integer_expression(
  self : WgslIrLowerer,
  handle : Handle,
) -> WgslIrIntegerValue raise WgslIrLowerError {
  match self.shader_module.global_expressions.items.get(handle.index()) {
    Some(expression) => self.eval_global_integer_expression_inner(expression)
    None =>
      raise UnsupportedExpression(
        "switch case selector references missing expression",
      )
  }
}

///|
fn WgslIrLowerer::lower_function_constant_array_size_expression(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle,
) -> ArraySize raise WgslIrLowerError {
  let evaluated = Some(self.eval_function_integer_expression(function, handle)) catch {
    _ => None
  }
  match evaluated {
    Some(value) => Constant(value.to_non_negative_int())
    None =>
      raise UnsupportedType(
        "local array size must resolve to an integer const expression",
      )
  }
}

///|
fn WgslIrLowerer::eval_function_integer_expression(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle,
) -> WgslIrIntegerValue raise WgslIrLowerError {
  match function.expressions.items.get(handle.index()) {
    Some(expression) =>
      self.eval_function_integer_expression_inner(function, expression)
    None =>
      raise UnsupportedExpression("array size references missing expression")
  }
}

///|
fn WgslIrLowerer::eval_function_integer_expression_inner(
  self : WgslIrLowerer,
  function : Function,
  expression : Expression,
) -> WgslIrIntegerValue raise WgslIrLowerError {
  match expression {
    Literal(I32(value)) => Signed(value)
    Literal(U32(value)) => Unsigned(value)
    Literal(AbstractInt(value)) => Abstract(value)
    Constant(handle) =>
      match self.shader_module.constants.items.get(handle.index()) {
        Some(constant) => self.eval_global_integer_expression(constant.init)
        None =>
          raise UnsupportedExpression(
            "array size references missing nested const",
          )
      }
    Binary(op, left, right) => {
      let left_value = self.eval_function_integer_expression(function, left)
      let right_value = self.eval_function_integer_expression(function, right)
      wgsl_ir_eval_integer_binary(op, left_value, right_value)
    }
    Unary(Negate, inner) => {
      let value = self
        .eval_function_integer_expression(function, inner)
        .to_signed_int()
      Signed(-value)
    }
    Unary(BitwiseNot, inner) =>
      match self.eval_function_integer_expression(function, inner) {
        Unsigned(value) => Unsigned(value.lnot())
        Signed(value) => Signed(value.lnot())
        Abstract(value) => Abstract(value.lnot())
      }
    _ =>
      raise UnsupportedExpression(
        "array size must initialize to an integer expression",
      )
  }
}

///|
fn WgslIrLowerer::eval_constant_integer_expression(
  self : WgslIrLowerer,
  handle : Handle,
) -> WgslIrIntegerValue raise WgslIrLowerError {
  match self.shader_module.constants.items.get(handle.index()) {
    Some(constant) => self.eval_global_integer_expression(constant.init)
    None =>
      raise UnsupportedExpression(
        "constant expression references missing const",
      )
  }
}

///|
fn WgslIrLowerer::eval_global_integer_expression_inner(
  self : WgslIrLowerer,
  expression : Expression,
) -> WgslIrIntegerValue raise WgslIrLowerError {
  match expression {
    Literal(I32(value)) => Signed(value)
    Literal(U32(value)) => Unsigned(value)
    Literal(AbstractInt(value)) => Abstract(value)
    Constant(handle) =>
      match self.shader_module.constants.items.get(handle.index()) {
        Some(constant) => self.eval_global_integer_expression(constant.init)
        None =>
          raise UnsupportedExpression(
            "switch case selector references missing nested const",
          )
      }
    Binary(op, left, right) => {
      let left_value = self.eval_global_integer_expression(left)
      let right_value = self.eval_global_integer_expression(right)
      wgsl_ir_eval_integer_binary(op, left_value, right_value)
    }
    Math(Min, a, Some(b), None, None) =>
      wgsl_ir_eval_integer_min(
        self.eval_global_integer_expression(a),
        self.eval_global_integer_expression(b),
      )
    Math(Max, a, Some(b), None, None) =>
      wgsl_ir_eval_integer_max(
        self.eval_global_integer_expression(a),
        self.eval_global_integer_expression(b),
      )
    Math(Clamp, value, Some(low), Some(high), None) =>
      wgsl_ir_eval_integer_clamp(
        self.eval_global_integer_expression(value),
        self.eval_global_integer_expression(low),
        self.eval_global_integer_expression(high),
      )
    Unary(Negate, inner) => {
      let value = self.eval_global_integer_expression(inner).to_signed_int()
      Signed(-value)
    }
    Unary(BitwiseNot, inner) =>
      match self.eval_global_integer_expression(inner) {
        Unsigned(value) => Unsigned(value.lnot())
        Signed(value) => Signed(value.lnot())
        Abstract(value) => Abstract(value.lnot())
      }
    _ =>
      raise UnsupportedExpression(
        "switch case const selector must initialize to an integer expression",
      )
  }
}

///|
priv enum WgslIrIntegerValue {
  Signed(Int)
  Unsigned(UInt)
  Abstract(Int64)
}

///|
fn WgslIrIntegerValue::is_unsigned(self : WgslIrIntegerValue) -> Bool {
  match self {
    Unsigned(_) => true
    Signed(_) | Abstract(_) => false
  }
}

///|
fn WgslIrIntegerValue::to_switch_value(
  self : WgslIrIntegerValue,
  selector_is_unsigned : Bool,
  label_style : SwitchCaseLabelStyle,
) -> SwitchValue raise WgslIrLowerError {
  if selector_is_unsigned {
    U32(self.to_unsigned(), label_style)
  } else {
    match self {
      Unsigned(value) =>
        I32(WgslIrIntegerValue::Unsigned(value).to_signed_int(), label_style)
      Signed(value) => I32(value, label_style)
      Abstract(value) => I32(wgsl_ir_int64_to_i32(value), label_style)
    }
  }
}

///|
fn WgslIrIntegerValue::to_signed_int(
  self : WgslIrIntegerValue,
) -> Int raise WgslIrLowerError {
  match self {
    Signed(value) => value
    Abstract(value) => wgsl_ir_int64_to_i32(value)
    Unsigned(value) =>
      match wgsl_ir_uint_literal_to_small_int(value) {
        Some(value) => value
        None =>
          raise UnsupportedExpression(
            "integer expression is outside signed int range",
          )
      }
  }
}

///|
fn WgslIrIntegerValue::to_unsigned(
  self : WgslIrIntegerValue,
) -> UInt raise WgslIrLowerError {
  match self {
    Unsigned(value) => value
    Signed(value) => wgsl_ir_non_negative_int_to_uint(value)
    Abstract(value) => {
      if value < Int64::from_int(0) {
        raise UnsupportedExpression(
          "unsigned integer expression contains a negative operand",
        )
      }
      if value > 4294967295L {
        raise UnsupportedExpression(
          "integer expression is outside unsigned int range",
        )
      }
      value.reinterpret_as_uint64().to_uint()
    }
  }
}

///|
fn wgsl_ir_non_negative_int_to_uint(value : Int) -> UInt raise WgslIrLowerError {
  if value < 0 {
    raise UnsupportedExpression(
      "unsigned integer expression contains a negative operand",
    )
  }
  value.reinterpret_as_uint()
}

///|
fn WgslIrIntegerValue::to_non_negative_int(
  self : WgslIrIntegerValue,
) -> Int raise WgslIrLowerError {
  let value = self.to_signed_int()
  if value < 0 {
    raise UnsupportedExpression("integer expression must be non-negative")
  }
  value
}

///|
fn WgslIrIntegerValue::to_signed_literal(
  self : WgslIrIntegerValue,
  width : Int,
) -> Literal raise WgslIrLowerError {
  let value = self.to_signed_int()
  match width {
    8 => I64(Int64::from_int(value))
    _ => I32(value)
  }
}

///|
fn WgslIrIntegerValue::to_unsigned_literal(
  self : WgslIrIntegerValue,
  width : Int,
) -> Literal raise WgslIrLowerError {
  let value = self.to_unsigned()
  match width {
    8 => U64(value.to_uint64())
    _ => U32(value)
  }
}

///|
fn WgslIrIntegerValue::to_abstract_int_literal(
  self : WgslIrIntegerValue,
) -> Literal raise WgslIrLowerError {
  match self {
    Abstract(value) => AbstractInt(value)
    Signed(value) => AbstractInt(Int64::from_int(value))
    Unsigned(value) =>
      AbstractInt(
        Int64::from_int(WgslIrIntegerValue::Unsigned(value).to_signed_int()),
      )
  }
}

///|
fn wgsl_ir_eval_integer_binary(
  op : BinaryOperator,
  left : WgslIrIntegerValue,
  right : WgslIrIntegerValue,
) -> WgslIrIntegerValue raise WgslIrLowerError {
  if left.is_unsigned() || right.is_unsigned() {
    let left = left.to_unsigned()
    let right_value = right.to_unsigned()
    let right_shift = WgslIrIntegerValue::Unsigned(right_value).to_non_negative_int()
    return match op {
      Add => Unsigned(left + right_value)
      Subtract => Unsigned(left - right_value)
      Multiply => Unsigned(left * right_value)
      Divide => Unsigned(left / right_value)
      Modulo => Unsigned(left % right_value)
      And => Unsigned(left & right_value)
      ExclusiveOr => Unsigned(left ^ right_value)
      InclusiveOr => Unsigned(left | right_value)
      ShiftLeft => Unsigned(left << right_shift)
      ShiftRight => Unsigned(left >> right_shift)
      _ =>
        raise UnsupportedExpression(
          "switch case const selector uses non-integer binary operator",
        )
    }
  }
  let left = left.to_signed_int()
  let right = right.to_signed_int()
  match op {
    Add => Signed(left + right)
    Subtract => Signed(left - right)
    Multiply => Signed(left * right)
    Divide => Signed(left / right)
    Modulo => Signed(left % right)
    And => Signed(left & right)
    ExclusiveOr => Signed(left ^ right)
    InclusiveOr => Signed(left | right)
    ShiftLeft => Signed(left << right)
    ShiftRight => Signed(left >> right)
    _ =>
      raise UnsupportedExpression(
        "switch case const selector uses non-integer binary operator",
      )
  }
}

///|
fn wgsl_ir_eval_integer_min(
  left : WgslIrIntegerValue,
  right : WgslIrIntegerValue,
) -> WgslIrIntegerValue raise WgslIrLowerError {
  if left.is_unsigned() || right.is_unsigned() {
    let left = left.to_unsigned()
    let right = right.to_unsigned()
    Unsigned(if left < right { left } else { right })
  } else {
    let left = left.to_signed_int()
    let right = right.to_signed_int()
    Signed(if left < right { left } else { right })
  }
}

///|
fn wgsl_ir_eval_integer_max(
  left : WgslIrIntegerValue,
  right : WgslIrIntegerValue,
) -> WgslIrIntegerValue raise WgslIrLowerError {
  if left.is_unsigned() || right.is_unsigned() {
    let left = left.to_unsigned()
    let right = right.to_unsigned()
    Unsigned(if left > right { left } else { right })
  } else {
    let left = left.to_signed_int()
    let right = right.to_signed_int()
    Signed(if left > right { left } else { right })
  }
}

///|
fn wgsl_ir_eval_integer_clamp(
  value : WgslIrIntegerValue,
  low : WgslIrIntegerValue,
  high : WgslIrIntegerValue,
) -> WgslIrIntegerValue raise WgslIrLowerError {
  wgsl_ir_eval_integer_min(wgsl_ir_eval_integer_max(value, low), high)
}

///|
fn WgslIrLowerer::fold_function_constant_float_expression(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle,
) -> Literal? {
  match self.eval_function_float_expression(function, handle) {
    Some(value) =>
      Some(
        self.folded_function_float_literal_for_expression(
          function, handle, value,
        ),
      )
    None => None
  }
}

///|
fn WgslIrLowerer::folded_function_float_literal_for_expression(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle,
  value : Double,
) -> Literal {
  self.folded_function_float_literal_for_expression_with_expected(
    function,
    handle,
    value,
    None,
  )
}

///|
fn WgslIrLowerer::folded_function_float_literal_for_expression_with_expected(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle,
  value : Double,
  expected_ty : Handle?,
) -> Literal {
  let ty = match expected_ty {
    Some(ty) => ty
    None =>
      match self.function_expression_type(function, handle) {
        Some(ty) => ty
        None => return AbstractFloat(value)
      }
  }
  guard self.shader_module.types.get(ty) is Some(type_) else {
    return AbstractFloat(value)
  }
  match type_.inner {
    Scalar({ kind: Float, width: 4 }) =>
      if wgsl_ir_function_expression_is_computed_float_fold(function, handle) {
        F32Exact(Float::from_double(value))
      } else {
        F32(Float::from_double(value))
      }
    Scalar({ kind: Float, width }) =>
      wgsl_ir_float_literal_for_scalar_width(value, width)
    _ =>
      if wgsl_ir_function_expression_is_computed_float_fold(function, handle) &&
        self.function_expression_tree_contains_concrete_f32_value(
          function, handle,
        ) {
        F32Exact(Float::from_double(value))
      } else {
        AbstractFloat(value)
      }
  }
}

///|
fn WgslIrLowerer::function_expression_tree_contains_concrete_f32_value(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle,
) -> Bool {
  match function.expressions.items.get(handle.index()) {
    Some(Literal(F32(_) | F32Exact(_))) => true
    Some(Constant(constant)) => self.constant_is_concrete_f32(constant)
    Some(Unary(_, inner)) | Some(Load(inner)) | Some(Splat(_, inner)) =>
      self.function_expression_tree_contains_concrete_f32_value(function, inner)
    Some(Binary(_, left, right)) =>
      self.function_expression_tree_contains_concrete_f32_value(function, left) ||
      self.function_expression_tree_contains_concrete_f32_value(function, right)
    Some(Math(_, a, b, c, d)) =>
      self.function_expression_tree_contains_concrete_f32_value(function, a) ||
      self.optional_function_expression_tree_contains_concrete_f32_value(
        function, b,
      ) ||
      self.optional_function_expression_tree_contains_concrete_f32_value(
        function, c,
      ) ||
      self.optional_function_expression_tree_contains_concrete_f32_value(
        function, d,
      )
    _ => false
  }
}

///|
fn WgslIrLowerer::optional_function_expression_tree_contains_concrete_f32_value(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle?,
) -> Bool {
  match handle {
    Some(handle) =>
      self.function_expression_tree_contains_concrete_f32_value(
        function, handle,
      )
    None => false
  }
}

///|
fn WgslIrLowerer::constant_is_concrete_f32(
  self : WgslIrLowerer,
  handle : Handle,
) -> Bool {
  match self.shader_module.constants.items.get(handle.index()) {
    Some(constant) =>
      match self.shader_module.types.get(constant.ty) {
        Some({ inner: Scalar({ kind: Float, width: 4 }), .. }) => true
        _ => false
      }
    None => false
  }
}

///|
fn wgsl_ir_function_expression_is_computed_float_fold(
  function : Function,
  handle : Handle,
) -> Bool {
  match function.expressions.items.get(handle.index()) {
    Some(Literal(_)) => false
    Some(_) => true
    None => false
  }
}

///|
fn WgslIrLowerer::fold_function_constant_float_vector_expression(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle,
) -> (Handle, Array[Double])? {
  guard self.function_expression_tree_contains_constant_reference(
    function, handle,
  ) else {
    return None
  }
  guard self.function_expression_type(function, handle) is Some(ty) else {
    return None
  }
  guard self.shader_module.types.get(ty) is Some(type_) else { return None }
  let (size, scalar) = match type_.inner {
    Vector(size, scalar) => {
      let scalar = match scalar.kind {
        AbstractFloat => Scalar::{ kind: Float, width: 4 }
        Float => scalar
        _ => return None
      }
      (size, scalar)
    }
    _ => return None
  }
  guard self.eval_function_float_vector_expression(function, handle)
    is Some(values) else {
    return None
  }
  guard values.length() == size.width() else { return None }
  Some((self.vector_type_handle(size, scalar), values))
}

///|
fn WgslIrLowerer::append_function_float_vector_literal_compose(
  self : WgslIrLowerer,
  function : Function,
  ty : Handle,
  values : Array[Double],
) -> Handle raise WgslIrLowerError {
  guard self.shader_module.types.get(ty) is Some(type_) else {
    raise UnsupportedExpression("folded float vector uses missing type")
  }
  guard type_.inner is Vector(_, scalar) else {
    raise UnsupportedExpression("folded float vector uses non-vector type")
  }
  let components : Array[Handle] = []
  for value in values {
    components.push(
      function.expressions.append_with_origin(
        Literal(wgsl_ir_float_literal_for_scalar_width(value, scalar.width)),
        FoldedLocalConstant,
      ),
    )
  }
  function.expressions.append_with_origin(
    Compose(ty, components),
    FoldedLocalConstant,
  )
}

///|
fn WgslIrLowerer::eval_function_float_vector_expression(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle,
) -> Array[Double]? {
  match function.expressions.items.get(handle.index()) {
    Some(expression) =>
      self.eval_function_float_vector_expression_inner(function, expression)
    None => None
  }
}

///|
fn WgslIrLowerer::eval_function_float_vector_expression_inner(
  self : WgslIrLowerer,
  function : Function,
  expression : Expression,
) -> Array[Double]? {
  match expression {
    Literal(literal) =>
      match wgsl_ir_float_value_from_literal_for_lowerer(literal) {
        Some(value) => Some([value])
        None => None
      }
    Constant(handle) =>
      match self.eval_constant_float_expression(handle) {
        Some(value) => Some([value])
        None => {
          let integer = Some(self.eval_constant_integer_expression(handle)) catch {
            _ => None
          }
          match integer {
            Some(value) => Some([value.to_double()])
            None => None
          }
        }
      }
    Unary(Negate, inner) =>
      match self.eval_function_float_vector_expression(function, inner) {
        Some(values) => Some(values.map(fn(value) { -value }))
        None => None
      }
    Splat(size, inner) =>
      match self.eval_function_float_expression(function, inner) {
        Some(value) => {
          let values : Array[Double] = []
          for _ in 0..<size.width() {
            values.push(value)
          }
          Some(values)
        }
        None => None
      }
    Compose(_, components) => {
      let values : Array[Double] = []
      for component in components {
        match self.eval_function_float_expression(function, component) {
          Some(value) => values.push(value)
          None => return None
        }
      }
      Some(values)
    }
    Binary(op, left, right) => {
      guard self.eval_function_float_vector_expression(function, left)
        is Some(left_values) else {
        return None
      }
      guard self.eval_function_float_vector_expression(function, right)
        is Some(right_values) else {
        return None
      }
      wgsl_ir_eval_float_vector_binary_for_lowerer(
        op, left_values, right_values,
      )
    }
    _ => None
  }
}

///|
fn wgsl_ir_float_value_from_literal_for_lowerer(literal : Literal) -> Double? {
  match literal {
    AbstractFloat(value) => Some(value)
    F32(value) | F32Exact(value) => Some(value.to_double())
    F16(value) | F64(value) => Some(value)
    _ => None
  }
}

///|
fn wgsl_ir_eval_float_vector_binary_for_lowerer(
  op : BinaryOperator,
  left : Array[Double],
  right : Array[Double],
) -> Array[Double]? {
  let width = if left.length() == right.length() {
    left.length()
  } else if left.length() == 1 {
    right.length()
  } else if right.length() == 1 {
    left.length()
  } else {
    return None
  }
  let values : Array[Double] = []
  for index in 0..<width {
    let left_value = if left.length() == 1 { left[0] } else { left[index] }
    let right_value = if right.length() == 1 { right[0] } else { right[index] }
    match wgsl_ir_eval_float_binary(op, left_value, right_value) {
      Some(value) => values.push(value)
      None => return None
    }
  }
  Some(values)
}

///|
fn WgslIrLowerer::function_expression_tree_contains_constant_reference(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle,
) -> Bool {
  match function.expressions.items.get(handle.index()) {
    Some(expression) =>
      self.function_expression_contains_constant_reference(function, expression)
    None => false
  }
}

///|
fn WgslIrLowerer::function_expression_contains_constant_reference(
  self : WgslIrLowerer,
  function : Function,
  expression : Expression,
) -> Bool {
  match expression {
    Constant(_) => true
    Literal(_)
    | Override(_)
    | FunctionArgument(_)
    | GlobalVariable(_)
    | LocalVariable(_)
    | Load(_)
    | AddressOf(_, _)
    | ZeroValue(_)
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
    Unary(_, inner)
    | Bitcast(_, inner)
    | Relational(_, inner)
    | As(inner, _, _)
    | Splat(_, inner)
    | Swizzle(_, inner, _)
    | AccessIndex(inner, _)
    | Component(inner, _)
    | Derivative(_, _, inner) =>
      self.function_expression_tree_contains_constant_reference(function, inner)
    Access(base, index) | Binary(_, base, index) =>
      self.function_expression_tree_contains_constant_reference(function, base) ||
      self.function_expression_tree_contains_constant_reference(function, index)
    Select(left, right, condition) =>
      self.function_expression_tree_contains_constant_reference(function, left) ||
      self.function_expression_tree_contains_constant_reference(function, right) ||
      self.function_expression_tree_contains_constant_reference(
        function, condition,
      )
    Compose(_, components) =>
      components.any(fn(component) {
        self.function_expression_tree_contains_constant_reference(
          function, component,
        )
      })
    Math(_, first, second, third, fourth) =>
      self.function_expression_tree_contains_constant_reference(function, first) ||
      self.optional_function_expression_contains_constant_reference(
        function, second,
      ) ||
      self.optional_function_expression_contains_constant_reference(
        function, third,
      ) ||
      self.optional_function_expression_contains_constant_reference(
        function, fourth,
      )
  }
}

///|
fn WgslIrLowerer::function_binary_expression_should_retain_generated_import_constant(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle,
) -> Bool {
  match function.expressions.items.get(handle.index()) {
    Some(Binary(Divide, left, right)) =>
      self.function_expression_is_generated_import_constant_reference(
        function, left,
      ) &&
      wgsl_ir_expression_origin_retains_generated_import_denominator(
        function.expressions.origin(right),
      )
    _ => false
  }
}

///|
fn wgsl_ir_expression_origin_retains_generated_import_denominator(
  origin : ExpressionOrigin?,
) -> Bool {
  match origin {
    Some(SourceLocalConstInitializer | RetainedSourceLetExpression) => true
    _ => false
  }
}

///|
fn WgslIrLowerer::function_expression_is_generated_import_constant_reference(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle,
) -> Bool {
  match function.expressions.items.get(handle.index()) {
    Some(Constant(constant_handle)) =>
      match self.shader_module.constants.items.get(constant_handle.index()) {
        Some(constant) => constant.generated_import
        None => false
      }
    _ => false
  }
}

///|
fn WgslIrLowerer::optional_function_expression_contains_constant_reference(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle?,
) -> Bool {
  match handle {
    Some(handle) =>
      self.function_expression_tree_contains_constant_reference(
        function, handle,
      )
    None => false
  }
}

///|
fn WgslIrLowerer::fold_function_constant_literal_expression(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle,
) -> Literal? raise WgslIrLowerError {
  let integer = Some(self.eval_function_integer_expression(function, handle)) catch {
    _ => None
  }
  match integer {
    Some(value) => return Some(value.to_abstract_int_literal())
    None => ()
  }
  self.fold_function_constant_float_expression(function, handle)
}

///|
fn WgslIrLowerer::fold_function_constant_typed_literal_expression(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle,
) -> Literal? raise WgslIrLowerError {
  let integer = Some(self.eval_function_integer_expression(function, handle)) catch {
    _ => None
  }
  match integer {
    Some(value) =>
      match self.function_expression_type(function, handle) {
        Some(ty) =>
          match self.shader_module.types.get(ty) {
            Some({ inner: Scalar(scalar), .. }) =>
              match scalar.kind {
                Sint => return Some(value.to_signed_literal(scalar.width))
                Uint => return Some(value.to_unsigned_literal(scalar.width))
                AbstractInt => return Some(value.to_abstract_int_literal())
                _ => ()
              }
            _ => ()
          }
        None => ()
      }
    None => ()
  }
  self.fold_function_constant_float_expression(function, handle)
}

///|
fn WgslIrLowerer::inline_constant_literal_for_function(
  self : WgslIrLowerer,
  handle : Handle,
) -> Literal? raise WgslIrLowerError {
  guard self.shader_module.constants.items.get(handle.index()) is Some(constant) else {
    return None
  }
  guard self.shader_module.types.get(constant.ty) is Some(ty) else {
    return None
  }
  guard ty.inner is Scalar(scalar) else { return None }
  guard constant.inline_value ||
    scalar.kind == AbstractInt ||
    scalar.kind == AbstractFloat else {
    return None
  }
  match scalar.kind {
    Float =>
      match self.eval_constant_float_expression(handle) {
        Some(value) =>
          if scalar.width == 4 {
            Some(F32Exact(Float::from_double(value)))
          } else {
            Some(wgsl_ir_float_literal_for_scalar_width(value, scalar.width))
          }
        None => None
      }
    AbstractFloat =>
      match self.eval_constant_float_expression(handle) {
        Some(value) => Some(AbstractFloat(value))
        None => None
      }
    Sint =>
      Some(
        self
        .eval_constant_integer_expression(handle)
        .to_signed_literal(scalar.width),
      )
    Uint =>
      Some(
        self
        .eval_constant_integer_expression(handle)
        .to_unsigned_literal(scalar.width),
      )
    AbstractInt =>
      Some(
        self.eval_constant_integer_expression(handle).to_abstract_int_literal(),
      )
    Bool => None
  }
}

///|
fn WgslIrLowerer::normalized_local_constant_initializer(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle,
  expected_ty : Handle?,
) -> Handle raise WgslIrLowerError {
  match function.expressions.items.get(handle.index()) {
    Some(Literal(literal)) => {
      match expected_ty {
        Some(ty) =>
          match self.shader_module.types.get(ty) {
            Some({ inner: Scalar(scalar), .. }) => {
              let contextualized = match
                (
                  function.expressions.origin(handle),
                  scalar.kind,
                  scalar.width,
                  literal,
                ) {
                (Some(FoldedLocalConstant), Float, 4, AbstractFloat(value)) =>
                  F32Exact(Float::from_double(value))
                _ => wgsl_ir_contextualize_literal(literal, scalar)
              }
              function.expressions.set(handle, Literal(contextualized))
            }
            _ => ()
          }
        None => ()
      }
      return handle
    }
    _ => ()
  }
  match self.eval_function_float_expression(function, handle) {
    Some(value) => {
      let literal = self.folded_function_float_literal_for_expression_with_expected(
        function, handle, value, expected_ty,
      )
      return function.expressions.append_with_origin(
        Literal(literal),
        FoldedLocalConstant,
      )
    }
    None => ()
  }
  match self.fold_function_constant_float_expression(function, handle) {
    Some(literal) =>
      function.expressions.append_with_origin(
        Literal(literal),
        FoldedLocalConstant,
      )
    None => handle
  }
}

///|
fn WgslIrLowerer::fold_function_scalar_constructor(
  self : WgslIrLowerer,
  ty : Handle,
  arguments : Array[Handle],
  function : Function,
) -> Literal? raise WgslIrLowerError {
  guard arguments is [argument] else { return None }
  match self.shader_module.types.get(ty) {
    Some({ inner: Scalar(scalar), .. }) =>
      self.fold_function_scalar_constructor_argument(scalar, function, argument)
    _ => None
  }
}

///|
fn WgslIrLowerer::fold_function_scalar_constructor_argument(
  self : WgslIrLowerer,
  scalar : Scalar,
  function : Function,
  argument : Handle,
) -> Literal? raise WgslIrLowerError {
  match scalar.kind {
    Float =>
      match self.eval_function_float_expression(function, argument) {
        Some(value) =>
          Some(wgsl_ir_float_literal_for_scalar_width(value, scalar.width))
        None => {
          let value = self.eval_function_integer_expression(function, argument)
          Some(
            wgsl_ir_float_literal_for_scalar_width(
              value.to_double(),
              scalar.width,
            ),
          )
        }
      }
    Sint =>
      match self.eval_function_integer_expression(function, argument) {
        value =>
          Some(
            match scalar.width {
              8 => I64(Int64::from_int(value.to_signed_int()))
              _ => I32(value.to_signed_int())
            },
          )
      }
    Uint =>
      match self.eval_function_integer_expression(function, argument) {
        value =>
          Some(
            match scalar.width {
              8 => U64(value.to_unsigned().to_uint64())
              _ => U32(value.to_unsigned())
            },
          )
      }
    Bool | AbstractInt | AbstractFloat => None
  }
}

///|
fn WgslIrIntegerValue::to_double(self : WgslIrIntegerValue) -> Double {
  match self {
    Signed(value) => value.to_double()
    Unsigned(value) => value.to_double()
    Abstract(value) => value.to_double()
  }
}

///|
fn wgsl_ir_float_literal_for_scalar_width(
  value : Double,
  width : Int,
) -> Literal {
  match width {
    2 => F16(value)
    8 => F64(value)
    _ => F32(Float::from_double(value))
  }
}

///|
fn WgslIrLowerer::eval_function_float_expression(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle,
) -> Double? {
  match function.expressions.items.get(handle.index()) {
    Some(expression) =>
      self.eval_function_float_expression_inner(function, expression)
    None => None
  }
}

///|
fn WgslIrLowerer::eval_function_float_expression_inner(
  self : WgslIrLowerer,
  function : Function,
  expression : Expression,
) -> Double? {
  match expression {
    Literal(AbstractFloat(value)) => Some(value)
    Literal(F32(value) | F32Exact(value)) => Some(value.to_double())
    Literal(F16(value)) | Literal(F64(value)) => Some(value)
    Constant(handle) => self.eval_constant_float_expression(handle)
    Binary(op, left, right) => {
      guard self.eval_function_float_expression(function, left)
        is Some(left_value) else {
        return None
      }
      guard self.eval_function_float_expression(function, right)
        is Some(right_value) else {
        return None
      }
      wgsl_ir_eval_float_binary(op, left_value, right_value)
    }
    Math(Sqrt, value, None, None, None) => {
      guard self.eval_function_float_expression(function, value) is Some(value) else {
        return None
      }
      Some(value.sqrt())
    }
    _ => None
  }
}

///|
fn WgslIrLowerer::eval_constant_float_expression(
  self : WgslIrLowerer,
  handle : Handle,
) -> Double? {
  match self.shader_module.constants.items.get(handle.index()) {
    Some(constant) => self.eval_global_float_expression(constant.init)
    None => None
  }
}

///|
fn WgslIrLowerer::eval_global_float_expression(
  self : WgslIrLowerer,
  handle : Handle,
) -> Double? {
  match self.shader_module.global_expressions.items.get(handle.index()) {
    Some(expression) => self.eval_global_float_expression_inner(expression)
    None => None
  }
}

///|
fn WgslIrLowerer::eval_global_float_expression_inner(
  self : WgslIrLowerer,
  expression : Expression,
) -> Double? {
  match expression {
    Literal(AbstractFloat(value)) => Some(value)
    Literal(F32(value) | F32Exact(value)) => Some(value.to_double())
    Literal(F16(value)) | Literal(F64(value)) => Some(value)
    Constant(handle) => self.eval_constant_float_expression(handle)
    Binary(op, left, right) => {
      guard self.eval_global_float_expression(left) is Some(left_value) else {
        return None
      }
      guard self.eval_global_float_expression(right) is Some(right_value) else {
        return None
      }
      wgsl_ir_eval_float_binary(op, left_value, right_value)
    }
    _ => None
  }
}

///|
fn wgsl_ir_eval_float_binary(
  op : BinaryOperator,
  left : Double,
  right : Double,
) -> Double? {
  match op {
    Add => Some(left + right)
    Subtract => Some(left - right)
    Multiply => Some(left * right)
    Divide => Some(left / right)
    _ => None
  }
}
