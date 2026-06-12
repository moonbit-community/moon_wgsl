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
priv struct WgslIrFunctionWriterPlan {
  materialization : WgslIrMaterializationWriterPlan
  body : WgslIrFunctionBodyWriterPlan
}

///|
priv struct WgslIrMaterializationWriterPlan {
  materialized_expressions : @set.Set[Int]
  temporary_initializer_expressions : @set.Set[Int]
  elided_local_alias_targets : Map[Int, Handle]
}

///|
fn WgslIrFunctionWriterPlan::from_function(
  shader_module : Module,
  function : Function,
  projection_aliases : Bool,
) -> WgslIrFunctionWriterPlan {
  let body = WgslIrFunctionBodyWriterPlan::from_function(
    shader_module, function, projection_aliases,
  )
  {
    materialization: WgslIrMaterializationWriterPlan::from_body_plan(body),
    body,
  }
}

///|
fn WgslIrFunctionWriterPlan::statement_plan(
  self : WgslIrFunctionWriterPlan,
  function : Function,
  block : Block,
) -> Array[WgslIrStatementWriterPlanItem] {
  self.body.statement_plan(function, block)
}

///|
fn WgslIrFunctionWriterPlan::local_declaration_order(
  self : WgslIrFunctionWriterPlan,
) -> Array[Int] {
  self.body.local_declaration_order()
}

///|
fn WgslIrFunctionWriterPlan::needs_blank_after_local_declarations(
  self : WgslIrFunctionWriterPlan,
) -> Bool {
  self.body.needs_blank_after_local_declarations()
}

///|
fn WgslIrFunctionWriterPlan::contains_temporary_initializer_expression(
  self : WgslIrFunctionWriterPlan,
  handle : Handle,
) -> Bool {
  self.materialization.temporary_initializer_expressions.contains(
    handle.index(),
  )
}

///|
fn WgslIrFunctionWriterPlan::contains_materialized_expression(
  self : WgslIrFunctionWriterPlan,
  handle : Handle,
) -> Bool {
  self.materialization.materialized_expressions.contains(handle.index())
}

///|
fn WgslIrFunctionWriterPlan::elided_local_alias_target(
  self : WgslIrFunctionWriterPlan,
  handle : Handle,
) -> Handle? {
  self.materialization.elided_local_alias_targets.get(handle.index())
}

///|
fn WgslIrFunctionWriterPlan::temporary_index(
  self : WgslIrFunctionWriterPlan,
  function : Function,
  handle : Handle,
) -> Int {
  wgsl_ir_emit_expression_temporary_index(function, self, handle)
}

///|
fn WgslIrFunctionWriterPlan::implicit_expression_slot_offset(
  self : WgslIrFunctionWriterPlan,
  handle : Handle,
) -> Int {
  self.body.implicit_expression_slot_offset(handle)
}

///|
fn WgslIrMaterializationWriterPlan::from_body_plan(
  body : WgslIrFunctionBodyWriterPlan,
) -> WgslIrMaterializationWriterPlan {
  {
    materialized_expressions: body.materialized_expressions,
    temporary_initializer_expressions: body.temporary_initializer_expressions,
    elided_local_alias_targets: body.elided_local_alias_targets,
  }
}
