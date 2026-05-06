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
}

///|
priv struct WgslIrFunctionScope {
  arguments : @hashmap.HashMap[String, Int]
  locals : @hashmap.HashMap[String, Handle]
}

///|
fn WgslIrFunctionScope::new() -> WgslIrFunctionScope {
  WgslIrFunctionScope::{
    arguments: @hashmap.HashMap::new(),
    locals: @hashmap.HashMap::new(),
  }
}

///|
fn WgslIrLowerer::new() -> WgslIrLowerer {
  WgslIrLowerer::{
    shader_module: Module::new(),
    type_cache: @hashmap.HashMap::new(),
    function_names: @hashmap.HashMap::new(),
    global_names: @hashmap.HashMap::new(),
    constant_names: @hashmap.HashMap::new(),
    override_names: @hashmap.HashMap::new(),
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
  let lowerer = WgslIrLowerer::new()
  lowerer.register_prelude_types()
  for declaration in unit.declarations() {
    lowerer.predeclare_global_declaration(declaration)
  }
  for declaration in unit.declarations() {
    lowerer.lower_global_declaration(declaration)
  }
  lowerer.shader_module
}

///|
fn WgslIrLowerer::register_prelude_types(self : WgslIrLowerer) -> Unit {
  ignore(self.intern_type("bool", TypeInner::Scalar(Scalar::new(Bool, 1))))
  ignore(self.intern_type("i32", TypeInner::Scalar(Scalar::new(Sint, 4))))
  ignore(self.intern_type("u32", TypeInner::Scalar(Scalar::new(Uint, 4))))
  ignore(self.intern_type("f32", TypeInner::Scalar(Scalar::new(Float, 4))))
  ignore(self.intern_type("f16", TypeInner::Scalar(Scalar::new(Float, 2))))
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
fn WgslIrLowerer::predeclare_global_declaration(
  self : WgslIrLowerer,
  declaration : @ast.WgslGlobalDecl,
) -> Unit {
  match declaration.data() {
    Function(function) =>
      if wgsl_ir_shader_stage_from_attributes(function.attributes()) == None {
        let handle = self.shader_module.append_function(
          Function::new(Some(function.name().name())),
        )
        self.function_names.set(function.name().name(), handle)
      }
    _ => ()
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
    Override(override_decl) => self.lower_override(override_decl)
    Function(function) => self.lower_function_declaration(function)
    _ => ()
  }
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
    offset = wgsl_ir_align_to(offset, layout.align)
    members.push(StructMember::{
      name: Some(struct_member.name().name()),
      ty,
      binding: wgsl_ir_binding_from_attributes(struct_member.attributes()),
      offset,
    })
    offset = offset + layout.size
    if layout.align > max_align {
      max_align = layout.align
    }
  }
  let span = wgsl_ir_align_to(if offset == 0 { 1 } else { offset }, max_align)
  let handle = self.shader_module.append_type(Type::{
    name: Some(struct_decl.name().name()),
    inner: TypeInner::Struct(members, span),
  })
  self.type_cache.set(struct_decl.name().name(), handle)
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
    Some(expr) => Some(self.lower_global_expression_ref(expr))
    None => None
  }
  let handle = self.shader_module.append_global_variable(GlobalVariable::{
    name: Some(global.name().name()),
    space: wgsl_ir_address_space_from_template_list(global.template_list()),
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
fn WgslIrLowerer::lower_constant(
  self : WgslIrLowerer,
  constant : @ast.WgslConst,
) -> Unit raise WgslIrLowerError {
  guard constant.ty_ref() is Some(ty_ref) else {
    raise WgslIrLowerError::MissingType(constant.name().name())
  }
  let ty = self.lower_type_ref(ty_ref)
  let init = match constant.initializer_ref() {
    Some(expr) => self.lower_global_expression_ref(expr)
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
fn WgslIrLowerer::lower_override(
  self : WgslIrLowerer,
  override_decl : @ast.WgslOverride,
) -> Unit raise WgslIrLowerError {
  guard override_decl.ty_ref() is Some(ty_ref) else {
    raise WgslIrLowerError::MissingType(override_decl.name().name())
  }
  let handle = self.shader_module.append_override(Override::{
    name: Some(override_decl.name().name()),
    id: wgsl_ir_id_from_attributes(override_decl.attributes()),
    ty: self.lower_type_ref(ty_ref),
    init: match override_decl.initializer_ref() {
      Some(expr) => Some(self.lower_global_expression_ref(expr))
      None => None
    },
  })
  self.override_names.set(override_decl.name().name(), handle)
}

///|
fn WgslIrLowerer::lower_function_declaration(
  self : WgslIrLowerer,
  function : @ast.WgslFunction,
) -> Unit raise WgslIrLowerError {
  let ir_function = self.lower_function(function)
  match wgsl_ir_shader_stage_from_attributes(function.attributes()) {
    Some(stage) =>
      self.shader_module.append_entry_point(EntryPoint::{
        name: function.name().name(),
        stage,
        early_depth_test: wgsl_ir_early_depth_test_from_attributes(
          function.attributes(),
        ),
        workgroup_size: wgsl_ir_workgroup_size_from_attributes(
          function.attributes(),
        ),
        workgroup_size_overrides: None,
        function: ir_function,
        mesh_info: None,
        task_payload: None,
        incoming_ray_payload: None,
      })
    None =>
      match self.function_names.get(function.name().name()) {
        Some(handle) => self.shader_module.set_function(handle, ir_function)
        None => {
          let handle = self.shader_module.append_function(ir_function)
          self.function_names.set(function.name().name(), handle)
        }
      }
  }
}

///|
fn WgslIrLowerer::lower_function(
  self : WgslIrLowerer,
  function : @ast.WgslFunction,
) -> Function raise WgslIrLowerError {
  let ir_function = Function::new(Some(function.name().name()))
  let scope = WgslIrFunctionScope::new()
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
fn WgslIrLowerer::lower_block(
  self : WgslIrLowerer,
  block : @ast.WgslBlock,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Block raise WgslIrLowerError {
  let ir_block = Block::new()
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
        self.lower_local_declaration(local_decl, function, scope)
      }
    Return(expr) => {
      let value = match expr {
        Some(expr_ref) =>
          Some(self.lower_function_expression_ref(expr_ref, function, scope))
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
        [] => Block::new()
      }
      let else_block = match statement.blocks() {
        [_, else_child, ..] => self.lower_block(else_child, function, scope)
        _ => Block::new()
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
        [] => Block::new()
      }
      let continuing = Block::new()
      continuing.push(
        Statement::If(cond, Block::new(), Block::{
          statements: [Statement::Break],
        }),
      )
      block.push(Statement::Loop(body, continuing, None))
    }
    Loop => {
      let body = match statement.blocks() {
        [body_block, ..] => self.lower_block(body_block, function, scope)
        [] => Block::new()
      }
      let continuing = match statement.blocks() {
        [_, continuing_block, ..] =>
          self.lower_block(continuing_block, function, scope)
        _ => Block::new()
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
      let target = self.lower_function_lvalue_ref(lhs_ref, function, scope)
      let rhs_value = self.lower_function_expression_ref(
        rhs_ref, function, scope,
      )
      let value = match wgsl_ir_compound_assignment_operator(op) {
        Some(binary_op) => {
          let loaded_target = function.expressions.append(
            Expression::Load(target),
          )
          function.expressions.append(
            Expression::Binary(binary_op, loaded_target, rhs_value),
          )
        }
        None => rhs_value
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
          ignore(self.lower_function_expression_ref(expr_ref, function, scope))
        None => ()
      }
    ConstAssert(_) => ()
    For(_) | Switch(_) | Case(_) | DefaultCase =>
      raise WgslIrLowerError::UnsupportedStatement(
        "structured statement not yet representable by this WGSL IR lowerer",
      )
  }
}

///|
fn WgslIrLowerer::lower_local_declaration(
  self : WgslIrLowerer,
  local_decl : @ast.WgslLocalDeclaration,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Unit raise WgslIrLowerError {
  guard local_decl.ty_ref() is Some(ty_ref) else {
    raise WgslIrLowerError::MissingType(local_decl.name().name())
  }
  let init = match local_decl.initializer_ref() {
    Some(expr_ref) =>
      Some(self.lower_function_expression_ref(expr_ref, function, scope))
    None => None
  }
  let handle = function.local_variables.append(LocalVariable::{
    name: Some(local_decl.name().name()),
    ty: self.lower_type_ref(ty_ref),
    init,
  })
  scope.locals.set(local_decl.name().name(), handle)
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
  match root.kind() {
    Call(callee, arguments) =>
      match callee.kind() {
        Identifier(name) =>
          match self.function_names.get(name.name()) {
            Some(handle) => {
              let values : Array[Handle] = []
              for argument in arguments {
                values.push(
                  self.lower_function_expression_node(argument, function, scope),
                )
              }
              block.push(Statement::Call(handle, values, None))
            }
            None =>
              ignore(self.lower_function_expression_node(root, function, scope))
          }
        _ => ignore(self.lower_function_expression_node(root, function, scope))
      }
    _ => ignore(self.lower_function_expression_node(root, function, scope))
  }
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
  let loaded = function.expressions.append(Expression::Load(pointer))
  let one = function.expressions.append(Expression::Literal(Literal::I32(1)))
  let op = if increment {
    BinaryOperator::Add
  } else {
    BinaryOperator::Subtract
  }
  let value = function.expressions.append(Expression::Binary(op, loaded, one))
  block.push(Statement::Store(pointer, value))
}

///|
fn WgslIrLowerer::lower_global_expression_ref(
  self : WgslIrLowerer,
  expr_ref : @ast.WgslExprRef,
) -> Handle raise WgslIrLowerError {
  guard expr_ref.root() is Some(root) else {
    raise WgslIrLowerError::UnsupportedExpression("empty global expression")
  }
  self.lower_global_expression_node(root)
}

///|
fn WgslIrLowerer::lower_global_expression_node(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
) -> Handle raise WgslIrLowerError {
  self.shader_module.append_global_expression(
    self.lower_expression_node_to_global_expression(node),
  )
}

///|
fn WgslIrLowerer::lower_expression_node_to_global_expression(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
) -> Expression raise WgslIrLowerError {
  match node.kind() {
    Literal(token) => Expression::Literal(wgsl_ir_literal_from_token(token))
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
    Group(expr) => self.lower_expression_node_to_global_expression(expr)
    Sequence([single]) =>
      self.lower_expression_node_to_global_expression(single)
    Call(callee, arguments) =>
      match callee.kind() {
        Identifier(name) =>
          match wgsl_ir_math_function_from_name(name.name()) {
            Some(math_function) =>
              self.lower_global_math_call(math_function, arguments)
            None => {
              let ty = self.lower_type_name_with_expression_arguments(
                name.name(),
                arguments,
              )
              Expression::Compose(
                ty,
                self.lower_global_expression_arguments(arguments),
              )
            }
          }
        _ =>
          raise WgslIrLowerError::UnsupportedExpression(
            "non-identifier global call expression",
          )
      }
    _ =>
      raise WgslIrLowerError::UnsupportedExpression(
        "global expression kind is not constant-lowerable",
      )
  }
}

///|
fn WgslIrLowerer::lower_global_expression_arguments(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
) -> Array[Handle] raise WgslIrLowerError {
  let handles : Array[Handle] = []
  for argument in wgsl_ir_flatten_expression_arguments(arguments) {
    handles.push(self.lower_global_expression_node(argument))
  }
  handles
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
fn WgslIrLowerer::lower_function_expression_ref(
  self : WgslIrLowerer,
  expr_ref : @ast.WgslExprRef,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  guard expr_ref.root() is Some(root) else {
    raise WgslIrLowerError::UnsupportedExpression("empty function expression")
  }
  self.lower_function_expression_node(root, function, scope)
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
      match scope.locals.get(name.name()) {
        Some(handle) =>
          function.expressions.append(Expression::LocalVariable(handle))
        None =>
          match self.global_names.get(name.name()) {
            Some(handle) =>
              function.expressions.append(Expression::GlobalVariable(handle))
            None => raise WgslIrLowerError::UnknownIdentifier(name.name())
          }
      }
    Member(base, member_name) => {
      let base_handle = self.lower_function_lvalue_node(base, function, scope)
      function.expressions.append(
        Expression::AccessIndex(
          base_handle,
          wgsl_ir_member_index(member_name.name()),
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
fn WgslIrLowerer::lower_function_expression_node(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  match node.kind() {
    Literal(token) =>
      function.expressions.append(
        Expression::Literal(wgsl_ir_literal_from_token(token)),
      )
    Identifier(name) =>
      self.lower_identifier_expression(name.name(), function, scope)
    Unary(op, expr) =>
      function.expressions.append(
        Expression::Unary(
          wgsl_ir_unary_operator(op),
          self.lower_function_expression_node(expr, function, scope),
        ),
      )
    Binary(op, left, right) =>
      function.expressions.append(
        Expression::Binary(
          wgsl_ir_binary_operator(op),
          self.lower_function_expression_node(left, function, scope),
          self.lower_function_expression_node(right, function, scope),
        ),
      )
    Group(expr) => self.lower_function_expression_node(expr, function, scope)
    Sequence([single]) =>
      self.lower_function_expression_node(single, function, scope)
    Member(base, member_name) => {
      let base_handle = self.lower_function_expression_node(
        base, function, scope,
      )
      function.expressions.append(
        Expression::AccessIndex(
          base_handle,
          wgsl_ir_member_index(member_name.name()),
        ),
      )
    }
    Index(base, index) => {
      let base_handle = self.lower_function_expression_node(
        base, function, scope,
      )
      let index_handle = self.lower_function_expression_node(
        index, function, scope,
      )
      function.expressions.append(Expression::Access(base_handle, index_handle))
    }
    Call(callee, arguments) =>
      match callee.kind() {
        Identifier(name) =>
          match self.function_names.get(name.name()) {
            Some(handle) =>
              function.expressions.append(
                Expression::FunctionCall(
                  handle,
                  self.lower_function_expression_arguments(
                    arguments, function, scope,
                  ),
                ),
              )
            None =>
              match wgsl_ir_math_function_from_name(name.name()) {
                Some(math_function) =>
                  self.lower_function_math_call(
                    math_function, arguments, function, scope,
                  )
                None => {
                  let ty = self.lower_type_name_with_expression_arguments(
                    name.name(),
                    arguments,
                  )
                  function.expressions.append(
                    Expression::Compose(
                      ty,
                      self.lower_function_expression_arguments(
                        arguments, function, scope,
                      ),
                    ),
                  )
                }
              }
          }
        _ =>
          raise WgslIrLowerError::UnsupportedExpression(
            "non-identifier call expression",
          )
      }
    _ =>
      raise WgslIrLowerError::UnsupportedExpression("unlowered expression node")
  }
}

///|
fn WgslIrLowerer::lower_identifier_expression(
  self : WgslIrLowerer,
  name : String,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  match scope.arguments.get(name) {
    Some(index) =>
      function.expressions.append(Expression::FunctionArgument(index))
    None =>
      match scope.locals.get(name) {
        Some(handle) =>
          function.expressions.append(
            Expression::Load(
              function.expressions.append(Expression::LocalVariable(handle)),
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
                      function.expressions.append(
                        Expression::Load(
                          function.expressions.append(
                            Expression::GlobalVariable(handle),
                          ),
                        ),
                      )
                    None => raise WgslIrLowerError::UnknownIdentifier(name)
                  }
              }
          }
      }
  }
}

///|
fn WgslIrLowerer::lower_function_expression_arguments(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Array[Handle] raise WgslIrLowerError {
  let handles : Array[Handle] = []
  for argument in wgsl_ir_flatten_expression_arguments(arguments) {
    handles.push(self.lower_function_expression_node(argument, function, scope))
  }
  handles
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
        [Expression(expr), ..] =>
          match wgsl_ir_int_literal_from_expr_ref(expr) {
            Some(value) => ArraySize::Constant(value)
            None => ArraySize::Dynamic
          }
        _ => ArraySize::Dynamic
      }
      let stride = self.type_layout(element).size
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
        [Expression(expr), ..] =>
          match wgsl_ir_int_literal_from_expr_ref(expr) {
            Some(value) => ArraySize::Constant(value)
            None => ArraySize::Dynamic
          }
        _ => ArraySize::Dynamic
      }
      self.intern_type(
        ty_ref.canonical_text(),
        TypeInner::BindingArray(self.lower_type_ref(element_ty), size),
      )
    }
    _ => raise WgslIrLowerError::UnsupportedType(ty_ref.canonical_text())
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
    "bool" => Scalar::new(Bool, 1)
    "i32" => Scalar::new(Sint, 4)
    "u32" => Scalar::new(Uint, 4)
    "f32" => Scalar::new(Float, 4)
    "f16" => Scalar::new(Float, 2)
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
priv struct WgslIrLayout {
  align : Int
  size : Int
}

///|
fn WgslIrLowerer::type_layout(
  self : WgslIrLowerer,
  handle : Handle,
) -> WgslIrLayout {
  match self.shader_module.types.get(handle) {
    Some(ty) =>
      match ty.inner {
        Scalar(scalar) =>
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
        Array(_, _, stride) => WgslIrLayout::{ align: 16, size: stride }
        Struct(_, span) => WgslIrLayout::{ align: 16, size: span }
        _ => WgslIrLayout::{ align: 4, size: 4 }
      }
    None => WgslIrLayout::{ align: 4, size: 4 }
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
    "bool" => Some(TypeInner::Scalar(Scalar::new(Bool, 1)))
    "i32" => Some(TypeInner::Scalar(Scalar::new(Sint, 4)))
    "u32" => Some(TypeInner::Scalar(Scalar::new(Uint, 4)))
    "f32" => Some(TypeInner::Scalar(Scalar::new(Float, 4)))
    "f16" => Some(TypeInner::Scalar(Scalar::new(Float, 2)))
    _ => None
  }
}

///|
fn wgsl_ir_builtin_vector_alias(name : String) -> TypeInner? {
  match name {
    "vec2f" => Some(TypeInner::Vector(Bi, Scalar::new(Float, 4)))
    "vec3f" => Some(TypeInner::Vector(Tri, Scalar::new(Float, 4)))
    "vec4f" => Some(TypeInner::Vector(Quad, Scalar::new(Float, 4)))
    "vec2h" => Some(TypeInner::Vector(Bi, Scalar::new(Float, 2)))
    "vec3h" => Some(TypeInner::Vector(Tri, Scalar::new(Float, 2)))
    "vec4h" => Some(TypeInner::Vector(Quad, Scalar::new(Float, 2)))
    "vec2i" => Some(TypeInner::Vector(Bi, Scalar::new(Sint, 4)))
    "vec3i" => Some(TypeInner::Vector(Tri, Scalar::new(Sint, 4)))
    "vec4i" => Some(TypeInner::Vector(Quad, Scalar::new(Sint, 4)))
    "vec2u" => Some(TypeInner::Vector(Bi, Scalar::new(Uint, 4)))
    "vec3u" => Some(TypeInner::Vector(Tri, Scalar::new(Uint, 4)))
    "vec4u" => Some(TypeInner::Vector(Quad, Scalar::new(Uint, 4)))
    _ => None
  }
}

///|
fn wgsl_ir_builtin_matrix_alias(name : String) -> TypeInner? {
  match name {
    "mat2x2f" => Some(TypeInner::Matrix(Bi, Bi, Scalar::new(Float, 4)))
    "mat2x3f" => Some(TypeInner::Matrix(Bi, Tri, Scalar::new(Float, 4)))
    "mat2x4f" => Some(TypeInner::Matrix(Bi, Quad, Scalar::new(Float, 4)))
    "mat3x2f" => Some(TypeInner::Matrix(Tri, Bi, Scalar::new(Float, 4)))
    "mat3x3f" => Some(TypeInner::Matrix(Tri, Tri, Scalar::new(Float, 4)))
    "mat3x4f" => Some(TypeInner::Matrix(Tri, Quad, Scalar::new(Float, 4)))
    "mat4x2f" => Some(TypeInner::Matrix(Quad, Bi, Scalar::new(Float, 4)))
    "mat4x3f" => Some(TypeInner::Matrix(Quad, Tri, Scalar::new(Float, 4)))
    "mat4x4f" => Some(TypeInner::Matrix(Quad, Quad, Scalar::new(Float, 4)))
    "mat2x2h" => Some(TypeInner::Matrix(Bi, Bi, Scalar::new(Float, 2)))
    "mat2x3h" => Some(TypeInner::Matrix(Bi, Tri, Scalar::new(Float, 2)))
    "mat2x4h" => Some(TypeInner::Matrix(Bi, Quad, Scalar::new(Float, 2)))
    "mat3x2h" => Some(TypeInner::Matrix(Tri, Bi, Scalar::new(Float, 2)))
    "mat3x3h" => Some(TypeInner::Matrix(Tri, Tri, Scalar::new(Float, 2)))
    "mat3x4h" => Some(TypeInner::Matrix(Tri, Quad, Scalar::new(Float, 2)))
    "mat4x2h" => Some(TypeInner::Matrix(Quad, Bi, Scalar::new(Float, 2)))
    "mat4x3h" => Some(TypeInner::Matrix(Quad, Tri, Scalar::new(Float, 2)))
    "mat4x4h" => Some(TypeInner::Matrix(Quad, Quad, Scalar::new(Float, 2)))
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
    "sin" => Some(Sin)
    "tan" => Some(Tan)
    "acos" => Some(Acos)
    "asin" => Some(Asin)
    "atan" => Some(Atan)
    "atan2" => Some(Atan2)
    "ceil" => Some(Ceil)
    "floor" => Some(Floor)
    "round" => Some(Round)
    "fract" => Some(Fract)
    "trunc" => Some(Trunc)
    "exp" => Some(Exp)
    "exp2" => Some(Exp2)
    "log" => Some(Log)
    "log2" => Some(Log2)
    "pow" => Some(Pow)
    "dot" => Some(Dot)
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
    "transpose" => Some(Transpose)
    "determinant" => Some(Determinant)
    "countTrailingZeros" => Some(CountTrailingZeros)
    "countLeadingZeros" => Some(CountLeadingZeros)
    "countOneBits" => Some(CountOneBits)
    "reverseBits" => Some(ReverseBits)
    "extractBits" => Some(ExtractBits)
    "insertBits" => Some(InsertBits)
    "firstTrailingBit" => Some(FirstTrailingBit)
    "firstLeadingBit" => Some(FirstLeadingBit)
    _ => None
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
fn wgsl_ir_literal_from_token(
  token : @ast.WgslExprToken,
) -> Literal raise WgslIrLowerError {
  match token.kind() {
    BoolLiteral(value) => Literal::Bool(value)
    IntLiteral(value) => Literal::I32(value)
    UintLiteral(value) => {
      let parsed : UInt = @strconv.from_str("\{value}") catch {
        _ => raise WgslIrLowerError::UnsupportedExpression(token.text())
      }
      Literal::U32(parsed)
    }
    FloatLiteral => {
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
                  None,
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
fn wgsl_ir_builtin_from_name(name : String) -> BuiltIn raise WgslIrLowerError {
  match name {
    "position" => BuiltIn::Position(false)
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
            [] =>
              AddressSpace::Storage(
                StorageAccess::load().union(StorageAccess::store()),
              )
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
    "storage" =>
      AddressSpace::Storage(StorageAccess::load().union(StorageAccess::store()))
    "handle" => AddressSpace::Handle
    "immediate" => AddressSpace::Immediate
    _ => AddressSpace::Private
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
fn wgsl_ir_workgroup_size_from_attributes(
  attributes : Array[@ast.WgslAttribute],
) -> Array[Int] {
  match wgsl_ir_attribute_named(attributes, "workgroup_size") {
    Some(attribute) =>
      match attribute.arguments_ref() {
        Some(expr_ref) => {
          let values : Array[Int] = []
          for token in expr_ref.tokens() {
            match token.kind() {
              IntLiteral(value) | UintLiteral(value) => values.push(value)
              _ => ()
            }
          }
          match values {
            [] => [1, 1, 1]
            [x] => [x, 1, 1]
            [x, y] => [x, y, 1]
            [x, y, z, ..] => [x, y, z]
          }
        }
        None => [1, 1, 1]
      }
    None => [1, 1, 1]
  }
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
