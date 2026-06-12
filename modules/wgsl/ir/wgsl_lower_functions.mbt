///|
fn WgslIrLowerer::lower_function_declaration(
  self : WgslIrLowerer,
  function : @ast.WgslFunction,
) -> Unit raise WgslIrLowerError {
  let stage = wgsl_ir_shader_stage_from_attributes(function.attributes())
  let referenced_stage_function = match stage {
    Some(_) => self.referenced_names.contains(function.name().name())
    None => false
  }
  let ir_function = if referenced_stage_function {
    wgsl_ir_strip_function_io_bindings(self.lower_function(function))
  } else {
    self.lower_function(function)
  }
  match self.function_names.get(function.name().name()) {
    Some(handle) => self.shader_module.set_function(handle, ir_function)
    None => {
      let handle = self.shader_module.append_function(ir_function)
      self.function_names.set(function.name().name(), handle)
    }
  }
  match stage {
    Some(stage) =>
      if !self.referenced_names.contains(function.name().name()) &&
        !self.entry_point_name_is_lowered(function.name().name()) {
        let (workgroup_size, workgroup_size_overrides) = self.workgroup_size_from_attributes(
          function.attributes(),
        )
        self.shader_module.append_entry_point({
          name: function.name().name(),
          source_start: function.fn_start(),
          stage,
          early_depth_test: wgsl_ir_early_depth_test_from_attributes(
            function.attributes(),
          ),
          workgroup_size,
          workgroup_size_overrides,
          function: ir_function,
          mesh_info: self.mesh_stage_info_from_attributes(
            stage,
            function.attributes(),
          ),
          task_payload: self.payload_variable_from_attributes(
            function.attributes(),
          ),
          incoming_ray_payload: None,
        })
      }
    None => ()
  }
}

///|
fn WgslIrLowerer::entry_point_name_is_lowered(
  self : WgslIrLowerer,
  name : String,
) -> Bool {
  for entry_point in self.shader_module.entry_points {
    if entry_point.name == name {
      return true
    }
  }
  false
}

///|
fn wgsl_ir_strip_function_io_bindings(function : Function) -> Function {
  let arguments : Array[FunctionArgument] = []
  for argument in function.arguments {
    arguments.push({ name: argument.name, ty: argument.ty, binding: None })
  }
  let result = match function.result {
    Some(value) => Some(FunctionResult::{ ty: value.ty, binding: None })
    None => None
  }
  {
    name: function.name,
    source_start: function.source_start,
    generated_import: function.generated_import,
    arguments,
    result,
    local_variables: function.local_variables,
    expressions: function.expressions,
    named_expressions: function.named_expressions,
    body: function.body,
    diagnostic_filter_leaf: function.diagnostic_filter_leaf,
  }
}

///|
fn WgslIrLowerer::resolve_ambient_global_function_parameters(
  self : WgslIrLowerer,
) -> Unit {
  for index in 0..<self.shader_module.functions.items.length() {
    let handle = Handle::Handle(index)
    guard self.function_is_called_only_without_arguments(handle) else {
      continue
    }
    guard self.shader_module.functions.items.get(index) is Some(function) else {
      continue
    }
    match self.ambient_global_arguments_for_function(function) {
      Some(global_handles) => {
        let rewritten = self.function_without_ambient_global_arguments(
          function, global_handles,
        )
        self.shader_module.set_function(handle, rewritten)
      }
      None => ()
    }
  }
}

///|
fn WgslIrLowerer::function_is_called_only_without_arguments(
  self : WgslIrLowerer,
  target : Handle,
) -> Bool {
  let mut has_call = false
  let mut has_non_empty_call = false
  for function in self.shader_module.functions.items {
    let (function_has_call, function_has_non_empty_call) = self.function_call_argument_shape(
      function, target,
    )
    has_call = has_call || function_has_call
    has_non_empty_call = has_non_empty_call || function_has_non_empty_call
  }
  for entry_point in self.shader_module.entry_points {
    let (function_has_call, function_has_non_empty_call) = self.function_call_argument_shape(
      entry_point.function,
      target,
    )
    has_call = has_call || function_has_call
    has_non_empty_call = has_non_empty_call || function_has_non_empty_call
  }
  has_call && !has_non_empty_call
}

///|
fn WgslIrLowerer::function_call_argument_shape(
  self : WgslIrLowerer,
  function : Function,
  target : Handle,
) -> (Bool, Bool) {
  ignore(self)
  let mut has_call = false
  let mut has_non_empty_call = false
  for expression in function.expressions.items {
    match expression {
      FunctionCall(handle, arguments) =>
        if handle == target {
          has_call = true
          if !arguments.is_empty() {
            has_non_empty_call = true
          }
        }
      _ => ()
    }
  }
  let (body_has_call, body_has_non_empty_call) = self.block_call_argument_shape(
    function.body,
    target,
  )
  has_call = has_call || body_has_call
  has_non_empty_call = has_non_empty_call || body_has_non_empty_call
  (has_call, has_non_empty_call)
}

///|
fn WgslIrLowerer::block_call_argument_shape(
  self : WgslIrLowerer,
  block : Block,
  target : Handle,
) -> (Bool, Bool) {
  let mut has_call = false
  let mut has_non_empty_call = false
  for statement in block.statements {
    let (statement_has_call, statement_has_non_empty_call) = self.statement_call_argument_shape(
      statement, target,
    )
    has_call = has_call || statement_has_call
    has_non_empty_call = has_non_empty_call || statement_has_non_empty_call
  }
  (has_call, has_non_empty_call)
}

///|
fn WgslIrLowerer::statement_call_argument_shape(
  self : WgslIrLowerer,
  statement : Statement,
  target : Handle,
) -> (Bool, Bool) {
  match statement {
    Call(handle, arguments, _) =>
      if handle == target {
        (true, !arguments.is_empty())
      } else {
        (false, false)
      }
    Block(block) => self.block_call_argument_shape(block, target)
    If(_, accept, reject) => {
      let (accept_has_call, accept_has_non_empty_call) = self.block_call_argument_shape(
        accept, target,
      )
      let (reject_has_call, reject_has_non_empty_call) = self.block_call_argument_shape(
        reject, target,
      )
      (
        accept_has_call || reject_has_call,
        accept_has_non_empty_call || reject_has_non_empty_call,
      )
    }
    Switch(_, cases) => {
      let mut has_call = false
      let mut has_non_empty_call = false
      for case in cases {
        let (case_has_call, case_has_non_empty_call) = self.block_call_argument_shape(
          case.body,
          target,
        )
        has_call = has_call || case_has_call
        has_non_empty_call = has_non_empty_call || case_has_non_empty_call
      }
      (has_call, has_non_empty_call)
    }
    Loop(body, continuing, _) => {
      let (body_has_call, body_has_non_empty_call) = self.block_call_argument_shape(
        body, target,
      )
      let (continuing_has_call, continuing_has_non_empty_call) = self.block_call_argument_shape(
        continuing, target,
      )
      (
        body_has_call || continuing_has_call,
        body_has_non_empty_call || continuing_has_non_empty_call,
      )
    }
    _ => (false, false)
  }
}

///|
fn WgslIrLowerer::ambient_global_arguments_for_function(
  self : WgslIrLowerer,
  function : Function,
) -> Array[Handle]? {
  if function.arguments.is_empty() {
    return None
  }
  let globals : Array[Handle] = []
  for argument in function.arguments {
    guard argument.binding == None else { return None }
    guard argument.name is Some(name) else { return None }
    guard self.global_names.get(name) is Some(global_handle) else {
      return None
    }
    guard self.shader_module.global_variables.items.get(global_handle.index())
      is Some(global) else {
      return None
    }
    guard global.ty == argument.ty else { return None }
    globals.push(global_handle)
  }
  Some(globals)
}

///|
fn WgslIrLowerer::function_without_ambient_global_arguments(
  self : WgslIrLowerer,
  function : Function,
  global_handles : Array[Handle],
) -> Function {
  let expressions = ExpressionArena()
  for index in 0..<function.expressions.items.length() {
    let expression = function.expressions.items[index]
    let origin = match function.expressions.origins.get(index) {
      Some(value) => value
      None => SourceExpression
    }
    ignore(
      expressions.append_with_origin(
        self.rewrite_ambient_global_function_expression(
          expression, global_handles,
        ),
        origin,
      ),
    )
  }
  {
    name: function.name,
    source_start: function.source_start,
    generated_import: function.generated_import,
    arguments: [],
    result: function.result,
    local_variables: function.local_variables,
    expressions,
    named_expressions: function.named_expressions,
    body: function.body,
    diagnostic_filter_leaf: function.diagnostic_filter_leaf,
  }
}

///|
fn WgslIrLowerer::rewrite_ambient_global_function_expression(
  self : WgslIrLowerer,
  expression : Expression,
  global_handles : Array[Handle],
) -> Expression {
  ignore(self)
  match expression {
    FunctionArgument(index) =>
      match global_handles.get(index) {
        Some(global_handle) => GlobalVariable(global_handle)
        None => FunctionArgument(index)
      }
    _ => expression
  }
}

///|
fn WgslIrLowerer::lower_function(
  self : WgslIrLowerer,
  function : @ast.WgslFunction,
) -> Function raise WgslIrLowerError {
  let result = match function.result() {
    Some(result) =>
      match result.ty_ref() {
        Some(ty_ref) =>
          Some(FunctionResult::{
            ty: self.lower_type_ref(ty_ref),
            binding: wgsl_ir_binding_from_attributes(result.attributes()),
          })
        None => None
      }
    None => None
  }
  let ir_function = Function::{
    name: Some(function.name().name()),
    source_start: function.fn_start(),
    generated_import: self.function_has_generated_import_provenance(
      function.name().name(),
    ),
    arguments: [],
    result,
    local_variables: LocalVariableArena(),
    expressions: ExpressionArena(),
    named_expressions: [],
    body: Block(),
    diagnostic_filter_leaf: None,
  }
  let scope = WgslIrFunctionScope()
  scope.visible_rel_path = self.generated_import_function_rel_path(
    function.name().name(),
  )
  if scope.visible_rel_path == "" {
    scope.visible_rel_path = self.root_visible_rel_path
  }
  let function_stage = wgsl_ir_shader_stage_from_attributes(
    function.attributes(),
  )
  let referenced_stage_function = match function_stage {
    Some(_) => self.referenced_names.contains(function.name().name())
    None => false
  }
  scope.generated_import_local_spelling = if function_stage == None ||
    referenced_stage_function ||
    ir_function.generated_import {
    AllGeneratedImportLocalSpelling
  } else {
    RootGeneratedImportLocalSpelling
  }
  let mut index = 0
  for argument in function.arguments() {
    guard argument.ty_ref() is Some(ty_ref) else {
      raise MissingType(argument.name().name())
    }
    ir_function.arguments.push({
      name: Some(
        self.generated_import_local_spelling_for_scope(
          argument.name().name(),
          scope,
        ),
      ),
      ty: self.lower_type_ref(ty_ref),
      binding: wgsl_ir_binding_from_attributes(argument.attributes()),
    })
    scope.arguments.set(argument.name().name(), index)
    index = index + 1
  }
  self.predeclare_function_source_local_prefix(
    function.body(),
    ir_function,
    scope,
  )
  let body = self.lower_block(function.body(), ir_function, scope) catch {
    error =>
      match error {
        UnknownIdentifier(name) =>
          raise UnknownIdentifier(
            "\{name} in function \{function.name().name()} with args \{wgsl_ir_function_argument_names(function)}",
          )
        UnsupportedExpression(message) =>
          raise UnsupportedExpression(
            "\{message} in function \{function.name().name()}",
          )
        UnsupportedStatement(message) =>
          raise UnsupportedStatement(
            "\{message} in function \{function.name().name()}",
          )
        _ => raise error
      }
  }
  if result == None &&
    !wgsl_ir_block_ends_with_return(body) &&
    !wgsl_ir_absorb_implicit_tail_return(body) {
    body.push(ImplicitReturn)
  }
  {
    name: ir_function.name,
    source_start: ir_function.source_start,
    generated_import: ir_function.generated_import,
    arguments: ir_function.arguments,
    result,
    local_variables: ir_function.local_variables,
    expressions: ir_function.expressions,
    named_expressions: ir_function.named_expressions,
    body,
    diagnostic_filter_leaf: ir_function.diagnostic_filter_leaf,
  }
}

///|
fn wgsl_ir_function_argument_names(function : @ast.WgslFunction) -> String {
  let names : Array[String] = []
  for argument in function.arguments() {
    names.push(argument.name().name())
  }
  names.join(",")
}
