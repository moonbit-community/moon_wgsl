///|
fn WgslIrValidator::validate_type_inner(
  self : WgslIrValidator,
  inner : TypeInner,
) -> Unit raise WgslIrValidationError {
  match inner {
    Pointer(base, space) => {
      self.require_type(base)
      self.validate_pointer_address_space(space)
    }
    ValuePointer(_, _, space) => self.validate_pointer_address_space(space)
    Array(base, size, stride) => {
      self.require_type(base)
      self.validate_array_size(size)
      self.validate_array_stride(base, stride)
    }
    BindingArray(base, size) => {
      self.require_type(base)
      self.validate_array_size(size)
    }
    Struct(members, span) => self.validate_struct_layout(members, span)
    PredeclaredStruct(members, _) =>
      for struct_member in members {
        self.require_type(struct_member.ty)
      }
    Atomic(scalar) => self.validate_atomic_scalar(scalar)
    _ => ()
  }
}

///|
fn WgslIrValidator::validate_array_size(
  self : WgslIrValidator,
  size : ArraySize,
) -> Unit raise WgslIrValidationError {
  match size {
    Pending(handle) => self.validate_global_expression_handle(handle)
    Constant(_) | Dynamic => ()
  }
}

///|
fn WgslIrValidator::validate_global_variable(
  self : WgslIrValidator,
  global : GlobalVariable,
) -> Unit raise WgslIrValidationError {
  self.require_type(global.ty)
  self.validate_global_address_space(global)
  match global.binding {
    Some(binding) => {
      if binding.group < 0 || binding.binding < 0 {
        raise InvalidGlobalVariable("negative resource binding")
      }
      if !self.global_address_space_accepts_resource_binding(global.space) {
        raise InvalidGlobalVariable(
          "resource binding on non-resource address space",
        )
      }
    }
    None => ()
  }
  match global.init {
    Some(init) => {
      if !self.global_address_space_accepts_initializer(global.space) {
        raise InvalidGlobalVariable(
          "initializer on non-initializable address space",
        )
      }
      self.validate_global_expression_handle(init)
    }
    None => ()
  }
}

///|
fn WgslIrValidator::validate_global_address_space(
  self : WgslIrValidator,
  global : GlobalVariable,
) -> Unit raise WgslIrValidationError {
  match global.space {
    Handle =>
      if !self.type_is_handle_resource(global.ty) {
        raise InvalidGlobalVariable(
          "handle address space requires handle resource type",
        )
      }
    Storage(access) =>
      if access == StorageAccess::empty() {
        raise InvalidGlobalVariable("storage address space has empty access")
      }
    _ => ()
  }
}

///|
fn WgslIrValidator::global_address_space_accepts_resource_binding(
  self : WgslIrValidator,
  space : AddressSpace,
) -> Bool {
  ignore(self)
  match space {
    Uniform | Storage(_) | Handle => true
    _ => false
  }
}

///|
fn WgslIrValidator::global_address_space_accepts_initializer(
  self : WgslIrValidator,
  space : AddressSpace,
) -> Bool {
  ignore(self)
  match space {
    Private => true
    _ => false
  }
}

///|
fn WgslIrValidator::validate_pointer_address_space(
  self : WgslIrValidator,
  space : AddressSpace,
) -> Unit raise WgslIrValidationError {
  ignore(self)
  match space {
    Function
    | Private
    | WorkGroup
    | Uniform
    | Storage(_)
    | TaskPayload
    | RayPayload
    | IncomingRayPayload => ()
    Handle | Immediate =>
      raise InvalidType("pointer uses non-addressable address space")
  }
}

///|
fn WgslIrValidator::validate_atomic_scalar(
  self : WgslIrValidator,
  scalar : Scalar,
) -> Unit raise WgslIrValidationError {
  ignore(self)
  if !(scalar.kind == Sint || scalar.kind == Uint) || scalar.width != 4 {
    raise InvalidType("atomic type must use i32 or u32 scalar")
  }
}

///|
fn WgslIrValidator::validate_array_stride(
  self : WgslIrValidator,
  base : Handle,
  stride : Int,
) -> Unit raise WgslIrValidationError {
  if stride <= 0 {
    raise InvalidType("array stride must be positive")
  }
  let layout = self.type_layout(base)
  if stride < layout.size {
    let element_text = match self.shader_module.types.items.get(base.index()) {
      Some(value) => @debug.to_string(value)
      None => "<invalid type handle>"
    }
    raise InvalidType(
      "array stride is smaller than element size: stride=\{stride}, element_size=\{layout.size}, element_type=\{base.index()} \{element_text}",
    )
  }
  if stride % layout.align != 0 {
    let element_text = match self.shader_module.types.items.get(base.index()) {
      Some(value) => @debug.to_string(value)
      None => "<invalid type handle>"
    }
    raise InvalidType(
      "array stride is not aligned to element alignment: stride=\{stride}, element_align=\{layout.align}, element_type=\{base.index()} \{element_text}",
    )
  }
}

///|
fn WgslIrValidator::validate_struct_layout(
  self : WgslIrValidator,
  members : Array[StructMember],
  span : Int,
) -> Unit raise WgslIrValidationError {
  if span <= 0 {
    raise InvalidType("struct span must be positive")
  }
  let mut end = 0
  let mut max_align = 1
  for index in 0..<members.length() {
    let struct_member = members[index]
    self.require_type(struct_member.ty)
    if self.type_is_runtime_array(struct_member.ty) &&
      index != members.length() - 1 {
      raise InvalidType("runtime array is only valid as the last struct member")
    }
    let layout = self.type_layout(struct_member.ty)
    let member_align = match struct_member.align {
      Some(value) => value
      None => layout.align
    }
    if !wgsl_ir_validation_is_power_of_two(member_align) ||
      member_align < layout.align {
      raise InvalidType("struct member alignment is invalid")
    }
    let member_size = match struct_member.size {
      Some(value) => value
      None => layout.size
    }
    if member_size < layout.size {
      raise InvalidType("struct member size is smaller than type size")
    }
    if struct_member.offset < end {
      raise InvalidType("struct member offset overlaps previous member")
    }
    if struct_member.offset % member_align != 0 {
      raise InvalidType("struct member offset is not aligned")
    }
    end = struct_member.offset + member_size
    if member_align > max_align {
      max_align = member_align
    }
  }
  if span < end {
    raise InvalidType("struct span is smaller than member range")
  }
  if span % max_align != 0 {
    raise InvalidType("struct span is not aligned to struct alignment")
  }
}
