///|
pub suberror WgslIrLowerError {
  Parse(String)
  MissingType(String)
  UnsupportedType(String)
  UnsupportedExpression(String)
  UnsupportedStatement(String)
  UnknownIdentifier(String)
}

///|
pub fn WgslIrLowerError::message(self : WgslIrLowerError) -> String {
  match self {
    Parse(message) => message
    MissingType(name) => "missing WGSL type for \{name}"
    UnsupportedType(name) => "unsupported WGSL type: \{name}"
    UnsupportedExpression(message) => "unsupported WGSL expression: \{message}"
    UnsupportedStatement(message) => "unsupported WGSL statement: \{message}"
    UnknownIdentifier(name) => "unknown WGSL identifier in IR lowering: \{name}"
  }
}

///|
priv struct WgslIrLowerer {
  shader_module : Module
  type_cache : Map[String, Handle]
  function_names : Map[String, Handle]
  global_names : Map[String, Handle]
  constant_names : Map[String, Handle]
  constant_declarations : Map[String, @ast.WgslConst]
  constant_type_cache : Map[String, Handle]
  constant_type_inference_stack : @set.Set[String]
  constant_lowering_stack : @set.Set[String]
  lowered_constants : @set.Set[String]
  override_names : Map[String, Handle]
  override_declarations : Map[String, @ast.WgslOverride]
  override_type_inference_stack : @set.Set[String]
  referenced_names : @set.Set[String]
}

///|
fn WgslIrLowerer::WgslIrLowerer() -> WgslIrLowerer {
  {
    shader_module: Module(),
    type_cache: Map([]),
    function_names: Map([]),
    global_names: Map([]),
    constant_names: Map([]),
    constant_declarations: Map([]),
    constant_type_cache: Map([]),
    constant_type_inference_stack: Set([]),
    constant_lowering_stack: Set([]),
    lowered_constants: Set([]),
    override_names: Map([]),
    override_declarations: Map([]),
    override_type_inference_stack: Set([]),
    referenced_names: Set([]),
  }
}

///|
fn wgsl_ir_parse_error_message(error : @parser.WgslParseError) -> String {
  error.message()
}

///|
fn validate_wgsl_module_namespace(
  unit : @ast.WgslTranslationUnit,
) -> Unit raise WgslIrLowerError {
  let names : @set.Set[String] = Set([])
  for declaration in unit.declarations() {
    match declaration.data() {
      Struct(struct_decl) =>
        validate_wgsl_unique_struct_member_names(struct_decl)
      Function(function) =>
        validate_wgsl_unique_function_argument_names(function)
      _ => ()
    }
    let name = declaration.name()
    if name == "" {
      continue
    }
    if names.contains(name) {
      raise Parse("redefinition of `\{name}`")
    }
    names.add(name)
  }
}

///|
fn validate_wgsl_unique_struct_member_names(
  struct_decl : @ast.WgslStruct,
) -> Unit raise WgslIrLowerError {
  let names : @set.Set[String] = Set([])
  for field in struct_decl.members() {
    let name = field.name().name()
    if names.contains(name) {
      raise Parse("redefinition of `\{name}`")
    }
    names.add(name)
  }
}

///|
fn validate_wgsl_unique_function_argument_names(
  function : @ast.WgslFunction,
) -> Unit raise WgslIrLowerError {
  let names : @set.Set[String] = Set([])
  for argument in function.arguments() {
    let name = argument.name().name()
    if name == "_" {
      continue
    }
    if names.contains(name) {
      raise Parse("redefinition of `\{name}`")
    }
    names.add(name)
  }
}

///|
pub fn parse_wgsl_module_to_ir(
  source : String,
) -> Module raise WgslIrLowerError {
  let unit = @parser.parse_wgsl_translation_unit_strict(source) catch {
    error => raise Parse(wgsl_ir_parse_error_message(error))
  }
  validate_wgsl_module_namespace(unit)
  lower_wgsl_translation_unit_to_ir(unit)
}

///|
fn lower_wgsl_translation_unit_to_ir(
  unit : @ast.WgslTranslationUnit,
) -> Module raise WgslIrLowerError {
  let lowerer = WgslIrLowerer()
  lowerer.register_prelude_types()
  for declaration in unit.declarations() {
    lowerer.record_referenced_names(declaration)
  }
  for declaration in unit.declarations() {
    lowerer.record_override_declaration(declaration)
  }
  for declaration in wgsl_ir_struct_predeclare_order(unit.declarations()) {
    lowerer.predeclare_global_type_declaration(declaration)
  }
  for declaration in unit.declarations() {
    lowerer.predeclare_global_type_alias(declaration)
  }
  for declaration in unit.declarations() {
    lowerer.lower_global_type_body_declaration(declaration)
  }
  lowerer.refresh_dependent_type_layouts()
  for declaration in unit.declarations() {
    lowerer.predeclare_global_value_declaration(declaration)
  }
  for declaration in unit.declarations() {
    lowerer.lower_global_declaration(declaration)
  }
  lowerer.resolve_ambient_global_function_parameters()
  lowerer.shader_module
}

///|
fn WgslIrLowerer::record_override_declaration(
  self : WgslIrLowerer,
  declaration : @ast.WgslGlobalDecl,
) -> Unit {
  match declaration.data() {
    Const(constant) =>
      self.constant_declarations.set(constant.name().name(), constant)
    Override(override_decl) =>
      self.override_declarations.set(override_decl.name().name(), override_decl)
    _ => ()
  }
}

///|
fn WgslIrLowerer::record_referenced_names(
  self : WgslIrLowerer,
  declaration : @ast.WgslGlobalDecl,
) -> Unit {
  let identifiers : Array[@ast.WgslIdent] = []
  @ast_analysis.collect_wgsl_decl_identifier_nodes(
    declaration.data(),
    identifiers,
  )
  for identifier in identifiers {
    self.referenced_names.add(identifier.name())
  }
}

///|
fn WgslIrLowerer::register_prelude_types(self : WgslIrLowerer) -> Unit {
  let bool_ty = self.intern_type("bool", Scalar(Scalar(Bool, 1)))
  ignore(self.intern_type("vec2<bool>", Vector(Bi, Scalar(Bool, 1))))
  ignore(self.intern_type("vec3<bool>", Vector(Tri, Scalar(Bool, 1))))
  ignore(self.intern_type("vec4<bool>", Vector(Quad, Scalar(Bool, 1))))
  ignore(self.intern_type("i32", Scalar(Scalar(Sint, 4))))
  ignore(self.intern_type("i64", Scalar(Scalar(Sint, 8))))
  let u32_ty = self.intern_type("u32", Scalar(Scalar(Uint, 4)))
  ignore(self.intern_type("u64", Scalar(Scalar(Uint, 8))))
  let f32_ty = self.intern_type("f32", Scalar(Scalar(Float, 4)))
  ignore(self.intern_type("f16", Scalar(Scalar(Float, 2))))
  let vec2_f32_ty = self.intern_type("vec2<f32>", Vector(Bi, Scalar(Float, 4)))
  let vec3_f32_ty = self.intern_type("vec3<f32>", Vector(Tri, Scalar(Float, 4)))
  self.shader_module.special_types.ray_vertex_return = Some(
    self.intern_type("array<vec3<f32>, 3>", Array(vec3_f32_ty, Constant(3), 16)),
  )
  let mat4x3_f32_ty = self.intern_type(
    "mat4x3<f32>",
    Matrix(Quad, Tri, Scalar(Float, 4)),
  )
  ignore(
    self.intern_type(
      "RayDesc",
      PredeclaredStruct(
        [
          wgsl_ir_synthetic_struct_member("flags", u32_ty),
          wgsl_ir_synthetic_struct_member("cull_mask", u32_ty),
          wgsl_ir_synthetic_struct_member("t_min", f32_ty),
          wgsl_ir_synthetic_struct_member("t_max", f32_ty),
          wgsl_ir_synthetic_struct_member("origin", vec3_f32_ty),
          wgsl_ir_synthetic_struct_member("direction", vec3_f32_ty),
        ],
        48,
      ),
    ),
  )
  ignore(
    self.intern_type(
      "RayIntersection",
      PredeclaredStruct(
        [
          wgsl_ir_synthetic_struct_member("kind", u32_ty),
          wgsl_ir_synthetic_struct_member("t", f32_ty),
          wgsl_ir_synthetic_struct_member("instance_custom_data", u32_ty),
          wgsl_ir_synthetic_struct_member("instance_index", u32_ty),
          wgsl_ir_synthetic_struct_member("sbt_record_offset", u32_ty),
          wgsl_ir_synthetic_struct_member("geometry_index", u32_ty),
          wgsl_ir_synthetic_struct_member("primitive_index", u32_ty),
          wgsl_ir_synthetic_struct_member("barycentrics", vec2_f32_ty),
          wgsl_ir_synthetic_struct_member("front_face", bool_ty),
          wgsl_ir_synthetic_struct_member("object_to_world", mat4x3_f32_ty),
          wgsl_ir_synthetic_struct_member("world_to_object", mat4x3_f32_ty),
        ],
        176,
      ),
    ),
  )
  ignore(self.intern_type("__abstract_int", Scalar(Scalar(AbstractInt, 8))))
  ignore(self.intern_type("__abstract_float", Scalar(Scalar(AbstractFloat, 8))))
}

///|
fn wgsl_ir_synthetic_struct_member(name : String, ty : Handle) -> StructMember {
  { name: Some(name), ty, binding: None, offset: 0, size: None, align: None }
}

///|
fn WgslIrLowerer::intern_type(
  self : WgslIrLowerer,
  key : String,
  inner : TypeInner,
) -> Handle {
  match self.type_cache.get(key) {
    Some(handle) => handle
    None => {
      self.ensure_type_dependencies(inner)
      let handle = self.shader_module.append_type({ name: Some(key), inner })
      self.type_cache.set(key, handle)
      handle
    }
  }
}

///|
fn WgslIrLowerer::ensure_type_dependencies(
  self : WgslIrLowerer,
  inner : TypeInner,
) -> Unit {
  match inner {
    Vector(_, scalar) => ignore(self.scalar_type_handle(scalar))
    Matrix(_, rows, scalar) => ignore(self.vector_type_handle(rows, scalar))
    CooperativeMatrix(_, _, scalar, _) =>
      ignore(self.scalar_type_handle(scalar))
    Pointer(base, _) => self.require_type_dependency(base)
    Atomic(scalar) => ignore(self.scalar_type_handle(scalar))
    Array(element, _, _) | BindingArray(element, _) =>
      self.require_type_dependency(element)
    Struct(members, _) | PredeclaredStruct(members, _) =>
      for field in members {
        self.require_type_dependency(field.ty)
      }
    _ => ()
  }
}

///|
fn WgslIrLowerer::require_type_dependency(
  self : WgslIrLowerer,
  handle : Handle,
) -> Unit {
  if handle.index() < 0 ||
    handle.index() >= self.shader_module.types.items.length() {
    abort("internal IR type dependency is not interned")
  }
}
