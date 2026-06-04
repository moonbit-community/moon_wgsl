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
fn wgsl_ir_record_store_value_temporary_references(
  function : Function,
  handle : Handle,
) -> Unit {
  let simple_store_value = !wgsl_ir_store_value_contains_materialized_operation(
    function, handle,
  )
  for index in 0..<function.expressions.items.length() {
    let reference = Handle::Handle(index)
    match function.expressions.items.get(index) {
      Some(LocalVariable(local_handle)) =>
        match function.local_variables.items.get(local_handle.index()) {
          Some(local_var) =>
            if local_var.generated_temporary &&
              wgsl_ir_store_value_contains_generated_temporary(
                function, handle, reference, local_var,
              ) {
              function.local_variables.items[local_handle.index()] = {
                name: local_var.name,
                kind: local_var.kind,
                generated_temporary: local_var.generated_temporary,
                generated_temporary_store_value_reference: simple_store_value,
                short_circuit_result: local_var.short_circuit_result,
                ty: local_var.ty,
                init: local_var.init,
              }
            }
          None => ()
        }
      _ => ()
    }
  }
}

///|
fn wgsl_ir_store_value_contains_materialized_operation(
  function : Function,
  store_value : Handle,
) -> Bool {
  for index in 0..<function.expressions.items.length() {
    let handle = Handle::Handle(index)
    if wgsl_ir_function_expression_graph_contains(function, store_value, handle) {
      match function.expressions.items.get(index) {
        Some(LocalVariable(local_handle)) =>
          match function.local_variables.items.get(local_handle.index()) {
            Some(local_var) =>
              if local_var.generated_temporary &&
                wgsl_ir_local_variable_initializes_materialized_value_call(
                  function, local_var,
                ) {
                return true
              }
            None => ()
          }
        Some(FunctionCall(_, _))
        | Some(CallResult(_))
        | Some(AtomicCall(_, _))
        | Some(AtomicResult(_, _))
        | Some(WorkGroupUniformLoad(_))
        | Some(WorkGroupUniformLoadResult(_))
        | Some(ImageSample(_, _, _, _, _, _, _, _, _))
        | Some(ImageLoad(_, _, _, _, _))
        | Some(ImageQuery(_, _)) => return true
        _ => ()
      }
    }
  }
  false
}

///|
fn wgsl_ir_store_value_contains_generated_temporary(
  function : Function,
  store_value : Handle,
  reference : Handle,
  local_var : LocalVariable,
) -> Bool {
  if wgsl_ir_function_expression_graph_contains(
      function, store_value, reference,
    ) {
    return true
  }
  match local_var.init {
    Some(init) =>
      wgsl_ir_function_expression_graph_contains(function, store_value, init)
    None => false
  }
}
