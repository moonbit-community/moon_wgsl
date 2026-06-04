///|
priv suberror WgslIrLowerError {
  Parse(String)
  MissingType(String)
  UnsupportedType(String)
  UnsupportedExpression(String)
  UnsupportedStatement(String)
  UnknownIdentifier(String)
}

///|
fn WgslIrLowerError::message(self : WgslIrLowerError) -> String {
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
pub(all) enum WgslIrGeneratedImportProvenanceKind {
  ImportedSourceSymbol
  VirtualOverrideSymbol
} derive(Eq, Debug)

///|
pub(all) struct WgslIrGeneratedImportProvenance {
  generated_symbol_name : String
  rel_path : String
  source_symbol_name : String
  kind : WgslIrGeneratedImportProvenanceKind
  inline_value : Bool
  local_spelling : Bool
  root_local_spelling : Bool
  local_spelling_visible_rel_paths : Array[String]
  import_sequence : Int
  source_start : Int
  source_end : Int
} derive(Eq, Debug)

///|
pub fn WgslIrGeneratedImportProvenance::WgslIrGeneratedImportProvenance(
  generated_symbol_name : String,
  rel_path : String,
  source_symbol_name : String,
  kind : WgslIrGeneratedImportProvenanceKind,
  inline_value : Bool,
  local_spelling? : Bool = false,
  root_local_spelling? : Bool = false,
  local_spelling_visible_rel_paths? : Array[String] = [],
  import_sequence? : Int = -1,
  source_start? : Int = -1,
  source_end? : Int = -1,
) -> WgslIrGeneratedImportProvenance {
  {
    generated_symbol_name,
    rel_path,
    source_symbol_name,
    kind,
    inline_value,
    local_spelling,
    root_local_spelling,
    local_spelling_visible_rel_paths,
    import_sequence,
    source_start,
    source_end,
  }
}

///|
pub fn WgslIrGeneratedImportProvenance::generated_symbol_name(
  self : WgslIrGeneratedImportProvenance,
) -> String {
  self.generated_symbol_name
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
  generated_import_provenance : Map[String, WgslIrGeneratedImportProvenance]
  root_visible_rel_path : String
}

///|
fn WgslIrLowerer::WgslIrLowerer(
  root_visible_rel_path? : String = "",
) -> WgslIrLowerer {
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
    generated_import_provenance: Map([]),
    root_visible_rel_path,
  }
}

///|
fn wgsl_ir_parse_error_message(error : @parser.WgslParseError) -> String {
  error.message()
}

///|
fn parse_wgsl_module_to_ir(source : String) -> Module raise WgslIrLowerError {
  parse_wgsl_module_to_ir_with_generated_imports(source, [])
}

///|
fn parse_wgsl_module_to_ir_with_generated_imports(
  source : String,
  generated_import_provenance : Array[WgslIrGeneratedImportProvenance],
) -> Module raise WgslIrLowerError {
  parse_wgsl_module_to_ir_with_generated_imports_and_import_arena_events(
    source,
    generated_import_provenance,
    [],
  )
}

///|
fn parse_wgsl_module_to_ir_with_generated_imports_and_import_arena_events(
  source : String,
  generated_import_provenance : Array[WgslIrGeneratedImportProvenance],
  import_arena_events : Array[WgslIrImportArenaEvent],
  root_visible_rel_path? : String = "",
) -> Module raise WgslIrLowerError {
  let unit = @parser.parse_wgsl_translation_unit_strict(source) catch {
    error => raise Parse(wgsl_ir_parse_error_message(error))
  }
  lower_wgsl_translation_unit_to_ir_with_generated_imports(
    unit,
    generated_import_provenance,
    import_arena_events,
    root_visible_rel_path~,
  )
}

///|
fn lower_wgsl_translation_unit_to_ir_with_generated_imports(
  unit : @ast.WgslTranslationUnit,
  generated_import_provenance : Array[WgslIrGeneratedImportProvenance],
  import_arena_events : Array[WgslIrImportArenaEvent],
  root_visible_rel_path? : String = "",
) -> Module raise WgslIrLowerError {
  let lowerer = WgslIrLowerer(root_visible_rel_path~)
  for event in import_arena_events {
    lowerer.shader_module.import_arena_events.push(event)
  }
  for entry in generated_import_provenance {
    lowerer.generated_import_provenance.set(
      entry.generated_symbol_name(),
      entry,
    )
    lowerer.shader_module.generated_import_provenance.set(
      entry.generated_symbol_name(),
      entry,
    )
  }
  lowerer.register_prelude_types()
  for declaration in unit.declarations() {
    lowerer.record_referenced_names(declaration)
  }
  for declaration in unit.declarations() {
    lowerer.record_override_declaration(declaration)
  }
  for
    declaration in wgsl_ir_struct_predeclare_order(
      unit.declarations(),
      lowerer.generated_import_provenance,
    ) {
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
fn WgslIrLowerer::naga_oil_generated_import_local_spelling(
  self : WgslIrLowerer,
  source_name : String,
  visible_rel_path : String,
) -> String {
  let mut target : String? = None
  for entry in self.generated_import_provenance.iter() {
    let (_, provenance) = entry
    if provenance.kind != ImportedSourceSymbol ||
      !provenance.local_spelling ||
      provenance.source_symbol_name != source_name ||
      !provenance.local_spelling_visible_rel_paths.contains(visible_rel_path) {
      continue
    }
    match target {
      Some(existing) if existing != provenance.generated_symbol_name =>
        return source_name
      Some(_) => ()
      None => target = Some(provenance.generated_symbol_name)
    }
  }
  match target {
    Some(value) => value
    None => source_name
  }
}

///|
fn WgslIrLowerer::naga_oil_generated_import_root_local_spelling(
  self : WgslIrLowerer,
  source_name : String,
) -> String {
  let mut target : String? = None
  for entry in self.generated_import_provenance.iter() {
    let (_, provenance) = entry
    if provenance.kind != ImportedSourceSymbol ||
      !provenance.root_local_spelling ||
      provenance.source_symbol_name != source_name {
      continue
    }
    match target {
      Some(existing) if existing != provenance.generated_symbol_name =>
        return source_name
      Some(_) => ()
      None => target = Some(provenance.generated_symbol_name)
    }
  }
  match target {
    Some(value) => value
    None => source_name
  }
}

///|
fn WgslIrLowerer::naga_oil_generated_import_local_spelling_for_scope(
  self : WgslIrLowerer,
  source_name : String,
  scope : WgslIrFunctionScope,
) -> String {
  match scope.generated_import_local_spelling {
    AllGeneratedImportLocalSpelling =>
      self.naga_oil_generated_import_local_spelling(
        source_name,
        scope.visible_rel_path,
      )
    RootGeneratedImportLocalSpelling =>
      self.naga_oil_generated_import_root_local_spelling(source_name)
    NoGeneratedImportLocalSpelling => source_name
  }
}

///|
fn WgslIrLowerer::generated_import_function_rel_path(
  self : WgslIrLowerer,
  generated_name : String,
) -> String {
  match self.generated_import_provenance.get(generated_name) {
    Some(provenance) if provenance.kind == ImportedSourceSymbol =>
      provenance.rel_path
    _ => ""
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
