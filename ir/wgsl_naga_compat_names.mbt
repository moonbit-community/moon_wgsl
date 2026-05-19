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
) -> WgslIrFinalNamePlan {
  let module_ = view.shader_module
  let table = WgslIrFinalNamePlan::empty()
  let namer = WgslIrNagaNamer::WgslIrNagaNamer()
  for index in view.type_order() {
    view.allocate_type_name(table, namer, index)
  }
  for ep_index in 0..<module_.entry_points.length() {
    if view.should_emit_entry_point(ep_index) {
      view.allocate_entry_point_signature_names(table, namer, ep_index)
    }
  }
  for fn_index in view.function_order() {
    view.allocate_function_signature_names(table, namer, fn_index)
  }
  for index in view.global_variable_order() {
    table.names.set(
      wgsl_ir_emit_name_key("global", index),
      namer.call_or(module_.global_variables.items[index].name, "global"),
    )
  }
  for index in view.constant_order() {
    table.names.set(
      wgsl_ir_emit_name_key("const", index),
      namer.call_or(module_.constants.items[index].name, "const"),
    )
  }
  for index in view.override_order() {
    table.names.set(
      wgsl_ir_emit_name_key("override", index),
      namer.call_or(module_.overrides.items[index].name, "override"),
    )
  }
  for ep_index in 0..<module_.entry_points.length() {
    if view.should_emit_entry_point(ep_index) {
      view.allocate_entry_point_body_names(table, namer, ep_index)
    }
  }
  for fn_index in view.function_order() {
    view.allocate_function_body_names(table, namer, fn_index)
  }
  table
}

///|
fn WgslIrNagaWriterModule::allocate_type_name(
  self : WgslIrNagaWriterModule,
  table : WgslIrFinalNamePlan,
  namer : WgslIrNagaNamer,
  index : Int,
) -> Unit {
  let ty = self.shader_module.types.items[index]
  let raw = match ty.name {
    Some(name) => name
    None => "type"
  }
  table.names.set(wgsl_ir_emit_name_key("type", index), namer.call(raw))
  match ty.inner {
    Struct(members, _) | PredeclaredStruct(members, _) => {
      let member_namer = WgslIrNagaNamer::WgslIrNagaNamer()
      for member_index in 0..<members.length() {
        let raw = match members[member_index].name {
          Some(name) => name
          None => "member"
        }
        table.names.set(
          wgsl_ir_emit_name_key2("member", index, member_index),
          member_namer.call(raw),
        )
      }
    }
    _ => ()
  }
}

///|
fn WgslIrNagaWriterModule::allocate_entry_point_signature_names(
  self : WgslIrNagaWriterModule,
  table : WgslIrFinalNamePlan,
  namer : WgslIrNagaNamer,
  ep_index : Int,
) -> Unit {
  let ep = self.shader_module.entry_points[ep_index]
  table.names.set(wgsl_ir_emit_name_key("ep", ep_index), namer.call(ep.name))
  for arg_index in 0..<ep.function.arguments.length() {
    table.names.set(
      wgsl_ir_emit_name_key2("ep_arg", ep_index, arg_index),
      namer.call_or(ep.function.arguments[arg_index].name, "param"),
    )
  }
}

///|
fn WgslIrNagaWriterModule::allocate_function_signature_names(
  self : WgslIrNagaWriterModule,
  table : WgslIrFinalNamePlan,
  namer : WgslIrNagaNamer,
  fn_index : Int,
) -> Unit {
  let function = self.shader_module.functions.items[fn_index]
  table.names.set(
    wgsl_ir_emit_name_key("fn", fn_index),
    namer.call_or(function.name, "function"),
  )
  for arg_index in 0..<function.arguments.length() {
    table.names.set(
      wgsl_ir_emit_name_key2("fn_arg", fn_index, arg_index),
      namer.call_or(function.arguments[arg_index].name, "param"),
    )
  }
}

///|
fn WgslIrNagaWriterModule::allocate_entry_point_body_names(
  self : WgslIrNagaWriterModule,
  table : WgslIrFinalNamePlan,
  namer : WgslIrNagaNamer,
  ep_index : Int,
) -> Unit {
  let ep = self.shader_module.entry_points[ep_index]
  table.allocate_function_body_names_from_arena(
    EntryPointFunction(ep_index),
    ep.function,
    namer,
  )
}

///|
fn WgslIrNagaWriterModule::allocate_function_body_names(
  self : WgslIrNagaWriterModule,
  table : WgslIrFinalNamePlan,
  namer : WgslIrNagaNamer,
  fn_index : Int,
) -> Unit {
  let function = self.shader_module.functions.items[fn_index]
  table.allocate_function_body_names_from_arena(
    UserFunction(fn_index),
    function,
    namer,
  )
}
