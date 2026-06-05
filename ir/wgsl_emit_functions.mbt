///|
fn WgslIrEmitter::emit_entry_point(
  self : WgslIrEmitter,
  out : StringBuilder,
  entry_point : EntryPoint,
  function_plan : NagaCompatFunctionPlan,
  index : Int,
) -> Unit raise WgslIrEmitError {
  let multiline_attributes = entry_point.stage == Task ||
    entry_point.stage == Mesh ||
    entry_point.task_payload != None
  match entry_point.stage {
    Mesh =>
      match entry_point.mesh_info {
        Some(mesh_info) =>
          out.write_string(
            "@mesh(\{self.global_variable_name(mesh_info.output_variable)})",
          )
        None => raise Unsupported("mesh entry point without mesh output")
      }
    _ => out.write_string(self.stage_attribute(entry_point.stage))
  }
  match entry_point.task_payload {
    Some(payload) =>
      out.write_string("\n@payload(\{self.global_variable_name(payload)})")
    None => ()
  }
  if wgsl_ir_stage_has_workgroup_size(entry_point.stage) {
    if multiline_attributes {
      out.write_string("\n@workgroup_size(")
    } else {
      out.write_string(" @workgroup_size(")
    }
    out.write_string(self.workgroup_size_component(entry_point, 0))
    out.write_string(", ")
    out.write_string(self.workgroup_size_component(entry_point, 1))
    out.write_string(", ")
    out.write_string(self.workgroup_size_component(entry_point, 2))
    out.write_string(")")
  } else if !multiline_attributes {
    out.write_string(" ")
  }
  if wgsl_ir_stage_has_workgroup_size(entry_point.stage) &&
    !multiline_attributes &&
    self.options.emit_trailing_space_after_entry_point_attributes() {
    out.write_string(" ")
  }
  out.write_string("\n")
  self.emit_function(
    out,
    entry_point.function,
    function_plan,
    EntryPointFunction(index),
  )
}

///|
fn wgsl_ir_stage_has_workgroup_size(stage : ShaderStage) -> Bool {
  stage == Compute || stage == Task || stage == Mesh
}

///|
fn WgslIrEmitter::workgroup_size_component(
  self : WgslIrEmitter,
  entry_point : EntryPoint,
  index : Int,
) -> String raise WgslIrEmitError {
  match entry_point.workgroup_size_overrides {
    Some(overrides) =>
      match overrides.get(index) {
        Some(Some(handle)) => return self.global_expression(handle)
        _ => ()
      }
    None => ()
  }
  match entry_point.workgroup_size.get(index) {
    Some(value) => "\{value}"
    None => "1"
  }
}

///|
fn WgslIrEmitter::emit_function(
  self : WgslIrEmitter,
  out : StringBuilder,
  function : Function,
  function_plan : NagaCompatFunctionPlan,
  origin : WgslIrEmitFunctionOrigin,
) -> Unit raise WgslIrEmitError {
  let emitter = self.with_function_origin(origin)
  let name = match origin {
    UserFunction(index) =>
      emitter.required_emit_name(wgsl_ir_emit_name_key("fn", index))
    EntryPointFunction(index) =>
      emitter.required_emit_name(wgsl_ir_emit_name_key("ep", index))
  }
  out.write_string("fn \{name}(")
  for index in 0..<function.arguments.length() {
    if index > 0 {
      out.write_string(", ")
    }
    emitter.emit_function_argument(out, function, index)
  }
  out.write_string(")")
  match function.result {
    Some(result) => {
      out.write_string(" -> ")
      emitter.emit_binding_attribute_prefix(
        out,
        result.binding,
        Some(result.ty),
      )
      out.write_string(emitter.type_name(result.ty))
    }
    None => ()
  }
  out.write_string(" {\n")
  emitter.emit_function_local_var_declarations(out, function, function_plan, 1)
  emitter.emit_block_statements(out, function, function_plan, function.body, 1)
  out.write_string("}\n")
}

///|
fn WgslIrEmitter::emit_function_argument(
  self : WgslIrEmitter,
  out : StringBuilder,
  function : Function,
  index : Int,
) -> Unit raise WgslIrEmitError {
  guard function.arguments.get(index) is Some(argument) else {
    raise MissingHandle("function argument \{index}")
  }
  self.emit_binding_attribute_prefix(out, argument.binding, Some(argument.ty))
  let name = self.function_argument_name(Some(function), index)
  out.write_string("\{name}: \{self.type_name(argument.ty)}")
}

///|
fn WgslIrEmitter::emit_local_declaration(
  self : WgslIrEmitter,
  out : StringBuilder,
  function : Function,
  handle : Handle,
  indent : Int,
) -> Unit raise WgslIrEmitError {
  let local_var = match function.local_variables.items.get(handle.index()) {
    Some(value) => value
    None => raise MissingHandle("local variable \{handle.index()}")
  }
  if wgsl_ir_local_variable_is_generated_call_result_alias(function, local_var) {
    return
  }
  let name = self.local_variable_name(Some(function), handle)
  out.write_string(
    "\{wgsl_ir_indent(indent)}\{self.local_variable_keyword(local_var.kind)} \{name}",
  )
  if self.local_variable_needs_type_annotation(local_var) {
    out.write_string(": \{self.type_name(local_var.ty)}")
  }
  match local_var.init {
    Some(init) => {
      let init_expr = if local_var.generated_temporary {
        self.function_expression_inline(function, init)
      } else {
        self.function_expression(function, init)
      }
      if self.type_is_pointer(local_var.ty) &&
        wgsl_ir_expression_text_needs_address(init_expr) &&
        !self.expression_is_pointer(Some(function), init) {
        out.write_string(
          " = \{self.options.address_of_text(self.function_pointer_expression(function, init))}",
        )
      } else {
        out.write_string(" = \{init_expr}")
      }
    }
    None => ()
  }
  out.write_string(";\n")
}

///|
fn wgsl_ir_local_variable_is_generated_call_result_alias(
  function : Function,
  local_var : LocalVariable,
) -> Bool {
  guard local_var.generated_temporary else { return false }
  guard local_var.init is Some(init) else { return false }
  match function.expressions.items.get(init.index()) {
    Some(CallResult(_)) => true
    _ => false
  }
}

///|
fn WgslIrEmitter::emit_function_local_var_declarations(
  self : WgslIrEmitter,
  out : StringBuilder,
  function : Function,
  function_plan : NagaCompatFunctionPlan,
  indent : Int,
) -> Unit raise WgslIrEmitError {
  for index in function_plan.local_declaration_order() {
    self.emit_local_declaration(out, function, Handle(index), indent)
  }
  if function_plan.needs_blank_after_local_declarations() {
    out.write_string("\n")
  }
}

///|
fn wgsl_ir_expression_text_needs_address(text : String) -> Bool {
  text.length() == 0 || text[0:1] != "&"
}

///|
fn WgslIrEmitter::local_variable_keyword(
  self : WgslIrEmitter,
  kind : LocalVariableKind,
) -> String {
  ignore(self)
  match kind {
    Var => "var"
    Let => "let"
  }
}

///|
fn WgslIrEmitter::local_variable_needs_type_annotation(
  self : WgslIrEmitter,
  local_var : LocalVariable,
) -> Bool {
  if self.type_contains_abstract_scalar(local_var.ty) {
    return false
  }
  if self.options.annotate_all_local_types() {
    return true
  }
  if self.options.annotate_atomic_compare_exchange_result_locals() &&
    self.type_is_atomic_compare_exchange_result(local_var.ty) {
    return true
  }
  !self.type_is_predeclared_result(local_var.ty)
}

///|
fn WgslIrEmitter::type_is_atomic_compare_exchange_result(
  self : WgslIrEmitter,
  handle : Handle,
) -> Bool {
  for item in self.shader_module.special_types.predeclared_types {
    let (predeclared, existing) = item
    if existing == handle {
      match predeclared {
        AtomicCompareExchangeWeakResult(_) => return true
        _ => return false
      }
    }
  }
  false
}

///|
fn WgslIrEmitter::type_is_predeclared_result(
  self : WgslIrEmitter,
  handle : Handle,
) -> Bool {
  for item in self.shader_module.special_types.predeclared_types {
    let (_, existing) = item
    if existing == handle {
      return true
    }
  }
  false
}
