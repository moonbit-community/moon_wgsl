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
  emit_wgsl_module_from_ir_with_options(
    shader_module,
    WgslIrEmitOptions::valid_wgsl(),
  )
}

///|
fn emit_wgsl_module_from_ir_naga_oil_writer_compatible(
  shader_module : Module,
) -> String raise WgslIrEmitError {
  emit_wgsl_module_from_ir_with_options(
    shader_module,
    WgslIrEmitOptions::naga_oil_writer_compatible(),
  )
}

///|
fn emit_wgsl_module_from_ir_with_options(
  shader_module : Module,
  options : WgslIrEmitOptions,
) -> String raise WgslIrEmitError {
  validate_wgsl_ir_module(shader_module) catch {
    error => raise WgslIrEmitError::Unsupported(error.message())
  }
  let emitter = WgslIrEmitter::{ shader_module, options, filter: None }
  emitter.emit_module()
}

///|
fn emit_wgsl_module_from_ir_roots(
  shader_module : Module,
  root_items : Array[String],
) -> String raise WgslIrEmitError {
  emit_wgsl_module_from_ir_with_options_and_roots(
    shader_module,
    WgslIrEmitOptions::valid_wgsl(),
    root_items,
  )
}

///|
fn emit_wgsl_module_from_ir_with_options_and_roots(
  shader_module : Module,
  options : WgslIrEmitOptions,
  root_items : Array[String],
) -> String raise WgslIrEmitError {
  if root_items.length() == 0 {
    return emit_wgsl_module_from_ir_with_options(shader_module, options)
  }
  let filter = build_wgsl_ir_emit_filter(shader_module, root_items)
  validate_wgsl_ir_module_with_filter(shader_module, filter) catch {
    error => raise WgslIrEmitError::Unsupported(error.message())
  }
  let emitter = WgslIrEmitter::{ shader_module, options, filter: Some(filter) }
  emitter.emit_module()
}

///|
priv struct WgslIrEmitOptions {
  preserve_abstract_float_literals : Bool
  annotate_atomic_compare_exchange_result_locals : Bool
  inline_generated_import_constants : Bool
}

///|
fn WgslIrEmitOptions::valid_wgsl() -> WgslIrEmitOptions {
  WgslIrEmitOptions::{
    preserve_abstract_float_literals: false,
    annotate_atomic_compare_exchange_result_locals: false,
    inline_generated_import_constants: false,
  }
}

///|
fn WgslIrEmitOptions::naga_oil_writer_compatible() -> WgslIrEmitOptions {
  WgslIrEmitOptions::{
    preserve_abstract_float_literals: false,
    annotate_atomic_compare_exchange_result_locals: true,
    inline_generated_import_constants: true,
  }
}

///|
priv struct WgslIrEmitter {
  shader_module : Module
  options : WgslIrEmitOptions
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
    options: WgslIrEmitOptions::{
      preserve_abstract_float_literals: true,
      annotate_atomic_compare_exchange_result_locals: self.options.annotate_atomic_compare_exchange_result_locals,
      inline_generated_import_constants: self.options.inline_generated_import_constants,
    },
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
        None =>
          raise WgslIrEmitError::Unsupported(
            "mesh entry point without mesh output",
          )
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
  out.write_string("\n")
  self.emit_function(out, entry_point.function, Some(entry_point.name))
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
  if self.options.annotate_atomic_compare_exchange_result_locals &&
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
  if self.options.inline_generated_import_constants &&
    self.compose_components_include_generated_import_constant(
      components, function,
    ) {
    match
      self.generated_import_constant_scalar_constructor_name(
        handle, components, function,
      ) {
      Some(name) => return name
      None => return self.type_name(handle)
    }
  }
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
fn WgslIrEmitter::compose_components_include_generated_import_constant(
  self : WgslIrEmitter,
  components : Array[Handle],
  function : Function?,
) -> Bool {
  for component in components {
    let expression = match function {
      Some(func) =>
        match func.expressions.items.get(component.index()) {
          Some(value) => value
          None => continue
        }
      None =>
        match
          self.shader_module.global_expressions.items.get(component.index()) {
          Some(value) => value
          None => continue
        }
    }
    match expression {
      Constant(handle) =>
        match self.shader_module.constants.items.get(handle.index()) {
          Some(constant) if constant.inline_value => return true
          _ => ()
        }
      _ => ()
    }
  }
  false
}

///|
fn WgslIrEmitter::generated_import_constant_scalar_constructor_name(
  self : WgslIrEmitter,
  handle : Handle,
  components : Array[Handle],
  function : Function?,
) -> String? {
  let mut scalar : Scalar? = None
  for component in components {
    let expression = match function {
      Some(func) =>
        match func.expressions.items.get(component.index()) {
          Some(value) => value
          None => continue
        }
      None =>
        match
          self.shader_module.global_expressions.items.get(component.index()) {
          Some(value) => value
          None => continue
        }
    }
    match expression {
      Constant(constant_handle) =>
        match self.shader_module.constants.items.get(constant_handle.index()) {
          Some(constant) if constant.inline_value =>
            match self.shader_module.types.items.get(constant.ty.index()) {
              Some({ inner: Scalar(value), .. }) => scalar = Some(value)
              _ => ()
            }
          _ => ()
        }
      _ => ()
    }
  }
  guard scalar is Some(concrete_scalar) else { return None }
  match self.shader_module.types.items.get(handle.index()) {
    Some({ inner: Vector(size, _), .. }) =>
      Some("vec\{size.width()}<\{self.scalar_name(concrete_scalar)}>")
    Some({ inner: Matrix(columns, rows, _), .. }) =>
      Some(
        "mat\{columns.width()}x\{rows.width()}<\{self.scalar_name(concrete_scalar)}>",
      )
    _ => None
  }
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
    AccelerationStructure(vertex_return) =>
      if vertex_return {
        "acceleration_structure<vertex_return>"
      } else {
        "acceleration_structure"
      }
    RayQuery(vertex_return) =>
      if vertex_return {
        "ray_query<vertex_return>"
      } else {
        "ray_query"
      }
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
    Task => "@task"
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
    Some(Location(location, interpolation, sampling, blend_src, per_primitive)) => {
      if per_primitive {
        out.write_string("@per_primitive ")
      }
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
    MeshTaskSize => "mesh_task_size"
    CullPrimitive => "cull_primitive"
    PointIndex => "point_index"
    LineIndices => "line_indices"
    TriangleIndices => "triangle_indices"
    VertexCount => "vertex_count"
    Vertices => "vertices"
    PrimitiveCount => "primitive_count"
    Primitives => "primitives"
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
      if self.options.preserve_abstract_float_literals {
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
fn WgslIrEmitter::constant_expression(
  self : WgslIrEmitter,
  handle : Handle,
) -> String raise WgslIrEmitError {
  match self.shader_module.constants.items.get(handle.index()) {
    Some(constant) =>
      if self.options.inline_generated_import_constants && constant.inline_value {
        self.global_expression(constant.init)
      } else {
        self.constant_name(handle)
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
