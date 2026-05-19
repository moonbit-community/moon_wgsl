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
  type_order : Array[Int]
  constant_order : Array[Int]
  override_order : Array[Int]
  global_variable_order : Array[Int]
  function_order : Array[Int]
  mut names : WgslIrEmitNameTable
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
    type_order: planner.type_order(),
    constant_order: planner.constant_order(),
    override_order: planner.override_order(),
    global_variable_order: planner.global_variable_order(),
    function_order: planner.function_order(),
    names: WgslIrEmitNameTable::empty(),
  }
  view.names = build_wgsl_ir_emit_name_table_for_naga_compat_view(view)
  view
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
fn wgsl_ir_source_order_indices(length : Int) -> Array[Int] {
  let order : Array[Int] = []
  for index in 0..<length {
    order.push(index)
  }
  order
}
