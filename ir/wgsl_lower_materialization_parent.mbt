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
fn wgsl_ir_parent_expression_operand(
  function : Function,
  original : Handle,
  lowered : Handle,
) -> Handle {
  if lowered != original &&
    wgsl_ir_function_expression_is_generated_temporary_reference(
      function, lowered,
    ) {
    original
  } else {
    lowered
  }
}

///|
fn wgsl_ir_parent_optional_expression_operand(
  function : Function,
  original : Handle?,
  lowered : Handle?,
) -> Handle? {
  match (original, lowered) {
    (Some(original_handle), Some(lowered_handle)) =>
      Some(
        wgsl_ir_parent_expression_operand(
          function, original_handle, lowered_handle,
        ),
      )
    _ => lowered
  }
}

///|
fn wgsl_ir_parent_sample_level_operand(
  function : Function,
  original : SampleLevel,
  lowered : SampleLevel,
) -> SampleLevel {
  match (original, lowered) {
    (Exact(original_handle), Exact(lowered_handle)) =>
      Exact(
        wgsl_ir_parent_expression_operand(
          function, original_handle, lowered_handle,
        ),
      )
    (Bias(original_handle), Bias(lowered_handle)) =>
      Bias(
        wgsl_ir_parent_expression_operand(
          function, original_handle, lowered_handle,
        ),
      )
    (Gradient(original_x, original_y), Gradient(lowered_x, lowered_y)) =>
      Gradient(
        wgsl_ir_parent_expression_operand(function, original_x, lowered_x),
        wgsl_ir_parent_expression_operand(function, original_y, lowered_y),
      )
    _ => lowered
  }
}

///|
fn wgsl_ir_projected_temporary_expression_slots(
  function : Function,
  handle : Handle,
) -> Int {
  match function.expressions.items.get(handle.index()) {
    Some(LocalVariable(local_handle)) =>
      match function.local_variables.items.get(local_handle.index()) {
        Some(local_var) =>
          match local_var.init {
            Some(init) =>
              match function.expressions.items.get(init.index()) {
                Some(ImageQuery(_, _)) => 1
                _ => 2
              }
            None => 2
          }
        None => 2
      }
    _ => 2
  }
}
