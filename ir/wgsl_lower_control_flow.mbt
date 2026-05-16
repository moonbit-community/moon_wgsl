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
    if expression.role() == @ast.WgslStatementExpressionRole::Condition {
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
    return Block::Block()
  }
  if condition_index >= blocks.length() {
    raise WgslIrLowerError::UnsupportedStatement(
      "else-if condition without block",
    )
  }
  let condition_handle = self.lower_function_expression_ref(
    conditions[condition_index],
    function,
    scope,
  )
  let block = Block::Block()
  let condition_handle = self.materialize_control_flow_condition_if_needed(
    function, scope, block, condition_handle,
  )
  let accept = self.lower_child_block(blocks[condition_index], function, scope)
  let reject = self.lower_if_reject_chain(
    blocks,
    conditions,
    condition_index + 1,
    function,
    scope,
  )
  block.push(Statement::If(condition_handle, accept, reject))
  block
}
