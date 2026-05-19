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
priv struct WgslIrNagaWriterEmissionPlan {
  types : Array[Int]
  constants : Array[Int]
  overrides : Array[Int]
  global_variables : Array[Int]
  functions : Array[Int]
  entry_points : Array[Int]
}

///|
fn WgslIrNagaCompatPlanner::writer_emission_plan(
  self : WgslIrNagaCompatPlanner,
  arena : WgslIrNagaWriterArena,
) -> WgslIrNagaWriterEmissionPlan {
  WgslIrNagaWriterEmissionPlan::{
    types: wgsl_ir_naga_type_slot_source_order(arena.types),
    constants: wgsl_ir_naga_constant_slot_source_order(arena.constants),
    overrides: wgsl_ir_naga_override_slot_source_order(arena.overrides),
    global_variables: wgsl_ir_naga_global_variable_slot_source_order(
      arena.global_variables,
    ),
    functions: wgsl_ir_naga_function_slot_source_order(arena.functions),
    entry_points: self.entry_point_order(),
  }
}

///|
fn wgsl_ir_naga_type_slot_source_order(
  slots : Array[WgslIrNagaWriterTypeSlot],
) -> Array[Int] {
  let order : Array[Int] = []
  for slot in slots {
    if slot.naga_index != order.length() {
      abort("invalid Naga writer type slot order")
    }
    ignore(slot.item)
    order.push(slot.source_index)
  }
  order
}

///|
fn wgsl_ir_naga_constant_slot_source_order(
  slots : Array[WgslIrNagaWriterConstantSlot],
) -> Array[Int] {
  let order : Array[Int] = []
  for slot in slots {
    if slot.naga_index != order.length() {
      abort("invalid Naga writer constant slot order")
    }
    ignore(slot.item)
    order.push(slot.source_index)
  }
  order
}

///|
fn wgsl_ir_naga_override_slot_source_order(
  slots : Array[WgslIrNagaWriterOverrideSlot],
) -> Array[Int] {
  let order : Array[Int] = []
  for slot in slots {
    if slot.naga_index != order.length() {
      abort("invalid Naga writer override slot order")
    }
    ignore(slot.item)
    order.push(slot.source_index)
  }
  order
}

///|
fn wgsl_ir_naga_global_variable_slot_source_order(
  slots : Array[WgslIrNagaWriterGlobalVariableSlot],
) -> Array[Int] {
  let order : Array[Int] = []
  for slot in slots {
    if slot.naga_index != order.length() {
      abort("invalid Naga writer global-variable slot order")
    }
    ignore(slot.item)
    order.push(slot.source_index)
  }
  order
}

///|
fn wgsl_ir_naga_function_slot_source_order(
  slots : Array[WgslIrNagaWriterFunctionSlot],
) -> Array[Int] {
  let order : Array[Int] = []
  for slot in slots {
    if slot.naga_index != order.length() {
      abort("invalid Naga writer function slot order")
    }
    ignore(slot.item)
    order.push(slot.source_index)
  }
  order
}

///|
fn WgslIrNagaCompatPlanner::entry_point_order(
  self : WgslIrNagaCompatPlanner,
) -> Array[Int] {
  let order : Array[Int] = []
  for index in 0..<self.shader_module.entry_points.length() {
    match self.filter {
      Some(filter) =>
        if filter.contains_entry_point(index) {
          order.push(index)
        }
      None => order.push(index)
    }
  }
  order
}

///|
fn WgslIrNagaWriterModule::type_order(
  self : WgslIrNagaWriterModule,
) -> Array[Int] {
  self.emission.types
}

///|
fn WgslIrNagaWriterModule::constant_order(
  self : WgslIrNagaWriterModule,
) -> Array[Int] {
  self.emission.constants
}

///|
fn WgslIrNagaWriterModule::override_order(
  self : WgslIrNagaWriterModule,
) -> Array[Int] {
  self.emission.overrides
}

///|
fn WgslIrNagaWriterModule::global_variable_order(
  self : WgslIrNagaWriterModule,
) -> Array[Int] {
  self.emission.global_variables
}

///|
fn WgslIrNagaWriterModule::function_order(
  self : WgslIrNagaWriterModule,
) -> Array[Int] {
  self.emission.functions
}

///|
fn WgslIrNagaWriterModule::entry_point_order(
  self : WgslIrNagaWriterModule,
) -> Array[Int] {
  self.emission.entry_points
}

///|
fn WgslIrNagaWriterModule::should_emit_entry_point(
  self : WgslIrNagaWriterModule,
  index : Int,
) -> Bool {
  self.emission.entry_points.contains(index)
}
