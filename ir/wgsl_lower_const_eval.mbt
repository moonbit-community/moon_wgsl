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
  .to_switch_value(selector_is_unsigned)
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
    Call(callee, arguments) =>
      self.eval_ast_integer_call(callee, arguments, function, scope)
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
    Some({ value: ExpressionAlias(handle), .. }) =>
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
    Some({ value: ExpressionAlias(handle), .. }) => {
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
) -> SwitchValue raise WgslIrLowerError {
  if selector_is_unsigned {
    U32(self.to_unsigned())
  } else {
    match self {
      Unsigned(value) =>
        I32(WgslIrIntegerValue::Unsigned(value).to_signed_int())
      Signed(value) => I32(value)
      Abstract(value) => I32(wgsl_ir_int64_to_i32(value))
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
    Some(value) => Some(AbstractFloat(value))
    None => None
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
          Some(wgsl_ir_float_literal_for_scalar_width(value, scalar.width))
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
) -> Handle {
  match function.expressions.items.get(handle.index()) {
    Some(Literal(_)) => return handle
    _ => ()
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
