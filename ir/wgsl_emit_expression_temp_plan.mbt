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
fn wgsl_ir_emit_named_expression_name_key(
  origin : WgslIrEmitFunctionOrigin,
  handle : Handle,
) -> String {
  match origin {
    UserFunction(function_index) =>
      wgsl_ir_emit_name_key2("fn_named_expr", function_index, handle.index())
    EntryPointFunction(entry_point_index) =>
      wgsl_ir_emit_name_key2("ep_named_expr", entry_point_index, handle.index())
  }
}

///|
priv struct WgslIrNagaFunctionBodyPlan {
  materialized_expressions : @set.Set[Int]
  elided_local_alias_targets : Map[Int, Handle]
  local_variable_declarations : Array[Int]
  has_body_after_hoisted_declarations : Bool
  implicit_expression_slots_before : Array[Int]
}

///|
priv struct WgslIrNagaStatementPlanItem {
  statement : Statement
  skip : Bool
  blank_before : Bool
}

///|
priv struct WgslIrNagaTemporaryIndexTrace {
  skipped : Int
  base_index : Int
  adjusted_base_index : Int
  implicit_expression_slots_before : Int
  prior_call_projection_argument_slots : Int
  implicit_naga_load_slots : Int
  reused_resource_operand_slots : Int
  projected_temporary_slots : Int
  final_index : Int
}

///|
fn WgslIrNagaFunctionBodyPlan::from_function(
  shader_module : Module,
  function : Function,
  projection_aliases : Bool,
) -> WgslIrNagaFunctionBodyPlan {
  let materialized_expressions = wgsl_ir_function_materialized_expression_indices(
    function,
  )
  let elided_local_alias_targets = wgsl_ir_naga_function_elided_local_alias_targets(
    shader_module, function, materialized_expressions, projection_aliases,
  )
  WgslIrNagaFunctionBodyPlan::{
    materialized_expressions,
    elided_local_alias_targets,
    local_variable_declarations: wgsl_ir_naga_function_body_local_declarations(
      function,
    ),
    has_body_after_hoisted_declarations: wgsl_ir_naga_function_body_has_non_hoisted_statement(
      function, elided_local_alias_targets,
    ),
    implicit_expression_slots_before: wgsl_ir_naga_function_implicit_expression_slots_before(
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
fn WgslIrNagaFunctionBodyPlan::elided_local_alias_target(
  self : WgslIrNagaFunctionBodyPlan,
  handle : Handle,
) -> Handle? {
  self.elided_local_alias_targets.get(handle.index())
}

///|
fn WgslIrNagaFunctionBodyPlan::contains_elided_local_alias(
  self : WgslIrNagaFunctionBodyPlan,
  handle : Handle,
) -> Bool {
  self.elided_local_alias_target(handle) != None
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
  let plan : Array[WgslIrNagaStatementPlanItem] = []
  let mut emitted_leading_var_declaration = false
  let mut separated_leading_var_declarations = false
  for statement in block.statements {
    let skip = self.statement_is_elided_local_alias_declaration(statement) ||
      wgsl_ir_statement_is_naga_hoisted_local_var_declaration(
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
fn WgslIrNagaFunctionBodyPlan::statement_is_elided_local_alias_declaration(
  self : WgslIrNagaFunctionBodyPlan,
  statement : Statement,
) -> Bool {
  match statement {
    Declare(handle) => self.contains_elided_local_alias(handle)
    _ => false
  }
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
  elided_local_alias_targets : Map[Int, Handle],
) -> Bool {
  for statement in function.body.statements {
    if !wgsl_ir_statement_is_naga_elided_local_alias_declaration(
        elided_local_alias_targets, statement,
      ) &&
      !wgsl_ir_statement_is_naga_hoisted_local_var_declaration(
        function, statement,
      ) {
      return true
    }
  }
  false
}

///|
fn wgsl_ir_statement_is_naga_elided_local_alias_declaration(
  elided_local_alias_targets : Map[Int, Handle],
  statement : Statement,
) -> Bool {
  match statement {
    Declare(handle) => elided_local_alias_targets.get(handle.index()) != None
    _ => false
  }
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
  shader_module : Module,
  origin : WgslIrEmitFunctionOrigin,
  function : Function,
  body_plan : WgslIrNagaFunctionBodyPlan,
  namer : WgslIrNagaNamer,
) -> Unit {
  let temp_namer = WgslIrNagaNamer::WgslIrNagaNamer()
  self.allocate_function_expression_temporary_names(
    origin, function, body_plan, temp_namer,
  )
  for named in function.named_expressions {
    let key = wgsl_ir_emit_named_expression_name_key(origin, named.handle)
    if self.names.get(key) == None {
      self.names.set(key, namer.local_call(temp_namer, named.name))
    }
  }
  for local_index in 0..<function.local_variables.items.length() {
    let local_handle = Handle::Handle(local_index)
    let local_var = function.local_variables.items[local_index]
    let local_name = match body_plan.elided_local_alias_target(local_handle) {
      Some(target) =>
        self.expression_alias_name(
          shader_module, origin, function, body_plan, target,
        )
      None =>
        if local_var.generated_temporary {
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
fn WgslIrFinalNamePlan::expression_alias_name(
  self : WgslIrFinalNamePlan,
  shader_module : Module,
  origin : WgslIrEmitFunctionOrigin,
  function : Function,
  body_plan : WgslIrNagaFunctionBodyPlan,
  handle : Handle,
) -> String? {
  match function.expressions.items.get(handle.index()) {
    Some(FunctionArgument(index)) =>
      match origin {
        UserFunction(function_index) =>
          self.names.get(
            wgsl_ir_emit_name_key2("fn_arg", function_index, index),
          )
        EntryPointFunction(entry_point_index) =>
          self.names.get(
            wgsl_ir_emit_name_key2("ep_arg", entry_point_index, index),
          )
      }
    Some(LocalVariable(local_handle)) =>
      match body_plan.elided_local_alias_target(local_handle) {
        Some(target) =>
          self.expression_alias_name(
            shader_module, origin, function, body_plan, target,
          )
        None =>
          self.names.get(wgsl_ir_emit_local_name_key(origin, local_handle))
      }
    Some(Swizzle(_, base, components)) =>
      match
        self.expression_alias_name(
          shader_module, origin, function, body_plan, base,
        ) {
        Some(base_name) =>
          Some("\{base_name}.\{wgsl_ir_naga_swizzle_components(components)}")
        None => None
      }
    Some(Component(base, component)) =>
      match
        self.expression_alias_name(
          shader_module, origin, function, body_plan, base,
        ) {
        Some(base_name) =>
          Some("\{base_name}.\{wgsl_ir_swizzle_component_name(component)}")
        None => None
      }
    Some(AccessIndex(base, index)) =>
      match
        self.expression_alias_name(
          shader_module, origin, function, body_plan, base,
        ) {
        Some(base_name) =>
          match
            wgsl_ir_naga_access_index_alias_suffix(
              shader_module, function, base, index,
            ) {
            Some(suffix) => Some("\{base_name}\{suffix}")
            None => None
          }
        None => None
      }
    _ =>
      self.names.get(wgsl_ir_emit_expression_temporary_name_key(origin, handle))
  }
}

///|
fn wgsl_ir_naga_swizzle_components(
  components : Array[SwizzleComponent],
) -> String {
  let out = StringBuilder::new()
  for component in components {
    out.write_string(wgsl_ir_swizzle_component_name(component))
  }
  out.to_string()
}

///|
fn wgsl_ir_naga_access_index_alias_suffix(
  shader_module : Module,
  function : Function,
  base : Handle,
  index : Int,
) -> String? {
  guard wgsl_ir_naga_alias_expression_is_vector(shader_module, function, base) else {
    return None
  }
  match index {
    0 => Some(".x")
    1 => Some(".y")
    2 => Some(".z")
    3 => Some(".w")
    _ => None
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
fn wgsl_ir_naga_function_elided_local_alias_targets(
  shader_module : Module,
  function : Function,
  materialized_expressions : @set.Set[Int],
  projection_aliases : Bool,
) -> Map[Int, Handle] {
  let targets : Map[Int, Handle] = Map([])
  let mut changed = true
  while changed {
    changed = false
    for local_index in 0..<function.local_variables.items.length() {
      if targets.get(local_index) == None {
        match
          wgsl_ir_naga_local_alias_target_expression(
            function,
            shader_module,
            materialized_expressions,
            targets,
            projection_aliases,
            Handle::Handle(local_index),
          ) {
          Some(target) => {
            targets.set(local_index, target)
            changed = true
          }
          None => ()
        }
      }
    }
  }
  targets
}

///|
fn wgsl_ir_naga_local_alias_target_expression(
  function : Function,
  shader_module : Module,
  materialized_expressions : @set.Set[Int],
  known_targets : Map[Int, Handle],
  projection_aliases : Bool,
  local_handle : Handle,
) -> Handle? {
  guard function.local_variables.items.get(local_handle.index())
    is Some(local_var) else {
    return None
  }
  guard local_var.kind == LocalVariableKind::Let else { return None }
  guard !local_var.generated_temporary else { return None }
  guard local_var.init is Some(init) else { return None }
  wgsl_ir_naga_expression_alias_target(
    function, shader_module, materialized_expressions, known_targets, projection_aliases,
    local_handle, init,
  )
}

///|
fn wgsl_ir_naga_expression_alias_target(
  function : Function,
  shader_module : Module,
  materialized_expressions : @set.Set[Int],
  known_targets : Map[Int, Handle],
  projection_aliases : Bool,
  local_handle : Handle,
  expression_handle : Handle,
) -> Handle? {
  if materialized_expressions.contains(expression_handle.index()) {
    return Some(expression_handle)
  }
  match function.expressions.items.get(expression_handle.index()) {
    Some(Swizzle(_, base, _)) if projection_aliases =>
      if wgsl_ir_naga_local_alias_is_forwarded_by_local_declaration(
          function, local_handle,
        ) &&
        wgsl_ir_naga_expression_projection_base_has_alias_target(
          function, materialized_expressions, known_targets, base,
        ) {
        Some(expression_handle)
      } else {
        None
      }
    Some(Component(base, _)) if projection_aliases =>
      if wgsl_ir_naga_local_alias_is_forwarded_by_local_declaration(
          function, local_handle,
        ) &&
        wgsl_ir_naga_expression_projection_base_has_alias_target(
          function, materialized_expressions, known_targets, base,
        ) {
        Some(expression_handle)
      } else {
        None
      }
    Some(AccessIndex(base, index)) if projection_aliases =>
      if wgsl_ir_naga_local_alias_is_forwarded_by_local_declaration(
          function, local_handle,
        ) &&
        wgsl_ir_naga_expression_projection_base_has_alias_target(
          function, materialized_expressions, known_targets, base,
        ) &&
        wgsl_ir_naga_access_index_alias_suffix(
          shader_module, function, base, index,
        ) !=
        None {
        Some(expression_handle)
      } else {
        None
      }
    Some(FunctionArgument(_)) => Some(expression_handle)
    Some(LocalVariable(local_handle)) =>
      match known_targets.get(local_handle.index()) {
        Some(target) =>
          if projection_aliases &&
            wgsl_ir_naga_expression_is_projection(function, target) {
            None
          } else {
            Some(target)
          }
        None =>
          match function.local_variables.items.get(local_handle.index()) {
            Some(local_var) =>
              if local_var.generated_temporary {
                match local_var.init {
                  Some(init) =>
                    if materialized_expressions.contains(init.index()) {
                      Some(init)
                    } else {
                      None
                    }
                  None => None
                }
              } else {
                None
              }
            None => None
          }
      }
    _ => None
  }
}

///|
fn wgsl_ir_naga_expression_is_projection(
  function : Function,
  handle : Handle,
) -> Bool {
  match function.expressions.items.get(handle.index()) {
    Some(Swizzle(_, _, _)) | Some(Component(_, _)) | Some(AccessIndex(_, _)) =>
      true
    _ => false
  }
}

///|
fn wgsl_ir_naga_local_alias_is_forwarded_by_local_declaration(
  function : Function,
  local_handle : Handle,
) -> Bool {
  let mut reference_count = 0
  for expression in function.expressions.items {
    if expression == Expression::LocalVariable(local_handle) {
      reference_count += 1
    }
  }
  if reference_count != 1 {
    return false
  }
  for local_var in function.local_variables.items {
    match local_var.init {
      Some(init) =>
        if wgsl_ir_expression_graph_contains_local_variable(
            function, init, local_handle,
          ) {
          return true
        }
      None => ()
    }
  }
  false
}

///|
fn wgsl_ir_expression_graph_contains_local_variable(
  function : Function,
  root : Handle,
  local_handle : Handle,
) -> Bool {
  match function.expressions.items.get(root.index()) {
    Some(LocalVariable(handle)) => handle == local_handle
    Some(Load(inner))
    | Some(AddressOf(_, inner))
    | Some(Splat(_, inner))
    | Some(Swizzle(_, inner, _))
    | Some(Component(inner, _))
    | Some(AccessIndex(inner, _)) =>
      wgsl_ir_expression_graph_contains_local_variable(
        function, inner, local_handle,
      )
    Some(Access(base, index)) =>
      wgsl_ir_expression_graph_contains_local_variable(
        function, base, local_handle,
      ) ||
      wgsl_ir_expression_graph_contains_local_variable(
        function, index, local_handle,
      )
    Some(Unary(_, inner)) =>
      wgsl_ir_expression_graph_contains_local_variable(
        function, inner, local_handle,
      )
    Some(Binary(_, left, right)) =>
      wgsl_ir_expression_graph_contains_local_variable(
        function, left, local_handle,
      ) ||
      wgsl_ir_expression_graph_contains_local_variable(
        function, right, local_handle,
      )
    _ => false
  }
}

///|
fn wgsl_ir_naga_expression_projection_base_has_alias_target(
  function : Function,
  materialized_expressions : @set.Set[Int],
  known_targets : Map[Int, Handle],
  base : Handle,
) -> Bool {
  if materialized_expressions.contains(base.index()) {
    return true
  }
  match function.expressions.items.get(base.index()) {
    Some(Swizzle(_, inner, _)) =>
      wgsl_ir_naga_expression_projection_base_has_alias_target(
        function, materialized_expressions, known_targets, inner,
      )
    Some(Component(inner, _)) =>
      wgsl_ir_naga_expression_projection_base_has_alias_target(
        function, materialized_expressions, known_targets, inner,
      )
    Some(AccessIndex(inner, _)) =>
      wgsl_ir_naga_expression_projection_base_has_alias_target(
        function, materialized_expressions, known_targets, inner,
      )
    _ => false
  }
}

///|
fn wgsl_ir_naga_alias_expression_is_vector(
  shader_module : Module,
  function : Function,
  handle : Handle,
) -> Bool {
  match function.expressions.items.get(handle.index()) {
    Some(FunctionArgument(index)) =>
      match function.arguments.get(index) {
        Some(argument) =>
          wgsl_ir_naga_type_handle_is_vector(shader_module, argument.ty)
        None => false
      }
    Some(LocalVariable(local_handle)) =>
      match function.local_variables.items.get(local_handle.index()) {
        Some(local_var) =>
          wgsl_ir_naga_type_handle_is_vector(shader_module, local_var.ty)
        None => false
      }
    Some(Load(pointer)) =>
      match
        wgsl_ir_naga_expression_type_handle(shader_module, function, pointer) {
        Some(ty) =>
          wgsl_ir_naga_type_handle_is_vector(
            shader_module,
            wgsl_ir_naga_deref_pointer_type_handle(shader_module, ty),
          )
        None => false
      }
    Some(ImageLoad(image, _, _, _, _)) =>
      wgsl_ir_naga_image_load_result_is_vector(shader_module, function, image)
    Some(Swizzle(size, _, _)) => size.width() > 1
    _ => false
  }
}

///|
fn wgsl_ir_naga_expression_type_handle(
  shader_module : Module,
  function : Function,
  handle : Handle,
) -> Handle? {
  match function.expressions.items.get(handle.index()) {
    Some(FunctionArgument(index)) =>
      match function.arguments.get(index) {
        Some(argument) => Some(argument.ty)
        None => None
      }
    Some(LocalVariable(local_handle)) =>
      match function.local_variables.items.get(local_handle.index()) {
        Some(local_var) => Some(local_var.ty)
        None => None
      }
    Some(GlobalVariable(global_handle)) =>
      match shader_module.global_variables.items.get(global_handle.index()) {
        Some(global) => Some(global.ty)
        None => None
      }
    Some(Load(pointer)) =>
      match
        wgsl_ir_naga_expression_type_handle(shader_module, function, pointer) {
        Some(ty) =>
          Some(wgsl_ir_naga_deref_pointer_type_handle(shader_module, ty))
        None => None
      }
    _ => None
  }
}

///|
fn wgsl_ir_naga_type_handle_is_vector(
  shader_module : Module,
  ty : Handle,
) -> Bool {
  match shader_module.types.items.get(ty.index()) {
    Some({ inner: Vector(_, _), .. }) => true
    _ => false
  }
}

///|
fn wgsl_ir_naga_deref_pointer_type_handle(
  shader_module : Module,
  ty : Handle,
) -> Handle {
  match shader_module.types.items.get(ty.index()) {
    Some({ inner: Pointer(inner, _) | BindingArray(inner, _), .. }) => inner
    _ => ty
  }
}

///|
fn wgsl_ir_naga_image_load_result_is_vector(
  shader_module : Module,
  function : Function,
  image : Handle,
) -> Bool {
  match wgsl_ir_naga_expression_type_handle(shader_module, function, image) {
    Some(image_ty) =>
      match shader_module.types.items.get(image_ty.index()) {
        Some({ inner: Image(_, _, _), .. }) => true
        _ => false
      }
    None => false
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
  wgsl_ir_emit_expression_temporary_index_trace(function, body_plan, handle).final_index
}

///|
fn wgsl_ir_emit_expression_temporary_index_trace(
  function : Function,
  body_plan : WgslIrNagaFunctionBodyPlan,
  handle : Handle,
) -> WgslIrNagaTemporaryIndexTrace {
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
        wgsl_ir_function_expression_is_absorbed_store_projected_call_argument_base(
          function, body_plan, expression_handle, handle,
        )
      ) ||
      (
        current_is_call_result &&
        wgsl_ir_function_expression_is_inline_naga_operand_slot_for_call_result(
          function, expression_handle, handle,
        )
      ) ||
      wgsl_ir_function_expression_is_atomic_compare_exchange_projection_role(
        function, expression_handle,
      ) {
      skipped += 1
    }
  }
  let base_index = handle.index() - skipped
  let adjusted_base_index = base_index
  let implicit_expression_slots_before = body_plan.implicit_expression_slot_offset(
    handle,
  )
  let prior_call_projection_argument_slots = 0
  let implicit_naga_load_slots = wgsl_ir_emit_implicit_naga_load_slot_offset(
    function, body_plan, handle,
  )
  let projected_temporary_slots = 0
  let reused_resource_operand_slots = wgsl_ir_emit_reused_resource_operand_slot_offset(
      function, handle,
    ) -
    projected_temporary_slots
  let reused_resource_operand_slots = if reused_resource_operand_slots > 0 {
    reused_resource_operand_slots
  } else {
    0
  }
  let final_index = adjusted_base_index +
    implicit_expression_slots_before +
    prior_call_projection_argument_slots +
    implicit_naga_load_slots +
    reused_resource_operand_slots +
    projected_temporary_slots
  WgslIrNagaTemporaryIndexTrace::{
    skipped,
    base_index,
    adjusted_base_index,
    implicit_expression_slots_before,
    prior_call_projection_argument_slots,
    implicit_naga_load_slots,
    reused_resource_operand_slots,
    projected_temporary_slots,
    final_index,
  }
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
fn wgsl_ir_function_expression_is_projection_of_call_result_temporary(
  function : Function,
  handle : Handle,
) -> Bool {
  match function.expressions.items.get(handle.index()) {
    Some(Access(base, _))
    | Some(AccessIndex(base, _))
    | Some(Component(base, _))
    | Some(Swizzle(_, base, _)) =>
      wgsl_ir_function_expression_is_call_result_projection_base(function, base)
    _ => false
  }
}

///|
fn wgsl_ir_function_expression_is_call_result_projection_base(
  function : Function,
  handle : Handle,
) -> Bool {
  match function.expressions.items.get(handle.index()) {
    Some(CallResult(_)) => true
    Some(Access(base, _))
    | Some(AccessIndex(base, _))
    | Some(Component(base, _))
    | Some(Swizzle(_, base, _)) =>
      wgsl_ir_function_expression_is_call_result_projection_base(function, base)
    _ => false
  }
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
    | Some(Component(_, _))
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
            if wgsl_ir_function_expression_is_projection_of_call_result_temporary(
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
    Some(AccessIndex(base, _)) | Some(Component(base, _)) =>
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
    Some(AccessIndex(base, _)) | Some(Component(base, _)) =>
      wgsl_ir_emit_expression_is_dynamic_pointer_access(function, base)
    _ => false
  }
}

///|
fn wgsl_ir_emit_reused_resource_operand_slot_offset(
  function : Function,
  limit : Handle,
) -> Int {
  let seen : @set.Set[Int] = @set.Set([])
  let mut offset = 0
  for index in 0..<=limit.index() {
    match function.expressions.items.get(index) {
      Some(ImageSample(image, sampler, _, _, _, _, _, _, _)) => {
        offset += wgsl_ir_emit_reused_resource_operand_slot(
          function, seen, image,
        )
        offset += wgsl_ir_emit_reused_resource_operand_slot(
          function, seen, sampler,
        )
      }
      _ => ()
    }
  }
  offset
}

///|
fn wgsl_ir_emit_reused_resource_operand_slot(
  function : Function,
  seen : @set.Set[Int],
  handle : Handle,
) -> Int {
  guard wgsl_ir_emit_expression_is_global_resource(function, handle) else {
    return 0
  }
  let index = handle.index()
  if seen.contains(index) {
    1
  } else {
    seen.add(index)
    0
  }
}

///|
fn wgsl_ir_emit_expression_is_global_resource(
  function : Function,
  handle : Handle,
) -> Bool {
  match function.expressions.items.get(handle.index()) {
    Some(GlobalVariable(_)) => true
    _ => false
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
