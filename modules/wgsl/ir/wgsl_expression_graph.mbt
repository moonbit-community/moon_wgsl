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
fn wgsl_ir_function_expression_graph_contains(
  function : Function,
  root : Handle,
  needle : Handle,
) -> Bool {
  let visited : @set.Set[Int] = Set([])
  wgsl_ir_function_expression_graph_contains_inner(
    function, root, needle, visited,
  )
}

///|
fn wgsl_ir_function_expression_graph_contains_inner(
  function : Function,
  root : Handle,
  needle : Handle,
  visited : @set.Set[Int],
) -> Bool {
  if root == needle {
    return true
  }
  if visited.contains(root.index()) {
    return false
  }
  visited.add(root.index())
  match function.expressions.items.get(root.index()) {
    Some(expression) =>
      wgsl_ir_function_expression_operands_contain(
        function, expression, needle, visited,
      )
    None => false
  }
}

///|
fn wgsl_ir_function_expression_operands_contain(
  function : Function,
  expression : Expression,
  needle : Handle,
  visited : @set.Set[Int],
) -> Bool {
  match expression {
    Compose(_, components)
    | AtomicCall(_, components)
    | FunctionCall(_, components)
    | SubgroupCall(_, components) =>
      wgsl_ir_function_handle_array_contains(
        function, components, needle, visited,
      )
    Access(base, index) =>
      wgsl_ir_function_handle_contains(function, base, needle, visited) ||
      wgsl_ir_function_handle_contains(function, index, needle, visited)
    AccessIndex(base, _)
    | Component(base, _)
    | Splat(_, base)
    | Swizzle(_, base, _)
    | Load(base)
    | WorkGroupUniformLoad(base)
    | ArrayLength(base)
    | RayQueryProceed(base)
    | RayQueryConfirmIntersection(base)
    | RayQueryTerminate(base)
    | RayQueryVertexPositions(base, _)
    | RayQueryGetIntersection(base, _)
    | SubgroupOperationResult(base) =>
      wgsl_ir_function_handle_contains(function, base, needle, visited)
    AddressOf(base, target)
    | Binary(_, base, target)
    | Bitcast(base, target)
    | RayQueryGenerateIntersection(base, target) =>
      wgsl_ir_function_handle_contains(function, base, needle, visited) ||
      wgsl_ir_function_handle_contains(function, target, needle, visited)
    CooperativeMultiplyAdd(a, b, c) =>
      wgsl_ir_function_handle_contains(function, a, needle, visited) ||
      wgsl_ir_function_handle_contains(function, b, needle, visited) ||
      wgsl_ir_function_handle_contains(function, c, needle, visited)
    ImageSample(
      image,
      sampler,
      _,
      coordinate,
      array_index,
      offset,
      level,
      depth_ref,
      _
    ) =>
      wgsl_ir_function_handle_contains(function, image, needle, visited) ||
      wgsl_ir_function_handle_contains(function, sampler, needle, visited) ||
      wgsl_ir_function_handle_contains(function, coordinate, needle, visited) ||
      wgsl_ir_function_optional_handle_contains(
        function, array_index, needle, visited,
      ) ||
      wgsl_ir_function_optional_handle_contains(
        function, offset, needle, visited,
      ) ||
      wgsl_ir_function_sample_level_contains(function, level, needle, visited) ||
      wgsl_ir_function_optional_handle_contains(
        function, depth_ref, needle, visited,
      )
    ImageLoad(image, coordinate, array_index, sample, level) =>
      wgsl_ir_function_handle_contains(function, image, needle, visited) ||
      wgsl_ir_function_handle_contains(function, coordinate, needle, visited) ||
      wgsl_ir_function_optional_handle_contains(
        function, array_index, needle, visited,
      ) ||
      wgsl_ir_function_optional_handle_contains(
        function, sample, needle, visited,
      ) ||
      wgsl_ir_function_optional_handle_contains(
        function, level, needle, visited,
      )
    ImageQuery(image, query) =>
      wgsl_ir_function_handle_contains(function, image, needle, visited) ||
      wgsl_ir_function_image_query_contains(function, query, needle, visited)
    Unary(_, inner)
    | Derivative(_, _, inner)
    | Relational(_, inner)
    | As(inner, _, _)
    | WorkGroupUniformLoadResult(inner) =>
      wgsl_ir_function_handle_contains(function, inner, needle, visited)
    AtomicResult(_, _) => false
    Select(condition, accept, reject)
    | RayQueryInitialize(condition, accept, reject) =>
      wgsl_ir_function_handle_contains(function, condition, needle, visited) ||
      wgsl_ir_function_handle_contains(function, accept, needle, visited) ||
      wgsl_ir_function_handle_contains(function, reject, needle, visited)
    Math(_, a, b, c, d) =>
      wgsl_ir_function_handle_contains(function, a, needle, visited) ||
      wgsl_ir_function_optional_handle_contains(function, b, needle, visited) ||
      wgsl_ir_function_optional_handle_contains(function, c, needle, visited) ||
      wgsl_ir_function_optional_handle_contains(function, d, needle, visited)
    CooperativeLoad(_, _, _, data) =>
      wgsl_ir_function_cooperative_data_contains(
        function, data, needle, visited,
      )
    Literal(_)
    | Constant(_)
    | Override(_)
    | ZeroValue(_)
    | FunctionArgument(_)
    | GlobalVariable(_)
    | LocalVariable(_)
    | CallResult(_)
    | RayQueryProceedResult
    | SubgroupBallotResult => false
  }
}

///|
fn wgsl_ir_function_handle_array_contains(
  function : Function,
  handles : Array[Handle],
  needle : Handle,
  visited : @set.Set[Int],
) -> Bool {
  for handle in handles {
    if wgsl_ir_function_handle_contains(function, handle, needle, visited) {
      return true
    }
  }
  false
}

///|
fn wgsl_ir_function_optional_handle_contains(
  function : Function,
  handle : Handle?,
  needle : Handle,
  visited : @set.Set[Int],
) -> Bool {
  match handle {
    Some(value) =>
      wgsl_ir_function_handle_contains(function, value, needle, visited)
    None => false
  }
}

///|
fn wgsl_ir_function_handle_contains(
  function : Function,
  handle : Handle,
  needle : Handle,
  visited : @set.Set[Int],
) -> Bool {
  wgsl_ir_function_expression_graph_contains_inner(
    function, handle, needle, visited,
  )
}

///|
fn wgsl_ir_function_sample_level_contains(
  function : Function,
  level : SampleLevel,
  needle : Handle,
  visited : @set.Set[Int],
) -> Bool {
  match level {
    Exact(handle) | Bias(handle) =>
      wgsl_ir_function_handle_contains(function, handle, needle, visited)
    Gradient(x, y) =>
      wgsl_ir_function_handle_contains(function, x, needle, visited) ||
      wgsl_ir_function_handle_contains(function, y, needle, visited)
    Auto | Zero => false
  }
}

///|
fn wgsl_ir_function_image_query_contains(
  function : Function,
  query : ImageQuery,
  needle : Handle,
  visited : @set.Set[Int],
) -> Bool {
  match query {
    Size(level) =>
      wgsl_ir_function_optional_handle_contains(
        function, level, needle, visited,
      )
    NumLevels | NumLayers | NumSamples => false
  }
}

///|
fn wgsl_ir_function_cooperative_data_contains(
  function : Function,
  data : CooperativeData,
  needle : Handle,
  visited : @set.Set[Int],
) -> Bool {
  wgsl_ir_function_handle_contains(function, data.pointer, needle, visited) ||
  wgsl_ir_function_handle_contains(function, data.stride, needle, visited)
}
