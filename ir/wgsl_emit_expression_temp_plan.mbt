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
fn wgsl_ir_emit_expression_temporary_name_key(
  origin : WgslIrEmitFunctionOrigin,
  handle : Handle,
) -> String {
  match origin {
    UserFunction(function_index) =>
      wgsl_ir_emit_name_key2("fn_expr", function_index, handle.index())
    EntryPointFunction(entry_point_index) =>
      wgsl_ir_emit_name_key2("ep_expr", entry_point_index, handle.index())
  }
}

///|
fn wgsl_ir_emit_local_name_key(
  origin : WgslIrEmitFunctionOrigin,
  handle : Handle,
) -> String {
  match origin {
    UserFunction(function_index) =>
      wgsl_ir_emit_name_key2("fn_local", function_index, handle.index())
    EntryPointFunction(entry_point_index) =>
      wgsl_ir_emit_name_key2("ep_local", entry_point_index, handle.index())
  }
}

///|
priv struct WgslIrNagaFunctionBodyPlan {
  materialized_expressions : @set.Set[Int]
  local_variable_declarations : Array[Int]
  has_body_after_hoisted_declarations : Bool
}

///|
priv struct WgslIrNagaStatementPlanItem {
  statement : Statement
  skip : Bool
  blank_before : Bool
}

///|
fn WgslIrNagaFunctionBodyPlan::from_function(
  function : Function,
) -> WgslIrNagaFunctionBodyPlan {
  WgslIrNagaFunctionBodyPlan::{
    materialized_expressions: wgsl_ir_function_materialized_expression_indices(
      function,
    ),
    local_variable_declarations: wgsl_ir_naga_function_body_local_declarations(
      function,
    ),
    has_body_after_hoisted_declarations: wgsl_ir_naga_function_body_has_non_hoisted_statement(
      function,
    ),
  }
}

///|
fn WgslIrNagaFunctionBodyPlan::contains_materialized_expression(
  self : WgslIrNagaFunctionBodyPlan,
  handle : Handle,
) -> Bool {
  self.materialized_expressions.contains(handle.index())
}

///|
fn WgslIrNagaFunctionBodyPlan::temporary_index(
  self : WgslIrNagaFunctionBodyPlan,
  function : Function,
  handle : Handle,
) -> Int {
  wgsl_ir_emit_expression_temporary_index(function, self, handle)
}

///|
fn WgslIrNagaFunctionBodyPlan::local_declaration_order(
  self : WgslIrNagaFunctionBodyPlan,
) -> Array[Int] {
  self.local_variable_declarations
}

///|
fn WgslIrNagaFunctionBodyPlan::needs_blank_after_local_declarations(
  self : WgslIrNagaFunctionBodyPlan,
) -> Bool {
  self.local_variable_declarations.length() > 0 &&
  self.has_body_after_hoisted_declarations
}

///|
fn WgslIrNagaFunctionBodyPlan::statement_plan(
  self : WgslIrNagaFunctionBodyPlan,
  function : Function,
  block : Block,
) -> Array[WgslIrNagaStatementPlanItem] {
  ignore(self)
  let plan : Array[WgslIrNagaStatementPlanItem] = []
  let mut emitted_leading_var_declaration = false
  let mut separated_leading_var_declarations = false
  for statement in block.statements {
    let skip = wgsl_ir_statement_is_naga_hoisted_local_var_declaration(
      function, statement,
    )
    let mut blank_before = false
    if !skip {
      if emitted_leading_var_declaration &&
        !separated_leading_var_declarations &&
        !wgsl_ir_statement_is_any_local_var_declaration(function, statement) {
        blank_before = true
        separated_leading_var_declarations = true
      }
      if !separated_leading_var_declarations &&
        wgsl_ir_statement_is_any_local_var_declaration(function, statement) {
        emitted_leading_var_declaration = true
      }
    }
    plan.push(WgslIrNagaStatementPlanItem::{ statement, skip, blank_before })
  }
  plan
}

///|
fn wgsl_ir_naga_function_body_local_declarations(
  function : Function,
) -> Array[Int] {
  let order : Array[Int] = []
  for index in 0..<function.local_variables.items.length() {
    match function.local_variables.items.get(index) {
      Some(local_var) =>
        if local_var.kind == LocalVariableKind::Var &&
          !local_var.generated_temporary {
          order.push(index)
        }
      None => ()
    }
  }
  order
}

///|
fn wgsl_ir_naga_function_body_has_non_hoisted_statement(
  function : Function,
) -> Bool {
  for statement in function.body.statements {
    if !wgsl_ir_statement_is_naga_hoisted_local_var_declaration(
        function, statement,
      ) {
      return true
    }
  }
  false
}

///|
fn wgsl_ir_statement_is_any_local_var_declaration(
  function : Function,
  statement : Statement,
) -> Bool {
  match statement {
    Declare(handle) =>
      match function.local_variables.items.get(handle.index()) {
        Some(local_var) => local_var.kind == LocalVariableKind::Var
        None => false
      }
    _ => false
  }
}

///|
fn wgsl_ir_statement_is_naga_hoisted_local_var_declaration(
  function : Function,
  statement : Statement,
) -> Bool {
  match statement {
    Declare(handle) =>
      match function.local_variables.items.get(handle.index()) {
        Some(local_var) =>
          local_var.kind == LocalVariableKind::Var &&
          !local_var.generated_temporary
        None => false
      }
    _ => false
  }
}

///|
fn WgslIrFinalNamePlan::allocate_function_body_names_from_arena(
  self : WgslIrFinalNamePlan,
  origin : WgslIrEmitFunctionOrigin,
  function : Function,
  body_plan : WgslIrNagaFunctionBodyPlan,
  namer : WgslIrNagaNamer,
) -> Unit {
  let temp_namer = WgslIrNagaNamer::WgslIrNagaNamer()
  self.allocate_function_expression_temporary_names(
    origin, function, body_plan, temp_namer,
  )
  for local_index in 0..<function.local_variables.items.length() {
    let local_handle = Handle::Handle(local_index)
    let local_var = function.local_variables.items[local_index]
    let local_name = if local_var.generated_temporary {
      match local_var.init {
        Some(init) =>
          self.names.get(
            wgsl_ir_emit_expression_temporary_name_key(origin, init),
          )
        None => None
      }
    } else {
      Some(namer.local_call_or(temp_namer, local_var.name, "local"))
    }
    match local_name {
      Some(name) =>
        self.names.set(wgsl_ir_emit_local_name_key(origin, local_handle), name)
      None => ()
    }
  }
}

///|
fn WgslIrFinalNamePlan::allocate_function_expression_temporary_names(
  self : WgslIrFinalNamePlan,
  origin : WgslIrEmitFunctionOrigin,
  function : Function,
  body_plan : WgslIrNagaFunctionBodyPlan,
  temp_namer : WgslIrNagaNamer,
) -> Unit {
  for expr_index in 0..<function.expressions.items.length() {
    let handle = Handle::Handle(expr_index)
    if body_plan.contains_materialized_expression(handle) {
      let key = wgsl_ir_emit_expression_temporary_name_key(origin, handle)
      if self.names.get(key) == None {
        let semantic_index = body_plan.temporary_index(function, handle)
        self.names.set(key, temp_namer.call("_e\{semantic_index}"))
      }
    }
  }
}

///|
fn wgsl_ir_function_materialized_expression_indices(
  function : Function,
) -> @set.Set[Int] {
  let indices : @set.Set[Int] = @set.Set([])
  for local_var in function.local_variables.items {
    if local_var.generated_temporary {
      match local_var.init {
        Some(init) => indices.add(init.index())
        None => ()
      }
    }
  }
  wgsl_ir_collect_statement_materialized_expression_indices(
    function.body,
    indices,
  )
  for expr_index in 0..<function.expressions.items.length() {
    match function.expressions.items.get(expr_index) {
      Some(CallResult(_)) => indices.add(expr_index)
      _ => ()
    }
  }
  indices
}

///|
fn wgsl_ir_collect_statement_materialized_expression_indices(
  block : Block,
  indices : @set.Set[Int],
) -> Unit {
  for statement in block.statements {
    match statement {
      Block(child) =>
        wgsl_ir_collect_statement_materialized_expression_indices(
          child, indices,
        )
      If(_, accept, reject) => {
        wgsl_ir_collect_statement_materialized_expression_indices(
          accept, indices,
        )
        wgsl_ir_collect_statement_materialized_expression_indices(
          reject, indices,
        )
      }
      Switch(_, cases) =>
        for case in cases {
          wgsl_ir_collect_statement_materialized_expression_indices(
            case.body,
            indices,
          )
        }
      Loop(body, continuing, _) => {
        wgsl_ir_collect_statement_materialized_expression_indices(body, indices)
        wgsl_ir_collect_statement_materialized_expression_indices(
          continuing, indices,
        )
      }
      Call(_, _, Some(result)) => indices.add(result.index())
      _ => ()
    }
  }
}

///|
fn wgsl_ir_emit_expression_temporary_index(
  function : Function,
  body_plan : WgslIrNagaFunctionBodyPlan,
  handle : Handle,
) -> Int {
  let mut skipped = 0
  let current_is_call_result = match
    function.expressions.items.get(handle.index()) {
    Some(CallResult(_)) => true
    _ => false
  }
  for index in 0..<handle.index() {
    let expression_handle = Handle::Handle(index)
    if wgsl_ir_function_expression_is_synthetic_local_reference(
        function, expression_handle,
      ) ||
      (
        current_is_call_result &&
        wgsl_ir_function_expression_is_unmaterialized_function_argument_reference(
          function, expression_handle, handle,
        )
      ) ||
      (
        !current_is_call_result &&
        wgsl_ir_emit_expression_is_call_result(function, expression_handle)
      ) ||
      wgsl_ir_function_expression_is_atomic_compare_exchange_projection_role(
        function, expression_handle,
      ) {
      skipped += 1
    }
  }
  let base_index = handle.index() - skipped
  let base_index = if wgsl_ir_emit_expression_is_adjacent_materialized_load_after_generated_snapshot(
      function, handle,
    ) {
    base_index - 1
  } else {
    base_index
  }
  base_index +
  wgsl_ir_emit_projected_temporary_slot_offset(function, body_plan, handle)
}

///|
fn wgsl_ir_emit_expression_is_call_result(
  function : Function,
  handle : Handle,
) -> Bool {
  match function.expressions.items.get(handle.index()) {
    Some(CallResult(_)) => true
    _ => false
  }
}

///|
fn wgsl_ir_emit_projected_temporary_slot_offset(
  function : Function,
  body_plan : WgslIrNagaFunctionBodyPlan,
  limit : Handle,
) -> Int {
  let mut offset = 0
  for index in 0..<limit.index() {
    if body_plan.contains_materialized_expression(Handle::Handle(index)) &&
      wgsl_ir_emit_materialized_expression_has_projected_use_before(
        function,
        Handle::Handle(index),
        limit,
      ) {
      offset += wgsl_ir_emit_projected_temporary_expression_slots(
        function,
        Handle::Handle(index),
      )
    }
  }
  offset
}

///|
fn wgsl_ir_emit_materialized_expression_has_projected_use_before(
  function : Function,
  materialized : Handle,
  limit : Handle,
) -> Bool {
  for index in (materialized.index() + 1)..<limit.index() {
    match function.expressions.items.get(index) {
      Some(Access(base, _))
      | Some(AccessIndex(base, _))
      | Some(Swizzle(_, base, _)) => if base == materialized { return true }
      _ => ()
    }
  }
  false
}

///|
fn wgsl_ir_emit_projected_temporary_expression_slots(
  function : Function,
  handle : Handle,
) -> Int {
  match function.expressions.items.get(handle.index()) {
    Some(ImageQuery(_, _)) => 1
    Some(ImageLoad(_, _, _, _, _)) => 0
    Some(AtomicCall(CompareExchangeWeak, _)) => 1
    Some(LocalVariable(local_handle)) =>
      match function.local_variables.items.get(local_handle.index()) {
        Some(local_var) =>
          match local_var.init {
            Some(init) =>
              wgsl_ir_emit_projected_temporary_expression_slots(function, init)
            None => 2
          }
        None => 2
      }
    _ => 2
  }
}

///|
fn wgsl_ir_emit_expression_is_adjacent_materialized_load_after_generated_snapshot(
  function : Function,
  handle : Handle,
) -> Bool {
  if handle.index() == 0 {
    return false
  }
  guard function.expressions.items.get(handle.index()) is Some(Load(_)) else {
    return false
  }
  guard function.expressions.items.get(handle.index() - 1)
    is Some(LocalVariable(local_handle)) else {
    return false
  }
  guard function.local_variables.items.get(local_handle.index())
    is Some(local_var) else {
    return false
  }
  guard local_var.generated_temporary else { return false }
  match local_var.init {
    Some(init) =>
      match function.expressions.items.get(init.index()) {
        Some(Load(_)) => true
        _ => false
      }
    None => false
  }
}
