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
  implicit_expression_slots_before : Array[Int]
  struct_value_store_pointers : @set.Set[Int]
}

///|
priv struct WgslIrNagaStatementPlanItem {
  statement : Statement
  skip : Bool
  blank_before : Bool
}

///|
fn WgslIrNagaFunctionBodyPlan::from_function(
  shader_module : Module,
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
    implicit_expression_slots_before: wgsl_ir_naga_function_implicit_expression_slots_before(
      shader_module, function,
    ),
    struct_value_store_pointers: wgsl_ir_naga_function_struct_value_store_pointer_indices(
      shader_module, function,
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
fn WgslIrNagaFunctionBodyPlan::implicit_expression_slot_offset(
  self : WgslIrNagaFunctionBodyPlan,
  handle : Handle,
) -> Int {
  match self.implicit_expression_slots_before.get(handle.index()) {
    Some(value) => value
    None => 0
  }
}

///|
fn WgslIrNagaFunctionBodyPlan::contains_struct_value_store_pointer(
  self : WgslIrNagaFunctionBodyPlan,
  pointer : Handle,
) -> Bool {
  self.struct_value_store_pointers.contains(pointer.index())
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
        if self.names.get(wgsl_ir_emit_local_name_key(origin, local_handle)) ==
          None {
          self.names.set(
            wgsl_ir_emit_local_name_key(origin, local_handle),
            name,
          )
        }
      None => ()
    }
  }
}

///|
fn WgslIrFinalNamePlan::reserve_function_var_local_names_from_arena(
  self : WgslIrFinalNamePlan,
  origin : WgslIrEmitFunctionOrigin,
  function : Function,
  namer : WgslIrNagaNamer,
) -> Unit {
  let temp_namer = WgslIrNagaNamer::WgslIrNagaNamer()
  for local_index in 0..<function.local_variables.items.length() {
    let local_handle = Handle::Handle(local_index)
    let local_var = function.local_variables.items[local_index]
    if local_var.kind == LocalVariableKind::Var &&
      !local_var.generated_temporary {
      let key = wgsl_ir_emit_local_name_key(origin, local_handle)
      if self.names.get(key) == None {
        self.names.set(
          key,
          namer.local_call_or(temp_namer, local_var.name, "local"),
        )
      }
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
        current_is_call_result &&
        wgsl_ir_function_expression_is_unmaterialized_call_result_projection_argument(
          function, expression_handle, handle,
        )
      ) ||
      (
        current_is_call_result &&
        wgsl_ir_function_expression_is_absorbed_store_projected_call_argument_base(
          function, body_plan, expression_handle, handle,
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
  let local_store_offset = if current_is_call_result {
    0
  } else {
    wgsl_ir_emit_local_var_store_value_slot_offset(function, body_plan, handle)
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
  body_plan.implicit_expression_slot_offset(handle) +
  wgsl_ir_emit_implicit_naga_load_slot_offset(function, body_plan, handle) +
  local_store_offset +
  wgsl_ir_emit_projected_temporary_slot_offset(function, body_plan, handle)
}

///|
fn wgsl_ir_naga_function_implicit_expression_slots_before(
  shader_module : Module,
  function : Function,
) -> Array[Int] {
  let offsets : Array[Int] = []
  let mut offset = 0
  for index in 0..<function.expressions.items.length() {
    offsets.push(offset)
    match function.expressions.items.get(index) {
      Some(Compose(ty, components)) =>
        offset += wgsl_ir_naga_compose_implicit_expression_slots(
          shader_module, ty, components,
        )
      _ => ()
    }
  }
  offsets
}

///|
fn wgsl_ir_naga_compose_implicit_expression_slots(
  shader_module : Module,
  ty : Handle,
  components : Array[Handle],
) -> Int {
  match shader_module.types.items.get(ty.index()) {
    Some(type_) =>
      match type_.inner {
        Matrix(columns, rows, _) =>
          if components.length() == columns.width() * rows.width() {
            columns.width()
          } else {
            0
          }
        _ => 0
      }
    None => 0
  }
}

///|
fn wgsl_ir_naga_function_struct_value_store_pointer_indices(
  shader_module : Module,
  function : Function,
) -> @set.Set[Int] {
  let pointers : @set.Set[Int] = @set.Set([])
  wgsl_ir_collect_struct_value_store_pointer_indices(
    shader_module,
    function,
    function.body,
    pointers,
  )
  pointers
}

///|
fn wgsl_ir_collect_struct_value_store_pointer_indices(
  shader_module : Module,
  function : Function,
  block : Block,
  pointers : @set.Set[Int],
) -> Unit {
  for statement in block.statements {
    match statement {
      Store(pointer, _) =>
        if wgsl_ir_naga_function_pointer_value_is_struct(
            shader_module, function, pointer,
          ) {
          pointers.add(pointer.index())
        }
      Block(child) =>
        wgsl_ir_collect_struct_value_store_pointer_indices(
          shader_module, function, child, pointers,
        )
      If(_, accept, reject) => {
        wgsl_ir_collect_struct_value_store_pointer_indices(
          shader_module, function, accept, pointers,
        )
        wgsl_ir_collect_struct_value_store_pointer_indices(
          shader_module, function, reject, pointers,
        )
      }
      Switch(_, cases) =>
        for case in cases {
          wgsl_ir_collect_struct_value_store_pointer_indices(
            shader_module,
            function,
            case.body,
            pointers,
          )
        }
      Loop(body, continuing, _) => {
        wgsl_ir_collect_struct_value_store_pointer_indices(
          shader_module, function, body, pointers,
        )
        wgsl_ir_collect_struct_value_store_pointer_indices(
          shader_module, function, continuing, pointers,
        )
      }
      _ => ()
    }
  }
}

///|
fn wgsl_ir_naga_function_pointer_value_is_struct(
  shader_module : Module,
  function : Function,
  pointer : Handle,
) -> Bool {
  match
    wgsl_ir_naga_function_expression_value_type(
      shader_module, function, pointer,
    ) {
    Some(ty) =>
      match shader_module.types.items.get(ty.index()) {
        Some(type_) =>
          match type_.inner {
            Struct(_, _) | PredeclaredStruct(_, _) => true
            _ => false
          }
        None => false
      }
    None => false
  }
}

///|
fn wgsl_ir_naga_function_expression_value_type(
  shader_module : Module,
  function : Function,
  handle : Handle,
) -> Handle? {
  match function.expressions.items.get(handle.index()) {
    Some(LocalVariable(local_handle)) =>
      match function.local_variables.items.get(local_handle.index()) {
        Some(local_var) => Some(local_var.ty)
        None => None
      }
    Some(FunctionArgument(index)) =>
      match function.arguments.get(index) {
        Some(argument) => Some(argument.ty)
        None => None
      }
    Some(Load(inner)) =>
      wgsl_ir_naga_function_expression_value_type(
        shader_module, function, inner,
      )
    Some(AccessIndex(base, member_index)) =>
      match
        wgsl_ir_naga_function_expression_value_type(
          shader_module, function, base,
        ) {
        Some(base_ty) =>
          match shader_module.types.items.get(base_ty.index()) {
            Some({ inner: Struct(members, _), .. })
            | Some({ inner: PredeclaredStruct(members, _), .. }) =>
              match members.get(member_index) {
                Some(field) => Some(field.ty)
                None => None
              }
            _ => None
          }
        None => None
      }
    _ => None
  }
}

///|
fn wgsl_ir_function_expression_is_unmaterialized_call_result_projection_argument(
  function : Function,
  handle : Handle,
  result : Handle,
) -> Bool {
  wgsl_ir_function_expression_is_projection_of_generated_temporary(
    function, handle,
  ) &&
  wgsl_ir_function_call_result_uses_direct_argument(
    function,
    function.body,
    handle,
    result,
  )
}

///|
fn wgsl_ir_function_call_result_uses_direct_argument(
  function : Function,
  block : Block,
  argument : Handle,
  result : Handle,
) -> Bool {
  for statement in block.statements {
    match statement {
      Call(_, arguments, Some(call_result)) =>
        if call_result == result {
          for item in arguments {
            if item == argument {
              return true
            }
          }
        }
      Block(child) =>
        if wgsl_ir_function_call_result_uses_direct_argument(
            function, child, argument, result,
          ) {
          return true
        }
      If(_, accept, reject) =>
        if wgsl_ir_function_call_result_uses_direct_argument(
            function, accept, argument, result,
          ) ||
          wgsl_ir_function_call_result_uses_direct_argument(
            function, reject, argument, result,
          ) {
          return true
        }
      Switch(_, cases) =>
        for case in cases {
          if wgsl_ir_function_call_result_uses_direct_argument(
              function,
              case.body,
              argument,
              result,
            ) {
            return true
          }
        }
      Loop(body, continuing, _) =>
        if wgsl_ir_function_call_result_uses_direct_argument(
            function, body, argument, result,
          ) ||
          wgsl_ir_function_call_result_uses_direct_argument(
            function, continuing, argument, result,
          ) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn wgsl_ir_function_expression_is_absorbed_store_projected_call_argument_base(
  function : Function,
  body_plan : WgslIrNagaFunctionBodyPlan,
  handle : Handle,
  result : Handle,
) -> Bool {
  !body_plan.contains_materialized_expression(handle) &&
  wgsl_ir_function_expression_is_projection_graph_node(function, handle) &&
  wgsl_ir_function_call_result_is_store_value(function.body, result) &&
  wgsl_ir_function_call_result_has_projected_argument_containing(
    function,
    function.body,
    handle,
    result,
  ) &&
  wgsl_ir_function_call_result_has_absorbed_direct_local_store(
    function, body_plan, result,
  )
}

///|
fn wgsl_ir_function_call_result_has_absorbed_direct_local_store(
  function : Function,
  body_plan : WgslIrNagaFunctionBodyPlan,
  result : Handle,
) -> Bool {
  wgsl_ir_function_call_result_has_absorbed_direct_local_store_in_block(
    function,
    body_plan,
    function.body,
    result,
  )
}

///|
fn wgsl_ir_function_call_result_has_absorbed_direct_local_store_in_block(
  function : Function,
  body_plan : WgslIrNagaFunctionBodyPlan,
  block : Block,
  result : Handle,
) -> Bool {
  for statement in block.statements {
    if wgsl_ir_function_call_result_has_absorbed_direct_local_store_in_statement(
        function, body_plan, statement, result,
      ) {
      return true
    }
  }
  false
}

///|
fn wgsl_ir_function_call_result_has_absorbed_direct_local_store_in_statement(
  function : Function,
  body_plan : WgslIrNagaFunctionBodyPlan,
  statement : Statement,
  result : Handle,
) -> Bool {
  match statement {
    Store(pointer, _) =>
      pointer.index() < result.index() &&
      wgsl_ir_emit_direct_local_store_slot_is_absorbed_by_call_argument_materialization(
        function, body_plan, pointer, result,
      )
    Block(child) =>
      wgsl_ir_function_call_result_has_absorbed_direct_local_store_in_block(
        function, body_plan, child, result,
      )
    If(_, accept, reject) =>
      wgsl_ir_function_call_result_has_absorbed_direct_local_store_in_block(
        function, body_plan, accept, result,
      ) ||
      wgsl_ir_function_call_result_has_absorbed_direct_local_store_in_block(
        function, body_plan, reject, result,
      )
    Switch(_, cases) => {
      for case in cases {
        if wgsl_ir_function_call_result_has_absorbed_direct_local_store_in_block(
            function,
            body_plan,
            case.body,
            result,
          ) {
          return true
        }
      }
      false
    }
    Loop(body, continuing, _) =>
      wgsl_ir_function_call_result_has_absorbed_direct_local_store_in_block(
        function, body_plan, body, result,
      ) ||
      wgsl_ir_function_call_result_has_absorbed_direct_local_store_in_block(
        function, body_plan, continuing, result,
      )
    _ => false
  }
}

///|
fn wgsl_ir_function_call_result_is_store_value(
  block : Block,
  result : Handle,
) -> Bool {
  for statement in block.statements {
    match statement {
      Store(_, value) => if value == result { return true }
      Block(child) =>
        if wgsl_ir_function_call_result_is_store_value(child, result) {
          return true
        }
      If(_, accept, reject) =>
        if wgsl_ir_function_call_result_is_store_value(accept, result) ||
          wgsl_ir_function_call_result_is_store_value(reject, result) {
          return true
        }
      Switch(_, cases) =>
        for case in cases {
          if wgsl_ir_function_call_result_is_store_value(case.body, result) {
            return true
          }
        }
      Loop(body, continuing, _) =>
        if wgsl_ir_function_call_result_is_store_value(body, result) ||
          wgsl_ir_function_call_result_is_store_value(continuing, result) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn wgsl_ir_function_expression_is_projection_graph_node(
  function : Function,
  handle : Handle,
) -> Bool {
  match function.expressions.items.get(handle.index()) {
    Some(Load(_))
    | Some(Access(_, _))
    | Some(AccessIndex(_, _))
    | Some(Swizzle(_, _, _)) => true
    _ => false
  }
}

///|
fn wgsl_ir_function_call_result_has_projected_argument_containing(
  function : Function,
  block : Block,
  handle : Handle,
  result : Handle,
) -> Bool {
  for statement in block.statements {
    match statement {
      Call(_, arguments, Some(call_result)) =>
        if call_result == result {
          for argument in arguments {
            if wgsl_ir_function_expression_is_projection_of_generated_temporary(
                function, argument,
              ) &&
              wgsl_ir_function_expression_graph_contains(
                function, argument, handle,
              ) {
              return true
            }
          }
        }
      Block(child) =>
        if wgsl_ir_function_call_result_has_projected_argument_containing(
            function, child, handle, result,
          ) {
          return true
        }
      If(_, accept, reject) =>
        if wgsl_ir_function_call_result_has_projected_argument_containing(
            function, accept, handle, result,
          ) ||
          wgsl_ir_function_call_result_has_projected_argument_containing(
            function, reject, handle, result,
          ) {
          return true
        }
      Switch(_, cases) =>
        for case in cases {
          if wgsl_ir_function_call_result_has_projected_argument_containing(
              function,
              case.body,
              handle,
              result,
            ) {
            return true
          }
        }
      Loop(body, continuing, _) =>
        if wgsl_ir_function_call_result_has_projected_argument_containing(
            function, body, handle, result,
          ) ||
          wgsl_ir_function_call_result_has_projected_argument_containing(
            function, continuing, handle, result,
          ) {
          return true
        }
      _ => ()
    }
  }
  false
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
fn wgsl_ir_emit_implicit_naga_load_slot_offset(
  function : Function,
  body_plan : WgslIrNagaFunctionBodyPlan,
  limit : Handle,
) -> Int {
  let mut offset = 0
  for index in 0..<=limit.index() {
    let handle = Handle::Handle(index)
    if body_plan.contains_materialized_expression(handle) &&
      wgsl_ir_emit_expression_has_implicit_naga_load_slot(function, handle) {
      offset += 1
    }
  }
  offset
}

///|
fn wgsl_ir_emit_expression_has_implicit_naga_load_slot(
  function : Function,
  handle : Handle,
) -> Bool {
  match function.expressions.items.get(handle.index()) {
    Some(AccessIndex(base, _)) =>
      wgsl_ir_emit_expression_is_dynamic_pointer_access(function, base)
    _ => false
  }
}

///|
fn wgsl_ir_emit_expression_is_dynamic_pointer_access(
  function : Function,
  handle : Handle,
) -> Bool {
  match function.expressions.items.get(handle.index()) {
    Some(Access(_, _)) => true
    Some(AccessIndex(base, _)) =>
      wgsl_ir_emit_expression_is_dynamic_pointer_access(function, base)
    _ => false
  }
}

///|
fn wgsl_ir_emit_local_var_store_value_slot_offset(
  function : Function,
  body_plan : WgslIrNagaFunctionBodyPlan,
  limit : Handle,
) -> Int {
  wgsl_ir_emit_local_var_store_value_slot_offset_in_block(
    function,
    body_plan,
    function.body,
    limit,
  )
}

///|
fn wgsl_ir_emit_local_var_store_value_slot_offset_in_block(
  function : Function,
  body_plan : WgslIrNagaFunctionBodyPlan,
  block : Block,
  limit : Handle,
) -> Int {
  let mut offset = 0
  for statement in block.statements {
    offset += wgsl_ir_emit_local_var_store_value_slot_offset_in_statement(
      function, body_plan, statement, limit,
    )
  }
  offset
}

///|
fn wgsl_ir_emit_local_var_store_value_slot_offset_in_statement(
  function : Function,
  body_plan : WgslIrNagaFunctionBodyPlan,
  statement : Statement,
  limit : Handle,
) -> Int {
  match statement {
    Store(pointer, value) =>
      if pointer.index() < limit.index() &&
        value.index() < limit.index() &&
        wgsl_ir_emit_store_pointer_is_user_local_slot_countable(
          function, body_plan, pointer,
        ) &&
        !wgsl_ir_emit_direct_local_store_slot_is_absorbed_by_call_argument_materialization(
          function, body_plan, pointer, limit,
        ) &&
        wgsl_ir_emit_store_value_is_materialized_user_call_result(
          function, body_plan, value,
        ) {
        1
      } else {
        0
      }
    Block(child) =>
      wgsl_ir_emit_local_var_store_value_slot_offset_in_block(
        function, body_plan, child, limit,
      )
    If(_, accept, reject) =>
      wgsl_ir_emit_local_var_store_value_slot_offset_in_block(
        function, body_plan, accept, limit,
      ) +
      wgsl_ir_emit_local_var_store_value_slot_offset_in_block(
        function, body_plan, reject, limit,
      )
    Switch(_, cases) => {
      let mut offset = 0
      for case in cases {
        offset += wgsl_ir_emit_local_var_store_value_slot_offset_in_block(
          function,
          body_plan,
          case.body,
          limit,
        )
      }
      offset
    }
    Loop(body, continuing, _) =>
      wgsl_ir_emit_local_var_store_value_slot_offset_in_block(
        function, body_plan, body, limit,
      ) +
      wgsl_ir_emit_local_var_store_value_slot_offset_in_block(
        function, body_plan, continuing, limit,
      )
    _ => 0
  }
}

///|
fn wgsl_ir_emit_direct_local_store_slot_is_absorbed_by_call_argument_materialization(
  function : Function,
  body_plan : WgslIrNagaFunctionBodyPlan,
  pointer : Handle,
  limit : Handle,
) -> Bool {
  guard wgsl_ir_emit_store_pointer_is_direct_user_local(function, pointer) else {
    return false
  }
  wgsl_ir_emit_direct_local_store_slot_is_absorbed_in_block(
    function,
    body_plan,
    function.body,
    pointer,
    limit,
  )
}

///|
fn wgsl_ir_emit_direct_local_store_slot_is_absorbed_in_block(
  function : Function,
  body_plan : WgslIrNagaFunctionBodyPlan,
  block : Block,
  pointer : Handle,
  limit : Handle,
) -> Bool {
  for statement in block.statements {
    if wgsl_ir_emit_direct_local_store_slot_is_absorbed_in_statement(
        function, body_plan, statement, pointer, limit,
      ) {
      return true
    }
  }
  false
}

///|
fn wgsl_ir_emit_direct_local_store_slot_is_absorbed_in_statement(
  function : Function,
  body_plan : WgslIrNagaFunctionBodyPlan,
  statement : Statement,
  pointer : Handle,
  limit : Handle,
) -> Bool {
  match statement {
    Call(_, arguments, Some(result)) => {
      if result.index() < limit.index() &&
        wgsl_ir_emit_call_arguments_contain_pointer(
          function, arguments, pointer,
        ) &&
        wgsl_ir_emit_call_arguments_have_independent_materialized_subgraph(
          function, body_plan, arguments, pointer,
        ) {
        return true
      }
      false
    }
    Block(child) =>
      wgsl_ir_emit_direct_local_store_slot_is_absorbed_in_block(
        function, body_plan, child, pointer, limit,
      )
    If(_, accept, reject) =>
      wgsl_ir_emit_direct_local_store_slot_is_absorbed_in_block(
        function, body_plan, accept, pointer, limit,
      ) ||
      wgsl_ir_emit_direct_local_store_slot_is_absorbed_in_block(
        function, body_plan, reject, pointer, limit,
      )
    Switch(_, cases) => {
      for case in cases {
        if wgsl_ir_emit_direct_local_store_slot_is_absorbed_in_block(
            function,
            body_plan,
            case.body,
            pointer,
            limit,
          ) {
          return true
        }
      }
      false
    }
    Loop(body, continuing, _) =>
      wgsl_ir_emit_direct_local_store_slot_is_absorbed_in_block(
        function, body_plan, body, pointer, limit,
      ) ||
      wgsl_ir_emit_direct_local_store_slot_is_absorbed_in_block(
        function, body_plan, continuing, pointer, limit,
      )
    _ => false
  }
}

///|
fn wgsl_ir_emit_call_arguments_contain_pointer(
  function : Function,
  arguments : Array[Handle],
  pointer : Handle,
) -> Bool {
  for argument in arguments {
    if wgsl_ir_function_expression_graph_contains(function, argument, pointer) {
      return true
    }
  }
  false
}

///|
fn wgsl_ir_emit_call_arguments_have_independent_materialized_subgraph(
  function : Function,
  body_plan : WgslIrNagaFunctionBodyPlan,
  arguments : Array[Handle],
  pointer : Handle,
) -> Bool {
  for argument in arguments {
    if !wgsl_ir_function_expression_graph_contains(function, argument, pointer) &&
      wgsl_ir_emit_expression_graph_contains_materialized_handle(
        function, body_plan, argument,
      ) {
      return true
    }
  }
  false
}

///|
fn wgsl_ir_emit_expression_graph_contains_materialized_handle(
  function : Function,
  body_plan : WgslIrNagaFunctionBodyPlan,
  root : Handle,
) -> Bool {
  for index in 0..<function.expressions.items.length() {
    let handle = Handle::Handle(index)
    if body_plan.contains_materialized_expression(handle) &&
      wgsl_ir_function_expression_graph_contains(function, root, handle) {
      return true
    }
  }
  false
}

///|
fn wgsl_ir_emit_store_pointer_is_user_local_slot_countable(
  function : Function,
  body_plan : WgslIrNagaFunctionBodyPlan,
  pointer : Handle,
) -> Bool {
  if wgsl_ir_emit_store_pointer_is_direct_user_local(function, pointer) {
    return true
  }
  wgsl_ir_emit_store_pointer_is_rooted_user_local(function, pointer) &&
  body_plan.contains_struct_value_store_pointer(pointer)
}

///|
fn wgsl_ir_emit_store_pointer_is_direct_user_local(
  function : Function,
  pointer : Handle,
) -> Bool {
  match function.expressions.items.get(pointer.index()) {
    Some(LocalVariable(local_handle)) =>
      match function.local_variables.items.get(local_handle.index()) {
        Some(local_var) =>
          local_var.kind == LocalVariableKind::Var &&
          !local_var.generated_temporary
        None => false
      }
    _ => false
  }
}

///|
fn wgsl_ir_emit_store_pointer_is_rooted_user_local(
  function : Function,
  pointer : Handle,
) -> Bool {
  if wgsl_ir_emit_store_pointer_is_direct_user_local(function, pointer) {
    return true
  }
  match function.expressions.items.get(pointer.index()) {
    Some(Load(base)) =>
      wgsl_ir_emit_store_pointer_is_rooted_user_local(function, base)
    Some(Access(base, _))
    | Some(AccessIndex(base, _))
    | Some(Swizzle(_, base, _)) =>
      wgsl_ir_emit_store_pointer_is_rooted_user_local(function, base)
    _ => false
  }
}

///|
fn wgsl_ir_emit_store_value_is_materialized_user_call_result(
  function : Function,
  body_plan : WgslIrNagaFunctionBodyPlan,
  value : Handle,
) -> Bool {
  if body_plan.contains_materialized_expression(value) &&
    wgsl_ir_emit_expression_is_call_result(function, value) {
    return true
  }
  match function.expressions.items.get(value.index()) {
    Some(LocalVariable(local_handle)) =>
      match function.local_variables.items.get(local_handle.index()) {
        Some(local_var) =>
          if local_var.generated_temporary {
            match local_var.init {
              Some(init) =>
                body_plan.contains_materialized_expression(init) &&
                wgsl_ir_emit_expression_is_call_result(function, init)
              None => false
            }
          } else {
            false
          }
        None => false
      }
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
    let handle = Handle::Handle(index)
    if body_plan.contains_materialized_expression(handle) &&
      wgsl_ir_emit_materialized_expression_has_projected_use_before(
        function, handle, limit,
      ) &&
      !wgsl_ir_emit_projected_materialized_expression_is_current_call_argument(
        function, handle, limit,
      ) {
      offset += wgsl_ir_emit_projected_temporary_expression_slots(
        function, handle,
      )
    }
  }
  offset
}

///|
fn wgsl_ir_emit_projected_materialized_expression_is_current_call_argument(
  function : Function,
  materialized : Handle,
  limit : Handle,
) -> Bool {
  match function.expressions.items.get(limit.index()) {
    Some(CallResult(_)) =>
      wgsl_ir_function_call_result_has_argument_projection_containing(
        function,
        function.body,
        materialized,
        limit,
      )
    _ => false
  }
}

///|
fn wgsl_ir_function_call_result_has_argument_projection_containing(
  function : Function,
  block : Block,
  handle : Handle,
  result : Handle,
) -> Bool {
  for statement in block.statements {
    match statement {
      Call(_, arguments, Some(call_result)) =>
        if call_result == result {
          for argument in arguments {
            if wgsl_ir_function_expression_is_projection_graph_node(
                function, argument,
              ) &&
              wgsl_ir_function_expression_graph_contains(
                function, argument, handle,
              ) {
              return true
            }
          }
        }
      Block(child) =>
        if wgsl_ir_function_call_result_has_argument_projection_containing(
            function, child, handle, result,
          ) {
          return true
        }
      If(_, accept, reject) =>
        if wgsl_ir_function_call_result_has_argument_projection_containing(
            function, accept, handle, result,
          ) ||
          wgsl_ir_function_call_result_has_argument_projection_containing(
            function, reject, handle, result,
          ) {
          return true
        }
      Switch(_, cases) =>
        for case in cases {
          if wgsl_ir_function_call_result_has_argument_projection_containing(
              function,
              case.body,
              handle,
              result,
            ) {
            return true
          }
        }
      Loop(body, continuing, _) =>
        if wgsl_ir_function_call_result_has_argument_projection_containing(
            function, body, handle, result,
          ) ||
          wgsl_ir_function_call_result_has_argument_projection_containing(
            function, continuing, handle, result,
          ) {
          return true
        }
      _ => ()
    }
  }
  false
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
    Some(Load(_))
    | Some(Access(_, _))
    | Some(AccessIndex(_, _))
    | Some(Swizzle(_, _, _)) => 0
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
  guard !local_var.generated_temporary_store_value_reference else {
    return false
  }
  match local_var.init {
    Some(init) =>
      match function.expressions.items.get(init.index()) {
        Some(Load(_)) => true
        _ => false
      }
    None => false
  }
}
