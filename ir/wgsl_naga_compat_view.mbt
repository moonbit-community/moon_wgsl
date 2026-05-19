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
priv struct WgslIrNagaCompatView {
  shader_module : Module
  filter : WgslIrEmitFilter?
  declarations : WgslIrNagaCompatDeclarationArena
  mut names : WgslIrEmitNameTable
}

///|
priv struct WgslIrNagaCompatDeclarationArena {
  types : Array[WgslIrNagaCompatDeclarationSlot]
  constants : Array[WgslIrNagaCompatDeclarationSlot]
  overrides : Array[WgslIrNagaCompatDeclarationSlot]
  global_variables : Array[WgslIrNagaCompatDeclarationSlot]
  functions : Array[WgslIrNagaCompatDeclarationSlot]
}

///|
priv struct WgslIrNagaCompatDeclarationSlot {
  source_index : Int
  naga_index : Int
}

///|
priv struct WgslIrNagaCompatPlanner {
  shader_module : Module
  filter : WgslIrEmitFilter?
}

///|
fn build_wgsl_ir_naga_compat_view(
  shader_module : Module,
  root_items : Array[String]?,
) -> WgslIrNagaCompatView {
  let filter = wgsl_ir_emit_filter_from_optional_roots(
    shader_module, root_items,
  )
  let planner = WgslIrNagaCompatPlanner::{ shader_module, filter }
  let view = WgslIrNagaCompatView::{
    shader_module,
    filter,
    declarations: planner.declaration_arena(),
    names: WgslIrEmitNameTable::empty(),
  }
  view.names = build_wgsl_ir_emit_name_table_for_naga_compat_view(view)
  view
}

///|
fn WgslIrNagaCompatPlanner::declaration_arena(
  self : WgslIrNagaCompatPlanner,
) -> WgslIrNagaCompatDeclarationArena {
  WgslIrNagaCompatDeclarationArena::{
    types: wgsl_ir_naga_compat_declaration_slots(self.type_order()),
    constants: wgsl_ir_naga_compat_declaration_slots(self.constant_order()),
    overrides: wgsl_ir_naga_compat_declaration_slots(self.override_order()),
    global_variables: wgsl_ir_naga_compat_declaration_slots(
      self.global_variable_order(),
    ),
    functions: wgsl_ir_naga_compat_declaration_slots(self.function_order()),
  }
}

///|
fn WgslIrNagaCompatPlanner::type_order(
  self : WgslIrNagaCompatPlanner,
) -> Array[Int] {
  match self.filter {
    Some(filter) => filter.type_order
    None =>
      wgsl_ir_source_order_indices(self.shader_module.types.items.length())
  }
}

///|
fn WgslIrNagaCompatPlanner::constant_order(
  self : WgslIrNagaCompatPlanner,
) -> Array[Int] {
  match self.filter {
    Some(filter) => filter.constant_order
    None =>
      wgsl_ir_source_order_indices(self.shader_module.constants.items.length())
  }
}

///|
fn WgslIrNagaCompatPlanner::override_order(
  self : WgslIrNagaCompatPlanner,
) -> Array[Int] {
  match self.filter {
    Some(filter) => filter.override_order
    None =>
      wgsl_ir_source_order_indices(self.shader_module.overrides.items.length())
  }
}

///|
fn WgslIrNagaCompatPlanner::global_variable_order(
  self : WgslIrNagaCompatPlanner,
) -> Array[Int] {
  match self.filter {
    Some(filter) => filter.global_variable_order
    None =>
      wgsl_ir_source_order_indices(
        self.shader_module.global_variables.items.length(),
      )
  }
}

///|
fn WgslIrNagaCompatPlanner::function_order(
  self : WgslIrNagaCompatPlanner,
) -> Array[Int] {
  let order = self.generated_import_function_order()
  let reachable = self.reachable_function_order()
  for index in reachable {
    if self.function_order_should_include(index, order) {
      order.push(index)
    }
  }
  for index in 0..<self.shader_module.functions.items.length() {
    if self.function_order_should_include(index, order) {
      self.push_function_with_dependencies(order, index)
    }
  }
  order
}

///|
fn WgslIrNagaCompatPlanner::generated_import_function_order(
  self : WgslIrNagaCompatPlanner,
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
fn WgslIrNagaCompatPlanner::reachable_function_order(
  self : WgslIrNagaCompatPlanner,
) -> Array[Int] {
  let order : Array[Int] = []
  for entry_point in self.shader_module.entry_points {
    self.push_source_prefix_before_entry(order, entry_point)
    let direct = wgsl_ir_collect_block_function_calls(entry_point.function)
    for function_index in direct {
      self.push_reachable_function_with_dependencies(order, function_index)
    }
  }
  order
}

///|
fn WgslIrNagaCompatPlanner::push_source_prefix_before_entry(
  self : WgslIrNagaCompatPlanner,
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
      self.push_reachable_function_with_dependencies(order, index)
    }
  }
}

///|
fn WgslIrNagaCompatPlanner::push_function_with_dependencies(
  self : WgslIrNagaCompatPlanner,
  order : Array[Int],
  index : Int,
) -> Unit {
  let visiting : Array[Int] = []
  self.push_function_with_dependencies_inner(order, visiting, index)
}

///|
fn WgslIrNagaCompatPlanner::push_reachable_function_with_dependencies(
  self : WgslIrNagaCompatPlanner,
  order : Array[Int],
  index : Int,
) -> Unit {
  if !self.function_order_should_include(index, order) {
    return
  }
  let dependencies : Array[Int] = []
  self.collect_transitive_function_dependencies(index, dependencies)
  for dependency_index in 0..<self.shader_module.functions.items.length() {
    if dependency_index < index && dependencies.contains(dependency_index) {
      self.push_reachable_function_with_dependencies(order, dependency_index)
    }
  }
  let function = self.shader_module.functions.items[index]
  let direct = wgsl_ir_collect_block_function_calls(function)
  for dependency_index in direct {
    if dependency_index > index {
      self.push_reachable_function_with_dependencies(order, dependency_index)
    }
  }
  if self.function_order_should_include(index, order) {
    order.push(index)
  }
}

///|
fn WgslIrNagaCompatPlanner::collect_transitive_function_dependencies(
  self : WgslIrNagaCompatPlanner,
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
      self.collect_transitive_function_dependencies(dependency, dependencies)
    }
  }
}

///|
fn WgslIrNagaCompatPlanner::push_function_with_dependencies_inner(
  self : WgslIrNagaCompatPlanner,
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
      self.push_function_with_dependencies_inner(
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
fn WgslIrNagaCompatPlanner::function_order_should_include(
  self : WgslIrNagaCompatPlanner,
  index : Int,
  emitted : Array[Int],
) -> Bool {
  if emitted.contains(index) {
    return false
  }
  if !self.should_emit_function(index) {
    return false
  }
  !wgsl_ir_function_is_entry_point_name(
    self.shader_module.functions.items[index],
    self.shader_module,
  )
}

///|
fn wgsl_ir_function_is_entry_point_name(
  function : Function,
  shader_module : Module,
) -> Bool {
  match function.name {
    Some(name) =>
      for entry_point in shader_module.entry_points {
        if entry_point.name == name {
          return true
        }
      }
    None => ()
  }
  false
}

///|
fn WgslIrNagaCompatPlanner::should_emit_function(
  self : WgslIrNagaCompatPlanner,
  index : Int,
) -> Bool {
  match self.filter {
    Some(filter) => filter.contains_function(index)
    None => true
  }
}

///|
fn WgslIrNagaCompatView::should_emit_entry_point(
  self : WgslIrNagaCompatView,
  index : Int,
) -> Bool {
  match self.filter {
    Some(filter) => filter.contains_entry_point(index)
    None => true
  }
}

///|
fn build_wgsl_ir_emit_name_table_for_naga_compat_view(
  view : WgslIrNagaCompatView,
) -> WgslIrEmitNameTable {
  let module_ = view.shader_module
  let table = WgslIrEmitNameTable::empty()
  let namer = WgslIrNagaNamer::WgslIrNagaNamer()
  for index in view.type_order() {
    view.allocate_type_name(table, namer, index)
  }
  for ep_index in 0..<module_.entry_points.length() {
    if view.should_emit_entry_point(ep_index) {
      view.allocate_entry_point_signature_names(table, namer, ep_index)
    }
  }
  for fn_index in view.function_order() {
    view.allocate_function_signature_names(table, namer, fn_index)
  }
  for index in view.global_variable_order() {
    table.names.set(
      wgsl_ir_emit_name_key("global", index),
      namer.call_or(module_.global_variables.items[index].name, "global"),
    )
  }
  for index in view.constant_order() {
    table.names.set(
      wgsl_ir_emit_name_key("const", index),
      namer.call_or(module_.constants.items[index].name, "const"),
    )
  }
  for index in view.override_order() {
    table.names.set(
      wgsl_ir_emit_name_key("override", index),
      namer.call_or(module_.overrides.items[index].name, "override"),
    )
  }
  for ep_index in 0..<module_.entry_points.length() {
    if view.should_emit_entry_point(ep_index) {
      view.allocate_entry_point_body_names(table, namer, ep_index)
    }
  }
  for fn_index in view.function_order() {
    view.allocate_function_body_names(table, namer, fn_index)
  }
  table
}

///|
fn WgslIrNagaCompatView::allocate_type_name(
  self : WgslIrNagaCompatView,
  table : WgslIrEmitNameTable,
  namer : WgslIrNagaNamer,
  index : Int,
) -> Unit {
  let ty = self.shader_module.types.items[index]
  let raw = match ty.name {
    Some(name) => name
    None => "type"
  }
  table.names.set(wgsl_ir_emit_name_key("type", index), namer.call(raw))
  match ty.inner {
    Struct(members, _) | PredeclaredStruct(members, _) => {
      let member_namer = WgslIrNagaNamer::WgslIrNagaNamer()
      for member_index in 0..<members.length() {
        let raw = match members[member_index].name {
          Some(name) => name
          None => "member"
        }
        table.names.set(
          wgsl_ir_emit_name_key2("member", index, member_index),
          member_namer.call(raw),
        )
      }
    }
    _ => ()
  }
}

///|
fn WgslIrNagaCompatView::allocate_entry_point_signature_names(
  self : WgslIrNagaCompatView,
  table : WgslIrEmitNameTable,
  namer : WgslIrNagaNamer,
  ep_index : Int,
) -> Unit {
  let ep = self.shader_module.entry_points[ep_index]
  table.names.set(wgsl_ir_emit_name_key("ep", ep_index), namer.call(ep.name))
  for arg_index in 0..<ep.function.arguments.length() {
    table.names.set(
      wgsl_ir_emit_name_key2("ep_arg", ep_index, arg_index),
      namer.call_or(ep.function.arguments[arg_index].name, "param"),
    )
  }
}

///|
fn WgslIrNagaCompatView::allocate_function_signature_names(
  self : WgslIrNagaCompatView,
  table : WgslIrEmitNameTable,
  namer : WgslIrNagaNamer,
  fn_index : Int,
) -> Unit {
  let function = self.shader_module.functions.items[fn_index]
  table.names.set(
    wgsl_ir_emit_name_key("fn", fn_index),
    namer.call_or(function.name, "function"),
  )
  for arg_index in 0..<function.arguments.length() {
    table.names.set(
      wgsl_ir_emit_name_key2("fn_arg", fn_index, arg_index),
      namer.call_or(function.arguments[arg_index].name, "param"),
    )
  }
}

///|
fn WgslIrNagaCompatView::allocate_entry_point_body_names(
  self : WgslIrNagaCompatView,
  table : WgslIrEmitNameTable,
  namer : WgslIrNagaNamer,
  ep_index : Int,
) -> Unit {
  let ep = self.shader_module.entry_points[ep_index]
  let temp_namer = WgslIrNagaNamer::WgslIrNagaNamer()
  for local_index in 0..<ep.function.local_variables.items.length() {
    table.names.set(
      wgsl_ir_emit_name_key2("ep_local", ep_index, local_index),
      namer.local_call_or(
        temp_namer,
        ep.function.local_variables.items[local_index].name,
        "local",
      ),
    )
  }
  for expr_index in 0..<ep.function.expressions.items.length() {
    match ep.function.expressions.items.get(expr_index) {
      Some(CallResult(_)) => {
        let semantic_index = wgsl_ir_emit_call_result_expression_index(
          ep.function,
          Handle::Handle(expr_index),
        )
        table.names.set(
          wgsl_ir_emit_name_key2("ep_expr", ep_index, expr_index),
          temp_namer.call("_e\{semantic_index}"),
        )
      }
      _ => ()
    }
  }
}

///|
fn WgslIrNagaCompatView::allocate_function_body_names(
  self : WgslIrNagaCompatView,
  table : WgslIrEmitNameTable,
  namer : WgslIrNagaNamer,
  fn_index : Int,
) -> Unit {
  let function = self.shader_module.functions.items[fn_index]
  let temp_namer = WgslIrNagaNamer::WgslIrNagaNamer()
  for local_index in 0..<function.local_variables.items.length() {
    table.names.set(
      wgsl_ir_emit_name_key2("fn_local", fn_index, local_index),
      namer.local_call_or(
        temp_namer,
        function.local_variables.items[local_index].name,
        "local",
      ),
    )
  }
  for expr_index in 0..<function.expressions.items.length() {
    match function.expressions.items.get(expr_index) {
      Some(CallResult(_)) => {
        let semantic_index = wgsl_ir_emit_call_result_expression_index(
          function,
          Handle::Handle(expr_index),
        )
        table.names.set(
          wgsl_ir_emit_name_key2("fn_expr", fn_index, expr_index),
          temp_namer.call("_e\{semantic_index}"),
        )
      }
      _ => ()
    }
  }
}

///|
fn WgslIrNagaCompatView::type_order(self : WgslIrNagaCompatView) -> Array[Int] {
  wgsl_ir_naga_compat_source_order_from_slots(self.declarations.types)
}

///|
fn WgslIrNagaCompatView::constant_order(
  self : WgslIrNagaCompatView,
) -> Array[Int] {
  wgsl_ir_naga_compat_source_order_from_slots(self.declarations.constants)
}

///|
fn WgslIrNagaCompatView::override_order(
  self : WgslIrNagaCompatView,
) -> Array[Int] {
  wgsl_ir_naga_compat_source_order_from_slots(self.declarations.overrides)
}

///|
fn WgslIrNagaCompatView::global_variable_order(
  self : WgslIrNagaCompatView,
) -> Array[Int] {
  wgsl_ir_naga_compat_source_order_from_slots(
    self.declarations.global_variables,
  )
}

///|
fn WgslIrNagaCompatView::function_order(
  self : WgslIrNagaCompatView,
) -> Array[Int] {
  wgsl_ir_naga_compat_source_order_from_slots(self.declarations.functions)
}

///|
fn wgsl_ir_naga_compat_declaration_slots(
  source_order : Array[Int],
) -> Array[WgslIrNagaCompatDeclarationSlot] {
  let slots : Array[WgslIrNagaCompatDeclarationSlot] = []
  for naga_index in 0..<source_order.length() {
    slots.push(WgslIrNagaCompatDeclarationSlot::{
      source_index: source_order[naga_index],
      naga_index,
    })
  }
  slots
}

///|
fn wgsl_ir_naga_compat_source_order_from_slots(
  slots : Array[WgslIrNagaCompatDeclarationSlot],
) -> Array[Int] {
  let order : Array[Int] = []
  for slot in slots {
    if slot.naga_index != order.length() {
      abort("invalid Naga-compatible declaration slot order")
    }
    order.push(slot.source_index)
  }
  order
}

///|
fn wgsl_ir_source_order_indices(length : Int) -> Array[Int] {
  let order : Array[Int] = []
  for index in 0..<length {
    order.push(index)
  }
  order
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
