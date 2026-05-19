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
  type_handles : Map[Int, Int]
  constant_handles : Map[Int, Int]
  override_handles : Map[Int, Int]
  global_variable_handles : Map[Int, Int]
  function_handles : Map[Int, Int]
}

///|
priv struct WgslIrNagaWriterTypeSlot {
  source_index : Int
  naga_index : Int
  item : Type
}

///|
priv struct WgslIrNagaWriterConstantSlot {
  source_index : Int
  naga_index : Int
  item : Constant
}

///|
priv struct WgslIrNagaWriterOverrideSlot {
  source_index : Int
  naga_index : Int
  item : Override
}

///|
priv struct WgslIrNagaWriterGlobalVariableSlot {
  source_index : Int
  naga_index : Int
  item : GlobalVariable
}

///|
priv struct WgslIrNagaWriterFunctionSlot {
  source_index : Int
  naga_index : Int
  item : Function
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
  WgslIrNagaWriterArena::{
    types,
    constants,
    overrides,
    global_variables,
    functions,
    type_handles: wgsl_ir_naga_type_slot_handle_map(types),
    constant_handles: wgsl_ir_naga_constant_slot_handle_map(constants),
    override_handles: wgsl_ir_naga_override_slot_handle_map(overrides),
    global_variable_handles: wgsl_ir_naga_global_variable_slot_handle_map(
      global_variables,
    ),
    function_handles: wgsl_ir_naga_function_slot_handle_map(functions),
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
      naga_index: slot.naga_index,
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
      naga_index: slot.naga_index,
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
      naga_index: slot.naga_index,
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
      naga_index: slot.naga_index,
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
    slots.push(WgslIrNagaWriterFunctionSlot::{
      source_index: slot.source_index,
      naga_index: slot.naga_index,
      item: self.shader_module.functions.items[slot.source_index],
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
fn WgslIrNagaWriterModule::contains_type_declaration(
  self : WgslIrNagaWriterModule,
  index : Int,
) -> Bool {
  self.arena.type_handles.get(index) != None
}

///|
fn WgslIrNagaWriterModule::contains_constant_declaration(
  self : WgslIrNagaWriterModule,
  index : Int,
) -> Bool {
  self.arena.constant_handles.get(index) != None
}

///|
fn WgslIrNagaWriterModule::contains_override_declaration(
  self : WgslIrNagaWriterModule,
  index : Int,
) -> Bool {
  self.arena.override_handles.get(index) != None
}

///|
fn WgslIrNagaWriterModule::contains_global_variable_declaration(
  self : WgslIrNagaWriterModule,
  index : Int,
) -> Bool {
  self.arena.global_variable_handles.get(index) != None
}

///|
fn WgslIrNagaWriterModule::contains_function_declaration(
  self : WgslIrNagaWriterModule,
  index : Int,
) -> Bool {
  self.arena.function_handles.get(index) != None
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
fn wgsl_ir_naga_type_slot_handle_map(
  slots : Array[WgslIrNagaWriterTypeSlot],
) -> Map[Int, Int] {
  let handles : Map[Int, Int] = Map([])
  for slot in slots {
    handles.set(slot.source_index, slot.naga_index)
  }
  handles
}

///|
fn wgsl_ir_naga_constant_slot_handle_map(
  slots : Array[WgslIrNagaWriterConstantSlot],
) -> Map[Int, Int] {
  let handles : Map[Int, Int] = Map([])
  for slot in slots {
    handles.set(slot.source_index, slot.naga_index)
  }
  handles
}

///|
fn wgsl_ir_naga_override_slot_handle_map(
  slots : Array[WgslIrNagaWriterOverrideSlot],
) -> Map[Int, Int] {
  let handles : Map[Int, Int] = Map([])
  for slot in slots {
    handles.set(slot.source_index, slot.naga_index)
  }
  handles
}

///|
fn wgsl_ir_naga_global_variable_slot_handle_map(
  slots : Array[WgslIrNagaWriterGlobalVariableSlot],
) -> Map[Int, Int] {
  let handles : Map[Int, Int] = Map([])
  for slot in slots {
    handles.set(slot.source_index, slot.naga_index)
  }
  handles
}

///|
fn wgsl_ir_naga_function_slot_handle_map(
  slots : Array[WgslIrNagaWriterFunctionSlot],
) -> Map[Int, Int] {
  let handles : Map[Int, Int] = Map([])
  for slot in slots {
    handles.set(slot.source_index, slot.naga_index)
  }
  handles
}

///|
fn wgsl_ir_source_order_indices(length : Int) -> Array[Int] {
  let order : Array[Int] = []
  for index in 0..<length {
    order.push(index)
  }
  order
}
