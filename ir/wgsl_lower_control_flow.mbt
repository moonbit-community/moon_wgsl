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
fn wgsl_ir_statement_condition_refs(
  expressions : Array[@ast.WgslStatementExpression],
) -> Array[@ast.WgslExprRef] {
  let refs : Array[@ast.WgslExprRef] = []
  for expression in expressions {
    if expression.role() == Condition {
      refs.push(expression.expression())
    }
  }
  refs
}

///|
fn WgslIrLowerer::lower_if_reject_chain(
  self : WgslIrLowerer,
  blocks : Array[@ast.WgslBlock],
  conditions : Array[@ast.WgslExprRef],
  condition_index : Int,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Block raise WgslIrLowerError {
  if condition_index >= conditions.length() {
    if condition_index < blocks.length() {
      return self.lower_child_block(blocks[condition_index], function, scope)
    }
    return Block()
  }
  if condition_index >= blocks.length() {
    raise UnsupportedStatement("else-if condition without block")
  }
  let block = Block::Block()
  let condition_handle = self.lower_control_flow_condition_ref(
    conditions[condition_index],
    function,
    scope,
    block,
  )
  let accept = self.lower_child_block(blocks[condition_index], function, scope)
  let reject = self.lower_if_reject_chain(
    blocks,
    conditions,
    condition_index + 1,
    function,
    scope,
  )
  block.push(If(condition_handle, accept, reject))
  block
}

///|
fn WgslIrLowerer::lower_control_flow_condition_ref(
  self : WgslIrLowerer,
  expr_ref : @ast.WgslExprRef,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
) -> Handle raise WgslIrLowerError {
  match expr_ref.root() {
    Some(root) if wgsl_ir_expr_node_is_short_circuit_binary(root) =>
      self
      .short_circuit_planner(function, scope, block)
      .materialize_value_node(root)
    _ => {
      let handle = self.lower_function_expression_ref(expr_ref, function, scope)
      self.materialize_control_flow_condition_if_needed(
        function, scope, block, handle,
      )
    }
  }
}

///|
fn WgslIrLowerer::materialize_control_flow_condition_if_needed(
  self : WgslIrLowerer,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
  value : Handle,
) -> Handle raise WgslIrLowerError {
  match function.expressions.items.get(value.index()) {
    Some(Binary(op, _, _)) if wgsl_ir_binary_operator_is_short_circuit(op) =>
      return self
        .short_circuit_planner(function, scope, block)
        .materialize_condition_handle(value)
    _ => ()
  }
  let normalized = self.materialize_control_flow_condition_subexpressions(
    function, scope, block, value,
  )
  if self.function_expression_should_materialize_as_control_flow_condition(
      function, normalized,
    ) {
    self.materialize_function_expression(function, scope, block, normalized)
  } else {
    normalized
  }
}

///|
fn WgslIrLowerer::materialize_for_loop_condition_if_needed(
  self : WgslIrLowerer,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
  value : Handle,
) -> Handle raise WgslIrLowerError {
  match function.expressions.items.get(value.index()) {
    Some(Binary(op, _, _)) if wgsl_ir_binary_operator_is_short_circuit(op) =>
      return self
        .short_circuit_planner(function, scope, block)
        .materialize_condition_handle(value)
    _ => ()
  }
  let normalized = self.materialize_return_subexpressions(
    function, scope, block, value,
  )
  if self.function_expression_should_materialize_as_control_flow_condition(
      function, normalized,
    ) ||
    self.function_expression_should_materialize_as_call_argument(
      function, normalized,
    ) {
    self.materialize_function_expression(function, scope, block, normalized)
  } else {
    normalized
  }
}

///|
fn WgslIrLowerer::lower_for_loop_condition_ref(
  self : WgslIrLowerer,
  expr_ref : @ast.WgslExprRef,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
) -> Handle raise WgslIrLowerError {
  match expr_ref.root() {
    Some(root) if wgsl_ir_expr_node_is_short_circuit_binary(root) =>
      self
      .short_circuit_planner(function, scope, block)
      .materialize_value_node(root)
    _ => {
      let handle = self.lower_function_expression_ref(expr_ref, function, scope)
      self.materialize_for_loop_condition_if_needed(
        function, scope, block, handle,
      )
    }
  }
}

///|
fn WgslIrLowerer::materialize_control_flow_condition_subexpressions(
  self : WgslIrLowerer,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
  value : Handle,
) -> Handle raise WgslIrLowerError {
  if wgsl_ir_function_expression_has_arena_name(function, value) {
    return value
  }
  match function.expressions.items.get(value.index()) {
    Some(Binary(op, left, right)) => {
      let lowered_left = self.materialize_nested_control_flow_condition_argument(
        function, scope, block, left,
      )
      let lowered_right = self.materialize_nested_control_flow_condition_argument(
        function, scope, block, right,
      )
      let parent_left = wgsl_ir_parent_expression_operand(
        function, left, lowered_left,
      )
      let parent_right = wgsl_ir_parent_expression_operand(
        function, right, lowered_right,
      )
      if parent_left != left || parent_right != right {
        function.expressions.append(Binary(op, parent_left, parent_right))
      } else {
        value
      }
    }
    Some(Unary(op, inner)) => {
      let lowered_inner = self.materialize_nested_control_flow_condition_argument(
        function, scope, block, inner,
      )
      let parent_inner = wgsl_ir_parent_expression_operand(
        function, inner, lowered_inner,
      )
      if parent_inner != inner {
        function.expressions.append(Unary(op, parent_inner))
      } else {
        value
      }
    }
    Some(Access(base, index)) => {
      let lowered_base = self.materialize_nested_access_base(
        function, scope, block, base,
      )
      let lowered_index = self.materialize_nested_access_index(
        function, scope, block, index,
      )
      let parent_base = wgsl_ir_parent_expression_operand(
        function, base, lowered_base,
      )
      let parent_index = wgsl_ir_parent_expression_operand(
        function, index, lowered_index,
      )
      if parent_base != base || parent_index != index {
        function.expressions.append(Access(parent_base, parent_index))
      } else {
        value
      }
    }
    Some(AccessIndex(base, index)) => {
      let lowered_base = self.materialize_nested_access_base(
        function, scope, block, base,
      )
      let parent_base = wgsl_ir_parent_expression_operand(
        function, base, lowered_base,
      )
      if parent_base != base {
        function.expressions.append(AccessIndex(parent_base, index))
      } else {
        value
      }
    }
    Some(Load(pointer)) => {
      let lowered_pointer = self.materialize_pointer_subexpressions(
        function, scope, block, pointer,
      )
      let parent_pointer = wgsl_ir_parent_expression_operand(
        function, pointer, lowered_pointer,
      )
      if parent_pointer != pointer {
        function.expressions.append(Load(parent_pointer))
      } else {
        value
      }
    }
    Some(Component(base, component)) => {
      let lowered_base = self.materialize_nested_access_base(
        function, scope, block, base,
      )
      let parent_base = wgsl_ir_parent_expression_operand(
        function, base, lowered_base,
      )
      if parent_base != base {
        function.expressions.append(Component(parent_base, component))
      } else {
        value
      }
    }
    Some(Swizzle(size, base, pattern)) => {
      let lowered_base = self.materialize_nested_access_base(
        function, scope, block, base,
      )
      let parent_base = wgsl_ir_parent_expression_operand(
        function, base, lowered_base,
      )
      if parent_base != base {
        function.expressions.append(Swizzle(size, parent_base, pattern))
      } else {
        value
      }
    }
    Some(Select(condition, accept, reject)) => {
      let lowered_reject = self.materialize_nested_control_flow_condition_argument(
        function, scope, block, reject,
      )
      let lowered_accept = self.materialize_nested_control_flow_condition_argument(
        function, scope, block, accept,
      )
      let lowered_condition = self.materialize_nested_control_flow_condition_argument(
        function, scope, block, condition,
      )
      let parent_condition = wgsl_ir_parent_expression_operand(
        function, condition, lowered_condition,
      )
      let parent_accept = wgsl_ir_parent_expression_operand(
        function, accept, lowered_accept,
      )
      let parent_reject = wgsl_ir_parent_expression_operand(
        function, reject, lowered_reject,
      )
      if parent_condition != condition ||
        parent_accept != accept ||
        parent_reject != reject {
        function.expressions.append(
          Select(parent_condition, parent_accept, parent_reject),
        )
      } else {
        value
      }
    }
    Some(Bitcast(ty, inner)) => {
      let lowered_inner = self.materialize_nested_control_flow_condition_argument(
        function, scope, block, inner,
      )
      let parent_inner = wgsl_ir_parent_expression_operand(
        function, inner, lowered_inner,
      )
      if parent_inner != inner {
        function.expressions.append(Bitcast(ty, parent_inner))
      } else {
        value
      }
    }
    Some(Relational(relational_function, argument)) => {
      let lowered_argument = self.materialize_nested_control_flow_condition_argument(
        function, scope, block, argument,
      )
      let parent_argument = wgsl_ir_parent_expression_operand(
        function, argument, lowered_argument,
      )
      if parent_argument != argument {
        function.expressions.append(
          Relational(relational_function, parent_argument),
        )
      } else {
        value
      }
    }
    Some(Math(math_function, a, b, c, d)) => {
      let lowered_a = self.materialize_nested_control_flow_condition_argument(
        function, scope, block, a,
      )
      let lowered_b = self.materialize_optional_nested_control_flow_condition_argument(
        function, scope, block, b,
      )
      let lowered_c = self.materialize_optional_nested_control_flow_condition_argument(
        function, scope, block, c,
      )
      let lowered_d = self.materialize_optional_nested_control_flow_condition_argument(
        function, scope, block, d,
      )
      let parent_a = wgsl_ir_parent_expression_operand(function, a, lowered_a)
      let parent_b = wgsl_ir_parent_optional_expression_operand(
        function, b, lowered_b,
      )
      let parent_c = wgsl_ir_parent_optional_expression_operand(
        function, c, lowered_c,
      )
      let parent_d = wgsl_ir_parent_optional_expression_operand(
        function, d, lowered_d,
      )
      if parent_a != a || parent_b != b || parent_c != c || parent_d != d {
        function.expressions.append(
          Math(math_function, parent_a, parent_b, parent_c, parent_d),
        )
      } else {
        value
      }
    }
    Some(As(inner, kind, width)) => {
      let lowered_inner = self.materialize_nested_control_flow_condition_argument(
        function, scope, block, inner,
      )
      let parent_inner = wgsl_ir_parent_expression_operand(
        function, inner, lowered_inner,
      )
      if parent_inner != inner {
        function.expressions.append(As(parent_inner, kind, width))
      } else {
        value
      }
    }
    Some(FunctionCall(handle, args)) => {
      let lowered : Array[Handle] = []
      let mut changed = false
      for arg in args {
        let lowered_arg = self.materialize_nested_call_argument(
          function, scope, block, arg,
        )
        let parent_arg = wgsl_ir_parent_expression_operand(
          function, arg, lowered_arg,
        )
        if parent_arg != arg {
          changed = true
        }
        lowered.push(parent_arg)
      }
      if changed {
        function.expressions.append(FunctionCall(handle, lowered))
      } else {
        value
      }
    }
    _ => value
  }
}

///|
fn WgslIrLowerer::materialize_nested_control_flow_condition_argument(
  self : WgslIrLowerer,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
  value : Handle,
) -> Handle raise WgslIrLowerError {
  let normalized = self.materialize_control_flow_condition_subexpressions(
    function, scope, block, value,
  )
  if self.function_expression_should_materialize_as_control_flow_condition(
      function, normalized,
    ) {
    self.materialize_function_expression(function, scope, block, normalized)
  } else {
    normalized
  }
}

///|
fn WgslIrLowerer::materialize_optional_nested_control_flow_condition_argument(
  self : WgslIrLowerer,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
  value : Handle?,
) -> Handle? raise WgslIrLowerError {
  match value {
    Some(handle) =>
      Some(
        self.materialize_nested_control_flow_condition_argument(
          function, scope, block, handle,
        ),
      )
    None => None
  }
}

///|
fn WgslIrLowerer::function_expression_should_materialize_as_control_flow_condition(
  self : WgslIrLowerer,
  function : Function,
  value : Handle,
) -> Bool {
  let should_materialize = match function.expressions.items.get(value.index()) {
    Some(FunctionCall(_, _))
    | Some(AtomicCall(_, _))
    | Some(WorkGroupUniformLoad(_)) => true
    Some(Load(_))
    | Some(Access(_, _))
    | Some(AccessIndex(_, _))
    | Some(Component(_, _))
    | Some(Swizzle(_, _, _)) =>
      self.function_expression_reads_global_binding(function, value) ||
      self.function_expression_reads_var_pointer_load(function, value)
    _ => false
  }
  should_materialize &&
  self.function_expression_can_materialize_to_let(function, value)
}
