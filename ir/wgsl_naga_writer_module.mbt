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
priv struct WgslIrNagaWriterModule {
  shader_module : Module
  filter : WgslIrEmitFilter?
  declarations : WgslIrNagaCompatDeclarationArena
  mut names : WgslIrFinalNamePlan
}

///|
priv struct WgslIrNagaCompatPlanner {
  shader_module : Module
  filter : WgslIrEmitFilter?
}

///|
fn build_wgsl_ir_naga_writer_module(
  shader_module : Module,
  root_items : Array[String]?,
) -> WgslIrNagaWriterModule {
  let filter = wgsl_ir_emit_filter_from_optional_roots(
    shader_module, root_items,
  )
  let planner = WgslIrNagaCompatPlanner::{ shader_module, filter }
  let view = WgslIrNagaWriterModule::{
    shader_module,
    filter,
    declarations: planner.declaration_arena(),
    names: WgslIrFinalNamePlan::empty(),
  }
  view.names = build_wgsl_ir_naga_writer_final_name_plan(view)
  view
}

///|
fn WgslIrNagaWriterModule::should_emit_entry_point(
  self : WgslIrNagaWriterModule,
  index : Int,
) -> Bool {
  match self.filter {
    Some(filter) => filter.contains_entry_point(index)
    None => true
  }
}
