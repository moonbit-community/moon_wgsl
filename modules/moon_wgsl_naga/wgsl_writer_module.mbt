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
priv struct WgslIrWriterModule {
  filter : WgslIrReachability?
  derived : WgslIrDerivedModuleView
  emission : WgslIrWriterEmissionPlan
  compatibility : WgslNagaCompatibilityView
  root_struct_member_import_spelling : Bool
  mut names : WgslIrFinalNamePlan
}

///|
priv struct WgslIrWriterPlanner {
  shader_module : Module
  filter : WgslIrReachability?
  compatibility : WgslNagaCompatibilityView
}

///|
fn build_wgsl_ir_writer_module(
  shader_module : Module,
  root_items : Array[String]?,
  compatibility? : WgslNagaCompatibilityView = WgslNagaCompatibilityView::empty(),
) -> WgslIrWriterModule {
  let filter = wgsl_ir_reachability_from_optional_roots(
    shader_module, root_items,
  )
  let planner = WgslIrWriterPlanner::{ shader_module, filter, compatibility }
  let derived = planner.derived_module_view()
  let arena = planner.writer_arena()
  let view = WgslIrWriterModule::{
    filter,
    derived,
    emission: planner.writer_emission_plan(arena),
    compatibility,
    root_struct_member_import_spelling: true,
    names: WgslIrFinalNamePlan::empty(),
  }
  view.names = build_wgsl_ir_writer_final_name_plan(view, shader_module)
  ignore(view.derived)
  view
}

///|
fn build_wgsl_ir_runtime_writer_module(
  shader_module : Module,
  root_items : Array[String]?,
  compatibility? : WgslNagaCompatibilityView = WgslNagaCompatibilityView::empty(),
) -> WgslIrWriterModule {
  let filter = wgsl_ir_reachability_from_optional_roots(
    shader_module, root_items,
  )
  let planner = WgslIrWriterPlanner::{ shader_module, filter, compatibility }
  let derived = planner.derived_module_view()
  let arena = planner.runtime_writer_arena()
  let view = WgslIrWriterModule::{
    filter,
    derived,
    emission: planner.writer_emission_plan(arena),
    compatibility,
    root_struct_member_import_spelling: false,
    names: WgslIrFinalNamePlan::empty(),
  }
  view.names = build_wgsl_ir_writer_final_name_plan(view, shader_module)
  ignore(view.derived)
  view
}
