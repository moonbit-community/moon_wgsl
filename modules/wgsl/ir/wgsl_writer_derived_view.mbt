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
priv struct WgslIrDerivedModuleView {
  types : Array[Int]
  constants : Array[Int]
  overrides : Array[Int]
  global_variables : Array[Int]
  functions : Array[Int]
}

///|
priv struct WgslIrDerivedModuleBuilder {
  planner : WgslIrWriterPlanner
  view : WgslIrDerivedModuleView
  seen_types : @set.Set[Int]
  seen_constants : @set.Set[Int]
  seen_overrides : @set.Set[Int]
  seen_globals : @set.Set[Int]
  seen_functions : @set.Set[Int]
}

///|
fn WgslIrWriterPlanner::derived_module_view(
  self : WgslIrWriterPlanner,
) -> WgslIrDerivedModuleView {
  let builder = WgslIrDerivedModuleBuilder::{
    planner: self,
    view: {
      types: [],
      constants: [],
      overrides: [],
      global_variables: [],
      functions: [],
    },
    seen_types: Set([]),
    seen_constants: Set([]),
    seen_overrides: Set([]),
    seen_globals: Set([]),
    seen_functions: Set([]),
  }
  for event in self.shader_module.import_arena_events {
    builder.import_event(event)
  }
  builder.append_remaining()
  builder.import_entry_points()
  builder.view
}

///|
fn WgslIrDerivedModuleBuilder::import_event(
  self : WgslIrDerivedModuleBuilder,
  event : WgslIrImportArenaEvent,
) -> Unit {
  let symbols = event.generated_symbols()
  let item_names = event.item_names()
  match event.kind() {
    ItemBinding => {
      self.import_event_symbols_by_kind(symbols, Some(item_names), Type)
      self.import_event_symbols_by_kind(symbols, Some(item_names), Constant)
      self.import_event_symbols_by_kind(symbols, Some(item_names), Override)
      self.import_event_symbols_by_kind(
        symbols,
        Some(item_names),
        GlobalVariable,
      )
      self.import_event_symbols_by_kind(symbols, Some(item_names), Function)
    }
    FullModule | AliasModule => {
      self.import_event_symbols_by_kind(symbols, None, Type)
      self.import_full_module_constant_event_symbols(symbols)
      self.import_event_symbols_by_kind(symbols, None, Override)
      self.import_event_symbols_by_kind(symbols, None, GlobalVariable)
      self.import_event_symbols_by_kind(symbols, None, Function)
    }
  }
}

///|
fn WgslIrDerivedModuleBuilder::import_full_module_constant_event_symbols(
  self : WgslIrDerivedModuleBuilder,
  symbols : Array[WgslIrImportArenaSymbol],
) -> Unit {
  for symbol in symbols {
    if symbol.kind() == Constant {
      let name = symbol.generated_symbol_name()
      if self.full_module_generated_constant_should_be_rooted(name) {
        self.import_named_constant_if_present(name)
      } else {
        self.import_named_non_generated_constant_if_present(name)
      }
    }
  }
}

///|
fn WgslIrDerivedModuleBuilder::full_module_generated_constant_should_be_rooted(
  self : WgslIrDerivedModuleBuilder,
  name : String,
) -> Bool {
  match self.planner.shader_module.generated_import_provenance.get(name) {
    Some(provenance) =>
      provenance.kind == ImportedSourceSymbol &&
      (
        provenance.local_spelling ||
        provenance.root_local_spelling ||
        provenance.inline_value
      )
    None => false
  }
}

///|
fn WgslIrDerivedModuleBuilder::import_event_symbols_by_kind(
  self : WgslIrDerivedModuleBuilder,
  symbols : Array[WgslIrImportArenaSymbol],
  item_names : Array[String]?,
  kind : WgslIrDeclarationKind,
) -> Unit {
  let selected_symbols : Array[WgslIrImportArenaSymbol] = []
  for symbol in symbols {
    if symbol.kind() != kind {
      continue
    }
    match item_names {
      Some(names) =>
        if !names.contains(symbol.source_symbol_name()) {
          continue
        }
      None => ()
    }
    selected_symbols.push(symbol)
  }
  if kind == Function {
    selected_symbols.sort_by(wgsl_ir_writer_compare_import_arena_symbols)
  }
  for symbol in selected_symbols {
    self.import_symbol(symbol)
  }
}

///|
fn wgsl_ir_writer_compare_import_arena_symbols(
  lhs : WgslIrImportArenaSymbol,
  rhs : WgslIrImportArenaSymbol,
) -> Int {
  let lhs_rank = lhs.source_order_rank()
  let rhs_rank = rhs.source_order_rank()
  if lhs_rank >= 0 && rhs_rank >= 0 && lhs_rank != rhs_rank {
    return lhs_rank - rhs_rank
  }
  let lhs_decl_rank = lhs.source_decl_rank()
  let rhs_decl_rank = rhs.source_decl_rank()
  if lhs_rank >= 0 && rhs_rank >= 0 && lhs_decl_rank != rhs_decl_rank {
    return lhs_decl_rank - rhs_decl_rank
  }
  if lhs_rank >= 0 && rhs_decl_rank >= 0 && lhs_rank != rhs_decl_rank {
    return lhs_rank - rhs_decl_rank
  }
  if rhs_rank >= 0 && lhs_decl_rank >= 0 && lhs_decl_rank != rhs_rank {
    return lhs_decl_rank - rhs_rank
  }
  0
}

///|
fn WgslIrDerivedModuleBuilder::import_symbol(
  self : WgslIrDerivedModuleBuilder,
  symbol : WgslIrImportArenaSymbol,
) -> Unit {
  let name = symbol.generated_symbol_name()
  match symbol.kind() {
    Type => self.import_named_type_if_present(name)
    Constant => self.import_named_constant_if_present(name)
    Override => self.import_named_override_if_present(name)
    GlobalVariable => self.import_named_global_if_present(name)
    Function => self.import_named_function_if_present(name)
  }
}

///|
fn WgslIrDerivedModuleBuilder::append_remaining(
  self : WgslIrDerivedModuleBuilder,
) -> Unit {
  for index in 0..<self.planner.shader_module.types.items.length() {
    self.import_type(index)
  }
  for index in 0..<self.planner.shader_module.constants.items.length() {
    if self.planner.shader_module.constants.items[index].generated_import {
      continue
    }
    self.import_constant(index)
  }
  for index in 0..<self.planner.shader_module.overrides.items.length() {
    self.import_override(index)
  }
  for index in 0..<self.planner.shader_module.global_variables.items.length() {
    self.import_global(index)
  }
  for index in self.planner.function_order() {
    self.import_function(index)
  }
}

///|
fn WgslIrDerivedModuleBuilder::import_named_type_if_present(
  self : WgslIrDerivedModuleBuilder,
  name : String,
) -> Unit {
  for index in 0..<self.planner.shader_module.types.items.length() {
    if self.seen_types.contains(index) {
      continue
    }
    match self.planner.shader_module.types.items[index].name {
      Some(type_name) if type_name == name => {
        self.import_type(index)
        return
      }
      _ => ()
    }
  }
}

///|
fn WgslIrDerivedModuleBuilder::import_named_constant_if_present(
  self : WgslIrDerivedModuleBuilder,
  name : String,
) -> Unit {
  for index in 0..<self.planner.shader_module.constants.items.length() {
    if self.seen_constants.contains(index) {
      continue
    }
    match self.planner.shader_module.constants.items[index].name {
      Some(constant_name) if constant_name == name => {
        self.import_constant(index)
        return
      }
      _ => ()
    }
  }
}

///|
fn WgslIrDerivedModuleBuilder::import_named_non_generated_constant_if_present(
  self : WgslIrDerivedModuleBuilder,
  name : String,
) -> Unit {
  for index in 0..<self.planner.shader_module.constants.items.length() {
    if self.seen_constants.contains(index) {
      continue
    }
    match self.planner.shader_module.constants.items[index] {
      { name: Some(constant_name), generated_import: false, .. } if constant_name ==
        name => {
        self.import_constant(index)
        return
      }
      _ => ()
    }
  }
}

///|
fn WgslIrDerivedModuleBuilder::import_named_override_if_present(
  self : WgslIrDerivedModuleBuilder,
  name : String,
) -> Unit {
  for index in 0..<self.planner.shader_module.overrides.items.length() {
    if self.seen_overrides.contains(index) {
      continue
    }
    match self.planner.shader_module.overrides.items[index].name {
      Some(override_name) if override_name == name => {
        self.import_override(index)
        return
      }
      _ => ()
    }
  }
}

///|
fn WgslIrDerivedModuleBuilder::import_named_global_if_present(
  self : WgslIrDerivedModuleBuilder,
  name : String,
) -> Unit {
  for index in 0..<self.planner.shader_module.global_variables.items.length() {
    if self.seen_globals.contains(index) {
      continue
    }
    match self.planner.shader_module.global_variables.items[index].name {
      Some(global_name) if global_name == name => {
        self.import_global(index)
        return
      }
      _ => ()
    }
  }
}

///|
fn WgslIrDerivedModuleBuilder::import_named_function_if_present(
  self : WgslIrDerivedModuleBuilder,
  name : String,
) -> Unit {
  for index in 0..<self.planner.shader_module.functions.items.length() {
    if self.seen_functions.contains(index) {
      continue
    }
    match self.planner.shader_module.functions.items[index].name {
      Some(function_name) =>
        if function_name == name &&
          self.planner.function_order_should_include(index, self.view.functions) {
          self.import_function(index)
          return
        }
      _ => ()
    }
  }
}

///|
fn WgslIrDerivedModuleBuilder::import_type(
  self : WgslIrDerivedModuleBuilder,
  index : Int,
) -> Unit {
  if self.seen_types.contains(index) || !self.should_emit_type(index) {
    return
  }
  match self.planner.shader_module.types.items.get(index) {
    Some(ty) => {
      self.import_type_inner_dependencies(ty.inner)
      self.seen_types.add(index)
      self.view.types.push(index)
    }
    None => ()
  }
}

///|
fn WgslIrDerivedModuleBuilder::import_type_handle(
  self : WgslIrDerivedModuleBuilder,
  handle : Handle,
) -> Unit {
  self.import_type(handle.index())
}

///|
fn WgslIrDerivedModuleBuilder::import_type_inner_dependencies(
  self : WgslIrDerivedModuleBuilder,
  inner : TypeInner,
) -> Unit {
  match inner {
    Pointer(base, _) => self.import_type_handle(base)
    Array(base, size, _) | BindingArray(base, size) => {
      self.import_type_handle(base)
      self.import_array_size(size)
    }
    Struct(members, _) | PredeclaredStruct(members, _) =>
      for field in members {
        self.import_type_handle(field.ty)
      }
    Atomic(_)
    | Scalar(_)
    | Vector(_, _)
    | Matrix(_, _, _)
    | CooperativeMatrix(_, _, _, _)
    | ValuePointer(_, _, _)
    | Image(_, _, _)
    | Sampler(_)
    | AccelerationStructure(_)
    | RayQuery(_) => ()
  }
}

///|
fn WgslIrDerivedModuleBuilder::import_array_size(
  self : WgslIrDerivedModuleBuilder,
  size : ArraySize,
) -> Unit {
  match size {
    Pending(handle) => self.import_global_expression(handle)
    Constant(_) | Dynamic => ()
  }
}

///|
fn WgslIrDerivedModuleBuilder::import_constant(
  self : WgslIrDerivedModuleBuilder,
  index : Int,
) -> Unit {
  if self.seen_constants.contains(index) || !self.should_emit_constant(index) {
    return
  }
  match self.planner.shader_module.constants.items.get(index) {
    Some(constant) => {
      self.import_type_handle(constant.ty)
      self.seen_constants.add(index)
      self.view.constants.push(index)
      self.import_global_expression(constant.init)
    }
    None => ()
  }
}

///|
fn WgslIrDerivedModuleBuilder::import_override(
  self : WgslIrDerivedModuleBuilder,
  index : Int,
) -> Unit {
  if self.seen_overrides.contains(index) || !self.should_emit_override(index) {
    return
  }
  match self.planner.shader_module.overrides.items.get(index) {
    Some(override_) => {
      self.import_type_handle(override_.ty)
      match override_.init {
        Some(init) => self.import_global_expression(init)
        None => ()
      }
      self.seen_overrides.add(index)
      self.view.overrides.push(index)
    }
    None => ()
  }
}

///|
fn WgslIrDerivedModuleBuilder::import_global(
  self : WgslIrDerivedModuleBuilder,
  index : Int,
) -> Unit {
  if self.seen_globals.contains(index) || !self.should_emit_global(index) {
    return
  }
  match self.planner.shader_module.global_variables.items.get(index) {
    Some(global) => {
      self.import_type_handle(global.ty)
      match global.init {
        Some(init) => self.import_global_expression(init)
        None => ()
      }
      self.seen_globals.add(index)
      self.view.global_variables.push(index)
    }
    None => ()
  }
}

///|
fn WgslIrDerivedModuleBuilder::import_function(
  self : WgslIrDerivedModuleBuilder,
  index : Int,
) -> Unit {
  if self.seen_functions.contains(index) ||
    !self.planner.function_order_should_include(index, self.view.functions) {
    return
  }
  let visiting : Array[Int] = []
  self.import_function_inner(index, visiting)
}

///|
fn WgslIrDerivedModuleBuilder::should_emit_type(
  self : WgslIrDerivedModuleBuilder,
  index : Int,
) -> Bool {
  match self.planner.filter {
    Some(filter) => filter.contains_type(index)
    None => true
  }
}

///|
fn WgslIrDerivedModuleBuilder::should_emit_constant(
  self : WgslIrDerivedModuleBuilder,
  index : Int,
) -> Bool {
  match self.planner.filter {
    Some(filter) => filter.contains_constant(index)
    None => true
  }
}

///|
fn WgslIrDerivedModuleBuilder::should_emit_override(
  self : WgslIrDerivedModuleBuilder,
  index : Int,
) -> Bool {
  match self.planner.filter {
    Some(filter) => filter.contains_override(index)
    None => true
  }
}

///|
fn WgslIrDerivedModuleBuilder::should_emit_global(
  self : WgslIrDerivedModuleBuilder,
  index : Int,
) -> Bool {
  match self.planner.filter {
    Some(filter) => filter.contains_global_variable(index)
    None => true
  }
}

///|
fn WgslIrDerivedModuleBuilder::import_function_inner(
  self : WgslIrDerivedModuleBuilder,
  index : Int,
  visiting : Array[Int],
) -> Unit {
  if self.seen_functions.contains(index) ||
    visiting.contains(index) ||
    !self.planner.function_order_should_include(index, self.view.functions) {
    return
  }
  visiting.push(index)
  match self.planner.shader_module.functions.items.get(index) {
    Some(function) => {
      for argument in function.arguments {
        self.import_type_handle(argument.ty)
      }
      match function.result {
        Some(result) => self.import_type_handle(result.ty)
        None => ()
      }
      for local_var in function.local_variables.items {
        self.import_type_handle(local_var.ty)
      }
      self.import_function_block(function, function.body, visiting)
      self.seen_functions.add(index)
      self.view.functions.push(index)
    }
    None => ()
  }
  visiting.pop() |> ignore
}

///|
fn WgslIrDerivedModuleBuilder::import_entry_points(
  self : WgslIrDerivedModuleBuilder,
) -> Unit {
  for index in 0..<self.planner.shader_module.entry_points.length() {
    match self.planner.filter {
      Some(filter) => if !filter.contains_entry_point(index) { continue }
      None => ()
    }
    self.import_entry_point(self.planner.shader_module.entry_points[index])
  }
}

///|
fn WgslIrDerivedModuleBuilder::import_entry_point(
  self : WgslIrDerivedModuleBuilder,
  entry_point : EntryPoint,
) -> Unit {
  let visiting : Array[Int] = []
  for argument in entry_point.function.arguments {
    self.import_type_handle(argument.ty)
  }
  match entry_point.function.result {
    Some(result) => self.import_type_handle(result.ty)
    None => ()
  }
  for local_var in entry_point.function.local_variables.items {
    self.import_type_handle(local_var.ty)
  }
  match entry_point.workgroup_size_overrides {
    Some(overrides) =>
      for item in overrides {
        match item {
          Some(expr) => self.import_global_expression(expr)
          None => ()
        }
      }
    None => ()
  }
  match entry_point.mesh_info {
    Some(mesh_info) => {
      match mesh_info.max_vertices_override {
        Some(expr) => self.import_global_expression(expr)
        None => ()
      }
      match mesh_info.max_primitives_override {
        Some(expr) => self.import_global_expression(expr)
        None => ()
      }
      self.import_type_handle(mesh_info.vertex_output_type)
      self.import_type_handle(mesh_info.primitive_output_type)
      self.import_global(mesh_info.output_variable.index())
    }
    None => ()
  }
  match entry_point.task_payload {
    Some(handle) => self.import_global(handle.index())
    None => ()
  }
  match entry_point.incoming_ray_payload {
    Some(handle) => self.import_global(handle.index())
    None => ()
  }
  self.import_function_block(
    entry_point.function,
    entry_point.function.body,
    visiting,
  )
}

///|
fn WgslIrDerivedModuleBuilder::import_global_expression(
  self : WgslIrDerivedModuleBuilder,
  handle : Handle,
) -> Unit {
  match
    self.planner.shader_module.global_expressions.items.get(handle.index()) {
    Some(expression) => self.import_expression(expression, None, [])
    None => ()
  }
}

///|
fn WgslIrDerivedModuleBuilder::import_function_expression(
  self : WgslIrDerivedModuleBuilder,
  function : Function,
  handle : Handle,
  visiting_functions : Array[Int],
) -> Unit {
  match function.expressions.items.get(handle.index()) {
    Some(expression) =>
      self.import_expression(expression, Some(function), visiting_functions)
    None => ()
  }
}

///|
fn WgslIrDerivedModuleBuilder::import_optional_function_expression(
  self : WgslIrDerivedModuleBuilder,
  function : Function,
  handle : Handle?,
  visiting_functions : Array[Int],
) -> Unit {
  match handle {
    Some(value) =>
      self.import_function_expression(function, value, visiting_functions)
    None => ()
  }
}

///|
fn WgslIrDerivedModuleBuilder::import_function_block(
  self : WgslIrDerivedModuleBuilder,
  function : Function,
  block : Block,
  visiting_functions : Array[Int],
) -> Unit {
  for statement in block.statements {
    self.import_statement(function, statement, visiting_functions)
  }
}

///|
fn WgslIrDerivedModuleBuilder::import_statement(
  self : WgslIrDerivedModuleBuilder,
  function : Function,
  statement : Statement,
  visiting_functions : Array[Int],
) -> Unit {
  match statement {
    Emit(range) => {
      let mut index = range.start.index()
      while index <= range.end.index() {
        self.import_function_expression(
          function,
          Handle(index),
          visiting_functions,
        )
        index = index + 1
      }
    }
    Phony(handle) =>
      self.import_function_expression(function, handle, visiting_functions)
    Block(nested) =>
      self.import_function_block(function, nested, visiting_functions)
    If(condition, accept, reject) => {
      self.import_function_expression(function, condition, visiting_functions)
      self.import_function_block(function, accept, visiting_functions)
      self.import_function_block(function, reject, visiting_functions)
    }
    Switch(selector, cases) => {
      self.import_function_expression(function, selector, visiting_functions)
      for case in cases {
        for dependency in case.constant_dependencies {
          self.import_constant(dependency.index())
        }
        self.import_function_block(function, case.body, visiting_functions)
      }
    }
    Loop(body, continuing, break_if) => {
      self.import_function_block(function, body, visiting_functions)
      self.import_function_block(function, continuing, visiting_functions)
      self.import_optional_function_expression(
        function, break_if, visiting_functions,
      )
    }
    Return(value) =>
      self.import_optional_function_expression(
        function, value, visiting_functions,
      )
    ConstAssert(expr) =>
      self.import_function_expression(function, expr, visiting_functions)
    Store(pointer, value) => {
      self.import_function_expression(function, pointer, visiting_functions)
      self.import_function_expression(function, value, visiting_functions)
    }
    ImageStore(image, coordinate, array_index, value) => {
      self.import_function_expression(function, image, visiting_functions)
      self.import_function_expression(function, coordinate, visiting_functions)
      self.import_optional_function_expression(
        function, array_index, visiting_functions,
      )
      self.import_function_expression(function, value, visiting_functions)
    }
    Atomic(pointer, _, value, compare, result) => {
      self.import_function_expression(function, pointer, visiting_functions)
      self.import_function_expression(function, value, visiting_functions)
      self.import_optional_function_expression(
        function, compare, visiting_functions,
      )
      self.import_optional_function_expression(
        function, result, visiting_functions,
      )
    }
    ImageAtomic(image, coordinate, array_index, _, value) => {
      self.import_function_expression(function, image, visiting_functions)
      self.import_function_expression(function, coordinate, visiting_functions)
      self.import_optional_function_expression(
        function, array_index, visiting_functions,
      )
      self.import_function_expression(function, value, visiting_functions)
    }
    WorkGroupUniformLoad(pointer, result) => {
      self.import_function_expression(function, pointer, visiting_functions)
      self.import_function_expression(function, result, visiting_functions)
    }
    Call(callee, arguments, result) => {
      for argument in arguments {
        self.import_function_expression(function, argument, visiting_functions)
      }
      self.import_optional_function_expression(
        function, result, visiting_functions,
      )
      self.import_function_inner(callee.index(), visiting_functions)
    }
    RayQuery(query, action) => {
      self.import_function_expression(function, query, visiting_functions)
      match action {
        Initialize(a, b) => {
          self.import_function_expression(function, a, visiting_functions)
          self.import_function_expression(function, b, visiting_functions)
        }
        GenerateIntersection(value) =>
          self.import_function_expression(function, value, visiting_functions)
        Proceed(value) =>
          self.import_function_expression(function, value, visiting_functions)
        ConfirmIntersection | Terminate => ()
      }
    }
    RayPipelineFunction(TraceRay(a, b, c)) => {
      self.import_function_expression(function, a, visiting_functions)
      self.import_function_expression(function, b, visiting_functions)
      self.import_function_expression(function, c, visiting_functions)
    }
    SubgroupBallot(value, result) => {
      self.import_function_expression(function, value, visiting_functions)
      self.import_optional_function_expression(
        function, result, visiting_functions,
      )
    }
    SubgroupGather(_, value, result)
    | SubgroupCollectiveOperation(_, _, value, result) => {
      self.import_function_expression(function, value, visiting_functions)
      self.import_function_expression(function, result, visiting_functions)
    }
    CooperativeStore(pointer, data) => {
      self.import_function_expression(function, pointer, visiting_functions)
      self.import_cooperative_data(function, data, visiting_functions)
    }
    Declare(handle) =>
      self.import_local_variable_declaration(
        function, handle, visiting_functions,
      )
    Break
    | Continue
    | ImplicitReturn
    | Kill
    | ControlBarrier(_)
    | MemoryBarrier(_) => ()
  }
}

///|
fn WgslIrDerivedModuleBuilder::import_local_variable_declaration(
  self : WgslIrDerivedModuleBuilder,
  function : Function,
  handle : Handle,
  visiting_functions : Array[Int],
) -> Unit {
  match function.local_variables.items.get(handle.index()) {
    Some(local_var) => {
      self.import_type_handle(local_var.ty)
      match local_var.init {
        Some(init) =>
          self.import_function_expression(function, init, visiting_functions)
        None => ()
      }
    }
    None => ()
  }
}

///|
fn WgslIrDerivedModuleBuilder::import_expression(
  self : WgslIrDerivedModuleBuilder,
  expression : Expression,
  function : Function?,
  visiting_functions : Array[Int],
) -> Unit {
  match expression {
    Constant(handle) => self.import_constant(handle.index())
    Override(handle) => self.import_override(handle.index())
    GlobalVariable(handle) => self.import_global(handle.index())
    ZeroValue(ty) => self.import_type_handle(ty)
    Compose(ty, components) => {
      self.import_type_handle(ty)
      for component in components {
        self.import_child_expression(function, component, visiting_functions)
      }
    }
    Access(base, index) | Binary(_, base, index) => {
      self.import_child_expression(function, base, visiting_functions)
      self.import_child_expression(function, index, visiting_functions)
    }
    AccessIndex(base, _)
    | Component(base, _)
    | Load(base)
    | Unary(_, base)
    | As(base, _, _)
    | Relational(_, base)
    | ArrayLength(base)
    | WorkGroupUniformLoad(base)
    | Splat(_, base)
    | Swizzle(_, base, _)
    | Derivative(_, _, base)
    | WorkGroupUniformLoadResult(base)
    | RayQueryProceed(base)
    | RayQueryConfirmIntersection(base)
    | RayQueryTerminate(base)
    | RayQueryGetIntersection(base, _) =>
      self.import_child_expression(function, base, visiting_functions)
    AtomicResult(_, _) => ()
    AddressOf(ty, target) | Bitcast(ty, target) => {
      self.import_type_handle(ty)
      self.import_child_expression(function, target, visiting_functions)
    }
    AtomicCall(_, arguments) | SubgroupCall(_, arguments) =>
      for argument in arguments {
        self.import_child_expression(function, argument, visiting_functions)
      }
    FunctionCall(target, arguments) => {
      for argument in arguments {
        self.import_child_expression(function, argument, visiting_functions)
      }
      self.import_function_inner(target.index(), visiting_functions)
    }
    Select(condition, accept, reject) => {
      self.import_child_expression(function, condition, visiting_functions)
      self.import_child_expression(function, accept, visiting_functions)
      self.import_child_expression(function, reject, visiting_functions)
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
      self.import_child_expression(function, image, visiting_functions)
      self.import_child_expression(function, sampler, visiting_functions)
      self.import_child_expression(function, coordinate, visiting_functions)
      self.import_optional_child_expression(
        function, array_index, visiting_functions,
      )
      self.import_optional_child_expression(
        function, offset, visiting_functions,
      )
      self.import_sample_level(function, level, visiting_functions)
      self.import_optional_child_expression(
        function, depth_ref, visiting_functions,
      )
    }
    ImageLoad(image, coordinate, array_index, sample, level) => {
      self.import_child_expression(function, image, visiting_functions)
      self.import_child_expression(function, coordinate, visiting_functions)
      self.import_optional_child_expression(
        function, array_index, visiting_functions,
      )
      self.import_optional_child_expression(
        function, sample, visiting_functions,
      )
      self.import_optional_child_expression(function, level, visiting_functions)
    }
    ImageQuery(image, query) => {
      self.import_child_expression(function, image, visiting_functions)
      match query {
        Size(level) =>
          self.import_optional_child_expression(
            function, level, visiting_functions,
          )
        _ => ()
      }
    }
    Math(_, a, b, c, d) => {
      self.import_child_expression(function, a, visiting_functions)
      self.import_optional_child_expression(function, b, visiting_functions)
      self.import_optional_child_expression(function, c, visiting_functions)
      self.import_optional_child_expression(function, d, visiting_functions)
    }
    CallResult(target) =>
      self.import_function_inner(target.index(), visiting_functions)
    RayQueryInitialize(query, acceleration, ray_desc) => {
      self.import_child_expression(function, query, visiting_functions)
      self.import_child_expression(function, acceleration, visiting_functions)
      self.import_child_expression(function, ray_desc, visiting_functions)
    }
    RayQueryGenerateIntersection(query, intersection_t) => {
      self.import_child_expression(function, query, visiting_functions)
      self.import_child_expression(function, intersection_t, visiting_functions)
    }
    RayQueryVertexPositions(query, _) =>
      self.import_child_expression(function, query, visiting_functions)
    SubgroupOperationResult(handle) =>
      self.import_child_expression(function, handle, visiting_functions)
    CooperativeLoad(_, _, _, data) =>
      self.import_cooperative_data_for_optional_function(
        function, data, visiting_functions,
      )
    CooperativeMultiplyAdd(a, b, c) => {
      self.import_child_expression(function, a, visiting_functions)
      self.import_child_expression(function, b, visiting_functions)
      self.import_child_expression(function, c, visiting_functions)
    }
    Literal(_)
    | FunctionArgument(_)
    | LocalVariable(_)
    | RayQueryProceedResult
    | SubgroupBallotResult => ()
  }
}

///|
fn WgslIrDerivedModuleBuilder::import_child_expression(
  self : WgslIrDerivedModuleBuilder,
  function : Function?,
  handle : Handle,
  visiting_functions : Array[Int],
) -> Unit {
  match function {
    Some(value) =>
      self.import_function_expression(value, handle, visiting_functions)
    None => self.import_global_expression(handle)
  }
}

///|
fn WgslIrDerivedModuleBuilder::import_optional_child_expression(
  self : WgslIrDerivedModuleBuilder,
  function : Function?,
  handle : Handle?,
  visiting_functions : Array[Int],
) -> Unit {
  match handle {
    Some(value) =>
      self.import_child_expression(function, value, visiting_functions)
    None => ()
  }
}

///|
fn WgslIrDerivedModuleBuilder::import_sample_level(
  self : WgslIrDerivedModuleBuilder,
  function : Function?,
  level : SampleLevel,
  visiting_functions : Array[Int],
) -> Unit {
  match level {
    Exact(handle) | Bias(handle) =>
      self.import_child_expression(function, handle, visiting_functions)
    Gradient(x, y) => {
      self.import_child_expression(function, x, visiting_functions)
      self.import_child_expression(function, y, visiting_functions)
    }
    Auto | Zero => ()
  }
}

///|
fn WgslIrDerivedModuleBuilder::import_cooperative_data(
  self : WgslIrDerivedModuleBuilder,
  function : Function,
  data : CooperativeData,
  visiting_functions : Array[Int],
) -> Unit {
  self.import_function_expression(function, data.pointer, visiting_functions)
  self.import_function_expression(function, data.stride, visiting_functions)
}

///|
fn WgslIrDerivedModuleBuilder::import_cooperative_data_for_optional_function(
  self : WgslIrDerivedModuleBuilder,
  function : Function?,
  data : CooperativeData,
  visiting_functions : Array[Int],
) -> Unit {
  self.import_child_expression(function, data.pointer, visiting_functions)
  self.import_child_expression(function, data.stride, visiting_functions)
}
