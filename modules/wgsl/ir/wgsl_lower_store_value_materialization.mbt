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
fn WgslIrLowerer::materialize_store_value_for_pointer_if_needed(
  self : WgslIrLowerer,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
  pointer : Handle,
  value : Handle,
) -> Handle raise WgslIrLowerError {
  ignore(
    self.materialize_pointer_subexpressions(function, scope, block, pointer),
  )
  let normalized = self.materialize_return_subexpressions(
    function, scope, block, value,
  )
  match self.store_pointer_value_type(function, pointer) {
    Some(ty) =>
      self.contextualize_function_expression_for_type(function, normalized, ty)
    None => ()
  }
  if self.function_expression_should_materialize_as_store_value(
      function, normalized,
    ) ||
    self.function_expression_should_materialize_as_projected_local_store_value(
      function, pointer, normalized,
    ) {
    self.materialize_function_expression(function, scope, block, normalized)
  } else {
    normalized
  }
}

///|
fn WgslIrLowerer::store_pointer_value_type(
  self : WgslIrLowerer,
  function : Function,
  pointer : Handle,
) -> Handle? {
  match self.function_expression_type(function, pointer) {
    Some(ty) => Some(self.deref_pointer_type_handle(ty))
    None => None
  }
}

///|
fn WgslIrLowerer::function_expression_should_materialize_as_projected_local_store_value(
  self : WgslIrLowerer,
  function : Function,
  pointer : Handle,
  value : Handle,
) -> Bool {
  self.function_store_pointer_is_projected_user_local(function, pointer) &&
  !wgsl_ir_function_expression_has_arena_name(function, value) &&
  self.function_expression_is_var_pointer_load(function, value) &&
  self.function_expression_can_materialize_to_let(function, value)
}

///|
fn WgslIrLowerer::function_store_pointer_is_projected_user_local(
  self : WgslIrLowerer,
  function : Function,
  pointer : Handle,
) -> Bool {
  ignore(self)
  match function.expressions.items.get(pointer.index()) {
    Some(Access(base, _))
    | Some(AccessIndex(base, _))
    | Some(Component(base, _))
    | Some(Swizzle(_, base, _)) =>
      wgsl_ir_function_store_pointer_root_is_user_local(function, base)
    _ => false
  }
}

///|
fn wgsl_ir_function_store_pointer_root_is_user_local(
  function : Function,
  pointer : Handle,
) -> Bool {
  match function.expressions.items.get(pointer.index()) {
    Some(LocalVariable(local_handle)) =>
      match function.local_variables.items.get(local_handle.index()) {
        Some(local_var) =>
          local_var.kind == Var && !local_var.generated_temporary
        None => false
      }
    Some(Access(base, _))
    | Some(AccessIndex(base, _))
    | Some(Component(base, _))
    | Some(Swizzle(_, base, _)) =>
      wgsl_ir_function_store_pointer_root_is_user_local(function, base)
    _ => false
  }
}
