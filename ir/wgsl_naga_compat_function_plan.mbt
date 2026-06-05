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
priv struct NagaCompatFunctionPlan {
  arena : NagaCompatExpressionArenaPlan
  call : NagaCompatCallArgumentPlan
  short_circuit : NagaCompatShortCircuitPlan
  materialization : NagaCompatMaterializationPlan
  body : WgslIrNagaFunctionBodyPlan
  names : NagaCompatNamePlan
}

///|
priv struct NagaCompatExpressionArenaPlan {
  expression_count : Int
  implicit_expression_slots_before : Array[Int]
}

///|
priv struct NagaCompatCallArgumentPlan {
  call_expression_count : Int
  call_result_expression_count : Int
}

///|
priv struct NagaCompatShortCircuitPlan {
  result_locals : Array[Int]
}

///|
priv struct NagaCompatMaterializationPlan {
  materialized_expressions : @set.Set[Int]
  temporary_initializer_expressions : @set.Set[Int]
  elided_local_alias_targets : Map[Int, Handle]
}

///|
priv struct NagaCompatNamePlan {
  materialized_temporary_slots : Int
  local_declaration_slots : Int
  named_expression_slots : Int
}

///|
fn NagaCompatFunctionPlan::from_function(
  shader_module : Module,
  function : Function,
  projection_aliases : Bool,
) -> NagaCompatFunctionPlan {
  let body = WgslIrNagaFunctionBodyPlan::from_function(
    shader_module, function, projection_aliases,
  )
  {
    arena: NagaCompatExpressionArenaPlan::from_function(function, body),
    call: NagaCompatCallArgumentPlan::from_function(function),
    short_circuit: NagaCompatShortCircuitPlan::from_function(function),
    materialization: NagaCompatMaterializationPlan::from_body_plan(body),
    body,
    names: NagaCompatNamePlan::from_function(function, body),
  }
}

///|
fn NagaCompatFunctionPlan::statement_plan(
  self : NagaCompatFunctionPlan,
  function : Function,
  block : Block,
) -> Array[WgslIrNagaStatementPlanItem] {
  self.body.statement_plan(function, block)
}

///|
fn NagaCompatFunctionPlan::local_declaration_order(
  self : NagaCompatFunctionPlan,
) -> Array[Int] {
  self.body.local_declaration_order()
}

///|
fn NagaCompatFunctionPlan::needs_blank_after_local_declarations(
  self : NagaCompatFunctionPlan,
) -> Bool {
  self.body.needs_blank_after_local_declarations()
}

///|
fn NagaCompatFunctionPlan::contains_temporary_initializer_expression(
  self : NagaCompatFunctionPlan,
  handle : Handle,
) -> Bool {
  self.materialization.temporary_initializer_expressions.contains(
    handle.index(),
  )
}

///|
fn NagaCompatFunctionPlan::contains_materialized_expression(
  self : NagaCompatFunctionPlan,
  handle : Handle,
) -> Bool {
  self.materialization.materialized_expressions.contains(handle.index())
}

///|
fn NagaCompatFunctionPlan::elided_local_alias_target(
  self : NagaCompatFunctionPlan,
  handle : Handle,
) -> Handle? {
  self.materialization.elided_local_alias_targets.get(handle.index())
}

///|
fn NagaCompatFunctionPlan::temporary_index(
  self : NagaCompatFunctionPlan,
  function : Function,
  handle : Handle,
) -> Int {
  wgsl_ir_emit_expression_temporary_index(function, self, handle)
}

///|
fn NagaCompatFunctionPlan::implicit_expression_slot_offset(
  self : NagaCompatFunctionPlan,
  handle : Handle,
) -> Int {
  self.body.implicit_expression_slot_offset(handle)
}

///|
fn NagaCompatFunctionPlan::trace_summary(
  self : NagaCompatFunctionPlan,
  label : String,
) -> String {
  "compat-plan\t\{label}\tarena_exprs=\{self.arena.expression_count}\timplicit_slots=\{self.arena.implicit_expression_slot_count()}\tcalls=\{self.call.call_expression_count}\tcall_results=\{self.call.call_result_expression_count}\tshort_circuit_locals=\{self.short_circuit.result_locals.length()}\tmaterialized=\{self.materialization.materialized_expressions.length()}\ttemporary_inits=\{self.materialization.temporary_initializer_expressions.length()}\telided_aliases=\{self.materialization.elided_local_alias_targets.length()}\tlocal_decls=\{self.names.local_declaration_slots}\ttemp_names=\{self.names.materialized_temporary_slots}\tnamed_exprs=\{self.names.named_expression_slots}\n"
}

///|
fn NagaCompatFunctionPlan::trace_sections(
  self : NagaCompatFunctionPlan,
  label : String,
) -> String {
  let out = StringBuilder::new()
  out.write_string(
    "plan-arena\t\{label}\texpressions=\{self.arena.expression_count}\timplicit_slots=\{self.arena.implicit_expression_slot_count()}\n",
  )
  out.write_string(
    "plan-calls\t\{label}\tcalls=\{self.call.call_expression_count}\tcall_results=\{self.call.call_result_expression_count}\n",
  )
  out.write_string(
    "plan-short-circuit\t\{label}\tresult_locals=\{self.short_circuit.result_locals.length()}\n",
  )
  out.write_string(
    "plan-materialization\t\{label}\tmaterialized=\{self.materialization.materialized_expressions.length()}\ttemporary_inits=\{self.materialization.temporary_initializer_expressions.length()}\telided_aliases=\{self.materialization.elided_local_alias_targets.length()}\n",
  )
  out.write_string(
    "plan-body\t\{label}\tlocal_decls=\{self.names.local_declaration_slots}\tblank_after_locals=\{self.needs_blank_after_local_declarations()}\n",
  )
  out.write_string(
    "plan-names\t\{label}\ttemp_names=\{self.names.materialized_temporary_slots}\tlocal_names=\{self.names.local_declaration_slots}\tnamed_exprs=\{self.names.named_expression_slots}\n",
  )
  out.to_string()
}

///|
fn NagaCompatExpressionArenaPlan::from_function(
  function : Function,
  body : WgslIrNagaFunctionBodyPlan,
) -> NagaCompatExpressionArenaPlan {
  {
    expression_count: function.expressions.items.length(),
    implicit_expression_slots_before: body.implicit_expression_slots_before,
  }
}

///|
fn NagaCompatExpressionArenaPlan::implicit_expression_slot_count(
  self : NagaCompatExpressionArenaPlan,
) -> Int {
  match self.implicit_expression_slots_before.last() {
    Some(value) => value
    None => 0
  }
}

///|
fn NagaCompatCallArgumentPlan::from_function(
  function : Function,
) -> NagaCompatCallArgumentPlan {
  let mut call_expression_count = 0
  let mut call_result_expression_count = 0
  for expression in function.expressions.items {
    match expression {
      FunctionCall(_, _)
      | AtomicCall(_, _)
      | ImageSample(_, _, _, _, _, _, _, _, _)
      | ImageLoad(_, _, _, _, _)
      | ImageQuery(_, _)
      | SubgroupCall(_, _) => call_expression_count += 1
      CallResult(_) | AtomicResult(_, _) => call_result_expression_count += 1
      _ => ()
    }
  }
  { call_expression_count, call_result_expression_count }
}

///|
fn NagaCompatShortCircuitPlan::from_function(
  function : Function,
) -> NagaCompatShortCircuitPlan {
  let result_locals : Array[Int] = []
  for local_index in 0..<function.local_variables.items.length() {
    if function.local_variables.items[local_index].short_circuit_result {
      result_locals.push(local_index)
    }
  }
  { result_locals, }
}

///|
fn NagaCompatMaterializationPlan::from_body_plan(
  body : WgslIrNagaFunctionBodyPlan,
) -> NagaCompatMaterializationPlan {
  {
    materialized_expressions: body.materialized_expressions,
    temporary_initializer_expressions: body.temporary_initializer_expressions,
    elided_local_alias_targets: body.elided_local_alias_targets,
  }
}

///|
fn NagaCompatNamePlan::from_function(
  function : Function,
  body : WgslIrNagaFunctionBodyPlan,
) -> NagaCompatNamePlan {
  {
    materialized_temporary_slots: body.materialized_expressions.length(),
    local_declaration_slots: body.local_declaration_order().length(),
    named_expression_slots: function.named_expressions.length(),
  }
}

///|
