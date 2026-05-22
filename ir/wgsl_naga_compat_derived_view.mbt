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
priv struct WgslIrNagaDerivedModuleView {
  types : Array[Int]
  constants : Array[Int]
  overrides : Array[Int]
  global_variables : Array[Int]
  functions : Array[Int]
}

///|
fn WgslIrNagaCompatPlanner::derived_module_view(
  self : WgslIrNagaCompatPlanner,
) -> WgslIrNagaDerivedModuleView {
  let view = WgslIrNagaDerivedModuleView::{
    types: [],
    constants: [],
    overrides: [],
    global_variables: [],
    functions: [],
  }
  let seen_types = @set.Set([])
  let seen_constants = @set.Set([])
  let seen_overrides = @set.Set([])
  let seen_globals = @set.Set([])
  let seen_functions = @set.Set([])
  for event in self.shader_module.import_arena_events {
    for generated_symbol_name in event.generated_symbol_names() {
      self.push_named_type_if_present(
        view.types,
        seen_types,
        generated_symbol_name,
      )
      self.push_named_constant_if_present(
        view.constants,
        seen_constants,
        generated_symbol_name,
      )
      self.push_named_override_if_present(
        view.overrides,
        seen_overrides,
        generated_symbol_name,
      )
      self.push_named_global_if_present(
        view.global_variables,
        seen_globals,
        generated_symbol_name,
      )
      self.push_named_function_if_present(
        view.functions,
        seen_functions,
        generated_symbol_name,
      )
    }
  }
  self.append_remaining_type_indices(view.types, seen_types)
  self.append_remaining_constant_indices(view.constants, seen_constants)
  self.append_remaining_override_indices(view.overrides, seen_overrides)
  self.append_remaining_global_indices(view.global_variables, seen_globals)
  self.append_remaining_function_indices(view.functions, seen_functions)
  view
}

///|
fn WgslIrNagaCompatPlanner::push_named_type_if_present(
  self : WgslIrNagaCompatPlanner,
  order : Array[Int],
  seen : @set.Set[Int],
  name : String,
) -> Unit {
  for index in 0..<self.shader_module.types.items.length() {
    if seen.contains(index) {
      continue
    }
    match self.shader_module.types.items[index].name {
      Some(type_name) if type_name == name => {
        seen.add(index)
        order.push(index)
        return
      }
      _ => ()
    }
  }
}

///|
fn WgslIrNagaCompatPlanner::push_named_constant_if_present(
  self : WgslIrNagaCompatPlanner,
  order : Array[Int],
  seen : @set.Set[Int],
  name : String,
) -> Unit {
  for index in 0..<self.shader_module.constants.items.length() {
    if seen.contains(index) {
      continue
    }
    match self.shader_module.constants.items[index].name {
      Some(constant_name) if constant_name == name => {
        seen.add(index)
        order.push(index)
        return
      }
      _ => ()
    }
  }
}

///|
fn WgslIrNagaCompatPlanner::push_named_override_if_present(
  self : WgslIrNagaCompatPlanner,
  order : Array[Int],
  seen : @set.Set[Int],
  name : String,
) -> Unit {
  for index in 0..<self.shader_module.overrides.items.length() {
    if seen.contains(index) {
      continue
    }
    match self.shader_module.overrides.items[index].name {
      Some(override_name) if override_name == name => {
        seen.add(index)
        order.push(index)
        return
      }
      _ => ()
    }
  }
}

///|
fn WgslIrNagaCompatPlanner::push_named_global_if_present(
  self : WgslIrNagaCompatPlanner,
  order : Array[Int],
  seen : @set.Set[Int],
  name : String,
) -> Unit {
  for index in 0..<self.shader_module.global_variables.items.length() {
    if seen.contains(index) {
      continue
    }
    match self.shader_module.global_variables.items[index].name {
      Some(global_name) if global_name == name => {
        seen.add(index)
        order.push(index)
        return
      }
      _ => ()
    }
  }
}

///|
fn WgslIrNagaCompatPlanner::push_named_function_if_present(
  self : WgslIrNagaCompatPlanner,
  order : Array[Int],
  seen : @set.Set[Int],
  name : String,
) -> Unit {
  for index in 0..<self.shader_module.functions.items.length() {
    if seen.contains(index) {
      continue
    }
    match self.shader_module.functions.items[index].name {
      Some(function_name) =>
        if function_name == name &&
          self.function_order_should_include(index, order) {
          seen.add(index)
          order.push(index)
          return
        }
      _ => ()
    }
  }
}

///|
fn WgslIrNagaCompatPlanner::append_remaining_type_indices(
  self : WgslIrNagaCompatPlanner,
  order : Array[Int],
  seen : @set.Set[Int],
) -> Unit {
  for index in 0..<self.shader_module.types.items.length() {
    if !seen.contains(index) {
      seen.add(index)
      order.push(index)
    }
  }
}

///|
fn WgslIrNagaCompatPlanner::append_remaining_constant_indices(
  self : WgslIrNagaCompatPlanner,
  order : Array[Int],
  seen : @set.Set[Int],
) -> Unit {
  for index in 0..<self.shader_module.constants.items.length() {
    if !seen.contains(index) {
      seen.add(index)
      order.push(index)
    }
  }
}

///|
fn WgslIrNagaCompatPlanner::append_remaining_override_indices(
  self : WgslIrNagaCompatPlanner,
  order : Array[Int],
  seen : @set.Set[Int],
) -> Unit {
  for index in 0..<self.shader_module.overrides.items.length() {
    if !seen.contains(index) {
      seen.add(index)
      order.push(index)
    }
  }
}

///|
fn WgslIrNagaCompatPlanner::append_remaining_global_indices(
  self : WgslIrNagaCompatPlanner,
  order : Array[Int],
  seen : @set.Set[Int],
) -> Unit {
  for index in 0..<self.shader_module.global_variables.items.length() {
    if !seen.contains(index) {
      seen.add(index)
      order.push(index)
    }
  }
}

///|
fn WgslIrNagaCompatPlanner::append_remaining_function_indices(
  self : WgslIrNagaCompatPlanner,
  order : Array[Int],
  seen : @set.Set[Int],
) -> Unit {
  for index in 0..<self.shader_module.functions.items.length() {
    if !seen.contains(index) && self.function_order_should_include(index, order) {
      seen.add(index)
      order.push(index)
    }
  }
}
