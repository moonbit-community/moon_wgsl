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
priv struct BodyEmissionPlanner {
  elided_local_alias_targets : Map[Int, Handle]
}

///|
priv struct WgslIrNagaStatementPlanItem {
  statement : Statement
  skip : Bool
  blank_before : Bool
}

///|
fn BodyEmissionPlanner::from_function(
  elided_local_alias_targets : Map[Int, Handle],
) -> BodyEmissionPlanner {
  { elided_local_alias_targets, }
}

///|
fn BodyEmissionPlanner::statement_plan(
  self : BodyEmissionPlanner,
  function : Function,
  block : Block,
) -> Array[WgslIrNagaStatementPlanItem] {
  let plan : Array[WgslIrNagaStatementPlanItem] = []
  let mut emitted_leading_var_declaration = false
  let mut separated_leading_var_declarations = false
  for statement in block.statements {
    let skip = self.statement_is_elided_local_alias_declaration(statement) ||
      wgsl_ir_body_statement_is_hoisted_local_var_declaration(
        function, statement,
      )
    let mut blank_before = false
    if !skip {
      if emitted_leading_var_declaration &&
        !separated_leading_var_declarations &&
        !wgsl_ir_body_statement_is_any_local_var_declaration(
          function, statement,
        ) {
        blank_before = true
        separated_leading_var_declarations = true
      }
      if !separated_leading_var_declarations &&
        wgsl_ir_body_statement_is_any_local_var_declaration(function, statement) {
        emitted_leading_var_declaration = true
      }
    }
    plan.push({ statement, skip, blank_before })
  }
  plan
}

///|
fn BodyEmissionPlanner::statement_is_elided_local_alias_declaration(
  self : BodyEmissionPlanner,
  statement : Statement,
) -> Bool {
  match statement {
    Declare(handle) =>
      self.elided_local_alias_targets.get(handle.index()) != None
    _ => false
  }
}

///|
fn wgsl_ir_body_statement_is_any_local_var_declaration(
  function : Function,
  statement : Statement,
) -> Bool {
  match statement {
    Declare(handle) =>
      match function.local_variables.items.get(handle.index()) {
        Some(local_var) => local_var.kind == Var
        None => false
      }
    _ => false
  }
}

///|
fn wgsl_ir_body_statement_is_hoisted_local_var_declaration(
  function : Function,
  statement : Statement,
) -> Bool {
  match statement {
    Declare(handle) =>
      match function.local_variables.items.get(handle.index()) {
        Some(local_var) =>
          local_var.kind == Var && !local_var.generated_temporary
        None => false
      }
    _ => false
  }
}

///|
fn BodyEmissionPlanner::push_named_expression_emit_ranges(
  block : Block,
  function : Function,
  expression_mark : Int,
  init_handle : Handle,
) -> Unit {
  BodyEmissionPlanner::push_statement_emit_ranges(
    block, function, expression_mark, init_handle,
  )
}

///|
fn BodyEmissionPlanner::push_statement_emit_ranges(
  block : Block,
  function : Function,
  expression_mark : Int,
  init_handle : Handle,
) -> Unit {
  let mut range_start : Handle? = None
  let mut range_end : Handle? = None
  for index in expression_mark..<=init_handle.index() {
    match function.expressions.items.get(index) {
      Some(expression) =>
        if wgsl_ir_expression_is_naga_emit_leaf(expression) {
          BodyEmissionPlanner::flush_named_expression_emit_range(
            block, range_start, range_end,
          )
          range_start = None
          range_end = None
        } else {
          let handle = Handle::Handle(index)
          if range_start == None {
            range_start = Some(handle)
          }
          range_end = Some(handle)
        }
      None => ()
    }
  }
  BodyEmissionPlanner::flush_named_expression_emit_range(
    block, range_start, range_end,
  )
}

///|
fn BodyEmissionPlanner::push_statement_emit_ranges_skipping(
  block : Block,
  function : Function,
  expression_mark : Int,
  init_handle : Handle,
  suppressed : @set.Set[Int],
) -> Unit {
  let mut range_start : Handle? = None
  let mut range_end : Handle? = None
  for index in expression_mark..<=init_handle.index() {
    match function.expressions.items.get(index) {
      Some(expression) =>
        if suppressed.contains(index) ||
          wgsl_ir_expression_is_naga_emit_leaf(expression) {
          BodyEmissionPlanner::flush_named_expression_emit_range(
            block, range_start, range_end,
          )
          range_start = None
          range_end = None
        } else {
          let handle = Handle::Handle(index)
          if range_start == None {
            range_start = Some(handle)
          }
          range_end = Some(handle)
        }
      None => ()
    }
  }
  BodyEmissionPlanner::flush_named_expression_emit_range(
    block, range_start, range_end,
  )
}

///|
fn BodyEmissionPlanner::flush_named_expression_emit_range(
  block : Block,
  range_start : Handle?,
  range_end : Handle?,
) -> Unit {
  match (range_start, range_end) {
    (Some(start), Some(end)) =>
      if !BodyEmissionPlanner::block_contains_emit_range(block, start, end) {
        block.push(Emit(HandleRange(start, end)))
      }
    _ => ()
  }
}

///|
fn BodyEmissionPlanner::block_contains_emit_range(
  block : Block,
  start : Handle,
  end : Handle,
) -> Bool {
  for statement in block.statements {
    match statement {
      Emit(range) => if range.start == start && range.end == end { return true }
      _ => ()
    }
  }
  false
}

///|
fn BodyEmissionPlanner::block_contains_expression_emit(
  block : Block,
  handle : Handle,
) -> Bool {
  for statement in block.statements {
    match statement {
      Emit(range) =>
        if range.start.index() <= handle.index() &&
          handle.index() <= range.end.index() {
          return true
        }
      _ => ()
    }
  }
  false
}
