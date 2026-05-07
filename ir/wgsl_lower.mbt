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
  type_cache : @hashmap.HashMap[String, Handle]
  function_names : @hashmap.HashMap[String, Handle]
  global_names : @hashmap.HashMap[String, Handle]
  constant_names : @hashmap.HashMap[String, Handle]
  override_names : @hashmap.HashMap[String, Handle]
  referenced_names : @hashset.HashSet[String]
}

///|
priv struct WgslIrFunctionScope {
  arguments : @hashmap.HashMap[String, Int]
  locals : @hashmap.HashMap[String, Handle]
  local_constants : @hashmap.HashMap[String, Handle]
  local_pointer_expressions : @hashmap.HashMap[String, Handle]
  global_pointer_expressions : @hashmap.HashMap[String, Handle]
  mut temporary_index : Int
}

///|
priv struct WgslIrExprTokenParser {
  tokens : Array[@ast.WgslExprToken]
  mut index : Int
}

///|
fn WgslIrFunctionScope::WgslIrFunctionScope() -> WgslIrFunctionScope {
  WgslIrFunctionScope::{
    arguments: @hashmap.HashMap([]),
    locals: @hashmap.HashMap([]),
    local_constants: @hashmap.HashMap([]),
    local_pointer_expressions: @hashmap.HashMap([]),
    global_pointer_expressions: @hashmap.HashMap([]),
    temporary_index: 0,
  }
}

///|
fn WgslIrFunctionScope::local_pointer_expression(
  self : WgslIrFunctionScope,
  name : String,
  local_handle : Handle,
  function : Function,
) -> Handle {
  match self.local_pointer_expressions.get(name) {
    Some(handle) => handle
    None => {
      let handle = function.expressions.append(
        Expression::LocalVariable(local_handle),
      )
      self.local_pointer_expressions.set(name, handle)
      handle
    }
  }
}

///|
fn WgslIrFunctionScope::global_pointer_expression(
  self : WgslIrFunctionScope,
  name : String,
  global_handle : Handle,
  function : Function,
) -> Handle {
  match self.global_pointer_expressions.get(name) {
    Some(handle) => handle
    None => {
      let handle = function.expressions.append(
        Expression::GlobalVariable(global_handle),
      )
      self.global_pointer_expressions.set(name, handle)
      handle
    }
  }
}

///|
fn WgslIrFunctionScope::next_temporary_name(
  self : WgslIrFunctionScope,
) -> String {
  let name = "_e\{self.temporary_index}"
  self.temporary_index = self.temporary_index + 1
  name
}

///|
fn WgslIrLowerer::WgslIrLowerer() -> WgslIrLowerer {
  WgslIrLowerer::{
    shader_module: Module(),
    type_cache: @hashmap.HashMap([]),
    function_names: @hashmap.HashMap([]),
    global_names: @hashmap.HashMap([]),
    constant_names: @hashmap.HashMap([]),
    override_names: @hashmap.HashMap([]),
    referenced_names: @hashset.HashSet([]),
  }
}

///|
fn wgsl_ir_parse_error_message(error : @parser.WgslParseError) -> String {
  error.message()
}

///|
pub fn parse_wgsl_module_to_ir(
  source : String,
) -> Module raise WgslIrLowerError {
  let unit = @parser.parse_wgsl_translation_unit_strict(source) catch {
    error => raise WgslIrLowerError::Parse(wgsl_ir_parse_error_message(error))
  }
  lower_wgsl_translation_unit_to_ir(unit)
}

///|
pub fn lower_wgsl_translation_unit_to_ir(
  unit : @ast.WgslTranslationUnit,
) -> Module raise WgslIrLowerError {
  let lowerer = WgslIrLowerer()
  lowerer.register_prelude_types()
  for declaration in unit.declarations() {
    lowerer.record_referenced_names(declaration)
  }
  for declaration in unit.declarations() {
    lowerer.predeclare_global_type_declaration(declaration)
  }
  for declaration in unit.declarations() {
    lowerer.predeclare_global_type_alias(declaration)
  }
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
fn WgslIrLowerer::record_referenced_names(
  self : WgslIrLowerer,
  declaration : @ast.WgslGlobalDecl,
) -> Unit {
  let identifiers : Array[@ast.WgslIdent] = []
  @ast.collect_wgsl_decl_identifier_nodes(declaration.data(), identifiers)
  for identifier in identifiers {
    self.referenced_names.add(identifier.name())
  }
}

///|
fn WgslIrLowerer::register_prelude_types(self : WgslIrLowerer) -> Unit {
  ignore(self.intern_type("bool", TypeInner::Scalar(Scalar::Scalar(Bool, 1))))
  ignore(self.intern_type("i32", TypeInner::Scalar(Scalar::Scalar(Sint, 4))))
  let u32_ty = self.intern_type(
    "u32",
    TypeInner::Scalar(Scalar::Scalar(Uint, 4)),
  )
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
          wgsl_ir_synthetic_struct_member("instance_custom_index", u32_ty),
          wgsl_ir_synthetic_struct_member("instance_index", u32_ty),
          wgsl_ir_synthetic_struct_member("sbt_record_offset", u32_ty),
          wgsl_ir_synthetic_struct_member("geometry_index", u32_ty),
          wgsl_ir_synthetic_struct_member("primitive_index", u32_ty),
          wgsl_ir_synthetic_struct_member("barycentrics", vec2_f32_ty),
        ],
        48,
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
  StructMember::{ name: Some(name), ty, binding: None, offset: 0 }
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
    Override(override_decl) =>
      self.predeclare_override_declaration(override_decl)
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
fn WgslIrLowerer::predeclare_override_declaration(
  self : WgslIrLowerer,
  override_decl : @ast.WgslOverride,
) -> Unit raise WgslIrLowerError {
  let ty = match override_decl.ty_ref() {
    Some(ty_ref) => self.lower_type_ref(ty_ref)
    None => self.predeclared_override_fallback_type(override_decl)
  }
  let handle = self.shader_module.append_override(Override::{
    name: Some(override_decl.name().name()),
    id: wgsl_ir_id_from_attributes(override_decl.attributes()),
    ty,
    init: None,
  })
  self.override_names.set(override_decl.name().name(), handle)
}

///|
fn WgslIrLowerer::predeclared_override_fallback_type(
  self : WgslIrLowerer,
  override_decl : @ast.WgslOverride,
) -> Handle raise WgslIrLowerError {
  match override_decl.initializer_ref() {
    Some(expr_ref) =>
      match expr_ref.root() {
        Some(root) =>
          match root.kind() {
            Literal(token) =>
              match token.kind() {
                BoolLiteral(_) => self.lower_builtin_type_name("bool")
                IntLiteral(_) => self.lower_builtin_type_name("__abstract_int")
                UintLiteral(_) => self.lower_builtin_type_name("u32")
                FloatLiteral => self.lower_builtin_type_name("__abstract_float")
                _ => self.lower_builtin_type_name("__abstract_int")
              }
            _ => self.lower_builtin_type_name("__abstract_int")
          }
        None => self.lower_builtin_type_name("__abstract_int")
      }
    None => self.lower_builtin_type_name("__abstract_int")
  }
}

///|
fn WgslIrLowerer::lower_global_declaration(
  self : WgslIrLowerer,
  declaration : @ast.WgslGlobalDecl,
) -> Unit raise WgslIrLowerError {
  match declaration.data() {
    Struct(struct_decl) => self.lower_struct_declaration(struct_decl)
    TypeAlias(alias_decl) => self.lower_type_alias(alias_decl)
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
  guard global.ty_ref() is Some(ty_ref) else {
    raise WgslIrLowerError::MissingType(global.name().name())
  }
  let ty = self.lower_type_ref(ty_ref)
  let init = match global.initializer_ref() {
    Some(expr) =>
      Some(self.lower_global_expression_ref_with_expected(expr, Some(ty)))
    None => None
  }
  let handle = self.shader_module.append_global_variable(GlobalVariable::{
    name: Some(global.name().name()),
    space: self.global_address_space(global.template_list(), ty),
    binding: wgsl_ir_resource_binding_from_attributes(global.attributes()),
    ty,
    init,
    memory_decorations: wgsl_ir_memory_decorations_from_attributes(
      global.attributes(),
    ),
  })
  self.global_names.set(global.name().name(), handle)
}

///|
fn WgslIrLowerer::global_address_space(
  self : WgslIrLowerer,
  template_list : Array[@ast.WgslTypeRef],
  ty : Handle,
) -> AddressSpace {
  if template_list.length() > 0 {
    return wgsl_ir_address_space_from_template_list(template_list)
  }
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Image(_, _, _) | Sampler(_) | AccelerationStructure(_) | RayQuery(_) =>
          Handle
        _ => Private
      }
    None => Private
  }
}

///|
fn WgslIrLowerer::lower_constant(
  self : WgslIrLowerer,
  constant : @ast.WgslConst,
) -> Unit raise WgslIrLowerError {
  let explicit_ty = match constant.ty_ref() {
    Some(ty_ref) => Some(self.lower_type_ref(ty_ref))
    None => None
  }
  let ty = match explicit_ty {
    Some(ty) => ty
    None =>
      self.infer_local_type_from_initializer(
        constant.name().name(),
        constant.initializer_ref(),
      )
  }
  let init = match constant.initializer_ref() {
    Some(expr) =>
      self.lower_global_expression_ref_with_expected(expr, explicit_ty)
    None =>
      self.shader_module.append_global_expression(Expression::ZeroValue(ty))
  }
  let handle = self.shader_module.append_constant(Constant::{
    name: Some(constant.name().name()),
    ty,
    init,
  })
  self.constant_names.set(constant.name().name(), handle)
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
      if !self.referenced_names.contains(function.name().name()) {
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
          mesh_info: None,
          task_payload: None,
          incoming_ray_payload: None,
        })
      }
    None => ()
  }
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
  let ir_function = Function::Function(Some(function.name().name()))
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
  let body = self.lower_block(function.body(), ir_function, scope)
  if result == None && !wgsl_ir_block_ends_with_return(body) {
    body.push(Statement::Return(None))
  }
  Function::{
    name: ir_function.name,
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
fn wgsl_ir_block_ends_with_return(block : Block) -> Bool {
  match block.statements {
    [.., Return(_)] => true
    _ => false
  }
}

///|
fn WgslIrLowerer::lower_block(
  self : WgslIrLowerer,
  block : @ast.WgslBlock,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Block raise WgslIrLowerError {
  let ir_block = Block::Block()
  for statement in block.statements() {
    self.lower_statement(statement, function, scope, ir_block)
  }
  ir_block
}

///|
fn WgslIrLowerer::lower_statement(
  self : WgslIrLowerer,
  statement : @ast.WgslStatement,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
) -> Unit raise WgslIrLowerError {
  match statement.payload() {
    Empty => ()
    Compound =>
      match statement.blocks() {
        [child, ..] =>
          block.push(Statement::Block(self.lower_block(child, function, scope)))
        [] => ()
      }
    LocalDeclaration(locals) =>
      for local_decl in locals {
        self.lower_local_declaration(local_decl, function, scope, block)
      }
    Return(expr) => {
      let value = match expr {
        Some(expr_ref) => {
          let handle = self.lower_function_expression_ref(
            expr_ref, function, scope,
          )
          Some(
            self.materialize_return_expression_if_needed(
              function, scope, block, handle,
            ),
          )
        }
        None => None
      }
      block.push(Statement::Return(value))
    }
    If(condition) => {
      guard condition is Some(condition_ref) else {
        raise WgslIrLowerError::UnsupportedStatement("if without condition")
      }
      let condition_handle = self.lower_function_expression_ref(
        condition_ref, function, scope,
      )
      let then_block = match statement.blocks() {
        [then_child, ..] => self.lower_block(then_child, function, scope)
        [] => Block::Block()
      }
      let else_block = match statement.blocks() {
        [_, else_child, ..] => self.lower_block(else_child, function, scope)
        _ => Block::Block()
      }
      block.push(Statement::If(condition_handle, then_block, else_block))
    }
    While(condition) => {
      guard condition is Some(condition_ref) else {
        raise WgslIrLowerError::UnsupportedStatement("while without condition")
      }
      let cond = self.lower_function_expression_ref(
        condition_ref, function, scope,
      )
      let body = match statement.blocks() {
        [body_block, ..] => self.lower_block(body_block, function, scope)
        [] => Block::Block()
      }
      let continuing = Block::Block()
      continuing.push(
        Statement::If(cond, Block::Block(), Block::{
          statements: [Statement::Break],
        }),
      )
      block.push(Statement::Loop(body, continuing, None))
    }
    Loop => {
      let body = match statement.blocks() {
        [body_block, ..] => self.lower_block(body_block, function, scope)
        [] => Block::Block()
      }
      let continuing = match statement.blocks() {
        [_, continuing_block, ..] =>
          self.lower_block(continuing_block, function, scope)
        _ => Block::Block()
      }
      block.push(Statement::Loop(body, continuing, None))
    }
    Break(_) => block.push(Statement::Break)
    Continue => block.push(Statement::Continue)
    Discard => block.push(Statement::Kill)
    Assignment(op, lhs, rhs) => {
      guard lhs is Some(lhs_ref) else {
        raise WgslIrLowerError::UnsupportedStatement("assignment without lhs")
      }
      guard rhs is Some(rhs_ref) else {
        raise WgslIrLowerError::UnsupportedStatement("assignment without rhs")
      }
      if wgsl_ir_expr_ref_is_phony(lhs_ref) {
        if self.lower_ray_query_statement_expr_ref(
            rhs_ref, function, scope, block,
          ) {
          return
        }
        let rhs_value = self.lower_function_expression_ref(
          rhs_ref, function, scope,
        )
        block.push(Statement::Emit(HandleRange(rhs_value, rhs_value)))
        return
      }
      let target = self.lower_function_lvalue_ref(lhs_ref, function, scope)
      let value = match wgsl_ir_compound_assignment_operator(op) {
        Some(binary_op) => {
          let loaded_target = function.expressions.append(
            Expression::Load(target),
          )
          let materialized_target = self.materialize_function_expression(
            function, scope, block, loaded_target,
          )
          let rhs_value = self.lower_function_expression_ref(
            rhs_ref, function, scope,
          )
          let rhs_value = self.materialize_side_effecting_expression(
            function, scope, block, rhs_value,
          )
          function.expressions.append(
            Expression::Binary(binary_op, materialized_target, rhs_value),
          )
        }
        None => self.lower_function_expression_ref(rhs_ref, function, scope)
      }
      block.push(Statement::Store(target, value))
    }
    Increment(target) =>
      self.lower_update_statement(target, function, scope, block, true)
    Decrement(target) =>
      self.lower_update_statement(target, function, scope, block, false)
    FunctionCall(expr) => {
      guard expr is Some(expr_ref) else {
        raise WgslIrLowerError::UnsupportedStatement(
          "function call without expression",
        )
      }
      self.lower_call_statement(expr_ref, function, scope, block)
    }
    Expression(expr) =>
      match expr {
        Some(expr_ref) =>
          if self.lower_ray_query_statement_expr_ref(
              expr_ref, function, scope, block,
            ) {
            ()
          } else if wgsl_ir_expr_ref_is_call(expr_ref) {
            self.lower_call_statement(expr_ref, function, scope, block)
          } else {
            let handle = self.lower_function_expression_ref(
              expr_ref, function, scope,
            )
            block.push(Statement::Emit(HandleRange(handle, handle)))
          }
        None => ()
      }
    ConstAssert(expr) => {
      guard expr is Some(expr_ref) else {
        raise WgslIrLowerError::UnsupportedStatement(
          "const_assert without expression",
        )
      }
      block.push(
        Statement::ConstAssert(
          self.lower_function_expression_ref(expr_ref, function, scope),
        ),
      )
    }
    For(expressions) =>
      self.lower_for_statement(statement, expressions, function, scope, block)
    Switch(selector) => {
      guard selector is Some(selector_ref) else {
        raise WgslIrLowerError::UnsupportedStatement("switch without selector")
      }
      let selector_handle = self.lower_function_expression_ref(
        selector_ref, function, scope,
      )
      let cases : Array[SwitchCase] = []
      match statement.blocks() {
        [switch_block, ..] =>
          self.lower_switch_cases(switch_block, function, scope, cases)
        [] => ()
      }
      block.push(Statement::Switch(selector_handle, cases))
    }
    Case(_) | DefaultCase =>
      raise WgslIrLowerError::UnsupportedStatement(
        "structured statement not yet representable by this WGSL IR lowerer",
      )
  }
}

///|
fn WgslIrLowerer::lower_ray_query_statement_expr_ref(
  self : WgslIrLowerer,
  expr_ref : @ast.WgslExprRef,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
) -> Bool raise WgslIrLowerError {
  match expr_ref.root() {
    Some(root) =>
      self.lower_ray_query_statement_node(root, function, scope, block)
    None => false
  }
}

///|
fn WgslIrLowerer::lower_ray_query_statement_node(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
) -> Bool raise WgslIrLowerError {
  match node.kind() {
    Group(inner) =>
      self.lower_ray_query_statement_node(inner, function, scope, block)
    Sequence([single]) =>
      self.lower_ray_query_statement_node(single, function, scope, block)
    Call(callee, arguments) =>
      match callee.kind() {
        Identifier(name) =>
          self.lower_ray_query_statement_call(
            name.name(),
            arguments,
            function,
            scope,
            block,
          )
        _ => false
      }
    _ => false
  }
}

///|
fn wgsl_ir_expr_ref_is_call(expr_ref : @ast.WgslExprRef) -> Bool {
  match expr_ref.root() {
    Some(root) => wgsl_ir_expr_node_is_call(root)
    None => false
  }
}

///|
fn wgsl_ir_expr_node_is_call(node : @ast.WgslExprNode) -> Bool {
  match node.kind() {
    Call(_, _) => true
    Group(inner) => wgsl_ir_expr_node_is_call(inner)
    Sequence([single]) => wgsl_ir_expr_node_is_call(single)
    _ => false
  }
}

///|
fn WgslIrLowerer::lower_for_statement(
  self : WgslIrLowerer,
  statement : @ast.WgslStatement,
  expressions : Array[@ast.WgslStatementExpression],
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
) -> Unit raise WgslIrLowerError {
  for local_decl in statement.local_bindings() {
    self.lower_local_declaration(local_decl, function, scope, block)
  }
  for expr in expressions {
    if expr.role() == @ast.WgslStatementExpressionRole::ForInitializer {
      self.lower_for_header_statement(expr.expression(), function, scope, block)
    }
  }
  let loop_body = Block::Block()
  match
    wgsl_ir_for_expression_by_role(
      expressions,
      @ast.WgslStatementExpressionRole::ForCondition,
    ) {
    Some(condition_ref) => {
      let condition = self.lower_function_expression_ref(
        condition_ref, function, scope,
      )
      let not_condition = function.expressions.append(
        Expression::Unary(UnaryOperator::LogicalNot, condition),
      )
      loop_body.push(
        Statement::If(
          not_condition,
          Block::{ statements: [Statement::Break] },
          Block::Block(),
        ),
      )
    }
    None => ()
  }
  match statement.blocks() {
    [body_block, ..] => {
      let body = self.lower_block(body_block, function, scope)
      for body_statement in body.statements {
        loop_body.push(body_statement)
      }
    }
    [] => ()
  }
  let continuing = Block::Block()
  for expr in expressions {
    if expr.role() == @ast.WgslStatementExpressionRole::ForUpdate {
      self.lower_for_header_statement(
        expr.expression(),
        function,
        scope,
        continuing,
      )
    }
  }
  block.push(Statement::Loop(loop_body, continuing, None))
}

///|
fn wgsl_ir_for_expression_by_role(
  expressions : Array[@ast.WgslStatementExpression],
  role : @ast.WgslStatementExpressionRole,
) -> @ast.WgslExprRef? {
  for expr in expressions {
    if expr.role() == role {
      return Some(expr.expression())
    }
  }
  None
}

///|
fn WgslIrLowerer::lower_switch_cases(
  self : WgslIrLowerer,
  switch_block : @ast.WgslBlock,
  function : Function,
  scope : WgslIrFunctionScope,
  cases : Array[SwitchCase],
) -> Unit raise WgslIrLowerError {
  for statement in switch_block.statements() {
    match statement.payload() {
      Case(selectors) => {
        let body = match statement.blocks() {
          [case_block, ..] => self.lower_block(case_block, function, scope)
          [] => Block::Block()
        }
        for selector in selectors {
          match selector {
            DefaultSelector =>
              cases.push(SwitchCase::{
                value: Default,
                body,
                fall_through: false,
              })
            ExpressionSelector(expr) => {
              let selector_handle = self.lower_function_expression_ref(
                expr, function, scope,
              )
              cases.push(SwitchCase::{
                value: wgsl_ir_switch_value_from_expression(
                  self, function, selector_handle,
                ),
                body,
                fall_through: false,
              })
            }
          }
        }
      }
      DefaultCase => {
        let body = match statement.blocks() {
          [case_block, ..] => self.lower_block(case_block, function, scope)
          [] => Block::Block()
        }
        cases.push(SwitchCase::{ value: Default, body, fall_through: false })
      }
      Empty => ()
      _ =>
        raise WgslIrLowerError::UnsupportedStatement(
          "switch body contains non-case statement",
        )
    }
  }
}

///|
fn wgsl_ir_switch_value_from_expression(
  lowerer : WgslIrLowerer,
  function : Function,
  handle : Handle,
) -> SwitchValue raise WgslIrLowerError {
  match function.expressions.items.get(handle.index()) {
    Some(Expression::Literal(Literal::I32(value))) => SwitchValue::I32(value)
    Some(Expression::Literal(Literal::U32(value))) => SwitchValue::U32(value)
    Some(Expression::Constant(const_handle)) =>
      lowerer.switch_value_from_constant(const_handle)
    _ =>
      raise WgslIrLowerError::UnsupportedExpression(
        "switch case selector must lower to an integer literal",
      )
  }
}

///|
fn WgslIrLowerer::switch_value_from_constant(
  self : WgslIrLowerer,
  handle : Handle,
) -> SwitchValue raise WgslIrLowerError {
  match self.shader_module.constants.items.get(handle.index()) {
    Some(constant) => {
      let (value, unsigned) = self.eval_global_integer_expression(constant.init)
      if unsigned {
        let parsed : UInt = @strconv.from_str("\{value}") catch {
          _ =>
            raise WgslIrLowerError::UnsupportedExpression(
              "switch case const selector is outside u32 range",
            )
        }
        SwitchValue::U32(parsed)
      } else {
        SwitchValue::I32(value)
      }
    }
    None =>
      raise WgslIrLowerError::UnsupportedExpression(
        "switch case selector references missing const",
      )
  }
}

///|
fn WgslIrLowerer::eval_global_integer_expression(
  self : WgslIrLowerer,
  handle : Handle,
) -> (Int, Bool) raise WgslIrLowerError {
  match self.shader_module.global_expressions.items.get(handle.index()) {
    Some(expression) => self.eval_global_integer_expression_inner(expression)
    None =>
      raise WgslIrLowerError::UnsupportedExpression(
        "switch case selector references missing expression",
      )
  }
}

///|
fn WgslIrLowerer::eval_global_integer_expression_inner(
  self : WgslIrLowerer,
  expression : Expression,
) -> (Int, Bool) raise WgslIrLowerError {
  match expression {
    Literal(Literal::I32(value)) => (value, false)
    Literal(Literal::U32(value)) => (value.reinterpret_as_int(), true)
    Literal(Literal::AbstractInt(value)) => (value.to_int(), false)
    Constant(handle) =>
      match self.shader_module.constants.items.get(handle.index()) {
        Some(constant) => self.eval_global_integer_expression(constant.init)
        None =>
          raise WgslIrLowerError::UnsupportedExpression(
            "switch case selector references missing nested const",
          )
      }
    Binary(op, left, right) => {
      let (left_value, left_unsigned) = self.eval_global_integer_expression(
        left,
      )
      let (right_value, right_unsigned) = self.eval_global_integer_expression(
        right,
      )
      (
        wgsl_ir_eval_integer_binary(op, left_value, right_value),
        left_unsigned || right_unsigned,
      )
    }
    Math(MathFunction::Min, a, Some(b), None, None) => {
      let (a_value, a_unsigned) = self.eval_global_integer_expression(a)
      let (b_value, b_unsigned) = self.eval_global_integer_expression(b)
      let value = if a_value < b_value { a_value } else { b_value }
      (value, a_unsigned || b_unsigned)
    }
    Math(MathFunction::Max, a, Some(b), None, None) => {
      let (a_value, a_unsigned) = self.eval_global_integer_expression(a)
      let (b_value, b_unsigned) = self.eval_global_integer_expression(b)
      let value = if a_value > b_value { a_value } else { b_value }
      (value, a_unsigned || b_unsigned)
    }
    Math(MathFunction::Clamp, value, Some(low), Some(high), None) => {
      let (value, value_unsigned) = self.eval_global_integer_expression(value)
      let (low, low_unsigned) = self.eval_global_integer_expression(low)
      let (high, high_unsigned) = self.eval_global_integer_expression(high)
      let clamped = if value < low {
        low
      } else if value > high {
        high
      } else {
        value
      }
      (clamped, value_unsigned || low_unsigned || high_unsigned)
    }
    Unary(UnaryOperator::Negate, inner) => {
      let (value, _) = self.eval_global_integer_expression(inner)
      (-value, false)
    }
    Unary(UnaryOperator::BitwiseNot, inner) => {
      let (value, unsigned) = self.eval_global_integer_expression(inner)
      (value.lnot(), unsigned)
    }
    _ =>
      raise WgslIrLowerError::UnsupportedExpression(
        "switch case const selector must initialize to an integer expression",
      )
  }
}

///|
fn wgsl_ir_eval_integer_binary(
  op : BinaryOperator,
  left : Int,
  right : Int,
) -> Int raise WgslIrLowerError {
  match op {
    Add => left + right
    Subtract => left - right
    Multiply => left * right
    Divide => left / right
    Modulo => left % right
    And => left & right
    ExclusiveOr => left ^ right
    InclusiveOr => left | right
    ShiftLeft => left << right
    ShiftRight => left >> right
    _ =>
      raise WgslIrLowerError::UnsupportedExpression(
        "switch case const selector uses non-integer binary operator",
      )
  }
}

///|
fn WgslIrLowerer::fold_function_constant_float_expression(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle,
) -> Literal? {
  match self.eval_function_float_expression(function, handle) {
    Some(value) => Some(Literal::AbstractFloat(value))
    None => None
  }
}

///|
fn WgslIrLowerer::eval_function_float_expression(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle,
) -> Double? {
  match function.expressions.items.get(handle.index()) {
    Some(expression) =>
      self.eval_function_float_expression_inner(function, expression)
    None => None
  }
}

///|
fn WgslIrLowerer::eval_function_float_expression_inner(
  self : WgslIrLowerer,
  function : Function,
  expression : Expression,
) -> Double? {
  match expression {
    Literal(Literal::AbstractFloat(value)) => Some(value)
    Constant(handle) => self.eval_constant_float_expression(handle)
    Binary(op, left, right) => {
      guard self.eval_function_float_expression(function, left)
        is Some(left_value) else {
        return None
      }
      guard self.eval_function_float_expression(function, right)
        is Some(right_value) else {
        return None
      }
      wgsl_ir_eval_float_binary(op, left_value, right_value)
    }
    _ => None
  }
}

///|
fn WgslIrLowerer::eval_constant_float_expression(
  self : WgslIrLowerer,
  handle : Handle,
) -> Double? {
  match self.shader_module.constants.items.get(handle.index()) {
    Some(constant) => self.eval_global_float_expression(constant.init)
    None => None
  }
}

///|
fn WgslIrLowerer::eval_global_float_expression(
  self : WgslIrLowerer,
  handle : Handle,
) -> Double? {
  match self.shader_module.global_expressions.items.get(handle.index()) {
    Some(expression) => self.eval_global_float_expression_inner(expression)
    None => None
  }
}

///|
fn WgslIrLowerer::eval_global_float_expression_inner(
  self : WgslIrLowerer,
  expression : Expression,
) -> Double? {
  match expression {
    Literal(Literal::AbstractFloat(value)) => Some(value)
    Constant(handle) => self.eval_constant_float_expression(handle)
    Binary(op, left, right) => {
      guard self.eval_global_float_expression(left) is Some(left_value) else {
        return None
      }
      guard self.eval_global_float_expression(right) is Some(right_value) else {
        return None
      }
      wgsl_ir_eval_float_binary(op, left_value, right_value)
    }
    _ => None
  }
}

///|
fn wgsl_ir_eval_float_binary(
  op : BinaryOperator,
  left : Double,
  right : Double,
) -> Double? {
  match op {
    Add => Some(left + right)
    Subtract => Some(left - right)
    Multiply => Some(left * right)
    Divide => Some(left / right)
    _ => None
  }
}

///|
fn WgslIrLowerer::lower_for_header_statement(
  self : WgslIrLowerer,
  expr_ref : @ast.WgslExprRef,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
) -> Unit raise WgslIrLowerError {
  let tokens = expr_ref.tokens()
  match wgsl_ir_expr_tokens_update_operator(tokens) {
    Some((target_tokens, increment)) => {
      let target = self.lower_function_lvalue_node(
        wgsl_ir_expr_node_from_tokens(target_tokens),
        function,
        scope,
      )
      self.lower_update_handle(target, function, block, increment)
      return
    }
    None => ()
  }
  match wgsl_ir_expr_tokens_assignment(tokens) {
    Some((op, lhs_tokens, rhs_tokens)) => {
      if wgsl_ir_expr_tokens_are_phony(lhs_tokens) {
        let rhs_value = self.lower_function_expression_node(
          wgsl_ir_expr_node_from_tokens(rhs_tokens),
          function,
          scope,
        )
        block.push(Statement::Emit(HandleRange(rhs_value, rhs_value)))
        return
      }
      let target = self.lower_function_lvalue_node(
        wgsl_ir_expr_node_from_tokens(lhs_tokens),
        function,
        scope,
      )
      let value = match wgsl_ir_compound_assignment_operator(op) {
        Some(binary_op) => {
          let loaded_target = function.expressions.append(
            Expression::Load(target),
          )
          let materialized_target = self.materialize_function_expression(
            function, scope, block, loaded_target,
          )
          let rhs_value = self.lower_function_expression_node(
            wgsl_ir_expr_node_from_tokens(rhs_tokens),
            function,
            scope,
          )
          function.expressions.append(
            Expression::Binary(binary_op, materialized_target, rhs_value),
          )
        }
        None =>
          self.lower_function_expression_node(
            wgsl_ir_expr_node_from_tokens(rhs_tokens),
            function,
            scope,
          )
      }
      block.push(Statement::Store(target, value))
      return
    }
    None => ()
  }
  ignore(self.lower_function_expression_ref(expr_ref, function, scope))
}

///|
fn WgslIrLowerer::lower_local_declaration(
  self : WgslIrLowerer,
  local_decl : @ast.WgslLocalDeclaration,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
) -> Unit raise WgslIrLowerError {
  if local_decl.kind() == @ast.WgslLocalDeclarationKind::Const {
    self.lower_local_const_declaration(local_decl, function, scope)
    return
  }
  let explicit_ty = match local_decl.ty_ref() {
    Some(ty_ref) => Some(self.lower_type_ref(ty_ref))
    None => None
  }
  let mut address_of_ty : Handle? = None
  let mut preserve_source_let_name = false
  let mut init = match local_decl.initializer_ref() {
    Some(expr_ref) =>
      match wgsl_ir_address_of_operand_ref(expr_ref) {
        Some(target_ref) => {
          let target = self.lower_function_lvalue_node(
            target_ref, function, scope,
          )
          let pointer_ty = self.pointer_type_for_lvalue(function, target)
          address_of_ty = Some(pointer_ty)
          Some(
            function.expressions.append(
              Expression::AddressOf(pointer_ty, target),
            ),
          )
        }
        None =>
          Some(
            self.lower_function_expression_ref_with_expected(
              expr_ref, function, scope, explicit_ty,
            ),
          )
      }
    None => None
  }
  if local_decl.kind() == @ast.WgslLocalDeclarationKind::Let {
    match init {
      Some(init_handle) => {
        let materialized = self.materialize_return_subexpressions(
          function, scope, block, init_handle,
        )
        if materialized != init_handle {
          init = Some(materialized)
          preserve_source_let_name = true
        }
      }
      None => ()
    }
  }
  let ty = match explicit_ty {
    Some(ty) => ty
    None =>
      match address_of_ty {
        Some(pointer_ty) => pointer_ty
        None =>
          match init {
            Some(init_handle) =>
              match self.address_of_expression_type(function, init_handle) {
                Some(inferred) => inferred
                None =>
                  match self.function_expression_type(function, init_handle) {
                    Some(inferred) => inferred
                    None =>
                      self.infer_local_type_from_initializer(
                        local_decl.name().name(),
                        local_decl.initializer_ref(),
                      )
                  }
              }
            None =>
              self.infer_local_type_from_initializer(
                local_decl.name().name(),
                local_decl.initializer_ref(),
              )
          }
      }
  }
  let ty = self.local_declaration_storage_type(local_decl.kind(), ty)
  let lowered_name = if local_decl.kind() == @ast.WgslLocalDeclarationKind::Let {
    if preserve_source_let_name {
      local_decl.name().name()
    } else {
      match init {
        Some(init_handle) =>
          self.function_expression_temporary_name(function, init_handle)
        None => scope.next_temporary_name()
      }
    }
  } else {
    local_decl.name().name()
  }
  let handle = function.local_variables.append(LocalVariable::{
    name: Some(lowered_name),
    kind: wgsl_ir_local_variable_kind(local_decl.kind()),
    ty,
    init: if local_decl.kind() == @ast.WgslLocalDeclarationKind::Var &&
      self.function_expression_is_side_effecting(function, init) {
      None
    } else {
      init
    },
  })
  ignore(scope.local_constants.remove(local_decl.name().name()))
  ignore(scope.local_pointer_expressions.remove(local_decl.name().name()))
  scope.locals.set(local_decl.name().name(), handle)
  block.push(Statement::Declare(handle))
  if local_decl.kind() == @ast.WgslLocalDeclarationKind::Var {
    match init {
      Some(init_handle) =>
        if self.function_expression_is_side_effecting(
            function,
            Some(init_handle),
          ) {
          let materialized = self.materialize_side_effecting_expression(
            function, scope, block, init_handle,
          )
          block.push(
            Statement::Store(
              scope.local_pointer_expression(
                local_decl.name().name(),
                handle,
                function,
              ),
              materialized,
            ),
          )
        }
      _ => ()
    }
  }
}

///|
fn WgslIrLowerer::local_declaration_storage_type(
  self : WgslIrLowerer,
  kind : @ast.WgslLocalDeclarationKind,
  ty : Handle,
) -> Handle {
  match kind {
    Var => self.concretize_abstract_storage_type(ty)
    Let | Const => ty
  }
}

///|
fn WgslIrLowerer::concretize_abstract_storage_type(
  self : WgslIrLowerer,
  ty : Handle,
) -> Handle {
  match self.shader_module.types.items.get(ty.index()) {
    Some(type_) =>
      match type_.inner {
        Scalar(scalar) =>
          match self.concretize_abstract_storage_scalar(scalar) {
            Some(concrete) => self.scalar_type_handle(concrete)
            None => ty
          }
        Vector(size, scalar) =>
          match self.concretize_abstract_storage_scalar(scalar) {
            Some(concrete) => self.vector_type_handle(size, concrete)
            None => ty
          }
        Matrix(columns, rows, scalar) =>
          match self.concretize_abstract_storage_scalar(scalar) {
            Some(concrete) =>
              self.intern_type(
                "mat\{columns.width()}x\{rows.width()}<\{wgsl_ir_scalar_name(concrete.kind, concrete.width)}>",
                TypeInner::Matrix(columns, rows, concrete),
              )
            None => ty
          }
        _ => ty
      }
    None => ty
  }
}

///|
fn WgslIrLowerer::concretize_abstract_storage_scalar(
  self : WgslIrLowerer,
  scalar : Scalar,
) -> Scalar? {
  ignore(self)
  match scalar.kind {
    AbstractInt => Some(Scalar::Scalar(Sint, 4))
    AbstractFloat => Some(Scalar::Scalar(Float, 4))
    _ => None
  }
}

///|
fn WgslIrLowerer::function_expression_temporary_name(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle,
) -> String {
  ignore(self)
  let index = wgsl_ir_function_expression_semantic_index(function, handle)
  let index = if wgsl_ir_function_expression_is_adjacent_materialized_load_after_local_snapshot(
      function, handle,
    ) {
    index - 1
  } else {
    index
  }
  "_e\{index}"
}

///|
fn wgsl_ir_function_expression_semantic_index(
  function : Function,
  handle : Handle,
) -> Int {
  let mut skipped = 0
  for index in 0..<handle.index() {
    if wgsl_ir_function_expression_is_synthetic_local_reference(
        function,
        Handle::Handle(index),
      ) ||
      wgsl_ir_function_expression_is_atomic_compare_exchange_projection_role(
        function,
        Handle::Handle(index),
      ) {
      skipped += 1
    }
  }
  handle.index() - skipped
}

///|
fn wgsl_ir_function_expression_is_adjacent_materialized_load_after_local_snapshot(
  function : Function,
  handle : Handle,
) -> Bool {
  if handle.index() == 0 {
    return false
  }
  guard function.expressions.items.get(handle.index()) is Some(Load(_)) else {
    return false
  }
  guard function.expressions.items.get(handle.index() - 1)
    is Some(LocalVariable(local_handle)) else {
    return false
  }
  guard function.local_variables.items.get(local_handle.index())
    is Some(local_var) else {
    return false
  }
  guard local_var.kind == Let else { return false }
  guard local_var.name is Some(name) else { return false }
  guard name.length() >= 2 && name[0:2] == "_e" else { return false }
  match local_var.init {
    Some(init) =>
      match function.expressions.items.get(init.index()) {
        Some(Load(_)) => true
        _ => false
      }
    None => false
  }
}

///|
fn wgsl_ir_function_expression_is_atomic_compare_exchange_projection_role(
  function : Function,
  handle : Handle,
) -> Bool {
  wgsl_ir_function_expression_is_atomic_compare_exchange_result_projection(
    function, handle,
  ) ||
  wgsl_ir_function_expression_is_atomic_compare_exchange_old_value_base_load(
    function, handle,
  )
}

///|
fn wgsl_ir_function_expression_is_atomic_compare_exchange_result_projection(
  function : Function,
  handle : Handle,
) -> Bool {
  match function.expressions.items.get(handle.index()) {
    Some(AccessIndex(base, _)) =>
      match function.expressions.items.get(base.index()) {
        Some(Load(inner)) =>
          wgsl_ir_function_expression_is_atomic_compare_exchange_result_ref(
            function, inner,
          )
        _ => false
      }
    _ => false
  }
}

///|
fn wgsl_ir_function_expression_is_atomic_compare_exchange_old_value_base_load(
  function : Function,
  handle : Handle,
) -> Bool {
  guard function.expressions.items.get(handle.index()) is Some(Load(inner)) else {
    return false
  }
  guard wgsl_ir_function_expression_is_atomic_compare_exchange_result_ref(
    function, inner,
  ) else {
    return false
  }
  match function.expressions.items.get(handle.index() + 1) {
    Some(AccessIndex(base, 0)) => base == handle
    _ => false
  }
}

///|
fn wgsl_ir_function_expression_is_atomic_compare_exchange_result_ref(
  function : Function,
  handle : Handle,
) -> Bool {
  match function.expressions.items.get(handle.index()) {
    Some(LocalVariable(local_handle)) =>
      match function.local_variables.items.get(local_handle.index()) {
        Some(local_var) =>
          match local_var.init {
            Some(init) =>
              match function.expressions.items.get(init.index()) {
                Some(AtomicCall(CompareExchangeWeak, _)) => true
                _ => false
              }
            None => false
          }
        None => false
      }
    _ => false
  }
}

///|
fn wgsl_ir_function_expression_is_synthetic_local_reference(
  function : Function,
  handle : Handle,
) -> Bool {
  match function.expressions.items.get(handle.index()) {
    Some(LocalVariable(local_handle)) =>
      match function.local_variables.items.get(local_handle.index()) {
        Some(local_var) =>
          if local_var.kind != Let {
            false
          } else {
            match local_var.name {
              Some(name) =>
                name.length() >= 2 &&
                name[0:2] == "_e" &&
                wgsl_ir_local_variable_initializes_side_effecting_expression(
                  function, local_var,
                )
              None => false
            }
          }
        None => false
      }
    _ => false
  }
}

///|
fn wgsl_ir_local_variable_initializes_side_effecting_expression(
  function : Function,
  local_var : LocalVariable,
) -> Bool {
  match local_var.init {
    Some(init) =>
      match function.expressions.items.get(init.index()) {
        Some(AtomicCall(function_, _)) =>
          match function_ {
            Load
            | Add
            | Subtract
            | And
            | ExclusiveOr
            | InclusiveOr
            | Min
            | Max
            | Exchange
            | CompareExchangeWeak => true
            Store => false
          }
        _ => false
      }
    None => false
  }
}

///|
fn WgslIrLowerer::materialize_function_expression(
  self : WgslIrLowerer,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
  value : Handle,
) -> Handle raise WgslIrLowerError {
  let ty = match self.function_expression_type(function, value) {
    Some(ty) => ty
    None =>
      raise WgslIrLowerError::MissingType(
        "\{self.function_expression_temporary_name(function, value)}: \{wgsl_ir_function_expression_debug(function, value)}",
      )
  }
  let local_handle = function.local_variables.append(LocalVariable::{
    name: Some(self.function_expression_temporary_name(function, value)),
    kind: Let,
    ty,
    init: Some(value),
  })
  ignore(scope)
  block.push(Statement::Declare(local_handle))
  function.expressions.append(Expression::LocalVariable(local_handle))
}

///|
fn wgsl_ir_function_expression_debug(
  function : Function,
  value : Handle,
) -> String {
  match function.expressions.items.get(value.index()) {
    Some(expression) =>
      match expression {
        Literal(_) => "literal"
        Constant(_) => "constant"
        Override(_) => "override"
        ZeroValue(_) => "zero-value"
        Compose(_, _) => "compose"
        Access(_, _) => "access"
        AccessIndex(_, _) => "access-index"
        Splat(_, _) => "splat"
        Swizzle(_, _, _) => "swizzle"
        FunctionArgument(_) => "function-argument"
        GlobalVariable(_) => "global-variable"
        LocalVariable(_) => "local-variable"
        Load(inner) =>
          "load(\{wgsl_ir_function_expression_debug(function, inner)})"
        AddressOf(_, _) => "address-of"
        AtomicCall(_, _) => "atomic-call"
        ImageSample(_, _, _, _, _, _, _, _, _) => "image-sample"
        ImageLoad(_, _, _, _, _) => "image-load"
        ImageQuery(_, _) => "image-query"
        Unary(_, _) => "unary"
        Binary(_, _, _) => "binary"
        FunctionCall(_, _) => "function-call"
        Select(_, _, _) => "select"
        Bitcast(_, _) => "bitcast"
        Derivative(_, _, _) => "derivative"
        Relational(_, _) => "relational"
        Math(_, _, _, _, _) => "math"
        As(_, _, _) => "as"
        CallResult(_) => "call-result"
        AtomicResult(_, _) => "atomic-result"
        WorkGroupUniformLoadResult(_) => "workgroup-uniform-load-result"
        ArrayLength(_) => "array-length"
        RayQueryInitialize(_, _, _) => "ray-query-initialize"
        RayQueryProceed(_) => "ray-query-proceed"
        RayQueryGenerateIntersection(_, _) => "ray-query-generate-intersection"
        RayQueryConfirmIntersection(_) => "ray-query-confirm-intersection"
        RayQueryTerminate(_) => "ray-query-terminate"
        RayQueryVertexPositions(_, _) => "ray-query-vertex-positions"
        RayQueryProceedResult => "ray-query-proceed-result"
        RayQueryGetIntersection(_, _) => "ray-query-get-intersection"
        SubgroupBallotResult => "subgroup-ballot-result"
        SubgroupOperationResult(_) => "subgroup-operation-result"
        CooperativeLoad(_, _, _, _) => "cooperative-load"
        CooperativeMultiplyAdd(_, _, _) => "cooperative-multiply-add"
      }
    None => "missing expression handle \{value.index()}"
  }
}

///|
fn WgslIrLowerer::materialize_return_expression_if_needed(
  self : WgslIrLowerer,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
  value : Handle,
) -> Handle raise WgslIrLowerError {
  let normalized = self.materialize_return_subexpressions(
    function, scope, block, value,
  )
  if self.function_expression_can_return_directly(function, normalized) {
    normalized
  } else {
    self.materialize_function_expression(function, scope, block, normalized)
  }
}

///|
fn WgslIrLowerer::materialize_return_subexpressions(
  self : WgslIrLowerer,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
  value : Handle,
) -> Handle raise WgslIrLowerError {
  match function.expressions.items.get(value.index()) {
    Some(Compose(ty, components)) => {
      let lowered : Array[Handle] = []
      let mut changed = false
      for component in components {
        let lowered_component = self.materialize_nested_constructor_argument(
          function, scope, block, component,
        )
        if lowered_component != component {
          changed = true
        }
        lowered.push(lowered_component)
      }
      if changed {
        function.expressions.append(Expression::Compose(ty, lowered))
      } else {
        value
      }
    }
    Some(Binary(op, left, right)) => {
      let lowered_left = self.materialize_nested_return_argument(
        function, scope, block, left,
      )
      let lowered_right = self.materialize_nested_return_argument(
        function, scope, block, right,
      )
      if lowered_left != left || lowered_right != right {
        function.expressions.append(
          Expression::Binary(op, lowered_left, lowered_right),
        )
      } else {
        value
      }
    }
    Some(Access(base, index)) => {
      let lowered_base = self.materialize_nested_access_base(
        function, scope, block, base,
      )
      let lowered_index = self.materialize_return_subexpressions(
        function, scope, block, index,
      )
      if lowered_base != base || lowered_index != index {
        function.expressions.append(
          Expression::Access(lowered_base, lowered_index),
        )
      } else {
        value
      }
    }
    Some(AccessIndex(base, index)) => {
      let lowered_base = self.materialize_nested_access_base(
        function, scope, block, base,
      )
      if lowered_base != base {
        function.expressions.append(
          Expression::AccessIndex(lowered_base, index),
        )
      } else {
        value
      }
    }
    Some(Swizzle(size, base, pattern)) => {
      let lowered_base = self.materialize_nested_access_base(
        function, scope, block, base,
      )
      if lowered_base != base {
        function.expressions.append(
          Expression::Swizzle(size, lowered_base, pattern),
        )
      } else {
        value
      }
    }
    Some(Unary(op, inner)) => {
      let lowered_inner = self.materialize_return_subexpressions(
        function, scope, block, inner,
      )
      if lowered_inner != inner {
        function.expressions.append(Expression::Unary(op, lowered_inner))
      } else {
        value
      }
    }
    Some(Bitcast(ty, inner)) => {
      let lowered_inner = self.materialize_nested_return_argument(
        function, scope, block, inner,
      )
      if lowered_inner != inner {
        function.expressions.append(Expression::Bitcast(ty, lowered_inner))
      } else {
        value
      }
    }
    Some(FunctionCall(handle, arguments)) => {
      let lowered : Array[Handle] = []
      let mut changed = false
      for argument in arguments {
        let lowered_argument = self.materialize_nested_call_argument(
          function, scope, block, argument,
        )
        if lowered_argument != argument {
          changed = true
        }
        lowered.push(lowered_argument)
      }
      if changed {
        function.expressions.set(
          value,
          Expression::FunctionCall(handle, lowered),
        )
      }
      value
    }
    Some(AtomicCall(atomic_function, arguments)) => {
      let lowered : Array[Handle] = []
      let mut changed = false
      for argument in arguments {
        let lowered_argument = self.materialize_nested_call_argument(
          function, scope, block, argument,
        )
        if lowered_argument != argument {
          changed = true
        }
        lowered.push(lowered_argument)
      }
      if changed {
        function.expressions.set(
          value,
          Expression::AtomicCall(atomic_function, lowered),
        )
      }
      value
    }
    _ => value
  }
}

///|
fn WgslIrLowerer::materialize_nested_return_argument(
  self : WgslIrLowerer,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
  value : Handle,
) -> Handle raise WgslIrLowerError {
  let normalized = self.materialize_return_subexpressions(
    function, scope, block, value,
  )
  if self.function_expression_should_materialize_as_nested_value(
      function, normalized,
    ) {
    self.materialize_function_expression(function, scope, block, normalized)
  } else {
    normalized
  }
}

///|
fn WgslIrLowerer::materialize_nested_access_base(
  self : WgslIrLowerer,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
  value : Handle,
) -> Handle raise WgslIrLowerError {
  let normalized = self.materialize_return_subexpressions(
    function, scope, block, value,
  )
  if self.function_expression_should_materialize_as_access_base(
      function, normalized,
    ) {
    self.materialize_function_expression(function, scope, block, normalized)
  } else {
    normalized
  }
}

///|
fn WgslIrLowerer::materialize_nested_call_argument(
  self : WgslIrLowerer,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
  value : Handle,
) -> Handle raise WgslIrLowerError {
  let normalized = self.materialize_return_subexpressions(
    function, scope, block, value,
  )
  if self.function_expression_should_materialize_as_call_argument(
      function, normalized,
    ) {
    self.materialize_function_expression(function, scope, block, normalized)
  } else {
    normalized
  }
}

///|
fn WgslIrLowerer::materialize_nested_constructor_argument(
  self : WgslIrLowerer,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
  value : Handle,
) -> Handle raise WgslIrLowerError {
  let normalized = self.materialize_return_subexpressions(
    function, scope, block, value,
  )
  if self.function_expression_should_materialize_as_nested_value(
      function, normalized,
    ) ||
    self.function_expression_should_materialize_as_call_argument(
      function, normalized,
    ) {
    self.materialize_function_expression(function, scope, block, normalized)
  } else {
    normalized
  }
}

///|
fn WgslIrLowerer::materialize_side_effecting_expression(
  self : WgslIrLowerer,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
  value : Handle,
) -> Handle raise WgslIrLowerError {
  let normalized = self.materialize_return_subexpressions(
    function, scope, block, value,
  )
  if self.function_expression_is_side_effecting(function, Some(normalized)) {
    self.materialize_function_expression(function, scope, block, normalized)
  } else {
    normalized
  }
}

///|
fn WgslIrLowerer::function_expression_is_side_effecting(
  self : WgslIrLowerer,
  function : Function,
  value : Handle?,
) -> Bool {
  ignore(self)
  match value {
    Some(handle) =>
      match function.expressions.items.get(handle.index()) {
        Some(AtomicCall(function_, _)) =>
          match function_ {
            Load
            | Add
            | Subtract
            | And
            | ExclusiveOr
            | InclusiveOr
            | Min
            | Max
            | Exchange
            | CompareExchangeWeak => true
            Store => false
          }
        _ => false
      }
    None => false
  }
}

///|
fn WgslIrLowerer::function_expression_should_materialize_as_nested_value(
  self : WgslIrLowerer,
  function : Function,
  value : Handle,
) -> Bool {
  let should_materialize = match function.expressions.items.get(value.index()) {
    Some(FunctionCall(_, _))
    | Some(AtomicCall(_, _))
    | Some(ImageSample(_, _, _, _, _, _, _, _, _))
    | Some(ImageLoad(_, _, _, _, _))
    | Some(ImageQuery(_, _)) => true
    Some(Access(_, _)) | Some(AccessIndex(_, _)) | Some(Swizzle(_, _, _)) =>
      self.function_expression_reads_global_binding(function, value)
    _ => false
  }
  should_materialize &&
  self.function_expression_can_materialize_to_let(function, value)
}

///|
fn WgslIrLowerer::function_expression_should_materialize_as_access_base(
  self : WgslIrLowerer,
  function : Function,
  value : Handle,
) -> Bool {
  match function.expressions.items.get(value.index()) {
    Some(FunctionCall(_, _))
    | Some(AtomicCall(_, _))
    | Some(ImageSample(_, _, _, _, _, _, _, _, _))
    | Some(ImageLoad(_, _, _, _, _))
    | Some(ImageQuery(_, _)) => true
    _ =>
      self.function_expression_should_materialize_as_nested_value(
        function, value,
      )
  }
}

///|
fn WgslIrLowerer::function_expression_should_materialize_as_call_argument(
  self : WgslIrLowerer,
  function : Function,
  value : Handle,
) -> Bool {
  self.function_expression_is_var_pointer_load(function, value) &&
  self.function_expression_can_materialize_to_let(function, value)
}

///|
fn WgslIrLowerer::function_expression_is_var_pointer_load(
  self : WgslIrLowerer,
  function : Function,
  value : Handle,
) -> Bool {
  ignore(self)
  match function.expressions.items.get(value.index()) {
    Some(Load(pointer)) =>
      match function.expressions.items.get(pointer.index()) {
        Some(LocalVariable(handle)) =>
          match function.local_variables.items.get(handle.index()) {
            Some(local_variable) => local_variable.kind == Var
            None => false
          }
        _ => false
      }
    _ => false
  }
}

///|
fn WgslIrLowerer::function_expression_reads_global_binding(
  self : WgslIrLowerer,
  function : Function,
  value : Handle,
) -> Bool {
  match function.expressions.items.get(value.index()) {
    Some(GlobalVariable(_)) => true
    Some(Load(inner)) =>
      self.function_expression_reads_global_binding(function, inner)
    Some(Access(base, index)) =>
      self.function_expression_reads_global_binding(function, base) ||
      self.function_expression_reads_global_binding(function, index)
    Some(AccessIndex(base, _)) | Some(Swizzle(_, base, _)) =>
      self.function_expression_reads_global_binding(function, base)
    _ => false
  }
}

///|
fn WgslIrLowerer::function_expression_can_materialize_to_let(
  self : WgslIrLowerer,
  function : Function,
  value : Handle,
) -> Bool {
  match self.function_expression_type(function, value) {
    Some(ty) => self.type_can_materialize_to_local_let(ty)
    None => false
  }
}

///|
fn WgslIrLowerer::type_can_materialize_to_local_let(
  self : WgslIrLowerer,
  ty : Handle,
) -> Bool {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Array(_, Dynamic, _)
        | BindingArray(_, _)
        | Image(_, _, _)
        | Sampler(_)
        | AccelerationStructure(_)
        | RayQuery(_)
        | Atomic(_) => false
        _ => true
      }
    None => false
  }
}

///|
fn WgslIrLowerer::function_expression_can_return_directly(
  self : WgslIrLowerer,
  function : Function,
  value : Handle,
) -> Bool {
  match function.expressions.items.get(value.index()) {
    Some(expression) =>
      match expression {
        Literal(_)
        | Constant(_)
        | Override(_)
        | FunctionArgument(_)
        | Binary(_, _, _)
        | Compose(_, _)
        | Access(_, _)
        | AccessIndex(_, _)
        | Swizzle(_, _, _)
        | Unary(_, _)
        | Select(_, _, _)
        | Bitcast(_, _)
        | Math(_, _, _, _, _)
        | Relational(_, _) => true
        Load(inner) =>
          self.function_pointer_expression_can_return_directly(function, inner)
        _ => false
      }
    None => false
  }
}

///|
fn WgslIrLowerer::function_pointer_expression_can_return_directly(
  self : WgslIrLowerer,
  function : Function,
  value : Handle,
) -> Bool {
  ignore(self)
  match function.expressions.items.get(value.index()) {
    Some(Expression::LocalVariable(handle)) =>
      match function.local_variables.items.get(handle.index()) {
        Some(local_variable) => local_variable.kind == Let
        None => false
      }
    _ => false
  }
}

///|
fn WgslIrLowerer::lower_local_const_declaration(
  self : WgslIrLowerer,
  local_decl : @ast.WgslLocalDeclaration,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Unit raise WgslIrLowerError {
  let explicit_ty = match local_decl.ty_ref() {
    Some(ty_ref) => Some(self.lower_type_ref(ty_ref))
    None => None
  }
  let init = match local_decl.initializer_ref() {
    Some(expr_ref) =>
      self.lower_function_expression_ref_with_expected(
        expr_ref, function, scope, explicit_ty,
      )
    None => raise WgslIrLowerError::MissingType(local_decl.name().name())
  }
  if !self.function_expression_is_const_expression(function, init) {
    raise WgslIrLowerError::UnsupportedExpression(
      "local const initializer is not a const expression",
    )
  }
  ignore(scope.locals.remove(local_decl.name().name()))
  scope.local_constants.set(local_decl.name().name(), init)
}

///|
fn WgslIrLowerer::function_expression_is_const_expression(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle,
) -> Bool {
  match function.expressions.items.get(handle.index()) {
    Some(expression) =>
      self.function_expression_inner_is_const_expression(function, expression)
    None => false
  }
}

///|
fn WgslIrLowerer::function_expression_inner_is_const_expression(
  self : WgslIrLowerer,
  function : Function,
  expression : Expression,
) -> Bool {
  match expression {
    Literal(_) | Constant(_) | ZeroValue(_) => true
    Override(_)
    | FunctionArgument(_)
    | GlobalVariable(_)
    | LocalVariable(_)
    | Load(_)
    | AddressOf(_, _)
    | FunctionCall(_, _)
    | AtomicCall(_, _)
    | ImageSample(_, _, _, _, _, _, _, _, _)
    | ImageLoad(_, _, _, _, _)
    | ImageQuery(_, _)
    | CallResult(_)
    | AtomicResult(_, _)
    | WorkGroupUniformLoadResult(_)
    | ArrayLength(_)
    | RayQueryInitialize(_, _, _)
    | RayQueryProceed(_)
    | RayQueryGenerateIntersection(_, _)
    | RayQueryConfirmIntersection(_)
    | RayQueryTerminate(_)
    | RayQueryVertexPositions(_, _)
    | RayQueryProceedResult
    | RayQueryGetIntersection(_, _)
    | SubgroupBallotResult
    | SubgroupOperationResult(_)
    | CooperativeLoad(_, _, _, _)
    | CooperativeMultiplyAdd(_, _, _) => false
    Compose(_, components) =>
      self.function_expression_list_is_const_expression(function, components)
    Access(base, index) =>
      self.function_expression_is_const_expression(function, base) &&
      self.function_expression_is_const_expression(function, index)
    AccessIndex(base, _) | Splat(_, base) | Swizzle(_, base, _) =>
      self.function_expression_is_const_expression(function, base)
    Unary(_, inner)
    | Bitcast(_, inner)
    | Relational(_, inner)
    | As(inner, _, _) =>
      self.function_expression_is_const_expression(function, inner)
    Binary(_, left, right) =>
      self.function_expression_is_const_expression(function, left) &&
      self.function_expression_is_const_expression(function, right)
    Select(left, right, condition) =>
      self.function_expression_is_const_expression(function, left) &&
      self.function_expression_is_const_expression(function, right) &&
      self.function_expression_is_const_expression(function, condition)
    Derivative(_, _, _) => false
    Math(_, first, second, third, fourth) =>
      self.function_expression_is_const_expression(function, first) &&
      self.optional_function_expression_is_const_expression(function, second) &&
      self.optional_function_expression_is_const_expression(function, third) &&
      self.optional_function_expression_is_const_expression(function, fourth)
  }
}

///|
fn WgslIrLowerer::function_expression_list_is_const_expression(
  self : WgslIrLowerer,
  function : Function,
  handles : Array[Handle],
) -> Bool {
  for handle in handles {
    if !self.function_expression_is_const_expression(function, handle) {
      return false
    }
  }
  true
}

///|
fn WgslIrLowerer::optional_function_expression_is_const_expression(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle?,
) -> Bool {
  match handle {
    Some(value) => self.function_expression_is_const_expression(function, value)
    None => true
  }
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
    Call(callee, arguments) =>
      match callee.kind() {
        Identifier(name) =>
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
                  let values : Array[Handle] = []
                  for argument in arguments {
                    values.push(
                      self.lower_function_expression_node(
                        argument, function, scope,
                      ),
                    )
                  }
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
                    ) {
                    ignore(
                      self.lower_function_expression_node(root, function, scope),
                    )
                  }
              }
          }
        _ => ignore(self.lower_function_expression_node(root, function, scope))
      }
    _ => ignore(self.lower_function_expression_node(root, function, scope))
  }
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
  let (component, image, sampler, coordinate, base_count) = if depth {
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
    (Some(SwizzleComponent::X), probe_image, sampler, coordinate, 3)
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
  } else if storage {
    guard arguments.length() == 2 else {
      raise WgslIrLowerError::UnsupportedExpression(
        "textureLoad storage texture expects no level argument",
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
fn WgslIrLowerer::infer_expression_type(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  name : String,
) -> Handle raise WgslIrLowerError {
  match node.kind() {
    Literal(token) =>
      match token.kind() {
        BoolLiteral(_) => self.lower_builtin_type_name("bool")
        IntLiteral(_) =>
          if wgsl_ir_literal_has_suffix(token.text(), "i") {
            self.lower_builtin_type_name("i32")
          } else {
            self.lower_builtin_type_name("__abstract_int")
          }
        UintLiteral(_) => self.lower_builtin_type_name("u32")
        FloatLiteral => self.lower_builtin_type_name("__abstract_float")
        _ => raise WgslIrLowerError::MissingType(name)
      }
    Identifier(identifier) =>
      self.infer_named_expression_type(identifier.name(), name)
    Group(inner) => self.infer_expression_type(inner, name)
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
    Call(callee, arguments) =>
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
    _ => raise WgslIrLowerError::MissingType(name)
  }
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
  match self.constant_names.get(referenced_name) {
    Some(handle) =>
      match self.shader_module.constants.items.get(handle.index()) {
        Some(constant) => constant.ty
        None => raise WgslIrLowerError::MissingType(diagnostic_name)
      }
    None =>
      match self.override_names.get(referenced_name) {
        Some(handle) =>
          match self.shader_module.overrides.items.get(handle.index()) {
            Some(override_) => override_.ty
            None => raise WgslIrLowerError::MissingType(diagnostic_name)
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
  let parser = WgslIrExprTokenParser::{ tokens, index: 0 }
  match parser.parse_expression(0) {
    Some(node) => node
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
      None => break
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
        BoolLiteral(_) | UintLiteral(_) | IntLiteral(_) | FloatLiteral => {
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
            None =>
              return Some(
                wgsl_ir_expr_make_node(
                  @ast.WgslExprNodeKind::Token(token),
                  token.start(),
                  token.end(),
                ),
              )
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
          Some(
            wgsl_ir_expr_make_node(
              @ast.WgslExprNodeKind::Token(token),
              token.start(),
              token.end(),
            ),
          )
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
      None => break
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
    Identifier(name) =>
      match self.constant_names.get(name.name()) {
        Some(handle) => Expression::Constant(handle)
        None =>
          match self.override_names.get(name.name()) {
            Some(handle) => Expression::Override(handle)
            None =>
              match self.global_names.get(name.name()) {
                Some(handle) => Expression::GlobalVariable(handle)
                None => raise WgslIrLowerError::UnknownIdentifier(name.name())
              }
          }
      }
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
    Call(callee, arguments) =>
      match self.lower_bitcast_callee_type(callee) {
        Some(ty) => self.lower_global_bitcast_call(ty, arguments)
        None =>
          match callee.kind() {
            Identifier(name) =>
              if name.name() == "select" {
                self.lower_global_select_call(arguments)
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
  )
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
fn WgslIrLowerer::lower_function_lvalue_node(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  match node.kind() {
    Identifier(name) =>
      match scope.local_constants.get(name.name()) {
        Some(_) =>
          raise WgslIrLowerError::UnsupportedExpression(
            "local const is not assignable",
          )
        None =>
          match scope.locals.get(name.name()) {
            Some(handle) =>
              scope.local_pointer_expression(name.name(), handle, function)
            None =>
              match self.global_names.get(name.name()) {
                Some(handle) =>
                  scope.global_pointer_expression(name.name(), handle, function)
                None => raise WgslIrLowerError::UnknownIdentifier(name.name())
              }
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
    Identifier(name) =>
      self.lower_identifier_expression(name.name(), function, scope)
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
        raise WgslIrLowerError::UnsupportedExpression(
          "standalone pointer dereference",
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
      let handle = function.expressions.append(
        Expression::Binary(
          wgsl_ir_binary_operator(op),
          self.lower_function_expression_node(left, function, scope),
          self.lower_function_expression_node(right, function, scope),
        ),
      )
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
    _ =>
      raise WgslIrLowerError::UnsupportedExpression("unlowered expression node")
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
  match self.lower_bitcast_callee_type(callee) {
    Some(ty) => self.lower_function_bitcast_call(ty, arguments, function, scope)
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
          self.lower_function_expression_arguments(arguments, function, scope),
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
                if name == "arrayLength" {
                  self.lower_function_array_length_call(
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
    Some(handle) => handle
    None =>
      match scope.arguments.get(name) {
        Some(index) =>
          function.expressions.append(Expression::FunctionArgument(index))
        None =>
          match scope.locals.get(name) {
            Some(handle) =>
              function.expressions.append(
                Expression::Load(
                  scope.local_pointer_expression(name, handle, function),
                ),
              )
            None =>
              match self.constant_names.get(name) {
                Some(handle) =>
                  function.expressions.append(Expression::Constant(handle))
                None =>
                  match self.override_names.get(name) {
                    Some(handle) =>
                      function.expressions.append(Expression::Override(handle))
                    None =>
                      match self.global_names.get(name) {
                        Some(handle) =>
                          if self.global_variable_is_handle_value(handle) {
                            scope.global_pointer_expression(
                              name, handle, function,
                            )
                          } else {
                            function.expressions.append(
                              Expression::Load(
                                scope.global_pointer_expression(
                                  name, handle, function,
                                ),
                              ),
                            )
                          }
                        None => raise WgslIrLowerError::UnknownIdentifier(name)
                      }
                  }
              }
          }
      }
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
  if self.function_index_base_is_addressable(base, scope) {
    self.lower_function_lvalue_node(base, function, scope)
  } else {
    self.lower_function_expression_node(base, function, scope)
  }
}

///|
fn WgslIrLowerer::function_index_base_is_addressable(
  self : WgslIrLowerer,
  base : @ast.WgslExprNode,
  scope : WgslIrFunctionScope,
) -> Bool {
  match base.kind() {
    Group(inner) => self.function_index_base_is_addressable(inner, scope)
    Identifier(name) =>
      scope.locals.get(name.name()) is Some(_) ||
      self.global_names.get(name.name()) is Some(_)
    Index(inner, _) | Member(inner, _) =>
      self.function_index_base_is_addressable(inner, scope)
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
    Token(token) => "token \{token.text()}"
    Unary(op, inner) => "unary \{op.text()}(\{wgsl_ir_expr_node_shape(inner)})"
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
    Sequence(items) => "sequence(\{items.length()})"
  }
}

///|
fn WgslIrLowerer::lower_type_ref(
  self : WgslIrLowerer,
  ty_ref : @ast.WgslTypeRef,
) -> Handle raise WgslIrLowerError {
  let key = ty_ref.canonical_text()
  match self.type_cache.get(key) {
    Some(handle) => handle
    None => {
      let handle = self.lower_uncached_type_ref(ty_ref)
      self.type_cache.set(key, handle)
      handle
    }
  }
}

///|
fn WgslIrLowerer::lower_uncached_type_ref(
  self : WgslIrLowerer,
  ty_ref : @ast.WgslTypeRef,
) -> Handle raise WgslIrLowerError {
  let name = ty_ref.name()
  match self.type_cache.get(name) {
    Some(handle) => handle
    None =>
      match wgsl_ir_builtin_scalar_alias(name) {
        Some(inner) => self.intern_type(name, inner)
        None =>
          match wgsl_ir_builtin_vector_alias(name) {
            Some(inner) => self.intern_type(name, inner)
            None =>
              match wgsl_ir_builtin_matrix_alias(name) {
                Some(inner) => self.intern_type(name, inner)
                None => self.lower_composite_type_ref(ty_ref)
              }
          }
      }
  }
}

///|
fn WgslIrLowerer::lower_composite_type_ref(
  self : WgslIrLowerer,
  ty_ref : @ast.WgslTypeRef,
) -> Handle raise WgslIrLowerError {
  let name = ty_ref.name()
  match name {
    "vec2" | "vec3" | "vec4" => {
      let scalar = self.required_scalar_type_argument(ty_ref)
      self.intern_type(
        ty_ref.canonical_text(),
        TypeInner::Vector(wgsl_ir_vector_size_from_name(name), scalar),
      )
    }
    "mat2x2"
    | "mat2x3"
    | "mat2x4"
    | "mat3x2"
    | "mat3x3"
    | "mat3x4"
    | "mat4x2"
    | "mat4x3"
    | "mat4x4" => {
      let scalar = self.required_scalar_type_argument(ty_ref)
      let (columns, rows) = wgsl_ir_matrix_size_from_name(name)
      self.intern_type(
        ty_ref.canonical_text(),
        TypeInner::Matrix(columns, rows, scalar),
      )
    }
    "array" => {
      let args = ty_ref.template_arguments()
      guard args is [Type(element_ty), .. rest] else {
        raise WgslIrLowerError::UnsupportedType(ty_ref.canonical_text())
      }
      let element = self.lower_type_ref(element_ty)
      let size = match rest {
        [size_arg, ..] => self.lower_type_template_array_size(size_arg)
        _ => ArraySize::Dynamic
      }
      let layout = self.type_layout(element)
      let stride = wgsl_ir_align_to(layout.size, layout.align)
      self.intern_type(
        ty_ref.canonical_text(),
        TypeInner::Array(element, size, stride),
      )
    }
    "ptr" => {
      let args = ty_ref.template_arguments()
      guard args is [Type(space_ref), Type(target_ref), ..] else {
        raise WgslIrLowerError::UnsupportedType(ty_ref.canonical_text())
      }
      let space = wgsl_ir_address_space_from_type_name(space_ref.name())
      self.intern_type(
        ty_ref.canonical_text(),
        TypeInner::Pointer(self.lower_type_ref(target_ref), space),
      )
    }
    "atomic" => {
      let scalar = self.required_scalar_type_argument(ty_ref)
      self.intern_type(ty_ref.canonical_text(), TypeInner::Atomic(scalar))
    }
    "sampler" => self.intern_type(name, TypeInner::Sampler(false))
    "sampler_comparison" => self.intern_type(name, TypeInner::Sampler(true))
    "acceleration_structure" =>
      self.intern_type(name, TypeInner::AccelerationStructure(false))
    "ray_query" => self.intern_type(name, TypeInner::RayQuery(false))
    "texture_1d"
    | "texture_2d"
    | "texture_2d_array"
    | "texture_3d"
    | "texture_cube"
    | "texture_cube_array"
    | "texture_multisampled_2d" => {
      let scalar = self.required_scalar_type_argument(ty_ref)
      self.intern_type(
        ty_ref.canonical_text(),
        TypeInner::Image(
          wgsl_ir_image_dimension_from_name(name),
          name.contains("array"),
          ImageClass::Sampled(scalar.kind, name.contains("multisampled")),
        ),
      )
    }
    "texture_depth_2d"
    | "texture_depth_2d_array"
    | "texture_depth_cube"
    | "texture_depth_cube_array"
    | "texture_depth_multisampled_2d" =>
      self.intern_type(
        name,
        TypeInner::Image(
          wgsl_ir_image_dimension_from_name(name),
          name.contains("array"),
          ImageClass::Depth(name.contains("multisampled")),
        ),
      )
    "texture_external" =>
      self.intern_type(
        name,
        TypeInner::Image(ImageDimension::D2, false, ImageClass::External),
      )
    "texture_storage_1d"
    | "texture_storage_2d"
    | "texture_storage_2d_array"
    | "texture_storage_3d" => {
      let args = ty_ref.template_arguments()
      guard args is [Type(format_ref), .. rest] else {
        raise WgslIrLowerError::UnsupportedType(ty_ref.canonical_text())
      }
      let access = match rest {
        [Type(access_ref), ..] =>
          wgsl_ir_storage_access_from_name(access_ref.name())
        _ => StorageAccess::load()
      }
      self.intern_type(
        ty_ref.canonical_text(),
        TypeInner::Image(
          wgsl_ir_image_dimension_from_name(name),
          name.contains("array"),
          ImageClass::Storage(
            wgsl_ir_storage_format_from_name(format_ref.name()),
            access,
          ),
        ),
      )
    }
    "binding_array" => {
      let args = ty_ref.template_arguments()
      guard args is [Type(element_ty), .. rest] else {
        raise WgslIrLowerError::UnsupportedType(ty_ref.canonical_text())
      }
      let size = match rest {
        [size_arg, ..] => self.lower_type_template_array_size(size_arg)
        _ => ArraySize::Dynamic
      }
      self.intern_type(
        ty_ref.canonical_text(),
        TypeInner::BindingArray(self.lower_type_ref(element_ty), size),
      )
    }
    _ =>
      raise WgslIrLowerError::UnsupportedType(
        "\{ty_ref.canonical_text()} before \{ty_ref.end()}",
      )
  }
}

///|
fn WgslIrLowerer::lower_type_template_array_size(
  self : WgslIrLowerer,
  argument : @ast.WgslTypeArgument,
) -> ArraySize raise WgslIrLowerError {
  match argument {
    Expression(expr) =>
      match wgsl_ir_int_literal_from_expr_ref(expr) {
        Some(value) => ArraySize::Constant(value)
        None => {
          let handle = self.lower_global_expression_ref(expr)
          self.lower_constant_array_size_expression(handle)
        }
      }
    Type(ty_ref) => self.lower_type_template_array_size_type_ref(ty_ref)
  }
}

///|
fn WgslIrLowerer::lower_type_template_array_size_type_ref(
  self : WgslIrLowerer,
  ty_ref : @ast.WgslTypeRef,
) -> ArraySize raise WgslIrLowerError {
  let name = ty_ref.name()
  let literal = wgsl_ir_array_size_literal_from_type_name(name)
  match literal {
    Some(value) => ArraySize::Constant(value)
    None =>
      match self.constant_names.get(name) {
        Some(handle) =>
          self.lower_constant_array_size_from_constant_handle(handle)
        None =>
          match self.override_names.get(name) {
            Some(handle) =>
              ArraySize::Pending(
                self.shader_module.append_global_expression(
                  Expression::Override(handle),
                ),
              )
            None => ArraySize::Dynamic
          }
      }
  }
}

///|
fn WgslIrLowerer::lower_constant_array_size_from_constant_handle(
  self : WgslIrLowerer,
  handle : Handle,
) -> ArraySize raise WgslIrLowerError {
  match self.shader_module.constants.items.get(handle.index()) {
    Some(constant) => self.lower_constant_array_size_expression(constant.init)
    None =>
      raise WgslIrLowerError::UnsupportedType(
        "array size references missing constant",
      )
  }
}

///|
fn WgslIrLowerer::lower_constant_array_size_expression(
  self : WgslIrLowerer,
  handle : Handle,
) -> ArraySize raise WgslIrLowerError {
  let evaluated = Some(self.eval_global_integer_expression(handle)) catch {
    _ => None
  }
  match evaluated {
    Some((value, _)) => {
      if value < 0 {
        raise WgslIrLowerError::UnsupportedType(
          "array size must be non-negative",
        )
      }
      ArraySize::Constant(value)
    }
    None => ArraySize::Pending(handle)
  }
}

///|
fn wgsl_ir_array_size_literal_from_type_name(name : String) -> Int? {
  let text = if name.length() > 0 {
    let suffix = name[name.length() - 1:]
    if suffix == "u" || suffix == "i" {
      name[:name.length() - 1]
    } else {
      name
    }
  } else {
    name
  }
  Some(@strconv.from_str(text)) catch {
    _ => None
  }
}

///|
fn WgslIrLowerer::required_scalar_type_argument(
  self : WgslIrLowerer,
  ty_ref : @ast.WgslTypeRef,
) -> Scalar raise WgslIrLowerError {
  match ty_ref.template_arguments() {
    [Type(arg), ..] => self.scalar_from_type_ref(arg)
    _ => raise WgslIrLowerError::UnsupportedType(ty_ref.canonical_text())
  }
}

///|
fn WgslIrLowerer::scalar_from_type_ref(
  self : WgslIrLowerer,
  ty_ref : @ast.WgslTypeRef,
) -> Scalar raise WgslIrLowerError {
  match ty_ref.name() {
    "bool" => Scalar::Scalar(Bool, 1)
    "i32" => Scalar::Scalar(Sint, 4)
    "u32" => Scalar::Scalar(Uint, 4)
    "f32" => Scalar::Scalar(Float, 4)
    "f16" => Scalar::Scalar(Float, 2)
    _ => {
      let handle = self.lower_type_ref(ty_ref)
      match self.shader_module.types.get(handle) {
        Some(ty) =>
          match ty.inner {
            Scalar(scalar) => scalar
            _ =>
              raise WgslIrLowerError::UnsupportedType(ty_ref.canonical_text())
          }
        None => raise WgslIrLowerError::UnsupportedType(ty_ref.canonical_text())
      }
    }
  }
}

///|
fn WgslIrLowerer::lower_templated_callee_type(
  self : WgslIrLowerer,
  callee : @ast.WgslExprNode,
) -> Handle? raise WgslIrLowerError {
  match callee.kind() {
    Template(base, template_arguments) =>
      match base.kind() {
        Identifier(name) => {
          let atom = @ast.WgslTypeAtom(
            @ast.WgslTypeAtomKind::Identifier,
            name.name(),
            name.start(),
            name.end(),
          )
          let ty_ref = @ast.WgslTypeRef::new_with_template_arguments(
            atom,
            template_arguments,
            callee.start(),
            callee.end(),
          )
          Some(self.lower_type_ref(ty_ref))
        }
        _ =>
          raise WgslIrLowerError::UnsupportedExpression(
            "template call callee must be a type identifier",
          )
      }
    _ => None
  }
}

///|
fn WgslIrLowerer::lower_untemplated_constructor_type_from_ast(
  self : WgslIrLowerer,
  name : String,
  arguments : Array[@ast.WgslExprNode],
  diagnostic_name : String,
) -> Handle raise WgslIrLowerError {
  match self.type_cache.get(name) {
    Some(handle) => handle
    None =>
      match wgsl_ir_builtin_vector_alias(name) {
        Some(inner) => self.intern_type(name, inner)
        None =>
          match wgsl_ir_builtin_matrix_alias(name) {
            Some(inner) => self.intern_type(name, inner)
            None =>
              match wgsl_ir_builtin_scalar_alias(name) {
                Some(inner) => self.intern_type(name, inner)
                None =>
                  self.lower_generic_constructor_type_from_ast(
                    name, arguments, diagnostic_name,
                  )
              }
          }
      }
  }
}

///|
fn WgslIrLowerer::lower_generic_constructor_type_from_ast(
  self : WgslIrLowerer,
  name : String,
  arguments : Array[@ast.WgslExprNode],
  diagnostic_name : String,
) -> Handle raise WgslIrLowerError {
  match name {
    "vec2" | "vec3" | "vec4" => {
      let scalar = self.constructor_scalar_from_ast_arguments(
        arguments, diagnostic_name,
      )
      self.intern_type(
        "\{name}<\{wgsl_ir_scalar_name(scalar.kind, scalar.width)}>",
        TypeInner::Vector(wgsl_ir_vector_size_from_name(name), scalar),
      )
    }
    "mat2x2"
    | "mat2x3"
    | "mat2x4"
    | "mat3x2"
    | "mat3x3"
    | "mat3x4"
    | "mat4x2"
    | "mat4x3"
    | "mat4x4" => {
      let scalar = self.constructor_scalar_from_ast_arguments(
        arguments, diagnostic_name,
      )
      let (columns, rows) = wgsl_ir_matrix_size_from_name(name)
      self.intern_type(
        "\{name}<\{wgsl_ir_scalar_name(scalar.kind, scalar.width)}>",
        TypeInner::Matrix(columns, rows, scalar),
      )
    }
    _ => raise WgslIrLowerError::UnsupportedType(name)
  }
}

///|
fn WgslIrLowerer::infer_array_constructor_type_from_ast(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  diagnostic_name : String,
) -> Handle raise WgslIrLowerError {
  let flattened = wgsl_ir_flatten_expression_arguments(arguments)
  guard flattened is [first, ..] else {
    raise WgslIrLowerError::MissingType(diagnostic_name)
  }
  let element_ty = self.infer_expression_type(first, diagnostic_name)
  self.intern_inferred_array_type(element_ty, flattened.length())
}

///|
fn WgslIrLowerer::constructor_scalar_from_ast_arguments(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  diagnostic_name : String,
) -> Scalar raise WgslIrLowerError {
  guard wgsl_ir_flatten_expression_arguments(arguments) is [first, ..] else {
    raise WgslIrLowerError::MissingType(diagnostic_name)
  }
  let ty = self.infer_expression_type(first, diagnostic_name)
  self.scalar_from_type_handle(ty, diagnostic_name)
}

///|
fn WgslIrLowerer::lower_untemplated_constructor_type_from_handles(
  self : WgslIrLowerer,
  name : String,
  arguments : Array[@ast.WgslExprNode],
  lowered_arguments : Array[Handle],
  function : Function,
) -> Handle raise WgslIrLowerError {
  match self.type_cache.get(name) {
    Some(handle) => handle
    None =>
      match wgsl_ir_builtin_vector_alias(name) {
        Some(inner) => self.intern_type(name, inner)
        None =>
          match wgsl_ir_builtin_matrix_alias(name) {
            Some(inner) => self.intern_type(name, inner)
            None =>
              match wgsl_ir_builtin_scalar_alias(name) {
                Some(inner) => self.intern_type(name, inner)
                None =>
                  self.lower_generic_constructor_type_from_handles(
                    name, arguments, lowered_arguments, function,
                  )
              }
          }
      }
  }
}

///|
fn WgslIrLowerer::lower_generic_constructor_type_from_handles(
  self : WgslIrLowerer,
  name : String,
  arguments : Array[@ast.WgslExprNode],
  lowered_arguments : Array[Handle],
  function : Function,
) -> Handle raise WgslIrLowerError {
  match name {
    "vec2" | "vec3" | "vec4" => {
      let scalar = self.constructor_scalar_from_handles(
        lowered_arguments, function, name,
      )
      self.intern_type(
        "\{name}<\{wgsl_ir_scalar_name(scalar.kind, scalar.width)}>",
        TypeInner::Vector(wgsl_ir_vector_size_from_name(name), scalar),
      )
    }
    "mat2x2"
    | "mat2x3"
    | "mat2x4"
    | "mat3x2"
    | "mat3x3"
    | "mat3x4"
    | "mat4x2"
    | "mat4x3"
    | "mat4x4" => {
      let scalar = self.constructor_scalar_from_handles(
        lowered_arguments, function, name,
      )
      let (columns, rows) = wgsl_ir_matrix_size_from_name(name)
      self.intern_type(
        "\{name}<\{wgsl_ir_scalar_name(scalar.kind, scalar.width)}>",
        TypeInner::Matrix(columns, rows, scalar),
      )
    }
    _ => self.lower_type_name_with_expression_arguments(name, arguments)
  }
}

///|
fn WgslIrLowerer::infer_array_constructor_type_from_handles(
  self : WgslIrLowerer,
  lowered_arguments : Array[Handle],
  function : Function,
  diagnostic_name : String,
) -> Handle raise WgslIrLowerError {
  guard lowered_arguments is [first, ..] else {
    raise WgslIrLowerError::MissingType(diagnostic_name)
  }
  guard self.function_expression_type(function, first) is Some(element_ty) else {
    raise WgslIrLowerError::MissingType(diagnostic_name)
  }
  self.intern_inferred_array_type(element_ty, lowered_arguments.length())
}

///|
fn WgslIrLowerer::constructor_scalar_from_handles(
  self : WgslIrLowerer,
  lowered_arguments : Array[Handle],
  function : Function,
  diagnostic_name : String,
) -> Scalar raise WgslIrLowerError {
  guard lowered_arguments is [first, ..] else {
    raise WgslIrLowerError::MissingType(diagnostic_name)
  }
  guard self.function_expression_type(function, first) is Some(ty) else {
    raise WgslIrLowerError::MissingType(diagnostic_name)
  }
  self.scalar_from_type_handle(ty, diagnostic_name)
}

///|
fn WgslIrLowerer::intern_inferred_array_type(
  self : WgslIrLowerer,
  element_ty : Handle,
  length : Int,
) -> Handle raise WgslIrLowerError {
  let layout = self.type_layout(element_ty)
  let stride = wgsl_ir_align_to(layout.size, layout.align)
  self.intern_type(
    "array<\{self.type_cache_name(element_ty)}, \{length}>",
    TypeInner::Array(element_ty, Constant(length), stride),
  )
}

///|
fn WgslIrLowerer::type_cache_name(
  self : WgslIrLowerer,
  handle : Handle,
) -> String raise WgslIrLowerError {
  match self.shader_module.types.get(handle) {
    Some(type_) =>
      match type_.name {
        Some(name) => name
        None => "type_\{handle.index()}"
      }
    None => raise WgslIrLowerError::MissingType("type handle")
  }
}

///|
fn WgslIrLowerer::scalar_from_type_handle(
  self : WgslIrLowerer,
  ty : Handle,
  diagnostic_name : String,
) -> Scalar raise WgslIrLowerError {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Scalar(scalar) => scalar
        Vector(_, scalar) => scalar
        Matrix(_, _, scalar) => scalar
        _ => raise WgslIrLowerError::MissingType(diagnostic_name)
      }
    None => raise WgslIrLowerError::MissingType(diagnostic_name)
  }
}

///|
priv struct WgslIrLayout {
  align : Int
  size : Int
}

///|
fn WgslIrLowerer::type_layout(
  self : WgslIrLowerer,
  handle : Handle,
) -> WgslIrLayout raise WgslIrLowerError {
  match self.shader_module.types.get(handle) {
    Some(ty) =>
      match ty.inner {
        Scalar(scalar) | Atomic(scalar) =>
          WgslIrLayout::{ align: scalar.width, size: scalar.width }
        Vector(size, scalar) => {
          let width = size.width()
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
        Matrix(columns, rows, scalar) => {
          let column_align = if rows.width() == 3 {
            4 * scalar.width
          } else {
            rows.width() * scalar.width
          }
          let column_size = wgsl_ir_align_to(
            rows.width() * scalar.width,
            column_align,
          )
          WgslIrLayout::{
            align: column_align,
            size: column_size * columns.width(),
          }
        }
        Array(base, size, stride) => {
          let base_layout = self.type_layout(base)
          WgslIrLayout::{
            align: base_layout.align,
            size: self.array_size_layout_count(size) * stride,
          }
        }
        Struct(members, span) | PredeclaredStruct(members, span) => {
          let mut align = 1
          for struct_member in members {
            let member_layout = self.type_layout(struct_member.ty)
            if member_layout.align > align {
              align = member_layout.align
            }
          }
          WgslIrLayout::{ align, size: span }
        }
        Pointer(_, _) | ValuePointer(_, _, _) =>
          WgslIrLayout::{ align: 1, size: 4 }
        Image(_, _, _)
        | Sampler(_)
        | AccelerationStructure(_)
        | RayQuery(_)
        | BindingArray(_, _) => WgslIrLayout::{ align: 1, size: 0 }
        CooperativeMatrix(columns, rows, scalar, _) =>
          WgslIrLayout::{
            align: scalar.width,
            size: wgsl_ir_cooperative_size_width(columns) *
            wgsl_ir_cooperative_size_width(rows) *
            scalar.width,
          }
      }
    None => raise WgslIrLowerError::UnsupportedType("invalid type handle")
  }
}

///|
fn WgslIrLowerer::array_size_layout_count(
  self : WgslIrLowerer,
  size : ArraySize,
) -> Int raise WgslIrLowerError {
  match size {
    Constant(value) => value
    Dynamic => 1
    Pending(handle) => {
      let (value, _) = self.eval_global_integer_expression(handle)
      if value < 0 {
        raise WgslIrLowerError::UnsupportedType(
          "array size must be non-negative",
        )
      }
      value
    }
  }
}

///|
fn wgsl_ir_struct_member_size(
  attributes : Array[@ast.WgslAttribute],
  layout : WgslIrLayout,
) -> Int raise WgslIrLowerError {
  match wgsl_ir_attribute_named(attributes, "size") {
    Some(attribute) =>
      match wgsl_ir_attribute_int_value(attribute) {
        Some(size) =>
          if size < layout.size {
            raise WgslIrLowerError::UnsupportedType(
              "@size is smaller than member type size",
            )
          } else {
            size
          }
        None =>
          raise WgslIrLowerError::UnsupportedType(
            "@size must be an integer literal",
          )
      }
    None => layout.size
  }
}

///|
fn wgsl_ir_struct_member_align(
  attributes : Array[@ast.WgslAttribute],
  layout : WgslIrLayout,
) -> Int raise WgslIrLowerError {
  match wgsl_ir_attribute_named(attributes, "align") {
    Some(attribute) =>
      match wgsl_ir_attribute_int_value(attribute) {
        Some(align) =>
          if !wgsl_ir_is_power_of_two(align) {
            raise WgslIrLowerError::UnsupportedType(
              "@align must be a positive power of two",
            )
          } else if align < layout.align {
            raise WgslIrLowerError::UnsupportedType(
              "@align is smaller than member type alignment",
            )
          } else {
            align
          }
        None =>
          raise WgslIrLowerError::UnsupportedType(
            "@align must be an integer literal",
          )
      }
    None => layout.align
  }
}

///|
fn wgsl_ir_is_power_of_two(value : Int) -> Bool {
  value > 0 && (value & (value - 1)) == 0
}

///|
fn wgsl_ir_cooperative_size_width(size : CooperativeSize) -> Int {
  match size {
    Eight => 8
    Sixteen => 16
  }
}

///|
fn WgslIrLowerer::lower_type_name_with_expression_arguments(
  self : WgslIrLowerer,
  name : String,
  arguments : Array[@ast.WgslExprNode],
) -> Handle raise WgslIrLowerError {
  match self.type_cache.get(name) {
    Some(handle) => handle
    None =>
      match wgsl_ir_builtin_vector_alias(name) {
        Some(inner) => self.intern_type(name, inner)
        None =>
          match wgsl_ir_builtin_matrix_alias(name) {
            Some(inner) => self.intern_type(name, inner)
            None =>
              match arguments {
                [] => raise WgslIrLowerError::UnsupportedType(name)
                _ => raise WgslIrLowerError::UnsupportedType(name)
              }
          }
      }
  }
}

///|
fn wgsl_ir_builtin_scalar_alias(name : String) -> TypeInner? {
  match name {
    "bool" => Some(TypeInner::Scalar(Scalar::Scalar(Bool, 1)))
    "i32" => Some(TypeInner::Scalar(Scalar::Scalar(Sint, 4)))
    "u32" => Some(TypeInner::Scalar(Scalar::Scalar(Uint, 4)))
    "f32" => Some(TypeInner::Scalar(Scalar::Scalar(Float, 4)))
    "f16" => Some(TypeInner::Scalar(Scalar::Scalar(Float, 2)))
    _ => None
  }
}

///|
fn wgsl_ir_builtin_vector_alias(name : String) -> TypeInner? {
  match name {
    "vec2f" => Some(TypeInner::Vector(Bi, Scalar::Scalar(Float, 4)))
    "vec3f" => Some(TypeInner::Vector(Tri, Scalar::Scalar(Float, 4)))
    "vec4f" => Some(TypeInner::Vector(Quad, Scalar::Scalar(Float, 4)))
    "vec2h" => Some(TypeInner::Vector(Bi, Scalar::Scalar(Float, 2)))
    "vec3h" => Some(TypeInner::Vector(Tri, Scalar::Scalar(Float, 2)))
    "vec4h" => Some(TypeInner::Vector(Quad, Scalar::Scalar(Float, 2)))
    "vec2i" => Some(TypeInner::Vector(Bi, Scalar::Scalar(Sint, 4)))
    "vec3i" => Some(TypeInner::Vector(Tri, Scalar::Scalar(Sint, 4)))
    "vec4i" => Some(TypeInner::Vector(Quad, Scalar::Scalar(Sint, 4)))
    "vec2u" => Some(TypeInner::Vector(Bi, Scalar::Scalar(Uint, 4)))
    "vec3u" => Some(TypeInner::Vector(Tri, Scalar::Scalar(Uint, 4)))
    "vec4u" => Some(TypeInner::Vector(Quad, Scalar::Scalar(Uint, 4)))
    _ => None
  }
}

///|
fn wgsl_ir_builtin_matrix_alias(name : String) -> TypeInner? {
  match name {
    "mat2x2f" => Some(TypeInner::Matrix(Bi, Bi, Scalar::Scalar(Float, 4)))
    "mat2x3f" => Some(TypeInner::Matrix(Bi, Tri, Scalar::Scalar(Float, 4)))
    "mat2x4f" => Some(TypeInner::Matrix(Bi, Quad, Scalar::Scalar(Float, 4)))
    "mat3x2f" => Some(TypeInner::Matrix(Tri, Bi, Scalar::Scalar(Float, 4)))
    "mat3x3f" => Some(TypeInner::Matrix(Tri, Tri, Scalar::Scalar(Float, 4)))
    "mat3x4f" => Some(TypeInner::Matrix(Tri, Quad, Scalar::Scalar(Float, 4)))
    "mat4x2f" => Some(TypeInner::Matrix(Quad, Bi, Scalar::Scalar(Float, 4)))
    "mat4x3f" => Some(TypeInner::Matrix(Quad, Tri, Scalar::Scalar(Float, 4)))
    "mat4x4f" => Some(TypeInner::Matrix(Quad, Quad, Scalar::Scalar(Float, 4)))
    "mat2x2h" => Some(TypeInner::Matrix(Bi, Bi, Scalar::Scalar(Float, 2)))
    "mat2x3h" => Some(TypeInner::Matrix(Bi, Tri, Scalar::Scalar(Float, 2)))
    "mat2x4h" => Some(TypeInner::Matrix(Bi, Quad, Scalar::Scalar(Float, 2)))
    "mat3x2h" => Some(TypeInner::Matrix(Tri, Bi, Scalar::Scalar(Float, 2)))
    "mat3x3h" => Some(TypeInner::Matrix(Tri, Tri, Scalar::Scalar(Float, 2)))
    "mat3x4h" => Some(TypeInner::Matrix(Tri, Quad, Scalar::Scalar(Float, 2)))
    "mat4x2h" => Some(TypeInner::Matrix(Quad, Bi, Scalar::Scalar(Float, 2)))
    "mat4x3h" => Some(TypeInner::Matrix(Quad, Tri, Scalar::Scalar(Float, 2)))
    "mat4x4h" => Some(TypeInner::Matrix(Quad, Quad, Scalar::Scalar(Float, 2)))
    _ => None
  }
}

///|
fn wgsl_ir_math_function_from_name(name : String) -> MathFunction? {
  match name {
    "abs" => Some(Abs)
    "min" => Some(Min)
    "max" => Some(Max)
    "clamp" => Some(Clamp)
    "saturate" => Some(Saturate)
    "cos" => Some(Cos)
    "cosh" => Some(Cosh)
    "sin" => Some(Sin)
    "sinh" => Some(Sinh)
    "tan" => Some(Tan)
    "tanh" => Some(Tanh)
    "acos" => Some(Acos)
    "acosh" => Some(Acosh)
    "asin" => Some(Asin)
    "asinh" => Some(Asinh)
    "atan" => Some(Atan)
    "atanh" => Some(Atanh)
    "atan2" => Some(Atan2)
    "radians" => Some(Radians)
    "degrees" => Some(Degrees)
    "ceil" => Some(Ceil)
    "floor" => Some(Floor)
    "round" => Some(Round)
    "fract" => Some(Fract)
    "trunc" => Some(Trunc)
    "modf" => Some(Modf)
    "frexp" => Some(Frexp)
    "ldexp" => Some(Ldexp)
    "exp" => Some(Exp)
    "exp2" => Some(Exp2)
    "log" => Some(Log)
    "log2" => Some(Log2)
    "pow" => Some(Pow)
    "dot" => Some(Dot)
    "dot4I8Packed" => Some(Dot4I8Packed)
    "dot4U8Packed" => Some(Dot4U8Packed)
    "cross" => Some(Cross)
    "distance" => Some(Distance)
    "length" => Some(Length)
    "normalize" => Some(Normalize)
    "faceForward" => Some(FaceForward)
    "reflect" => Some(Reflect)
    "refract" => Some(Refract)
    "sign" => Some(Sign)
    "fma" => Some(Fma)
    "mix" => Some(Mix)
    "step" => Some(Step)
    "smoothstep" => Some(SmoothStep)
    "sqrt" => Some(Sqrt)
    "inverseSqrt" => Some(InverseSqrt)
    "inverse" => Some(Inverse)
    "transpose" => Some(Transpose)
    "determinant" => Some(Determinant)
    "quantizeToF16" => Some(QuantizeToF16)
    "countTrailingZeros" => Some(CountTrailingZeros)
    "countLeadingZeros" => Some(CountLeadingZeros)
    "countOneBits" => Some(CountOneBits)
    "reverseBits" => Some(ReverseBits)
    "extractBits" => Some(ExtractBits)
    "insertBits" => Some(InsertBits)
    "firstTrailingBit" => Some(FirstTrailingBit)
    "firstLeadingBit" => Some(FirstLeadingBit)
    "pack4x8snorm" => Some(Pack4x8snorm)
    "pack4x8unorm" => Some(Pack4x8unorm)
    "pack2x16snorm" => Some(Pack2x16snorm)
    "pack2x16unorm" => Some(Pack2x16unorm)
    "pack2x16float" => Some(Pack2x16float)
    "pack4xI8" => Some(Pack4xI8)
    "pack4xU8" => Some(Pack4xU8)
    "pack4xI8Clamp" => Some(Pack4xI8Clamp)
    "pack4xU8Clamp" => Some(Pack4xU8Clamp)
    "unpack4x8snorm" => Some(Unpack4x8snorm)
    "unpack4x8unorm" => Some(Unpack4x8unorm)
    "unpack2x16snorm" => Some(Unpack2x16snorm)
    "unpack2x16unorm" => Some(Unpack2x16unorm)
    "unpack2x16float" => Some(Unpack2x16float)
    "unpack4xI8" => Some(Unpack4xI8)
    "unpack4xU8" => Some(Unpack4xU8)
    _ => None
  }
}

///|
fn wgsl_ir_derivative_function_from_name(
  name : String,
) -> (DerivativeAxis, DerivativeControl)? {
  match name {
    "dpdx" => Some((X, DerivativeControl::None))
    "dpdxCoarse" => Some((X, Coarse))
    "dpdxFine" => Some((X, Fine))
    "dpdy" => Some((Y, DerivativeControl::None))
    "dpdyCoarse" => Some((Y, Coarse))
    "dpdyFine" => Some((Y, Fine))
    "fwidth" => Some((Width, DerivativeControl::None))
    "fwidthCoarse" => Some((Width, Coarse))
    "fwidthFine" => Some((Width, Fine))
    _ => None
  }
}

///|
fn wgsl_ir_relational_function_from_name(name : String) -> RelationalFunction? {
  match name {
    "all" => Some(All)
    "any" => Some(Any)
    "isNan" => Some(IsNan)
    "isInf" => Some(IsInf)
    _ => None
  }
}

///|
fn wgsl_ir_relational_function_name(
  relational_function : RelationalFunction,
) -> String {
  match relational_function {
    All => "all"
    Any => "any"
    IsNan => "isNan"
    IsInf => "isInf"
  }
}

///|
fn wgsl_ir_atomic_function_from_name(name : String) -> AtomicFunction? {
  match name {
    "atomicLoad" => Some(Load)
    "atomicStore" => Some(Store)
    "atomicAdd" => Some(Add)
    "atomicSub" => Some(Subtract)
    "atomicMax" => Some(Max)
    "atomicMin" => Some(Min)
    "atomicAnd" => Some(And)
    "atomicOr" => Some(InclusiveOr)
    "atomicXor" => Some(ExclusiveOr)
    "atomicExchange" => Some(Exchange)
    "atomicCompareExchangeWeak" => Some(CompareExchangeWeak)
    _ => None
  }
}

///|
fn wgsl_ir_atomic_function_name(function : AtomicFunction) -> String {
  match function {
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
fn wgsl_ir_align_to(value : Int, align : Int) -> Int {
  if align <= 1 {
    value
  } else {
    let rem = value % align
    if rem == 0 {
      value
    } else {
      value + align - rem
    }
  }
}

///|
fn wgsl_ir_vector_size_from_name(name : String) -> VectorSize {
  match name {
    "vec2" => Bi
    "vec3" => Tri
    _ => Quad
  }
}

///|
fn wgsl_ir_matrix_size_from_name(name : String) -> (VectorSize, VectorSize) {
  match name {
    "mat2x2" => (Bi, Bi)
    "mat2x3" => (Bi, Tri)
    "mat2x4" => (Bi, Quad)
    "mat3x2" => (Tri, Bi)
    "mat3x3" => (Tri, Tri)
    "mat3x4" => (Tri, Quad)
    "mat4x2" => (Quad, Bi)
    "mat4x3" => (Quad, Tri)
    _ => (Quad, Quad)
  }
}

///|
fn WgslIrLowerer::literal_from_token_with_expected(
  self : WgslIrLowerer,
  token : @ast.WgslExprToken,
  expected_ty : Handle?,
) -> Literal raise WgslIrLowerError {
  let literal = wgsl_ir_literal_from_token(token)
  guard expected_ty is Some(ty_handle) else { return literal }
  match self.shader_module.types.get(ty_handle) {
    Some(ty) =>
      match ty.inner {
        Scalar(scalar) => wgsl_ir_contextualize_literal(literal, scalar)
        _ => literal
      }
    None => literal
  }
}

///|
fn wgsl_ir_contextualize_literal(
  literal : Literal,
  scalar : Scalar,
) -> Literal raise WgslIrLowerError {
  match (literal, scalar.kind) {
    (AbstractInt(value), Sint) => Literal::I32(value.to_int())
    (AbstractInt(value), Uint) => {
      let parsed : UInt = @strconv.from_str("\{value}") catch {
        _ =>
          raise WgslIrLowerError::UnsupportedExpression(
            "unsigned literal \{value}",
          )
      }
      Literal::U32(parsed)
    }
    _ => literal
  }
}

///|
fn wgsl_ir_literal_from_token(
  token : @ast.WgslExprToken,
) -> Literal raise WgslIrLowerError {
  match token.kind() {
    BoolLiteral(value) => Literal::Bool(value)
    IntLiteral(value) =>
      if wgsl_ir_literal_has_suffix(token.text(), "h") {
        Literal::F16Bits(value)
      } else if wgsl_ir_literal_has_suffix(token.text(), "i") {
        Literal::I32(value)
      } else {
        Literal::AbstractInt(wgsl_ir_int64_literal_from_text(token.text()))
      }
    UintLiteral(value) => {
      let parsed : UInt = @strconv.from_str("\{value}") catch {
        _ => raise WgslIrLowerError::UnsupportedExpression(token.text())
      }
      Literal::U32(parsed)
    }
    FloatLiteral => {
      if wgsl_ir_literal_has_suffix(token.text(), "h") {
        let h_text = wgsl_ir_literal_without_suffix(token.text())
        let value : Int = @strconv.from_str(h_text) catch {
          _ => raise WgslIrLowerError::UnsupportedExpression(token.text())
        }
        return Literal::F16Bits(value)
      }
      let text = wgsl_ir_float_literal_text(token.text())
      let value : Double = @strconv.from_str(text) catch {
        _ => raise WgslIrLowerError::UnsupportedExpression(token.text())
      }
      Literal::AbstractFloat(value)
    }
    _ => raise WgslIrLowerError::UnsupportedExpression(token.text())
  }
}

///|
fn wgsl_ir_literal_has_suffix(text : String, lower_suffix : String) -> Bool {
  if text.length() == 0 {
    return false
  }
  let last = text[text.length() - 1:].to_owned().to_lower()
  last == lower_suffix
}

///|
fn wgsl_ir_literal_without_suffix(text : String) -> String {
  if text.length() == 0 {
    text
  } else {
    text[0:text.length() - 1].to_owned()
  }
}

///|
fn wgsl_ir_int64_literal_from_text(
  text : String,
) -> Int64 raise WgslIrLowerError {
  let mut end = text.length()
  if end > 0 {
    let last = text.code_unit_at(end - 1).to_int()
    if last == 105 || last == 73 {
      end = end - 1
    }
  }
  guard end > 0 else { raise WgslIrLowerError::UnsupportedExpression(text) }
  let mut value : Int64 = 0
  if end > 2 &&
    text.code_unit_at(0).to_int() == 48 &&
    (
      text.code_unit_at(1).to_int() == 120 ||
      text.code_unit_at(1).to_int() == 88
    ) {
    for i in 2..<end {
      match wgsl_ir_hex_digit_value(text.code_unit_at(i).to_int()) {
        Some(digit) => value = value * 16 + Int64::from_int(digit)
        None => raise WgslIrLowerError::UnsupportedExpression(text)
      }
    }
    return value
  }
  for i in 0..<end {
    let code = text.code_unit_at(i).to_int()
    if code < 48 || code > 57 {
      raise WgslIrLowerError::UnsupportedExpression(text)
    }
    value = value * 10 + Int64::from_int(code - 48)
  }
  value
}

///|
fn wgsl_ir_hex_digit_value(code : Int) -> Int? {
  if code >= 48 && code <= 57 {
    return Some(code - 48)
  }
  if code >= 65 && code <= 70 {
    return Some(code - 65 + 10)
  }
  if code >= 97 && code <= 102 {
    return Some(code - 97 + 10)
  }
  None
}

///|
fn wgsl_ir_float_literal_text(text : String) -> String {
  let trimmed = text.trim().to_owned()
  if trimmed.contains("f") {
    match trimmed.split("f").collect() {
      [head, ..] => head.to_owned()
      [] => trimmed
    }
  } else if trimmed.contains("h") {
    match trimmed.split("h").collect() {
      [head, ..] => head.to_owned()
      [] => trimmed
    }
  } else {
    trimmed
  }
}

///|
fn wgsl_ir_int_literal_from_expr_ref(expr_ref : @ast.WgslExprRef) -> Int? {
  match expr_ref.root() {
    Some(node) =>
      match node.kind() {
        Literal(token) =>
          match token.kind() {
            IntLiteral(value) | UintLiteral(value) => Some(value)
            _ => None
          }
        _ => None
      }
    None => None
  }
}

///|
fn wgsl_ir_unary_operator(
  op : @ast.WgslExprOperator,
) -> UnaryOperator raise WgslIrLowerError {
  match op {
    Subtract => UnaryOperator::Negate
    Not => UnaryOperator::LogicalNot
    Complement => UnaryOperator::BitwiseNot
    _ =>
      raise WgslIrLowerError::UnsupportedExpression(
        "unary operator \{op.text()}",
      )
  }
}

///|
fn wgsl_ir_binary_operator(
  op : @ast.WgslExprOperator,
) -> BinaryOperator raise WgslIrLowerError {
  match op {
    Add => BinaryOperator::Add
    Subtract => BinaryOperator::Subtract
    Multiply => BinaryOperator::Multiply
    Divide => BinaryOperator::Divide
    Modulo => BinaryOperator::Modulo
    Equal => BinaryOperator::Equal
    NotEqual => BinaryOperator::NotEqual
    Less => BinaryOperator::Less
    LessEqual => BinaryOperator::LessEqual
    Greater => BinaryOperator::Greater
    GreaterEqual => BinaryOperator::GreaterEqual
    BitAnd => BinaryOperator::And
    BitXor => BinaryOperator::ExclusiveOr
    BitOr => BinaryOperator::InclusiveOr
    LogicalAnd => BinaryOperator::LogicalAnd
    LogicalOr => BinaryOperator::LogicalOr
    ShiftLeft => BinaryOperator::ShiftLeft
    ShiftRight => BinaryOperator::ShiftRight
    _ =>
      raise WgslIrLowerError::UnsupportedExpression(
        "binary operator \{op.text()}",
      )
  }
}

///|
fn wgsl_ir_compound_assignment_operator(op : String) -> BinaryOperator? {
  match op {
    "+=" => Some(BinaryOperator::Add)
    "-=" => Some(BinaryOperator::Subtract)
    "*=" => Some(BinaryOperator::Multiply)
    "/=" => Some(BinaryOperator::Divide)
    "%=" => Some(BinaryOperator::Modulo)
    "&=" => Some(BinaryOperator::And)
    "^=" => Some(BinaryOperator::ExclusiveOr)
    "|=" => Some(BinaryOperator::InclusiveOr)
    "<<=" => Some(BinaryOperator::ShiftLeft)
    ">>=" => Some(BinaryOperator::ShiftRight)
    _ => None
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
    Load(inner) => self.function_expression_type(function, inner)
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
    RayQueryProceedResult => self.type_cache.get("bool")
    Literal(literal) => self.literal_type(literal)
    _ => None
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
    _ => Some(input_ty)
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
        Matrix(_, rows, scalar) =>
          match self.shader_module.types.get(right_ty) {
            Some(right) =>
              match right.inner {
                Vector(_, _) => Some(self.vector_type_handle(rows, scalar))
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
          },
          StructMember::{
            name: Some("exchanged"),
            ty: bool_ty,
            binding: None,
            offset: exchanged_offset,
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
          },
          StructMember::{
            name: Some("whole"),
            ty: value_ty,
            binding: None,
            offset: whole_offset,
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
          },
          StructMember::{
            name: Some("exp"),
            ty: exponent_ty,
            binding: None,
            offset: exponent_offset,
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
fn WgslIrLowerer::image_expression_result_type(
  self : WgslIrLowerer,
  function : Function,
  image : Handle,
  gather : SwizzleComponent?,
  depth_ref : Handle?,
) -> Handle? {
  guard self.function_expression_type(function, image) is Some(image_ty) else {
    return None
  }
  match self.shader_module.types.items.get(image_ty.index()) {
    Some(ty) =>
      match ty.inner {
        Image(_, _, Sampled(kind, _)) =>
          Some(
            self.intern_type(
              "vec4<\{wgsl_ir_scalar_name(kind, 4)}>",
              TypeInner::Vector(Quad, Scalar::Scalar(kind, 4)),
            ),
          )
        Image(_, _, Depth(_)) =>
          if gather != None {
            Some(
              self.intern_type(
                "vec4<f32>",
                TypeInner::Vector(Quad, Scalar::Scalar(Float, 4)),
              ),
            )
          } else if depth_ref != None {
            self.type_cache.get("f32")
          } else {
            self.type_cache.get("f32")
          }
        Image(_, _, Storage(format, _)) => {
          let kind = wgsl_ir_storage_format_scalar_kind(format)
          Some(
            self.intern_type(
              "vec4<\{wgsl_ir_scalar_name(kind, 4)}>",
              TypeInner::Vector(Quad, Scalar::Scalar(kind, 4)),
            ),
          )
        }
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrLowerer::image_query_expression_result_type(
  self : WgslIrLowerer,
  function : Function,
  image : Handle,
  query : ImageQuery,
) -> Handle? {
  match query {
    Size(_) =>
      match self.image_expression_inner(function, image) {
        Some((dimension, _, _)) =>
          Some(self.image_dimension_size_type(dimension))
        None => None
      }
    NumLevels | NumLayers | NumSamples => self.type_cache.get("u32")
  }
}

///|
fn WgslIrLowerer::image_dimension_size_type(
  self : WgslIrLowerer,
  dimension : ImageDimension,
) -> Handle {
  let u32_scalar = Scalar::Scalar(Uint, 4)
  match dimension {
    D1 => self.scalar_type_handle(u32_scalar)
    D2 | Cube => self.numeric_value_type_handle(Some(Bi), u32_scalar)
    D3 => self.numeric_value_type_handle(Some(Tri), u32_scalar)
  }
}

///|
fn WgslIrLowerer::indexed_expression_type(
  self : WgslIrLowerer,
  function : Function,
  base : Handle,
  index : Int?,
) -> Handle? {
  guard self.function_expression_type(function, base) is Some(base_ty) else {
    return None
  }
  self.indexed_type_from_type_handle(base_ty, index)
}

///|
fn WgslIrLowerer::indexed_type_from_type_handle(
  self : WgslIrLowerer,
  ty_handle : Handle,
  index : Int?,
) -> Handle? {
  match self.shader_module.types.get(ty_handle) {
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
        Vector(_, scalar) => Some(self.scalar_type_handle(scalar))
        Matrix(_, rows, scalar) => Some(self.vector_type_handle(rows, scalar))
        Array(element, _, _) | BindingArray(element, _) => Some(element)
        Pointer(inner, _) => self.indexed_type_from_type_handle(inner, index)
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrLowerer::array_element_type(
  self : WgslIrLowerer,
  ty_handle : Handle,
) -> Handle? {
  match self.shader_module.types.get(ty_handle) {
    Some(ty) =>
      match ty.inner {
        Array(element, _, _) | BindingArray(element, _) => Some(element)
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrLowerer::expected_constructor_type(
  self : WgslIrLowerer,
  name : String,
  expected_ty : Handle?,
) -> Handle? {
  guard expected_ty is Some(ty_handle) else { return None }
  match self.shader_module.types.get(ty_handle) {
    Some(ty) =>
      match ty.inner {
        Scalar(scalar) =>
          if name == wgsl_ir_scalar_name(scalar.kind, scalar.width) {
            Some(ty_handle)
          } else {
            None
          }
        Vector(size, _) =>
          if name == "vec\{size.width()}" {
            Some(ty_handle)
          } else {
            None
          }
        Matrix(columns, rows, _) =>
          if name == "mat\{columns.width()}x\{rows.width()}" {
            Some(ty_handle)
          } else {
            None
          }
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrLowerer::constructor_component_expected_type(
  self : WgslIrLowerer,
  ty_handle : Handle,
) -> Handle? {
  match self.shader_module.types.get(ty_handle) {
    Some(ty) =>
      match ty.inner {
        Vector(_, scalar) => Some(self.scalar_type_handle(scalar))
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrLowerer::literal_type(
  self : WgslIrLowerer,
  literal : Literal,
) -> Handle? {
  match literal {
    Bool(_) => self.type_cache.get("bool")
    I32(_) => self.type_cache.get("i32")
    AbstractInt(_) => self.type_cache.get("__abstract_int")
    U32(_) => self.type_cache.get("u32")
    F16Bits(_) => self.type_cache.get("f16")
    F32(_) => self.type_cache.get("f32")
    AbstractFloat(_) => self.type_cache.get("__abstract_float")
    _ => None
  }
}

///|
fn WgslIrLowerer::scalar_type_handle(
  self : WgslIrLowerer,
  scalar : Scalar,
) -> Handle {
  let name = match scalar.kind {
    Bool => "bool"
    Sint => "i32"
    Uint => "u32"
    Float => if scalar.width == 2 { "f16" } else { "f32" }
    AbstractInt => "__abstract_int"
    AbstractFloat => "__abstract_float"
  }
  self.intern_type(name, TypeInner::Scalar(scalar))
}

///|
fn wgsl_ir_scalar_name(kind : ScalarKind, width : Int) -> String {
  match kind {
    Bool => "bool"
    Sint => "i32"
    Uint => "u32"
    Float => if width == 2 { "f16" } else { "f32" }
    AbstractInt => "__abstract_int"
    AbstractFloat => "__abstract_float"
  }
}

///|
fn wgsl_ir_storage_format_scalar_kind(format : StorageFormat) -> ScalarKind {
  match format {
    R8Uint
    | R16Uint
    | Rg8Uint
    | R32Uint
    | Rg16Uint
    | Rgba8Uint
    | Rgb10a2Uint
    | R64Uint
    | Rg32Uint
    | Rgba16Uint
    | Rgba32Uint => Uint
    R8Sint
    | R16Sint
    | Rg8Sint
    | R32Sint
    | Rg16Sint
    | Rgba8Sint
    | Rg32Sint
    | Rgba16Sint
    | Rgba32Sint => Sint
    _ => Float
  }
}

///|
fn wgsl_ir_gather_component_from_node(
  node : @ast.WgslExprNode,
) -> SwizzleComponent raise WgslIrLowerError {
  match node.kind() {
    Literal(token) =>
      match token.kind() {
        IntLiteral(value) | UintLiteral(value) =>
          match value {
            0 => SwizzleComponent::X
            1 => SwizzleComponent::Y
            2 => SwizzleComponent::Z
            3 => SwizzleComponent::W
            _ =>
              raise WgslIrLowerError::UnsupportedExpression(
                "textureGather component must be 0, 1, 2, or 3",
              )
          }
        _ =>
          raise WgslIrLowerError::UnsupportedExpression(
            "textureGather component must be an integer literal",
          )
      }
    _ =>
      raise WgslIrLowerError::UnsupportedExpression(
        "textureGather component must be an integer literal",
      )
  }
}

///|
fn wgsl_ir_expr_node_is_gather_component(node : @ast.WgslExprNode) -> Bool {
  match node.kind() {
    Literal(token) =>
      match token.kind() {
        IntLiteral(value) | UintLiteral(value) => value >= 0 && value <= 3
        _ => false
      }
    _ => false
  }
}

///|
fn wgsl_ir_struct_member_index(
  members : Array[StructMember],
  member_name : String,
) -> Int? {
  for i in 0..<members.length() {
    if members[i].name == Some(member_name) {
      return Some(i)
    }
  }
  None
}

///|
fn wgsl_ir_member_index(name : String) -> Int raise WgslIrLowerError {
  match name {
    "x" | "r" => 0
    "y" | "g" => 1
    "z" | "b" => 2
    "w" | "a" => 3
    _ =>
      raise WgslIrLowerError::UnsupportedExpression(
        "member access requires resolved struct member index: \{name}",
      )
  }
}

///|
fn wgsl_ir_swizzle_components(name : String) -> Array[SwizzleComponent]? {
  if name.length() == 0 || name.length() > 4 {
    return None
  }
  let components : Array[SwizzleComponent] = []
  for i in 0..<name.length() {
    match name.code_unit_at(i).to_int() {
      120 | 114 => components.push(SwizzleComponent::X)
      121 | 103 => components.push(SwizzleComponent::Y)
      122 | 98 => components.push(SwizzleComponent::Z)
      119 | 97 => components.push(SwizzleComponent::W)
      _ => return None
    }
  }
  Some(components)
}

///|
fn wgsl_ir_vector_size_from_component_count(count : Int) -> VectorSize {
  match count {
    2 => Bi
    3 => Tri
    _ => Quad
  }
}

///|
fn wgsl_ir_attribute_named(
  attributes : Array[@ast.WgslAttribute],
  name : String,
) -> @ast.WgslAttribute? {
  for attribute in attributes {
    if attribute.name().name() == name {
      break Some(attribute)
    }
  } nobreak {
    None
  }
}

///|
fn wgsl_ir_attribute_int_value(attribute : @ast.WgslAttribute) -> Int? {
  match attribute.arguments_ref() {
    Some(expr_ref) => wgsl_ir_int_literal_from_expr_ref(expr_ref)
    None => None
  }
}

///|
fn wgsl_ir_attribute_identifier_value(
  attribute : @ast.WgslAttribute,
) -> String? {
  match attribute.arguments_ref() {
    Some(expr_ref) =>
      match expr_ref.root() {
        Some(node) =>
          match node.kind() {
            Identifier(name) => Some(name.name())
            _ => None
          }
        None => None
      }
    None => None
  }
}

///|
fn wgsl_ir_binding_from_attributes(
  attributes : Array[@ast.WgslAttribute],
) -> Binding? raise WgslIrLowerError {
  match wgsl_ir_attribute_named(attributes, "builtin") {
    Some(attribute) =>
      match wgsl_ir_attribute_identifier_value(attribute) {
        Some(name) => Some(Binding::BuiltIn(wgsl_ir_builtin_from_name(name)))
        None => None
      }
    None =>
      match wgsl_ir_attribute_named(attributes, "location") {
        Some(attribute) =>
          match wgsl_ir_attribute_int_value(attribute) {
            Some(location) =>
              Some(
                Binding::Location(
                  location,
                  wgsl_ir_interpolation_from_attributes(attributes),
                  wgsl_ir_sampling_from_attributes(attributes),
                  wgsl_ir_blend_src_from_attributes(attributes),
                  false,
                ),
              )
            None => None
          }
        None => None
      }
  }
}

///|
fn wgsl_ir_blend_src_from_attributes(
  attributes : Array[@ast.WgslAttribute],
) -> Int? {
  match wgsl_ir_attribute_named(attributes, "blend_src") {
    Some(attribute) => wgsl_ir_attribute_int_value(attribute)
    None => None
  }
}

///|
fn wgsl_ir_builtin_from_name(name : String) -> BuiltIn raise WgslIrLowerError {
  match name {
    "position" => BuiltIn::Position(false)
    "view_index" => BuiltIn::ViewIndex
    "clip_distances" => BuiltIn::ClipDistances
    "primitive_index" => BuiltIn::PrimitiveIndex
    "vertex_index" => BuiltIn::VertexIndex
    "instance_index" => BuiltIn::InstanceIndex
    "front_facing" => BuiltIn::FrontFacing
    "frag_depth" => BuiltIn::FragDepth
    "sample_index" => BuiltIn::SampleIndex
    "sample_mask" => BuiltIn::SampleMask
    "global_invocation_id" => BuiltIn::GlobalInvocationId
    "local_invocation_id" => BuiltIn::LocalInvocationId
    "local_invocation_index" => BuiltIn::LocalInvocationIndex
    "workgroup_id" => BuiltIn::WorkGroupId
    "num_workgroups" => BuiltIn::NumWorkGroups
    "num_subgroups" => BuiltIn::NumSubgroups
    "subgroup_id" => BuiltIn::SubgroupId
    "subgroup_size" => BuiltIn::SubgroupSize
    "subgroup_invocation_id" => BuiltIn::SubgroupInvocationId
    _ =>
      raise WgslIrLowerError::UnsupportedExpression(
        "unknown builtin attribute: \{name}",
      )
  }
}

///|
fn wgsl_ir_interpolation_from_attributes(
  attributes : Array[@ast.WgslAttribute],
) -> Interpolation? {
  match wgsl_ir_attribute_named(attributes, "interpolate") {
    Some(attribute) =>
      match attribute.arguments_ref() {
        Some(expr_ref) =>
          match expr_ref.identifiers() {
            [name, ..] =>
              match name.name() {
                "perspective" => Some(Interpolation::Perspective)
                "linear" => Some(Interpolation::Linear)
                "flat" => Some(Interpolation::Flat)
                _ => None
              }
            [] => None
          }
        None => None
      }
    None => None
  }
}

///|
fn wgsl_ir_sampling_from_attributes(
  attributes : Array[@ast.WgslAttribute],
) -> Sampling? {
  match wgsl_ir_attribute_named(attributes, "interpolate") {
    Some(attribute) =>
      match attribute.arguments_ref() {
        Some(expr_ref) =>
          match expr_ref.identifiers() {
            [_, sampling, ..] =>
              match sampling.name() {
                "center" => Some(Sampling::Center)
                "centroid" => Some(Sampling::Centroid)
                "sample" => Some(Sampling::Sample)
                "first" => Some(Sampling::First)
                "either" => Some(Sampling::Either)
                _ => None
              }
            _ => None
          }
        None => None
      }
    None => None
  }
}

///|
fn wgsl_ir_resource_binding_from_attributes(
  attributes : Array[@ast.WgslAttribute],
) -> ResourceBinding? {
  match wgsl_ir_attribute_named(attributes, "group") {
    Some(group_attribute) =>
      match wgsl_ir_attribute_named(attributes, "binding") {
        Some(binding_attribute) =>
          match
            (
              wgsl_ir_attribute_int_value(group_attribute),
              wgsl_ir_attribute_int_value(binding_attribute),
            ) {
            (Some(group), Some(binding)) =>
              Some(ResourceBinding::{ group, binding })
            _ => None
          }
        None => None
      }
    None => None
  }
}

///|
fn wgsl_ir_address_space_from_template_list(
  template_list : Array[@ast.WgslTypeRef],
) -> AddressSpace {
  match template_list {
    [space, .. rest] =>
      match space.name() {
        "storage" =>
          match rest {
            [access, ..] =>
              AddressSpace::Storage(
                wgsl_ir_storage_access_from_name(access.name()),
              )
            [] => AddressSpace::Storage(StorageAccess::load())
          }
        other => wgsl_ir_address_space_from_type_name(other)
      }
    [] => AddressSpace::Private
  }
}

///|
fn wgsl_ir_address_space_from_type_name(name : String) -> AddressSpace {
  match name {
    "function" => AddressSpace::Function
    "private" => AddressSpace::Private
    "workgroup" => AddressSpace::WorkGroup
    "uniform" => AddressSpace::Uniform
    "storage" => AddressSpace::Storage(StorageAccess::load())
    "handle" => AddressSpace::Handle
    "immediate" => AddressSpace::Immediate
    _ => AddressSpace::Private
  }
}

///|
fn wgsl_ir_address_space_key(space : AddressSpace) -> String {
  match space {
    Function => "function"
    Private => "private"
    WorkGroup => "workgroup"
    Uniform => "uniform"
    Storage(access) => "storage,\{wgsl_ir_storage_access_key(access)}"
    Handle => "handle"
    Immediate => "immediate"
    TaskPayload => "task_payload"
    RayPayload => "ray_payload"
    IncomingRayPayload => "incoming_ray_payload"
  }
}

///|
fn wgsl_ir_storage_access_key(access : StorageAccess) -> String {
  if access.contains(StorageAccess::load()) &&
    access.contains(StorageAccess::store()) {
    "read_write"
  } else if access.contains(StorageAccess::store()) {
    "write"
  } else {
    "read"
  }
}

///|
fn wgsl_ir_storage_access_from_name(name : String) -> StorageAccess {
  match name {
    "read" => StorageAccess::load()
    "write" => StorageAccess::store()
    "read_write" => StorageAccess::load().union(StorageAccess::store())
    _ => StorageAccess::load()
  }
}

///|
fn wgsl_ir_memory_decorations_from_attributes(
  attributes : Array[@ast.WgslAttribute],
) -> MemoryDecorations {
  let mut decorations = MemoryDecorations::empty()
  match wgsl_ir_attribute_named(attributes, "coherent") {
    Some(_) => decorations = decorations.union(MemoryDecorations::coherent())
    None => ()
  }
  match wgsl_ir_attribute_named(attributes, "volatile") {
    Some(_) =>
      decorations = decorations.union(MemoryDecorations::volatile_decoration())
    None => ()
  }
  decorations
}

///|
fn wgsl_ir_id_from_attributes(attributes : Array[@ast.WgslAttribute]) -> Int? {
  match wgsl_ir_attribute_named(attributes, "id") {
    Some(attribute) => wgsl_ir_attribute_int_value(attribute)
    None => None
  }
}

///|
fn wgsl_ir_shader_stage_from_attributes(
  attributes : Array[@ast.WgslAttribute],
) -> ShaderStage? {
  match wgsl_ir_attribute_named(attributes, "vertex") {
    Some(_) => Some(ShaderStage::Vertex)
    None =>
      match wgsl_ir_attribute_named(attributes, "fragment") {
        Some(_) => Some(ShaderStage::Fragment)
        None =>
          match wgsl_ir_attribute_named(attributes, "compute") {
            Some(_) => Some(ShaderStage::Compute)
            None => None
          }
      }
  }
}

///|
fn wgsl_ir_early_depth_test_from_attributes(
  attributes : Array[@ast.WgslAttribute],
) -> EarlyDepthTest? {
  match wgsl_ir_attribute_named(attributes, "early_depth_test") {
    Some(_) => Some(EarlyDepthTest::Force)
    None => None
  }
}

///|
fn WgslIrLowerer::workgroup_size_from_attributes(
  self : WgslIrLowerer,
  attributes : Array[@ast.WgslAttribute],
) -> (Array[Int], Array[Handle?]?) raise WgslIrLowerError {
  match wgsl_ir_attribute_named(attributes, "workgroup_size") {
    Some(attribute) =>
      match attribute.arguments_ref() {
        Some(expr_ref) => {
          let nodes = match expr_ref.root() {
            Some(root) => wgsl_ir_flatten_workgroup_size_arguments(root)
            None => []
          }
          let values : Array[Int] = [1, 1, 1]
          let overrides : Array[Handle?] = [None, None, None]
          for i in 0..<3 {
            match nodes.get(i) {
              Some(node) => {
                let (value, override_handle) = self.workgroup_size_dimension_from_node(
                  node,
                )
                values[i] = value
                overrides[i] = override_handle
              }
              None => ()
            }
          }
          if wgsl_ir_optional_handle_array_is_empty(overrides) {
            (values, None)
          } else {
            (values, Some(overrides))
          }
        }
        None => ([1, 1, 1], None)
      }
    None => ([1, 1, 1], None)
  }
}

///|
fn wgsl_ir_flatten_workgroup_size_arguments(
  root : @ast.WgslExprNode,
) -> Array[@ast.WgslExprNode] {
  match root.kind() {
    Sequence(items) => items
    _ => [root]
  }
}

///|
fn WgslIrLowerer::workgroup_size_dimension_from_node(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
) -> (Int, Handle?) raise WgslIrLowerError {
  let handle = self.lower_global_expression_node(node)
  let evaluated = Some(self.eval_global_integer_expression(handle)) catch {
    _ => None
  }
  match evaluated {
    Some((value, _)) => (value, None)
    None =>
      if self.global_expression_references_override(handle) {
        (1, Some(handle))
      } else {
        raise WgslIrLowerError::UnsupportedExpression(
          "workgroup_size dimension must be a const or override integer expression",
        )
      }
  }
}

///|
fn WgslIrLowerer::global_expression_references_override(
  self : WgslIrLowerer,
  handle : Handle,
) -> Bool {
  match self.shader_module.global_expressions.items.get(handle.index()) {
    Some(expression) =>
      self.global_expression_inner_references_override(expression)
    None => false
  }
}

///|
fn WgslIrLowerer::global_expression_inner_references_override(
  self : WgslIrLowerer,
  expression : Expression,
) -> Bool {
  match expression {
    Override(_) => true
    Constant(handle) =>
      match self.shader_module.constants.items.get(handle.index()) {
        Some(constant) =>
          self.global_expression_references_override(constant.init)
        None => false
      }
    Compose(_, components)
    | AtomicCall(_, components)
    | FunctionCall(_, components) =>
      wgsl_ir_global_expression_list_references_override(self, components)
    Access(base, index) | Binary(_, base, index) =>
      self.global_expression_references_override(base) ||
      self.global_expression_references_override(index)
    AccessIndex(base, _)
    | Splat(_, base)
    | Swizzle(_, base, _)
    | Load(base)
    | Unary(_, base)
    | Bitcast(_, base)
    | Derivative(_, _, base)
    | Relational(_, base)
    | As(base, _, _)
    | CallResult(base)
    | AtomicResult(base, _)
    | WorkGroupUniformLoadResult(base)
    | ArrayLength(base)
    | RayQueryProceed(base)
    | RayQueryConfirmIntersection(base)
    | RayQueryTerminate(base)
    | RayQueryVertexPositions(base, _)
    | RayQueryGetIntersection(base, _)
    | SubgroupOperationResult(base) =>
      self.global_expression_references_override(base)
    AddressOf(_, target) => self.global_expression_references_override(target)
    RayQueryGenerateIntersection(base, intersection_t) =>
      self.global_expression_references_override(base) ||
      self.global_expression_references_override(intersection_t)
    RayQueryInitialize(query, acceleration, ray_desc) =>
      self.global_expression_references_override(query) ||
      self.global_expression_references_override(acceleration) ||
      self.global_expression_references_override(ray_desc)
    CooperativeMultiplyAdd(a, b, c) =>
      self.global_expression_references_override(a) ||
      self.global_expression_references_override(b) ||
      self.global_expression_references_override(c)
    ImageLoad(image, coordinate, array_index, sample, level) =>
      self.global_expression_references_override(image) ||
      self.global_expression_references_override(coordinate) ||
      wgsl_ir_optional_global_expression_references_override(self, array_index) ||
      wgsl_ir_optional_global_expression_references_override(self, sample) ||
      wgsl_ir_optional_global_expression_references_override(self, level)
    ImageQuery(image, query) =>
      self.global_expression_references_override(image) ||
      wgsl_ir_image_query_references_override(self, query)
    ImageSample(
      image,
      sampler,
      _,
      coordinate,
      array_index,
      offset,
      level,
      depth_ref,
      _
    ) =>
      self.global_expression_references_override(image) ||
      self.global_expression_references_override(sampler) ||
      self.global_expression_references_override(coordinate) ||
      wgsl_ir_optional_global_expression_references_override(self, array_index) ||
      wgsl_ir_optional_global_expression_references_override(self, offset) ||
      wgsl_ir_sample_level_references_override(self, level) ||
      wgsl_ir_optional_global_expression_references_override(self, depth_ref)
    Select(condition, accept, reject) =>
      self.global_expression_references_override(condition) ||
      self.global_expression_references_override(accept) ||
      self.global_expression_references_override(reject)
    Math(_, a, b, c, d) =>
      self.global_expression_references_override(a) ||
      wgsl_ir_optional_global_expression_references_override(self, b) ||
      wgsl_ir_optional_global_expression_references_override(self, c) ||
      wgsl_ir_optional_global_expression_references_override(self, d)
    Literal(_)
    | ZeroValue(_)
    | FunctionArgument(_)
    | GlobalVariable(_)
    | LocalVariable(_)
    | RayQueryProceedResult
    | SubgroupBallotResult
    | CooperativeLoad(_, _, _, _) => false
  }
}

///|
fn wgsl_ir_global_expression_list_references_override(
  lowerer : WgslIrLowerer,
  handles : Array[Handle],
) -> Bool {
  for handle in handles {
    if lowerer.global_expression_references_override(handle) {
      return true
    }
  }
  false
}

///|
fn wgsl_ir_optional_global_expression_references_override(
  lowerer : WgslIrLowerer,
  handle : Handle?,
) -> Bool {
  match handle {
    Some(handle) => lowerer.global_expression_references_override(handle)
    None => false
  }
}

///|
fn wgsl_ir_sample_level_references_override(
  lowerer : WgslIrLowerer,
  level : SampleLevel,
) -> Bool {
  match level {
    Exact(handle) | Bias(handle) =>
      lowerer.global_expression_references_override(handle)
    Zero => false
    Gradient(x, y) =>
      lowerer.global_expression_references_override(x) ||
      lowerer.global_expression_references_override(y)
    Auto => false
  }
}

///|
fn wgsl_ir_image_query_references_override(
  lowerer : WgslIrLowerer,
  query : ImageQuery,
) -> Bool {
  match query {
    Size(level) =>
      wgsl_ir_optional_global_expression_references_override(lowerer, level)
    NumLevels | NumLayers | NumSamples => false
  }
}

///|
fn wgsl_ir_optional_handle_array_is_empty(handles : Array[Handle?]) -> Bool {
  for handle in handles {
    if handle != None {
      return false
    }
  }
  true
}

///|
fn wgsl_ir_image_dimension_from_name(name : String) -> ImageDimension {
  if name.contains("_1d") {
    ImageDimension::D1
  } else if name.contains("_3d") {
    ImageDimension::D3
  } else if name.contains("cube") {
    ImageDimension::Cube
  } else {
    ImageDimension::D2
  }
}

///|
fn wgsl_ir_storage_format_from_name(
  name : String,
) -> StorageFormat raise WgslIrLowerError {
  match name {
    "r8unorm" => R8Unorm
    "r8snorm" => R8Snorm
    "r8uint" => R8Uint
    "r8sint" => R8Sint
    "r16uint" => R16Uint
    "r16sint" => R16Sint
    "r16float" => R16Float
    "rg8unorm" => Rg8Unorm
    "rg8snorm" => Rg8Snorm
    "rg8uint" => Rg8Uint
    "rg8sint" => Rg8Sint
    "r32uint" => R32Uint
    "r32sint" => R32Sint
    "r32float" => R32Float
    "rg16uint" => Rg16Uint
    "rg16sint" => Rg16Sint
    "rg16float" => Rg16Float
    "rgba8unorm" => Rgba8Unorm
    "rgba8snorm" => Rgba8Snorm
    "rgba8uint" => Rgba8Uint
    "rgba8sint" => Rgba8Sint
    "bgra8unorm" => Bgra8Unorm
    "rgba16uint" => Rgba16Uint
    "rgba16sint" => Rgba16Sint
    "rgba16float" => Rgba16Float
    "rgba32uint" => Rgba32Uint
    "rgba32sint" => Rgba32Sint
    "rgba32float" => Rgba32Float
    _ => raise WgslIrLowerError::UnsupportedType("storage format \{name}")
  }
}
