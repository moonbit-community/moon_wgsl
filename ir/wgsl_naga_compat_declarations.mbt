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
fn WgslIrNagaWriterModule::type_order(
  self : WgslIrNagaWriterModule,
) -> Array[Int] {
  wgsl_ir_naga_compat_source_order_from_slots(self.declarations.types)
}

///|
fn WgslIrNagaWriterModule::constant_order(
  self : WgslIrNagaWriterModule,
) -> Array[Int] {
  wgsl_ir_naga_compat_source_order_from_slots(self.declarations.constants)
}

///|
fn WgslIrNagaWriterModule::override_order(
  self : WgslIrNagaWriterModule,
) -> Array[Int] {
  wgsl_ir_naga_compat_source_order_from_slots(self.declarations.overrides)
}

///|
fn WgslIrNagaWriterModule::global_variable_order(
  self : WgslIrNagaWriterModule,
) -> Array[Int] {
  wgsl_ir_naga_compat_source_order_from_slots(
    self.declarations.global_variables,
  )
}

///|
fn WgslIrNagaWriterModule::function_order(
  self : WgslIrNagaWriterModule,
) -> Array[Int] {
  wgsl_ir_naga_compat_source_order_from_slots(self.declarations.functions)
}

///|
fn WgslIrNagaWriterModule::contains_type_declaration(
  self : WgslIrNagaWriterModule,
  index : Int,
) -> Bool {
  wgsl_ir_naga_compat_slots_contain_source_index(self.declarations.types, index)
}

///|
fn WgslIrNagaWriterModule::contains_constant_declaration(
  self : WgslIrNagaWriterModule,
  index : Int,
) -> Bool {
  wgsl_ir_naga_compat_slots_contain_source_index(
    self.declarations.constants,
    index,
  )
}

///|
fn WgslIrNagaWriterModule::contains_override_declaration(
  self : WgslIrNagaWriterModule,
  index : Int,
) -> Bool {
  wgsl_ir_naga_compat_slots_contain_source_index(
    self.declarations.overrides,
    index,
  )
}

///|
fn WgslIrNagaWriterModule::contains_global_variable_declaration(
  self : WgslIrNagaWriterModule,
  index : Int,
) -> Bool {
  wgsl_ir_naga_compat_slots_contain_source_index(
    self.declarations.global_variables,
    index,
  )
}

///|
fn WgslIrNagaWriterModule::contains_function_declaration(
  self : WgslIrNagaWriterModule,
  index : Int,
) -> Bool {
  wgsl_ir_naga_compat_slots_contain_source_index(
    self.declarations.functions,
    index,
  )
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
fn wgsl_ir_naga_compat_slots_contain_source_index(
  slots : Array[WgslIrNagaCompatDeclarationSlot],
  index : Int,
) -> Bool {
  for slot in slots {
    if slot.source_index == index {
      return true
    }
  }
  false
}

///|
fn wgsl_ir_source_order_indices(length : Int) -> Array[Int] {
  let order : Array[Int] = []
  for index in 0..<length {
    order.push(index)
  }
  order
}
