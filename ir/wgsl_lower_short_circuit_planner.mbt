// Copyright 2026 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
priv struct ShortCircuitPlanner {
  lowerer : WgslIrLowerer
  function : Function
  scope : WgslIrFunctionScope
  block : Block
}

///|
fn WgslIrLowerer::short_circuit_planner(
  self : WgslIrLowerer,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
) -> ShortCircuitPlanner {
  { lowerer: self, function, scope, block }
}

///|
fn WgslIrLowerer::lower_expression_ref_with_materialized_short_circuit_inputs(
  self : WgslIrLowerer,
  expr_ref : @ast.WgslExprRef,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
  expected_ty : Handle?,
) -> Handle raise WgslIrLowerError {
  guard expr_ref.root() is Some(root) else {
    raise UnsupportedExpression("empty function expression")
  }
  if wgsl_ir_expr_node_is_short_circuit_binary(root) {
    self
    .short_circuit_planner(function, scope, block)
    .materialize_value_node(root)
  } else if wgsl_ir_expr_node_contains_short_circuit_binary(root) {
    self
    .short_circuit_planner(function, scope, block)
    .lower_expression_with_materialized_inputs(root, expected_ty)
  } else {
    self.lower_function_expression_ref_with_expected(
      expr_ref, function, scope, expected_ty,
    )
  }
}

///|
fn ShortCircuitPlanner::with_block(
  self : ShortCircuitPlanner,
  block : Block,
) -> ShortCircuitPlanner {
  { lowerer: self.lowerer, function: self.function, scope: self.scope, block }
}

///|
fn ShortCircuitPlanner::materialize_value_handle(
  self : ShortCircuitPlanner,
  value : Handle,
) -> Handle raise WgslIrLowerError {
  guard self.function.expressions.items.get(value.index())
    is Some(Binary(op, left, right)) else {
    return value
  }
  guard wgsl_ir_binary_operator_is_short_circuit(op) else { return value }
  let ty = match self.lowerer.function_expression_type(self.function, value) {
    Some(ty) => ty
    None =>
      raise MissingType(
        "materialized short-circuit expression \{value.index()}: boolean expression",
      )
  }
  match op {
    LogicalAnd => self.materialize_binary_handle(left, right, ty, false)
    LogicalOr => self.materialize_binary_handle(left, right, ty, true)
    _ => raise UnsupportedExpression("expected short-circuit operator")
  }
}

///|
fn ShortCircuitPlanner::materialize_value_node(
  self : ShortCircuitPlanner,
  node : @ast.WgslExprNode,
) -> Handle raise WgslIrLowerError {
  match node.kind() {
    Group(inner) | Template(inner, _) =>
      return self.materialize_value_node(inner)
    _ => ()
  }
  guard node.kind() is Binary(ast_op, left, right) else {
    let value = self.lowerer.lower_function_expression_node(
      node,
      self.function,
      self.scope,
    )
    return self.lowerer.materialize_return_expression_if_needed(
      self.function,
      self.scope,
      self.block,
      value,
    )
  }
  let op = wgsl_ir_binary_operator(ast_op)
  guard wgsl_ir_binary_operator_is_short_circuit(op) else {
    let value = self.lowerer.lower_function_expression_node(
      node,
      self.function,
      self.scope,
    )
    return self.lowerer.materialize_return_expression_if_needed(
      self.function,
      self.scope,
      self.block,
      value,
    )
  }
  let ty = self.lowerer.scalar_type_handle(Scalar(Bool, 1))
  match op {
    LogicalAnd =>
      self.materialize_binary_node(left, right, ty, false, true, false)
    LogicalOr =>
      self.materialize_binary_node(left, right, ty, true, true, false)
    _ => raise UnsupportedExpression("expected short-circuit operator")
  }
}

///|
fn ShortCircuitPlanner::materialize_return_value_node(
  self : ShortCircuitPlanner,
  node : @ast.WgslExprNode,
) -> Handle raise WgslIrLowerError {
  match node.kind() {
    Group(inner) | Template(inner, _) =>
      return self.materialize_return_value_node(inner)
    _ => ()
  }
  guard node.kind() is Binary(ast_op, left, right) else {
    let value = self.lowerer.lower_function_expression_node(
      node,
      self.function,
      self.scope,
    )
    return self.lowerer.materialize_return_expression_if_needed(
      self.function,
      self.scope,
      self.block,
      value,
    )
  }
  let op = wgsl_ir_binary_operator(ast_op)
  guard wgsl_ir_binary_operator_is_short_circuit(op) else {
    let value = self.lowerer.lower_function_expression_node(
      node,
      self.function,
      self.scope,
    )
    return self.lowerer.materialize_return_expression_if_needed(
      self.function,
      self.scope,
      self.block,
      value,
    )
  }
  let ty = self.lowerer.scalar_type_handle(Scalar(Bool, 1))
  match op {
    LogicalAnd =>
      self.materialize_binary_node(left, right, ty, false, false, false)
    LogicalOr =>
      self.materialize_binary_node(left, right, ty, true, false, false)
    _ => raise UnsupportedExpression("expected short-circuit operator")
  }
}

///|
fn ShortCircuitPlanner::materialize_value_node_as_expression_input(
  self : ShortCircuitPlanner,
  node : @ast.WgslExprNode,
) -> Handle raise WgslIrLowerError {
  match node.kind() {
    Group(inner) | Template(inner, _) =>
      return self.materialize_value_node_as_expression_input(inner)
    _ => ()
  }
  guard node.kind() is Binary(ast_op, left, right) else {
    return self.lowerer.lower_function_expression_node(
      node,
      self.function,
      self.scope,
    )
  }
  let op = wgsl_ir_binary_operator(ast_op)
  let ty = self.lowerer.scalar_type_handle(Scalar(Bool, 1))
  match op {
    LogicalAnd =>
      self.materialize_binary_node(left, right, ty, false, false, true)
    LogicalOr =>
      self.materialize_binary_node(left, right, ty, true, false, true)
    _ => raise UnsupportedExpression("expected short-circuit operator")
  }
}

///|
fn ShortCircuitPlanner::materialize_binary_handle(
  self : ShortCircuitPlanner,
  left : Handle,
  right : Handle,
  ty : Handle,
  true_when_left : Bool,
) -> Handle raise WgslIrLowerError {
  let condition = self.materialize_condition_handle(left)
  let guard_condition = if true_when_left {
    self.function.expressions.append(Unary(LogicalNot, condition))
  } else {
    condition
  }
  let local_ptr = self.append_result_local(ty)
  let accept = Block::Block()
  let reject = Block::Block()
  let right_value = self.with_block(accept).materialize_branch_handle(right)
  accept.push(Store(local_ptr, right_value))
  reject.push(
    Store(
      local_ptr,
      self.function.expressions.append(Literal(Bool(true_when_left))),
    ),
  )
  self.block.push(If(guard_condition, accept, reject))
  self.function.expressions.append(Load(local_ptr))
}

///|
fn ShortCircuitPlanner::materialize_binary_node(
  self : ShortCircuitPlanner,
  left : @ast.WgslExprNode,
  right : @ast.WgslExprNode,
  ty : Handle,
  true_when_left : Bool,
  emit_result_load : Bool,
  local_pointer_before_branch : Bool,
) -> Handle raise WgslIrLowerError {
  let left_is_short_circuit = wgsl_ir_expr_node_is_short_circuit_binary(left)
  let condition_mark = self.function.expressions.items.length()
  let condition = self.materialize_condition_node(left)
  let guard_condition = if true_when_left {
    self.function.expressions.append(Unary(LogicalNot, condition))
  } else {
    condition
  }
  self.emit_condition_range(
    left_is_short_circuit, condition_mark, guard_condition,
  )
  let local_handle = self.allocate_result_local(ty)
  let accept = Block::Block()
  let reject = Block::Block()
  let mut local_ptr : Handle? = None
  if local_pointer_before_branch {
    local_ptr = Some(self.append_result_local_pointer(local_handle))
  }
  let right_value = self.with_block(accept).materialize_branch_node(right)
  let local_ptr = match local_ptr {
    Some(handle) => handle
    None => self.append_result_local_pointer(local_handle)
  }
  accept.push(Store(local_ptr, right_value))
  reject.push(
    Store(
      local_ptr,
      self.function.expressions.append(Literal(Bool(true_when_left))),
    ),
  )
  self.block.push(If(guard_condition, accept, reject))
  let result = self.append_result_load(local_ptr)
  if emit_result_load {
    self.lowerer.materialize_function_expression(
      self.function,
      self.scope,
      self.block,
      result,
    )
  } else {
    result
  }
}

///|
fn ShortCircuitPlanner::emit_condition_range(
  self : ShortCircuitPlanner,
  left_is_short_circuit : Bool,
  condition_mark : Int,
  guard_condition : Handle,
) -> Unit {
  if left_is_short_circuit {
    if self.function.expressions.items.get(guard_condition.index())
      is Some(Unary(LogicalNot, _)) {
      self.block.push(Emit(HandleRange(guard_condition, guard_condition)))
    }
  } else {
    BodyEmissionPlanner::push_statement_emit_ranges(
      self.block,
      self.function,
      condition_mark,
      guard_condition,
    )
  }
}

///|
fn ShortCircuitPlanner::materialize_condition_node(
  self : ShortCircuitPlanner,
  node : @ast.WgslExprNode,
) -> Handle raise WgslIrLowerError {
  match node.kind() {
    Group(inner) | Template(inner, _) =>
      return self.materialize_condition_node(inner)
    _ => ()
  }
  if wgsl_ir_expr_node_is_short_circuit_binary(node) {
    let lowered = self.materialize_value_node(node)
    if self.lowerer.function_expression_should_materialize_as_nested_value(
        self.function,
        lowered,
      ) {
      self.lowerer.materialize_function_expression(
        self.function,
        self.scope,
        self.block,
        lowered,
      )
    } else {
      lowered
    }
  } else {
    let value = self.lowerer.lower_function_expression_node(
      node,
      self.function,
      self.scope,
    )
    self.materialize_condition_handle(value)
  }
}

///|
fn ShortCircuitPlanner::materialize_branch_node(
  self : ShortCircuitPlanner,
  node : @ast.WgslExprNode,
) -> Handle raise WgslIrLowerError {
  match node.kind() {
    Group(inner) | Template(inner, _) =>
      return self.materialize_branch_node(inner)
    _ => ()
  }
  if wgsl_ir_expr_node_is_short_circuit_binary(node) {
    let lowered = self.materialize_value_node(node)
    if self.lowerer.function_expression_should_materialize_as_nested_value(
        self.function,
        lowered,
      ) {
      self.lowerer.materialize_function_expression(
        self.function,
        self.scope,
        self.block,
        lowered,
      )
    } else {
      lowered
    }
  } else {
    let value = self.lowerer.lower_function_expression_node(
      node,
      self.function,
      self.scope,
    )
    self.materialize_branch_handle(value)
  }
}

///|
fn ShortCircuitPlanner::materialize_condition_handle(
  self : ShortCircuitPlanner,
  value : Handle,
) -> Handle raise WgslIrLowerError {
  match self.function.expressions.items.get(value.index()) {
    Some(Binary(op, _, _)) if wgsl_ir_binary_operator_is_short_circuit(op) => {
      let lowered = self.materialize_value_handle(value)
      if self.lowerer.function_expression_should_materialize_as_nested_value(
          self.function,
          lowered,
        ) {
        self.lowerer.materialize_function_expression(
          self.function,
          self.scope,
          self.block,
          lowered,
        )
      } else {
        lowered
      }
    }
    _ => {
      let normalized = self.lowerer.materialize_return_subexpressions(
        self.function,
        self.scope,
        self.block,
        value,
      )
      if self.lowerer.function_expression_should_materialize_as_nested_value(
          self.function,
          normalized,
        ) {
        self.lowerer.materialize_function_expression(
          self.function,
          self.scope,
          self.block,
          normalized,
        )
      } else {
        normalized
      }
    }
  }
}

///|
fn ShortCircuitPlanner::materialize_branch_handle(
  self : ShortCircuitPlanner,
  value : Handle,
) -> Handle raise WgslIrLowerError {
  match self.function.expressions.items.get(value.index()) {
    Some(Binary(op, _, _)) if wgsl_ir_binary_operator_is_short_circuit(op) => {
      let lowered = self.materialize_value_handle(value)
      if self.lowerer.function_expression_should_materialize_as_nested_value(
          self.function,
          lowered,
        ) {
        self.lowerer.materialize_function_expression(
          self.function,
          self.scope,
          self.block,
          lowered,
        )
      } else {
        lowered
      }
    }
    _ =>
      self.lowerer.materialize_store_value_if_needed(
        self.function,
        self.scope,
        self.block,
        value,
      )
  }
}

///|
fn ShortCircuitPlanner::append_result_load(
  self : ShortCircuitPlanner,
  local_ptr : Handle,
) -> Handle raise WgslIrLowerError {
  match self.function.expressions.items.get(local_ptr.index()) {
    Some(LocalVariable(local_handle)) => {
      let load_ptr = self.function.expressions.append(
        LocalVariable(local_handle),
      )
      self.function.expressions.append(Load(load_ptr))
    }
    _ =>
      raise UnsupportedExpression(
        "short-circuit result pointer is not a local variable",
      )
  }
}

///|
fn ShortCircuitPlanner::allocate_result_local(
  self : ShortCircuitPlanner,
  ty : Handle,
) -> Handle {
  self.function.local_variables.append({
    name: Some("local"),
    kind: Var,
    generated_temporary: false,
    generated_temporary_store_value_reference: false,
    short_circuit_result: true,
    ty,
    init: None,
  })
}

///|
fn ShortCircuitPlanner::append_result_local_pointer(
  self : ShortCircuitPlanner,
  local_handle : Handle,
) -> Handle {
  self.block.push(Declare(local_handle))
  self.function.expressions.append(LocalVariable(local_handle))
}

///|
fn ShortCircuitPlanner::append_result_local(
  self : ShortCircuitPlanner,
  ty : Handle,
) -> Handle {
  let local_handle = self.allocate_result_local(ty)
  self.append_result_local_pointer(local_handle)
}

///|
fn ShortCircuitPlanner::lower_expression_with_materialized_inputs(
  self : ShortCircuitPlanner,
  node : @ast.WgslExprNode,
  expected_ty : Handle?,
) -> Handle raise WgslIrLowerError {
  match node.kind() {
    Group(inner) | Template(inner, _) =>
      return self.lower_expression_with_materialized_inputs(inner, expected_ty)
    _ => ()
  }
  guard wgsl_ir_expr_node_contains_short_circuit_binary(node) else {
    return self.lowerer.lower_function_expression_node_with_expected(
      node,
      self.function,
      self.scope,
      expected_ty,
    )
  }
  match node.kind() {
    Unary(op, expr) => {
      let inner = self.lower_expression_with_materialized_inputs(expr, None)
      self.function.expressions.append(Unary(wgsl_ir_unary_operator(op), inner))
    }
    Binary(op, left, right) => {
      if wgsl_ir_binary_operator_is_short_circuit(wgsl_ir_binary_operator(op)) {
        return self.materialize_value_node_as_expression_input(node)
      }
      let left = self.lower_expression_with_materialized_inputs(left, None)
      let right = self.lower_expression_with_materialized_inputs(right, None)
      let binary_op = wgsl_ir_binary_operator(op)
      let (left, right) = self.lowerer.normalize_function_binary_operands(
        self.function,
        binary_op,
        left,
        right,
      )
      self.function.expressions.append(Binary(binary_op, left, right))
    }
    Call(callee, arguments) =>
      self.lower_call_with_materialized_inputs(
        callee,
        wgsl_ir_call_arguments(arguments),
        expected_ty,
      )
    _ =>
      self.lowerer.lower_function_expression_node_with_expected(
        node,
        self.function,
        self.scope,
        expected_ty,
      )
  }
}

///|
fn ShortCircuitPlanner::lower_call_with_materialized_inputs(
  self : ShortCircuitPlanner,
  callee : @ast.WgslExprNode,
  arguments : Array[@ast.WgslExprNode],
  expected_ty : Handle?,
) -> Handle raise WgslIrLowerError {
  match callee.kind() {
    Identifier(name) =>
      self.lower_named_call_with_materialized_inputs(
        name.name(),
        arguments,
        expected_ty,
      )
    _ =>
      self.lowerer.lower_function_call_expression(
        callee,
        arguments,
        self.function,
        self.scope,
        expected_ty,
      )
  }
}

///|
fn ShortCircuitPlanner::lower_named_call_with_materialized_inputs(
  self : ShortCircuitPlanner,
  name : String,
  arguments : Array[@ast.WgslExprNode],
  expected_ty : Handle?,
) -> Handle raise WgslIrLowerError {
  if self.lowerer.function_names.get(name) is Some(_) ||
    wgsl_ir_math_function_from_name(name) is Some(_) ||
    wgsl_ir_derivative_function_from_name(name) is Some(_) ||
    wgsl_ir_relational_function_from_name(name) is Some(_) ||
    name == "select" ||
    wgsl_ir_barrier_builtin_from_name(name) is Some(_) ||
    wgsl_ir_atomic_function_from_name(name) is Some(_) ||
    wgsl_ir_subgroup_function_from_name(name) is Some(_) ||
    name == "arrayLength" ||
    name == "coopMultiplyAdd" ||
    name == "workgroupUniformLoad" ||
    name == "array" {
    return self.lowerer.lower_named_function_call_expression(
      name,
      arguments,
      self.function,
      self.scope,
      expected_ty,
    )
  }
  let expression_mark = self.function.expressions.items.length()
  let flattened = wgsl_ir_flatten_expression_arguments(arguments)
  let lowered_arguments : Array[Handle] = []
  for argument in flattened {
    let lowered = self.lower_expression_with_materialized_inputs(argument, None)
    lowered_arguments.push(
      self.lowerer.apply_function_load_rule(self.function, lowered),
    )
  }
  self.lowerer.finish_function_constructor_call(
    name,
    flattened,
    lowered_arguments,
    self.function,
    expected_ty,
    expression_mark,
  )
}

///|
fn wgsl_ir_expr_node_contains_short_circuit_binary(
  node : @ast.WgslExprNode,
) -> Bool {
  match node.kind() {
    Binary(op, left, right) =>
      op == LogicalAnd ||
      op == LogicalOr ||
      wgsl_ir_expr_node_contains_short_circuit_binary(left) ||
      wgsl_ir_expr_node_contains_short_circuit_binary(right)
    Unary(_, expr) | Group(expr) | Template(expr, _) =>
      wgsl_ir_expr_node_contains_short_circuit_binary(expr)
    Call(callee, arguments) => {
      if wgsl_ir_expr_node_contains_short_circuit_binary(callee) {
        return true
      }
      for argument in wgsl_ir_call_arguments(arguments) {
        if wgsl_ir_expr_node_contains_short_circuit_binary(argument) {
          return true
        }
      }
      false
    }
    Member(base, _) => wgsl_ir_expr_node_contains_short_circuit_binary(base)
    Index(base, index) | Assignment(_, base, index) =>
      wgsl_ir_expr_node_contains_short_circuit_binary(base) ||
      wgsl_ir_expr_node_contains_short_circuit_binary(index)
    Sequence(items) => {
      for item in items {
        if wgsl_ir_expr_node_contains_short_circuit_binary(item) {
          return true
        }
      }
      false
    }
    _ => false
  }
}
