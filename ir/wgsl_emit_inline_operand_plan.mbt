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
fn wgsl_ir_function_expression_is_inline_naga_operand_slot_for_call_result(
  function : Function,
  handle : Handle,
  result : Handle,
) -> Bool {
  let inline_operand = match function.expressions.items.get(handle.index()) {
    Some(Literal(_))
    | Some(Constant(_))
    | Some(Override(_))
    | Some(ZeroValue(_)) => true
    _ => false
  }
  inline_operand &&
  wgsl_ir_function_expressions_share_materialized_parent(
    function, handle, result,
  )
}

///|
fn wgsl_ir_function_expressions_share_materialized_parent(
  function : Function,
  operand : Handle,
  result : Handle,
) -> Bool {
  for local_var in function.local_variables.items {
    match local_var.init {
      Some(root) =>
        if wgsl_ir_function_expression_root_contains_pair(
            function, root, operand, result,
          ) {
          return true
        }
      None => ()
    }
  }
  wgsl_ir_function_block_contains_expression_pair(
    function,
    function.body,
    operand,
    result,
  )
}

///|
fn wgsl_ir_function_block_contains_expression_pair(
  function : Function,
  block : Block,
  operand : Handle,
  result : Handle,
) -> Bool {
  for statement in block.statements {
    if wgsl_ir_function_statement_contains_expression_pair(
        function, statement, operand, result,
      ) {
      return true
    }
  }
  false
}

///|
fn wgsl_ir_function_statement_contains_expression_pair(
  function : Function,
  statement : Statement,
  operand : Handle,
  result : Handle,
) -> Bool {
  match statement {
    Declare(_)
    | Emit(_)
    | Phony(_)
    | Break
    | Continue
    | ImplicitReturn
    | Kill
    | ControlBarrier(_)
    | MemoryBarrier(_) => false
    Block(child) =>
      wgsl_ir_function_block_contains_expression_pair(
        function, child, operand, result,
      )
    If(condition, accept, reject) =>
      wgsl_ir_function_expression_root_contains_pair(
        function, condition, operand, result,
      ) ||
      wgsl_ir_function_block_contains_expression_pair(
        function, accept, operand, result,
      ) ||
      wgsl_ir_function_block_contains_expression_pair(
        function, reject, operand, result,
      )
    Switch(selector, cases) => {
      if wgsl_ir_function_expression_root_contains_pair(
          function, selector, operand, result,
        ) {
        return true
      }
      for case in cases {
        if wgsl_ir_function_block_contains_expression_pair(
            function,
            case.body,
            operand,
            result,
          ) {
          return true
        }
      }
      false
    }
    Loop(body, continuing, break_if) =>
      wgsl_ir_function_block_contains_expression_pair(
        function, body, operand, result,
      ) ||
      wgsl_ir_function_block_contains_expression_pair(
        function, continuing, operand, result,
      ) ||
      wgsl_ir_function_optional_expression_root_contains_pair(
        function, break_if, operand, result,
      )
    Return(value) =>
      wgsl_ir_function_optional_expression_root_contains_pair(
        function, value, operand, result,
      )
    ConstAssert(condition) =>
      wgsl_ir_function_expression_root_contains_pair(
        function, condition, operand, result,
      )
    Store(pointer, value) =>
      wgsl_ir_function_expression_root_contains_pair(
        function, pointer, operand, result,
      ) ||
      wgsl_ir_function_expression_root_contains_pair(
        function, value, operand, result,
      )
    ImageStore(image, coordinate, array_index, value) =>
      wgsl_ir_function_expression_root_contains_pair(
        function, image, operand, result,
      ) ||
      wgsl_ir_function_expression_root_contains_pair(
        function, coordinate, operand, result,
      ) ||
      wgsl_ir_function_optional_expression_root_contains_pair(
        function, array_index, operand, result,
      ) ||
      wgsl_ir_function_expression_root_contains_pair(
        function, value, operand, result,
      )
    Atomic(pointer, _, value, compare) =>
      wgsl_ir_function_expression_root_contains_pair(
        function, pointer, operand, result,
      ) ||
      wgsl_ir_function_expression_root_contains_pair(
        function, value, operand, result,
      ) ||
      wgsl_ir_function_optional_expression_root_contains_pair(
        function, compare, operand, result,
      )
    ImageAtomic(image, coordinate, array_index, _, value) =>
      wgsl_ir_function_expression_root_contains_pair(
        function, image, operand, result,
      ) ||
      wgsl_ir_function_expression_root_contains_pair(
        function, coordinate, operand, result,
      ) ||
      wgsl_ir_function_optional_expression_root_contains_pair(
        function, array_index, operand, result,
      ) ||
      wgsl_ir_function_expression_root_contains_pair(
        function, value, operand, result,
      )
    WorkGroupUniformLoad(pointer, value)
    | SubgroupGather(_, pointer, value)
    | SubgroupCollectiveOperation(_, _, pointer, value) =>
      wgsl_ir_function_expression_root_contains_pair(
        function, pointer, operand, result,
      ) ||
      wgsl_ir_function_expression_root_contains_pair(
        function, value, operand, result,
      )
    Call(_, arguments, call_result) =>
      call_result != Some(result) &&
      wgsl_ir_function_expression_array_contains_pair(
        function, arguments, operand, result,
      )
    RayQuery(query, ray_function) =>
      wgsl_ir_function_expression_root_contains_pair(
        function, query, operand, result,
      ) ||
      wgsl_ir_function_ray_query_contains_expression_pair(
        function, ray_function, operand, result,
      )
    RayPipelineFunction(ray_function) =>
      wgsl_ir_function_ray_pipeline_contains_expression_pair(
        function, ray_function, operand, result,
      )
    SubgroupBallot(value, maybe_result) =>
      wgsl_ir_function_expression_root_contains_pair(
        function, value, operand, result,
      ) ||
      wgsl_ir_function_optional_expression_root_contains_pair(
        function, maybe_result, operand, result,
      )
    CooperativeStore(pointer, data) =>
      wgsl_ir_function_expression_root_contains_pair(
        function, pointer, operand, result,
      ) ||
      wgsl_ir_function_cooperative_data_contains_expression_pair(
        function, data, operand, result,
      )
  }
}

///|
fn wgsl_ir_function_expression_array_contains_pair(
  function : Function,
  roots : Array[Handle],
  operand : Handle,
  result : Handle,
) -> Bool {
  for root in roots {
    if wgsl_ir_function_expression_root_contains_pair(
        function, root, operand, result,
      ) {
      return true
    }
  }
  false
}

///|
fn wgsl_ir_function_optional_expression_root_contains_pair(
  function : Function,
  root : Handle?,
  operand : Handle,
  result : Handle,
) -> Bool {
  match root {
    Some(handle) =>
      wgsl_ir_function_expression_root_contains_pair(
        function, handle, operand, result,
      )
    None => false
  }
}

///|
fn wgsl_ir_function_expression_root_contains_pair(
  function : Function,
  root : Handle,
  operand : Handle,
  result : Handle,
) -> Bool {
  root != result &&
  wgsl_ir_function_expression_graph_contains(function, root, operand) &&
  wgsl_ir_function_expression_graph_contains(function, root, result)
}

///|
fn wgsl_ir_function_ray_query_contains_expression_pair(
  function : Function,
  ray_function : RayQueryFunction,
  operand : Handle,
  result : Handle,
) -> Bool {
  match ray_function {
    Initialize(a, b) =>
      wgsl_ir_function_expression_root_contains_pair(
        function, a, operand, result,
      ) ||
      wgsl_ir_function_expression_root_contains_pair(
        function, b, operand, result,
      )
    Proceed(value) | GenerateIntersection(value) =>
      wgsl_ir_function_expression_root_contains_pair(
        function, value, operand, result,
      )
    ConfirmIntersection | Terminate => false
  }
}

///|
fn wgsl_ir_function_ray_pipeline_contains_expression_pair(
  function : Function,
  ray_function : RayPipelineFunction,
  operand : Handle,
  result : Handle,
) -> Bool {
  match ray_function {
    TraceRay(a, b, c) =>
      wgsl_ir_function_expression_root_contains_pair(
        function, a, operand, result,
      ) ||
      wgsl_ir_function_expression_root_contains_pair(
        function, b, operand, result,
      ) ||
      wgsl_ir_function_expression_root_contains_pair(
        function, c, operand, result,
      )
  }
}

///|
fn wgsl_ir_function_cooperative_data_contains_expression_pair(
  function : Function,
  data : CooperativeData,
  operand : Handle,
  result : Handle,
) -> Bool {
  wgsl_ir_function_expression_root_contains_pair(
    function,
    data.pointer,
    operand,
    result,
  ) ||
  wgsl_ir_function_expression_root_contains_pair(
    function,
    data.stride,
    operand,
    result,
  )
}
