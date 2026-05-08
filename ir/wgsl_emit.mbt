///|
priv suberror WgslIrEmitError {
  MissingHandle(String)
  MissingName(String)
  Unsupported(String)
}

///|
fn WgslIrEmitError::message(self : WgslIrEmitError) -> String {
  match self {
    MissingHandle(message) => "missing IR handle: \{message}"
    MissingName(message) => "missing IR name: \{message}"
    Unsupported(message) => "unsupported IR emission: \{message}"
  }
}

///|
fn emit_wgsl_module_from_ir(
  shader_module : Module,
) -> String raise WgslIrEmitError {
  validate_wgsl_ir_module(shader_module) catch {
    error => raise WgslIrEmitError::Unsupported(error.message())
  }
  let emitter = WgslIrEmitter::{
    shader_module,
    preserve_abstract_float_literals: false,
    filter: None,
  }
  emitter.emit_module()
}

///|
fn emit_wgsl_module_from_ir_roots(
  shader_module : Module,
  root_items : Array[String],
) -> String raise WgslIrEmitError {
  if root_items.length() == 0 {
    return emit_wgsl_module_from_ir(shader_module)
  }
  validate_wgsl_ir_module(shader_module) catch {
    error => raise WgslIrEmitError::Unsupported(error.message())
  }
  let emitter = WgslIrEmitter::{
    shader_module,
    preserve_abstract_float_literals: false,
    filter: Some(build_wgsl_ir_emit_filter(shader_module, root_items)),
  }
  emitter.emit_module()
}

///|
priv struct WgslIrEmitter {
  shader_module : Module
  preserve_abstract_float_literals : Bool
  filter : WgslIrEmitFilter?
}

///|
fn WgslIrEmitter::emit_module(
  self : WgslIrEmitter,
) -> String raise WgslIrEmitError {
  let out = StringBuilder::new()
  let mut needs_blank = false
  let mut last_item_is_entry_point = false
  for directive in self.shader_module.directives {
    out.write_string(directive)
    out.write_string("\n")
    needs_blank = true
    last_item_is_entry_point = false
  }
  for index in 0..<self.shader_module.types.items.length() {
    if !self.should_emit_type(index) {
      continue
    }
    let ty = self.shader_module.types.items[index]
    match ty.inner {
      Struct(_, _) if ty.name != None => {
        if needs_blank {
          out.write_string("\n")
        }
        self.emit_struct_type(out, ty)
        needs_blank = true
        last_item_is_entry_point = false
      }
      _ => ()
    }
  }
  let mut emitted_constant = false
  for index in 0..<self.shader_module.constants.items.length() {
    if !self.should_emit_constant(index) {
      continue
    }
    if needs_blank && !emitted_constant {
      out.write_string("\n")
    }
    self.emit_constant(out, self.shader_module.constants.items[index])
    needs_blank = true
    last_item_is_entry_point = false
    emitted_constant = true
  }
  let mut emitted_const_assert = false
  for condition in self.shader_module.const_asserts {
    if needs_blank && !emitted_const_assert {
      out.write_string("\n")
    }
    self.emit_global_const_assert(out, condition)
    needs_blank = true
    last_item_is_entry_point = false
    emitted_const_assert = true
  }
  let mut emitted_override = false
  for index in 0..<self.shader_module.overrides.items.length() {
    if !self.should_emit_override(index) {
      continue
    }
    if needs_blank && !emitted_override {
      out.write_string("\n")
    }
    self.emit_override(out, self.shader_module.overrides.items[index])
    needs_blank = true
    last_item_is_entry_point = false
    emitted_override = true
  }
  let mut emitted_global_variable = false
  for index in 0..<self.shader_module.global_variables.items.length() {
    if !self.should_emit_global_variable(index) {
      continue
    }
    if needs_blank && !emitted_global_variable {
      out.write_string("\n")
    }
    self.emit_global_variable(
      out,
      self.shader_module.global_variables.items[index],
    )
    needs_blank = true
    last_item_is_entry_point = false
    emitted_global_variable = true
  }
  for index in 0..<self.shader_module.functions.items.length() {
    if !self.should_emit_function(index) {
      continue
    }
    if self.function_is_entry_point_name(
        self.shader_module.functions.items[index],
      ) {
      continue
    }
    if needs_blank {
      out.write_string("\n")
    }
    self.emit_function(out, self.shader_module.functions.items[index], None)
    needs_blank = true
    last_item_is_entry_point = false
  }
  for index in 0..<self.shader_module.entry_points.length() {
    if !self.should_emit_entry_point(index) {
      continue
    }
    let entry_point = self.shader_module.entry_points[index]
    if needs_blank {
      out.write_string("\n")
    }
    self.emit_entry_point(out, entry_point)
    needs_blank = true
    last_item_is_entry_point = true
  }
  if needs_blank && !last_item_is_entry_point {
    out.write_string("\n")
  }
  out.to_string()
}

///|
fn WgslIrEmitter::should_emit_type(self : WgslIrEmitter, index : Int) -> Bool {
  match self.filter {
    Some(filter) => filter.contains_type(index)
    None => true
  }
}

///|
fn WgslIrEmitter::should_emit_constant(
  self : WgslIrEmitter,
  index : Int,
) -> Bool {
  match self.filter {
    Some(filter) => filter.contains_constant(index)
    None => true
  }
}

///|
fn WgslIrEmitter::should_emit_override(
  self : WgslIrEmitter,
  index : Int,
) -> Bool {
  match self.filter {
    Some(filter) => filter.contains_override(index)
    None => true
  }
}

///|
fn WgslIrEmitter::should_emit_global_variable(
  self : WgslIrEmitter,
  index : Int,
) -> Bool {
  match self.filter {
    Some(filter) => filter.contains_global_variable(index)
    None => true
  }
}

///|
fn WgslIrEmitter::should_emit_function(
  self : WgslIrEmitter,
  index : Int,
) -> Bool {
  match self.filter {
    Some(filter) => filter.contains_function(index)
    None => true
  }
}

///|
fn WgslIrEmitter::should_emit_entry_point(
  self : WgslIrEmitter,
  index : Int,
) -> Bool {
  match self.filter {
    Some(filter) => filter.contains_entry_point(index)
    None => true
  }
}

///|
fn WgslIrEmitter::emit_global_const_assert(
  self : WgslIrEmitter,
  out : StringBuilder,
  condition : Handle,
) -> Unit raise WgslIrEmitError {
  out.write_string(
    "const_assert \{self.abstract_float_global_expression(condition)};\n",
  )
}

///|
fn WgslIrEmitter::with_preserved_abstract_float_literals(
  self : WgslIrEmitter,
) -> WgslIrEmitter {
  WgslIrEmitter::{
    shader_module: self.shader_module,
    preserve_abstract_float_literals: true,
    filter: self.filter,
  }
}

///|
fn WgslIrEmitter::function_is_entry_point_name(
  self : WgslIrEmitter,
  function : Function,
) -> Bool {
  match function.name {
    Some(name) =>
      for entry_point in self.shader_module.entry_points {
        if entry_point.name == name {
          return true
        }
      }
    None => ()
  }
  false
}

///|
fn WgslIrEmitter::emit_struct_type(
  self : WgslIrEmitter,
  out : StringBuilder,
  ty : Type,
) -> Unit raise WgslIrEmitError {
  guard ty.name is Some(name) else {
    raise WgslIrEmitError::MissingName("struct type")
  }
  guard ty.inner is Struct(members, _) else {
    raise WgslIrEmitError::Unsupported(
      "non-struct type passed to struct emitter",
    )
  }
  out.write_string("struct \{sanitize_wgsl_ir_identifier(name)} {\n")
  for struct_member in members {
    out.write_string("    ")
    self.emit_struct_member_layout_attribute_prefix(out, struct_member)
    self.emit_binding_attribute_prefix(out, struct_member.binding)
    let member_name = match struct_member.name {
      Some(value) => value
      None => raise WgslIrEmitError::MissingName("struct member")
    }
    out.write_string(
      "\{sanitize_wgsl_ir_identifier(member_name)}: \{self.type_name(struct_member.ty)},\n",
    )
  }
  out.write_string("}\n")
}

///|
fn WgslIrEmitter::emit_struct_member_layout_attribute_prefix(
  self : WgslIrEmitter,
  out : StringBuilder,
  struct_member : StructMember,
) -> Unit {
  ignore(self)
  match struct_member.size {
    Some(size) => out.write_string("@size(\{size}) ")
    None => ()
  }
  match struct_member.align {
    Some(align) => out.write_string("@align(\{align}) ")
    None => ()
  }
}

///|
fn WgslIrEmitter::emit_constant(
  self : WgslIrEmitter,
  out : StringBuilder,
  constant : Constant,
) -> Unit raise WgslIrEmitError {
  guard constant.name is Some(name) else {
    raise WgslIrEmitError::MissingName("constant")
  }
  if self.type_contains_abstract_scalar(constant.ty) {
    out.write_string(
      "const \{sanitize_wgsl_ir_identifier(name)} = \{self.abstract_float_global_expression(constant.init)};\n",
    )
  } else {
    out.write_string(
      "const \{sanitize_wgsl_ir_identifier(name)}: \{self.type_name(constant.ty)} = \{self.global_expression(constant.init)};\n",
    )
  }
}

///|
fn WgslIrEmitter::emit_override(
  self : WgslIrEmitter,
  out : StringBuilder,
  override_ : Override,
) -> Unit raise WgslIrEmitError {
  match override_.id {
    Some(id) => out.write_string("@id(\{id}) ")
    None => ()
  }
  guard override_.name is Some(name) else {
    raise WgslIrEmitError::MissingName("override")
  }
  if self.type_contains_abstract_scalar(override_.ty) {
    out.write_string("override \{sanitize_wgsl_ir_identifier(name)}")
  } else {
    out.write_string(
      "override \{sanitize_wgsl_ir_identifier(name)}: \{self.type_name(override_.ty)}",
    )
  }
  match override_.init {
    Some(init) => out.write_string(" = \{self.global_expression(init)}")
    None => ()
  }
  out.write_string(";\n")
}

///|
fn WgslIrEmitter::emit_global_variable(
  self : WgslIrEmitter,
  out : StringBuilder,
  global : GlobalVariable,
) -> Unit raise WgslIrEmitError {
  match global.binding {
    Some(binding) =>
      out.write_string(
        "@group(\{binding.group}) @binding(\{binding.binding}) \n",
      )
    None => ()
  }
  guard global.name is Some(name) else {
    raise WgslIrEmitError::MissingName("global variable")
  }
  let space = self.address_space_template(global.space)
  out.write_string(
    "var\{space} \{sanitize_wgsl_ir_identifier(name)}: \{self.type_name(global.ty)}",
  )
  match global.init {
    Some(init) => out.write_string(" = \{self.global_expression(init)}")
    None => ()
  }
  out.write_string(";\n")
}

///|
fn WgslIrEmitter::type_is_pointer(
  self : WgslIrEmitter,
  handle : Handle,
) -> Bool {
  match self.shader_module.types.get(handle) {
    Some(ty) =>
      match ty.inner {
        Pointer(_, _) | ValuePointer(_, _, _) => true
        _ => false
      }
    None => false
  }
}

///|
fn WgslIrEmitter::type_contains_abstract_scalar(
  self : WgslIrEmitter,
  handle : Handle,
) -> Bool {
  match self.shader_module.types.get(handle) {
    Some(ty) => self.type_inner_contains_abstract_scalar(ty.inner)
    None => false
  }
}

///|
fn WgslIrEmitter::type_inner_contains_abstract_scalar(
  self : WgslIrEmitter,
  inner : TypeInner,
) -> Bool {
  match inner {
    Scalar(scalar)
    | Vector(_, scalar)
    | Matrix(_, _, scalar)
    | CooperativeMatrix(_, _, scalar, _)
    | Atomic(scalar)
    | ValuePointer(_, scalar, _) =>
      scalar.kind == AbstractInt || scalar.kind == AbstractFloat
    Pointer(base, _) | Array(base, _, _) | BindingArray(base, _) =>
      self.type_contains_abstract_scalar(base)
    Struct(members, _) | PredeclaredStruct(members, _) => {
      for struct_member in members {
        if self.type_contains_abstract_scalar(struct_member.ty) {
          return true
        }
      }
      false
    }
    Image(_, _, _) | Sampler(_) | AccelerationStructure(_) | RayQuery(_) =>
      false
  }
}

///|
fn WgslIrEmitter::expression_is_pointer(
  self : WgslIrEmitter,
  function : Function?,
  handle : Handle,
) -> Bool {
  match self.expression_type(function, handle) {
    Some(ty) => self.type_is_pointer(ty)
    None => false
  }
}

///|
fn WgslIrEmitter::emit_entry_point(
  self : WgslIrEmitter,
  out : StringBuilder,
  entry_point : EntryPoint,
) -> Unit raise WgslIrEmitError {
  out.write_string(self.stage_attribute(entry_point.stage))
  if entry_point.stage == Compute {
    out.write_string(" @workgroup_size(")
    out.write_string(self.workgroup_size_component(entry_point, 0))
    out.write_string(", ")
    out.write_string(self.workgroup_size_component(entry_point, 1))
    out.write_string(", ")
    out.write_string(self.workgroup_size_component(entry_point, 2))
    out.write_string(")")
  } else {
    out.write_string(" ")
  }
  out.write_string("\n")
  self.emit_function(out, entry_point.function, Some(entry_point.name))
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
  name_override : String?,
) -> Unit raise WgslIrEmitError {
  let name = match name_override {
    Some(value) => sanitize_wgsl_ir_identifier(value)
    None =>
      match function.name {
        Some(value) => sanitize_wgsl_ir_identifier(value)
        None => raise WgslIrEmitError::MissingName("function")
      }
  }
  out.write_string("fn \{name}(")
  for index in 0..<function.arguments.length() {
    if index > 0 {
      out.write_string(", ")
    }
    self.emit_function_argument(out, function, index)
  }
  out.write_string(")")
  match function.result {
    Some(result) => {
      out.write_string(" -> ")
      self.emit_binding_attribute_prefix(out, result.binding)
      out.write_string(self.type_name(result.ty))
    }
    None => ()
  }
  out.write_string(" {\n")
  self.emit_function_local_var_declarations(out, function, 1)
  self.emit_block_statements(out, function, function.body, 1)
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
    raise WgslIrEmitError::MissingHandle("function argument \{index}")
  }
  self.emit_binding_attribute_prefix(out, argument.binding)
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
    None =>
      raise WgslIrEmitError::MissingHandle("local variable \{handle.index()}")
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
      let init_expr = self.function_expression(function, init)
      if self.type_is_pointer(local_var.ty) &&
        wgsl_ir_expression_text_needs_address(init_expr) &&
        !self.expression_is_pointer(Some(function), init) {
        out.write_string(
          " = &\{self.function_pointer_expression(function, init)}",
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
fn WgslIrEmitter::emit_function_local_var_declarations(
  self : WgslIrEmitter,
  out : StringBuilder,
  function : Function,
  indent : Int,
) -> Unit raise WgslIrEmitError {
  let mut emitted = false
  for index in 0..<function.local_variables.items.length() {
    let handle = Handle::Handle(index)
    match function.local_variables.items.get(index) {
      Some(local_var) =>
        if local_var.kind == LocalVariableKind::Var && local_var.init == None {
          self.emit_local_declaration(out, function, handle, indent)
          emitted = true
        }
      _ => ()
    }
  }
  if emitted && self.block_has_non_var_statement(function, function.body) {
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
  !self.type_is_predeclared_result(local_var.ty)
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

///|
fn WgslIrEmitter::emit_block_statements(
  self : WgslIrEmitter,
  out : StringBuilder,
  function : Function,
  block : Block,
  indent : Int,
) -> Unit raise WgslIrEmitError {
  let mut emitted_leading_var_declaration = false
  let mut separated_leading_var_declarations = false
  for statement in block.statements {
    if self.statement_is_local_var_declaration(function, statement) {
      continue
    }
    if emitted_leading_var_declaration &&
      !separated_leading_var_declarations &&
      !self.statement_is_any_local_var_declaration(function, statement) {
      out.write_string("\n")
      separated_leading_var_declarations = true
    }
    self.emit_statement(out, function, statement, indent)
    if !separated_leading_var_declarations &&
      self.statement_is_any_local_var_declaration(function, statement) {
      emitted_leading_var_declaration = true
    }
  }
}

///|
fn WgslIrEmitter::statement_is_local_var_declaration(
  self : WgslIrEmitter,
  function : Function,
  statement : Statement,
) -> Bool {
  ignore(self)
  match statement {
    Declare(handle) =>
      match function.local_variables.items.get(handle.index()) {
        Some(local_var) =>
          local_var.kind == LocalVariableKind::Var && local_var.init == None
        None => false
      }
    _ => false
  }
}

///|
fn WgslIrEmitter::statement_is_any_local_var_declaration(
  self : WgslIrEmitter,
  function : Function,
  statement : Statement,
) -> Bool {
  ignore(self)
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
fn WgslIrEmitter::block_has_non_var_statement(
  self : WgslIrEmitter,
  function : Function,
  block : Block,
) -> Bool {
  for statement in block.statements {
    if !self.statement_is_local_var_declaration(function, statement) {
      return true
    }
  }
  false
}

///|
fn WgslIrEmitter::emit_statement(
  self : WgslIrEmitter,
  out : StringBuilder,
  function : Function,
  statement : Statement,
  indent : Int,
) -> Unit raise WgslIrEmitError {
  let pad = wgsl_ir_indent(indent)
  match statement {
    Declare(handle) =>
      self.emit_local_declaration(out, function, handle, indent)
    Emit(range) =>
      for index in range.start.index()..<=range.end.index() {
        let handle = Handle::Handle(index)
        let expr = self.function_expression(function, handle)
        if self.expression_type(Some(function), handle) == None &&
          !self.function_expression_requires_phony_assignment(function, handle) {
          out.write_string("\{pad}\{expr};\n")
        } else {
          out.write_string("\{pad}_ = \{expr};\n")
        }
      }
    Block(child) => {
      out.write_string("\{pad}{\n")
      self.emit_block_statements(out, function, child, indent + 1)
      out.write_string("\{pad}}\n")
    }
    If(condition, accept, reject) => {
      out.write_string(
        "\{pad}if \{self.function_expression(function, condition)} {\n",
      )
      self.emit_block_statements(out, function, accept, indent + 1)
      out.write_string("\{pad}}")
      if reject.statements.is_empty() {
        out.write_string("\n")
      } else {
        out.write_string(" else {\n")
        self.emit_block_statements(out, function, reject, indent + 1)
        out.write_string("\{pad}}\n")
      }
    }
    Loop(body, continuing, break_if) => {
      out.write_string("\{pad}loop {\n")
      self.emit_block_statements(out, function, body, indent + 1)
      let has_break_if = match break_if {
        Some(_) => true
        None => false
      }
      if !continuing.statements.is_empty() || has_break_if {
        out.write_string("\{wgsl_ir_indent(indent + 1)}continuing {\n")
        self.emit_block_statements(out, function, continuing, indent + 2)
        match break_if {
          Some(condition) =>
            out.write_string(
              "\{wgsl_ir_indent(indent + 2)}break if \{self.function_expression(function, condition)};\n",
            )
          None => ()
        }
        out.write_string("\{wgsl_ir_indent(indent + 1)}}\n")
      }
      out.write_string("\{pad}}\n")
    }
    Switch(selector, cases) => {
      out.write_string(
        "\{pad}switch \{self.function_expression(function, selector)} {\n",
      )
      for case in cases {
        out.write_string(
          "\{wgsl_ir_indent(indent + 1)}\{wgsl_ir_switch_case_label(case.value)} {\n",
        )
        self.emit_block_statements(out, function, case.body, indent + 2)
        out.write_string("\{wgsl_ir_indent(indent + 1)}}\n")
      }
      out.write_string("\{pad}}\n")
    }
    Break => out.write_string("\{pad}break;\n")
    Continue => out.write_string("\{pad}continue;\n")
    Return(value) =>
      match value {
        Some(handle) =>
          out.write_string(
            "\{pad}return \{self.function_expression(function, handle)};\n",
          )
        None => out.write_string("\{pad}return;\n")
      }
    Kill => out.write_string("\{pad}discard;\n")
    ConstAssert(condition) =>
      out.write_string(
        "\{pad}const_assert \{self.abstract_float_function_expression(function, condition)};\n",
      )
    ControlBarrier(barrier) =>
      self.emit_control_barrier_statement(out, barrier, indent)
    MemoryBarrier(barrier) =>
      self.emit_memory_barrier_statement(out, barrier, indent)
    Store(pointer, value) =>
      out.write_string(
        "\{pad}\{self.function_store_pointer_expression(function, pointer)} = \{self.function_expression(function, value)};\n",
      )
    ImageStore(image, coordinate, array_index, value) => {
      out.write_string(
        "\{pad}textureStore(\{self.function_expression(function, image)}, \{self.function_expression(function, coordinate)}",
      )
      match array_index {
        Some(index) =>
          out.write_string(", \{self.function_expression(function, index)}")
        None => ()
      }
      out.write_string(", \{self.function_expression(function, value)});\n")
    }
    ImageAtomic(image, coordinate, array_index, atomic_function, value) => {
      out.write_string(
        "\{pad}\{self.texture_atomic_function_name(atomic_function)}(\{self.function_expression(function, image)}, \{self.function_expression(function, coordinate)}",
      )
      match array_index {
        Some(index) =>
          out.write_string(", \{self.function_expression(function, index)}")
        None => ()
      }
      out.write_string(", \{self.function_expression(function, value)});\n")
    }
    Call(function_handle, arguments, result) => {
      match result {
        Some(_) =>
          raise WgslIrEmitError::Unsupported(
            "call statement with result handle",
          )
        None => ()
      }
      out.write_string("\{pad}\{self.function_name(function_handle)}(")
      self.emit_function_call_arguments(out, function, arguments)
      out.write_string(");\n")
    }
    RayQuery(query, query_function) =>
      self.emit_ray_query_statement(
        out, function, query, query_function, indent,
      )
    CooperativeStore(target, data) =>
      self.emit_cooperative_store_statement(out, function, target, data, indent)
    _ => raise WgslIrEmitError::Unsupported("statement kind")
  }
}

///|
fn WgslIrEmitter::function_expression_requires_phony_assignment(
  self : WgslIrEmitter,
  function : Function,
  handle : Handle,
) -> Bool {
  ignore(self)
  match function.expressions.items.get(handle.index()) {
    Some(expression) =>
      match expression {
        ImageSample(_, _, _, _, _, _, _, _, _)
        | ImageLoad(_, _, _, _, _)
        | ImageQuery(_, _)
        | WorkGroupUniformLoad(_)
        | SubgroupCall(_, _) => true
        _ => false
      }
    None => false
  }
}

///|
fn WgslIrEmitter::function_store_pointer_expression(
  self : WgslIrEmitter,
  function : Function,
  handle : Handle,
) -> String raise WgslIrEmitError {
  let expression = match function.expressions.items.get(handle.index()) {
    Some(value) => value
    None =>
      raise WgslIrEmitError::MissingHandle(
        "function store pointer expression \{handle.index()}",
      )
  }
  let text = self.function_pointer_expression(function, handle)
  match expression {
    Access(_, _) | AccessIndex(_, _) | Swizzle(_, _, _) => text
    _ =>
      match self.expression_type(Some(function), handle) {
        Some(ty) =>
          match self.shader_module.types.items.get(ty.index()) {
            Some(type_) =>
              match type_.inner {
                Pointer(_, _) => "*(\{text})"
                _ => text
              }
            None => text
          }
        None => text
      }
  }
}

///|
fn WgslIrEmitter::emit_control_barrier_statement(
  self : WgslIrEmitter,
  out : StringBuilder,
  barrier : Barrier,
  indent : Int,
) -> Unit raise WgslIrEmitError {
  let pad = wgsl_ir_indent(indent)
  if barrier == Barrier::work_group() {
    out.write_string("\{pad}workgroupBarrier();\n")
  } else if barrier == Barrier::sub_group() {
    out.write_string("\{pad}subgroupBarrier();\n")
  } else {
    ignore(self)
    raise WgslIrEmitError::Unsupported("control barrier flags")
  }
}

///|
fn WgslIrEmitter::emit_memory_barrier_statement(
  self : WgslIrEmitter,
  out : StringBuilder,
  barrier : Barrier,
  indent : Int,
) -> Unit raise WgslIrEmitError {
  let pad = wgsl_ir_indent(indent)
  if barrier == Barrier::storage() {
    out.write_string("\{pad}storageBarrier();\n")
  } else if barrier == Barrier::texture() {
    out.write_string("\{pad}textureBarrier();\n")
  } else {
    ignore(self)
    raise WgslIrEmitError::Unsupported("memory barrier flags")
  }
}

///|
fn WgslIrEmitter::emit_ray_query_statement(
  self : WgslIrEmitter,
  out : StringBuilder,
  function : Function,
  query : Handle,
  query_function : RayQueryFunction,
  indent : Int,
) -> Unit raise WgslIrEmitError {
  let pad = wgsl_ir_indent(indent)
  match query_function {
    Initialize(acceleration, ray_desc) =>
      out.write_string(
        "\{pad}rayQueryInitialize(\{self.function_expression(function, query)}, \{self.function_expression(function, acceleration)}, \{self.function_expression(function, ray_desc)});\n",
      )
    Proceed(_) =>
      out.write_string(
        "\{pad}rayQueryProceed(\{self.function_expression(function, query)});\n",
      )
    GenerateIntersection(intersection_t) =>
      out.write_string(
        "\{pad}rayQueryGenerateIntersection(\{self.function_expression(function, query)}, \{self.function_expression(function, intersection_t)});\n",
      )
    ConfirmIntersection =>
      out.write_string(
        "\{pad}rayQueryConfirmIntersection(\{self.function_expression(function, query)});\n",
      )
    Terminate =>
      out.write_string(
        "\{pad}rayQueryTerminate(\{self.function_expression(function, query)});\n",
      )
  }
}

///|
fn wgsl_ir_switch_case_label(value : SwitchValue) -> String {
  match value {
    I32(value) => "case \{value}i"
    U32(value) => "case \{value}u"
    Default => "default"
  }
}

///|
fn WgslIrEmitter::emit_function_call_arguments(
  self : WgslIrEmitter,
  out : StringBuilder,
  function : Function,
  arguments : Array[Handle],
) -> Unit raise WgslIrEmitError {
  for index in 0..<arguments.length() {
    if index > 0 {
      out.write_string(", ")
    }
    out.write_string(self.function_expression(function, arguments[index]))
  }
}

///|
fn WgslIrEmitter::global_expression(
  self : WgslIrEmitter,
  handle : Handle,
) -> String raise WgslIrEmitError {
  let expression = match
    self.shader_module.global_expressions.items.get(handle.index()) {
    Some(value) => value
    None =>
      raise WgslIrEmitError::MissingHandle(
        "global expression \{handle.index()}",
      )
  }
  self.emit_expression(expression, None)
}

///|
fn WgslIrEmitter::abstract_float_global_expression(
  self : WgslIrEmitter,
  handle : Handle,
) -> String raise WgslIrEmitError {
  self.with_preserved_abstract_float_literals().global_expression(handle)
}

///|
fn WgslIrEmitter::function_expression(
  self : WgslIrEmitter,
  function : Function,
  handle : Handle,
) -> String raise WgslIrEmitError {
  let expression = match function.expressions.items.get(handle.index()) {
    Some(value) => value
    None =>
      raise WgslIrEmitError::MissingHandle(
        "function expression \{handle.index()}",
      )
  }
  self.emit_expression(expression, Some(function))
}

///|
fn WgslIrEmitter::abstract_float_function_expression(
  self : WgslIrEmitter,
  function : Function,
  handle : Handle,
) -> String raise WgslIrEmitError {
  self
  .with_preserved_abstract_float_literals()
  .function_expression(function, handle)
}

///|
fn WgslIrEmitter::function_pointer_expression(
  self : WgslIrEmitter,
  function : Function,
  handle : Handle,
) -> String raise WgslIrEmitError {
  let expression = match function.expressions.items.get(handle.index()) {
    Some(value) => value
    None =>
      raise WgslIrEmitError::MissingHandle(
        "function pointer expression \{handle.index()}",
      )
  }
  match expression {
    Load(inner) => self.function_pointer_expression(function, inner)
    _ => self.emit_expression(expression, Some(function))
  }
}

///|
fn WgslIrEmitter::load_expression(
  self : WgslIrEmitter,
  function : Function?,
  pointer : Handle,
) -> String raise WgslIrEmitError {
  let expression = self.required_function_expression(function, pointer)
  if self.load_expression_requires_explicit_deref(function, pointer) {
    "*(\{expression})"
  } else {
    expression
  }
}

///|
fn WgslIrEmitter::load_expression_requires_explicit_deref(
  self : WgslIrEmitter,
  function : Function?,
  pointer : Handle,
) -> Bool raise WgslIrEmitError {
  let expression = match function {
    Some(function) =>
      match function.expressions.items.get(pointer.index()) {
        Some(expression) => expression
        None =>
          raise WgslIrEmitError::MissingHandle(
            "function load expression \{pointer.index()}",
          )
      }
    None =>
      match self.shader_module.global_expressions.items.get(pointer.index()) {
        Some(expression) => expression
        None =>
          raise WgslIrEmitError::MissingHandle(
            "global load expression \{pointer.index()}",
          )
      }
  }
  match expression {
    Access(_, _) | AccessIndex(_, _) | Swizzle(_, _, _) => false
    Load(inner) => self.load_expression_requires_explicit_deref(function, inner)
    _ =>
      match self.expression_type(function, pointer) {
        Some(ty) =>
          match self.shader_module.types.items.get(ty.index()) {
            Some(type_) =>
              match type_.inner {
                Pointer(_, _) => true
                _ => false
              }
            None => false
          }
        None => false
      }
  }
}

///|
fn WgslIrEmitter::access_base_expression(
  self : WgslIrEmitter,
  function : Function?,
  base : Handle,
) -> String raise WgslIrEmitError {
  let expression = self.required_function_expression(function, base)
  let needs_parens = match function {
    Some(function) =>
      match function.expressions.items.get(base.index()) {
        Some(Load(inner)) =>
          self.load_expression_requires_explicit_deref(Some(function), inner)
        Some(Binary(_, _, _)) | Some(Select(_, _, _)) => true
        _ => false
      }
    None =>
      match self.shader_module.global_expressions.items.get(base.index()) {
        Some(Load(inner)) =>
          self.load_expression_requires_explicit_deref(None, inner)
        Some(Binary(_, _, _)) | Some(Select(_, _, _)) => true
        _ => false
      }
  }
  if needs_parens {
    "(\{expression})"
  } else {
    expression
  }
}

///|
fn WgslIrEmitter::emit_expression(
  self : WgslIrEmitter,
  expression : Expression,
  function : Function?,
) -> String raise WgslIrEmitError {
  match expression {
    Literal(literal) => self.literal(literal)
    Constant(handle) => self.constant_name(handle)
    Override(handle) => self.override_name(handle)
    ZeroValue(ty) => "\{self.type_name(ty)}()"
    Compose(ty, components) =>
      "\{self.compose_constructor_name_for_components(ty, components, function)}(\{self.expression_list(components, function)})"
    Access(base, index) =>
      "\{self.access_base_expression(function, base)}[\{self.required_function_expression(function, index)}]"
    AccessIndex(base, index) =>
      "\{self.access_base_expression(function, base)}.\{self.member_name_for_expression(function, base, index)}"
    Swizzle(_, base, components) =>
      "\{self.access_base_expression(function, base)}.\{self.swizzle_components(components)}"
    FunctionArgument(index) => self.function_argument_name(function, index)
    GlobalVariable(handle) => self.global_variable_name(handle)
    LocalVariable(handle) => self.local_variable_name(function, handle)
    Load(pointer) => self.load_expression(function, pointer)
    AddressOf(_, target) =>
      match function {
        Some(func) => "&\{self.function_pointer_expression(func, target)}"
        None =>
          raise WgslIrEmitError::Unsupported("global address-of expression")
      }
    AtomicCall(atomic_function, arguments) =>
      self.atomic_call_expression(function, atomic_function, arguments)
    ImageSample(
      image,
      sampler,
      gather,
      coordinate,
      array_index,
      offset,
      level,
      depth_ref,
      clamp_to_edge
    ) =>
      self.image_sample_expression(
        function, image, sampler, gather, coordinate, array_index, offset, level,
        depth_ref, clamp_to_edge,
      )
    ImageLoad(image, coordinate, array_index, sample, level) =>
      self.image_load_expression(
        function, image, coordinate, array_index, sample, level,
      )
    ImageQuery(image, query) =>
      self.image_query_expression(function, image, query)
    ArrayLength(pointer) =>
      "arrayLength(\{self.atomic_pointer_expression(function, pointer)})"
    RayQueryInitialize(query, acceleration, ray_desc) =>
      "rayQueryInitialize(\{self.required_function_expression(function, query)}, \{self.required_function_expression(function, acceleration)}, \{self.required_function_expression(function, ray_desc)})"
    RayQueryProceed(query) =>
      "rayQueryProceed(\{self.required_function_expression(function, query)})"
    RayQueryGenerateIntersection(query, intersection_t) =>
      "rayQueryGenerateIntersection(\{self.required_function_expression(function, query)}, \{self.required_function_expression(function, intersection_t)})"
    RayQueryConfirmIntersection(query) =>
      "rayQueryConfirmIntersection(\{self.required_function_expression(function, query)})"
    RayQueryTerminate(query) =>
      "rayQueryTerminate(\{self.required_function_expression(function, query)})"
    RayQueryGetIntersection(query, committed) =>
      self.ray_query_get_intersection_expression(function, query, committed)
    SubgroupCall(subgroup_function, arguments) =>
      "\{wgsl_ir_emit_subgroup_function_name(subgroup_function)}(\{self.expression_list(arguments, function)})"
    CooperativeLoad(columns, rows, role, data) =>
      self.cooperative_load_expression(function, columns, rows, role, data)
    CooperativeMultiplyAdd(a, b, c) =>
      "coopMultiplyAdd(\{self.required_function_expression(function, a)}, \{self.required_function_expression(function, b)}, \{self.required_function_expression(function, c)})"
    WorkGroupUniformLoad(pointer) =>
      "workgroupUniformLoad(\{self.required_function_expression(function, pointer)})"
    Unary(op, expr) =>
      "\{self.unary_operator(op)}(\{self.required_function_expression(function, expr)})"
    Binary(op, left, right) =>
      "(\{self.required_function_expression(function, left)} \{self.binary_operator(op)} \{self.required_function_expression(function, right)})"
    Select(condition, accept, reject) =>
      "select(\{self.required_function_expression(function, reject)}, \{self.required_function_expression(function, accept)}, \{self.required_function_expression(function, condition)})"
    Bitcast(ty, expr) =>
      "bitcast<\{self.type_name(ty)}>(\{self.required_function_expression(function, expr)})"
    Derivative(axis, control, expr) =>
      "\{wgsl_ir_derivative_function_name(axis, control)}(\{self.required_function_expression(function, expr)})"
    FunctionCall(handle, arguments) =>
      "\{self.function_name(handle)}(\{self.expression_list(arguments, function)})"
    Math(math_function, a, b, c, d) =>
      "\{self.math_function_name(math_function)}(\{self.math_argument_list(a, b, c, d, function)})"
    Relational(relational_function, expr) =>
      "\{self.relational_function_name(relational_function)}(\{self.required_function_expression(function, expr)})"
    CallResult(handle) => self.function_name(handle)
    _ => raise WgslIrEmitError::Unsupported("expression kind")
  }
}

///|
fn WgslIrEmitter::image_sample_expression(
  self : WgslIrEmitter,
  function : Function?,
  image : Handle,
  sampler : Handle,
  gather : SwizzleComponent?,
  coordinate : Handle,
  array_index : Handle?,
  offset : Handle?,
  level : SampleLevel,
  depth_ref : Handle?,
  clamp_to_edge : Bool,
) -> String raise WgslIrEmitError {
  match gather {
    Some(component) =>
      return self.image_gather_expression(
        function, image, sampler, component, coordinate, array_index, offset, depth_ref,
      )
    None => ()
  }
  if clamp_to_edge {
    if array_index != None || offset != None || depth_ref != None {
      raise WgslIrEmitError::Unsupported(
        "textureSampleBaseClampToEdge advanced arguments",
      )
    }
    let callee = "textureSampleBaseClampToEdge"
    return "\{callee}(\{self.required_function_expression(function, image)}, \{self.required_function_expression(function, sampler)}, \{self.required_function_expression(function, coordinate)})"
  }
  let callee = match depth_ref {
    Some(_) =>
      match level {
        Auto => "textureSampleCompare"
        Zero => "textureSampleCompareLevel"
        _ =>
          raise WgslIrEmitError::Unsupported(
            "texture compare sampling level mode",
          )
      }
    None =>
      match level {
        Auto => "textureSample"
        Exact(_) => "textureSampleLevel"
        Bias(_) => "textureSampleBias"
        Gradient(_, _) => "textureSampleGrad"
        Zero => "textureSampleLevel"
      }
  }
  let out = StringBuilder::new()
  out.write_string(
    "\{callee}(\{self.required_function_expression(function, image)}, \{self.required_function_expression(function, sampler)}, \{self.required_function_expression(function, coordinate)}",
  )
  match array_index {
    Some(index) =>
      out.write_string(
        ", \{self.required_function_expression(function, index)}",
      )
    None => ()
  }
  match level {
    Exact(handle) =>
      out.write_string(
        ", \{self.required_function_expression(function, handle)}",
      )
    Bias(handle) =>
      out.write_string(
        ", \{self.required_function_expression(function, handle)}",
      )
    Gradient(ddx, ddy) =>
      out.write_string(
        ", \{self.required_function_expression(function, ddx)}, \{self.required_function_expression(function, ddy)}",
      )
    Zero if depth_ref == None => out.write_string(", 0")
    _ => ()
  }
  match depth_ref {
    Some(handle) =>
      out.write_string(
        ", \{self.required_function_expression(function, handle)}",
      )
    None => ()
  }
  match offset {
    Some(handle) =>
      out.write_string(
        ", \{self.required_function_expression(function, handle)}",
      )
    None => ()
  }
  out.write_string(")")
  out.to_string()
}

///|
fn WgslIrEmitter::atomic_call_expression(
  self : WgslIrEmitter,
  function : Function?,
  atomic_function : AtomicFunction,
  arguments : Array[Handle],
) -> String raise WgslIrEmitError {
  guard arguments is [pointer, .. rest] else {
    raise WgslIrEmitError::Unsupported("atomic call without pointer")
  }
  let out = StringBuilder::new()
  let pointer_text = self.atomic_pointer_expression(function, pointer)
  out.write_string(
    "\{self.atomic_function_name(atomic_function)}(\{wgsl_ir_atomic_pointer_argument_text(pointer_text)}",
  )
  for argument in rest {
    out.write_string(
      ", \{self.required_function_expression(function, argument)}",
    )
  }
  out.write_string(")")
  out.to_string()
}

///|
fn wgsl_ir_atomic_pointer_argument_text(text : String) -> String {
  if text.length() > 0 && text[0:1] == "&" {
    "(\{text})"
  } else {
    text
  }
}

///|
fn WgslIrEmitter::atomic_pointer_expression(
  self : WgslIrEmitter,
  function : Function?,
  pointer : Handle,
) -> String raise WgslIrEmitError {
  if self.expression_is_pointer(function, pointer) {
    self.required_function_expression(function, pointer)
  } else {
    "&\{self.required_function_expression(function, pointer)}"
  }
}

///|
fn WgslIrEmitter::emit_cooperative_store_statement(
  self : WgslIrEmitter,
  out : StringBuilder,
  function : Function,
  target : Handle,
  data : CooperativeData,
  indent : Int,
) -> Unit raise WgslIrEmitError {
  let suffix = if data.row_major { "T" } else { "" }
  out.write_string(
    "\{wgsl_ir_indent(indent)}coopStore\{suffix}(\{self.function_expression(function, target)}, \{self.atomic_pointer_expression(Some(function), data.pointer)}, \{self.function_expression(function, data.stride)});\n",
  )
}

///|
fn WgslIrEmitter::cooperative_load_expression(
  self : WgslIrEmitter,
  function : Function?,
  columns : CooperativeSize,
  rows : CooperativeSize,
  role : CooperativeRole,
  data : CooperativeData,
) -> String raise WgslIrEmitError {
  let suffix = if data.row_major { "T" } else { "" }
  let scalar = match self.cooperative_data_scalar(function, data) {
    Some(scalar) => scalar
    None =>
      raise WgslIrEmitError::Unsupported("cooperative load pointer scalar type")
  }
  "coopLoad\{suffix}<coop_mat\{wgsl_ir_cooperative_size_name(columns)}x\{wgsl_ir_cooperative_size_name(rows)}<\{self.scalar_name(scalar)}, \{wgsl_ir_cooperative_role_name(role)}>>(\{self.atomic_pointer_expression(function, data.pointer)}, \{self.required_function_expression(function, data.stride)})"
}

///|
fn WgslIrEmitter::cooperative_data_scalar(
  self : WgslIrEmitter,
  function : Function?,
  data : CooperativeData,
) -> Scalar? {
  match self.expression_type(function, data.pointer) {
    Some(ty) => self.cooperative_pointer_scalar(ty)
    None => None
  }
}

///|
fn WgslIrEmitter::cooperative_pointer_scalar(
  self : WgslIrEmitter,
  ty : Handle,
) -> Scalar? {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Pointer(base, _) => self.cooperative_pointer_scalar(base)
        ValuePointer(_, scalar, _) => Some(scalar)
        Scalar(scalar) => Some(scalar)
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrEmitter::image_gather_expression(
  self : WgslIrEmitter,
  function : Function?,
  image : Handle,
  sampler : Handle,
  component : SwizzleComponent,
  coordinate : Handle,
  array_index : Handle?,
  offset : Handle?,
  depth_ref : Handle?,
) -> String raise WgslIrEmitError {
  let callee = if depth_ref != None {
    "textureGatherCompare"
  } else {
    "textureGather"
  }
  let out = StringBuilder::new()
  out.write_string("\{callee}(")
  if depth_ref == None {
    out.write_string("\{wgsl_ir_gather_component_index(component)}, ")
  }
  out.write_string(
    "\{self.required_function_expression(function, image)}, \{self.required_function_expression(function, sampler)}, \{self.required_function_expression(function, coordinate)}",
  )
  match array_index {
    Some(handle) =>
      out.write_string(
        ", \{self.required_function_expression(function, handle)}",
      )
    None => ()
  }
  match depth_ref {
    Some(handle) =>
      out.write_string(
        ", \{self.required_function_expression(function, handle)}",
      )
    None => ()
  }
  match offset {
    Some(handle) =>
      out.write_string(
        ", \{self.required_function_expression(function, handle)}",
      )
    None => ()
  }
  out.write_string(")")
  out.to_string()
}

///|
fn WgslIrEmitter::image_load_expression(
  self : WgslIrEmitter,
  function : Function?,
  image : Handle,
  coordinate : Handle,
  array_index : Handle?,
  sample : Handle?,
  level : Handle?,
) -> String raise WgslIrEmitError {
  let out = StringBuilder::new()
  out.write_string(
    "textureLoad(\{self.required_function_expression(function, image)}, \{self.required_function_expression(function, coordinate)}",
  )
  match array_index {
    Some(index) =>
      out.write_string(
        ", \{self.required_function_expression(function, index)}",
      )
    None => ()
  }
  match sample {
    Some(handle) =>
      out.write_string(
        ", \{self.required_function_expression(function, handle)}",
      )
    None => ()
  }
  match level {
    Some(handle) =>
      out.write_string(
        ", \{self.required_function_expression(function, handle)}",
      )
    None => ()
  }
  out.write_string(")")
  out.to_string()
}

///|
fn WgslIrEmitter::image_query_expression(
  self : WgslIrEmitter,
  function : Function?,
  image : Handle,
  query : ImageQuery,
) -> String raise WgslIrEmitError {
  match query {
    Size(level) => {
      let out = StringBuilder::new()
      out.write_string(
        "textureDimensions(\{self.required_function_expression(function, image)}",
      )
      match level {
        Some(handle) =>
          out.write_string(
            ", \{self.required_function_expression(function, handle)}",
          )
        None => ()
      }
      out.write_string(")")
      out.to_string()
    }
    NumLevels =>
      "textureNumLevels(\{self.required_function_expression(function, image)})"
    NumLayers =>
      "textureNumLayers(\{self.required_function_expression(function, image)})"
    NumSamples =>
      "textureNumSamples(\{self.required_function_expression(function, image)})"
  }
}

///|
fn WgslIrEmitter::ray_query_get_intersection_expression(
  self : WgslIrEmitter,
  function : Function?,
  query : Handle,
  committed : Bool,
) -> String raise WgslIrEmitError {
  let name = if committed {
    "rayQueryGetCommittedIntersection"
  } else {
    "rayQueryGetCandidateIntersection"
  }
  "\{name}(\{self.required_function_expression(function, query)})"
}

///|
fn WgslIrEmitter::member_name_for_expression(
  self : WgslIrEmitter,
  function : Function?,
  base : Handle,
  index : Int,
) -> String raise WgslIrEmitError {
  match self.expression_type(function, base) {
    Some(ty_handle) =>
      match
        self.shader_module.types.items.get(
          self.deref_pointer_type_handle(ty_handle).index(),
        ) {
        Some(ty) =>
          match ty.inner {
            Struct(members, _) | PredeclaredStruct(members, _) =>
              match members.get(index) {
                Some(struct_member) =>
                  match struct_member.name {
                    Some(name) => sanitize_wgsl_ir_identifier(name)
                    None => wgsl_ir_swizzle_component(index)
                  }
                None => wgsl_ir_swizzle_component(index)
              }
            _ => wgsl_ir_swizzle_component(index)
          }
        None => wgsl_ir_swizzle_component(index)
      }
    None => wgsl_ir_swizzle_component(index)
  }
}

///|
fn WgslIrEmitter::deref_pointer_type_handle(
  self : WgslIrEmitter,
  ty_handle : Handle,
) -> Handle {
  match self.shader_module.types.items.get(ty_handle.index()) {
    Some(ty) =>
      match ty.inner {
        Pointer(inner, _) => self.deref_pointer_type_handle(inner)
        _ => ty_handle
      }
    None => ty_handle
  }
}

///|
fn WgslIrEmitter::swizzle_components(
  self : WgslIrEmitter,
  components : Array[SwizzleComponent],
) -> String {
  ignore(self)
  let out = StringBuilder::new()
  for component in components {
    out.write_string(wgsl_ir_swizzle_component_name(component))
  }
  out.to_string()
}

///|
fn WgslIrEmitter::expression_type(
  self : WgslIrEmitter,
  function : Function?,
  handle : Handle,
) -> Handle? {
  match function {
    Some(function) =>
      match function.expressions.items.get(handle.index()) {
        Some(expression) =>
          self.function_expression_inner_type(function, expression)
        None => None
      }
    None =>
      match self.shader_module.global_expressions.items.get(handle.index()) {
        Some(expression) => self.global_expression_inner_type(expression)
        None => None
      }
  }
}

///|
fn WgslIrEmitter::function_expression_inner_type(
  self : WgslIrEmitter,
  function : Function,
  expression : Expression,
) -> Handle? {
  match expression {
    FunctionArgument(index) =>
      match function.arguments.get(index) {
        Some(argument) => Some(argument.ty)
        None => None
      }
    LocalVariable(handle) =>
      match function.local_variables.items.get(handle.index()) {
        Some(local_variable) => Some(local_variable.ty)
        None => None
      }
    AddressOf(ty, _) => Some(ty)
    GlobalVariable(handle) =>
      match self.shader_module.global_variables.items.get(handle.index()) {
        Some(global) => Some(global.ty)
        None => None
      }
    Constant(handle) =>
      match self.shader_module.constants.items.get(handle.index()) {
        Some(constant) => Some(constant.ty)
        None => None
      }
    Override(handle) =>
      match self.shader_module.overrides.items.get(handle.index()) {
        Some(override_) => Some(override_.ty)
        None => None
      }
    Load(inner) =>
      match self.expression_type(Some(function), inner) {
        Some(ty) => Some(self.deref_pointer_type_handle(ty))
        None => None
      }
    Compose(ty, _) | ZeroValue(ty) => Some(ty)
    AccessIndex(base, index) =>
      self.indexed_expression_type(Some(function), base, Some(index))
    Access(base, _) => self.indexed_expression_type(Some(function), base, None)
    Swizzle(size, base, _) =>
      self.swizzle_expression_type(Some(function), base, size)
    Unary(_, inner) => self.expression_type(Some(function), inner)
    Binary(op, left, right) =>
      match self.expression_type(Some(function), left) {
        Some(left_ty) =>
          match self.expression_type(Some(function), right) {
            Some(right_ty) =>
              self.binary_expression_result_type(op, left_ty, right_ty)
            None => Some(left_ty)
          }
        None => self.expression_type(Some(function), right)
      }
    Select(_, accept, reject) =>
      match self.expression_type(Some(function), accept) {
        Some(ty) => Some(ty)
        None => self.expression_type(Some(function), reject)
      }
    Bitcast(ty, _) => Some(ty)
    FunctionCall(handle, _) =>
      match self.shader_module.functions.items.get(handle.index()) {
        Some(callee) =>
          match callee.result {
            Some(result) => Some(result.ty)
            None => None
          }
        None => None
      }
    Math(math_function, a, _, _, _) =>
      self.math_expression_result_type(Some(function), math_function, a)
    Relational(relational_function, expr) =>
      self.relational_expression_result_type(
        Some(function),
        relational_function,
        expr,
      )
    AtomicCall(atomic_function, arguments) =>
      self.atomic_expression_result_type(
        Some(function),
        atomic_function,
        arguments,
      )
    ImageSample(image, _, gather, _, _, _, _, depth_ref, _) =>
      self.image_expression_result_type(
        Some(function),
        image,
        gather,
        depth_ref,
      )
    ImageLoad(image, _, _, _, _) =>
      self.image_expression_result_type(Some(function), image, None, None)
    ImageQuery(image, query) =>
      self.image_query_expression_result_type(Some(function), image, query)
    RayQueryGetIntersection(_, _) => self.type_handle_named("RayIntersection")
    RayQueryProceedResult => self.type_handle_named("bool")
    WorkGroupUniformLoad(pointer) =>
      match self.expression_type(Some(function), pointer) {
        Some(ty) => Some(self.deref_pointer_type_handle(ty))
        None => None
      }
    CooperativeLoad(columns, rows, role, data) =>
      match self.cooperative_data_scalar(Some(function), data) {
        Some(scalar) =>
          self.cooperative_matrix_type_handle(columns, rows, scalar, role)
        None => None
      }
    CooperativeMultiplyAdd(_, _, c) => self.expression_type(Some(function), c)
    SubgroupCall(subgroup_function, arguments) =>
      self.subgroup_expression_result_type(
        Some(function),
        subgroup_function,
        arguments,
      )
    Literal(literal) => self.literal_type(literal)
    _ => None
  }
}

///|
fn WgslIrEmitter::cooperative_matrix_type_handle(
  self : WgslIrEmitter,
  columns : CooperativeSize,
  rows : CooperativeSize,
  scalar : Scalar,
  role : CooperativeRole,
) -> Handle? {
  for index in 0..<self.shader_module.types.items.length() {
    match self.shader_module.types.items[index].inner {
      CooperativeMatrix(
        existing_columns,
        existing_rows,
        existing_scalar,
        existing_role
      ) =>
        if existing_columns == columns &&
          existing_rows == rows &&
          existing_scalar == scalar &&
          existing_role == role {
          return Some(Handle::Handle(index))
        }
      _ => ()
    }
  }
  None
}

///|
fn WgslIrEmitter::type_handle_named(
  self : WgslIrEmitter,
  name : String,
) -> Handle? {
  for index in 0..<self.shader_module.types.items.length() {
    match self.shader_module.types.items[index].name {
      Some(existing) if existing == name => return Some(Handle::Handle(index))
      _ => ()
    }
  }
  None
}

///|
fn WgslIrEmitter::global_expression_inner_type(
  self : WgslIrEmitter,
  expression : Expression,
) -> Handle? {
  match expression {
    Constant(handle) =>
      match self.shader_module.constants.items.get(handle.index()) {
        Some(constant) => Some(constant.ty)
        None => None
      }
    Override(handle) =>
      match self.shader_module.overrides.items.get(handle.index()) {
        Some(override_) => Some(override_.ty)
        None => None
      }
    GlobalVariable(handle) =>
      match self.shader_module.global_variables.items.get(handle.index()) {
        Some(global) => Some(global.ty)
        None => None
      }
    Load(inner) =>
      match self.expression_type(None, inner) {
        Some(ty) => Some(self.deref_pointer_type_handle(ty))
        None => None
      }
    Compose(ty, _) | ZeroValue(ty) => Some(ty)
    AccessIndex(base, index) =>
      self.indexed_expression_type(None, base, Some(index))
    Access(base, _) => self.indexed_expression_type(None, base, None)
    Swizzle(size, base, _) => self.swizzle_expression_type(None, base, size)
    Unary(_, inner) => self.expression_type(None, inner)
    Binary(op, left, right) =>
      match self.expression_type(None, left) {
        Some(left_ty) =>
          match self.expression_type(None, right) {
            Some(right_ty) =>
              self.binary_expression_result_type(op, left_ty, right_ty)
            None => Some(left_ty)
          }
        None => self.expression_type(None, right)
      }
    Select(_, accept, reject) =>
      match self.expression_type(None, accept) {
        Some(ty) => Some(ty)
        None => self.expression_type(None, reject)
      }
    Bitcast(ty, _) => Some(ty)
    Derivative(_, _, expr) => self.expression_type(None, expr)
    Math(math_function, a, _, _, _) =>
      self.math_expression_result_type(None, math_function, a)
    Relational(relational_function, expr) =>
      self.relational_expression_result_type(None, relational_function, expr)
    AtomicCall(atomic_function, arguments) =>
      self.atomic_expression_result_type(None, atomic_function, arguments)
    ImageQuery(image, query) =>
      self.image_query_expression_result_type(None, image, query)
    ArrayLength(_) => self.type_handle_named("u32")
    SubgroupCall(subgroup_function, arguments) =>
      self.subgroup_expression_result_type(None, subgroup_function, arguments)
    Literal(literal) => self.literal_type(literal)
    _ => None
  }
}

///|
fn WgslIrEmitter::literal_type(
  self : WgslIrEmitter,
  literal : Literal,
) -> Handle? {
  match literal {
    Bool(_) => self.type_handle_named("bool")
    I32(_) => self.type_handle_named("i32")
    AbstractInt(_) => self.type_handle_named("__abstract_int")
    U32(_) => self.type_handle_named("u32")
    F16(_) => self.type_handle_named("f16")
    F32(_) => self.type_handle_named("f32")
    F64(_) => self.type_handle_named("f64")
    AbstractFloat(_) => self.type_handle_named("__abstract_float")
    _ => None
  }
}

///|
fn WgslIrEmitter::subgroup_expression_result_type(
  self : WgslIrEmitter,
  function : Function?,
  subgroup_function : SubgroupFunction,
  arguments : Array[Handle],
) -> Handle? {
  match subgroup_function {
    Ballot => self.find_vector_type(Quad, Scalar::Scalar(Uint, 4))
    All | Any => self.type_handle_named("bool")
    _ =>
      match arguments.get(0) {
        Some(first) => self.expression_type(function, first)
        None => None
      }
  }
}

///|
fn wgsl_ir_emit_subgroup_function_name(function : SubgroupFunction) -> String {
  match function {
    Ballot => "subgroupBallot"
    All => "subgroupAll"
    Any => "subgroupAny"
    Add => "subgroupAdd"
    Mul => "subgroupMul"
    Max => "subgroupMax"
    Min => "subgroupMin"
    And => "subgroupAnd"
    Or => "subgroupOr"
    Xor => "subgroupXor"
    ExclusiveAdd => "subgroupExclusiveAdd"
    ExclusiveMul => "subgroupExclusiveMul"
    InclusiveAdd => "subgroupInclusiveAdd"
    InclusiveMul => "subgroupInclusiveMul"
    BroadcastFirst => "subgroupBroadcastFirst"
    Broadcast => "subgroupBroadcast"
    Shuffle => "subgroupShuffle"
    ShuffleDown => "subgroupShuffleDown"
    ShuffleUp => "subgroupShuffleUp"
    ShuffleXor => "subgroupShuffleXor"
    QuadBroadcast => "quadBroadcast"
    QuadSwapX => "quadSwapX"
    QuadSwapY => "quadSwapY"
    QuadSwapDiagonal => "quadSwapDiagonal"
  }
}

///|
fn WgslIrEmitter::image_expression_result_type(
  self : WgslIrEmitter,
  function : Function?,
  image : Handle,
  gather : SwizzleComponent?,
  depth_ref : Handle?,
) -> Handle? {
  guard self.expression_type(function, image) is Some(image_ty) else {
    return None
  }
  match self.shader_module.types.items.get(image_ty.index()) {
    Some(ty) =>
      match ty.inner {
        Image(_, _, Sampled(kind, _)) =>
          self.find_vector_type(Quad, Scalar::Scalar(kind, 4))
        Image(_, _, Depth(_)) =>
          if gather != None {
            self.find_vector_type(Quad, Scalar::Scalar(Float, 4))
          } else if depth_ref != None {
            self.type_handle_named("f32")
          } else {
            self.type_handle_named("f32")
          }
        Image(_, _, Storage(format, _)) =>
          self.find_vector_type(
            Quad,
            wgsl_ir_emit_storage_format_scalar(format),
          )
        Image(_, _, External) =>
          self.find_vector_type(Quad, Scalar::Scalar(Float, 4))
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrEmitter::image_query_expression_result_type(
  self : WgslIrEmitter,
  function : Function?,
  image : Handle,
  query : ImageQuery,
) -> Handle? {
  match query {
    Size(_) =>
      match self.expression_type(function, image) {
        Some(image_ty) =>
          match self.shader_module.types.items.get(image_ty.index()) {
            Some(ty) =>
              match ty.inner {
                Image(dimension, _, _) =>
                  self.image_dimension_size_type_handle(dimension)
                _ => None
              }
            None => None
          }
        None => None
      }
    NumLevels | NumLayers | NumSamples => self.type_handle_named("u32")
  }
}

///|
fn WgslIrEmitter::image_dimension_size_type_handle(
  self : WgslIrEmitter,
  dimension : ImageDimension,
) -> Handle? {
  match dimension {
    D1 => self.type_handle_named("u32")
    D2 | Cube => self.type_handle_named("vec2<u32>")
    D3 => self.type_handle_named("vec3<u32>")
  }
}

///|
fn WgslIrEmitter::indexed_expression_type(
  self : WgslIrEmitter,
  function : Function?,
  base : Handle,
  index : Int?,
) -> Handle? {
  guard self.expression_type(function, base) is Some(base_ty) else {
    return None
  }
  self.indexed_type_from_type_handle(base_ty, index)
}

///|
fn WgslIrEmitter::indexed_type_from_type_handle(
  self : WgslIrEmitter,
  ty_handle : Handle,
  index : Int?,
) -> Handle? {
  match self.shader_module.types.items.get(ty_handle.index()) {
    Some(ty) =>
      match ty.inner {
        Struct(members, _) | PredeclaredStruct(members, _) =>
          match index {
            Some(i) =>
              match members.get(i) {
                Some(struct_member) => Some(struct_member.ty)
                None => None
              }
            None => None
          }
        Vector(_, scalar) => self.find_vector_scalar_type(scalar)
        Matrix(_, rows, scalar) => self.find_vector_type(rows, scalar)
        Array(element, _, _) | BindingArray(element, _) => Some(element)
        Pointer(inner, _) => self.indexed_type_from_type_handle(inner, index)
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrEmitter::swizzle_expression_type(
  self : WgslIrEmitter,
  function : Function?,
  base : Handle,
  size : VectorSize,
) -> Handle? {
  guard self.expression_type(function, base) is Some(base_ty) else {
    return None
  }
  match self.shader_module.types.get(base_ty) {
    Some(ty) =>
      match ty.inner {
        Vector(_, scalar) => self.find_vector_type(size, scalar)
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrEmitter::find_vector_scalar_type(
  self : WgslIrEmitter,
  scalar : Scalar,
) -> Handle? {
  let scalar_inner = TypeInner::Scalar(scalar)
  for i in 0..<self.shader_module.types.items.length() {
    if self.shader_module.types.items[i].inner == scalar_inner {
      return Some(Handle::Handle(i))
    }
  }
  None
}

///|
fn WgslIrEmitter::find_vector_type(
  self : WgslIrEmitter,
  size : VectorSize,
  scalar : Scalar,
) -> Handle? {
  let vector_inner = TypeInner::Vector(size, scalar)
  for i in 0..<self.shader_module.types.items.length() {
    if self.shader_module.types.items[i].inner == vector_inner {
      return Some(Handle::Handle(i))
    }
  }
  None
}

///|
fn WgslIrEmitter::math_expression_result_type(
  self : WgslIrEmitter,
  function : Function?,
  math_function : MathFunction,
  argument : Handle,
) -> Handle? {
  guard self.expression_type(function, argument) is Some(input_ty) else {
    return None
  }
  match math_function {
    Modf | Frexp =>
      self.predeclared_numeric_result_type(input_ty, math_function)
    Pack4x8snorm
    | Pack4x8unorm
    | Pack2x16snorm
    | Pack2x16unorm
    | Pack2x16float
    | Pack4xI8
    | Pack4xU8
    | Pack4xI8Clamp
    | Pack4xU8Clamp
    | Dot4U8Packed => self.type_handle_named("u32")
    Dot4I8Packed => self.type_handle_named("i32")
    Unpack4x8snorm | Unpack4x8unorm =>
      self.find_vector_type(Quad, Scalar::Scalar(Float, 4))
    Unpack2x16snorm | Unpack2x16unorm | Unpack2x16float =>
      self.find_vector_type(Bi, Scalar::Scalar(Float, 4))
    Unpack4xI8 => self.find_vector_type(Quad, Scalar::Scalar(Sint, 4))
    Unpack4xU8 => self.find_vector_type(Quad, Scalar::Scalar(Uint, 4))
    Dot | Distance | Length | Determinant =>
      self.scalar_type_from_composite_type(input_ty)
    Transpose => self.transpose_expression_result_type(input_ty)
    _ => Some(input_ty)
  }
}

///|
fn WgslIrEmitter::transpose_expression_result_type(
  self : WgslIrEmitter,
  input_ty : Handle,
) -> Handle? {
  match self.shader_module.types.get(input_ty) {
    Some(type_) =>
      match type_.inner {
        Matrix(columns, rows, scalar) =>
          self.find_matrix_type(rows, columns, scalar)
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrEmitter::scalar_type_from_composite_type(
  self : WgslIrEmitter,
  ty_handle : Handle,
) -> Handle? {
  match self.shader_module.types.get(ty_handle) {
    Some(ty) =>
      match ty.inner {
        Vector(_, scalar) | Matrix(_, _, scalar) =>
          self.find_scalar_type(scalar)
        _ => Some(ty_handle)
      }
    None => None
  }
}

///|
fn WgslIrEmitter::relational_expression_result_type(
  self : WgslIrEmitter,
  function : Function?,
  relational_function : RelationalFunction,
  argument : Handle,
) -> Handle? {
  match relational_function {
    All | Any => self.find_scalar_type(Scalar::Scalar(Bool, 1))
    IsNan | IsInf =>
      match self.expression_type(function, argument) {
        Some(input_ty) => self.boolean_result_type(input_ty, input_ty)
        None => None
      }
  }
}

///|
fn WgslIrEmitter::binary_expression_result_type(
  self : WgslIrEmitter,
  op : BinaryOperator,
  left_ty : Handle,
  right_ty : Handle,
) -> Handle? {
  if wgsl_ir_binary_operator_is_comparison(op) {
    return self.boolean_result_type(left_ty, right_ty)
  }
  if op == BinaryOperator::Multiply {
    match self.matrix_vector_multiply_result_type(left_ty, right_ty) {
      Some(ty) => return Some(ty)
      None => ()
    }
  }
  if self.type_is_scalar(left_ty) && !self.type_is_scalar(right_ty) {
    return Some(right_ty)
  }
  if !self.type_is_scalar(left_ty) && self.type_is_scalar(right_ty) {
    return Some(left_ty)
  }
  Some(left_ty)
}

///|
fn WgslIrEmitter::matrix_vector_multiply_result_type(
  self : WgslIrEmitter,
  left_ty : Handle,
  right_ty : Handle,
) -> Handle? {
  match self.shader_module.types.get(left_ty) {
    Some(left) =>
      match left.inner {
        Matrix(left_columns, rows, scalar) =>
          match self.shader_module.types.get(right_ty) {
            Some(right) =>
              match right.inner {
                Vector(_, _) => self.find_vector_type(rows, scalar)
                Matrix(columns, right_rows, _) =>
                  if right_rows == left_columns {
                    self.find_matrix_type(columns, rows, scalar)
                  } else {
                    None
                  }
                _ => None
              }
            None => None
          }
        Vector(_, scalar) =>
          match self.shader_module.types.get(right_ty) {
            Some(right) =>
              match right.inner {
                Matrix(columns, _, _) => self.find_vector_type(columns, scalar)
                _ => None
              }
            None => None
          }
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrEmitter::find_matrix_type(
  self : WgslIrEmitter,
  columns : VectorSize,
  rows : VectorSize,
  scalar : Scalar,
) -> Handle? {
  let matrix_inner = TypeInner::Matrix(columns, rows, scalar)
  for i in 0..<self.shader_module.types.items.length() {
    if self.shader_module.types.items[i].inner == matrix_inner {
      return Some(Handle::Handle(i))
    }
  }
  None
}

///|
fn WgslIrEmitter::boolean_result_type(
  self : WgslIrEmitter,
  left_ty : Handle,
  right_ty : Handle,
) -> Handle? {
  match self.vector_size_from_type(left_ty) {
    Some(size) => self.find_vector_type(size, Scalar::Scalar(Bool, 1))
    None =>
      match self.vector_size_from_type(right_ty) {
        Some(size) => self.find_vector_type(size, Scalar::Scalar(Bool, 1))
        None => self.find_scalar_type(Scalar::Scalar(Bool, 1))
      }
  }
}

///|
fn WgslIrEmitter::type_is_scalar(
  self : WgslIrEmitter,
  ty_handle : Handle,
) -> Bool {
  match self.shader_module.types.get(ty_handle) {
    Some(ty) =>
      match ty.inner {
        Scalar(_) => true
        _ => false
      }
    None => false
  }
}

///|
fn WgslIrEmitter::vector_size_from_type(
  self : WgslIrEmitter,
  ty_handle : Handle,
) -> VectorSize? {
  match self.shader_module.types.get(ty_handle) {
    Some(ty) =>
      match ty.inner {
        Vector(size, _) => Some(size)
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrEmitter::find_scalar_type(
  self : WgslIrEmitter,
  scalar : Scalar,
) -> Handle? {
  let scalar_inner = TypeInner::Scalar(scalar)
  for i in 0..<self.shader_module.types.items.length() {
    if self.shader_module.types.items[i].inner == scalar_inner {
      return Some(Handle::Handle(i))
    }
  }
  None
}

///|
fn WgslIrEmitter::predeclared_numeric_result_type(
  self : WgslIrEmitter,
  input_ty : Handle,
  math_function : MathFunction,
) -> Handle? {
  let key = match self.shader_module.types.items.get(input_ty.index()) {
    Some(ty) =>
      match ty.inner {
        Scalar(scalar) =>
          if math_function == Modf {
            Some(PredeclaredType::ModfResult(None, scalar))
          } else {
            Some(PredeclaredType::FrexpResult(None, scalar))
          }
        Vector(size, scalar) =>
          if math_function == Modf {
            Some(PredeclaredType::ModfResult(Some(size), scalar))
          } else {
            Some(PredeclaredType::FrexpResult(Some(size), scalar))
          }
        _ => None
      }
    None => None
  }
  match key {
    Some(predeclared) => self.predeclared_type_handle(predeclared)
    None => None
  }
}

///|
fn WgslIrEmitter::atomic_expression_result_type(
  self : WgslIrEmitter,
  function : Function?,
  atomic_function : AtomicFunction,
  arguments : Array[Handle],
) -> Handle? {
  guard arguments is [pointer, ..] else { return None }
  let scalar = self.atomic_pointer_scalar_type(function, pointer)
  match atomic_function {
    Store => None
    CompareExchangeWeak =>
      match scalar {
        Some(value) =>
          self.predeclared_type_handle(AtomicCompareExchangeWeakResult(value))
        None => None
      }
    _ =>
      match scalar {
        Some(value) => self.find_vector_scalar_type(value)
        None => None
      }
  }
}

///|
fn WgslIrEmitter::atomic_pointer_scalar_type(
  self : WgslIrEmitter,
  function : Function?,
  pointer : Handle,
) -> Scalar? {
  guard self.expression_type(function, pointer) is Some(ty_handle) else {
    return None
  }
  self.atomic_scalar_type_from_handle(ty_handle)
}

///|
fn WgslIrEmitter::atomic_scalar_type_from_handle(
  self : WgslIrEmitter,
  ty_handle : Handle,
) -> Scalar? {
  match self.shader_module.types.items.get(ty_handle.index()) {
    Some(ty) =>
      match ty.inner {
        Atomic(scalar) => Some(scalar)
        Pointer(base, _) => self.atomic_scalar_type_from_handle(base)
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrEmitter::predeclared_type_handle(
  self : WgslIrEmitter,
  predeclared : PredeclaredType,
) -> Handle? {
  for item in self.shader_module.special_types.predeclared_types {
    let (existing, handle) = item
    if existing == predeclared {
      return Some(handle)
    }
  }
  None
}

///|
fn WgslIrEmitter::required_function_expression(
  self : WgslIrEmitter,
  function : Function?,
  handle : Handle,
) -> String raise WgslIrEmitError {
  match function {
    Some(value) => self.function_expression(value, handle)
    None => self.global_expression(handle)
  }
}

///|
fn WgslIrEmitter::expression_list(
  self : WgslIrEmitter,
  handles : Array[Handle],
  function : Function?,
) -> String raise WgslIrEmitError {
  let out = StringBuilder::new()
  for index in 0..<handles.length() {
    if index > 0 {
      out.write_string(", ")
    }
    match function {
      Some(func) =>
        out.write_string(self.function_expression(func, handles[index]))
      None => out.write_string(self.global_expression(handles[index]))
    }
  }
  out.to_string()
}

///|
fn WgslIrEmitter::math_argument_list(
  self : WgslIrEmitter,
  a : Handle,
  b : Handle?,
  c : Handle?,
  d : Handle?,
  function : Function?,
) -> String raise WgslIrEmitError {
  let handles : Array[Handle] = [a]
  match b {
    Some(value) => handles.push(value)
    None => ()
  }
  match c {
    Some(value) => handles.push(value)
    None => ()
  }
  match d {
    Some(value) => handles.push(value)
    None => ()
  }
  self.expression_list(handles, function)
}

///|
fn WgslIrEmitter::type_name(
  self : WgslIrEmitter,
  handle : Handle,
) -> String raise WgslIrEmitError {
  let ty = match self.shader_module.types.items.get(handle.index()) {
    Some(value) => value
    None => raise WgslIrEmitError::MissingHandle("type \{handle.index()}")
  }
  match ty.name {
    Some(name) =>
      match ty.inner {
        Scalar(_) => name
        Struct(_, _) | PredeclaredStruct(_, _) =>
          sanitize_wgsl_ir_identifier(name)
        _ => self.type_inner_name(ty.inner)
      }
    None =>
      match self.predeclared_result_type_name(handle) {
        Some(name) => sanitize_wgsl_ir_identifier(name)
        None => self.type_inner_name(ty.inner)
      }
  }
}

///|
fn WgslIrEmitter::predeclared_result_type_name(
  self : WgslIrEmitter,
  handle : Handle,
) -> String? {
  for item in self.shader_module.special_types.predeclared_types {
    let (predeclared, existing) = item
    if existing == handle {
      return Some(wgsl_ir_predeclared_result_type_name(predeclared))
    }
  }
  None
}

///|
fn wgsl_ir_predeclared_result_type_name(
  predeclared : PredeclaredType,
) -> String {
  match predeclared {
    AtomicCompareExchangeWeakResult(scalar) =>
      "_atomic_compare_exchange_result_\{wgsl_ir_predeclared_scalar_name(scalar)}_"
    ModfResult(size, scalar) =>
      "_modf_result_\{wgsl_ir_predeclared_numeric_name(size, scalar)}_"
    FrexpResult(size, scalar) =>
      "_frexp_result_\{wgsl_ir_predeclared_numeric_name(size, scalar)}_"
  }
}

///|
fn wgsl_ir_predeclared_numeric_name(
  size : VectorSize?,
  scalar : Scalar,
) -> String {
  match size {
    Some(vector_size) =>
      "Vec\{vector_size.width()}_\{wgsl_ir_predeclared_scalar_name(scalar)}"
    None => wgsl_ir_predeclared_scalar_name(scalar)
  }
}

///|
fn wgsl_ir_predeclared_scalar_name(scalar : Scalar) -> String {
  let kind = match scalar.kind {
    Sint => "Sint"
    Uint => "Uint"
    Float => "Float"
    Bool => "Bool"
    AbstractInt => "AbstractInt"
    AbstractFloat => "AbstractFloat"
  }
  "\{kind}_\{scalar.width}"
}

///|
fn WgslIrEmitter::compose_constructor_name(
  self : WgslIrEmitter,
  handle : Handle,
) -> String raise WgslIrEmitError {
  let ty = match self.shader_module.types.items.get(handle.index()) {
    Some(value) => value
    None => raise WgslIrEmitError::MissingHandle("type \{handle.index()}")
  }
  if !self.type_inner_contains_abstract_scalar(ty.inner) {
    return self.type_name(handle)
  }
  match ty.inner {
    Scalar(_) => self.type_name(handle)
    Vector(size, _) => "vec\{size.width()}"
    Matrix(columns, rows, _) => "mat\{columns.width()}x\{rows.width()}"
    Array(_, _, _) => "array"
    _ => self.type_name(handle)
  }
}

///|
fn WgslIrEmitter::compose_constructor_name_for_components(
  self : WgslIrEmitter,
  handle : Handle,
  components : Array[Handle],
  function : Function?,
) -> String raise WgslIrEmitError {
  if components.length() == 1 {
    match self.shader_module.types.items.get(handle.index()) {
      Some(type_) =>
        match type_.inner {
          Vector(size, scalar) =>
            if self.expression_is_scalar_type(function, components[0], scalar) {
              return "vec\{size.width()}"
            }
          _ => ()
        }
      None => raise WgslIrEmitError::MissingHandle("type \{handle.index()}")
    }
  }
  self.compose_constructor_name(handle)
}

///|
fn WgslIrEmitter::expression_is_scalar_type(
  self : WgslIrEmitter,
  function : Function?,
  handle : Handle,
  scalar : Scalar,
) -> Bool {
  match self.expression_type(function, handle) {
    Some(ty_handle) =>
      match self.shader_module.types.items.get(ty_handle.index()) {
        Some(type_) =>
          match type_.inner {
            Scalar(value) =>
              self.scalar_matches_constructor_component(value, scalar)
            _ => false
          }
        None => false
      }
    None => false
  }
}

///|
fn WgslIrEmitter::scalar_matches_constructor_component(
  self : WgslIrEmitter,
  value : Scalar,
  target : Scalar,
) -> Bool {
  ignore(self)
  if value.kind == target.kind && value.width == target.width {
    return true
  }
  match (value.kind, target.kind) {
    (AbstractFloat, Float) => true
    (AbstractInt, Sint) | (AbstractInt, Uint) => true
    _ => false
  }
}

///|
fn WgslIrEmitter::type_inner_name(
  self : WgslIrEmitter,
  inner : TypeInner,
) -> String raise WgslIrEmitError {
  match inner {
    Scalar(scalar) => self.scalar_name(scalar)
    Vector(size, scalar) => "vec\{size.width()}<\{self.scalar_name(scalar)}>"
    Matrix(columns, rows, scalar) =>
      "mat\{columns.width()}x\{rows.width()}<\{self.scalar_name(scalar)}>"
    CooperativeMatrix(columns, rows, scalar, role) =>
      "coop_mat\{wgsl_ir_cooperative_size_name(columns)}x\{wgsl_ir_cooperative_size_name(rows)}<\{self.scalar_name(scalar)}, \{wgsl_ir_cooperative_role_name(role)}>"
    Atomic(scalar) => "atomic<\{self.scalar_name(scalar)}>"
    Pointer(base, space) =>
      match space {
        Storage(access) =>
          "ptr<storage, \{self.type_name(base)}, \{self.storage_access_name(access)}>"
        _ => "ptr<\{self.address_space_name(space)}, \{self.type_name(base)}>"
      }
    Array(base, size, _) =>
      match size {
        Constant(value) => "array<\{self.type_name(base)}, \{value}>"
        Dynamic => "array<\{self.type_name(base)}>"
        Pending(handle) =>
          "array<\{self.type_name(base)}, \{self.global_expression(handle)}>"
      }
    Struct(_, _) => raise WgslIrEmitError::Unsupported("anonymous struct type")
    PredeclaredStruct(_, _) =>
      raise WgslIrEmitError::Unsupported("anonymous predeclared struct type")
    Image(dimension, arrayed, image_class) =>
      self.image_type_name(dimension, arrayed, image_class)
    Sampler(comparison) =>
      if comparison {
        "sampler_comparison"
      } else {
        "sampler"
      }
    AccelerationStructure(_) => "acceleration_structure"
    RayQuery(_) => "ray_query"
    BindingArray(base, size) =>
      match size {
        Constant(value) => "binding_array<\{self.type_name(base)}, \{value}>"
        Dynamic => "binding_array<\{self.type_name(base)}>"
        Pending(handle) =>
          "binding_array<\{self.type_name(base)}, \{self.global_expression(handle)}>"
      }
    _ => raise WgslIrEmitError::Unsupported("type kind")
  }
}

///|
fn WgslIrEmitter::image_type_name(
  self : WgslIrEmitter,
  dimension : ImageDimension,
  arrayed : Bool,
  image_class : ImageClass,
) -> String {
  match image_class {
    Sampled(kind, multisampled) => {
      let prefix = if multisampled { "texture_multisampled" } else { "texture" }
      "\{prefix}_\{self.image_dimension_suffix(dimension, arrayed)}<\{self.scalar_kind_name(kind)}>"
    }
    Depth(multisampled) => {
      let prefix = if multisampled {
        "texture_depth_multisampled"
      } else {
        "texture_depth"
      }
      "\{prefix}_\{self.image_dimension_suffix(dimension, arrayed)}"
    }
    External => "texture_external"
    Storage(format, access) =>
      "texture_storage_\{self.image_dimension_suffix(dimension, arrayed)}<\{self.storage_format_name(format)}, \{self.storage_access_name(access)}>"
  }
}

///|
fn WgslIrEmitter::image_dimension_suffix(
  self : WgslIrEmitter,
  dimension : ImageDimension,
  arrayed : Bool,
) -> String {
  ignore(self)
  let base = match dimension {
    D1 => "1d"
    D2 => "2d"
    D3 => "3d"
    Cube => "cube"
  }
  if arrayed {
    "\{base}_array"
  } else {
    base
  }
}

///|
fn WgslIrEmitter::scalar_name(self : WgslIrEmitter, scalar : Scalar) -> String {
  ignore(self)
  match scalar.kind {
    Bool => "bool"
    Sint => if scalar.width == 8 { "i64" } else { "i32" }
    Uint => if scalar.width == 8 { "u64" } else { "u32" }
    Float =>
      if scalar.width == 2 {
        "f16"
      } else if scalar.width == 8 {
        "f64"
      } else {
        "f32"
      }
    AbstractInt => "abstract-int"
    AbstractFloat => "abstract-float"
  }
}

///|
fn WgslIrEmitter::scalar_kind_name(
  self : WgslIrEmitter,
  kind : ScalarKind,
) -> String {
  ignore(self)
  match kind {
    Sint => "i32"
    Uint => "u32"
    Float => "f32"
    Bool => "bool"
    AbstractInt => "i32"
    AbstractFloat => "f32"
  }
}

///|
fn WgslIrEmitter::address_space_template(
  self : WgslIrEmitter,
  space : AddressSpace,
) -> String {
  match space {
    Private => "<private>"
    WorkGroup => "<workgroup>"
    Uniform => "<uniform>"
    Storage(access) => "<storage, \{self.storage_access_name(access)}>"
    Handle => ""
    Function => "<function>"
    Immediate => "<immediate>"
    TaskPayload => "<task_payload>"
    RayPayload => "<ray_payload>"
    IncomingRayPayload => "<incoming_ray_payload>"
  }
}

///|
fn WgslIrEmitter::address_space_name(
  self : WgslIrEmitter,
  space : AddressSpace,
) -> String {
  ignore(self)
  match space {
    Function => "function"
    Private => "private"
    WorkGroup => "workgroup"
    Uniform => "uniform"
    Storage(_) => "storage"
    Handle => "handle"
    Immediate => "immediate"
    TaskPayload => "task_payload"
    RayPayload => "ray_payload"
    IncomingRayPayload => "incoming_ray_payload"
  }
}

///|
fn WgslIrEmitter::storage_access_name(
  self : WgslIrEmitter,
  access : StorageAccess,
) -> String {
  ignore(self)
  if access.contains(StorageAccess::atomic_access()) {
    "atomic"
  } else if access.contains(StorageAccess::load()) &&
    access.contains(StorageAccess::store()) {
    "read_write"
  } else if access.contains(StorageAccess::store()) {
    "write"
  } else {
    "read"
  }
}

///|
fn WgslIrEmitter::stage_attribute(
  self : WgslIrEmitter,
  stage : ShaderStage,
) -> String raise WgslIrEmitError {
  ignore(self)
  match stage {
    Vertex => "@vertex"
    Fragment => "@fragment"
    Compute => "@compute"
    _ => raise WgslIrEmitError::Unsupported("shader stage")
  }
}

///|
fn WgslIrEmitter::emit_binding_attribute_prefix(
  self : WgslIrEmitter,
  out : StringBuilder,
  binding : Binding?,
) -> Unit raise WgslIrEmitError {
  match binding {
    Some(BuiltIn(builtin)) =>
      out.write_string("@builtin(\{self.builtin_name(builtin)}) ")
    Some(Location(location, interpolation, sampling, blend_src, _)) => {
      out.write_string("@location(\{location}) ")
      match blend_src {
        Some(value) => out.write_string("@blend_src(\{value}) ")
        None => ()
      }
      match interpolation {
        Some(value) => {
          out.write_string("@interpolate(\{self.interpolation_name(value)}")
          match sampling {
            Some(sampling_value) =>
              out.write_string(", \{self.sampling_name(sampling_value)}")
            None => ()
          }
          out.write_string(") ")
        }
        None => ()
      }
    }
    None => ()
  }
}

///|
fn WgslIrEmitter::builtin_name(
  self : WgslIrEmitter,
  builtin : BuiltIn,
) -> String raise WgslIrEmitError {
  ignore(self)
  match builtin {
    Position(_) => "position"
    ViewIndex => "view_index"
    ClipDistances => "clip_distances"
    PrimitiveIndex => "primitive_index"
    VertexIndex => "vertex_index"
    InstanceIndex => "instance_index"
    FrontFacing => "front_facing"
    Barycentric(true) => "barycentric"
    Barycentric(false) => "barycentric_no_perspective"
    FragDepth => "frag_depth"
    SampleIndex => "sample_index"
    SampleMask => "sample_mask"
    GlobalInvocationId => "global_invocation_id"
    LocalInvocationId => "local_invocation_id"
    LocalInvocationIndex => "local_invocation_index"
    WorkGroupId => "workgroup_id"
    NumWorkGroups => "num_workgroups"
    NumSubgroups => "num_subgroups"
    SubgroupId => "subgroup_id"
    SubgroupSize => "subgroup_size"
    SubgroupInvocationId => "subgroup_invocation_id"
    _ => raise WgslIrEmitError::Unsupported("builtin")
  }
}

///|
fn WgslIrEmitter::interpolation_name(
  self : WgslIrEmitter,
  interpolation : Interpolation,
) -> String {
  ignore(self)
  match interpolation {
    Perspective => "perspective"
    Linear => "linear"
    Flat => "flat"
    PerVertex => "per_vertex"
  }
}

///|
fn WgslIrEmitter::sampling_name(
  self : WgslIrEmitter,
  sampling : Sampling,
) -> String {
  ignore(self)
  match sampling {
    Center => "center"
    Centroid => "centroid"
    Sample => "sample"
    First => "first"
    Either => "either"
  }
}

///|
fn WgslIrEmitter::literal(self : WgslIrEmitter, literal : Literal) -> String {
  match literal {
    F64(value) => wgsl_ir_emit_abstract_float_literal_text("\{value}")
    F32(value) => wgsl_ir_emit_concrete_float_literal_text("\{value}")
    F16(value) => wgsl_ir_emit_f16_literal_text("\{value}")
    U16(value) => "\{value}u"
    I16(value) => "\{value}"
    U32(value) => "\{value}u"
    I32(value) => "\{value}i"
    U64(value) => "\{value}u"
    I64(value) => "\{value}"
    Bool(value) => if value { "true" } else { "false" }
    AbstractInt(value) => "\{value}"
    AbstractFloat(value) =>
      if self.preserve_abstract_float_literals {
        wgsl_ir_emit_abstract_float_literal_text("\{value}")
      } else {
        wgsl_ir_emit_concrete_float_literal_text("\{value}")
      }
  }
}

///|
fn wgsl_ir_emit_normalized_float_literal_text(text : String) -> String {
  if text.contains(".") || text.contains("e") || text.contains("E") {
    text
  } else {
    "\{text}.0"
  }
}

///|
fn wgsl_ir_emit_concrete_float_literal_text(text : String) -> String {
  let normalized = wgsl_ir_emit_normalized_float_literal_text(text)
  if normalized.has_suffix(".0") {
    "\{normalized[0:normalized.length() - 2]}f"
  } else {
    "\{normalized}f"
  }
}

///|
fn wgsl_ir_emit_f16_literal_text(text : String) -> String {
  let normalized = wgsl_ir_emit_normalized_float_literal_text(text)
  if normalized.has_suffix(".0") {
    "\{normalized[0:normalized.length() - 2]}h"
  } else {
    "\{normalized}h"
  }
}

///|
fn wgsl_ir_emit_abstract_float_literal_text(text : String) -> String {
  wgsl_ir_emit_normalized_float_literal_text(text)
}

///|
fn WgslIrEmitter::constant_name(
  self : WgslIrEmitter,
  handle : Handle,
) -> String raise WgslIrEmitError {
  match self.shader_module.constants.items.get(handle.index()) {
    Some(constant) =>
      match constant.name {
        Some(name) => sanitize_wgsl_ir_identifier(name)
        None => raise WgslIrEmitError::MissingName("constant \{handle.index()}")
      }
    None => raise WgslIrEmitError::MissingHandle("constant \{handle.index()}")
  }
}

///|
fn WgslIrEmitter::override_name(
  self : WgslIrEmitter,
  handle : Handle,
) -> String raise WgslIrEmitError {
  match self.shader_module.overrides.items.get(handle.index()) {
    Some(override_) =>
      match override_.name {
        Some(name) => sanitize_wgsl_ir_identifier(name)
        None => raise WgslIrEmitError::MissingName("override \{handle.index()}")
      }
    None => raise WgslIrEmitError::MissingHandle("override \{handle.index()}")
  }
}

///|
fn WgslIrEmitter::global_variable_name(
  self : WgslIrEmitter,
  handle : Handle,
) -> String raise WgslIrEmitError {
  match self.shader_module.global_variables.items.get(handle.index()) {
    Some(global) =>
      match global.name {
        Some(name) => sanitize_wgsl_ir_identifier(name)
        None =>
          raise WgslIrEmitError::MissingName(
            "global variable \{handle.index()}",
          )
      }
    None =>
      raise WgslIrEmitError::MissingHandle("global variable \{handle.index()}")
  }
}

///|
fn WgslIrEmitter::function_name(
  self : WgslIrEmitter,
  handle : Handle,
) -> String raise WgslIrEmitError {
  match self.shader_module.functions.items.get(handle.index()) {
    Some(function) =>
      match function.name {
        Some(name) => sanitize_wgsl_ir_identifier(name)
        None => raise WgslIrEmitError::MissingName("function \{handle.index()}")
      }
    None => raise WgslIrEmitError::MissingHandle("function \{handle.index()}")
  }
}

///|
fn WgslIrEmitter::function_argument_name(
  self : WgslIrEmitter,
  function : Function?,
  index : Int,
) -> String raise WgslIrEmitError {
  guard function is Some(func) else {
    raise WgslIrEmitError::Unsupported("function argument outside function")
  }
  match func.arguments.get(index) {
    Some(argument) => {
      let base_name = self.function_argument_base_name(argument, index)
      if self.function_argument_name_needs_suffix(func, index, base_name) {
        "\{base_name}_1"
      } else {
        base_name
      }
    }
    None => raise WgslIrEmitError::MissingHandle("function argument \{index}")
  }
}

///|
fn WgslIrEmitter::function_argument_base_name(
  self : WgslIrEmitter,
  argument : FunctionArgument,
  index : Int,
) -> String {
  ignore(self)
  match argument.name {
    Some(name) => sanitize_wgsl_ir_identifier(name)
    None => "arg\{index}"
  }
}

///|
fn WgslIrEmitter::function_argument_name_needs_suffix(
  self : WgslIrEmitter,
  function : Function,
  argument_index : Int,
  base_name : String,
) -> Bool {
  if self.function_is_entry_point_name(function) {
    return false
  }
  if !self.function_is_generated_import_function(function) {
    return false
  }
  for index in 0..<argument_index {
    if self.function_argument_base_name(function.arguments[index], index) ==
      base_name {
      return true
    }
  }
  if self.previous_generated_import_function_uses_argument_name(
      function, base_name,
    ) {
    return true
  }
  self.entry_point_function_uses_local_name(base_name)
}

///|
fn WgslIrEmitter::previous_generated_import_function_uses_argument_name(
  self : WgslIrEmitter,
  function : Function,
  base_name : String,
) -> Bool {
  guard function.name is Some(current_name) else { return false }
  for sibling in self.shader_module.functions.items {
    match sibling.name {
      Some(name) if name == current_name => return false
      _ => ()
    }
    if self.function_is_generated_import_function(sibling) {
      for index in 0..<sibling.arguments.length() {
        if self.function_argument_base_name(sibling.arguments[index], index) ==
          base_name {
          return true
        }
      }
    }
  }
  false
}

///|
fn WgslIrEmitter::function_is_generated_import_function(
  self : WgslIrEmitter,
  function : Function,
) -> Bool {
  ignore(self)
  function.generated_import
}

///|
fn WgslIrEmitter::entry_point_function_uses_local_name(
  self : WgslIrEmitter,
  name : String,
) -> Bool {
  for entry_point in self.shader_module.entry_points {
    for index in 0..<entry_point.function.arguments.length() {
      if self.function_argument_base_name(
          entry_point.function.arguments[index],
          index,
        ) ==
        name {
        return true
      }
    }
    for index in 0..<entry_point.function.local_variables.items.length() {
      if self.local_variable_base_name(
          entry_point.function.local_variables.items[index],
          Handle::Handle(index),
        ) ==
        name {
        return true
      }
    }
  }
  false
}

///|
fn WgslIrEmitter::local_variable_name(
  self : WgslIrEmitter,
  function : Function?,
  handle : Handle,
) -> String raise WgslIrEmitError {
  ignore(self)
  guard function is Some(func) else {
    raise WgslIrEmitError::Unsupported("local variable outside function")
  }
  match func.local_variables.items.get(handle.index()) {
    Some(local_var) => {
      let base_name = self.local_variable_base_name(local_var, handle)
      if self.local_variable_name_needs_suffix(func, handle, base_name) {
        "\{base_name}_\{handle.index()}"
      } else {
        base_name
      }
    }
    None =>
      raise WgslIrEmitError::MissingHandle("local variable \{handle.index()}")
  }
}

///|
fn WgslIrEmitter::local_variable_base_name(
  self : WgslIrEmitter,
  local_var : LocalVariable,
  handle : Handle,
) -> String {
  ignore(self)
  match local_var.name {
    Some(name) => sanitize_wgsl_ir_identifier(name)
    None => "local\{handle.index()}"
  }
}

///|
fn WgslIrEmitter::local_variable_name_needs_suffix(
  self : WgslIrEmitter,
  function : Function,
  handle : Handle,
  base_name : String,
) -> Bool {
  for index in 0..<function.arguments.length() {
    if self.function_argument_base_name(function.arguments[index], index) ==
      base_name {
      return true
    }
  }
  for index in 0..<function.local_variables.items.length() {
    if index == handle.index() {
      return false
    }
    if self.local_variable_base_name(
        function.local_variables.items[index],
        Handle::Handle(index),
      ) ==
      base_name {
      return true
    }
  }
  false
}

///|
fn WgslIrEmitter::unary_operator(
  self : WgslIrEmitter,
  op : UnaryOperator,
) -> String {
  ignore(self)
  match op {
    Negate => "-"
    LogicalNot => "!"
    BitwiseNot => "~"
  }
}

///|
fn WgslIrEmitter::binary_operator(
  self : WgslIrEmitter,
  op : BinaryOperator,
) -> String {
  ignore(self)
  match op {
    Add => "+"
    Subtract => "-"
    Multiply => "*"
    Divide => "/"
    Modulo => "%"
    Equal => "=="
    NotEqual => "!="
    Less => "<"
    LessEqual => "<="
    Greater => ">"
    GreaterEqual => ">="
    And => "&"
    ExclusiveOr => "^"
    InclusiveOr => "|"
    LogicalAnd => "&&"
    LogicalOr => "||"
    ShiftLeft => "<<"
    ShiftRight => ">>"
  }
}

///|
fn WgslIrEmitter::math_function_name(
  self : WgslIrEmitter,
  math_function : MathFunction,
) -> String raise WgslIrEmitError {
  ignore(self)
  match math_function {
    Abs => "abs"
    Min => "min"
    Max => "max"
    Clamp => "clamp"
    Saturate => "saturate"
    Cos => "cos"
    Cosh => "cosh"
    Sin => "sin"
    Sinh => "sinh"
    Tan => "tan"
    Tanh => "tanh"
    Acos => "acos"
    Acosh => "acosh"
    Asin => "asin"
    Asinh => "asinh"
    Atan => "atan"
    Atanh => "atanh"
    Atan2 => "atan2"
    Radians => "radians"
    Degrees => "degrees"
    Ceil => "ceil"
    Floor => "floor"
    Round => "round"
    Fract => "fract"
    Trunc => "trunc"
    Modf => "modf"
    Frexp => "frexp"
    Ldexp => "ldexp"
    Exp => "exp"
    Exp2 => "exp2"
    Log => "log"
    Log2 => "log2"
    Pow => "pow"
    Dot => "dot"
    Dot4I8Packed => "dot4I8Packed"
    Dot4U8Packed => "dot4U8Packed"
    Cross => "cross"
    Distance => "distance"
    Length => "length"
    Normalize => "normalize"
    FaceForward => "faceForward"
    Reflect => "reflect"
    Refract => "refract"
    Sign => "sign"
    Fma => "fma"
    Mix => "mix"
    Step => "step"
    SmoothStep => "smoothstep"
    Sqrt => "sqrt"
    InverseSqrt => "inverseSqrt"
    Inverse => "inverse"
    Transpose => "transpose"
    Determinant => "determinant"
    QuantizeToF16 => "quantizeToF16"
    CountTrailingZeros => "countTrailingZeros"
    CountLeadingZeros => "countLeadingZeros"
    CountOneBits => "countOneBits"
    ReverseBits => "reverseBits"
    ExtractBits => "extractBits"
    InsertBits => "insertBits"
    FirstTrailingBit => "firstTrailingBit"
    FirstLeadingBit => "firstLeadingBit"
    Pack4x8snorm => "pack4x8snorm"
    Pack4x8unorm => "pack4x8unorm"
    Pack2x16snorm => "pack2x16snorm"
    Pack2x16unorm => "pack2x16unorm"
    Pack2x16float => "pack2x16float"
    Pack4xI8 => "pack4xI8"
    Pack4xU8 => "pack4xU8"
    Pack4xI8Clamp => "pack4xI8Clamp"
    Pack4xU8Clamp => "pack4xU8Clamp"
    Unpack4x8snorm => "unpack4x8snorm"
    Unpack4x8unorm => "unpack4x8unorm"
    Unpack2x16snorm => "unpack2x16snorm"
    Unpack2x16unorm => "unpack2x16unorm"
    Unpack2x16float => "unpack2x16float"
    Unpack4xI8 => "unpack4xI8"
    Unpack4xU8 => "unpack4xU8"
    _ => raise WgslIrEmitError::Unsupported("math function")
  }
}

///|
fn wgsl_ir_derivative_function_name(
  axis : DerivativeAxis,
  control : DerivativeControl,
) -> String {
  match (axis, control) {
    (X, DerivativeControl::None) => "dpdx"
    (X, Coarse) => "dpdxCoarse"
    (X, Fine) => "dpdxFine"
    (Y, DerivativeControl::None) => "dpdy"
    (Y, Coarse) => "dpdyCoarse"
    (Y, Fine) => "dpdyFine"
    (Width, DerivativeControl::None) => "fwidth"
    (Width, Coarse) => "fwidthCoarse"
    (Width, Fine) => "fwidthFine"
  }
}

///|
fn WgslIrEmitter::relational_function_name(
  self : WgslIrEmitter,
  relational_function : RelationalFunction,
) -> String {
  ignore(self)
  match relational_function {
    All => "all"
    Any => "any"
    IsNan => "isNan"
    IsInf => "isInf"
  }
}

///|
fn WgslIrEmitter::atomic_function_name(
  self : WgslIrEmitter,
  atomic_function : AtomicFunction,
) -> String {
  ignore(self)
  match atomic_function {
    Load => "atomicLoad"
    Store => "atomicStore"
    Add => "atomicAdd"
    Subtract => "atomicSub"
    Max => "atomicMax"
    Min => "atomicMin"
    And => "atomicAnd"
    InclusiveOr => "atomicOr"
    ExclusiveOr => "atomicXor"
    Exchange => "atomicExchange"
    CompareExchangeWeak => "atomicCompareExchangeWeak"
  }
}

///|
fn WgslIrEmitter::texture_atomic_function_name(
  self : WgslIrEmitter,
  atomic_function : AtomicFunction,
) -> String raise WgslIrEmitError {
  ignore(self)
  match atomic_function {
    Add => "textureAtomicAdd"
    And => "textureAtomicAnd"
    Max => "textureAtomicMax"
    Min => "textureAtomicMin"
    InclusiveOr => "textureAtomicOr"
    ExclusiveOr => "textureAtomicXor"
    _ =>
      raise WgslIrEmitError::Unsupported("unsupported texture atomic function")
  }
}

///|
fn WgslIrEmitter::storage_format_name(
  self : WgslIrEmitter,
  format : StorageFormat,
) -> String {
  ignore(self)
  match format {
    R8Unorm => "r8unorm"
    R8Snorm => "r8snorm"
    R8Uint => "r8uint"
    R8Sint => "r8sint"
    R16Uint => "r16uint"
    R16Sint => "r16sint"
    R16Float => "r16float"
    Rg8Unorm => "rg8unorm"
    Rg8Snorm => "rg8snorm"
    Rg8Uint => "rg8uint"
    Rg8Sint => "rg8sint"
    R32Uint => "r32uint"
    R32Sint => "r32sint"
    R32Float => "r32float"
    Rg16Uint => "rg16uint"
    Rg16Sint => "rg16sint"
    Rg16Float => "rg16float"
    Rgba8Unorm => "rgba8unorm"
    Rgba8Snorm => "rgba8snorm"
    Rgba8Uint => "rgba8uint"
    Rgba8Sint => "rgba8sint"
    Bgra8Unorm => "bgra8unorm"
    Rgb10a2Uint => "rgb10a2uint"
    Rgb10a2Unorm => "rgb10a2unorm"
    Rg11b10Ufloat => "rg11b10ufloat"
    R64Uint => "r64uint"
    Rg32Uint => "rg32uint"
    Rg32Sint => "rg32sint"
    Rg32Float => "rg32float"
    Rgba16Uint => "rgba16uint"
    Rgba16Sint => "rgba16sint"
    Rgba16Float => "rgba16float"
    Rgba32Uint => "rgba32uint"
    Rgba32Sint => "rgba32sint"
    Rgba32Float => "rgba32float"
    R16Unorm => "r16unorm"
    R16Snorm => "r16snorm"
    Rg16Unorm => "rg16unorm"
    Rg16Snorm => "rg16snorm"
    Rgba16Unorm => "rgba16unorm"
    Rgba16Snorm => "rgba16snorm"
  }
}

///|
fn wgsl_ir_emit_storage_format_scalar(format : StorageFormat) -> Scalar {
  match format {
    R64Uint => Scalar::Scalar(Uint, 8)
    R8Uint
    | R16Uint
    | R32Uint
    | Rg8Uint
    | Rg16Uint
    | Rgba8Uint
    | Rgb10a2Uint
    | Rg32Uint
    | Rgba16Uint
    | Rgba32Uint => Scalar::Scalar(Uint, 4)
    R8Sint
    | R16Sint
    | R32Sint
    | Rg8Sint
    | Rg16Sint
    | Rgba8Sint
    | Rg32Sint
    | Rgba16Sint
    | Rgba32Sint => Scalar::Scalar(Sint, 4)
    _ => Scalar::Scalar(Float, 4)
  }
}

///|
fn wgsl_ir_swizzle_component(index : Int) -> String raise WgslIrEmitError {
  match index {
    0 => "x"
    1 => "y"
    2 => "z"
    3 => "w"
    _ => raise WgslIrEmitError::Unsupported("access index \{index}")
  }
}

///|
fn wgsl_ir_gather_component_index(component : SwizzleComponent) -> Int {
  match component {
    X => 0
    Y => 1
    Z => 2
    W => 3
  }
}

///|
fn wgsl_ir_swizzle_component_name(component : SwizzleComponent) -> String {
  match component {
    X => "x"
    Y => "y"
    Z => "z"
    W => "w"
  }
}

///|
fn wgsl_ir_indent(count : Int) -> String {
  let out = StringBuilder::new()
  for _ in 0..<count {
    out.write_string("    ")
  }
  out.to_string()
}
