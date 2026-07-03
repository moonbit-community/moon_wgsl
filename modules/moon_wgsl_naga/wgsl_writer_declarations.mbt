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
priv struct WgslIrWriterArena {
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
priv struct WgslIrWriterTypeSlot {
  source_index : Int
  item : Type
}

///|
priv struct WgslIrWriterConstantSlot {
  source_index : Int
  item : Constant
}

///|
priv struct WgslIrWriterOverrideSlot {
  source_index : Int
  item : Override
}

///|
priv struct WgslIrWriterGlobalVariableSlot {
  source_index : Int
  item : GlobalVariable
}

///|
priv struct WgslIrWriterFunctionSlot {
  source_index : Int
  item : Function
  function_plan : WgslIrFunctionWriterPlan
}

///|
priv struct WgslIrWriterEntryPointSlot {
  source_index : Int
  item : EntryPoint
  function_plan : WgslIrFunctionWriterPlan
}

///|
priv struct WgslIrWriterConstAssertSlot {
  condition : Handle
}

///|
priv struct WgslIrWriterDeclarationArena {
  types : Array[WgslIrWriterDeclarationSlot]
  constants : Array[WgslIrWriterDeclarationSlot]
  overrides : Array[WgslIrWriterDeclarationSlot]
  global_variables : Array[WgslIrWriterDeclarationSlot]
  functions : Array[WgslIrWriterDeclarationSlot]
}

///|
priv struct WgslIrWriterDeclarationSlot {
  source_index : Int
}

///|
fn WgslIrWriterPlanner::writer_arena(
  self : WgslIrWriterPlanner,
) -> WgslIrWriterArena {
  let declarations = self.declaration_arena()
  let types = self.type_slots(declarations.types)
  let constants = self.constant_slots(declarations.constants)
  let overrides = self.override_slots(declarations.overrides)
  let global_variables = self.global_variable_slots(
    declarations.global_variables,
  )
  let functions = self.function_slots(declarations.functions, true)
  let entry_points = self.entry_point_slots(true)
  let const_asserts = self.const_assert_slots()
  {
    directives: wgsl_ir_semantic_source_directives(self.shader_module),
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
fn WgslIrWriterPlanner::runtime_writer_arena(
  self : WgslIrWriterPlanner,
) -> WgslIrWriterArena {
  let declarations = self.runtime_declaration_arena()
  let types = self.type_slots(declarations.types)
  let constants = self.constant_slots(declarations.constants)
  let overrides = self.override_slots(declarations.overrides)
  let global_variables = self.global_variable_slots(
    declarations.global_variables,
  )
  let functions = self.function_slots(declarations.functions, false)
  let entry_points = self.entry_point_slots(false)
  let const_asserts = self.const_assert_slots()
  {
    directives: wgsl_ir_semantic_source_directives(self.shader_module),
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
fn WgslIrWriterPlanner::type_slots(
  self : WgslIrWriterPlanner,
  declarations : Array[WgslIrWriterDeclarationSlot],
) -> Array[WgslIrWriterTypeSlot] {
  let slots : Array[WgslIrWriterTypeSlot] = []
  for slot in declarations {
    slots.push({
      source_index: slot.source_index,
      item: self.shader_module.types.items[slot.source_index],
    })
  }
  slots
}

///|
fn WgslIrWriterPlanner::constant_slots(
  self : WgslIrWriterPlanner,
  declarations : Array[WgslIrWriterDeclarationSlot],
) -> Array[WgslIrWriterConstantSlot] {
  let slots : Array[WgslIrWriterConstantSlot] = []
  for slot in declarations {
    slots.push({
      source_index: slot.source_index,
      item: self.shader_module.constants.items[slot.source_index],
    })
  }
  slots
}

///|
fn WgslIrWriterPlanner::override_slots(
  self : WgslIrWriterPlanner,
  declarations : Array[WgslIrWriterDeclarationSlot],
) -> Array[WgslIrWriterOverrideSlot] {
  let slots : Array[WgslIrWriterOverrideSlot] = []
  for slot in declarations {
    slots.push({
      source_index: slot.source_index,
      item: self.shader_module.overrides.items[slot.source_index],
    })
  }
  slots
}

///|
fn WgslIrWriterPlanner::global_variable_slots(
  self : WgslIrWriterPlanner,
  declarations : Array[WgslIrWriterDeclarationSlot],
) -> Array[WgslIrWriterGlobalVariableSlot] {
  let slots : Array[WgslIrWriterGlobalVariableSlot] = []
  for slot in declarations {
    slots.push({
      source_index: slot.source_index,
      item: self.shader_module.global_variables.items[slot.source_index],
    })
  }
  slots
}

///|
fn WgslIrWriterPlanner::function_slots(
  self : WgslIrWriterPlanner,
  declarations : Array[WgslIrWriterDeclarationSlot],
  projection_aliases : Bool,
) -> Array[WgslIrWriterFunctionSlot] {
  let slots : Array[WgslIrWriterFunctionSlot] = []
  for slot in declarations {
    let item = self.shader_module.functions.items[slot.source_index]
    slots.push({
      source_index: slot.source_index,
      item,
      function_plan: WgslIrFunctionWriterPlan::from_function(
        self.shader_module,
        item,
        projection_aliases,
      ),
    })
  }
  slots
}

///|
fn WgslIrWriterPlanner::entry_point_slots(
  self : WgslIrWriterPlanner,
  projection_aliases : Bool,
) -> Array[WgslIrWriterEntryPointSlot] {
  let slots : Array[WgslIrWriterEntryPointSlot] = []
  for source_index in self.entry_point_order() {
    let item = self.shader_module.entry_points[source_index]
    slots.push({
      source_index,
      item,
      function_plan: WgslIrFunctionWriterPlan::from_function(
        self.shader_module,
        item.function,
        projection_aliases,
      ),
    })
  }
  slots
}

///|
fn WgslIrWriterPlanner::const_assert_slots(
  self : WgslIrWriterPlanner,
) -> Array[WgslIrWriterConstAssertSlot] {
  let slots : Array[WgslIrWriterConstAssertSlot] = []
  for source_index in 0..<self.shader_module.const_asserts.length() {
    slots.push({ condition: self.shader_module.const_asserts[source_index] })
  }
  slots
}

///|
fn WgslIrWriterPlanner::declaration_arena(
  self : WgslIrWriterPlanner,
) -> WgslIrWriterDeclarationArena {
  let derived = self.derived_module_view()
  {
    types: wgsl_ir_writer_compat_declaration_slots(self.type_order()),
    constants: wgsl_ir_writer_compat_declaration_slots(derived.constants),
    overrides: wgsl_ir_writer_compat_declaration_slots(self.override_order()),
    global_variables: wgsl_ir_writer_compat_declaration_slots(
      derived.global_variables,
    ),
    functions: wgsl_ir_writer_compat_declaration_slots(derived.functions),
  }
}

///|
fn WgslIrWriterPlanner::runtime_declaration_arena(
  self : WgslIrWriterPlanner,
) -> WgslIrWriterDeclarationArena {
  let derived = self.derived_module_view()
  {
    types: wgsl_ir_writer_compat_declaration_slots(self.type_order()),
    constants: wgsl_ir_writer_compat_declaration_slots(derived.constants),
    overrides: wgsl_ir_writer_compat_declaration_slots(self.override_order()),
    global_variables: wgsl_ir_writer_compat_declaration_slots(
      derived.global_variables,
    ),
    functions: wgsl_ir_writer_compat_declaration_slots(
      self.runtime_function_order(),
    ),
  }
}

///|
fn WgslIrWriterPlanner::type_order(self : WgslIrWriterPlanner) -> Array[Int] {
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
fn WgslIrWriterPlanner::override_order(
  self : WgslIrWriterPlanner,
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
fn WgslIrWriterPlanner::runtime_function_order(
  self : WgslIrWriterPlanner,
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
fn WgslIrWriterPlanner::runtime_function_order_should_include(
  self : WgslIrWriterPlanner,
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
fn wgsl_ir_writer_compat_declaration_slots(
  source_order : Array[Int],
) -> Array[WgslIrWriterDeclarationSlot] {
  let slots : Array[WgslIrWriterDeclarationSlot] = []
  for source_index in source_order {
    slots.push({ source_index, })
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
