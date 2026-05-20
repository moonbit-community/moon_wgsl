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
priv struct WgslIrNagaWriterArena {
  types : Array[WgslIrNagaWriterTypeSlot]
  constants : Array[WgslIrNagaWriterConstantSlot]
  overrides : Array[WgslIrNagaWriterOverrideSlot]
  global_variables : Array[WgslIrNagaWriterGlobalVariableSlot]
  functions : Array[WgslIrNagaWriterFunctionSlot]
  entry_points : Array[WgslIrNagaWriterEntryPointSlot]
  const_asserts : Array[WgslIrNagaWriterConstAssertSlot]
}

///|
priv struct WgslIrNagaWriterTypeSlot {
  source_index : Int
  item : Type
}

///|
priv struct WgslIrNagaWriterConstantSlot {
  source_index : Int
  item : Constant
}

///|
priv struct WgslIrNagaWriterOverrideSlot {
  source_index : Int
  item : Override
}

///|
priv struct WgslIrNagaWriterGlobalVariableSlot {
  source_index : Int
  item : GlobalVariable
}

///|
priv struct WgslIrNagaWriterFunctionSlot {
  source_index : Int
  item : Function
  body_plan : WgslIrNagaFunctionBodyPlan
}

///|
priv struct WgslIrNagaWriterEntryPointSlot {
  source_index : Int
  item : EntryPoint
  body_plan : WgslIrNagaFunctionBodyPlan
}

///|
priv struct WgslIrNagaWriterConstAssertSlot {
  condition : Handle
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
}

///|
fn WgslIrNagaCompatPlanner::writer_arena(
  self : WgslIrNagaCompatPlanner,
) -> WgslIrNagaWriterArena {
  let declarations = self.declaration_arena()
  let types = self.type_slots(declarations.types)
  let constants = self.constant_slots(declarations.constants)
  let overrides = self.override_slots(declarations.overrides)
  let global_variables = self.global_variable_slots(
    declarations.global_variables,
  )
  let functions = self.function_slots(declarations.functions)
  let entry_points = self.entry_point_slots()
  let const_asserts = self.const_assert_slots()
  WgslIrNagaWriterArena::{
    types,
    constants,
    overrides,
    global_variables,
    functions,
    entry_points,
    const_asserts,
  }
}

///|
fn WgslIrNagaCompatPlanner::runtime_writer_arena(
  self : WgslIrNagaCompatPlanner,
) -> WgslIrNagaWriterArena {
  let declarations = self.runtime_declaration_arena()
  let types = self.type_slots(declarations.types)
  let constants = self.constant_slots(declarations.constants)
  let overrides = self.override_slots(declarations.overrides)
  let global_variables = self.global_variable_slots(
    declarations.global_variables,
  )
  let functions = self.function_slots(declarations.functions)
  let entry_points = self.entry_point_slots()
  let const_asserts = self.const_assert_slots()
  WgslIrNagaWriterArena::{
    types,
    constants,
    overrides,
    global_variables,
    functions,
    entry_points,
    const_asserts,
  }
}

///|
fn WgslIrNagaCompatPlanner::type_slots(
  self : WgslIrNagaCompatPlanner,
  declarations : Array[WgslIrNagaCompatDeclarationSlot],
) -> Array[WgslIrNagaWriterTypeSlot] {
  let slots : Array[WgslIrNagaWriterTypeSlot] = []
  for slot in declarations {
    slots.push(WgslIrNagaWriterTypeSlot::{
      source_index: slot.source_index,
      item: self.shader_module.types.items[slot.source_index],
    })
  }
  slots
}

///|
fn WgslIrNagaCompatPlanner::constant_slots(
  self : WgslIrNagaCompatPlanner,
  declarations : Array[WgslIrNagaCompatDeclarationSlot],
) -> Array[WgslIrNagaWriterConstantSlot] {
  let slots : Array[WgslIrNagaWriterConstantSlot] = []
  for slot in declarations {
    slots.push(WgslIrNagaWriterConstantSlot::{
      source_index: slot.source_index,
      item: self.shader_module.constants.items[slot.source_index],
    })
  }
  slots
}

///|
fn WgslIrNagaCompatPlanner::override_slots(
  self : WgslIrNagaCompatPlanner,
  declarations : Array[WgslIrNagaCompatDeclarationSlot],
) -> Array[WgslIrNagaWriterOverrideSlot] {
  let slots : Array[WgslIrNagaWriterOverrideSlot] = []
  for slot in declarations {
    slots.push(WgslIrNagaWriterOverrideSlot::{
      source_index: slot.source_index,
      item: self.shader_module.overrides.items[slot.source_index],
    })
  }
  slots
}

///|
fn WgslIrNagaCompatPlanner::global_variable_slots(
  self : WgslIrNagaCompatPlanner,
  declarations : Array[WgslIrNagaCompatDeclarationSlot],
) -> Array[WgslIrNagaWriterGlobalVariableSlot] {
  let slots : Array[WgslIrNagaWriterGlobalVariableSlot] = []
  for slot in declarations {
    slots.push(WgslIrNagaWriterGlobalVariableSlot::{
      source_index: slot.source_index,
      item: self.shader_module.global_variables.items[slot.source_index],
    })
  }
  slots
}

///|
fn WgslIrNagaCompatPlanner::function_slots(
  self : WgslIrNagaCompatPlanner,
  declarations : Array[WgslIrNagaCompatDeclarationSlot],
) -> Array[WgslIrNagaWriterFunctionSlot] {
  let slots : Array[WgslIrNagaWriterFunctionSlot] = []
  for slot in declarations {
    let item = self.shader_module.functions.items[slot.source_index]
    slots.push(WgslIrNagaWriterFunctionSlot::{
      source_index: slot.source_index,
      item,
      body_plan: WgslIrNagaFunctionBodyPlan::from_function(item),
    })
  }
  slots
}

///|
fn WgslIrNagaCompatPlanner::entry_point_slots(
  self : WgslIrNagaCompatPlanner,
) -> Array[WgslIrNagaWriterEntryPointSlot] {
  let slots : Array[WgslIrNagaWriterEntryPointSlot] = []
  for source_index in self.entry_point_order() {
    let item = self.shader_module.entry_points[source_index]
    slots.push(WgslIrNagaWriterEntryPointSlot::{
      source_index,
      item,
      body_plan: WgslIrNagaFunctionBodyPlan::from_function(item.function),
    })
  }
  slots
}

///|
fn WgslIrNagaCompatPlanner::const_assert_slots(
  self : WgslIrNagaCompatPlanner,
) -> Array[WgslIrNagaWriterConstAssertSlot] {
  let slots : Array[WgslIrNagaWriterConstAssertSlot] = []
  for source_index in 0..<self.shader_module.const_asserts.length() {
    slots.push(WgslIrNagaWriterConstAssertSlot::{
      condition: self.shader_module.const_asserts[source_index],
    })
  }
  slots
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
fn WgslIrNagaCompatPlanner::runtime_declaration_arena(
  self : WgslIrNagaCompatPlanner,
) -> WgslIrNagaCompatDeclarationArena {
  WgslIrNagaCompatDeclarationArena::{
    types: wgsl_ir_naga_compat_declaration_slots(self.type_order()),
    constants: wgsl_ir_naga_compat_declaration_slots(self.constant_order()),
    overrides: wgsl_ir_naga_compat_declaration_slots(self.override_order()),
    global_variables: wgsl_ir_naga_compat_declaration_slots(
      self.global_variable_order(),
    ),
    functions: wgsl_ir_naga_compat_declaration_slots(
      self.runtime_function_order(),
    ),
  }
}

///|
fn WgslIrNagaCompatPlanner::type_order(
  self : WgslIrNagaCompatPlanner,
) -> Array[Int] {
  match self.filter {
    Some(filter) => {
      let order : Array[Int] = []
      for index in 0..<self.shader_module.types.items.length() {
        if filter.contains_type(index) {
          order.push(index)
        }
      }
      order
    }
    None =>
      wgsl_ir_source_order_indices(self.shader_module.types.items.length())
  }
}

///|
fn WgslIrNagaCompatPlanner::constant_order(
  self : WgslIrNagaCompatPlanner,
) -> Array[Int] {
  match self.filter {
    Some(filter) => {
      let order : Array[Int] = []
      for index in 0..<self.shader_module.constants.items.length() {
        if filter.contains_constant(index) {
          order.push(index)
        }
      }
      order
    }
    None =>
      wgsl_ir_source_order_indices(self.shader_module.constants.items.length())
  }
}

///|
fn WgslIrNagaCompatPlanner::override_order(
  self : WgslIrNagaCompatPlanner,
) -> Array[Int] {
  match self.filter {
    Some(filter) => {
      let order : Array[Int] = []
      for index in 0..<self.shader_module.overrides.items.length() {
        if filter.contains_override(index) {
          order.push(index)
        }
      }
      order
    }
    None =>
      wgsl_ir_source_order_indices(self.shader_module.overrides.items.length())
  }
}

///|
fn WgslIrNagaCompatPlanner::global_variable_order(
  self : WgslIrNagaCompatPlanner,
) -> Array[Int] {
  match self.filter {
    Some(filter) => {
      let order : Array[Int] = []
      for index in 0..<self.shader_module.global_variables.items.length() {
        if filter.contains_global_variable(index) {
          order.push(index)
        }
      }
      order
    }
    None =>
      wgsl_ir_source_order_indices(
        self.shader_module.global_variables.items.length(),
      )
  }
}

///|
fn WgslIrNagaCompatPlanner::runtime_function_order(
  self : WgslIrNagaCompatPlanner,
) -> Array[Int] {
  let order : Array[Int] = []
  for index in 0..<self.shader_module.functions.items.length() {
    if self.runtime_function_order_should_include(index, order) {
      order.push(index)
    }
  }
  order
}

///|
fn WgslIrNagaCompatPlanner::runtime_function_order_should_include(
  self : WgslIrNagaCompatPlanner,
  index : Int,
  emitted : Array[Int],
) -> Bool {
  if emitted.contains(index) {
    return false
  }
  match self.filter {
    Some(filter) => if !filter.contains_function(index) { return false }
    None => ()
  }
  !wgsl_ir_function_is_entry_point_name(
    self.shader_module.functions.items[index],
    self.shader_module,
  )
}

///|
fn wgsl_ir_naga_compat_declaration_slots(
  source_order : Array[Int],
) -> Array[WgslIrNagaCompatDeclarationSlot] {
  let slots : Array[WgslIrNagaCompatDeclarationSlot] = []
  for source_index in source_order {
    slots.push(WgslIrNagaCompatDeclarationSlot::{ source_index, })
  }
  slots
}

///|
fn wgsl_ir_source_order_indices(length : Int) -> Array[Int] {
  let order : Array[Int] = []
  for index in 0..<length {
    order.push(index)
  }
  order
}
