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
fn WgslIrEmitter::function_emission_order(self : WgslIrEmitter) -> Array[Int] {
  if !self.options.order_functions_by_naga_reachability {
    return self.source_ordered_function_indices()
  }
  let order = self.naga_generated_import_function_order()
  let reachable = self.naga_reachable_function_order()
  for index in reachable {
    if self.function_order_should_include(index, order) {
      order.push(index)
    }
  }
  for index in 0..<self.shader_module.functions.items.length() {
    if self.function_order_should_include(index, order) {
      self.push_naga_function_with_dependencies(order, index)
    }
  }
  order
}

///|
fn WgslIrEmitter::naga_generated_import_function_order(
  self : WgslIrEmitter,
) -> Array[Int] {
  let order : Array[Int] = []
  for index in 0..<self.shader_module.functions.items.length() {
    if self.function_order_should_include(index, order) &&
      self.shader_module.functions.items[index].generated_import {
      order.push(index)
    }
  }
  order
}

///|
fn WgslIrEmitter::source_ordered_function_indices(
  self : WgslIrEmitter,
) -> Array[Int] {
  let order : Array[Int] = []
  for index in 0..<self.shader_module.functions.items.length() {
    if self.function_order_should_include(index, order) {
      order.push(index)
    }
  }
  order
}

///|
fn WgslIrEmitter::function_order_should_include(
  self : WgslIrEmitter,
  index : Int,
  emitted : Array[Int],
) -> Bool {
  if emitted.contains(index) {
    return false
  }
  if !self.should_emit_function(index) {
    return false
  }
  !self.function_is_entry_point_name(self.shader_module.functions.items[index])
}

///|
fn WgslIrEmitter::naga_reachable_function_order(
  self : WgslIrEmitter,
) -> Array[Int] {
  let order : Array[Int] = []
  for entry_point in self.shader_module.entry_points {
    self.push_naga_source_prefix_before_entry(order, entry_point)
    let direct = wgsl_ir_collect_block_function_calls(entry_point.function)
    for function_index in direct {
      self.push_naga_reachable_function_with_dependencies(order, function_index)
    }
  }
  order
}

///|
fn WgslIrEmitter::push_naga_source_prefix_before_entry(
  self : WgslIrEmitter,
  order : Array[Int],
  entry_point : EntryPoint,
) -> Unit {
  guard entry_point.source_start >= 0 else { return }
  for index in 0..<self.shader_module.functions.items.length() {
    let function = self.shader_module.functions.items[index]
    if function.source_start >= 0 &&
      function.source_start < entry_point.source_start &&
      !function.generated_import &&
      self.function_order_should_include(index, order) {
      self.push_naga_reachable_function_with_dependencies(order, index)
    }
  }
}

///|
fn WgslIrEmitter::push_naga_function_with_dependencies(
  self : WgslIrEmitter,
  order : Array[Int],
  index : Int,
) -> Unit {
  let visiting : Array[Int] = []
  self.push_naga_function_with_dependencies_inner(order, visiting, index)
}

///|
fn WgslIrEmitter::push_naga_reachable_function_with_dependencies(
  self : WgslIrEmitter,
  order : Array[Int],
  index : Int,
) -> Unit {
  if !self.function_order_should_include(index, order) {
    return
  }
  let dependencies : Array[Int] = []
  self.collect_naga_transitive_function_dependencies(index, dependencies)
  for dependency_index in 0..<self.shader_module.functions.items.length() {
    if dependency_index < index && dependencies.contains(dependency_index) {
      self.push_naga_reachable_function_with_dependencies(
        order, dependency_index,
      )
    }
  }
  let function = self.shader_module.functions.items[index]
  let direct = wgsl_ir_collect_block_function_calls(function)
  for dependency_index in direct {
    if dependency_index > index {
      self.push_naga_reachable_function_with_dependencies(
        order, dependency_index,
      )
    }
  }
  if self.function_order_should_include(index, order) {
    order.push(index)
  }
}

///|
fn WgslIrEmitter::collect_naga_transitive_function_dependencies(
  self : WgslIrEmitter,
  index : Int,
  dependencies : Array[Int],
) -> Unit {
  if !self.function_order_should_include(index, []) {
    return
  }
  let function = self.shader_module.functions.items[index]
  let direct = wgsl_ir_collect_block_function_calls(function)
  for dependency in direct {
    if dependency == index {
      continue
    }
    if !dependencies.contains(dependency) {
      dependencies.push(dependency)
      self.collect_naga_transitive_function_dependencies(
        dependency, dependencies,
      )
    }
  }
}

///|
fn WgslIrEmitter::push_naga_function_with_dependencies_inner(
  self : WgslIrEmitter,
  order : Array[Int],
  visiting : Array[Int],
  index : Int,
) -> Unit {
  if !self.function_order_should_include(index, order) ||
    visiting.contains(index) {
    return
  }
  visiting.push(index)
  let function = self.shader_module.functions.items[index]
  let direct = wgsl_ir_collect_block_function_calls(function)
  for dependency_index in direct {
    if dependency_index != index {
      self.push_naga_function_with_dependencies_inner(
        order, visiting, dependency_index,
      )
    }
  }
  visiting.pop() |> ignore
  if self.function_order_should_include(index, order) {
    order.push(index)
  }
}

///|
fn wgsl_ir_collect_block_function_calls(function : Function) -> Array[Int] {
  let calls : Array[Int] = []
  wgsl_ir_collect_function_calls_from_block(function, function.body, calls)
  calls
}

///|
fn wgsl_ir_collect_function_calls_from_block(
  function : Function,
  block : Block,
  calls : Array[Int],
) -> Unit {
  for statement in block.statements {
    wgsl_ir_collect_function_calls_from_statement(function, statement, calls)
  }
}

///|
fn wgsl_ir_collect_function_calls_from_statement(
  function : Function,
  statement : Statement,
  calls : Array[Int],
) -> Unit {
  match statement {
    Emit(range) => {
      let mut index = range.start.index()
      while index <= range.end.index() {
        wgsl_ir_collect_function_calls_from_expression(
          function,
          Handle::Handle(index),
          calls,
        )
        index = index + 1
      }
    }
    Block(nested) =>
      wgsl_ir_collect_function_calls_from_block(function, nested, calls)
    If(condition, accept, reject) => {
      wgsl_ir_collect_function_calls_from_expression(function, condition, calls)
      wgsl_ir_collect_function_calls_from_block(function, accept, calls)
      wgsl_ir_collect_function_calls_from_block(function, reject, calls)
    }
    Switch(selector, cases) => {
      wgsl_ir_collect_function_calls_from_expression(function, selector, calls)
      for case in cases {
        wgsl_ir_collect_function_calls_from_block(function, case.body, calls)
      }
    }
    Loop(body, continuing, break_if) => {
      wgsl_ir_collect_function_calls_from_block(function, body, calls)
      wgsl_ir_collect_function_calls_from_block(function, continuing, calls)
      match break_if {
        Some(condition) =>
          wgsl_ir_collect_function_calls_from_expression(
            function, condition, calls,
          )
        None => ()
      }
    }
    Return(value) =>
      match value {
        Some(expr) =>
          wgsl_ir_collect_function_calls_from_expression(function, expr, calls)
        None => ()
      }
    ConstAssert(expr) =>
      wgsl_ir_collect_function_calls_from_expression(function, expr, calls)
    Store(pointer, value) => {
      wgsl_ir_collect_function_calls_from_expression(function, pointer, calls)
      wgsl_ir_collect_function_calls_from_expression(function, value, calls)
    }
    ImageStore(image, coordinate, array_index, value) => {
      wgsl_ir_collect_function_calls_from_expression(function, image, calls)
      wgsl_ir_collect_function_calls_from_expression(
        function, coordinate, calls,
      )
      match array_index {
        Some(expr) =>
          wgsl_ir_collect_function_calls_from_expression(function, expr, calls)
        None => ()
      }
      wgsl_ir_collect_function_calls_from_expression(function, value, calls)
    }
    Atomic(pointer, _, value, compare) => {
      wgsl_ir_collect_function_calls_from_expression(function, pointer, calls)
      wgsl_ir_collect_function_calls_from_expression(function, value, calls)
      match compare {
        Some(expr) =>
          wgsl_ir_collect_function_calls_from_expression(function, expr, calls)
        None => ()
      }
    }
    ImageAtomic(image, coordinate, array_index, _, value) => {
      wgsl_ir_collect_function_calls_from_expression(function, image, calls)
      wgsl_ir_collect_function_calls_from_expression(
        function, coordinate, calls,
      )
      match array_index {
        Some(expr) =>
          wgsl_ir_collect_function_calls_from_expression(function, expr, calls)
        None => ()
      }
      wgsl_ir_collect_function_calls_from_expression(function, value, calls)
    }
    WorkGroupUniformLoad(pointer, result) => {
      wgsl_ir_collect_function_calls_from_expression(function, pointer, calls)
      wgsl_ir_collect_function_calls_from_expression(function, result, calls)
    }
    Call(callee, arguments, result) => {
      wgsl_ir_push_function_call(calls, callee.index())
      for argument in arguments {
        wgsl_ir_collect_function_calls_from_expression(
          function, argument, calls,
        )
      }
      match result {
        Some(expr) =>
          wgsl_ir_collect_function_calls_from_expression(function, expr, calls)
        None => ()
      }
    }
    RayQuery(query, _) =>
      wgsl_ir_collect_function_calls_from_expression(function, query, calls)
    RayPipelineFunction(TraceRay(a, b, c)) => {
      wgsl_ir_collect_function_calls_from_expression(function, a, calls)
      wgsl_ir_collect_function_calls_from_expression(function, b, calls)
      wgsl_ir_collect_function_calls_from_expression(function, c, calls)
    }
    SubgroupBallot(value, result) => {
      wgsl_ir_collect_function_calls_from_expression(function, value, calls)
      match result {
        Some(expr) =>
          wgsl_ir_collect_function_calls_from_expression(function, expr, calls)
        None => ()
      }
    }
    SubgroupGather(_, value, result)
    | SubgroupCollectiveOperation(_, _, value, result) => {
      wgsl_ir_collect_function_calls_from_expression(function, value, calls)
      wgsl_ir_collect_function_calls_from_expression(function, result, calls)
    }
    CooperativeStore(pointer, data) => {
      wgsl_ir_collect_function_calls_from_expression(function, pointer, calls)
      wgsl_ir_collect_function_calls_from_expression(
        function,
        data.pointer,
        calls,
      )
      wgsl_ir_collect_function_calls_from_expression(
        function,
        data.stride,
        calls,
      )
    }
    Declare(_)
    | Break
    | Continue
    | Kill
    | ControlBarrier(_)
    | MemoryBarrier(_) => ()
  }
}

///|
fn wgsl_ir_collect_function_calls_from_expression(
  function : Function,
  handle : Handle,
  calls : Array[Int],
) -> Unit {
  match function.expressions.items.get(handle.index()) {
    Some(expression) =>
      wgsl_ir_collect_function_calls_from_expression_inner(
        function, expression, calls,
      )
    None => ()
  }
}

///|
fn wgsl_ir_collect_function_calls_from_expression_inner(
  function : Function,
  expression : Expression,
  calls : Array[Int],
) -> Unit {
  match expression {
    Compose(_, components) =>
      for component in components {
        wgsl_ir_collect_function_calls_from_expression(
          function, component, calls,
        )
      }
    Access(base, index) | Binary(_, base, index) => {
      wgsl_ir_collect_function_calls_from_expression(function, base, calls)
      wgsl_ir_collect_function_calls_from_expression(function, index, calls)
    }
    AccessIndex(base, _)
    | Load(base)
    | AddressOf(_, base)
    | Unary(_, base)
    | Bitcast(_, base)
    | As(base, _, _)
    | Relational(_, base)
    | ArrayLength(base)
    | WorkGroupUniformLoad(base)
    | Splat(_, base)
    | Swizzle(_, base, _)
    | Derivative(_, _, base)
    | AtomicResult(base, _)
    | WorkGroupUniformLoadResult(base)
    | RayQueryProceed(base)
    | RayQueryConfirmIntersection(base)
    | RayQueryTerminate(base)
    | RayQueryGetIntersection(base, _) =>
      wgsl_ir_collect_function_calls_from_expression(function, base, calls)
    AtomicCall(_, arguments) | SubgroupCall(_, arguments) =>
      for argument in arguments {
        wgsl_ir_collect_function_calls_from_expression(
          function, argument, calls,
        )
      }
    FunctionCall(target, arguments) => {
      wgsl_ir_push_function_call(calls, target.index())
      for argument in arguments {
        wgsl_ir_collect_function_calls_from_expression(
          function, argument, calls,
        )
      }
    }
    Select(condition, accept, reject) => {
      wgsl_ir_collect_function_calls_from_expression(function, condition, calls)
      wgsl_ir_collect_function_calls_from_expression(function, accept, calls)
      wgsl_ir_collect_function_calls_from_expression(function, reject, calls)
    }
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
    ) => {
      wgsl_ir_collect_function_calls_from_expression(function, image, calls)
      wgsl_ir_collect_function_calls_from_expression(function, sampler, calls)
      wgsl_ir_collect_function_calls_from_expression(
        function, coordinate, calls,
      )
      wgsl_ir_collect_optional_function_call(function, array_index, calls)
      wgsl_ir_collect_optional_function_call(function, offset, calls)
      wgsl_ir_collect_sample_level_function_calls(function, level, calls)
      wgsl_ir_collect_optional_function_call(function, depth_ref, calls)
    }
    ImageLoad(image, coordinate, array_index, sample, level) => {
      wgsl_ir_collect_function_calls_from_expression(function, image, calls)
      wgsl_ir_collect_function_calls_from_expression(
        function, coordinate, calls,
      )
      wgsl_ir_collect_optional_function_call(function, array_index, calls)
      wgsl_ir_collect_optional_function_call(function, sample, calls)
      wgsl_ir_collect_optional_function_call(function, level, calls)
    }
    ImageQuery(image, query) => {
      wgsl_ir_collect_function_calls_from_expression(function, image, calls)
      match query {
        Size(level) =>
          wgsl_ir_collect_optional_function_call(function, level, calls)
        _ => ()
      }
    }
    Math(_, a, b, c, d) => {
      wgsl_ir_collect_function_calls_from_expression(function, a, calls)
      wgsl_ir_collect_optional_function_call(function, b, calls)
      wgsl_ir_collect_optional_function_call(function, c, calls)
      wgsl_ir_collect_optional_function_call(function, d, calls)
    }
    CallResult(target) => wgsl_ir_push_function_call(calls, target.index())
    RayQueryInitialize(query, acceleration, ray_desc) => {
      wgsl_ir_collect_function_calls_from_expression(function, query, calls)
      wgsl_ir_collect_function_calls_from_expression(
        function, acceleration, calls,
      )
      wgsl_ir_collect_function_calls_from_expression(function, ray_desc, calls)
    }
    RayQueryGenerateIntersection(query, intersection_t) => {
      wgsl_ir_collect_function_calls_from_expression(function, query, calls)
      wgsl_ir_collect_function_calls_from_expression(
        function, intersection_t, calls,
      )
    }
    RayQueryVertexPositions(query, _) =>
      wgsl_ir_collect_function_calls_from_expression(function, query, calls)
    SubgroupOperationResult(handle) =>
      wgsl_ir_collect_function_calls_from_expression(function, handle, calls)
    CooperativeLoad(_, _, _, data) => {
      wgsl_ir_collect_function_calls_from_expression(
        function,
        data.pointer,
        calls,
      )
      wgsl_ir_collect_function_calls_from_expression(
        function,
        data.stride,
        calls,
      )
    }
    CooperativeMultiplyAdd(a, b, c) => {
      wgsl_ir_collect_function_calls_from_expression(function, a, calls)
      wgsl_ir_collect_function_calls_from_expression(function, b, calls)
      wgsl_ir_collect_function_calls_from_expression(function, c, calls)
    }
    Literal(_)
    | Constant(_)
    | Override(_)
    | ZeroValue(_)
    | FunctionArgument(_)
    | GlobalVariable(_)
    | LocalVariable(_)
    | RayQueryProceedResult
    | SubgroupBallotResult => ()
  }
}

///|
fn wgsl_ir_collect_sample_level_function_calls(
  function : Function,
  level : SampleLevel,
  calls : Array[Int],
) -> Unit {
  match level {
    Exact(handle) | Bias(handle) =>
      wgsl_ir_collect_function_calls_from_expression(function, handle, calls)
    Gradient(x, y) => {
      wgsl_ir_collect_function_calls_from_expression(function, x, calls)
      wgsl_ir_collect_function_calls_from_expression(function, y, calls)
    }
    Auto | Zero => ()
  }
}

///|
fn wgsl_ir_collect_optional_function_call(
  function : Function,
  handle : Handle?,
  calls : Array[Int],
) -> Unit {
  match handle {
    Some(value) =>
      wgsl_ir_collect_function_calls_from_expression(function, value, calls)
    None => ()
  }
}

///|
fn wgsl_ir_push_function_call(calls : Array[Int], index : Int) -> Unit {
  if !calls.contains(index) {
    calls.push(index)
  }
}
