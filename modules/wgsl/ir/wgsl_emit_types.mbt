///|
/// A policy-neutral type spelling service shared by WGSL writers.
///
/// Callers supply only writer-owned name/expression lookups and the two byte
/// spelling choices that cannot be derived from semantic IR.
pub struct WgslIrTypeSpelling {
  priv shader_module : Module
  priv final_type_name : (Handle) -> String?
  priv global_expression : (Handle) -> String?
  priv elide_storage_pointer_read_access : Bool
  priv storage_texture_type_argument_separator : String
}

///|
pub suberror WgslIrTypeSpellingError {
  MissingType(Int)
  MissingTypeName(Int)
  MissingGlobalExpression(Int)
  UnsupportedTypeSpelling(String)
}

///|
pub fn WgslIrTypeSpellingError::message(
  self : WgslIrTypeSpellingError,
) -> String {
  match self {
    MissingType(index) => "missing IR type handle: \{index}"
    MissingTypeName(index) => "missing final name for IR type: \{index}"
    MissingGlobalExpression(index) =>
      "missing spelling for IR global expression: \{index}"
    UnsupportedTypeSpelling(message) =>
      "unsupported IR type spelling: \{message}"
  }
}

///|
pub fn WgslIrTypeSpelling::new(
  shader_module : Module,
  final_type_name : (Handle) -> String?,
  global_expression : (Handle) -> String?,
  elide_storage_pointer_read_access : Bool,
  storage_texture_type_argument_separator : String,
) -> WgslIrTypeSpelling {
  {
    shader_module,
    final_type_name,
    global_expression,
    elide_storage_pointer_read_access,
    storage_texture_type_argument_separator,
  }
}

///|
fn WgslIrTypeSpelling::type_inference(
  self : WgslIrTypeSpelling,
) -> WgslIrTypeInference {
  WgslIrTypeInference::from_module(self.shader_module)
}

///|
fn WgslIrTypeSpelling::required_type_name(
  self : WgslIrTypeSpelling,
  handle : Handle,
) -> String raise WgslIrTypeSpellingError {
  match (self.final_type_name)(handle) {
    Some(name) => name
    None => raise MissingTypeName(handle.index())
  }
}

///|
fn WgslIrTypeSpelling::required_global_expression(
  self : WgslIrTypeSpelling,
  handle : Handle,
) -> String raise WgslIrTypeSpellingError {
  match (self.global_expression)(handle) {
    Some(source) => source
    None => raise MissingGlobalExpression(handle.index())
  }
}

///|
pub fn WgslIrTypeSpelling::type_is_pointer(
  self : WgslIrTypeSpelling,
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
pub fn WgslIrTypeSpelling::type_contains_abstract_scalar(
  self : WgslIrTypeSpelling,
  handle : Handle,
) -> Bool {
  match self.shader_module.types.get(handle) {
    Some(ty) => self.type_inner_contains_abstract_scalar(ty.inner)
    None => false
  }
}

///|
fn WgslIrTypeSpelling::type_inner_contains_abstract_scalar(
  self : WgslIrTypeSpelling,
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
pub fn WgslIrTypeSpelling::expression_is_pointer(
  self : WgslIrTypeSpelling,
  function : Function?,
  handle : Handle,
) -> Bool {
  match self.type_inference().expression_type(function, handle) {
    Some(ty) => self.type_is_pointer(ty)
    None => false
  }
}

///|
pub fn WgslIrTypeSpelling::type_name(
  self : WgslIrTypeSpelling,
  handle : Handle,
) -> String raise WgslIrTypeSpellingError {
  let ty = match self.shader_module.types.items.get(handle.index()) {
    Some(value) => value
    None => raise MissingType(handle.index())
  }
  match ty.name {
    Some(name) =>
      match ty.inner {
        Scalar(_) => name
        Struct(_, _) | PredeclaredStruct(_, _) =>
          self.required_type_name(handle)
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
fn WgslIrTypeSpelling::predeclared_result_type_name(
  self : WgslIrTypeSpelling,
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
fn wgsl_ir_predeclared_result_type_from_name(name : String) -> PredeclaredType? {
  let atomic_prefix = "_atomic_compare_exchange_result_"
  if name.has_prefix(atomic_prefix) && name.has_suffix("_") {
    let scalar_name = name[atomic_prefix.length():name.length() - 1].to_owned()
    return match wgsl_ir_predeclared_scalar_from_name(scalar_name) {
      Some(scalar) => Some(AtomicCompareExchangeWeakResult(scalar))
      None => None
    }
  }
  let modf_prefix = "_modf_result_"
  if name.has_prefix(modf_prefix) && name.has_suffix("_") {
    let numeric_name = name[modf_prefix.length():name.length() - 1].to_owned()
    return match wgsl_ir_predeclared_numeric_from_name(numeric_name) {
      Some((size, scalar)) => Some(ModfResult(size, scalar))
      None => None
    }
  }
  let frexp_prefix = "_frexp_result_"
  if name.has_prefix(frexp_prefix) && name.has_suffix("_") {
    let numeric_name = name[frexp_prefix.length():name.length() - 1].to_owned()
    return match wgsl_ir_predeclared_numeric_from_name(numeric_name) {
      Some((size, scalar)) => Some(FrexpResult(size, scalar))
      None => None
    }
  }
  None
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
fn wgsl_ir_predeclared_numeric_from_name(
  name : String,
) -> (VectorSize?, Scalar)? {
  if name.has_prefix("Vec") {
    match name.split("_").collect() {
      [size_name, kind_name, width_name] =>
        match
          (
            wgsl_ir_predeclared_vector_size_from_name(size_name.to_owned()),
            wgsl_ir_predeclared_scalar_from_parts(
              kind_name.to_owned(),
              width_name.to_owned(),
            ),
          ) {
          (Some(size), Some(scalar)) => Some((Some(size), scalar))
          _ => None
        }
      _ => None
    }
  } else {
    match wgsl_ir_predeclared_scalar_from_name(name) {
      Some(scalar) => Some((None, scalar))
      None => None
    }
  }
}

///|
fn wgsl_ir_predeclared_vector_size_from_name(name : String) -> VectorSize? {
  match name {
    "Vec2" => Some(Bi)
    "Vec3" => Some(Tri)
    "Vec4" => Some(Quad)
    _ => None
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
fn wgsl_ir_predeclared_scalar_from_name(name : String) -> Scalar? {
  match name.split("_").collect() {
    [kind_name, width_name] =>
      wgsl_ir_predeclared_scalar_from_parts(
        kind_name.to_owned(),
        width_name.to_owned(),
      )
    _ => None
  }
}

///|
fn wgsl_ir_predeclared_scalar_from_parts(
  kind_name : String,
  width_name : String,
) -> Scalar? {
  let kind = match kind_name {
    "Sint" => Some(ScalarKind::Sint)
    "Uint" => Some(Uint)
    "Float" => Some(Float)
    "Bool" => Some(Bool)
    "AbstractInt" => Some(AbstractInt)
    "AbstractFloat" => Some(AbstractFloat)
    _ => None
  }
  let width = match width_name {
    "1" => Some(1)
    "2" => Some(2)
    "4" => Some(4)
    "8" => Some(8)
    _ => None
  }
  match (kind, width) {
    (Some(kind), Some(width)) => Some(Scalar(kind, width))
    _ => None
  }
}

///|
fn WgslIrTypeSpelling::compose_constructor_name(
  self : WgslIrTypeSpelling,
  handle : Handle,
) -> String raise WgslIrTypeSpellingError {
  let ty = match self.shader_module.types.items.get(handle.index()) {
    Some(value) => value
    None => raise MissingType(handle.index())
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
pub fn WgslIrTypeSpelling::compose_constructor_name_for_components(
  self : WgslIrTypeSpelling,
  handle : Handle,
  components : Array[Handle],
  function : Function?,
) -> String raise WgslIrTypeSpellingError {
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
      None => raise MissingType(handle.index())
    }
  }
  self.compose_constructor_name(handle)
}

///|
pub fn WgslIrTypeSpelling::expression_is_scalar_type(
  self : WgslIrTypeSpelling,
  function : Function?,
  handle : Handle,
  scalar : Scalar,
) -> Bool {
  match self.type_inference().expression_type(function, handle) {
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
fn WgslIrTypeSpelling::scalar_matches_constructor_component(
  self : WgslIrTypeSpelling,
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
fn WgslIrTypeSpelling::type_inner_name(
  self : WgslIrTypeSpelling,
  inner : TypeInner,
) -> String raise WgslIrTypeSpellingError {
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
          if access == StorageAccess::load() &&
            self.elide_storage_pointer_read_access {
            "ptr<storage, \{self.type_name(base)}>"
          } else {
            "ptr<storage, \{self.type_name(base)}, \{self.storage_access_name(access)}>"
          }
        _ => "ptr<\{self.address_space_name(space)}, \{self.type_name(base)}>"
      }
    Array(base, size, _) =>
      match size {
        Constant(value) => "array<\{self.type_name(base)}, \{value}>"
        Dynamic => "array<\{self.type_name(base)}>"
        Pending(handle) =>
          "array<\{self.type_name(base)}, \{self.required_global_expression(handle)}>"
      }
    Struct(_, _) => raise UnsupportedTypeSpelling("anonymous struct type")
    PredeclaredStruct(_, _) =>
      raise UnsupportedTypeSpelling("anonymous predeclared struct type")
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
          "binding_array<\{self.type_name(base)}, \{self.required_global_expression(handle)}>"
      }
    _ => raise UnsupportedTypeSpelling("type kind")
  }
}

///|
fn WgslIrTypeSpelling::image_type_name(
  self : WgslIrTypeSpelling,
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
    Storage(format, access) => {
      let separator = self.storage_texture_type_argument_separator
      "texture_storage_\{self.image_dimension_suffix(dimension, arrayed)}<\{wgsl_ir_storage_format_name(format)}\{separator}\{self.storage_access_name(access)}>"
    }
  }
}

///|
fn WgslIrTypeSpelling::image_dimension_suffix(
  self : WgslIrTypeSpelling,
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
pub fn WgslIrTypeSpelling::scalar_name(
  self : WgslIrTypeSpelling,
  scalar : Scalar,
) -> String {
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
fn WgslIrTypeSpelling::scalar_kind_name(
  self : WgslIrTypeSpelling,
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
pub fn WgslIrTypeSpelling::address_space_template(
  self : WgslIrTypeSpelling,
  space : AddressSpace,
) -> String {
  match space {
    Private => "<private>"
    WorkGroup => "<workgroup>"
    Uniform => "<uniform>"
    Storage(access) =>
      if access == StorageAccess::load() {
        "<storage>"
      } else {
        "<storage, \{self.storage_access_name(access)}>"
      }
    Handle => ""
    Function => "<function>"
    Immediate => "<immediate>"
    TaskPayload => "<task_payload>"
    RayPayload => "<ray_payload>"
    IncomingRayPayload => "<incoming_ray_payload>"
  }
}

///|
fn WgslIrTypeSpelling::address_space_name(
  self : WgslIrTypeSpelling,
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
fn WgslIrTypeSpelling::storage_access_name(
  self : WgslIrTypeSpelling,
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
