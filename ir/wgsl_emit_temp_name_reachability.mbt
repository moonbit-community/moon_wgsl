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
fn wgsl_ir_function_expression_is_unmaterialized_function_argument_reference(
  function : Function,
  handle : Handle,
  limit : Handle,
) -> Bool {
  match function.expressions.items.get(handle.index()) {
    Some(FunctionArgument(index)) =>
      handle.index() != index &&
      !wgsl_ir_function_expression_graph_contains(function, limit, handle) &&
      !wgsl_ir_function_expression_is_used_by_materialized_value_before(
        function, handle, limit,
      )
    _ => false
  }
}

///|
fn wgsl_ir_function_expression_is_used_by_materialized_value_before(
  function : Function,
  needle : Handle,
  limit : Handle,
) -> Bool {
  for local_var in function.local_variables.items {
    if local_var.generated_temporary {
      match local_var.init {
        Some(init) =>
          if init.index() <= limit.index() &&
            wgsl_ir_function_expression_graph_contains(function, init, needle) {
            return true
          }
        None => ()
      }
    }
  }
  for statement in function.body.statements {
    match statement {
      Call(_, arguments, Some(result)) =>
        if result.index() <= limit.index() {
          for argument in arguments {
            if wgsl_ir_function_expression_graph_contains(
                function, argument, needle,
              ) {
              return true
            }
          }
        }
      _ => ()
    }
  }
  false
}
