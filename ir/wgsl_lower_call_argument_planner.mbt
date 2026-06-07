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
priv struct CallArgumentPlanner {
  lowerer : WgslIrLowerer
  callee_function : Function
  function : Function
  scope : WgslIrFunctionScope
  arguments : Array[@ast.WgslExprNode]
  prelowered : Array[Handle?]
}

///|
fn WgslIrLowerer::call_argument_planner(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  callee_function : Function,
  function : Function,
  scope : WgslIrFunctionScope,
) -> CallArgumentPlanner {
  let prelowered : Array[Handle?] = []
  for _ in 0..<arguments.length() {
    prelowered.push(None)
  }
  { lowerer: self, callee_function, function, scope, arguments, prelowered }
}

///|
fn CallArgumentPlanner::lower_arguments(
  self : CallArgumentPlanner,
) -> Array[Handle] raise WgslIrLowerError {
  self.prelower_dependencies()
  let handles : Array[Handle] = []
  let mut index = 0
  while index < self.arguments.length() {
    if self.prelowered[index] == None &&
      self.argument_is_deferred_const_like(self.arguments[index]) {
      self.lower_later_source_let_arithmetic_before_direct(index)
      ignore(self.lower_next_reference_run(index + 1))
    } else if self.prelowered[index] == None &&
      self.argument_uses_reference_predeclare(index) {
      ignore(self.lower_reference_run(index))
    }
    if self.prelowered[index] == None &&
      wgsl_ir_expr_node_is_function_argument_value(
        self.arguments[index],
        self.scope,
      ) {
      self.lower_later_reference_before_direct(index)
    }
    let argument = match self.prelowered[index] {
      Some(handle) => handle
      None => self.lower_argument_at(index)
    }
    handles.push(argument)
    index += 1
  }
  handles
}

///|
fn CallArgumentPlanner::prelower_dependencies(
  self : CallArgumentPlanner,
) -> Unit raise WgslIrLowerError {
  for index in 0..<self.arguments.length() {
    if self.lowerer.expression_node_contains_user_function_call(
        self.arguments[index],
      ) {
      self.prelowered[index] = Some(self.lower_argument_at(index))
    }
  }
  for index in 1..<self.arguments.length() {
    if self.prelowered[index] == None &&
      self.value_argument_lowers_before_prior_direct(index) {
      self.prelowered[index] = Some(self.lower_argument_at(index))
    }
  }
}

///|
fn CallArgumentPlanner::lower_later_source_let_arithmetic_before_direct(
  self : CallArgumentPlanner,
  direct_index : Int,
) -> Unit raise WgslIrLowerError {
  guard self.has_later_pointer_argument(direct_index) else { return }
  let mut lookahead = direct_index + 1
  while lookahead < self.arguments.length() {
    if self.prelowered[lookahead] != None {
      lookahead += 1
      continue
    }
    if self.lowerer.callee_parameter_is_pointer(self.callee_function, lookahead) {
      return
    }
    if wgsl_ir_expr_node_is_call_value(self.arguments[lookahead]) ||
      self.lowerer.expression_node_contains_user_function_call(
        self.arguments[lookahead],
      ) {
      return
    }
    if self.argument_is_pure_binary_value_expression(lookahead) {
      self.prelowered[lookahead] = Some(self.lower_argument_at(lookahead))
      return
    }
    if self.argument_is_existing_alias_reference(self.arguments[lookahead]) ||
      self.lowerer.expression_node_is_inline_constant_reference(
        self.arguments[lookahead],
        self.scope,
      ) ||
      wgsl_ir_expr_node_is_function_argument_value(
        self.arguments[lookahead],
        self.scope,
      ) {
      lookahead += 1
      continue
    }
    return
  }
}

///|
fn CallArgumentPlanner::has_later_pointer_argument(
  self : CallArgumentPlanner,
  direct_index : Int,
) -> Bool {
  let mut index = direct_index + 1
  while index < self.arguments.length() {
    if self.lowerer.callee_parameter_is_pointer(self.callee_function, index) {
      return true
    }
    index += 1
  }
  false
}

///|
fn CallArgumentPlanner::argument_is_pure_binary_value_expression(
  self : CallArgumentPlanner,
  index : Int,
) -> Bool {
  if self.argument_uses_reference_predeclare(index) {
    return false
  }
  if self.lowerer.expression_node_contains_user_function_call(
      self.arguments[index],
    ) {
    return false
  }
  match wgsl_ir_expr_node_without_groups(self.arguments[index]).kind() {
    Binary(_, _, _) => true
    _ => false
  }
}

///|
fn CallArgumentPlanner::argument_is_deferred_const_like(
  self : CallArgumentPlanner,
  argument : @ast.WgslExprNode,
) -> Bool {
  wgsl_ir_expr_node_is_literal_like(argument) ||
  wgsl_ir_expr_node_is_deferred_select_value(argument) ||
  self.lowerer.expression_node_is_inline_constant_reference(
    argument,
    self.scope,
  )
}

///|
fn CallArgumentPlanner::argument_uses_reference_predeclare(
  self : CallArgumentPlanner,
  index : Int,
) -> Bool {
  if self.lowerer.callee_parameter_is_pointer(self.callee_function, index) {
    return false
  }
  self.argument_is_reference_access_chain(self.arguments[index])
}

///|
fn CallArgumentPlanner::value_argument_lowers_before_prior_direct(
  self : CallArgumentPlanner,
  index : Int,
) -> Bool {
  guard wgsl_ir_expr_node_is_call_value(self.arguments[index]) else {
    return false
  }
  guard self.lowerer.expression_node_contains_naga_reference_value(
    self.arguments[index],
    self.function,
    self.scope,
  ) else {
    return false
  }
  for prior in 0..<index {
    if self.prelowered[prior] == None &&
      wgsl_ir_expr_node_is_call_value(self.arguments[prior]) {
      return false
    }
    if self.prelowered[prior] == None &&
      wgsl_ir_expr_node_is_direct_access_chain(self.arguments[prior]) &&
      wgsl_ir_direct_access_chain_root_is_function_argument(
        self.arguments[prior],
        self.scope,
      ) {
      return false
    }
    if self.prelowered[prior] == None &&
      wgsl_ir_expr_node_is_function_argument_value(
        self.arguments[prior],
        self.scope,
      ) {
      return true
    }
    if self.prelowered[prior] == None &&
      !self.argument_is_existing_alias(self.arguments[prior]) {
      return false
    }
  }
  false
}

///|
fn CallArgumentPlanner::lower_later_reference_before_direct(
  self : CallArgumentPlanner,
  direct_index : Int,
) -> Unit raise WgslIrLowerError {
  let mut lookahead = direct_index + 1
  while lookahead < self.arguments.length() {
    if self.prelowered[lookahead] != None {
      lookahead += 1
      continue
    }
    if wgsl_ir_expr_node_is_function_argument_value(
        self.arguments[lookahead],
        self.scope,
      ) {
      lookahead += 1
      continue
    }
    if wgsl_ir_expr_node_is_call_value(self.arguments[lookahead]) {
      return
    }
    if self.argument_is_pending_store_pointer_deref(lookahead) {
      self.prelowered[lookahead] = Some(self.lower_argument_at(lookahead))
      return
    }
    if self.argument_uses_reference_predeclare(lookahead) {
      self.prelowered[lookahead] = Some(self.lower_argument_at(lookahead))
      return
    }
    if self.argument_is_mutable_local_value(lookahead) {
      self.prelowered[lookahead] = Some(self.lower_argument_at(lookahead))
      return
    }
    if self.argument_is_existing_alias_reference(self.arguments[lookahead]) {
      lookahead += 1
      continue
    }
    if self.lowerer.expression_node_is_inline_constant_reference(
        self.arguments[lookahead],
        self.scope,
      ) {
      lookahead += 1
      continue
    }
    return
  }
}

///|
fn CallArgumentPlanner::argument_is_pending_store_pointer_deref(
  self : CallArgumentPlanner,
  index : Int,
) -> Bool {
  if self.lowerer.callee_parameter_is_pointer(self.callee_function, index) {
    return false
  }
  match self.scope.pending_store_pointer_argument_root {
    Some(name) =>
      wgsl_ir_expr_node_is_pointer_deref_of_argument_name(
        self.arguments[index], name,
      )
    None => false
  }
}

///|
fn CallArgumentPlanner::lower_next_reference_run(
  self : CallArgumentPlanner,
  start : Int,
) -> Int raise WgslIrLowerError {
  let mut run_start = start
  while run_start < self.arguments.length() &&
        self.prelowered[run_start] == None &&
        self.argument_is_existing_alias(self.arguments[run_start]) {
    run_start += 1
  }
  if run_start < self.arguments.length() &&
    self.prelowered[run_start] == None &&
    self.argument_uses_reference_predeclare(run_start) {
    self.lower_reference_run(run_start)
  } else {
    run_start
  }
}

///|
fn CallArgumentPlanner::lower_reference_run(
  self : CallArgumentPlanner,
  start : Int,
) -> Int raise WgslIrLowerError {
  let mut index = start
  while index < self.arguments.length() &&
        self.prelowered[index] == None &&
        self.argument_uses_reference_predeclare(index) {
    index += 1
  }
  for run_index in start..<index {
    if self.reference_has_dynamic_indexed_root(self.arguments[run_index]) {
      self.lowerer.predeclare_function_member_base_expressions(
        self.arguments[run_index],
        self.function,
        self.scope,
      )
    } else {
      self.lowerer.predeclare_function_member_base_expressions(
        self.arguments[run_index],
        self.function,
        self.scope,
      )
      let lookahead_start = run_index + 1
      for lookahead in lookahead_start..<index {
        if !self.reference_has_dynamic_indexed_root(self.arguments[lookahead]) &&
          wgsl_ir_direct_access_chain_root_is_function_argument(
            self.arguments[lookahead],
            self.scope,
          ) {
          self.lowerer.predeclare_function_member_base_expressions(
            self.arguments[lookahead],
            self.function,
            self.scope,
          )
        }
      }
    }
    self.prelowered[run_index] = Some(self.lower_argument_at(run_index))
  }
  index
}

///|
fn CallArgumentPlanner::argument_is_existing_alias(
  self : CallArgumentPlanner,
  argument : @ast.WgslExprNode,
) -> Bool {
  match argument.kind() {
    Group(inner) => self.argument_is_existing_alias(inner)
    Identifier(name) =>
      match self.scope.local_constants.get(name.name()) {
        Some({ value: ExpressionAlias(_), .. }) => true
        _ => false
      }
    _ => false
  }
}

///|
fn CallArgumentPlanner::argument_is_mutable_local_value(
  self : CallArgumentPlanner,
  index : Int,
) -> Bool {
  if self.lowerer.callee_parameter_is_pointer(self.callee_function, index) {
    return false
  }
  match self.arguments[index].kind() {
    Group(_) => self.argument_is_mutable_local_value_node(self.arguments[index])
    _ => self.argument_is_mutable_local_value_node(self.arguments[index])
  }
}

///|
fn CallArgumentPlanner::argument_is_mutable_local_value_node(
  self : CallArgumentPlanner,
  argument : @ast.WgslExprNode,
) -> Bool {
  match argument.kind() {
    Group(inner) => self.argument_is_mutable_local_value_node(inner)
    Identifier(name) =>
      match self.scope.locals.get(name.name()) {
        Some(handle) =>
          match self.function.local_variables.items.get(handle.index()) {
            Some(local_var) =>
              local_var.kind == Var && !local_var.generated_temporary
            None => false
          }
        None => false
      }
    _ => false
  }
}

///|
fn CallArgumentPlanner::argument_is_existing_alias_reference(
  self : CallArgumentPlanner,
  argument : @ast.WgslExprNode,
) -> Bool {
  match argument.kind() {
    Group(inner) => self.argument_is_existing_alias_reference(inner)
    Member(base, _) | Index(base, _) =>
      self.argument_is_existing_alias_reference(base)
    _ => self.argument_is_existing_alias(argument)
  }
}

///|
fn CallArgumentPlanner::reference_has_dynamic_indexed_root(
  self : CallArgumentPlanner,
  node : @ast.WgslExprNode,
) -> Bool {
  match node.kind() {
    Group(inner) => self.reference_has_dynamic_indexed_root(inner)
    Member(base, _) | Index(base, _) =>
      self.reference_access_base_has_dynamic_index(base)
    _ => false
  }
}

///|
fn CallArgumentPlanner::reference_access_base_has_dynamic_index(
  self : CallArgumentPlanner,
  node : @ast.WgslExprNode,
) -> Bool {
  match node.kind() {
    Group(inner) => self.reference_access_base_has_dynamic_index(inner)
    Member(base, _) => self.reference_access_base_has_dynamic_index(base)
    Index(base, index) =>
      !wgsl_ir_expr_node_is_static_literal_index(index) ||
      self.reference_access_base_has_dynamic_index(base)
    _ => false
  }
}

///|
fn CallArgumentPlanner::argument_is_reference_access_chain(
  self : CallArgumentPlanner,
  node : @ast.WgslExprNode,
) -> Bool {
  match node.kind() {
    Group(inner) => self.argument_is_reference_access_chain(inner)
    Member(base, _) | Index(base, _) =>
      self.argument_access_root_is_reference(base)
    _ => false
  }
}

///|
fn CallArgumentPlanner::argument_access_root_is_reference(
  self : CallArgumentPlanner,
  node : @ast.WgslExprNode,
) -> Bool {
  match node.kind() {
    Group(inner) => self.argument_access_root_is_reference(inner)
    Unary(op, inner) =>
      op == Multiply && self.argument_access_root_is_reference(inner)
    Member(base, _) | Index(base, _) =>
      self.argument_access_root_is_reference(base)
    Identifier(name) =>
      self.scope.arguments.contains(name.name()) ||
      self.argument_is_existing_alias(node) ||
      self.lowerer.global_names.contains(name.name())
    _ => false
  }
}

///|
fn CallArgumentPlanner::lower_argument_at(
  self : CallArgumentPlanner,
  index : Int,
) -> Handle raise WgslIrLowerError {
  self.lowerer.lower_user_function_call_argument_at(
    self.arguments[index],
    self.callee_function,
    index,
    self.function,
    self.scope,
  )
}
