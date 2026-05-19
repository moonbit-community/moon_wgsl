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
  declarations : WgslIrNagaCompatDeclarationArena
  type_handles : Map[Int, Int]
  constant_handles : Map[Int, Int]
  override_handles : Map[Int, Int]
  global_variable_handles : Map[Int, Int]
  function_handles : Map[Int, Int]
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
  WgslIrNagaWriterArena::{
    declarations,
    type_handles: wgsl_ir_naga_compat_handle_map(declarations.types),
    constant_handles: wgsl_ir_naga_compat_handle_map(declarations.constants),
    override_handles: wgsl_ir_naga_compat_handle_map(declarations.overrides),
    global_variable_handles: wgsl_ir_naga_compat_handle_map(
      declarations.global_variables,
    ),
    function_handles: wgsl_ir_naga_compat_handle_map(declarations.functions),
  }
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
  wgsl_ir_naga_compat_source_order_from_slots(self.arena.declarations.types)
}

///|
fn WgslIrNagaWriterModule::constant_order(
  self : WgslIrNagaWriterModule,
) -> Array[Int] {
  wgsl_ir_naga_compat_source_order_from_slots(self.arena.declarations.constants)
}

///|
fn WgslIrNagaWriterModule::override_order(
  self : WgslIrNagaWriterModule,
) -> Array[Int] {
  wgsl_ir_naga_compat_source_order_from_slots(self.arena.declarations.overrides)
}

///|
fn WgslIrNagaWriterModule::global_variable_order(
  self : WgslIrNagaWriterModule,
) -> Array[Int] {
  wgsl_ir_naga_compat_source_order_from_slots(
    self.arena.declarations.global_variables,
  )
}

///|
fn WgslIrNagaWriterModule::function_order(
  self : WgslIrNagaWriterModule,
) -> Array[Int] {
  wgsl_ir_naga_compat_source_order_from_slots(self.arena.declarations.functions)
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
fn wgsl_ir_naga_compat_handle_map(
  slots : Array[WgslIrNagaCompatDeclarationSlot],
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
