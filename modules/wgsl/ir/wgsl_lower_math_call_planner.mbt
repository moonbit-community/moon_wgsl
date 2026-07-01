///|
fn WgslIrLowerer::lower_function_math_call(
  self : WgslIrLowerer,
  math_function : MathFunction,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  let expression_mark = function.expressions.items.length()
  let local_constant_snapshot = wgsl_ir_snapshot_local_constant_values(
    scope.local_constants,
  )
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
  if wgsl_ir_math_call_has_later_function_argument_values(arguments, scope) &&
    !deferred_constructors.contains(0) {
    match
      self.prelower_math_splat_constructor_argument_from_later_context(
        arguments, function, scope,
      ) {
      Some(value) => deferred_constructors.set(0, value)
      None => ()
    }
  }
  if self.math_call_predeclares_later_function_arguments_after_first_consts(
      math_function, arguments, deferred_constructors, function, scope,
    ) {
    self.predeclare_inline_constant_references_in_source_order(
      arguments[0],
      function,
      scope,
    )
    for index in 1..<arguments.length() {
      self.predeclare_function_argument_values_in_source_order(
        arguments[index],
        function,
        scope,
      )
    }
  }
  if self.math_call_predeclares_later_direct_arguments_before_reference_first(
      arguments, function, scope,
    ) {
    for index in 1..<arguments.length() {
      if wgsl_ir_expr_node_is_function_argument_value(arguments[index], scope) {
        self.predeclare_function_argument_value(
          arguments[index],
          function,
          scope,
        )
      }
    }
  }
  self.predeclare_math_later_direct_argument_after_first_constructor_component(
    arguments, function, scope,
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
      wgsl_ir_rewind_function_expressions_and_local_constant_values(
        function, expression_mark, scope, local_constant_snapshot,
      )
      function.expressions.append_with_origin(
        Literal(literal),
        FoldedLocalConstant,
      )
    }
    None => handle
  }
}

///|
fn WgslIrLowerer::predeclare_math_later_direct_argument_after_first_constructor_component(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Unit raise WgslIrLowerError {
  guard arguments.length() >= 3 else { return }
  guard arguments[0].kind() is Call(callee, constructor_arguments) else {
    return
  }
  guard self.expression_callee_is_constructor_call_value(callee) else { return }
  guard wgsl_ir_flatten_expression_arguments(constructor_arguments)
    is [component] else {
    return
  }
  guard wgsl_ir_expr_node_is_function_argument_value(component, scope) else {
    return
  }
  let mut direct_index = -1
  for index in 2..<arguments.length() {
    if direct_index < 0 &&
      wgsl_ir_expr_node_is_function_argument_value(arguments[index], scope) {
      direct_index = index
    }
  }
  guard direct_index >= 0 else { return }
  ignore(self.lower_function_expression_node(component, function, scope))
  self.predeclare_function_argument_value(
    arguments[direct_index],
    function,
    scope,
  )
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
fn wgsl_ir_math_call_has_later_function_argument_values(
  arguments : Array[@ast.WgslExprNode],
  scope : WgslIrFunctionScope,
) -> Bool {
  guard arguments.length() > 1 else { return false }
  for index in 1..<arguments.length() {
    if wgsl_ir_expr_node_contains_function_argument_value(
        arguments[index],
        scope,
      ) {
      return true
    }
  }
  false
}

///|
fn WgslIrLowerer::prelower_math_splat_constructor_argument_from_later_context(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> WgslIrDeferredConstructorArgument? raise WgslIrLowerError {
  guard arguments.length() > 1 else { return None }
  guard arguments[0].kind() is Call(_, constructor_arguments) else {
    return None
  }
  guard wgsl_ir_flatten_expression_arguments(constructor_arguments)
    is [component] else {
    return None
  }
  guard wgsl_ir_expr_node_is_foldable_float_arena_candidate(component) else {
    return None
  }
  guard self.math_call_later_function_argument_context_type(
      arguments, function, scope,
    )
    is Some(expected_ty) else {
    return None
  }
  self.prelower_math_splat_constructor_argument_with_expected_type(
    arguments[0],
    expected_ty,
    function,
    scope,
  )
}

///|
fn WgslIrLowerer::math_call_later_function_argument_context_type(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle? raise WgslIrLowerError {
  for index in 1..<arguments.length() {
    if wgsl_ir_expr_node_contains_function_argument_value(
        arguments[index],
        scope,
      ) {
      return Some(
        self.infer_expression_type_in_function_scope(
          arguments[index],
          "math argument",
          function,
          scope,
        ),
      )
    }
  }
  None
}

///|
fn WgslIrLowerer::prelower_math_splat_constructor_argument_with_expected_type(
  self : WgslIrLowerer,
  argument : @ast.WgslExprNode,
  expected_ty : Handle,
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
  guard self.vector_size_from_type(expected_ty) is Some(expected_size) else {
    return None
  }
  let ty = match self.lower_templated_callee_type(callee) {
    Some(ty) => ty
    None =>
      match callee.kind() {
        Identifier(name) =>
          match wgsl_ir_vector_size_from_constructor_name(name.name()) {
            Some(size) if size == expected_size => expected_ty
            _ => return None
          }
        _ => return None
      }
  }
  guard self.constructor_component_expected_type(ty) is Some(component_ty) else {
    return None
  }
  let expression_mark = function.expressions.items.length()
  let local_constant_snapshot = wgsl_ir_snapshot_local_constant_values(
    scope.local_constants,
  )
  let lowered = self.lower_function_expression_node_with_expected(
    component,
    function,
    scope,
    Some(component_ty),
  )
  match self.fold_function_constant_float_expression(function, lowered) {
    Some(literal) => {
      wgsl_ir_rewind_function_expressions_and_local_constant_values(
        function, expression_mark, scope, local_constant_snapshot,
      )
      let component = function.expressions.append_with_origin(
        Literal(literal),
        FoldedLocalConstant,
      )
      Some({ ty, component })
    }
    None => {
      wgsl_ir_rewind_function_expressions_and_local_constant_values(
        function, expression_mark, scope, local_constant_snapshot,
      )
      None
    }
  }
}

///|
fn WgslIrLowerer::math_call_predeclares_later_function_arguments_after_first_consts(
  self : WgslIrLowerer,
  math_function : MathFunction,
  arguments : Array[@ast.WgslExprNode],
  deferred_constructors : Map[Int, WgslIrDeferredConstructorArgument],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Bool {
  guard wgsl_ir_math_function_has_homogeneous_arguments(math_function) else {
    return false
  }
  guard arguments.length() > 1 else { return false }
  let first_has_const_leaf = deferred_constructors.contains(0) ||
    self.expression_node_contains_inline_constant_reference(arguments[0], scope)
  guard first_has_const_leaf else { return false }
  for index in 1..<arguments.length() {
    if wgsl_ir_expr_node_contains_function_argument_value(
        arguments[index],
        scope,
      ) {
      return true
    }
  }
  ignore(function)
  false
}

///|
fn WgslIrLowerer::math_call_later_argument_lowers_before_deferred_first(
  self : WgslIrLowerer,
  argument : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Bool {
  wgsl_ir_expr_node_is_direct_access_chain(argument) &&
  self.expression_node_contains_writer_reference_value(
    argument, function, scope,
  )
}

///|
fn WgslIrLowerer::math_call_predeclares_later_direct_arguments_before_reference_first(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Bool {
  guard arguments.length() > 1 else { return false }
  guard wgsl_ir_expr_node_is_direct_access_chain(arguments[0]) else {
    return false
  }
  guard self.expression_node_contains_writer_reference_value(
    arguments[0],
    function,
    scope,
  ) else {
    return false
  }
  for index in 1..<arguments.length() {
    if wgsl_ir_expr_node_is_function_argument_value(arguments[index], scope) {
      return true
    }
  }
  false
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
fn WgslIrLowerer::predeclare_inline_constant_references_in_source_order(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Unit raise WgslIrLowerError {
  match node.kind() {
    Identifier(name) =>
      if self.expression_node_is_inline_constant_reference(node, scope) {
        ignore(self.lower_identifier_expression(name.name(), function, scope))
      }
    Group(inner) | Unary(_, inner) | PostfixUpdate(_, inner) =>
      self.predeclare_inline_constant_references_in_source_order(
        inner, function, scope,
      )
    Binary(_, left, right) | Assignment(_, left, right) | Index(left, right) => {
      self.predeclare_inline_constant_references_in_source_order(
        left, function, scope,
      )
      self.predeclare_inline_constant_references_in_source_order(
        right, function, scope,
      )
    }
    Member(base, _) | PathAccess(base, _) | Template(base, _) =>
      self.predeclare_inline_constant_references_in_source_order(
        base, function, scope,
      )
    Call(_, arguments) | Sequence(arguments) =>
      for argument in arguments {
        self.predeclare_inline_constant_references_in_source_order(
          argument, function, scope,
        )
      }
    Literal(_) | ShaderDefTemplate(_) => ()
  }
}

///|
fn WgslIrLowerer::expression_node_contains_inline_constant_reference(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  scope : WgslIrFunctionScope,
) -> Bool {
  match node.kind() {
    Identifier(_) =>
      self.expression_node_is_inline_constant_reference(node, scope)
    Group(inner) | Unary(_, inner) | PostfixUpdate(_, inner) =>
      self.expression_node_contains_inline_constant_reference(inner, scope)
    Binary(_, left, right) | Assignment(_, left, right) | Index(left, right) =>
      self.expression_node_contains_inline_constant_reference(left, scope) ||
      self.expression_node_contains_inline_constant_reference(right, scope)
    Member(base, _) | PathAccess(base, _) | Template(base, _) =>
      self.expression_node_contains_inline_constant_reference(base, scope)
    Call(_, arguments) | Sequence(arguments) =>
      arguments.any(fn(argument) {
        self.expression_node_contains_inline_constant_reference(argument, scope)
      })
    Literal(_) | ShaderDefTemplate(_) => false
  }
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
  let local_constant_snapshot = wgsl_ir_snapshot_local_constant_values(
    scope.local_constants,
  )
  let lowered = self.lower_function_math_argument_at(
    index, arguments, deferred_constructors, function, scope,
  )
  match self.fold_function_constant_literal_expression(function, lowered) {
    Some(literal) => {
      wgsl_ir_rewind_function_expressions_and_local_constant_values(
        function, expression_mark, scope, local_constant_snapshot,
      )
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
    self.expression_node_contains_writer_reference_value(
      arguments[1],
      function,
      scope,
    )
  ) ||
  (
    wgsl_ir_expr_node_is_foldable_float_splat_constructor(arguments[0]) &&
    self.expression_node_contains_writer_reference_value(
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
fn wgsl_ir_expr_node_is_foldable_float_splat_constructor(
  node : @ast.WgslExprNode,
) -> Bool {
  match node.kind() {
    Group(inner) => wgsl_ir_expr_node_is_foldable_float_splat_constructor(inner)
    Call(callee, arguments) =>
      wgsl_ir_callee_is_vector_constructor(callee) &&
      wgsl_ir_flatten_expression_arguments(arguments) is [component] &&
      wgsl_ir_expr_node_is_foldable_float_arena_candidate(component)
    _ => false
  }
}

///|
fn wgsl_ir_callee_is_vector_constructor(callee : @ast.WgslExprNode) -> Bool {
  match callee.kind() {
    Identifier(name) =>
      wgsl_ir_vector_size_from_constructor_name(name.name()) != None
    Template(base, _) => wgsl_ir_callee_is_vector_constructor(base)
    Group(inner) => wgsl_ir_callee_is_vector_constructor(inner)
    _ => false
  }
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
  guard self.expression_node_is_writer_deferred_const_like(component, scope) else {
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
  let local_constant_snapshot = wgsl_ir_snapshot_local_constant_values(
    scope.local_constants,
  )
  let lowered = self.lower_function_expression_node_with_expected(
    component, function, scope, expected_ty,
  )
  match self.fold_function_constant_float_expression(function, lowered) {
    Some(literal) => {
      wgsl_ir_rewind_function_expressions_and_local_constant_values(
        function, expression_mark, scope, local_constant_snapshot,
      )
      let component = function.expressions.append_with_origin(
        Literal(literal),
        FoldedLocalConstant,
      )
      Some({ ty, component })
    }
    None => {
      wgsl_ir_rewind_function_expressions_and_local_constant_values(
        function, expression_mark, scope, local_constant_snapshot,
      )
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
  let local_constant_snapshot = wgsl_ir_snapshot_local_constant_values(
    scope.local_constants,
  )
  let lowered = self.lower_function_expression_node_with_expected(
    component, function, scope, expected_ty,
  )
  match self.fold_function_constant_float_expression(function, lowered) {
    Some(literal) => {
      wgsl_ir_rewind_function_expressions_and_local_constant_values(
        function, expression_mark, scope, local_constant_snapshot,
      )
      let component = function.expressions.append_with_origin(
        Literal(literal),
        FoldedLocalConstant,
      )
      Some({ ty, component })
    }
    None => {
      wgsl_ir_rewind_function_expressions_and_local_constant_values(
        function, expression_mark, scope, local_constant_snapshot,
      )
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
