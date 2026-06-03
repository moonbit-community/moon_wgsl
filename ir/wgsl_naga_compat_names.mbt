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
fn build_wgsl_ir_naga_writer_final_name_plan(
  view : WgslIrNagaWriterModule,
  shader_module : Module,
) -> WgslIrFinalNamePlan {
  let table = WgslIrFinalNamePlan::empty()
  let namer = WgslIrNagaNamer::WgslIrNagaNamer()
  for slot in view.type_slots() {
    view.allocate_type_name(table, namer, slot)
  }
  for slot in view.entry_point_slots() {
    view.allocate_entry_point_signature_names(table, namer, slot)
    view.reserve_entry_point_var_local_names(table, namer, slot)
  }
  for slot in view.function_slots() {
    view.allocate_function_signature_names(table, namer, slot)
    view.reserve_function_var_local_names(table, namer, slot)
  }
  for slot in view.global_variable_slots() {
    table.names.set(
      wgsl_ir_emit_name_key("global", slot.source_index),
      namer.call_or(slot.item.name, "global"),
    )
  }
  for slot in view.constant_slots() {
    table.names.set(
      wgsl_ir_emit_name_key("const", slot.source_index),
      namer.call_or(slot.item.name, "const"),
    )
  }
  for slot in view.override_slots() {
    table.names.set(
      wgsl_ir_emit_name_key("override", slot.source_index),
      namer.call_or(slot.item.name, "override"),
    )
  }
  for slot in view.function_slots() {
    view.allocate_function_body_names(table, namer, slot, shader_module)
  }
  for slot in view.entry_point_slots() {
    view.allocate_entry_point_body_names(table, namer, slot, shader_module)
  }
  table
}

///|
fn WgslIrNagaWriterModule::allocate_type_name(
  self : WgslIrNagaWriterModule,
  table : WgslIrFinalNamePlan,
  namer : WgslIrNagaNamer,
  slot : WgslIrNagaWriterTypeSlot,
) -> Unit {
  ignore(self)
  let ty = slot.item
  let raw = match ty.name {
    Some(name) => name
    None => "type"
  }
  table.names.set(
    wgsl_ir_emit_name_key("type", slot.source_index),
    namer.call(raw),
  )
  match ty.inner {
    Struct(members, _) | PredeclaredStruct(members, _) => {
      let member_namer = WgslIrNagaNamer::WgslIrNagaNamer()
      for member_index in 0..<members.length() {
        let raw = match members[member_index].name {
          Some(name) => name
          None => "member"
        }
        let raw = if self.type_name_is_imported_generated_symbol(ty.name) {
          raw
        } else {
          self.root_struct_member_import_spelling_name(raw)
        }
        table.names.set(
          wgsl_ir_emit_name_key2("member", slot.source_index, member_index),
          member_namer.member_call(raw),
        )
      }
    }
    _ => ()
  }
}

///|
fn WgslIrNagaWriterModule::type_name_is_imported_generated_symbol(
  self : WgslIrNagaWriterModule,
  name : String?,
) -> Bool {
  match name {
    Some(value) =>
      match self.generated_import_provenance.get(value) {
        Some(provenance) => provenance.kind == ImportedSourceSymbol
        None => false
      }
    None => false
  }
}

///|
fn WgslIrNagaWriterModule::root_struct_member_import_spelling_name(
  self : WgslIrNagaWriterModule,
  source_name : String,
) -> String {
  if !self.root_struct_member_import_spelling {
    return source_name
  }
  let mut target : String? = None
  for entry in self.generated_import_provenance.iter() {
    let (_, provenance) = entry
    if provenance.kind != ImportedSourceSymbol ||
      !provenance.root_local_spelling ||
      provenance.source_symbol_name != source_name {
      continue
    }
    match target {
      Some(existing) if existing != provenance.generated_symbol_name =>
        return source_name
      Some(_) => ()
      None => target = Some(provenance.generated_symbol_name)
    }
  }
  match target {
    Some(value) => value
    None => source_name
  }
}

///|
fn WgslIrNagaWriterModule::allocate_entry_point_signature_names(
  self : WgslIrNagaWriterModule,
  table : WgslIrFinalNamePlan,
  namer : WgslIrNagaNamer,
  slot : WgslIrNagaWriterEntryPointSlot,
) -> Unit {
  ignore(self)
  let ep = slot.item
  table.names.set(
    wgsl_ir_emit_name_key("ep", slot.source_index),
    namer.call(ep.name),
  )
  for arg_index in 0..<ep.function.arguments.length() {
    table.names.set(
      wgsl_ir_emit_name_key2("ep_arg", slot.source_index, arg_index),
      namer.call_or(ep.function.arguments[arg_index].name, "param"),
    )
  }
}

///|
fn WgslIrNagaWriterModule::allocate_function_signature_names(
  self : WgslIrNagaWriterModule,
  table : WgslIrFinalNamePlan,
  namer : WgslIrNagaNamer,
  slot : WgslIrNagaWriterFunctionSlot,
) -> Unit {
  ignore(self)
  let function = slot.item
  table.names.set(
    wgsl_ir_emit_name_key("fn", slot.source_index),
    namer.call_or(function.name, "function"),
  )
  for arg_index in 0..<function.arguments.length() {
    table.names.set(
      wgsl_ir_emit_name_key2("fn_arg", slot.source_index, arg_index),
      namer.call_or(function.arguments[arg_index].name, "param"),
    )
  }
}

///|
fn WgslIrNagaWriterModule::allocate_entry_point_body_names(
  self : WgslIrNagaWriterModule,
  table : WgslIrFinalNamePlan,
  namer : WgslIrNagaNamer,
  slot : WgslIrNagaWriterEntryPointSlot,
  shader_module : Module,
) -> Unit {
  ignore(self)
  let ep = slot.item
  table.allocate_function_body_names_from_arena(
    shader_module,
    EntryPointFunction(slot.source_index),
    ep.function,
    slot.body_plan,
    namer,
  )
}

///|
fn WgslIrNagaWriterModule::reserve_entry_point_var_local_names(
  self : WgslIrNagaWriterModule,
  table : WgslIrFinalNamePlan,
  namer : WgslIrNagaNamer,
  slot : WgslIrNagaWriterEntryPointSlot,
) -> Unit {
  ignore(self)
  table.reserve_function_var_local_names_from_arena(
    EntryPointFunction(slot.source_index),
    slot.item.function,
    slot.body_plan,
    namer,
  )
}

///|
fn WgslIrNagaWriterModule::allocate_function_body_names(
  self : WgslIrNagaWriterModule,
  table : WgslIrFinalNamePlan,
  namer : WgslIrNagaNamer,
  slot : WgslIrNagaWriterFunctionSlot,
  shader_module : Module,
) -> Unit {
  ignore(self)
  let function = slot.item
  table.allocate_function_body_names_from_arena(
    shader_module,
    UserFunction(slot.source_index),
    function,
    slot.body_plan,
    namer,
  )
}

///|
fn WgslIrNagaWriterModule::reserve_function_var_local_names(
  self : WgslIrNagaWriterModule,
  table : WgslIrFinalNamePlan,
  namer : WgslIrNagaNamer,
  slot : WgslIrNagaWriterFunctionSlot,
) -> Unit {
  ignore(self)
  table.reserve_function_var_local_names_from_arena(
    UserFunction(slot.source_index),
    slot.item,
    slot.body_plan,
    namer,
  )
}
