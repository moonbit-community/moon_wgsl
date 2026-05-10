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
} derive(Eq, Debug)

///|
pub fn WgslIrGeneratedImportProvenance::WgslIrGeneratedImportProvenance(
  generated_symbol_name : String,
  rel_path : String,
  source_symbol_name : String,
  kind : WgslIrGeneratedImportProvenanceKind,
  inline_value : Bool,
) -> WgslIrGeneratedImportProvenance {
  WgslIrGeneratedImportProvenance::{
    generated_symbol_name,
    rel_path,
    source_symbol_name,
    kind,
    inline_value,
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
  type_cache : @hashmap.HashMap[String, Handle]
  function_names : @hashmap.HashMap[String, Handle]
  global_names : @hashmap.HashMap[String, Handle]
  constant_names : @hashmap.HashMap[String, Handle]
  constant_declarations : @hashmap.HashMap[String, @ast.WgslConst]
  constant_type_cache : @hashmap.HashMap[String, Handle]
  constant_type_inference_stack : @hashset.HashSet[String]
  constant_lowering_stack : @hashset.HashSet[String]
  override_names : @hashmap.HashMap[String, Handle]
  override_declarations : @hashmap.HashMap[String, @ast.WgslOverride]
  override_type_inference_stack : @hashset.HashSet[String]
  referenced_names : @hashset.HashSet[String]
  generated_import_provenance : @hashmap.HashMap[
    String,
    WgslIrGeneratedImportProvenance,
  ]
}

///|
fn WgslIrLowerer::WgslIrLowerer() -> WgslIrLowerer {
  WgslIrLowerer::{
    shader_module: Module(),
    type_cache: @hashmap.HashMap([]),
    function_names: @hashmap.HashMap([]),
    global_names: @hashmap.HashMap([]),
    constant_names: @hashmap.HashMap([]),
    constant_declarations: @hashmap.HashMap([]),
    constant_type_cache: @hashmap.HashMap([]),
    constant_type_inference_stack: @hashset.HashSet([]),
    constant_lowering_stack: @hashset.HashSet([]),
    override_names: @hashmap.HashMap([]),
    override_declarations: @hashmap.HashMap([]),
    override_type_inference_stack: @hashset.HashSet([]),
    referenced_names: @hashset.HashSet([]),
    generated_import_provenance: @hashmap.HashMap([]),
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
  let unit = @parser.parse_wgsl_translation_unit_strict(source) catch {
    error => raise WgslIrLowerError::Parse(wgsl_ir_parse_error_message(error))
  }
  lower_wgsl_translation_unit_to_ir_with_generated_imports(
    unit, generated_import_provenance,
  )
}

///|
fn lower_wgsl_translation_unit_to_ir_with_generated_imports(
  unit : @ast.WgslTranslationUnit,
  generated_import_provenance : Array[WgslIrGeneratedImportProvenance],
) -> Module raise WgslIrLowerError {
  let lowerer = WgslIrLowerer()
  for entry in generated_import_provenance {
    lowerer.generated_import_provenance.set(
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
  for declaration in unit.declarations() {
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
  let bool_ty = self.intern_type(
    "bool",
    TypeInner::Scalar(Scalar::Scalar(Bool, 1)),
  )
  ignore(
    self.intern_type(
      "vec2<bool>",
      TypeInner::Vector(Bi, Scalar::Scalar(Bool, 1)),
    ),
  )
  ignore(
    self.intern_type(
      "vec3<bool>",
      TypeInner::Vector(Tri, Scalar::Scalar(Bool, 1)),
    ),
  )
  ignore(
    self.intern_type(
      "vec4<bool>",
      TypeInner::Vector(Quad, Scalar::Scalar(Bool, 1)),
    ),
  )
  ignore(self.intern_type("i32", TypeInner::Scalar(Scalar::Scalar(Sint, 4))))
  ignore(self.intern_type("i64", TypeInner::Scalar(Scalar::Scalar(Sint, 8))))
  let u32_ty = self.intern_type(
    "u32",
    TypeInner::Scalar(Scalar::Scalar(Uint, 4)),
  )
  ignore(self.intern_type("u64", TypeInner::Scalar(Scalar::Scalar(Uint, 8))))
  let f32_ty = self.intern_type(
    "f32",
    TypeInner::Scalar(Scalar::Scalar(Float, 4)),
  )
  ignore(self.intern_type("f16", TypeInner::Scalar(Scalar::Scalar(Float, 2))))
  let vec2_f32_ty = self.intern_type(
    "vec2<f32>",
    TypeInner::Vector(Bi, Scalar::Scalar(Float, 4)),
  )
  let vec3_f32_ty = self.intern_type(
    "vec3<f32>",
    TypeInner::Vector(Tri, Scalar::Scalar(Float, 4)),
  )
  self.shader_module.special_types.ray_vertex_return = Some(
    self.intern_type(
      "array<vec3<f32>, 3>",
      TypeInner::Array(vec3_f32_ty, ArraySize::Constant(3), 16),
    ),
  )
  let mat4x3_f32_ty = self.intern_type(
    "mat4x3<f32>",
    TypeInner::Matrix(Quad, Tri, Scalar::Scalar(Float, 4)),
  )
  ignore(
    self.intern_type(
      "RayDesc",
      TypeInner::PredeclaredStruct(
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
      TypeInner::PredeclaredStruct(
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
  ignore(
    self.intern_type(
      "__abstract_int",
      TypeInner::Scalar(Scalar::Scalar(AbstractInt, 8)),
    ),
  )
  ignore(
    self.intern_type(
      "__abstract_float",
      TypeInner::Scalar(Scalar::Scalar(AbstractFloat, 8)),
    ),
  )
}

///|
fn wgsl_ir_synthetic_struct_member(name : String, ty : Handle) -> StructMember {
  StructMember::{
    name: Some(name),
    ty,
    binding: None,
    offset: 0,
    size: None,
    align: None,
  }
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
      let handle = self.shader_module.append_type(Type::{
        name: Some(key),
        inner,
      })
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
  let handle = self.shader_module.append_type(Type::{
    name: Some(struct_decl.name().name()),
    inner: TypeInner::Struct([], 1),
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
    generated_import: self.function_has_generated_import_provenance(
      function.name().name(),
    ),
    arguments: [],
    result,
    local_variables: LocalVariableArena(),
    expressions: ExpressionArena(),
    named_expressions: [],
    body: Block::Block(),
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
  let handle = self.shader_module.append_global_variable(GlobalVariable::{
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
fn WgslIrLowerer::function_has_generated_import_provenance(
  self : WgslIrLowerer,
  name : String,
) -> Bool {
  self.generated_import_provenance.get(name) != None
}

///|
fn WgslIrLowerer::constant_should_inline_generated_import_value(
  self : WgslIrLowerer,
  name : String,
) -> Bool {
  match self.generated_import_provenance.get(name) {
    Some(provenance) => provenance.inline_value
    None => false
  }
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
    raise WgslIrLowerError::MissingType(name)
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
  let handle = self.shader_module.append_override(Override::{
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
    _ => ()
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
    raise WgslIrLowerError::MissingType(alias_decl.name().name())
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
      raise WgslIrLowerError::MissingType(struct_member.name().name())
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
    members.push(StructMember::{
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
    inner: TypeInner::Struct(members, span),
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
  if self.constant_names.contains(name) {
    return
  }
  if self.constant_lowering_stack.contains(name) {
    raise WgslIrLowerError::MissingType(name)
  }
  self.constant_lowering_stack.add(name)
  let explicit_ty = match constant.ty_ref() {
    Some(ty_ref) => Some(self.lower_type_ref(ty_ref))
    None => None
  }
  let ty = match explicit_ty {
    Some(ty) => ty
    None =>
      self.infer_local_type_from_initializer(name, constant.initializer_ref())
  }
  let init = match constant.initializer_ref() {
    Some(expr) =>
      self.lower_global_expression_ref_with_expected(expr, explicit_ty)
    None =>
      self.shader_module.append_global_expression(Expression::ZeroValue(ty))
  }
  let handle = self.shader_module.append_constant(Constant::{
    name: Some(name),
    generated_import: self.function_has_generated_import_provenance(name),
    inline_value: self.constant_should_inline_generated_import_value(name),
    ty,
    init,
  })
  self.constant_names.set(name, handle)
  ignore(self.constant_lowering_stack.remove(name))
}

///|
fn WgslIrLowerer::ensure_constant_declaration_lowered(
  self : WgslIrLowerer,
  name : String,
) -> Handle? raise WgslIrLowerError {
  match self.constant_names.get(name) {
    Some(handle) => Some(handle)
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

///|
fn WgslIrLowerer::lower_function_declaration(
  self : WgslIrLowerer,
  function : @ast.WgslFunction,
) -> Unit raise WgslIrLowerError {
  let stage = wgsl_ir_shader_stage_from_attributes(function.attributes())
  let referenced_stage_function = match stage {
    Some(_) => self.referenced_names.contains(function.name().name())
    None => false
  }
  let ir_function = if referenced_stage_function {
    wgsl_ir_strip_function_io_bindings(self.lower_function(function))
  } else {
    self.lower_function(function)
  }
  match self.function_names.get(function.name().name()) {
    Some(handle) => self.shader_module.set_function(handle, ir_function)
    None => {
      let handle = self.shader_module.append_function(ir_function)
      self.function_names.set(function.name().name(), handle)
    }
  }
  match stage {
    Some(stage) =>
      if !self.referenced_names.contains(function.name().name()) &&
        !self.entry_point_name_is_lowered(function.name().name()) {
        let (workgroup_size, workgroup_size_overrides) = self.workgroup_size_from_attributes(
          function.attributes(),
        )
        self.shader_module.append_entry_point(EntryPoint::{
          name: function.name().name(),
          stage,
          early_depth_test: wgsl_ir_early_depth_test_from_attributes(
            function.attributes(),
          ),
          workgroup_size,
          workgroup_size_overrides,
          function: ir_function,
          mesh_info: self.mesh_stage_info_from_attributes(
            stage,
            function.attributes(),
          ),
          task_payload: self.payload_variable_from_attributes(
            function.attributes(),
          ),
          incoming_ray_payload: None,
        })
      }
    None => ()
  }
}

///|
fn WgslIrLowerer::entry_point_name_is_lowered(
  self : WgslIrLowerer,
  name : String,
) -> Bool {
  for entry_point in self.shader_module.entry_points {
    if entry_point.name == name {
      return true
    }
  }
  false
}

///|
fn wgsl_ir_strip_function_io_bindings(function : Function) -> Function {
  let arguments : Array[FunctionArgument] = []
  for argument in function.arguments {
    arguments.push(FunctionArgument::{
      name: argument.name,
      ty: argument.ty,
      binding: None,
    })
  }
  let result = match function.result {
    Some(value) => Some(FunctionResult::{ ty: value.ty, binding: None })
    None => None
  }
  Function::{
    name: function.name,
    generated_import: function.generated_import,
    arguments,
    result,
    local_variables: function.local_variables,
    expressions: function.expressions,
    named_expressions: function.named_expressions,
    body: function.body,
    diagnostic_filter_leaf: function.diagnostic_filter_leaf,
  }
}

///|
fn WgslIrLowerer::resolve_ambient_global_function_parameters(
  self : WgslIrLowerer,
) -> Unit {
  for index in 0..<self.shader_module.functions.items.length() {
    let handle = Handle::Handle(index)
    guard self.function_is_called_only_without_arguments(handle) else {
      continue
    }
    guard self.shader_module.functions.items.get(index) is Some(function) else {
      continue
    }
    match self.ambient_global_arguments_for_function(function) {
      Some(global_handles) => {
        let rewritten = self.function_without_ambient_global_arguments(
          function, global_handles,
        )
        self.shader_module.set_function(handle, rewritten)
      }
      None => ()
    }
  }
}

///|
fn WgslIrLowerer::function_is_called_only_without_arguments(
  self : WgslIrLowerer,
  target : Handle,
) -> Bool {
  let mut has_call = false
  let mut has_non_empty_call = false
  for function in self.shader_module.functions.items {
    let (function_has_call, function_has_non_empty_call) = self.function_call_argument_shape(
      function, target,
    )
    has_call = has_call || function_has_call
    has_non_empty_call = has_non_empty_call || function_has_non_empty_call
  }
  for entry_point in self.shader_module.entry_points {
    let (function_has_call, function_has_non_empty_call) = self.function_call_argument_shape(
      entry_point.function,
      target,
    )
    has_call = has_call || function_has_call
    has_non_empty_call = has_non_empty_call || function_has_non_empty_call
  }
  has_call && !has_non_empty_call
}

///|
fn WgslIrLowerer::function_call_argument_shape(
  self : WgslIrLowerer,
  function : Function,
  target : Handle,
) -> (Bool, Bool) {
  ignore(self)
  let mut has_call = false
  let mut has_non_empty_call = false
  for expression in function.expressions.items {
    match expression {
      FunctionCall(handle, arguments) =>
        if handle == target {
          has_call = true
          if !arguments.is_empty() {
            has_non_empty_call = true
          }
        }
      _ => ()
    }
  }
  (has_call, has_non_empty_call)
}

///|
fn WgslIrLowerer::ambient_global_arguments_for_function(
  self : WgslIrLowerer,
  function : Function,
) -> Array[Handle]? {
  if function.arguments.is_empty() {
    return None
  }
  let globals : Array[Handle] = []
  for argument in function.arguments {
    guard argument.binding == None else { return None }
    guard argument.name is Some(name) else { return None }
    guard self.global_names.get(name) is Some(global_handle) else {
      return None
    }
    guard self.shader_module.global_variables.items.get(global_handle.index())
      is Some(global) else {
      return None
    }
    guard global.ty == argument.ty else { return None }
    globals.push(global_handle)
  }
  Some(globals)
}

///|
fn WgslIrLowerer::function_without_ambient_global_arguments(
  self : WgslIrLowerer,
  function : Function,
  global_handles : Array[Handle],
) -> Function {
  let expressions = ExpressionArena()
  for expression in function.expressions.items {
    expressions.items.push(
      self.rewrite_ambient_global_function_expression(
        expression, global_handles,
      ),
    )
  }
  Function::{
    name: function.name,
    generated_import: function.generated_import,
    arguments: [],
    result: function.result,
    local_variables: function.local_variables,
    expressions,
    named_expressions: function.named_expressions,
    body: function.body,
    diagnostic_filter_leaf: function.diagnostic_filter_leaf,
  }
}

///|
fn WgslIrLowerer::rewrite_ambient_global_function_expression(
  self : WgslIrLowerer,
  expression : Expression,
  global_handles : Array[Handle],
) -> Expression {
  ignore(self)
  match expression {
    FunctionArgument(index) =>
      match global_handles.get(index) {
        Some(global_handle) => GlobalVariable(global_handle)
        None => FunctionArgument(index)
      }
    _ => expression
  }
}

///|
fn WgslIrLowerer::lower_function(
  self : WgslIrLowerer,
  function : @ast.WgslFunction,
) -> Function raise WgslIrLowerError {
  let ir_function = Function::{
    name: Some(function.name().name()),
    generated_import: self.function_has_generated_import_provenance(
      function.name().name(),
    ),
    arguments: [],
    result: None,
    local_variables: LocalVariableArena(),
    expressions: ExpressionArena(),
    named_expressions: [],
    body: Block::Block(),
    diagnostic_filter_leaf: None,
  }
  let scope = WgslIrFunctionScope()
  let mut index = 0
  for argument in function.arguments() {
    guard argument.ty_ref() is Some(ty_ref) else {
      raise WgslIrLowerError::MissingType(argument.name().name())
    }
    ir_function.arguments.push(FunctionArgument::{
      name: Some(argument.name().name()),
      ty: self.lower_type_ref(ty_ref),
      binding: wgsl_ir_binding_from_attributes(argument.attributes()),
    })
    scope.arguments.set(argument.name().name(), index)
    index = index + 1
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
  let body = self.lower_block(function.body(), ir_function, scope) catch {
    error =>
      match error {
        UnknownIdentifier(name) =>
          raise WgslIrLowerError::UnknownIdentifier(
            "\{name} in function \{function.name().name()} with args \{wgsl_ir_function_argument_names(function)}",
          )
        UnsupportedExpression(message) =>
          raise WgslIrLowerError::UnsupportedExpression(
            "\{message} in function \{function.name().name()}",
          )
        UnsupportedStatement(message) =>
          raise WgslIrLowerError::UnsupportedStatement(
            "\{message} in function \{function.name().name()}",
          )
        _ => raise error
      }
  }
  if result == None && !wgsl_ir_block_ends_with_return(body) {
    body.push(Statement::Return(None))
  }
  Function::{
    name: ir_function.name,
    generated_import: ir_function.generated_import,
    arguments: ir_function.arguments,
    result,
    local_variables: ir_function.local_variables,
    expressions: ir_function.expressions,
    named_expressions: ir_function.named_expressions,
    body,
    diagnostic_filter_leaf: ir_function.diagnostic_filter_leaf,
  }
}

///|
fn wgsl_ir_function_argument_names(function : @ast.WgslFunction) -> String {
  let names : Array[String] = []
  for argument in function.arguments() {
    names.push(argument.name().name())
  }
  names.join(",")
}

///|
fn WgslIrLowerer::address_of_expression_type(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle,
) -> Handle? {
  ignore(self)
  match function.expressions.items.get(handle.index()) {
    Some(Expression::AddressOf(ty, _)) => Some(ty)
    _ => None
  }
}

///|
fn wgsl_ir_address_of_operand_ref(
  expr_ref : @ast.WgslExprRef,
) -> @ast.WgslExprNode? {
  match expr_ref.root() {
    Some(root) => wgsl_ir_address_of_operand_node(root)
    None => None
  }
}

///|
fn wgsl_ir_address_of_operand_node(
  node : @ast.WgslExprNode,
) -> @ast.WgslExprNode? {
  match node.kind() {
    Group(inner) => wgsl_ir_address_of_operand_node(inner)
    Unary(op, expr) =>
      if op == @ast.WgslExprOperator::BitAnd {
        Some(expr)
      } else {
        None
      }
    _ => None
  }
}

///|
fn wgsl_ir_local_variable_kind(
  kind : @ast.WgslLocalDeclarationKind,
) -> LocalVariableKind {
  match kind {
    Var => LocalVariableKind::Var
    Let => LocalVariableKind::Let
    Const => abort("local const declarations are not local variables")
  }
}

///|
fn WgslIrLowerer::lower_call_statement(
  self : WgslIrLowerer,
  expr_ref : @ast.WgslExprRef,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
) -> Unit raise WgslIrLowerError {
  guard expr_ref.root() is Some(root) else {
    raise WgslIrLowerError::UnsupportedExpression("empty function call")
  }
  match wgsl_ir_expr_call_node(root).kind() {
    Call(callee, arguments) => {
      let arguments = wgsl_ir_call_arguments(arguments)
      match callee.kind() {
        Identifier(name) =>
          match wgsl_ir_barrier_statement_from_call(name.name(), arguments) {
            Some(statement) => block.push(statement)
            None =>
              match wgsl_ir_atomic_function_from_name(name.name()) {
                Some(atomic_function) => {
                  let handle = self.lower_function_atomic_call(
                    atomic_function, arguments, function, scope,
                  )
                  block.push(Statement::Emit(HandleRange(handle, handle)))
                }
                None =>
                  match self.function_names.get(name.name()) {
                    Some(handle) => {
                      let values = self.lower_user_function_call_arguments(
                        handle, arguments, function, scope,
                      )
                      block.push(Statement::Call(handle, values, None))
                    }
                    None =>
                      if !self.lower_ray_query_statement_call(
                          name.name(),
                          arguments,
                          function,
                          scope,
                          block,
                        ) &&
                        !self.lower_texture_statement_call(
                          name.name(),
                          arguments,
                          function,
                          scope,
                          block,
                        ) &&
                        !self.lower_cooperative_statement_call(
                          name.name(),
                          arguments,
                          function,
                          scope,
                          block,
                        ) {
                        ignore(
                          self.lower_function_expression_node(
                            root, function, scope,
                          ),
                        )
                      }
                  }
              }
          }
        _ => ignore(self.lower_function_expression_node(root, function, scope))
      }
    }
    _ => ignore(self.lower_function_expression_node(root, function, scope))
  }
}

///|
priv enum WgslIrBarrierBuiltin {
  BarrierControl(Barrier)
  BarrierMemory(Barrier)
}

///|
fn wgsl_ir_barrier_builtin_from_name(name : String) -> WgslIrBarrierBuiltin? {
  match name {
    "workgroupBarrier" => Some(BarrierControl(Barrier::work_group()))
    "storageBarrier" => Some(BarrierMemory(Barrier::storage()))
    "textureBarrier" => Some(BarrierMemory(Barrier::texture()))
    "subgroupBarrier" => Some(BarrierControl(Barrier::sub_group()))
    _ => None
  }
}

///|
fn wgsl_ir_barrier_statement_from_call(
  name : String,
  arguments : Array[@ast.WgslExprNode],
) -> Statement? raise WgslIrLowerError {
  match wgsl_ir_barrier_builtin_from_name(name) {
    Some(barrier) => {
      guard arguments.length() == 0 else {
        raise WgslIrLowerError::UnsupportedExpression(
          "\{name} expects no arguments",
        )
      }
      match barrier {
        BarrierControl(barrier) => Some(Statement::ControlBarrier(barrier))
        BarrierMemory(barrier) => Some(Statement::MemoryBarrier(barrier))
      }
    }
    None => None
  }
}

///|
fn wgsl_ir_barrier_value_error(name : String) -> WgslIrLowerError {
  WgslIrLowerError::UnsupportedExpression(
    "barrier builtin has no value: \{name}",
  )
}

///|
fn WgslIrLowerer::lower_user_function_call_arguments(
  self : WgslIrLowerer,
  callee : Handle,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Array[Handle] raise WgslIrLowerError {
  let flattened = wgsl_ir_flatten_expression_arguments(arguments)
  let handles : Array[Handle] = []
  let callee_function = match
    self.shader_module.functions.items.get(callee.index()) {
    Some(value) => value
    None =>
      raise WgslIrLowerError::UnsupportedExpression(
        "invalid function call target",
      )
  }
  for index in 0..<flattened.length() {
    let expected_ty = match callee_function.arguments.get(index) {
      Some(argument) => Some(argument.ty)
      None => None
    }
    handles.push(
      self.lower_function_expression_node_with_expected(
        flattened[index],
        function,
        scope,
        expected_ty,
      ),
    )
  }
  handles
}

///|
fn wgsl_ir_expr_call_node(node : @ast.WgslExprNode) -> @ast.WgslExprNode {
  match node.kind() {
    Group(inner) => wgsl_ir_expr_call_node(inner)
    Sequence([single]) => wgsl_ir_expr_call_node(single)
    _ => node
  }
}

///|
fn wgsl_ir_call_arguments(
  arguments : Array[@ast.WgslExprNode],
) -> Array[@ast.WgslExprNode] {
  wgsl_ir_flatten_expression_arguments(arguments)
}

///|
fn WgslIrLowerer::lower_ray_query_statement_call(
  self : WgslIrLowerer,
  name : String,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
) -> Bool raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  match name {
    "rayQueryInitialize" => {
      guard arguments is [query, acceleration, ray_desc] else { return false }
      let query_handle = self.lower_function_expression_node(
        query, function, scope,
      )
      let acceleration_handle = self.lower_function_expression_node(
        acceleration, function, scope,
      )
      let ray_desc_handle = self.lower_function_expression_node(
        ray_desc, function, scope,
      )
      block.push(
        Statement::RayQuery(
          query_handle,
          RayQueryFunction::Initialize(acceleration_handle, ray_desc_handle),
        ),
      )
      true
    }
    "rayQueryProceed" => {
      guard arguments is [query] else { return false }
      let query_handle = self.lower_function_expression_node(
        query, function, scope,
      )
      block.push(
        Statement::RayQuery(
          query_handle,
          RayQueryFunction::Proceed(query_handle),
        ),
      )
      true
    }
    "rayQueryGenerateIntersection" => {
      guard arguments is [query, intersection_t] else { return false }
      let query_handle = self.lower_function_expression_node(
        query, function, scope,
      )
      let t_handle = self.lower_function_expression_node(
        intersection_t, function, scope,
      )
      block.push(
        Statement::RayQuery(
          query_handle,
          RayQueryFunction::GenerateIntersection(t_handle),
        ),
      )
      true
    }
    "rayQueryConfirmIntersection" => {
      guard arguments is [query] else { return false }
      let query_handle = self.lower_function_expression_node(
        query, function, scope,
      )
      block.push(
        Statement::RayQuery(query_handle, RayQueryFunction::ConfirmIntersection),
      )
      true
    }
    "rayQueryTerminate" => {
      guard arguments is [query] else { return false }
      let query_handle = self.lower_function_expression_node(
        query, function, scope,
      )
      block.push(Statement::RayQuery(query_handle, RayQueryFunction::Terminate))
      true
    }
    _ => false
  }
}

///|
fn WgslIrLowerer::lower_texture_statement_call(
  self : WgslIrLowerer,
  name : String,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
) -> Bool raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  match name {
    "textureAtomicAdd"
    | "textureAtomicAnd"
    | "textureAtomicMax"
    | "textureAtomicMin"
    | "textureAtomicOr"
    | "textureAtomicXor" => {
      let atomic_function = match
        wgsl_ir_texture_atomic_function_from_name(name) {
        Some(function) => function
        None => abort("unreachable texture atomic builtin")
      }
      self.lower_texture_atomic_statement(
        name, atomic_function, arguments, function, scope, block,
      )
      true
    }
    "textureStore" => {
      guard arguments.length() == 3 || arguments.length() == 4 else {
        raise WgslIrLowerError::UnsupportedExpression(
          "textureStore expects 3 or 4 arguments",
        )
      }
      let image = self.lower_function_expression_node(
        arguments[0],
        function,
        scope,
      )
      let coordinate = self.lower_function_expression_node(
        arguments[1],
        function,
        scope,
      )
      let (array_index, value_index) = if arguments.length() == 4 {
        (
          Some(
            self.lower_function_expression_node(arguments[2], function, scope),
          ),
          3,
        )
      } else {
        (None, 2)
      }
      let value = self.lower_function_expression_node(
        arguments[value_index],
        function,
        scope,
      )
      block.push(Statement::ImageStore(image, coordinate, array_index, value))
      true
    }
    _ => false
  }
}

///|
fn wgsl_ir_texture_atomic_function_from_name(name : String) -> AtomicFunction? {
  match name {
    "textureAtomicAdd" => Some(Add)
    "textureAtomicAnd" => Some(And)
    "textureAtomicMax" => Some(Max)
    "textureAtomicMin" => Some(Min)
    "textureAtomicOr" => Some(InclusiveOr)
    "textureAtomicXor" => Some(ExclusiveOr)
    _ => None
  }
}

///|
fn WgslIrLowerer::lower_texture_atomic_statement(
  self : WgslIrLowerer,
  name : String,
  atomic_function : AtomicFunction,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
) -> Unit raise WgslIrLowerError {
  guard arguments.length() == 3 || arguments.length() == 4 else {
    raise WgslIrLowerError::UnsupportedExpression(
      "\{name} expects 3 arguments for non-arrayed storage textures or 4 arguments for arrayed storage textures",
    )
  }
  let image = self.lower_function_expression_node(arguments[0], function, scope)
  let coordinate = self.lower_function_expression_node(
    arguments[1],
    function,
    scope,
  )
  let arrayed = self.image_expression_is_arrayed(function, image)
  let (array_index, value_index) = if arrayed {
    guard arguments.length() == 4 else {
      raise WgslIrLowerError::UnsupportedExpression(
        "\{name} on arrayed storage texture expects array index",
      )
    }
    (
      Some(self.lower_function_expression_node(arguments[2], function, scope)),
      3,
    )
  } else {
    guard arguments.length() == 3 else {
      raise WgslIrLowerError::UnsupportedExpression(
        "\{name} on non-arrayed storage texture does not accept array index",
      )
    }
    (None, 2)
  }
  let value = self.lower_function_expression_node(
    arguments[value_index],
    function,
    scope,
  )
  block.push(
    Statement::ImageAtomic(
      image, coordinate, array_index, atomic_function, value,
    ),
  )
}

///|
fn WgslIrLowerer::lower_texture_expression_call(
  self : WgslIrLowerer,
  name : String,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle? raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  match name {
    "textureSample" =>
      Some(
        self.lower_image_sample_expression(
          arguments,
          function,
          scope,
          SampleLevel::Auto,
        ),
      )
    "textureSampleBias" =>
      Some(
        self.lower_image_sample_with_level_argument(
          arguments, function, scope, "textureSampleBias", "bias",
        ),
      )
    "textureSampleGrad" =>
      Some(self.lower_image_sample_grad_expression(arguments, function, scope))
    "textureSampleLevel" =>
      Some(
        self.lower_image_sample_with_level_argument(
          arguments, function, scope, "textureSampleLevel", "level",
        ),
      )
    "textureSampleCompare" =>
      Some(
        self.lower_image_sample_compare_expression(
          arguments,
          function,
          scope,
          SampleLevel::Auto,
          "textureSampleCompare",
        ),
      )
    "textureSampleCompareLevel" =>
      Some(
        self.lower_image_sample_compare_expression(
          arguments,
          function,
          scope,
          SampleLevel::Zero,
          "textureSampleCompareLevel",
        ),
      )
    "textureSampleBaseClampToEdge" =>
      Some(
        self.lower_image_sample_base_clamp_to_edge_expression(
          arguments, function, scope,
        ),
      )
    "textureGather" =>
      Some(self.lower_image_gather_expression(arguments, function, scope))
    "textureGatherCompare" =>
      Some(
        self.lower_image_gather_compare_expression(arguments, function, scope),
      )
    "textureLoad" =>
      Some(self.lower_image_load_expression(arguments, function, scope))
    "textureDimensions" =>
      Some(self.lower_image_query_expression(arguments, function, scope))
    "textureNumLevels" =>
      Some(
        self.lower_image_query_kind_expression(
          arguments,
          function,
          scope,
          ImageQuery::NumLevels,
          "textureNumLevels",
        ),
      )
    "textureNumLayers" =>
      Some(
        self.lower_image_query_kind_expression(
          arguments,
          function,
          scope,
          ImageQuery::NumLayers,
          "textureNumLayers",
        ),
      )
    "textureNumSamples" =>
      Some(
        self.lower_image_query_kind_expression(
          arguments,
          function,
          scope,
          ImageQuery::NumSamples,
          "textureNumSamples",
        ),
      )
    _ => None
  }
}

///|
priv struct WgslIrTextureTrailingArgs {
  array_index : Handle?
  trailing : Array[Handle]
  offset : Handle?
}

///|
fn WgslIrLowerer::lower_texture_trailing_args(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
  image : Handle,
  base_count : Int,
  trailing_count : Int,
  callee : String,
) -> WgslIrTextureTrailingArgs raise WgslIrLowerError {
  let arrayed = self.image_expression_is_arrayed(function, image)
  let remaining = arguments.length() - base_count
  guard remaining >= trailing_count else {
    raise WgslIrLowerError::UnsupportedExpression(
      "\{callee} has too few arguments",
    )
  }
  let (array_index, trailing_start) = if arrayed {
    guard remaining == trailing_count + 1 || remaining == trailing_count + 2 else {
      raise WgslIrLowerError::UnsupportedExpression(
        "\{callee} argument list does not match arrayed texture signature",
      )
    }
    (
      Some(
        self.lower_function_expression_node(
          arguments[base_count],
          function,
          scope,
        ),
      ),
      base_count + 1,
    )
  } else {
    guard remaining == trailing_count || remaining == trailing_count + 1 else {
      raise WgslIrLowerError::UnsupportedExpression(
        "\{callee} argument list does not match texture signature",
      )
    }
    (None, base_count)
  }
  let trailing : Array[Handle] = []
  for i in 0..<trailing_count {
    trailing.push(
      self.lower_function_expression_node(
        arguments[trailing_start + i],
        function,
        scope,
      ),
    )
  }
  let offset_index = trailing_start + trailing_count
  let offset = if offset_index < arguments.length() {
    Some(
      self.lower_function_expression_node(
        arguments[offset_index],
        function,
        scope,
      ),
    )
  } else {
    None
  }
  WgslIrTextureTrailingArgs::{ array_index, trailing, offset }
}

///|
fn WgslIrLowerer::image_expression_is_arrayed(
  self : WgslIrLowerer,
  function : Function,
  image : Handle,
) -> Bool {
  match self.image_expression_inner(function, image) {
    Some((_, arrayed, _)) => arrayed
    None => false
  }
}

///|
fn WgslIrLowerer::image_expression_is_multisampled(
  self : WgslIrLowerer,
  function : Function,
  image : Handle,
) -> Bool {
  match self.image_expression_inner(function, image) {
    Some((_, _, Sampled(_, multisampled))) => multisampled
    Some((_, _, Depth(multisampled))) => multisampled
    _ => false
  }
}

///|
fn WgslIrLowerer::image_expression_is_storage(
  self : WgslIrLowerer,
  function : Function,
  image : Handle,
) -> Bool {
  match self.image_expression_inner(function, image) {
    Some((_, _, Storage(_, _))) => true
    _ => false
  }
}

///|
fn WgslIrLowerer::image_expression_is_external(
  self : WgslIrLowerer,
  function : Function,
  image : Handle,
) -> Bool {
  match self.image_expression_inner(function, image) {
    Some((_, _, External)) => true
    _ => false
  }
}

///|
fn WgslIrLowerer::image_expression_is_depth(
  self : WgslIrLowerer,
  function : Function,
  image : Handle,
) -> Bool {
  match self.image_expression_inner(function, image) {
    Some((_, _, Depth(_))) => true
    _ => false
  }
}

///|
fn WgslIrLowerer::image_expression_inner(
  self : WgslIrLowerer,
  function : Function,
  image : Handle,
) -> (ImageDimension, Bool, ImageClass)? {
  match self.function_expression_type(function, image) {
    Some(ty_handle) =>
      match self.shader_module.types.get(ty_handle) {
        Some(ty) =>
          match ty.inner {
            Image(dimension, arrayed, image_class) =>
              Some((dimension, arrayed, image_class))
            _ => None
          }
        None => None
      }
    None => None
  }
}

///|
fn WgslIrLowerer::lower_image_sample_expression(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
  level : SampleLevel,
) -> Handle raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments.length() >= 3 else {
    raise WgslIrLowerError::UnsupportedExpression(
      "textureSample expects at least 3 arguments",
    )
  }
  let image = self.lower_function_expression_node(arguments[0], function, scope)
  let sampler = self.lower_function_expression_node(
    arguments[1],
    function,
    scope,
  )
  let coordinate = self.lower_function_expression_node(
    arguments[2],
    function,
    scope,
  )
  let parsed = self.lower_texture_trailing_args(
    arguments, function, scope, image, 3, 0, "textureSample",
  )
  function.expressions.append(
    Expression::ImageSample(
      image,
      sampler,
      None,
      coordinate,
      parsed.array_index,
      parsed.offset,
      level,
      None,
      false,
    ),
  )
}

///|
fn WgslIrLowerer::lower_image_sample_with_level_argument(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
  callee : String,
  level_name : String,
) -> Handle raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments.length() >= 4 else {
    raise WgslIrLowerError::UnsupportedExpression(
      "\{callee} expects at least 4 arguments",
    )
  }
  let image = self.lower_function_expression_node(arguments[0], function, scope)
  let sampler = self.lower_function_expression_node(
    arguments[1],
    function,
    scope,
  )
  let coordinate = self.lower_function_expression_node(
    arguments[2],
    function,
    scope,
  )
  let parsed = self.lower_texture_trailing_args(
    arguments, function, scope, image, 3, 1, callee,
  )
  guard parsed.trailing is [level_handle] else {
    raise WgslIrLowerError::UnsupportedExpression(
      "\{callee} missing \{level_name} argument",
    )
  }
  let level = if level_name == "bias" {
    SampleLevel::Bias(level_handle)
  } else {
    SampleLevel::Exact(level_handle)
  }
  function.expressions.append(
    Expression::ImageSample(
      image,
      sampler,
      None,
      coordinate,
      parsed.array_index,
      parsed.offset,
      level,
      None,
      false,
    ),
  )
}

///|
fn WgslIrLowerer::lower_image_sample_grad_expression(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments.length() >= 5 else {
    raise WgslIrLowerError::UnsupportedExpression(
      "textureSampleGrad expects at least 5 arguments",
    )
  }
  let image = self.lower_function_expression_node(arguments[0], function, scope)
  let sampler = self.lower_function_expression_node(
    arguments[1],
    function,
    scope,
  )
  let coordinate = self.lower_function_expression_node(
    arguments[2],
    function,
    scope,
  )
  let parsed = self.lower_texture_trailing_args(
    arguments, function, scope, image, 3, 2, "textureSampleGrad",
  )
  guard parsed.trailing is [ddx, ddy] else {
    raise WgslIrLowerError::UnsupportedExpression(
      "textureSampleGrad missing gradient arguments",
    )
  }
  function.expressions.append(
    Expression::ImageSample(
      image,
      sampler,
      None,
      coordinate,
      parsed.array_index,
      parsed.offset,
      SampleLevel::Gradient(ddx, ddy),
      None,
      false,
    ),
  )
}

///|
fn WgslIrLowerer::lower_image_sample_compare_expression(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
  level : SampleLevel,
  callee : String,
) -> Handle raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments.length() >= 4 else {
    raise WgslIrLowerError::UnsupportedExpression(
      "\{callee} expects at least 4 arguments",
    )
  }
  let image = self.lower_function_expression_node(arguments[0], function, scope)
  let sampler = self.lower_function_expression_node(
    arguments[1],
    function,
    scope,
  )
  let coordinate = self.lower_function_expression_node(
    arguments[2],
    function,
    scope,
  )
  let parsed = self.lower_texture_trailing_args(
    arguments, function, scope, image, 3, 1, callee,
  )
  guard parsed.trailing is [depth_ref] else {
    raise WgslIrLowerError::UnsupportedExpression(
      "\{callee} missing depth reference argument",
    )
  }
  function.expressions.append(
    Expression::ImageSample(
      image,
      sampler,
      None,
      coordinate,
      parsed.array_index,
      parsed.offset,
      level,
      Some(depth_ref),
      false,
    ),
  )
}

///|
fn WgslIrLowerer::lower_image_sample_base_clamp_to_edge_expression(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments.length() == 3 else {
    raise WgslIrLowerError::UnsupportedExpression(
      "textureSampleBaseClampToEdge expects 3 arguments",
    )
  }
  let image = self.lower_function_expression_node(arguments[0], function, scope)
  let sampler = self.lower_function_expression_node(
    arguments[1],
    function,
    scope,
  )
  let coordinate = self.lower_function_expression_node(
    arguments[2],
    function,
    scope,
  )
  function.expressions.append(
    Expression::ImageSample(
      image,
      sampler,
      None,
      coordinate,
      None,
      None,
      SampleLevel::Zero,
      None,
      true,
    ),
  )
}

///|
fn WgslIrLowerer::lower_image_gather_expression(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments.length() >= 3 else {
    raise WgslIrLowerError::UnsupportedExpression(
      "textureGather expects at least 3 arguments",
    )
  }
  let probe_image_index = if wgsl_ir_expr_node_is_gather_component(arguments[0]) {
    1
  } else {
    0
  }
  let probe_image = self.lower_function_expression_node(
    arguments[probe_image_index],
    function,
    scope,
  )
  let depth = self.image_expression_is_depth(function, probe_image)
  let has_component = probe_image_index == 1
  let (component, image, sampler, coordinate, base_count) = if depth {
    let (component, sampler_index, coordinate_index, base_count) = if has_component {
      guard arguments.length() >= 4 else {
        raise WgslIrLowerError::UnsupportedExpression(
          "textureGather with a component argument expects image, sampler, and coordinate arguments",
        )
      }
      (wgsl_ir_gather_component_from_node(arguments[0]), 2, 3, 4)
    } else {
      (SwizzleComponent::X, 1, 2, 3)
    }
    let sampler = self.lower_function_expression_node(
      arguments[sampler_index],
      function,
      scope,
    )
    let coordinate = self.lower_function_expression_node(
      arguments[coordinate_index],
      function,
      scope,
    )
    (Some(component), probe_image, sampler, coordinate, base_count)
  } else {
    guard arguments.length() >= 4 else {
      raise WgslIrLowerError::UnsupportedExpression(
        "textureGather for non-depth textures expects a component argument",
      )
    }
    let component = wgsl_ir_gather_component_from_node(arguments[0])
    let sampler = self.lower_function_expression_node(
      arguments[2],
      function,
      scope,
    )
    let coordinate = self.lower_function_expression_node(
      arguments[3],
      function,
      scope,
    )
    (Some(component), probe_image, sampler, coordinate, 4)
  }
  let parsed = self.lower_texture_trailing_args(
    arguments, function, scope, image, base_count, 0, "textureGather",
  )
  function.expressions.append(
    Expression::ImageSample(
      image,
      sampler,
      component,
      coordinate,
      parsed.array_index,
      parsed.offset,
      SampleLevel::Auto,
      None,
      false,
    ),
  )
}

///|
fn WgslIrLowerer::lower_image_gather_compare_expression(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments.length() >= 4 else {
    raise WgslIrLowerError::UnsupportedExpression(
      "textureGatherCompare expects at least 4 arguments",
    )
  }
  let image = self.lower_function_expression_node(arguments[0], function, scope)
  let sampler = self.lower_function_expression_node(
    arguments[1],
    function,
    scope,
  )
  let coordinate = self.lower_function_expression_node(
    arguments[2],
    function,
    scope,
  )
  let parsed = self.lower_texture_trailing_args(
    arguments, function, scope, image, 3, 1, "textureGatherCompare",
  )
  guard parsed.trailing is [depth_ref] else {
    raise WgslIrLowerError::UnsupportedExpression(
      "textureGatherCompare missing depth reference argument",
    )
  }
  function.expressions.append(
    Expression::ImageSample(
      image,
      sampler,
      Some(SwizzleComponent::X),
      coordinate,
      parsed.array_index,
      parsed.offset,
      SampleLevel::Auto,
      Some(depth_ref),
      false,
    ),
  )
}

///|
fn WgslIrLowerer::lower_image_load_expression(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments.length() >= 2 && arguments.length() <= 4 else {
    raise WgslIrLowerError::UnsupportedExpression(
      "textureLoad expects 2 to 4 arguments",
    )
  }
  let image = self.lower_function_expression_node(arguments[0], function, scope)
  let coordinate = self.lower_function_expression_node(
    arguments[1],
    function,
    scope,
  )
  let arrayed = self.image_expression_is_arrayed(function, image)
  let multisampled = self.image_expression_is_multisampled(function, image)
  let storage = self.image_expression_is_storage(function, image)
  let external = self.image_expression_is_external(function, image)
  let no_handle : Handle? = None
  let (array_index, sample, level) = if multisampled {
    guard !arrayed && arguments.length() == 3 else {
      raise WgslIrLowerError::UnsupportedExpression(
        "textureLoad multisampled texture expects sample index",
      )
    }
    (
      no_handle,
      Some(self.lower_function_expression_node(arguments[2], function, scope)),
      no_handle,
    )
  } else if arrayed {
    if storage {
      guard arguments.length() == 3 else {
        raise WgslIrLowerError::UnsupportedExpression(
          "textureLoad storage texture array expects array index",
        )
      }
      (
        Some(self.lower_function_expression_node(arguments[2], function, scope)),
        no_handle,
        no_handle,
      )
    } else {
      guard arguments.length() == 4 else {
        raise WgslIrLowerError::UnsupportedExpression(
          "textureLoad sampled texture array expects array index and level",
        )
      }
      (
        Some(self.lower_function_expression_node(arguments[2], function, scope)),
        no_handle,
        Some(self.lower_function_expression_node(arguments[3], function, scope)),
      )
    }
  } else if storage || external {
    guard arguments.length() == 2 else {
      raise WgslIrLowerError::UnsupportedExpression(
        "textureLoad storage/external texture expects no level argument",
      )
    }
    (no_handle, no_handle, no_handle)
  } else {
    guard arguments.length() == 3 else {
      raise WgslIrLowerError::UnsupportedExpression(
        "textureLoad sampled texture expects mip level",
      )
    }
    (
      no_handle,
      no_handle,
      Some(self.lower_function_expression_node(arguments[2], function, scope)),
    )
  }
  ignore(self.image_expression_result_type(function, image, None, None))
  function.expressions.append(
    Expression::ImageLoad(image, coordinate, array_index, sample, level),
  )
}

///|
fn WgslIrLowerer::lower_image_query_expression(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments.length() == 1 || arguments.length() == 2 else {
    raise WgslIrLowerError::UnsupportedExpression(
      "textureDimensions expects 1 or 2 arguments",
    )
  }
  let image = self.lower_function_expression_node(arguments[0], function, scope)
  let level = if arguments.length() == 2 {
    Some(self.lower_function_expression_node(arguments[1], function, scope))
  } else {
    None
  }
  function.expressions.append(
    Expression::ImageQuery(image, ImageQuery::Size(level)),
  )
}

///|
fn WgslIrLowerer::lower_image_query_kind_expression(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
  query : ImageQuery,
  callee : String,
) -> Handle raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments.length() == 1 else {
    raise WgslIrLowerError::UnsupportedExpression(
      "\{callee} expects 1 argument",
    )
  }
  let image = self.lower_function_expression_node(arguments[0], function, scope)
  function.expressions.append(Expression::ImageQuery(image, query))
}

///|
fn WgslIrLowerer::lower_update_statement(
  self : WgslIrLowerer,
  target : @ast.WgslExprRef?,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
  increment : Bool,
) -> Unit raise WgslIrLowerError {
  guard target is Some(target_ref) else {
    raise WgslIrLowerError::UnsupportedStatement("update without target")
  }
  let pointer = self.lower_function_lvalue_ref(target_ref, function, scope)
  self.lower_update_handle(pointer, function, block, increment)
}

///|
fn WgslIrLowerer::lower_update_handle(
  self : WgslIrLowerer,
  pointer : Handle,
  function : Function,
  block : Block,
  increment : Bool,
) -> Unit {
  let loaded = function.expressions.append(Expression::Load(pointer))
  let one = function.expressions.append(
    Expression::Literal(self.update_unit_literal(function, pointer)),
  )
  let op = if increment {
    BinaryOperator::Add
  } else {
    BinaryOperator::Subtract
  }
  let value = function.expressions.append(Expression::Binary(op, loaded, one))
  block.push(Statement::Store(pointer, value))
}

///|
fn WgslIrLowerer::update_unit_literal(
  self : WgslIrLowerer,
  function : Function,
  pointer : Handle,
) -> Literal {
  guard self.function_expression_type(function, pointer) is Some(pointer_ty) else {
    return Literal::I32(1)
  }
  let value_ty = self.deref_pointer_type_handle(pointer_ty)
  match self.shader_module.types.get(value_ty) {
    Some(ty) =>
      match ty.inner {
        Scalar(scalar) =>
          match scalar.kind {
            Uint => Literal::U32(1)
            Sint => Literal::I32(1)
            AbstractInt => Literal::AbstractInt(1)
            _ => Literal::I32(1)
          }
        _ => Literal::I32(1)
      }
    None => Literal::I32(1)
  }
}

///|
fn WgslIrLowerer::infer_local_type_from_initializer(
  self : WgslIrLowerer,
  name : String,
  initializer : @ast.WgslExprRef?,
) -> Handle raise WgslIrLowerError {
  guard initializer is Some(expr_ref) else {
    raise WgslIrLowerError::MissingType(name)
  }
  match expr_ref.root() {
    Some(root) => self.infer_expression_type(root, name)
    None => raise WgslIrLowerError::MissingType(name)
  }
}

///|
fn WgslIrLowerer::infer_constant_declaration_type(
  self : WgslIrLowerer,
  constant : @ast.WgslConst,
) -> Handle raise WgslIrLowerError {
  let name = constant.name().name()
  match self.constant_type_cache.get(name) {
    Some(ty) => return ty
    None => ()
  }
  if self.constant_type_inference_stack.contains(name) {
    raise WgslIrLowerError::MissingType(name)
  }
  self.constant_type_inference_stack.add(name)
  let ty = match constant.ty_ref() {
    Some(ty_ref) => self.lower_type_ref(ty_ref)
    None =>
      self.infer_local_type_from_initializer(name, constant.initializer_ref())
  }
  self.constant_type_cache.set(name, ty)
  ignore(self.constant_type_inference_stack.remove(name))
  ty
}

///|
fn WgslIrLowerer::infer_expression_type(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  name : String,
) -> Handle raise WgslIrLowerError {
  match node.kind() {
    Literal(token) =>
      match token.kind() {
        BoolLiteral(_) => self.lower_builtin_type_name("bool")
        NumericLiteral(literal) =>
          self.lower_builtin_type_name(
            wgsl_ir_numeric_literal_default_type_name(literal),
          )
        _ => raise WgslIrLowerError::MissingType(name)
      }
    Identifier(identifier) =>
      self.infer_named_expression_type(identifier.name(), name)
    Group(inner) => self.infer_expression_type(inner, name)
    Unary(op, inner) =>
      match op {
        Not => self.lower_builtin_type_name("bool")
        Subtract | Complement => self.infer_expression_type(inner, name)
        _ => raise WgslIrLowerError::MissingType(name)
      }
    Member(base, member_ident) =>
      match self.infer_member_expression_type(base, member_ident.name(), name) {
        Some(ty) => ty
        None => raise WgslIrLowerError::MissingType(name)
      }
    Index(base, _) =>
      match self.infer_index_expression_type(base, name) {
        Some(ty) => ty
        None => raise WgslIrLowerError::MissingType(name)
      }
    Binary(op, left, right) =>
      match self.infer_expression_type(left, name) {
        left_ty =>
          match self.infer_expression_type(right, name) {
            right_ty =>
              self.binary_expression_result_type(
                wgsl_ir_binary_operator(op),
                left_ty,
                right_ty,
              )
          }
      }
    Call(callee, arguments) => {
      let arguments = wgsl_ir_call_arguments(arguments)
      match self.lower_bitcast_callee_type(callee) {
        Some(ty) => ty
        None =>
          match self.lower_templated_callee_type(callee) {
            Some(ty) => ty
            None =>
              match callee.kind() {
                Identifier(ident) =>
                  if ident.name() == "select" {
                    self.infer_select_expression_type(arguments, name)
                  } else if ident.name() == "array" {
                    self.infer_array_constructor_type_from_ast(arguments, name)
                  } else if wgsl_ir_barrier_builtin_from_name(ident.name())
                    is Some(_) {
                    raise wgsl_ir_barrier_value_error(ident.name())
                  } else {
                    match wgsl_ir_relational_function_from_name(ident.name()) {
                      Some(relational_function) =>
                        self.infer_relational_expression_type(
                          relational_function, arguments, name,
                        )
                      None =>
                        match wgsl_ir_math_function_from_name(ident.name()) {
                          Some(math_function) =>
                            self.infer_math_expression_type(
                              math_function, arguments, name,
                            )
                          None =>
                            self.lower_untemplated_constructor_type_from_ast(
                              ident.name(),
                              arguments,
                              name,
                            )
                        }
                    }
                  }
                _ => raise WgslIrLowerError::MissingType(name)
              }
          }
      }
    }
    _ => raise WgslIrLowerError::MissingType(name)
  }
}

///|
fn WgslIrLowerer::infer_member_expression_type(
  self : WgslIrLowerer,
  base : @ast.WgslExprNode,
  member_name : String,
  diagnostic_name : String,
) -> Handle? raise WgslIrLowerError {
  let base_ty = self.infer_expression_type(base, diagnostic_name)
  let deref_ty = self.deref_pointer_type_handle(base_ty)
  match self.shader_module.types.get(deref_ty) {
    Some(ty) =>
      match ty.inner {
        Struct(members, _) | PredeclaredStruct(members, _) =>
          match wgsl_ir_struct_member_index(members, member_name) {
            Some(index) =>
              self.indexed_type_from_type_handle(deref_ty, Some(index))
            None => None
          }
        Vector(_, scalar) =>
          match wgsl_ir_swizzle_components(member_name) {
            Some(components) =>
              match components.length() {
                1 => Some(self.scalar_type_handle(scalar))
                count =>
                  Some(
                    self.vector_type_handle(
                      wgsl_ir_vector_size_from_component_count(count),
                      scalar,
                    ),
                  )
              }
            None => None
          }
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrLowerer::infer_index_expression_type(
  self : WgslIrLowerer,
  base : @ast.WgslExprNode,
  diagnostic_name : String,
) -> Handle? raise WgslIrLowerError {
  let base_ty = self.infer_expression_type(base, diagnostic_name)
  self.indexed_type_from_type_handle(base_ty, None)
}

///|
fn WgslIrLowerer::lower_bitcast_callee_type(
  self : WgslIrLowerer,
  callee : @ast.WgslExprNode,
) -> Handle? raise WgslIrLowerError {
  match callee.kind() {
    Template(base, template_arguments) =>
      match base.kind() {
        Identifier(name) if name.name() == "bitcast" =>
          match template_arguments {
            [Type(ty_ref)] => Some(self.lower_type_ref(ty_ref))
            _ =>
              raise WgslIrLowerError::UnsupportedExpression(
                "bitcast expects exactly one type template argument",
              )
          }
        _ => None
      }
    _ => None
  }
}

///|
fn WgslIrLowerer::infer_select_expression_type(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  name : String,
) -> Handle raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  match arguments {
    [reject, _, _] => self.infer_expression_type(reject, name)
    _ => raise WgslIrLowerError::MissingType(name)
  }
}

///|
fn WgslIrLowerer::infer_math_expression_type(
  self : WgslIrLowerer,
  math_function : MathFunction,
  arguments : Array[@ast.WgslExprNode],
  name : String,
) -> Handle raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments is [first, .. rest] else {
    raise WgslIrLowerError::MissingType(name)
  }
  match math_function {
    Dot | Distance | Length | Determinant =>
      match self.infer_expression_type(first, name) {
        ty => self.scalar_type_from_composite_type(ty)
      }
    Modf | Frexp => self.infer_expression_type(first, name)
    _ =>
      match rest {
        _ => self.infer_expression_type(first, name)
      }
  }
}

///|
fn WgslIrLowerer::infer_relational_expression_type(
  self : WgslIrLowerer,
  relational_function : RelationalFunction,
  arguments : Array[@ast.WgslExprNode],
  name : String,
) -> Handle raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments is [first, ..] else {
    raise WgslIrLowerError::MissingType(name)
  }
  match relational_function {
    All | Any => self.scalar_type_handle(Scalar::Scalar(Bool, 1))
    IsNan | IsInf =>
      match self.infer_expression_type(first, name) {
        ty => self.boolean_result_type(ty, ty)
      }
  }
}

///|
fn WgslIrLowerer::scalar_type_from_composite_type(
  self : WgslIrLowerer,
  ty_handle : Handle,
) -> Handle {
  match self.shader_module.types.get(ty_handle) {
    Some(ty) =>
      match ty.inner {
        Vector(_, scalar) => self.scalar_type_handle(scalar)
        Matrix(_, _, scalar) => self.scalar_type_handle(scalar)
        _ => ty_handle
      }
    None => ty_handle
  }
}

///|
fn WgslIrLowerer::infer_named_expression_type(
  self : WgslIrLowerer,
  referenced_name : String,
  diagnostic_name : String,
) -> Handle raise WgslIrLowerError {
  match wgsl_ir_predeclared_u32_constant_literal(referenced_name) {
    Some(_) => self.lower_builtin_type_name("u32")
    None =>
      match self.constant_names.get(referenced_name) {
        Some(handle) =>
          match self.shader_module.constants.items.get(handle.index()) {
            Some(constant) => constant.ty
            None => raise WgslIrLowerError::MissingType(diagnostic_name)
          }
        None =>
          match self.constant_declarations.get(referenced_name) {
            Some(constant) => self.infer_constant_declaration_type(constant)
            None =>
              self.infer_non_constant_named_expression_type(
                referenced_name, diagnostic_name,
              )
          }
      }
  }
}

///|
fn wgsl_ir_predeclared_u32_constant_literal(name : String) -> Literal? {
  match name {
    "RAY_FLAG_NONE" => Some(Literal::U32(0))
    "RAY_FLAG_FORCE_OPAQUE" => Some(Literal::U32(0x1))
    "RAY_FLAG_FORCE_NO_OPAQUE" => Some(Literal::U32(0x2))
    "RAY_FLAG_TERMINATE_ON_FIRST_HIT" => Some(Literal::U32(0x4))
    "RAY_FLAG_SKIP_CLOSEST_HIT_SHADER" => Some(Literal::U32(0x8))
    "RAY_FLAG_CULL_BACK_FACING" => Some(Literal::U32(0x10))
    "RAY_FLAG_CULL_FRONT_FACING" => Some(Literal::U32(0x20))
    "RAY_FLAG_CULL_OPAQUE" => Some(Literal::U32(0x40))
    "RAY_FLAG_CULL_NO_OPAQUE" => Some(Literal::U32(0x80))
    "RAY_FLAG_SKIP_TRIANGLES" => Some(Literal::U32(0x100))
    "RAY_FLAG_SKIP_AABBS" => Some(Literal::U32(0x200))
    "RAY_QUERY_INTERSECTION_NONE" => Some(Literal::U32(0))
    "RAY_QUERY_INTERSECTION_TRIANGLE" => Some(Literal::U32(1))
    "RAY_QUERY_INTERSECTION_GENERATED" => Some(Literal::U32(2))
    "RAY_QUERY_INTERSECTION_AABB" => Some(Literal::U32(3))
    _ => None
  }
}

///|
fn WgslIrLowerer::global_identifier_expression(
  self : WgslIrLowerer,
  name : @ast.WgslIdent,
) -> Expression raise WgslIrLowerError {
  match self.ensure_constant_declaration_lowered(name.name()) {
    Some(handle) => Expression::Constant(handle)
    None =>
      match self.ensure_override_declaration_predeclared(name.name()) {
        Some(handle) => Expression::Override(handle)
        None =>
          match self.global_names.get(name.name()) {
            Some(handle) => Expression::GlobalVariable(handle)
            None =>
              match wgsl_ir_predeclared_u32_constant_literal(name.name()) {
                Some(literal) => Expression::Literal(literal)
                None => raise WgslIrLowerError::UnknownIdentifier(name.name())
              }
          }
      }
  }
}

///|
fn WgslIrLowerer::infer_non_constant_named_expression_type(
  self : WgslIrLowerer,
  referenced_name : String,
  diagnostic_name : String,
) -> Handle raise WgslIrLowerError {
  match self.override_names.get(referenced_name) {
    Some(handle) =>
      match self.shader_module.overrides.items.get(handle.index()) {
        Some(override_) => override_.ty
        None => raise WgslIrLowerError::MissingType(diagnostic_name)
      }
    None =>
      match self.override_declarations.get(referenced_name) {
        Some(override_decl) => {
          self.predeclare_override_declaration(override_decl)
          match self.override_names.get(referenced_name) {
            Some(handle) =>
              match self.shader_module.overrides.items.get(handle.index()) {
                Some(override_) => override_.ty
                None => raise WgslIrLowerError::MissingType(diagnostic_name)
              }
            None => raise WgslIrLowerError::MissingType(diagnostic_name)
          }
        }
        None =>
          match self.global_names.get(referenced_name) {
            Some(handle) =>
              match
                self.shader_module.global_variables.items.get(handle.index()) {
                Some(global) => global.ty
                None => raise WgslIrLowerError::MissingType(diagnostic_name)
              }
            None => raise WgslIrLowerError::MissingType(diagnostic_name)
          }
      }
  }
}

///|
fn WgslIrLowerer::lower_builtin_type_name(
  self : WgslIrLowerer,
  name : String,
) -> Handle raise WgslIrLowerError {
  match self.type_cache.get(name) {
    Some(handle) => handle
    None => raise WgslIrLowerError::MissingType(name)
  }
}

///|
priv struct WgslIrExprTokenDepth {
  mut paren : Int
  mut angle : Int
  mut bracket : Int
  mut brace : Int
}

///|
fn WgslIrExprTokenDepth::WgslIrExprTokenDepth() -> WgslIrExprTokenDepth {
  WgslIrExprTokenDepth::{ paren: 0, angle: 0, bracket: 0, brace: 0 }
}

///|
fn WgslIrExprTokenDepth::at_top(self : WgslIrExprTokenDepth) -> Bool {
  self.paren == 0 && self.angle == 0 && self.bracket == 0 && self.brace == 0
}

///|
fn WgslIrExprTokenDepth::observe(
  self : WgslIrExprTokenDepth,
  token : @ast.WgslExprToken,
) -> Unit {
  match token.kind() {
    Operator(ShiftRight) => {
      if self.angle >= 2 {
        self.angle = self.angle - 2
      } else {
        self.angle = 0
      }
      return
    }
    _ => ()
  }
  match token.kind() {
    Punctuation(40) => self.paren = self.paren + 1
    Punctuation(41) => self.paren = self.paren - 1
    Punctuation(60) => self.angle = self.angle + 1
    Punctuation(62) => self.angle = self.angle - 1
    Punctuation(91) => self.bracket = self.bracket + 1
    Punctuation(93) => self.bracket = self.bracket - 1
    Punctuation(123) => self.brace = self.brace + 1
    Punctuation(125) => self.brace = self.brace - 1
    _ => ()
  }
}

///|
fn wgsl_ir_expr_tokens_assignment(
  tokens : Array[@ast.WgslExprToken],
) -> (String, Array[@ast.WgslExprToken], Array[@ast.WgslExprToken])? {
  let depth = WgslIrExprTokenDepth()
  for i in 0..<tokens.length() {
    if depth.at_top() {
      match wgsl_ir_expr_assignment_at(tokens, i) {
        Some((op, consumed)) =>
          return Some(
            (
              op,
              wgsl_ir_expr_token_slice(tokens, 0, i),
              wgsl_ir_expr_token_slice(tokens, i + consumed, tokens.length()),
            ),
          )
        None => ()
      }
    }
    depth.observe(tokens[i])
  }
  None
}

///|
fn wgsl_ir_expr_assignment_at(
  tokens : Array[@ast.WgslExprToken],
  index : Int,
) -> (String, Int)? {
  guard index >= 0 && index < tokens.length() else { return None }
  match tokens[index].kind() {
    Operator(Unknown(op)) if wgsl_ir_is_compound_assignment_operator(op) =>
      Some((op, 1))
    Operator(ShiftLeft) if index + 1 < tokens.length() &&
      wgsl_ir_expr_token_is_punctuation(tokens[index + 1], 61) =>
      Some(("<<=", 2))
    Operator(ShiftRight) if index + 1 < tokens.length() &&
      wgsl_ir_expr_token_is_punctuation(tokens[index + 1], 61) =>
      Some((">>=", 2))
    Punctuation(61) => Some(("=", 1))
    _ => None
  }
}

///|
fn wgsl_ir_is_compound_assignment_operator(op : String) -> Bool {
  op == "+=" ||
  op == "-=" ||
  op == "*=" ||
  op == "/=" ||
  op == "%=" ||
  op == "&=" ||
  op == "|=" ||
  op == "^="
}

///|
fn wgsl_ir_expr_tokens_update_operator(
  tokens : Array[@ast.WgslExprToken],
) -> (Array[@ast.WgslExprToken], Bool)? {
  guard tokens.length() > 1 else { return None }
  let last = tokens[tokens.length() - 1]
  match last.kind() {
    Operator(Unknown("++")) =>
      Some((wgsl_ir_expr_token_slice(tokens, 0, tokens.length() - 1), true))
    Operator(Unknown("--")) =>
      Some((wgsl_ir_expr_token_slice(tokens, 0, tokens.length() - 1), false))
    _ => None
  }
}

///|
fn wgsl_ir_expr_token_slice(
  tokens : Array[@ast.WgslExprToken],
  start : Int,
  end_ : Int,
) -> Array[@ast.WgslExprToken] {
  let out : Array[@ast.WgslExprToken] = []
  for i in start..<end_ {
    out.push(tokens[i])
  }
  out
}

///|
fn wgsl_ir_expr_token_is_punctuation(
  token : @ast.WgslExprToken,
  code : Int,
) -> Bool {
  match token.kind() {
    Punctuation(value) => value == code
    _ => false
  }
}

///|
fn wgsl_ir_expr_node_from_tokens(
  tokens : Array[@ast.WgslExprToken],
) -> @ast.WgslExprNode raise WgslIrLowerError {
  guard tokens.length() > 0 else {
    raise WgslIrLowerError::UnsupportedExpression("empty expression token list")
  }
  let parser = WgslIrExprTokenParser::{ tokens, index: 0, failed: false }
  match parser.parse_expression(0) {
    Some(node) =>
      if parser.failed || !parser.at_end() {
        raise WgslIrLowerError::UnsupportedExpression(
          "failed to parse expression token list",
        )
      } else {
        node
      }
    None =>
      raise WgslIrLowerError::UnsupportedExpression(
        "failed to parse expression token list",
      )
  }
}

///|
fn WgslIrExprTokenParser::at_end(self : WgslIrExprTokenParser) -> Bool {
  self.index >= self.tokens.length()
}

///|
fn WgslIrExprTokenParser::peek(
  self : WgslIrExprTokenParser,
) -> @ast.WgslExprToken? {
  self.tokens.get(self.index)
}

///|
fn WgslIrExprTokenParser::consume_punctuation(
  self : WgslIrExprTokenParser,
  code : Int,
) -> Bool {
  match self.peek() {
    Some(token) if wgsl_ir_expr_token_is_punctuation(token, code) => {
      self.index = self.index + 1
      true
    }
    _ => false
  }
}

///|
fn wgsl_ir_expr_make_node(
  kind : @ast.WgslExprNodeKind,
  start : Int,
  end_ : Int,
) -> @ast.WgslExprNode {
  @ast.WgslExprNode(kind, start, end_)
}

///|
fn WgslIrExprTokenParser::parse_expression(
  self : WgslIrExprTokenParser,
  min_precedence : Int,
) -> @ast.WgslExprNode? {
  let prefix = match self.parse_prefix() {
    Some(value) => value
    None => return None
  }
  let mut lhs = self.parse_postfix(prefix)
  while true {
    let (op, consumed) = match self.binary_operator_at() {
      Some(value) => value
      None => break
    }
    let precedence = op.binary_precedence()
    if precedence < min_precedence {
      break
    }
    self.index = self.index + consumed
    let rhs = match self.parse_expression(precedence + 1) {
      Some(value) => value
      None => {
        self.failed = true
        break
      }
    }
    lhs = wgsl_ir_expr_make_node(
      @ast.WgslExprNodeKind::Binary(op, lhs, rhs),
      lhs.start(),
      rhs.end(),
    )
  }
  Some(lhs)
}

///|
fn WgslIrExprTokenParser::parse_prefix(
  self : WgslIrExprTokenParser,
) -> @ast.WgslExprNode? {
  match self.peek() {
    Some(token) =>
      match token.kind() {
        Identifier => {
          self.index = self.index + 1
          Some(
            wgsl_ir_expr_make_node(
              @ast.WgslExprNodeKind::Identifier(
                @ast.WgslIdent(token.text(), token.start(), token.end()),
              ),
              token.start(),
              token.end(),
            ),
          )
        }
        BoolLiteral(_) | NumericLiteral(_) => {
          self.index = self.index + 1
          Some(
            wgsl_ir_expr_make_node(
              @ast.WgslExprNodeKind::Literal(token),
              token.start(),
              token.end(),
            ),
          )
        }
        Punctuation(33)
        | Punctuation(45)
        | Punctuation(43)
        | Punctuation(42)
        | Punctuation(38)
        | Punctuation(126) => {
          self.index = self.index + 1
          let rhs = match self.parse_prefix() {
            Some(node) => node
            None => {
              self.failed = true
              return None
            }
          }
          Some(
            wgsl_ir_expr_make_node(
              @ast.WgslExprNodeKind::Unary(
                @ast.WgslExprOperator::from_text(token.text()),
                rhs,
              ),
              token.start(),
              rhs.end(),
            ),
          )
        }
        Punctuation(40) => {
          let start = token.start()
          self.index = self.index + 1
          let inner = self.parse_sequence_until_any([41])
          let end_ = match self.peek() {
            Some(close) if wgsl_ir_expr_token_is_punctuation(close, 41) => {
              self.index = self.index + 1
              close.end()
            }
            _ => inner.end()
          }
          Some(
            wgsl_ir_expr_make_node(
              @ast.WgslExprNodeKind::Group(inner),
              start,
              end_,
            ),
          )
        }
        _ => {
          self.index = self.index + 1
          self.failed = true
          None
        }
      }
    None => None
  }
}

///|
fn WgslIrExprTokenParser::parse_postfix(
  self : WgslIrExprTokenParser,
  base : @ast.WgslExprNode,
) -> @ast.WgslExprNode {
  let mut node = base
  while true {
    match self.peek() {
      Some(token) if wgsl_ir_expr_token_is_punctuation(token, 40) => {
        self.index = self.index + 1
        let args : Array[@ast.WgslExprNode] = []
        while !self.at_end() {
          match self.peek() {
            Some(close) if wgsl_ir_expr_token_is_punctuation(close, 41) => {
              self.index = self.index + 1
              node = wgsl_ir_expr_make_node(
                @ast.WgslExprNodeKind::Call(node, args),
                node.start(),
                close.end(),
              )
              break
            }
            _ => {
              args.push(self.parse_sequence_until_any([44, 41]))
              if self.consume_punctuation(44) {
                continue
              }
            }
          }
        }
        continue
      }
      Some(token) if wgsl_ir_expr_token_is_punctuation(token, 46) => {
        self.index = self.index + 1
        match self.peek() {
          Some(member_token) if member_token.kind() is Identifier => {
            self.index = self.index + 1
            node = wgsl_ir_expr_make_node(
              @ast.WgslExprNodeKind::Member(
                node,
                @ast.WgslIdent(
                  member_token.text(),
                  member_token.start(),
                  member_token.end(),
                ),
              ),
              node.start(),
              member_token.end(),
            )
            continue
          }
          _ => return node
        }
      }
      Some(token) if wgsl_ir_expr_token_is_punctuation(token, 91) => {
        self.index = self.index + 1
        let index = self.parse_sequence_until_any([93])
        let end_ = match self.peek() {
          Some(close) if wgsl_ir_expr_token_is_punctuation(close, 93) => {
            self.index = self.index + 1
            close.end()
          }
          _ => index.end()
        }
        node = wgsl_ir_expr_make_node(
          @ast.WgslExprNodeKind::Index(node, index),
          node.start(),
          end_,
        )
        continue
      }
      _ => return node
    }
  }
  node
}

///|
fn WgslIrExprTokenParser::parse_sequence_until_any(
  self : WgslIrExprTokenParser,
  stop_codes : Array[Int],
) -> @ast.WgslExprNode {
  let nodes : Array[@ast.WgslExprNode] = []
  while !self.at_end() {
    match self.peek() {
      Some(token) if token.kind() is Punctuation(code) &&
        stop_codes.contains(code) => break
      _ => ()
    }
    match self.parse_expression(0) {
      Some(node) => nodes.push(node)
      None => {
        self.failed = true
        break
      }
    }
    if self.consume_punctuation(44) {
      continue
    }
    match self.peek() {
      Some(token) if token.kind() is Punctuation(code) &&
        stop_codes.contains(code) => break
      _ => ()
    }
  }
  match nodes {
    [single] => single
    [] => wgsl_ir_expr_make_node(@ast.WgslExprNodeKind::Sequence([]), 0, 0)
    _ =>
      wgsl_ir_expr_make_node(
        @ast.WgslExprNodeKind::Sequence(nodes),
        nodes[0].start(),
        nodes[nodes.length() - 1].end(),
      )
  }
}

///|
fn WgslIrExprTokenParser::binary_operator_at(
  self : WgslIrExprTokenParser,
) -> (@ast.WgslExprOperator, Int)? {
  guard self.index < self.tokens.length() else { return None }
  match self.tokens[self.index].kind() {
    Operator(op) => Some((op, 1))
    Punctuation(124) => Some((@ast.WgslExprOperator::BitOr, 1))
    Punctuation(38) => Some((@ast.WgslExprOperator::BitAnd, 1))
    Punctuation(60) => Some((@ast.WgslExprOperator::Less, 1))
    Punctuation(62) => Some((@ast.WgslExprOperator::Greater, 1))
    Punctuation(43) => Some((@ast.WgslExprOperator::Add, 1))
    Punctuation(45) => Some((@ast.WgslExprOperator::Subtract, 1))
    Punctuation(42) => Some((@ast.WgslExprOperator::Multiply, 1))
    Punctuation(47) => Some((@ast.WgslExprOperator::Divide, 1))
    Punctuation(37) => Some((@ast.WgslExprOperator::Modulo, 1))
    Punctuation(94) => Some((@ast.WgslExprOperator::BitXor, 1))
    _ => None
  }
}

///|
fn WgslIrLowerer::lower_global_expression_ref(
  self : WgslIrLowerer,
  expr_ref : @ast.WgslExprRef,
) -> Handle raise WgslIrLowerError {
  self.lower_global_expression_ref_with_expected(expr_ref, None)
}

///|
fn WgslIrLowerer::lower_global_expression_ref_with_expected(
  self : WgslIrLowerer,
  expr_ref : @ast.WgslExprRef,
  expected_ty : Handle?,
) -> Handle raise WgslIrLowerError {
  guard expr_ref.root() is Some(root) else {
    raise WgslIrLowerError::UnsupportedExpression("empty global expression")
  }
  self.lower_global_expression_node_with_expected(root, expected_ty)
}

///|
fn WgslIrLowerer::lower_global_expression_node(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
) -> Handle raise WgslIrLowerError {
  self.lower_global_expression_node_with_expected(node, None)
}

///|
fn WgslIrLowerer::lower_global_expression_node_with_expected(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  expected_ty : Handle?,
) -> Handle raise WgslIrLowerError {
  self.shader_module.append_global_expression(
    self.lower_expression_node_to_global_expression_with_expected(
      node, expected_ty,
    ),
  )
}

///|
fn WgslIrLowerer::lower_expression_node_to_global_expression_with_expected(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  expected_ty : Handle?,
) -> Expression raise WgslIrLowerError {
  match node.kind() {
    Literal(token) =>
      Expression::Literal(
        self.literal_from_token_with_expected(token, expected_ty),
      )
    Identifier(name) => self.global_identifier_expression(name)
    Unary(op, expr) =>
      Expression::Unary(
        wgsl_ir_unary_operator(op),
        self.lower_global_expression_node(expr),
      )
    Binary(op, left, right) =>
      Expression::Binary(
        wgsl_ir_binary_operator(op),
        self.lower_global_expression_node(left),
        self.lower_global_expression_node(right),
      )
    Group(expr) =>
      self.lower_expression_node_to_global_expression_with_expected(
        expr, expected_ty,
      )
    Sequence([single]) =>
      self.lower_expression_node_to_global_expression_with_expected(
        single, expected_ty,
      )
    Member(base, member_name) => {
      let base_handle = self.lower_global_expression_node(base)
      Expression::AccessIndex(
        base_handle,
        self.member_index_for_global_expression(base_handle, member_name.name()),
      )
    }
    Index(base, index) =>
      Expression::Access(
        self.lower_global_expression_node(base),
        self.lower_global_expression_node(index),
      )
    Call(callee, arguments) => {
      let arguments = wgsl_ir_call_arguments(arguments)
      match self.lower_bitcast_callee_type(callee) {
        Some(ty) => self.lower_global_bitcast_call(ty, arguments)
        None =>
          match callee.kind() {
            Identifier(name) =>
              if name.name() == "select" {
                self.lower_global_select_call(arguments)
              } else if wgsl_ir_barrier_builtin_from_name(name.name())
                is Some(_) {
                raise wgsl_ir_barrier_value_error(name.name())
              } else {
                match wgsl_ir_math_function_from_name(name.name()) {
                  Some(math_function) =>
                    self.lower_global_math_call(math_function, arguments)
                  None =>
                    match wgsl_ir_relational_function_from_name(name.name()) {
                      Some(relational_function) =>
                        self.lower_global_relational_call(
                          relational_function, arguments,
                        )
                      None =>
                        if name.name() == "array" {
                          self.lower_global_array_constructor_call(
                            expected_ty, arguments,
                          )
                        } else {
                          let ty = match
                            self.expected_constructor_type(
                              name.name(),
                              expected_ty,
                            ) {
                            Some(ty) => ty
                            None =>
                              self.lower_untemplated_constructor_type_from_ast(
                                name.name(),
                                arguments,
                                name.name(),
                              )
                          }
                          Expression::Compose(
                            ty,
                            self.lower_global_expression_arguments(arguments),
                          )
                        }
                    }
                }
              }
            _ =>
              match self.lower_templated_callee_type(callee) {
                Some(ty) =>
                  Expression::Compose(
                    ty,
                    self.lower_global_constructor_arguments(ty, arguments),
                  )
                None =>
                  raise WgslIrLowerError::UnsupportedExpression(
                    "non-identifier global call expression: \{wgsl_ir_expr_node_shape(callee)}",
                  )
              }
          }
      }
    }
    _ =>
      raise WgslIrLowerError::UnsupportedExpression(
        "global expression kind is not constant-lowerable",
      )
  }
}

///|
fn WgslIrLowerer::lower_global_select_call(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
) -> Expression raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments is [reject, accept, condition] else {
    raise WgslIrLowerError::UnsupportedExpression(
      "select expects three arguments",
    )
  }
  Expression::Select(
    self.lower_global_expression_node(condition),
    self.lower_global_expression_node(accept),
    self.lower_global_expression_node(reject),
  )
}

///|
fn WgslIrLowerer::lower_global_bitcast_call(
  self : WgslIrLowerer,
  ty : Handle,
  arguments : Array[@ast.WgslExprNode],
) -> Expression raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments is [expr] else {
    raise WgslIrLowerError::UnsupportedExpression(
      "bitcast expects one argument",
    )
  }
  Expression::Bitcast(ty, self.lower_global_expression_node(expr))
}

///|
fn WgslIrLowerer::lower_global_array_constructor_call(
  self : WgslIrLowerer,
  expected_ty : Handle?,
  arguments : Array[@ast.WgslExprNode],
) -> Expression raise WgslIrLowerError {
  let ty = match expected_ty {
    Some(ty) => ty
    None => self.infer_array_constructor_type_from_ast(arguments, "array")
  }
  guard self.array_element_type(ty) is Some(element_ty) else {
    raise WgslIrLowerError::UnsupportedType("array")
  }
  Expression::Compose(
    ty,
    self.lower_global_expression_arguments_with_expected(
      arguments,
      Some(element_ty),
    ),
  )
}

///|
fn WgslIrLowerer::lower_global_expression_arguments(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
) -> Array[Handle] raise WgslIrLowerError {
  self.lower_global_expression_arguments_with_expected(arguments, None)
}

///|
fn WgslIrLowerer::lower_global_expression_arguments_with_expected(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  expected_ty : Handle?,
) -> Array[Handle] raise WgslIrLowerError {
  let handles : Array[Handle] = []
  for argument in wgsl_ir_flatten_expression_arguments(arguments) {
    handles.push(
      self.lower_global_expression_node_with_expected(argument, expected_ty),
    )
  }
  handles
}

///|
fn WgslIrLowerer::lower_global_constructor_arguments(
  self : WgslIrLowerer,
  ty : Handle,
  arguments : Array[@ast.WgslExprNode],
) -> Array[Handle] raise WgslIrLowerError {
  self.lower_global_expression_arguments_with_expected(
    arguments,
    self.constructor_component_expected_type(ty),
  )
}

///|
fn WgslIrLowerer::lower_global_math_call(
  self : WgslIrLowerer,
  math_function : MathFunction,
  arguments : Array[@ast.WgslExprNode],
) -> Expression raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments is [first, .. rest] else {
    raise WgslIrLowerError::UnsupportedExpression(
      "math call requires at least one argument",
    )
  }
  let a = self.lower_global_expression_node(first)
  let b = match rest {
    [value, ..] => Some(self.lower_global_expression_node(value))
    [] => None
  }
  let c = match rest {
    [_, value, ..] => Some(self.lower_global_expression_node(value))
    _ => None
  }
  let d = match rest {
    [_, _, value, ..] => Some(self.lower_global_expression_node(value))
    _ => None
  }
  Expression::Math(math_function, a, b, c, d)
}

///|
fn WgslIrLowerer::lower_global_relational_call(
  self : WgslIrLowerer,
  relational_function : RelationalFunction,
  arguments : Array[@ast.WgslExprNode],
) -> Expression raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments is [expr] else {
    raise WgslIrLowerError::UnsupportedExpression(
      "\{wgsl_ir_relational_function_name(relational_function)} expects one argument",
    )
  }
  Expression::Relational(
    relational_function,
    self.lower_global_expression_node(expr),
  )
}

///|
fn WgslIrLowerer::lower_function_expression_ref(
  self : WgslIrLowerer,
  expr_ref : @ast.WgslExprRef,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  self.lower_function_expression_ref_with_expected(
    expr_ref,
    function,
    scope,
    None,
  )
}

///|
fn WgslIrLowerer::lower_function_expression_ref_with_expected(
  self : WgslIrLowerer,
  expr_ref : @ast.WgslExprRef,
  function : Function,
  scope : WgslIrFunctionScope,
  expected_ty : Handle?,
) -> Handle raise WgslIrLowerError {
  guard expr_ref.root() is Some(root) else {
    raise WgslIrLowerError::UnsupportedExpression("empty function expression")
  }
  self.lower_function_expression_node_with_expected(
    root, function, scope, expected_ty,
  ) catch {
    UnsupportedExpression(message) =>
      raise WgslIrLowerError::UnsupportedExpression(
        "\{message} at \{expr_ref.start()}..\{expr_ref.end()}: \{wgsl_ir_expr_ref_token_text(expr_ref)}",
      )
    error => raise error
  }
}

///|
fn wgsl_ir_expr_ref_token_text(expr_ref : @ast.WgslExprRef) -> String {
  let parts : Array[String] = []
  for token in expr_ref.tokens() {
    parts.push(token.text())
  }
  parts.join(" ")
}

///|
fn WgslIrLowerer::lower_function_lvalue_ref(
  self : WgslIrLowerer,
  expr_ref : @ast.WgslExprRef,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  guard expr_ref.root() is Some(root) else {
    raise WgslIrLowerError::UnsupportedExpression("empty lvalue")
  }
  self.lower_function_lvalue_node(root, function, scope)
}

///|
fn WgslIrLowerer::function_argument_is_pointer(
  self : WgslIrLowerer,
  function : Function,
  index : Int,
) -> Bool {
  match function.arguments.get(index) {
    Some(argument) =>
      match self.shader_module.types.get(argument.ty) {
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

///|
fn WgslIrLowerer::lower_function_lvalue_node(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  match node.kind() {
    Identifier(name) => {
      match scope.local_constants.get(name.name()) {
        Some(_) =>
          raise WgslIrLowerError::UnsupportedExpression(
            "local const is not assignable",
          )
        None => ()
      }
      match scope.local_inline_lets.get(name.name()) {
        Some(_) =>
          raise WgslIrLowerError::UnsupportedExpression(
            "local let is not assignable",
          )
        None => ()
      }
      match scope.locals.get(name.name()) {
        Some(handle) =>
          return scope.local_pointer_expression(name.name(), handle, function)
        None => ()
      }
      match scope.arguments.get(name.name()) {
        Some(index) =>
          if self.function_argument_is_pointer(function, index) {
            return scope.argument_pointer_expression(
              name.name(),
              index,
              function,
            )
          } else {
            raise WgslIrLowerError::UnsupportedExpression(
              "function argument is not assignable",
            )
          }
        None => ()
      }
      match self.global_names.get(name.name()) {
        Some(handle) =>
          scope.global_pointer_expression(name.name(), handle, function)
        None => raise WgslIrLowerError::UnknownIdentifier(name.name())
      }
    }
    Group(inner) => self.lower_function_lvalue_node(inner, function, scope)
    Unary(op, expr) =>
      if op == @ast.WgslExprOperator::Multiply {
        self.lower_function_expression_node(expr, function, scope)
      } else {
        raise WgslIrLowerError::UnsupportedExpression(
          "unsupported lvalue shape",
        )
      }
    Member(base, member_name) => {
      let base_handle = self.lower_function_member_lvalue_base(
        base, function, scope,
      )
      function.expressions.append(
        Expression::AccessIndex(
          base_handle,
          self.member_index_for_expression(
            function,
            base_handle,
            member_name.name(),
          ),
        ),
      )
    }
    Index(base, index) => {
      let base_handle = self.lower_function_lvalue_node(base, function, scope)
      let index_handle = self.lower_function_expression_node(
        index, function, scope,
      )
      function.expressions.append(Expression::Access(base_handle, index_handle))
    }
    _ =>
      raise WgslIrLowerError::UnsupportedExpression("unsupported lvalue shape")
  }
}

///|
fn WgslIrLowerer::lower_function_member_lvalue_base(
  self : WgslIrLowerer,
  base : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  match wgsl_ir_deref_operand(base) {
    Some(operand) =>
      self.lower_function_expression_node(operand, function, scope)
    None => self.lower_function_lvalue_node(base, function, scope)
  }
}

///|
fn WgslIrLowerer::lower_function_member_value_base(
  self : WgslIrLowerer,
  base : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  match wgsl_ir_deref_operand(base) {
    Some(operand) =>
      self.lower_function_expression_node(operand, function, scope)
    None => self.lower_function_expression_node(base, function, scope)
  }
}

///|
fn wgsl_ir_deref_operand(node : @ast.WgslExprNode) -> @ast.WgslExprNode? {
  match node.kind() {
    Group(inner) => wgsl_ir_deref_operand(inner)
    Unary(op, expr) =>
      if op == @ast.WgslExprOperator::Multiply {
        Some(expr)
      } else {
        None
      }
    _ => None
  }
}

///|
fn WgslIrLowerer::lower_function_expression_node(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  self.lower_function_expression_node_with_expected(node, function, scope, None)
}

///|
fn WgslIrLowerer::lower_function_expression_node_with_expected(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
  expected_ty : Handle?,
) -> Handle raise WgslIrLowerError {
  match node.kind() {
    Literal(token) =>
      function.expressions.append(
        Expression::Literal(
          self.literal_from_token_with_expected(token, expected_ty),
        ),
      )
    ShaderDefTemplate(text) =>
      raise WgslIrLowerError::UnsupportedExpression(
        "shader-def template expression requires preprocessing: \{text}",
      )
    Identifier(name) =>
      self.lower_identifier_expression(name.name(), function, scope)
    PostfixUpdate(_, _) =>
      raise WgslIrLowerError::UnsupportedExpression(
        "update expression outside statement context",
      )
    Assignment(_, _, _) =>
      raise WgslIrLowerError::UnsupportedExpression(
        "assignment expression outside statement context",
      )
    Unary(op, expr) =>
      if op == @ast.WgslExprOperator::BitAnd {
        let target = self.lower_function_lvalue_node(expr, function, scope)
        function.expressions.append(
          Expression::AddressOf(
            self.pointer_type_for_lvalue(function, target),
            target,
          ),
        )
      } else if op == @ast.WgslExprOperator::Multiply {
        function.expressions.append(
          Expression::Load(
            self.lower_function_expression_node(expr, function, scope),
          ),
        )
      } else {
        function.expressions.append(
          Expression::Unary(
            wgsl_ir_unary_operator(op),
            self.lower_function_expression_node(expr, function, scope),
          ),
        )
      }
    Binary(op, left, right) => {
      let expression_start = function.expressions.items.length()
      let left_handle = self.lower_function_expression_node(
        left, function, scope,
      )
      let right_handle = self.lower_function_expression_node(
        right, function, scope,
      )
      let handle = function.expressions.append(
        Expression::Binary(
          wgsl_ir_binary_operator(op),
          left_handle,
          right_handle,
        ),
      )
      if scope.is_direct_local_inline_let_value(left_handle) ||
        scope.is_direct_local_inline_let_value(right_handle) {
        scope.hide_temporary_name_indices(
          expression_start,
          function.expressions.items.length(),
        )
      }
      match self.fold_function_constant_float_expression(function, handle) {
        Some(literal) =>
          function.expressions.append(Expression::Literal(literal))
        None => handle
      }
    }
    Group(expr) =>
      self.lower_function_expression_node_with_expected(
        expr, function, scope, expected_ty,
      )
    Sequence([single]) =>
      self.lower_function_expression_node_with_expected(
        single, function, scope, expected_ty,
      )
    Member(base, member_name) => {
      let base_handle = self.lower_function_member_value_base(
        base, function, scope,
      )
      self.lower_member_expression(function, base_handle, member_name.name())
    }
    Index(base, index) => {
      let base_handle = self.lower_function_index_value_base(
        base, function, scope,
      )
      let index_handle = self.lower_function_expression_node(
        index, function, scope,
      )
      function.expressions.append(Expression::Access(base_handle, index_handle))
    }
    Call(callee, arguments) =>
      self.lower_function_call_expression(
        callee, arguments, function, scope, expected_ty,
      )
    Template(base, _) =>
      raise WgslIrLowerError::UnsupportedExpression(
        "standalone template expression: \{wgsl_ir_expr_node_shape(base)}",
      )
    PathAccess(_, _) =>
      raise WgslIrLowerError::UnsupportedExpression(
        "unresolved qualified path expression: \{wgsl_ir_expr_node_shape(node)}",
      )
    Sequence(items) =>
      raise WgslIrLowerError::UnsupportedExpression(
        "expression sequence with \{items.length()} item(s) outside argument context: \{wgsl_ir_expr_node_shape(node)}",
      )
  }
}

///|
fn WgslIrLowerer::lower_function_call_expression(
  self : WgslIrLowerer,
  callee : @ast.WgslExprNode,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
  expected_ty : Handle?,
) -> Handle raise WgslIrLowerError {
  let arguments = wgsl_ir_call_arguments(arguments)
  match
    self.lower_templated_builtin_function_call(
      callee, arguments, function, scope,
    ) {
    Some(handle) => handle
    None =>
      match self.lower_bitcast_callee_type(callee) {
        Some(ty) =>
          self.lower_function_bitcast_call(ty, arguments, function, scope)
        None =>
          match callee.kind() {
            Identifier(name) =>
              self.lower_named_function_call_expression(
                name.name(),
                arguments,
                function,
                scope,
                expected_ty,
              )
            _ =>
              match self.lower_templated_callee_type(callee) {
                Some(ty) =>
                  function.expressions.append(
                    Expression::Compose(
                      ty,
                      self.lower_function_constructor_arguments(
                        ty, arguments, function, scope,
                      ),
                    ),
                  )
                None =>
                  raise WgslIrLowerError::UnsupportedExpression(
                    "non-identifier call expression: \{wgsl_ir_expr_node_shape(callee)}",
                  )
              }
          }
      }
  }
}

///|
fn WgslIrLowerer::lower_named_function_call_expression(
  self : WgslIrLowerer,
  name : String,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
  expected_ty : Handle?,
) -> Handle raise WgslIrLowerError {
  match self.function_names.get(name) {
    Some(handle) =>
      function.expressions.append(
        Expression::FunctionCall(
          handle,
          self.lower_user_function_call_arguments(
            handle, arguments, function, scope,
          ),
        ),
      )
    None =>
      match wgsl_ir_math_function_from_name(name) {
        Some(math_function) =>
          self.lower_function_math_call(
            math_function, arguments, function, scope,
          )
        None =>
          match wgsl_ir_derivative_function_from_name(name) {
            Some((axis, control)) =>
              self.lower_function_derivative_call(
                axis, control, arguments, function, scope,
              )
            None =>
              match wgsl_ir_relational_function_from_name(name) {
                Some(relational_function) =>
                  self.lower_function_relational_call(
                    relational_function, arguments, function, scope,
                  )
                None =>
                  self.lower_unclassified_named_function_call_expression(
                    name, arguments, function, scope, expected_ty,
                  )
              }
          }
      }
  }
}

///|
fn WgslIrLowerer::lower_unclassified_named_function_call_expression(
  self : WgslIrLowerer,
  name : String,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
  expected_ty : Handle?,
) -> Handle raise WgslIrLowerError {
  if name == "select" {
    self.lower_function_select_call(arguments, function, scope)
  } else if wgsl_ir_barrier_builtin_from_name(name) is Some(_) {
    raise wgsl_ir_barrier_value_error(name)
  } else {
    match wgsl_ir_atomic_function_from_name(name) {
      Some(atomic_function) =>
        self.lower_function_atomic_call(
          atomic_function, arguments, function, scope,
        )
      None =>
        match
          self.lower_texture_expression_call(name, arguments, function, scope) {
          Some(handle) => handle
          None =>
            match
              self.lower_ray_query_expression_call(
                name, arguments, function, scope,
              ) {
              Some(handle) => handle
              None =>
                match wgsl_ir_subgroup_function_from_name(name) {
                  Some(subgroup_function) =>
                    self.lower_function_subgroup_call(
                      subgroup_function, arguments, function, scope,
                    )
                  None =>
                    if name == "arrayLength" {
                      self.lower_function_array_length_call(
                        arguments, function, scope,
                      )
                    } else if name == "coopMultiplyAdd" {
                      self.lower_function_cooperative_multiply_add_call(
                        arguments, function, scope,
                      )
                    } else if name == "workgroupUniformLoad" {
                      self.lower_function_workgroup_uniform_load_call(
                        arguments, function, scope,
                      )
                    } else if name == "array" {
                      self.lower_function_array_constructor_call(
                        expected_ty, arguments, function, scope,
                      )
                    } else {
                      self.lower_function_constructor_call(
                        name, arguments, function, scope, expected_ty,
                      )
                    }
                }
            }
        }
    }
  }
}

///|
fn wgsl_ir_subgroup_function_from_name(name : String) -> SubgroupFunction? {
  match name {
    "subgroupBallot" => Some(Ballot)
    "subgroupAll" => Some(All)
    "subgroupAny" => Some(Any)
    "subgroupAdd" => Some(Add)
    "subgroupMul" => Some(Mul)
    "subgroupMax" => Some(Max)
    "subgroupMin" => Some(Min)
    "subgroupAnd" => Some(And)
    "subgroupOr" => Some(Or)
    "subgroupXor" => Some(Xor)
    "subgroupExclusiveAdd" => Some(ExclusiveAdd)
    "subgroupExclusiveMul" => Some(ExclusiveMul)
    "subgroupInclusiveAdd" => Some(InclusiveAdd)
    "subgroupInclusiveMul" => Some(InclusiveMul)
    "subgroupBroadcastFirst" => Some(BroadcastFirst)
    "subgroupBroadcast" => Some(Broadcast)
    "subgroupShuffle" => Some(Shuffle)
    "subgroupShuffleDown" => Some(ShuffleDown)
    "subgroupShuffleUp" => Some(ShuffleUp)
    "subgroupShuffleXor" => Some(ShuffleXor)
    "quadBroadcast" => Some(QuadBroadcast)
    "quadSwapX" => Some(QuadSwapX)
    "quadSwapY" => Some(QuadSwapY)
    "quadSwapDiagonal" => Some(QuadSwapDiagonal)
    _ => None
  }
}

///|
fn wgsl_ir_subgroup_function_name(function : SubgroupFunction) -> String {
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
fn WgslIrLowerer::lower_function_subgroup_call(
  self : WgslIrLowerer,
  subgroup_function : SubgroupFunction,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  let expected = match subgroup_function {
    Ballot
    | All
    | Any
    | Add
    | Mul
    | Max
    | Min
    | And
    | Or
    | Xor
    | ExclusiveAdd
    | ExclusiveMul
    | InclusiveAdd
    | InclusiveMul
    | BroadcastFirst
    | QuadSwapX
    | QuadSwapY
    | QuadSwapDiagonal => 1
    Broadcast
    | Shuffle
    | ShuffleDown
    | ShuffleUp
    | ShuffleXor
    | QuadBroadcast => 2
  }
  guard arguments.length() == expected else {
    raise WgslIrLowerError::UnsupportedExpression(
      "\{wgsl_ir_subgroup_function_name(subgroup_function)} expects \{expected} argument(s)",
    )
  }
  let lowered = self.lower_function_expression_arguments(
    arguments, function, scope,
  )
  function.expressions.append(
    Expression::SubgroupCall(subgroup_function, lowered),
  )
}

///|
fn WgslIrLowerer::lower_function_constructor_call(
  self : WgslIrLowerer,
  name : String,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
  expected_ty : Handle?,
) -> Handle raise WgslIrLowerError {
  let lowered_arguments = self.lower_function_expression_arguments(
    arguments, function, scope,
  )
  let ty = match self.expected_constructor_type(name, expected_ty) {
    Some(ty) => ty
    None =>
      self.lower_untemplated_constructor_type_from_handles(
        name, arguments, lowered_arguments, function,
      )
  }
  function.expressions.append(Expression::Compose(ty, lowered_arguments))
}

///|
fn WgslIrLowerer::lower_function_derivative_call(
  self : WgslIrLowerer,
  axis : DerivativeAxis,
  control : DerivativeControl,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments is [expr] else {
    raise WgslIrLowerError::UnsupportedExpression(
      "derivative call expects one argument",
    )
  }
  function.expressions.append(
    Expression::Derivative(
      axis,
      control,
      self.lower_function_expression_node(expr, function, scope),
    ),
  )
}

///|
fn WgslIrLowerer::lower_identifier_expression(
  self : WgslIrLowerer,
  name : String,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  match scope.local_constants.get(name) {
    Some(handle) => return handle
    None => ()
  }
  if scope.allow_local_inline_lets {
    match scope.local_inline_lets.get(name) {
      Some(handle) => return handle
      None => ()
    }
  } else {
    match scope.local_inline_lets.get(name) {
      Some(_) =>
        raise WgslIrLowerError::UnsupportedExpression(
          "local let is not a const expression",
        )
      None => ()
    }
  }
  match scope.locals.get(name) {
    Some(handle) =>
      if self.local_variable_is_handle_value(function, handle) {
        return scope.local_pointer_expression(name, handle, function)
      } else {
        return function.expressions.append(
          Expression::Load(
            scope.local_pointer_expression(name, handle, function),
          ),
        )
      }
    None => ()
  }
  match scope.arguments.get(name) {
    Some(index) =>
      return function.expressions.append(Expression::FunctionArgument(index))
    None => ()
  }
  match self.ensure_constant_declaration_lowered(name) {
    Some(handle) =>
      return function.expressions.append(Expression::Constant(handle))
    None => ()
  }
  match self.ensure_override_declaration_predeclared(name) {
    Some(handle) =>
      return function.expressions.append(Expression::Override(handle))
    None => ()
  }
  match self.global_names.get(name) {
    Some(handle) =>
      if self.global_variable_is_handle_value(handle) {
        scope.global_pointer_expression(name, handle, function)
      } else {
        function.expressions.append(
          Expression::Load(
            scope.global_pointer_expression(name, handle, function),
          ),
        )
      }
    None =>
      match wgsl_ir_predeclared_u32_constant_literal(name) {
        Some(literal) =>
          function.expressions.append(Expression::Literal(literal))
        None => raise WgslIrLowerError::UnknownIdentifier(name)
      }
  }
}

///|
fn WgslIrLowerer::local_variable_is_handle_value(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle,
) -> Bool {
  match function.local_variables.items.get(handle.index()) {
    Some(local_var) =>
      match self.shader_module.types.get(local_var.ty) {
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

///|
fn WgslIrLowerer::global_variable_is_handle_value(
  self : WgslIrLowerer,
  handle : Handle,
) -> Bool {
  match self.shader_module.global_variables.items.get(handle.index()) {
    Some(global) =>
      match self.shader_module.types.get(global.ty) {
        Some(type_) =>
          match type_.inner {
            Image(_, _, _)
            | Sampler(_)
            | AccelerationStructure(_)
            | RayQuery(_) => true
            _ => false
          }
        None => false
      }
    None => false
  }
}

///|
fn WgslIrLowerer::lower_function_index_value_base(
  self : WgslIrLowerer,
  base : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  if self.function_index_base_is_addressable(base, function, scope) {
    self.lower_function_lvalue_node(base, function, scope)
  } else {
    self.lower_function_expression_node(base, function, scope)
  }
}

///|
fn WgslIrLowerer::function_index_base_is_addressable(
  self : WgslIrLowerer,
  base : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Bool {
  match base.kind() {
    Group(inner) =>
      self.function_index_base_is_addressable(inner, function, scope)
    Identifier(name) =>
      if scope.locals.get(name.name()) is Some(_) {
        true
      } else {
        match scope.arguments.get(name.name()) {
          Some(index) => self.function_argument_is_pointer(function, index)
          None => self.global_names.get(name.name()) is Some(_)
        }
      }
    Index(inner, _) | Member(inner, _) =>
      self.function_index_base_is_addressable(inner, function, scope)
    Unary(op, _) => op == @ast.WgslExprOperator::Multiply
    _ => false
  }
}

///|
fn WgslIrLowerer::lower_ray_query_expression_call(
  self : WgslIrLowerer,
  name : String,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle? raise WgslIrLowerError {
  match name {
    "rayQueryInitialize" => {
      guard arguments is [query, acceleration, ray_desc] else { return None }
      Some(
        function.expressions.append(
          Expression::RayQueryInitialize(
            self.lower_function_expression_node(query, function, scope),
            self.lower_function_expression_node(acceleration, function, scope),
            self.lower_function_expression_node(ray_desc, function, scope),
          ),
        ),
      )
    }
    "rayQueryProceed" => {
      guard arguments is [query] else { return None }
      Some(
        function.expressions.append(
          Expression::RayQueryProceed(
            self.lower_function_expression_node(query, function, scope),
          ),
        ),
      )
    }
    "rayQueryGenerateIntersection" => {
      guard arguments is [query, intersection_t] else { return None }
      Some(
        function.expressions.append(
          Expression::RayQueryGenerateIntersection(
            self.lower_function_expression_node(query, function, scope),
            self.lower_function_expression_node(intersection_t, function, scope),
          ),
        ),
      )
    }
    "rayQueryConfirmIntersection" => {
      guard arguments is [query] else { return None }
      Some(
        function.expressions.append(
          Expression::RayQueryConfirmIntersection(
            self.lower_function_expression_node(query, function, scope),
          ),
        ),
      )
    }
    "rayQueryTerminate" => {
      guard arguments is [query] else { return None }
      Some(
        function.expressions.append(
          Expression::RayQueryTerminate(
            self.lower_function_expression_node(query, function, scope),
          ),
        ),
      )
    }
    "rayQueryGetCommittedIntersection" => {
      guard arguments is [query] else { return None }
      Some(
        function.expressions.append(
          Expression::RayQueryGetIntersection(
            self.lower_function_expression_node(query, function, scope),
            true,
          ),
        ),
      )
    }
    "rayQueryGetCandidateIntersection" => {
      guard arguments is [query] else { return None }
      Some(
        function.expressions.append(
          Expression::RayQueryGetIntersection(
            self.lower_function_expression_node(query, function, scope),
            false,
          ),
        ),
      )
    }
    "getCommittedHitVertexPositions" => {
      guard arguments is [query] else { return None }
      Some(
        function.expressions.append(
          Expression::RayQueryVertexPositions(
            self.lower_function_expression_node(query, function, scope),
            true,
          ),
        ),
      )
    }
    "getCandidateHitVertexPositions" => {
      guard arguments is [query] else { return None }
      Some(
        function.expressions.append(
          Expression::RayQueryVertexPositions(
            self.lower_function_expression_node(query, function, scope),
            false,
          ),
        ),
      )
    }
    _ => None
  }
}

///|
fn WgslIrLowerer::lower_function_expression_arguments(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Array[Handle] raise WgslIrLowerError {
  self.lower_function_expression_arguments_with_expected(
    arguments,
    function,
    scope,
    None,
  )
}

///|
fn WgslIrLowerer::lower_function_expression_arguments_with_expected(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
  expected_ty : Handle?,
) -> Array[Handle] raise WgslIrLowerError {
  let handles : Array[Handle] = []
  for argument in wgsl_ir_flatten_expression_arguments(arguments) {
    handles.push(
      self.lower_function_expression_node_with_expected(
        argument, function, scope, expected_ty,
      ),
    )
  }
  handles
}

///|
fn WgslIrLowerer::lower_function_constructor_arguments(
  self : WgslIrLowerer,
  ty : Handle,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Array[Handle] raise WgslIrLowerError {
  self.lower_function_expression_arguments_with_expected(
    arguments,
    function,
    scope,
    self.constructor_component_expected_type(ty),
  )
}

///|
fn WgslIrLowerer::lower_function_array_constructor_call(
  self : WgslIrLowerer,
  expected_ty : Handle?,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  let lowered_arguments = self.lower_function_expression_arguments(
    arguments, function, scope,
  )
  let ty = match expected_ty {
    Some(ty) => ty
    None =>
      self.infer_array_constructor_type_from_handles(
        lowered_arguments, function, "array",
      )
  }
  guard self.array_element_type(ty) is Some(element_ty) else {
    raise WgslIrLowerError::UnsupportedType("array")
  }
  let components = match expected_ty {
    Some(_) =>
      self.lower_function_expression_arguments_with_expected(
        arguments,
        function,
        scope,
        Some(element_ty),
      )
    None => lowered_arguments
  }
  function.expressions.append(Expression::Compose(ty, components))
}

///|
fn WgslIrLowerer::lower_function_array_length_call(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments is [argument] else {
    raise WgslIrLowerError::UnsupportedExpression(
      "arrayLength expects one argument",
    )
  }
  let pointer = self.lower_atomic_pointer_argument(argument, function, scope)
  function.expressions.append(Expression::ArrayLength(pointer))
}

///|
fn WgslIrLowerer::lower_function_workgroup_uniform_load_call(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments is [argument] else {
    raise WgslIrLowerError::UnsupportedExpression(
      "workgroupUniformLoad expects one argument",
    )
  }
  let pointer = self.lower_atomic_pointer_argument(argument, function, scope)
  function.expressions.append(Expression::WorkGroupUniformLoad(pointer))
}

///|
fn WgslIrLowerer::lower_function_math_call(
  self : WgslIrLowerer,
  math_function : MathFunction,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments is [first, .. rest] else {
    raise WgslIrLowerError::UnsupportedExpression(
      "math call requires at least one argument",
    )
  }
  let a = self.lower_function_expression_node(first, function, scope)
  let b = match rest {
    [value, ..] =>
      Some(self.lower_function_expression_node(value, function, scope))
    [] => None
  }
  let c = match rest {
    [_, value, ..] =>
      Some(self.lower_function_expression_node(value, function, scope))
    _ => None
  }
  let d = match rest {
    [_, _, value, ..] =>
      Some(self.lower_function_expression_node(value, function, scope))
    _ => None
  }
  function.expressions.append(Expression::Math(math_function, a, b, c, d))
}

///|
fn WgslIrLowerer::lower_function_relational_call(
  self : WgslIrLowerer,
  relational_function : RelationalFunction,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments is [expr] else {
    raise WgslIrLowerError::UnsupportedExpression(
      "\{wgsl_ir_relational_function_name(relational_function)} expects one argument",
    )
  }
  function.expressions.append(
    Expression::Relational(
      relational_function,
      self.lower_function_expression_node(expr, function, scope),
    ),
  )
}

///|
fn WgslIrLowerer::lower_function_select_call(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments is [reject, accept, condition] else {
    raise WgslIrLowerError::UnsupportedExpression(
      "select expects three arguments",
    )
  }
  function.expressions.append(
    Expression::Select(
      self.lower_function_expression_node(condition, function, scope),
      self.lower_function_expression_node(accept, function, scope),
      self.lower_function_expression_node(reject, function, scope),
    ),
  )
}

///|
fn WgslIrLowerer::lower_function_bitcast_call(
  self : WgslIrLowerer,
  ty : Handle,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments is [expr] else {
    raise WgslIrLowerError::UnsupportedExpression(
      "bitcast expects one argument",
    )
  }
  function.expressions.append(
    Expression::Bitcast(
      ty,
      self.lower_function_expression_node(expr, function, scope),
    ),
  )
}

///|
fn WgslIrLowerer::lower_function_atomic_call(
  self : WgslIrLowerer,
  atomic_function : AtomicFunction,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  let expected = match atomic_function {
    Load => 1
    Store => 2
    Add | Subtract | And | ExclusiveOr | InclusiveOr | Min | Max | Exchange => 2
    CompareExchangeWeak => 3
  }
  if arguments.length() != expected {
    raise WgslIrLowerError::UnsupportedExpression(
      "\{wgsl_ir_atomic_function_name(atomic_function)} expects \{expected} arguments",
    )
  }
  let handles : Array[Handle] = []
  for index in 0..<arguments.length() {
    let argument = arguments[index]
    if index == 0 {
      handles.push(
        self.lower_atomic_pointer_argument(argument, function, scope),
      )
    } else {
      handles.push(
        self.lower_function_expression_node(argument, function, scope),
      )
    }
  }
  function.expressions.append(Expression::AtomicCall(atomic_function, handles))
}

///|
fn WgslIrLowerer::lower_atomic_pointer_argument(
  self : WgslIrLowerer,
  argument : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  match wgsl_ir_address_of_operand_node(argument) {
    Some(target) => self.lower_function_lvalue_node(target, function, scope)
    None => self.lower_function_expression_node(argument, function, scope)
  }
}

///|
fn wgsl_ir_expr_ref_is_phony(expr_ref : @ast.WgslExprRef) -> Bool {
  match expr_ref.root() {
    Some(root) =>
      match root.kind() {
        Identifier(name) => name.name() == "_"
        _ => false
      }
    None => false
  }
}

///|
fn wgsl_ir_expr_tokens_are_phony(tokens : Array[@ast.WgslExprToken]) -> Bool {
  match tokens {
    [token] =>
      match token.kind() {
        Identifier => token.text() == "_"
        _ => false
      }
    _ => false
  }
}

///|
fn wgsl_ir_flatten_expression_arguments(
  arguments : Array[@ast.WgslExprNode],
) -> Array[@ast.WgslExprNode] {
  match arguments {
    [single] =>
      match single.kind() {
        Sequence(items) => items
        _ => arguments
      }
    _ => arguments
  }
}

///|
fn wgsl_ir_expr_node_shape(node : @ast.WgslExprNode) -> String {
  match node.kind() {
    Identifier(name) => "identifier \{name.name()}"
    Literal(token) => "literal \{token.text()}"
    ShaderDefTemplate(text) => "shader-def template \{text}"
    Unary(op, inner) => "unary \{op.text()}(\{wgsl_ir_expr_node_shape(inner)})"
    PostfixUpdate(op, inner) =>
      "postfix \{op}(\{wgsl_ir_expr_node_shape(inner)})"
    Assignment(op, left, right) =>
      "assignment \{op}(\{wgsl_ir_expr_node_shape(left)}, \{wgsl_ir_expr_node_shape(right)})"
    Binary(op, left, right) =>
      "binary \{op.text()}(\{wgsl_ir_expr_node_shape(left)}, \{wgsl_ir_expr_node_shape(right)})"
    Call(callee, _) => "call(\{wgsl_ir_expr_node_shape(callee)})"
    Template(base, _) => "template(\{wgsl_ir_expr_node_shape(base)})"
    PathAccess(base, segment) =>
      "path(\{wgsl_ir_expr_node_shape(base)}::\{segment.name()})"
    Member(base, segment) =>
      "member(\{wgsl_ir_expr_node_shape(base)}.\{segment.name()})"
    Index(base, _) => "index(\{wgsl_ir_expr_node_shape(base)})"
    Group(inner) => "group(\{wgsl_ir_expr_node_shape(inner)})"
    Sequence(items) => {
      let parts : Array[String] = []
      let limit = if items.length() < 4 { items.length() } else { 4 }
      for i in 0..<limit {
        parts.push(wgsl_ir_expr_node_shape(items[i]))
      }
      if items.length() > limit {
        parts.push("...")
      }
      let text = parts.join(", ")
      "sequence(\{items.length()}: \{text})"
    }
  }
}

///|
fn WgslIrLowerer::member_index_for_expression(
  self : WgslIrLowerer,
  function : Function,
  expression_handle : Handle,
  member_name : String,
) -> Int raise WgslIrLowerError {
  match self.function_expression_type(function, expression_handle) {
    Some(ty_handle) =>
      match
        self.shader_module.types.get(self.deref_pointer_type_handle(ty_handle)) {
        Some(ty) =>
          match ty.inner {
            Struct(members, _) | PredeclaredStruct(members, _) =>
              match wgsl_ir_struct_member_index(members, member_name) {
                Some(index) => index
                None =>
                  raise WgslIrLowerError::UnsupportedExpression(
                    "unknown struct member \{member_name}",
                  )
              }
            _ => wgsl_ir_member_index(member_name)
          }
        None => wgsl_ir_member_index(member_name)
      }
    None => wgsl_ir_member_index(member_name)
  }
}

///|
fn WgslIrLowerer::member_index_for_global_expression(
  self : WgslIrLowerer,
  expression_handle : Handle,
  member_name : String,
) -> Int raise WgslIrLowerError {
  match self.global_expression_type(expression_handle) {
    Some(ty_handle) =>
      match
        self.shader_module.types.get(self.deref_pointer_type_handle(ty_handle)) {
        Some(ty) =>
          match ty.inner {
            Struct(members, _) | PredeclaredStruct(members, _) =>
              match wgsl_ir_struct_member_index(members, member_name) {
                Some(index) => index
                None =>
                  raise WgslIrLowerError::UnsupportedExpression(
                    "unknown struct member \{member_name}",
                  )
              }
            _ => wgsl_ir_member_index(member_name)
          }
        None => wgsl_ir_member_index(member_name)
      }
    None => wgsl_ir_member_index(member_name)
  }
}

///|
fn WgslIrLowerer::global_expression_type(
  self : WgslIrLowerer,
  handle : Handle,
) -> Handle? {
  match self.shader_module.global_expressions.items.get(handle.index()) {
    Some(expression) => self.global_expression_inner_type(expression)
    None => None
  }
}

///|
fn WgslIrLowerer::global_expression_inner_type(
  self : WgslIrLowerer,
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
    Compose(ty, _) | ZeroValue(ty) => Some(ty)
    AccessIndex(base, index) =>
      match self.global_expression_type(base) {
        Some(ty) => self.indexed_type_from_type_handle(ty, Some(index))
        None => None
      }
    Access(base, _) =>
      match self.global_expression_type(base) {
        Some(ty) => self.indexed_type_from_type_handle(ty, None)
        None => None
      }
    Swizzle(_, _, _) => None
    Literal(literal) => self.literal_type(literal)
    Unary(_, inner) => self.global_expression_type(inner)
    Binary(op, left, right) =>
      match self.global_expression_type(left) {
        Some(left_ty) =>
          match self.global_expression_type(right) {
            Some(right_ty) =>
              Some(self.binary_expression_result_type(op, left_ty, right_ty))
            None => Some(left_ty)
          }
        None => self.global_expression_type(right)
      }
    Select(_, accept, reject) =>
      match self.global_expression_type(accept) {
        Some(ty) => Some(ty)
        None => self.global_expression_type(reject)
      }
    Bitcast(ty, _) => Some(ty)
    Math(math_function, a, _, _, _) =>
      self.math_expression_result_type(
        Function::Function(None),
        math_function,
        a,
      )
    Relational(relational_function, expr) =>
      self.relational_expression_result_type(
        Function::Function(None),
        relational_function,
        expr,
      )
    _ => None
  }
}

///|
fn WgslIrLowerer::deref_pointer_type_handle(
  self : WgslIrLowerer,
  ty_handle : Handle,
) -> Handle {
  match self.shader_module.types.get(ty_handle) {
    Some(ty) =>
      match ty.inner {
        Pointer(inner, _) => self.deref_pointer_type_handle(inner)
        _ => ty_handle
      }
    None => ty_handle
  }
}

///|
fn WgslIrLowerer::pointer_type_for_lvalue(
  self : WgslIrLowerer,
  function : Function,
  target : Handle,
) -> Handle raise WgslIrLowerError {
  guard self.function_expression_type(function, target) is Some(value_ty) else {
    raise WgslIrLowerError::MissingType("address-of target")
  }
  let space = self.address_space_for_lvalue(function, target)
  let key = "ptr<\{wgsl_ir_address_space_key(space)}, \{self.type_key(value_ty)}>"
  let handle = self.shader_module.append_type(Type::{
    name: Some(key),
    inner: TypeInner::Pointer(value_ty, space),
  })
  self.type_cache.set(key, handle)
  handle
}

///|
fn WgslIrLowerer::address_space_for_lvalue(
  self : WgslIrLowerer,
  function : Function,
  target : Handle,
) -> AddressSpace {
  match function.expressions.items.get(target.index()) {
    Some(expression) =>
      match expression {
        LocalVariable(handle) =>
          match function.local_variables.items.get(handle.index()) {
            Some(local_variable) =>
              self.address_space_from_pointer_type(local_variable.ty)
            None => AddressSpace::Function
          }
        GlobalVariable(handle) =>
          match self.shader_module.global_variables.items.get(handle.index()) {
            Some(global) => global.space
            None => AddressSpace::Function
          }
        FunctionArgument(index) =>
          match function.arguments.get(index) {
            Some(argument) => self.address_space_from_pointer_type(argument.ty)
            None => AddressSpace::Function
          }
        Access(base, _) | AccessIndex(base, _) =>
          self.address_space_for_lvalue(function, base)
        Load(inner) => self.address_space_for_lvalue(function, inner)
        _ => AddressSpace::Function
      }
    None => AddressSpace::Function
  }
}

///|
fn WgslIrLowerer::address_space_from_pointer_type(
  self : WgslIrLowerer,
  ty_handle : Handle,
) -> AddressSpace {
  match self.shader_module.types.get(ty_handle) {
    Some(ty) =>
      match ty.inner {
        Pointer(_, space) => space
        _ => AddressSpace::Function
      }
    None => AddressSpace::Function
  }
}

///|
fn WgslIrLowerer::type_key(self : WgslIrLowerer, ty_handle : Handle) -> String {
  match self.shader_module.types.get(ty_handle) {
    Some(ty) =>
      match ty.name {
        Some(name) => name
        None => "type#\{ty_handle.index()}"
      }
    None => "type#\{ty_handle.index()}"
  }
}

///|
fn WgslIrLowerer::lower_member_expression(
  self : WgslIrLowerer,
  function : Function,
  base_handle : Handle,
  member_name : String,
) -> Handle raise WgslIrLowerError {
  match self.function_expression_type(function, base_handle) {
    Some(ty_handle) =>
      match self.shader_module.types.get(ty_handle) {
        Some(ty) =>
          match ty.inner {
            Vector(_, _) =>
              match wgsl_ir_swizzle_components(member_name) {
                Some(components) =>
                  if components.length() == 1 {
                    function.expressions.append(
                      Expression::AccessIndex(
                        base_handle,
                        wgsl_ir_gather_component_index(components[0]),
                      ),
                    )
                  } else {
                    function.expressions.append(
                      Expression::Swizzle(
                        wgsl_ir_vector_size_from_component_count(
                          components.length(),
                        ),
                        base_handle,
                        components,
                      ),
                    )
                  }
                None =>
                  raise WgslIrLowerError::UnsupportedExpression(
                    "invalid vector swizzle: \{member_name}",
                  )
              }
            _ =>
              function.expressions.append(
                Expression::AccessIndex(
                  base_handle,
                  self.member_index_for_expression(
                    function, base_handle, member_name,
                  ),
                ),
              )
          }
        None =>
          function.expressions.append(
            Expression::AccessIndex(
              base_handle,
              self.member_index_for_expression(
                function, base_handle, member_name,
              ),
            ),
          )
      }
    None =>
      function.expressions.append(
        Expression::AccessIndex(
          base_handle,
          self.member_index_for_expression(function, base_handle, member_name),
        ),
      )
  }
}

///|
fn WgslIrLowerer::function_expression_type(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle,
) -> Handle? {
  match function.expressions.items.get(handle.index()) {
    Some(expression) =>
      self.function_expression_inner_type(function, expression)
    None => None
  }
}

///|
fn WgslIrLowerer::function_expression_inner_type(
  self : WgslIrLowerer,
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
      match self.function_expression_type(function, inner) {
        Some(ty) => Some(self.deref_pointer_type_handle(ty))
        None => None
      }
    Expression::AddressOf(ty, _) => Some(ty)
    Compose(ty, _) | ZeroValue(ty) => Some(ty)
    AccessIndex(base, index) =>
      self.indexed_expression_type(function, base, Some(index))
    Access(base, _) => self.indexed_expression_type(function, base, None)
    Swizzle(size, base, _) => self.swizzle_expression_type(function, base, size)
    Unary(_, inner) => self.function_expression_type(function, inner)
    Binary(op, left, right) =>
      match self.function_expression_type(function, left) {
        Some(left_ty) =>
          match self.function_expression_type(function, right) {
            Some(right_ty) =>
              Some(self.binary_expression_result_type(op, left_ty, right_ty))
            None => Some(left_ty)
          }
        None => self.function_expression_type(function, right)
      }
    Select(_, accept, reject) =>
      match self.function_expression_type(function, accept) {
        Some(ty) => Some(ty)
        None => self.function_expression_type(function, reject)
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
    Derivative(_, _, expr) => self.function_expression_type(function, expr)
    Math(math_function, a, _, _, _) =>
      self.math_expression_result_type(function, math_function, a)
    Relational(relational_function, expr) =>
      self.relational_expression_result_type(
        function, relational_function, expr,
      )
    AtomicCall(atomic_function, arguments) =>
      self.atomic_expression_result_type(function, atomic_function, arguments)
    ImageSample(image, _, gather, _, _, _, _, depth_ref, _) =>
      self.image_expression_result_type(function, image, gather, depth_ref)
    ImageLoad(image, _, _, _, _) =>
      self.image_expression_result_type(function, image, None, None)
    ImageQuery(image, query) =>
      self.image_query_expression_result_type(function, image, query)
    ArrayLength(_) => self.type_cache.get("u32")
    RayQueryGetIntersection(_, _) => self.type_cache.get("RayIntersection")
    RayQueryVertexPositions(_, _) =>
      self.shader_module.special_types.ray_vertex_return
    RayQueryProceedResult => self.type_cache.get("bool")
    WorkGroupUniformLoad(pointer) =>
      match self.function_expression_type(function, pointer) {
        Some(ty) => Some(self.deref_pointer_type_handle(ty))
        None => None
      }
    CooperativeLoad(columns, rows, role, data) =>
      match self.cooperative_data_scalar(function, data) {
        Some(scalar) =>
          Some(self.cooperative_matrix_type_handle(columns, rows, scalar, role))
        None => None
      }
    CooperativeMultiplyAdd(_, _, c) =>
      self.function_expression_type(function, c)
    SubgroupCall(subgroup_function, arguments) =>
      self.subgroup_expression_result_type(
        function, subgroup_function, arguments,
      )
    Literal(literal) => self.literal_type(literal)
    _ => None
  }
}

///|
fn WgslIrLowerer::subgroup_expression_result_type(
  self : WgslIrLowerer,
  function : Function,
  subgroup_function : SubgroupFunction,
  arguments : Array[Handle],
) -> Handle? {
  match subgroup_function {
    Ballot => Some(self.vector_type_handle(Quad, Scalar::Scalar(Uint, 4)))
    All | Any => self.type_cache.get("bool")
    _ =>
      match arguments.get(0) {
        Some(first) => self.function_expression_type(function, first)
        None => None
      }
  }
}

///|
fn WgslIrLowerer::math_expression_result_type(
  self : WgslIrLowerer,
  function : Function,
  math_function : MathFunction,
  argument : Handle,
) -> Handle? {
  guard self.function_expression_type(function, argument) is Some(input_ty) else {
    return None
  }
  match math_function {
    Modf => self.predeclared_modf_result_type(input_ty)
    Frexp => self.predeclared_frexp_result_type(input_ty)
    Pack4x8snorm
    | Pack4x8unorm
    | Pack2x16snorm
    | Pack2x16unorm
    | Pack2x16float
    | Pack4xI8
    | Pack4xU8
    | Pack4xI8Clamp
    | Pack4xU8Clamp
    | Dot4U8Packed => Some(self.scalar_type_handle(Scalar::Scalar(Uint, 4)))
    Dot4I8Packed => Some(self.scalar_type_handle(Scalar::Scalar(Sint, 4)))
    Unpack4x8snorm | Unpack4x8unorm =>
      Some(self.vector_type_handle(Quad, Scalar::Scalar(Float, 4)))
    Unpack2x16snorm | Unpack2x16unorm | Unpack2x16float =>
      Some(self.vector_type_handle(Bi, Scalar::Scalar(Float, 4)))
    Unpack4xI8 => Some(self.vector_type_handle(Quad, Scalar::Scalar(Sint, 4)))
    Unpack4xU8 => Some(self.vector_type_handle(Quad, Scalar::Scalar(Uint, 4)))
    Dot | Distance | Length | Determinant =>
      Some(self.scalar_type_from_composite_type(input_ty))
    Transpose => self.transpose_expression_result_type(input_ty)
    _ => Some(input_ty)
  }
}

///|
fn WgslIrLowerer::transpose_expression_result_type(
  self : WgslIrLowerer,
  input_ty : Handle,
) -> Handle? {
  match self.shader_module.types.get(input_ty) {
    Some(type_) =>
      match type_.inner {
        Matrix(columns, rows, scalar) =>
          Some(self.matrix_type_handle(rows, columns, scalar))
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrLowerer::relational_expression_result_type(
  self : WgslIrLowerer,
  function : Function,
  relational_function : RelationalFunction,
  argument : Handle,
) -> Handle? {
  match relational_function {
    All | Any => Some(self.scalar_type_handle(Scalar::Scalar(Bool, 1)))
    IsNan | IsInf =>
      match self.function_expression_type(function, argument) {
        Some(input_ty) => Some(self.boolean_result_type(input_ty, input_ty))
        None => None
      }
  }
}

///|
fn WgslIrLowerer::binary_expression_result_type(
  self : WgslIrLowerer,
  op : BinaryOperator,
  left_ty : Handle,
  right_ty : Handle,
) -> Handle {
  if wgsl_ir_binary_operator_is_comparison(op) {
    return self.boolean_result_type(left_ty, right_ty)
  }
  if op == BinaryOperator::Multiply {
    match self.matrix_vector_multiply_result_type(left_ty, right_ty) {
      Some(ty) => return ty
      None => ()
    }
  }
  if wgsl_ir_binary_operator_is_arithmetic(op) {
    match self.numeric_binary_scalar_result_type(left_ty, right_ty) {
      Some(ty) => return ty
      None => ()
    }
  }
  if self.type_is_scalar(left_ty) && !self.type_is_scalar(right_ty) {
    return right_ty
  }
  if !self.type_is_scalar(left_ty) && self.type_is_scalar(right_ty) {
    return left_ty
  }
  left_ty
}

///|
fn WgslIrLowerer::matrix_vector_multiply_result_type(
  self : WgslIrLowerer,
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
                Vector(_, _) => Some(self.vector_type_handle(rows, scalar))
                Matrix(columns, right_rows, _) =>
                  if right_rows == left_columns {
                    Some(self.matrix_type_handle(columns, rows, scalar))
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
                Matrix(columns, _, _) =>
                  Some(self.vector_type_handle(columns, scalar))
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
fn WgslIrLowerer::vector_type_handle(
  self : WgslIrLowerer,
  size : VectorSize,
  scalar : Scalar,
) -> Handle {
  self.intern_type(
    "vec\{size.width()}<\{wgsl_ir_scalar_name(scalar.kind, scalar.width)}>",
    TypeInner::Vector(size, scalar),
  )
}

///|
fn WgslIrLowerer::matrix_type_handle(
  self : WgslIrLowerer,
  columns : VectorSize,
  rows : VectorSize,
  scalar : Scalar,
) -> Handle {
  self.intern_type(
    "mat\{columns.width()}x\{rows.width()}<\{wgsl_ir_scalar_name(scalar.kind, scalar.width)}>",
    TypeInner::Matrix(columns, rows, scalar),
  )
}

///|
fn WgslIrLowerer::boolean_result_type(
  self : WgslIrLowerer,
  left_ty : Handle,
  right_ty : Handle,
) -> Handle {
  match self.vector_size_from_type(left_ty) {
    Some(size) => self.boolean_vector_type(size)
    None =>
      match self.vector_size_from_type(right_ty) {
        Some(size) => self.boolean_vector_type(size)
        None => self.scalar_type_handle(Scalar::Scalar(Bool, 1))
      }
  }
}

///|
fn WgslIrLowerer::boolean_vector_type(
  self : WgslIrLowerer,
  size : VectorSize,
) -> Handle {
  self.intern_type(
    "vec\{size.width()}<bool>",
    TypeInner::Vector(size, Scalar::Scalar(Bool, 1)),
  )
}

///|
fn WgslIrLowerer::type_is_scalar(
  self : WgslIrLowerer,
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
fn WgslIrLowerer::vector_size_from_type(
  self : WgslIrLowerer,
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
fn wgsl_ir_binary_operator_is_comparison(op : BinaryOperator) -> Bool {
  match op {
    Equal | NotEqual | Less | LessEqual | Greater | GreaterEqual => true
    _ => false
  }
}

///|
fn WgslIrLowerer::atomic_expression_result_type(
  self : WgslIrLowerer,
  function : Function,
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
          Some(
            self.predeclared_struct_type(AtomicCompareExchangeWeakResult(value)),
          )
        None => None
      }
    _ =>
      match scalar {
        Some(value) => Some(self.scalar_type_handle(value))
        None => None
      }
  }
}

///|
fn WgslIrLowerer::atomic_pointer_scalar_type(
  self : WgslIrLowerer,
  function : Function,
  pointer : Handle,
) -> Scalar? {
  guard self.function_expression_type(function, pointer) is Some(ty_handle) else {
    return None
  }
  self.atomic_scalar_type_from_handle(ty_handle)
}

///|
fn WgslIrLowerer::atomic_scalar_type_from_handle(
  self : WgslIrLowerer,
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
fn WgslIrLowerer::predeclared_numeric_result_type(
  self : WgslIrLowerer,
  input_ty : Handle,
  frexp : Bool,
) -> Handle? {
  match self.shader_module.types.items.get(input_ty.index()) {
    Some(ty) =>
      match ty.inner {
        Scalar(scalar) =>
          if frexp {
            Some(self.predeclared_struct_type(FrexpResult(None, scalar)))
          } else {
            Some(self.predeclared_struct_type(ModfResult(None, scalar)))
          }
        Vector(size, scalar) =>
          if frexp {
            Some(self.predeclared_struct_type(FrexpResult(Some(size), scalar)))
          } else {
            Some(self.predeclared_struct_type(ModfResult(Some(size), scalar)))
          }
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrLowerer::predeclared_modf_result_type(
  self : WgslIrLowerer,
  input_ty : Handle,
) -> Handle? {
  self.predeclared_numeric_result_type(input_ty, false)
}

///|
fn WgslIrLowerer::predeclared_frexp_result_type(
  self : WgslIrLowerer,
  input_ty : Handle,
) -> Handle? {
  self.predeclared_numeric_result_type(input_ty, true)
}

///|
fn WgslIrLowerer::predeclared_struct_type(
  self : WgslIrLowerer,
  predeclared : PredeclaredType,
) -> Handle {
  for item in self.shader_module.special_types.predeclared_types {
    let (existing, handle) = item
    if existing == predeclared {
      return handle
    }
  }
  let handle = self.shader_module.append_type(Type::{
    name: None,
    inner: self.predeclared_type_inner(predeclared),
  })
  self.shader_module.special_types.predeclared_types.push((predeclared, handle))
  handle
}

///|
fn WgslIrLowerer::predeclared_type_inner(
  self : WgslIrLowerer,
  predeclared : PredeclaredType,
) -> TypeInner {
  match predeclared {
    AtomicCompareExchangeWeakResult(scalar) => {
      let value_ty = self.scalar_type_handle(scalar)
      let bool_ty = self.scalar_type_handle(Scalar::Scalar(Bool, 1))
      let value_layout = WgslIrLayout::{
        align: scalar.width,
        size: scalar.width,
      }
      let bool_layout = WgslIrLayout::{ align: 1, size: 1 }
      let exchanged_offset = wgsl_ir_align_to(
        value_layout.size,
        bool_layout.align,
      )
      let span = wgsl_ir_align_to(
        exchanged_offset + bool_layout.size,
        value_layout.align,
      )
      TypeInner::Struct(
        [
          StructMember::{
            name: Some("old_value"),
            ty: value_ty,
            binding: None,
            offset: 0,
            size: None,
            align: None,
          },
          StructMember::{
            name: Some("exchanged"),
            ty: bool_ty,
            binding: None,
            offset: exchanged_offset,
            size: None,
            align: None,
          },
        ],
        span,
      )
    }
    ModfResult(size, scalar) => {
      let value_ty = self.numeric_value_type_handle(size, scalar)
      let value_layout = wgsl_ir_numeric_value_layout(size, scalar)
      let whole_offset = wgsl_ir_align_to(value_layout.size, value_layout.align)
      let span = wgsl_ir_align_to(
        whole_offset + value_layout.size,
        value_layout.align,
      )
      TypeInner::Struct(
        [
          StructMember::{
            name: Some("fract"),
            ty: value_ty,
            binding: None,
            offset: 0,
            size: None,
            align: None,
          },
          StructMember::{
            name: Some("whole"),
            ty: value_ty,
            binding: None,
            offset: whole_offset,
            size: None,
            align: None,
          },
        ],
        span,
      )
    }
    FrexpResult(size, scalar) => {
      let fract_ty = self.numeric_value_type_handle(size, scalar)
      let exponent_scalar = Scalar::Scalar(Sint, 4)
      let exponent_ty = self.numeric_value_type_handle(size, exponent_scalar)
      let fract_layout = wgsl_ir_numeric_value_layout(size, scalar)
      let exponent_layout = wgsl_ir_numeric_value_layout(size, exponent_scalar)
      let exponent_offset = wgsl_ir_align_to(
        fract_layout.size,
        exponent_layout.align,
      )
      let max_align = if fract_layout.align > exponent_layout.align {
        fract_layout.align
      } else {
        exponent_layout.align
      }
      let span = wgsl_ir_align_to(
        exponent_offset + exponent_layout.size,
        max_align,
      )
      TypeInner::Struct(
        [
          StructMember::{
            name: Some("fract"),
            ty: fract_ty,
            binding: None,
            offset: 0,
            size: None,
            align: None,
          },
          StructMember::{
            name: Some("exp"),
            ty: exponent_ty,
            binding: None,
            offset: exponent_offset,
            size: None,
            align: None,
          },
        ],
        span,
      )
    }
  }
}

///|
fn wgsl_ir_numeric_value_layout(
  size : VectorSize?,
  scalar : Scalar,
) -> WgslIrLayout {
  match size {
    Some(vector_size) => {
      let width = vector_size.width()
      let raw = width * scalar.width
      WgslIrLayout::{
        align: if width == 3 {
          4 * scalar.width
        } else {
          raw
        },
        size: raw,
      }
    }
    None => WgslIrLayout::{ align: scalar.width, size: scalar.width }
  }
}

///|
fn WgslIrLowerer::numeric_value_type_handle(
  self : WgslIrLowerer,
  size : VectorSize?,
  scalar : Scalar,
) -> Handle {
  match size {
    Some(vector_size) =>
      self.intern_type(
        "vec\{vector_size.width()}<\{wgsl_ir_scalar_name(scalar.kind, scalar.width)}>",
        TypeInner::Vector(vector_size, scalar),
      )
    None => self.scalar_type_handle(scalar)
  }
}

///|
fn WgslIrLowerer::swizzle_expression_type(
  self : WgslIrLowerer,
  function : Function,
  base : Handle,
  size : VectorSize,
) -> Handle? {
  guard self.function_expression_type(function, base) is Some(base_ty) else {
    return None
  }
  match self.shader_module.types.get(base_ty) {
    Some(ty) =>
      match ty.inner {
        Vector(_, scalar) =>
          Some(
            self.intern_type(
              "vec\{size.width()}<\{wgsl_ir_scalar_name(scalar.kind, scalar.width)}>",
              TypeInner::Vector(size, scalar),
            ),
          )
        _ => None
      }
    None => None
  }
}

///|
