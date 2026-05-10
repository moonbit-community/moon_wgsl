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
