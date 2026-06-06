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
priv struct ExpressionArenaScheduler {
  lowerer : WgslIrLowerer
  function : Function
  scope : WgslIrFunctionScope
}

///|
fn WgslIrLowerer::expression_arena_scheduler(
  self : WgslIrLowerer,
  function : Function,
  scope : WgslIrFunctionScope,
) -> ExpressionArenaScheduler {
  { lowerer: self, function, scope }
}

///|
fn ExpressionArenaScheduler::binary_predeclares_left_associative_reference_roots(
  self : ExpressionArenaScheduler,
  op : @ast.WgslExprOperator,
  left : @ast.WgslExprNode,
  right : @ast.WgslExprNode,
) -> Bool {
  if wgsl_ir_expr_node_contains_non_math_call(left) ||
    wgsl_ir_expr_node_contains_non_math_call(right) {
    return false
  }
  guard wgsl_ir_expr_node_without_groups(left).kind() is Binary(left_op, _, _) else {
    return false
  }
  guard left_op.binary_precedence() == op.binary_precedence() else {
    return false
  }
  self.lowerer.expression_node_is_mutable_local_value(
    right,
    self.function,
    self.scope,
  ) ||
  (
    !wgsl_ir_expr_node_is_function_argument_value(right, self.scope) &&
    wgsl_ir_direct_access_chain_root_is_function_argument(right, self.scope)
  )
}

///|
fn ExpressionArenaScheduler::binary_predeclares_sibling_member_roots(
  self : ExpressionArenaScheduler,
  left : @ast.WgslExprNode,
  right : @ast.WgslExprNode,
) -> Bool {
  if wgsl_ir_direct_access_chain_root_is_function_argument(left, self.scope) &&
    wgsl_ir_expr_node_contains_call_member_access(right) {
    return false
  }
  if wgsl_ir_direct_access_chain_root_is_function_argument(left, self.scope) &&
    self.lowerer.direct_access_chain_root_is_global_reference(right) {
    return false
  }
  if self.lowerer.direct_access_chain_root_is_global_reference(left) &&
    self.lowerer.direct_access_chain_root_is_global_reference(right) {
    return false
  }
  wgsl_ir_expr_node_is_direct_access_chain(left) &&
  wgsl_ir_binary_right_operand_has_sibling_member_root(right)
}

///|
fn wgsl_ir_binary_right_operand_has_sibling_member_root(
  right : @ast.WgslExprNode,
) -> Bool {
  match wgsl_ir_expr_node_without_groups(right).kind() {
    Binary(_, _, _) => wgsl_ir_expr_node_contains_member_access(right)
    _ => wgsl_ir_expr_node_is_direct_access_chain(right)
  }
}

///|
fn ExpressionArenaScheduler::binary_lowers_right_before_left(
  self : ExpressionArenaScheduler,
  op : @ast.WgslExprOperator,
  left : @ast.WgslExprNode,
  right : @ast.WgslExprNode,
) -> Bool {
  if wgsl_ir_expr_node_is_literal_like(left) {
    return self.lowerer.expression_node_contains_naga_reference_value(
      right,
      self.function,
      self.scope,
    )
  }
  if self.scope.compound_assignment_rhs_depth > 0 &&
    wgsl_ir_ast_binary_operator_is_multiplicative(op) &&
    self.lowerer.expression_node_is_naga_deferred_const_like(left, self.scope) &&
    wgsl_ir_expr_node_contains_non_math_call(right) {
    return false
  }
  if wgsl_ir_ast_binary_operator_is_multiplicative(op) &&
    wgsl_ir_expr_node_without_groups(left).kind() is Binary(_, _, _) &&
    wgsl_ir_expr_node_without_groups(right).kind() is Call(_, _) &&
    wgsl_ir_expr_node_references_local_constant_alias(right, self.scope) {
    return false
  }
  if self.lowerer.expression_node_is_naga_deferred_const_like(left, self.scope) {
    if self.binary_preserves_deferred_const_left_before_local_right_binary(
        op, left, right,
      ) {
      return false
    }
    return wgsl_ir_ast_binary_operator_is_multiplicative(op) &&
      !self.lowerer.expression_node_is_mutable_local_value(
        right,
        self.function,
        self.scope,
      ) &&
      self.lowerer.expression_node_contains_naga_reference_value(
        right,
        self.function,
        self.scope,
      )
  }
  if self.lowerer.expression_node_is_inline_constant_reference(left, self.scope) {
    return !self.lowerer.expression_node_is_mutable_local_value(
        right,
        self.function,
        self.scope,
      ) &&
      self.lowerer.expression_node_contains_naga_reference_value(
        right,
        self.function,
        self.scope,
      )
  }
  self.lowerer.expression_node_is_mutable_local_value(
    left,
    self.function,
    self.scope,
  ) &&
  wgsl_ir_expr_node_is_function_argument_value(right, self.scope)
}

///|
fn wgsl_ir_expr_node_references_local_constant_alias(
  node : @ast.WgslExprNode,
  scope : WgslIrFunctionScope,
) -> Bool {
  match node.kind() {
    Identifier(name) => scope.local_constants.contains(name.name())
    Literal(_) | ShaderDefTemplate(_) => false
    Group(inner) | Unary(_, inner) | PostfixUpdate(_, inner) =>
      wgsl_ir_expr_node_references_local_constant_alias(inner, scope)
    Assignment(_, left, right) | Binary(_, left, right) | Index(left, right) =>
      wgsl_ir_expr_node_references_local_constant_alias(left, scope) ||
      wgsl_ir_expr_node_references_local_constant_alias(right, scope)
    Call(callee, arguments) =>
      wgsl_ir_expr_node_references_local_constant_alias(callee, scope) ||
      wgsl_ir_call_arguments(arguments).any(fn(argument) {
        wgsl_ir_expr_node_references_local_constant_alias(argument, scope)
      })
    Template(callee, arguments) =>
      wgsl_ir_expr_node_references_local_constant_alias(callee, scope) ||
      arguments.any(fn(argument) {
        match argument {
          Expression(expr_ref) =>
            match expr_ref.root() {
              Some(root) =>
                wgsl_ir_expr_node_references_local_constant_alias(root, scope)
              None => false
            }
          Type(_) => false
        }
      })
    Member(base, _) | PathAccess(base, _) =>
      wgsl_ir_expr_node_references_local_constant_alias(base, scope)
    Sequence(items) =>
      items.any(fn(item) {
        wgsl_ir_expr_node_references_local_constant_alias(item, scope)
      })
  }
}

///|
fn ExpressionArenaScheduler::binary_preserves_deferred_const_left_before_local_right_binary(
  self : ExpressionArenaScheduler,
  op : @ast.WgslExprOperator,
  left : @ast.WgslExprNode,
  right : @ast.WgslExprNode,
) -> Bool {
  guard wgsl_ir_ast_binary_operator_is_multiplicative(op) else { return false }
  guard wgsl_ir_expr_node_without_groups(left).kind() is Binary(_, _, _) else {
    return false
  }
  guard wgsl_ir_expr_node_without_groups(right).kind() is Binary(right_op, _, _) else {
    return false
  }
  guard right_op.binary_precedence() == op.binary_precedence() else {
    return false
  }
  !wgsl_ir_expr_node_contains_non_math_call(right) &&
  self.lowerer.expression_node_contains_mutable_local_reference(
    right,
    self.function,
    self.scope,
  )
}

///|
fn ExpressionArenaScheduler::binary_lowers_right_argument_before_left_access(
  self : ExpressionArenaScheduler,
  left : @ast.WgslExprNode,
  right : @ast.WgslExprNode,
) -> Bool {
  wgsl_ir_expr_node_is_direct_access_chain(left) &&
  wgsl_ir_expr_node_is_function_argument_value(right, self.scope)
}

///|
fn ExpressionArenaScheduler::binary_predeclares_right_constructor_argument_member_root(
  self : ExpressionArenaScheduler,
  left : @ast.WgslExprNode,
  right : @ast.WgslExprNode,
) -> Bool {
  wgsl_ir_expr_node_is_direct_access_chain(left) &&
  self.lowerer.direct_access_chain_root_is_global_reference(left) &&
  self.lowerer.expression_node_is_constructor_call_value(right) &&
  wgsl_ir_expr_node_contains_member_access(right) &&
  wgsl_ir_expr_node_contains_function_argument_value(right, self.scope)
}

///|
fn ExpressionArenaScheduler::binary_delays_left_constructor_commit_until_right_argument(
  self : ExpressionArenaScheduler,
  left : @ast.WgslExprNode,
  right : @ast.WgslExprNode,
) -> Bool {
  self.lowerer.expression_node_is_constructor_call_value(left) &&
  wgsl_ir_expr_node_is_function_argument_value(right, self.scope)
}

///|
fn ExpressionArenaScheduler::binary_right_subtree_has_higher_precedence(
  self : ExpressionArenaScheduler,
  op : @ast.WgslExprOperator,
  right : @ast.WgslExprNode,
) -> Bool {
  ignore(self)
  match right.kind() {
    Binary(right_op, _, _) =>
      right_op.binary_precedence() > op.binary_precedence()
    _ => false
  }
}

///|
fn ExpressionArenaScheduler::binary_preserves_left_first_across_higher_precedence_right(
  self : ExpressionArenaScheduler,
  parent_op : @ast.WgslExprOperator,
  left : @ast.WgslExprNode,
  right : @ast.WgslExprNode,
) -> Bool {
  ignore(self)
  match parent_op {
    Add | Subtract => ()
    _ => return false
  }
  if wgsl_ir_expr_node_contains_call(left) ||
    wgsl_ir_expr_node_contains_call(right) {
    return false
  }
  let left = wgsl_ir_expr_node_without_groups(left)
  let right = wgsl_ir_expr_node_without_groups(right)
  guard left.kind() is Binary(left_op, _, _) else { return false }
  guard right.kind() is Binary(right_op, _, _) else { return false }
  if !wgsl_ir_ast_binary_operator_is_multiplicative(right_op) ||
    right_op.binary_precedence() <= parent_op.binary_precedence() {
    return false
  }
  if wgsl_ir_ast_binary_operator_is_multiplicative(left_op) {
    return true
  }
  left_op.binary_precedence() == parent_op.binary_precedence()
}

///|
fn ExpressionArenaScheduler::binary_right_root_is_delayed_after_parent_left(
  self : ExpressionArenaScheduler,
  parent_op : @ast.WgslExprOperator,
  node : @ast.WgslExprNode,
) -> Bool {
  ignore(self)
  match node.kind() {
    Binary(op, left, _) =>
      op.binary_precedence() == parent_op.binary_precedence() ||
      !wgsl_ir_expr_node_is_literal_like(left)
    Group(inner) =>
      self.binary_right_root_is_delayed_after_parent_left(parent_op, inner)
    _ => false
  }
}

///|
fn ExpressionArenaScheduler::constructor_arguments_delay_literals(
  self : ExpressionArenaScheduler,
  arguments : Array[@ast.WgslExprNode],
) -> Bool {
  let mut saw_literal = false
  let mut should_delay = false
  for argument in arguments {
    if self.constructor_argument_has_ordered_effect(argument) {
      return false
    }
    if self.constructor_argument_is_literal_like(argument) {
      saw_literal = true
    } else if saw_literal {
      should_delay = true
    }
  }
  should_delay
}

///|
fn ExpressionArenaScheduler::constructor_argument_is_literal_like(
  self : ExpressionArenaScheduler,
  node : @ast.WgslExprNode,
) -> Bool {
  match node.kind() {
    Group(inner) => self.constructor_argument_is_literal_like(inner)
    Literal(_) => true
    Unary(op, inner) =>
      op == Subtract && self.constructor_argument_is_literal_like(inner)
    Binary(_, left, right) =>
      self.constructor_argument_is_literal_like(left) &&
      self.constructor_argument_is_literal_like(right)
    _ => false
  }
}

///|
fn ExpressionArenaScheduler::constructor_argument_has_ordered_effect(
  self : ExpressionArenaScheduler,
  node : @ast.WgslExprNode,
) -> Bool {
  match node.kind() {
    Group(inner) | Unary(_, inner) | PostfixUpdate(_, inner) =>
      if node.kind() is PostfixUpdate(_, _) {
        true
      } else {
        self.constructor_argument_has_ordered_effect(inner)
      }
    Assignment(_, _, _) => true
    Call(_, _) => true
    Binary(_, left, right) | Index(left, right) =>
      self.constructor_argument_has_ordered_effect(left) ||
      self.constructor_argument_has_ordered_effect(right)
    Member(base, _) | Template(base, _) =>
      self.constructor_argument_has_ordered_effect(base)
    Sequence(items) =>
      items.any(fn(item) { self.constructor_argument_has_ordered_effect(item) })
    Identifier(_) | Literal(_) | ShaderDefTemplate(_) | PathAccess(_, _) =>
      false
  }
}
