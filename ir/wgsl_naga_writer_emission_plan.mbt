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
  directives : Array[String]
  types : Array[WgslIrNagaWriterTypeSlot]
  constants : Array[WgslIrNagaWriterConstantSlot]
  overrides : Array[WgslIrNagaWriterOverrideSlot]
  global_variables : Array[WgslIrNagaWriterGlobalVariableSlot]
  functions : Array[WgslIrNagaWriterFunctionSlot]
  entry_points : Array[WgslIrNagaWriterEntryPointSlot]
  const_asserts : Array[WgslIrNagaWriterConstAssertSlot]
}

///|
fn WgslIrNagaCompatPlanner::writer_emission_plan(
  self : WgslIrNagaCompatPlanner,
  arena : WgslIrNagaWriterArena,
) -> WgslIrNagaWriterEmissionPlan {
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
fn WgslIrNagaWriterModule::source_directives(
  self : WgslIrNagaWriterModule,
) -> Array[String] {
  self.emission.directives
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
fn WgslIrNagaWriterModule::type_slots(
  self : WgslIrNagaWriterModule,
) -> Array[WgslIrNagaWriterTypeSlot] {
  self.emission.types
}

///|
fn WgslIrNagaWriterModule::constant_slots(
  self : WgslIrNagaWriterModule,
) -> Array[WgslIrNagaWriterConstantSlot] {
  self.emission.constants
}

///|
fn WgslIrNagaWriterModule::override_slots(
  self : WgslIrNagaWriterModule,
) -> Array[WgslIrNagaWriterOverrideSlot] {
  self.emission.overrides
}

///|
fn WgslIrNagaWriterModule::global_variable_slots(
  self : WgslIrNagaWriterModule,
) -> Array[WgslIrNagaWriterGlobalVariableSlot] {
  self.emission.global_variables
}

///|
fn WgslIrNagaWriterModule::function_slots(
  self : WgslIrNagaWriterModule,
) -> Array[WgslIrNagaWriterFunctionSlot] {
  self.emission.functions
}

///|
fn WgslIrNagaWriterModule::entry_point_slots(
  self : WgslIrNagaWriterModule,
) -> Array[WgslIrNagaWriterEntryPointSlot] {
  self.emission.entry_points
}

///|
fn WgslIrNagaWriterModule::const_assert_slots(
  self : WgslIrNagaWriterModule,
) -> Array[WgslIrNagaWriterConstAssertSlot] {
  self.emission.const_asserts
}
