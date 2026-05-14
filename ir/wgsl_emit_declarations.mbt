///|
fn WgslIrEmitter::emit_struct_type(
  self : WgslIrEmitter,
  out : StringBuilder,
  handle : Handle,
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
  ignore(name)
  let type_name = self.required_emit_name(
    wgsl_ir_emit_name_key("type", handle.index()),
  )
  out.write_string("struct \{type_name} {\n")
  for member_index in 0..<members.length() {
    let struct_member = members[member_index]
    out.write_string("    ")
    self.emit_struct_member_layout_attribute_prefix(out, struct_member)
    self.emit_binding_attribute_prefix(out, struct_member.binding)
    let member_name = self.required_emit_name(
      wgsl_ir_emit_name_key2("member", handle.index(), member_index),
    )
    out.write_string("\{member_name}: \{self.type_name(struct_member.ty)},\n")
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
  handle : Handle,
  constant : Constant,
) -> Unit raise WgslIrEmitError {
  guard constant.name is Some(name) else {
    raise WgslIrEmitError::MissingName("constant")
  }
  ignore(name)
  let generated_name = self.constant_name(handle)
  if self.type_contains_abstract_scalar(constant.ty) {
    out.write_string(
      "const \{generated_name} = \{self.abstract_float_global_expression(constant.init)};\n",
    )
  } else if self.folded_constant_expression(constant) is Some(value) {
    out.write_string(
      "const \{generated_name}: \{self.type_name(constant.ty)} = \{value};\n",
    )
  } else {
    out.write_string(
      "const \{generated_name}: \{self.type_name(constant.ty)} = \{self.global_expression(constant.init)};\n",
    )
  }
}

///|
fn WgslIrEmitter::emit_override(
  self : WgslIrEmitter,
  out : StringBuilder,
  handle : Handle,
  override_ : Override,
) -> Unit raise WgslIrEmitError {
  match override_.id {
    Some(id) => out.write_string("@id(\{id}) ")
    None => ()
  }
  guard override_.name is Some(name) else {
    raise WgslIrEmitError::MissingName("override")
  }
  ignore(name)
  let generated_name = self.override_name(handle)
  if self.type_contains_abstract_scalar(override_.ty) {
    out.write_string("override \{generated_name}")
  } else {
    out.write_string(
      "override \{generated_name}: \{self.type_name(override_.ty)}",
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
  handle : Handle,
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
  ignore(name)
  let generated_name = self.global_variable_name(handle)
  let space = self.address_space_template(global.space)
  out.write_string(
    "var\{space} \{generated_name}: \{self.type_name(global.ty)}",
  )
  match global.init {
    Some(init) => out.write_string(" = \{self.global_expression(init)}")
    None => ()
  }
  out.write_string(";\n")
}
