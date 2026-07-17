///|
fn WgslIrLowerer::predeclare_global_type_declaration(
  self : WgslIrLowerer,
  declaration : @ast.WgslGlobalDecl,
) -> Unit {
  match declaration.data() {
    Struct(struct_decl) => self.predeclare_struct_declaration(struct_decl)
    _ => ()
  }
}

///|
fn WgslIrLowerer::predeclare_global_type_alias(
  self : WgslIrLowerer,
  declaration : @ast.WgslGlobalDecl,
) -> Unit raise WgslIrLowerError {
  match declaration.data() {
    TypeAlias(alias_decl) => self.lower_type_alias(alias_decl)
    _ => ()
  }
}

///|
fn WgslIrLowerer::predeclare_global_value_declaration(
  self : WgslIrLowerer,
  declaration : @ast.WgslGlobalDecl,
) -> Unit raise WgslIrLowerError {
  match declaration.data() {
    Function(function) => self.predeclare_function_declaration(function)
    GlobalVariable(global) => self.predeclare_global_variable(global)
    Const(constant) => self.predeclare_constant_declaration(constant)
    Override(override_decl) =>
      self.predeclare_override_declaration(override_decl)
    _ => ()
  }
}

///|
fn WgslIrLowerer::lower_global_type_body_declaration(
  self : WgslIrLowerer,
  declaration : @ast.WgslGlobalDecl,
) -> Unit raise WgslIrLowerError {
  match declaration.data() {
    Struct(struct_decl) => self.lower_struct_declaration(struct_decl)
    TypeAlias(alias_decl) => self.lower_type_alias(alias_decl)
    _ => ()
  }
}

///|
fn WgslIrLowerer::predeclare_struct_declaration(
  self : WgslIrLowerer,
  struct_decl : @ast.WgslStruct,
) -> Unit {
  if self.type_cache.contains(struct_decl.name().name()) {
    return
  }
  let handle = self.shader_module.append_type({
    name: Some(struct_decl.name().name()),
    inner: Struct([], 1),
  })
  self.type_cache.set(struct_decl.name().name(), handle)
}

///|
fn WgslIrLowerer::predeclare_function_declaration(
  self : WgslIrLowerer,
  function : @ast.WgslFunction,
) -> Unit raise WgslIrLowerError {
  if self.function_names.contains(function.name().name()) {
    return
  }
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
  let placeholder = Function::{
    name: Some(function.name().name()),
    source_start: function.fn_start(),
    arguments: [],
    result,
    local_variables: LocalVariableArena(),
    expressions: ExpressionArena(),
    named_expressions: [],
    body: Block(),
    diagnostic_filter_leaf: None,
  }
  let handle = self.shader_module.append_function(placeholder)
  self.function_names.set(function.name().name(), handle)
}

///|
fn WgslIrLowerer::predeclare_global_variable(
  self : WgslIrLowerer,
  global : @ast.WgslGlobalVariable,
) -> Unit raise WgslIrLowerError {
  let name = global.name().name()
  if self.global_names.contains(name) {
    return
  }
  let inferred_ty = match global.ty_ref() {
    Some(ty_ref) => self.lower_type_ref(ty_ref)
    None =>
      self.infer_local_type_from_initializer(name, global.initializer_ref())
  }
  let ty = self.concretize_abstract_storage_type(inferred_ty)
  let handle = self.shader_module.append_global_variable({
    name: Some(name),
    space: self.global_address_space(global.template_list(), ty),
    binding: wgsl_ir_resource_binding_from_attributes(global.attributes()),
    ty,
    init: None,
    memory_decorations: wgsl_ir_memory_decorations_from_attributes(
      global.attributes(),
    ),
  })
  self.global_names.set(name, handle)
}

///|
fn WgslIrLowerer::predeclare_constant_declaration(
  self : WgslIrLowerer,
  constant : @ast.WgslConst,
) -> Unit raise WgslIrLowerError {
  let name = constant.name().name()
  if self.constant_names.contains(name) {
    return
  }
  let ty = self.infer_constant_declaration_type(constant)
  let placeholder_init = self.shader_module.append_global_expression(
    ZeroValue(ty),
  )
  let handle = self.shader_module.append_constant({
    name: Some(name),
    source_start: constant.name().start(),
    ty,
    init: placeholder_init,
  })
  self.constant_names.set(name, handle)
}

///|
fn WgslIrLowerer::predeclare_override_declaration(
  self : WgslIrLowerer,
  override_decl : @ast.WgslOverride,
) -> Unit raise WgslIrLowerError {
  let name = override_decl.name().name()
  if self.override_names.contains(name) {
    return
  }
  if self.override_type_inference_stack.contains(name) {
    raise MissingType(name)
  }
  self.override_type_inference_stack.add(name)
  let ty = match override_decl.ty_ref() {
    Some(ty_ref) => self.lower_type_ref(ty_ref)
    None =>
      self.infer_local_type_from_initializer(
        name,
        override_decl.initializer_ref(),
      )
  }
  let handle = self.shader_module.append_override({
    name: Some(name),
    id: wgsl_ir_id_from_attributes(override_decl.attributes()),
    ty,
    init: None,
  })
  self.override_names.set(name, handle)
  ignore(self.override_type_inference_stack.remove(name))
}

///|
fn WgslIrLowerer::lower_global_declaration(
  self : WgslIrLowerer,
  declaration : @ast.WgslGlobalDecl,
) -> Unit raise WgslIrLowerError {
  match declaration.data() {
    Struct(_) | TypeAlias(_) => ()
    GlobalVariable(global) => self.lower_global_variable(global)
    Const(constant) => self.lower_constant(constant)
    ConstAssert(expr) => self.lower_global_const_assert(expr)
    Override(override_decl) => self.lower_override(override_decl)
    Function(function) => self.lower_function_declaration(function)
    Directive(directive) => self.lower_source_directive(directive)
    _ => ()
  }
}

///|
fn WgslIrLowerer::lower_source_directive(
  self : WgslIrLowerer,
  directive : @ast.WgslDirective,
) -> Unit {
  match directive.kind() {
    Enable | Requires | Diagnostic =>
      self.shader_module.append_directive(wgsl_ir_directive_text(directive))
  }
}

///|
fn wgsl_ir_directive_text(directive : @ast.WgslDirective) -> String {
  let out = StringBuilder::new()
  out.write_string(directive.name().name())
  if directive.has_tail() {
    if directive.has_required_tail_separator() {
      out.write_string(" ")
    }
    out.write_string(directive.tail())
  }
  out.write_string(";")
  out.to_string()
}

///|
fn WgslIrLowerer::lower_type_alias(
  self : WgslIrLowerer,
  alias_decl : @ast.WgslTypeAlias,
) -> Unit raise WgslIrLowerError {
  guard alias_decl.ty_ref() is Some(ty_ref) else {
    raise MissingType(alias_decl.name().name())
  }
  let target = self.lower_type_ref(ty_ref)
  self.type_cache.set(alias_decl.name().name(), target)
}

///|
fn WgslIrLowerer::lower_struct_declaration(
  self : WgslIrLowerer,
  struct_decl : @ast.WgslStruct,
) -> Unit raise WgslIrLowerError {
  let members : Array[StructMember] = []
  let mut offset = 0
  let mut max_align = 1
  for struct_member in struct_decl.members() {
    guard struct_member.ty_ref() is Some(member_ty_ref) else {
      raise MissingType(struct_member.name().name())
    }
    let ty = self.lower_type_ref(member_ty_ref)
    let layout = self.type_layout(ty)
    let member_size = wgsl_ir_struct_member_size(
      struct_member.attributes(),
      layout,
    )
    let member_align = wgsl_ir_struct_member_align(
      struct_member.attributes(),
      layout,
    )
    offset = wgsl_ir_align_to(offset, member_align)
    members.push({
      name: Some(struct_member.name().name()),
      ty,
      binding: wgsl_ir_binding_from_attributes(struct_member.attributes()),
      offset,
      size: if wgsl_ir_attribute_named(struct_member.attributes(), "size")
        is Some(_) {
        Some(member_size)
      } else {
        None
      },
      align: if wgsl_ir_attribute_named(struct_member.attributes(), "align")
        is Some(_) {
        Some(member_align)
      } else {
        None
      },
    })
    offset = offset + member_size
    if member_align > max_align {
      max_align = member_align
    }
  }
  let span = wgsl_ir_align_to(if offset == 0 { 1 } else { offset }, max_align)
  let ty = Type::{
    name: Some(struct_decl.name().name()),
    inner: Struct(members, span),
  }
  match self.type_cache.get(struct_decl.name().name()) {
    Some(handle) => self.shader_module.types.set(handle, ty)
    None => {
      let handle = self.shader_module.append_type(ty)
      self.type_cache.set(struct_decl.name().name(), handle)
    }
  }
}

///|
fn WgslIrLowerer::lower_global_variable(
  self : WgslIrLowerer,
  global : @ast.WgslGlobalVariable,
) -> Unit raise WgslIrLowerError {
  let inferred_ty = match global.ty_ref() {
    Some(ty_ref) => self.lower_type_ref(ty_ref)
    None =>
      self.infer_local_type_from_initializer(
        global.name().name(),
        global.initializer_ref(),
      )
  }
  let ty = self.concretize_abstract_storage_type(inferred_ty)
  let init = match global.initializer_ref() {
    Some(expr) =>
      Some(self.lower_global_expression_ref_with_expected(expr, Some(ty)))
    None => None
  }
  let variable = GlobalVariable::{
    name: Some(global.name().name()),
    space: self.global_address_space(global.template_list(), ty),
    binding: wgsl_ir_resource_binding_from_attributes(global.attributes()),
    ty,
    init,
    memory_decorations: wgsl_ir_memory_decorations_from_attributes(
      global.attributes(),
    ),
  }
  match self.global_names.get(global.name().name()) {
    Some(handle) => self.shader_module.global_variables.set(handle, variable)
    None => {
      let handle = self.shader_module.append_global_variable(variable)
      self.global_names.set(global.name().name(), handle)
    }
  }
}

///|
fn WgslIrLowerer::global_address_space(
  self : WgslIrLowerer,
  template_list : Array[@ast.WgslTypeRef],
  ty : Handle,
) -> AddressSpace raise WgslIrLowerError {
  if template_list.length() > 0 {
    return wgsl_ir_address_space_from_template_list(template_list)
  }
  if self.global_type_uses_handle_address_space(ty) {
    return Handle
  }
  Private
}

///|
fn WgslIrLowerer::global_type_uses_handle_address_space(
  self : WgslIrLowerer,
  ty : Handle,
) -> Bool {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Image(_, _, _) | Sampler(_) | AccelerationStructure(_) | RayQuery(_) =>
          true
        BindingArray(element, _) =>
          self.global_type_uses_handle_address_space(element)
        _ => false
      }
    None => false
  }
}

///|
fn WgslIrLowerer::lower_constant(
  self : WgslIrLowerer,
  constant : @ast.WgslConst,
) -> Unit raise WgslIrLowerError {
  let name = constant.name().name()
  if self.lowered_constants.contains(name) {
    return
  }
  if self.constant_lowering_stack.contains(name) {
    raise MissingType(name)
  }
  self.constant_lowering_stack.add(name)
  let explicit_ty = match constant.ty_ref() {
    Some(ty_ref) => Some(self.lower_type_ref(ty_ref))
    None => None
  }
  let (handle, ty) = match self.constant_names.get(name) {
    Some(handle) =>
      match self.shader_module.constants.items.get(handle.index()) {
        Some(existing) => (handle, existing.ty)
        None => raise MissingType(name)
      }
    None => {
      let ty = match explicit_ty {
        Some(ty) => ty
        None =>
          self.infer_local_type_from_initializer(
            name,
            constant.initializer_ref(),
          )
      }
      let placeholder_init = self.shader_module.append_global_expression(
        ZeroValue(ty),
      )
      let handle = self.shader_module.append_constant({
        name: Some(name),
        source_start: constant.name().start(),
        ty,
        init: placeholder_init,
      })
      self.constant_names.set(name, handle)
      (handle, ty)
    }
  }
  let init = match constant.initializer_ref() {
    Some(expr) =>
      self.lower_global_expression_ref_with_expected(expr, explicit_ty)
    None => self.shader_module.append_global_expression(ZeroValue(ty))
  }
  module_set_constant(self.shader_module, handle, {
    name: Some(name),
    source_start: constant.name().start(),
    ty,
    init,
  })
  self.lowered_constants.add(name)
  ignore(self.constant_lowering_stack.remove(name))
}

///|
fn WgslIrLowerer::ensure_constant_declaration_lowered(
  self : WgslIrLowerer,
  name : String,
) -> Handle? raise WgslIrLowerError {
  if self.constant_lowering_stack.contains(name) {
    raise MissingType(name)
  }
  match self.constant_names.get(name) {
    Some(handle) =>
      if self.lowered_constants.contains(name) {
        Some(handle)
      } else {
        match self.constant_declarations.get(name) {
          Some(constant) => {
            self.lower_constant(constant)
            Some(handle)
          }
          None => Some(handle)
        }
      }
    None =>
      match self.constant_declarations.get(name) {
        Some(constant) => {
          self.lower_constant(constant)
          self.constant_names.get(name)
        }
        None => None
      }
  }
}

///|
fn WgslIrLowerer::ensure_override_declaration_predeclared(
  self : WgslIrLowerer,
  name : String,
) -> Handle? raise WgslIrLowerError {
  match self.override_names.get(name) {
    Some(handle) => Some(handle)
    None =>
      match self.override_declarations.get(name) {
        Some(override_decl) => {
          self.predeclare_override_declaration(override_decl)
          self.override_names.get(name)
        }
        None => None
      }
  }
}

///|
fn WgslIrLowerer::lower_global_const_assert(
  self : WgslIrLowerer,
  expr : @ast.WgslExprRef,
) -> Unit raise WgslIrLowerError {
  self.shader_module.append_const_assert(self.lower_global_expression_ref(expr))
}

///|
fn WgslIrLowerer::lower_override(
  self : WgslIrLowerer,
  override_decl : @ast.WgslOverride,
) -> Unit raise WgslIrLowerError {
  let explicit_ty = match override_decl.ty_ref() {
    Some(ty_ref) => Some(self.lower_type_ref(ty_ref))
    None => None
  }
  let ty = match explicit_ty {
    Some(ty) => ty
    None =>
      self.infer_local_type_from_initializer(
        override_decl.name().name(),
        override_decl.initializer_ref(),
      )
  }
  let override_ = Override::{
    name: Some(override_decl.name().name()),
    id: wgsl_ir_id_from_attributes(override_decl.attributes()),
    ty,
    init: match override_decl.initializer_ref() {
      Some(expr) =>
        Some(self.lower_global_expression_ref_with_expected(expr, explicit_ty))
      None => None
    },
  }
  match self.override_names.get(override_decl.name().name()) {
    Some(handle) => self.shader_module.set_override(handle, override_)
    None => {
      let handle = self.shader_module.append_override(override_)
      self.override_names.set(override_decl.name().name(), handle)
    }
  }
}
