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
fn WgslIrLowerer::materialize_store_pointer_if_needed(
  self : WgslIrLowerer,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
  pointer : Handle,
) -> Handle raise WgslIrLowerError {
  match function.expressions.items.get(pointer.index()) {
    Some(Access(base, index)) => {
      let lowered_base = self.materialize_store_pointer_if_needed(
        function, scope, block, base,
      )
      let lowered_index = self.materialize_store_pointer_index_if_needed(
        function, scope, block, lowered_base, index,
      )
      if lowered_base == base && lowered_index == index {
        pointer
      } else {
        function.expressions.append(
          Expression::Access(lowered_base, lowered_index),
        )
      }
    }
    Some(AccessIndex(base, index)) => {
      let lowered_base = self.materialize_store_pointer_if_needed(
        function, scope, block, base,
      )
      if lowered_base == base {
        pointer
      } else {
        function.expressions.append(
          Expression::AccessIndex(lowered_base, index),
        )
      }
    }
    Some(Component(base, component)) => {
      let lowered_base = self.materialize_store_pointer_if_needed(
        function, scope, block, base,
      )
      if lowered_base == base {
        pointer
      } else {
        function.expressions.append(
          Expression::Component(lowered_base, component),
        )
      }
    }
    _ => pointer
  }
}

///|
fn WgslIrLowerer::materialize_store_pointer_index_if_needed(
  self : WgslIrLowerer,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
  pointer_base : Handle,
  index : Handle,
) -> Handle raise WgslIrLowerError {
  let normalized = self.materialize_return_subexpressions(
    function, scope, block, index,
  )
  if self.function_expression_is_const_expression(function, normalized) &&
    self.function_expression_has_scalar_type(function, normalized) {
    return normalized
  }
  if function.expressions.items.get(normalized.index())
    is Some(FunctionArgument(_)) {
    return normalized
  }
  if wgsl_ir_function_expression_is_store_pointer_index_local_reference(
      function, normalized,
    ) {
    return normalized
  }
  if wgsl_ir_function_expression_is_store_pointer_index_effect(
      function, normalized,
    ) {
    return self.materialize_function_expression(
      function, scope, block, normalized,
    )
  }
  if wgsl_ir_function_store_pointer_root_is_user_local(function, pointer_base) {
    return normalized
  }
  if self.function_expression_should_snapshot_store_pointer_index(
      function, normalized,
    ) {
    self.materialize_function_expression_snapshot(
      function, scope, block, normalized,
    )
  } else {
    normalized
  }
}

///|
fn wgsl_ir_function_expression_is_store_pointer_index_local_reference(
  function : Function,
  handle : Handle,
) -> Bool {
  match function.expressions.items.get(handle.index()) {
    Some(Load(inner)) =>
      wgsl_ir_function_expression_is_store_pointer_index_local_reference(
        function, inner,
      )
    Some(LocalVariable(local_handle)) =>
      match function.local_variables.items.get(local_handle.index()) {
        Some(local_var) => local_var.kind == Let
        None => false
      }
    _ => false
  }
}

///|
fn wgsl_ir_function_expression_is_store_pointer_index_effect(
  function : Function,
  handle : Handle,
) -> Bool {
  match function.expressions.items.get(handle.index()) {
    Some(FunctionCall(_, _))
    | Some(AtomicCall(_, _))
    | Some(ImageSample(_, _, _, _, _, _, _, _, _))
    | Some(ImageLoad(_, _, _, _, _))
    | Some(ImageQuery(_, _))
    | Some(WorkGroupUniformLoad(_)) => true
    _ => false
  }
}

///|
fn WgslIrLowerer::function_expression_should_snapshot_store_pointer_index(
  self : WgslIrLowerer,
  function : Function,
  value : Handle,
) -> Bool {
  self.function_expression_is_var_pointer_load(function, value) &&
  self.function_expression_can_materialize_to_let(function, value)
}

///|
fn WgslIrLowerer::materialize_function_expression_snapshot(
  self : WgslIrLowerer,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
  value : Handle,
) -> Handle raise WgslIrLowerError {
  match function.expressions.items.get(value.index()) {
    Some(expression) => {
      let snapshot = function.expressions.append(expression)
      self.materialize_function_expression(function, scope, block, snapshot)
    }
    None =>
      raise WgslIrLowerError::UnsupportedExpression(
        "materialized expression snapshot \{value.index()}",
      )
  }
}
