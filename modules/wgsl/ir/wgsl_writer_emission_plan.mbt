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
priv struct WgslIrWriterEmissionPlan {
  directives : Array[String]
  types : Array[WgslIrWriterTypeSlot]
  constants : Array[WgslIrWriterConstantSlot]
  overrides : Array[WgslIrWriterOverrideSlot]
  global_variables : Array[WgslIrWriterGlobalVariableSlot]
  functions : Array[WgslIrWriterFunctionSlot]
  entry_points : Array[WgslIrWriterEntryPointSlot]
  const_asserts : Array[WgslIrWriterConstAssertSlot]
}

///|
fn WgslIrWriterPlanner::writer_emission_plan(
  self : WgslIrWriterPlanner,
  arena : WgslIrWriterArena,
) -> WgslIrWriterEmissionPlan {
  ignore(self)
  {
    directives: arena.directives,
    types: arena.types,
    constants: arena.constants,
    overrides: arena.overrides,
    global_variables: arena.global_variables,
    functions: arena.functions,
    entry_points: arena.entry_points,
    const_asserts: arena.const_asserts,
  }
}

///|
fn WgslIrWriterModule::source_directives(
  self : WgslIrWriterModule,
) -> Array[String] {
  self.emission.directives
}

///|
fn WgslIrWriterPlanner::entry_point_order(
  self : WgslIrWriterPlanner,
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
fn WgslIrWriterModule::type_slots(
  self : WgslIrWriterModule,
) -> Array[WgslIrWriterTypeSlot] {
  self.emission.types
}

///|
fn WgslIrWriterModule::constant_slots(
  self : WgslIrWriterModule,
) -> Array[WgslIrWriterConstantSlot] {
  self.emission.constants
}

///|
fn WgslIrWriterModule::override_slots(
  self : WgslIrWriterModule,
) -> Array[WgslIrWriterOverrideSlot] {
  self.emission.overrides
}

///|
fn WgslIrWriterModule::global_variable_slots(
  self : WgslIrWriterModule,
) -> Array[WgslIrWriterGlobalVariableSlot] {
  self.emission.global_variables
}

///|
fn WgslIrWriterModule::function_slots(
  self : WgslIrWriterModule,
) -> Array[WgslIrWriterFunctionSlot] {
  self.emission.functions
}

///|
fn WgslIrWriterModule::entry_point_slots(
  self : WgslIrWriterModule,
) -> Array[WgslIrWriterEntryPointSlot] {
  self.emission.entry_points
}

///|
fn WgslIrWriterModule::const_assert_slots(
  self : WgslIrWriterModule,
) -> Array[WgslIrWriterConstAssertSlot] {
  self.emission.const_asserts
}
