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
}

///|
priv struct WgslIrExprTokenParser {
  tokens : Array[@ast.WgslExprToken]
  mut index : Int
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
    referenced_names: @hashset.HashSet::new(),
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
    lowerer.record_referenced_names(declaration)
  }
  for declaration in unit.declarations() {
    lowerer.predeclare_global_declaration(declaration)
  }
  for declaration in unit.declarations() {
    lowerer.lower_global_declaration(declaration)
  }
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
  ignore(self.intern_type("bool", TypeInner::Scalar(Scalar::new(Bool, 1))))
  ignore(self.intern_type("i32", TypeInner::Scalar(Scalar::new(Sint, 4))))
  ignore(self.intern_type("u32", TypeInner::Scalar(Scalar::new(Uint, 4))))
  ignore(self.intern_type("f32", TypeInner::Scalar(Scalar::new(Float, 4))))
  ignore(self.intern_type("f16", TypeInner::Scalar(Scalar::new(Float, 2))))
  ignore(
    self.intern_type(
      "__abstract_int",
      TypeInner::Scalar(Scalar::new(AbstractInt, 8)),
    ),
  )
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
    Function(function) => {
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
  let ty = match constant.ty_ref() {
    Some(ty_ref) => self.lower_type_ref(ty_ref)
    None =>
      self.infer_local_type_from_initializer(
        constant.name().name(),
        constant.initializer_ref(),
      )
  }
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
  let ty = match override_decl.ty_ref() {
    Some(ty_ref) => self.lower_type_ref(ty_ref)
    None =>
      self.infer_local_type_from_initializer(
        override_decl.name().name(),
        override_decl.initializer_ref(),
      )
  }
  let handle = self.shader_module.append_override(Override::{
    name: Some(override_decl.name().name()),
    id: wgsl_ir_id_from_attributes(override_decl.attributes()),
    ty,
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
        self.lower_local_declaration(local_decl, function, scope, block)
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
      if wgsl_ir_expr_ref_is_phony(lhs_ref) {
        let rhs_value = self.lower_function_expression_ref(
          rhs_ref, function, scope,
        )
        block.push(Statement::Emit(HandleRange::new(rhs_value, rhs_value)))
        return
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
        Some(expr_ref) => {
          let handle = self.lower_function_expression_ref(
            expr_ref, function, scope,
          )
          block.push(Statement::Emit(HandleRange::new(handle, handle)))
        }
        None => ()
      }
    ConstAssert(_) => ()
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
  let loop_body = Block::new()
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
          Block::new(),
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
  let continuing = Block::new()
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
          [] => Block::new()
        }
        for selector in selectors {
          let selector_handle = self.lower_function_expression_ref(
            selector, function, scope,
          )
          cases.push(SwitchCase::{
            value: wgsl_ir_switch_value_from_expression(
              function, selector_handle,
            ),
            body,
            fall_through: false,
          })
        }
      }
      DefaultCase => {
        let body = match statement.blocks() {
          [case_block, ..] => self.lower_block(case_block, function, scope)
          [] => Block::new()
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
  function : Function,
  handle : Handle,
) -> SwitchValue raise WgslIrLowerError {
  match function.expressions.items.get(handle.index()) {
    Some(Expression::Literal(Literal::I32(value))) => SwitchValue::I32(value)
    Some(Expression::Literal(Literal::U32(value))) => SwitchValue::U32(value)
    _ =>
      raise WgslIrLowerError::UnsupportedExpression(
        "switch case selector must lower to an integer literal",
      )
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
      wgsl_ir_lower_update_handle(target, function, block, increment)
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
        block.push(Statement::Emit(HandleRange::new(rhs_value, rhs_value)))
        return
      }
      let target = self.lower_function_lvalue_node(
        wgsl_ir_expr_node_from_tokens(lhs_tokens),
        function,
        scope,
      )
      let rhs_value = self.lower_function_expression_node(
        wgsl_ir_expr_node_from_tokens(rhs_tokens),
        function,
        scope,
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
  let init = match local_decl.initializer_ref() {
    Some(expr_ref) =>
      Some(self.lower_function_expression_ref(expr_ref, function, scope))
    None => None
  }
  let ty = match local_decl.ty_ref() {
    Some(ty_ref) => self.lower_type_ref(ty_ref)
    None =>
      match init {
        Some(init_handle) =>
          match self.function_expression_type(function, init_handle) {
            Some(inferred) => inferred
            None =>
              self.infer_local_type_from_initializer(
                local_decl.name().name(),
                local_decl.initializer_ref(),
              )
          }
        None =>
          self.infer_local_type_from_initializer(
            local_decl.name().name(),
            local_decl.initializer_ref(),
          )
      }
  }
  let handle = function.local_variables.append(LocalVariable::{
    name: Some(local_decl.name().name()),
    kind: wgsl_ir_local_variable_kind(local_decl.kind()),
    ty,
    init,
  })
  scope.locals.set(local_decl.name().name(), handle)
  block.push(Statement::Declare(handle))
}

///|
fn wgsl_ir_local_variable_kind(
  kind : @ast.WgslLocalDeclarationKind,
) -> LocalVariableKind {
  match kind {
    Var => LocalVariableKind::Var
    Let => LocalVariableKind::Let
    Const => LocalVariableKind::Const
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
  match root.kind() {
    Call(callee, arguments) =>
      match callee.kind() {
        Identifier(name) =>
          match wgsl_ir_atomic_function_from_name(name.name()) {
            Some(atomic_function) => {
              let handle = self.lower_function_atomic_call(
                atomic_function, arguments, function, scope,
              )
              block.push(Statement::Emit(HandleRange::new(handle, handle)))
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
                  if !self.lower_texture_statement_call(
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
  wgsl_ir_lower_update_handle(pointer, function, block, increment)
}

///|
fn wgsl_ir_lower_update_handle(
  pointer : Handle,
  function : Function,
  block : Block,
  increment : Bool,
) -> Unit {
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
        FloatLiteral => self.lower_builtin_type_name("f32")
        _ => raise WgslIrLowerError::MissingType(name)
      }
    Identifier(identifier) =>
      self.infer_named_expression_type(identifier.name(), name)
    Group(inner) => self.infer_expression_type(inner, name)
    Binary(_, left, _) => self.infer_expression_type(left, name)
    Call(callee, arguments) =>
      match self.lower_templated_callee_type(callee) {
        Some(ty) => ty
        None =>
          match callee.kind() {
            Identifier(ident) =>
              self.lower_untemplated_constructor_type_from_ast(
                ident.name(),
                arguments,
                name,
              )
            _ => raise WgslIrLowerError::MissingType(name)
          }
      }
    _ => raise WgslIrLowerError::MissingType(name)
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
fn WgslIrExprTokenDepth::new() -> WgslIrExprTokenDepth {
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
  let depth = WgslIrExprTokenDepth::new()
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
  @ast.WgslExprNode::new(kind, start, end_)
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
                @ast.WgslIdent::new(token.text(), token.start(), token.end()),
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
                @ast.WgslIdent::new(
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
              let ty = self.lower_untemplated_constructor_type_from_ast(
                name.name(),
                arguments,
                name.name(),
              )
              Expression::Compose(
                ty,
                self.lower_global_expression_arguments(arguments),
              )
            }
          }
        _ =>
          match self.lower_templated_callee_type(callee) {
            Some(ty) =>
              Expression::Compose(
                ty,
                self.lower_global_expression_arguments(arguments),
              )
            None =>
              raise WgslIrLowerError::UnsupportedExpression(
                "non-identifier global call expression",
              )
          }
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
      if op == @ast.WgslExprOperator::BitAnd {
        self.lower_function_lvalue_node(expr, function, scope)
      } else {
        function.expressions.append(
          Expression::Unary(
            wgsl_ir_unary_operator(op),
            self.lower_function_expression_node(expr, function, scope),
          ),
        )
      }
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
      self.lower_member_expression(function, base_handle, member_name.name())
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
                None =>
                  match wgsl_ir_atomic_function_from_name(name.name()) {
                    Some(atomic_function) =>
                      self.lower_function_atomic_call(
                        atomic_function, arguments, function, scope,
                      )
                    None =>
                      match
                        self.lower_texture_expression_call(
                          name.name(),
                          arguments,
                          function,
                          scope,
                        ) {
                        Some(handle) => handle
                        None => {
                          let lowered_arguments = self.lower_function_expression_arguments(
                            arguments, function, scope,
                          )
                          let ty = self.lower_untemplated_constructor_type_from_handles(
                            name.name(),
                            arguments,
                            lowered_arguments,
                            function,
                          )
                          function.expressions.append(
                            Expression::Compose(ty, lowered_arguments),
                          )
                        }
                      }
                  }
              }
          }
        _ =>
          match self.lower_templated_callee_type(callee) {
            Some(ty) =>
              function.expressions.append(
                Expression::Compose(
                  ty,
                  self.lower_function_expression_arguments(
                    arguments, function, scope,
                  ),
                ),
              )
            None =>
              raise WgslIrLowerError::UnsupportedExpression(
                "non-identifier call expression",
              )
          }
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
  for argument in arguments {
    handles.push(self.lower_function_expression_node(argument, function, scope))
  }
  function.expressions.append(Expression::AtomicCall(atomic_function, handles))
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
fn WgslIrLowerer::lower_templated_callee_type(
  self : WgslIrLowerer,
  callee : @ast.WgslExprNode,
) -> Handle? raise WgslIrLowerError {
  match callee.kind() {
    Template(base, template_arguments) =>
      match base.kind() {
        Identifier(name) => {
          let atom = @ast.WgslTypeAtom::new(
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
fn WgslIrLowerer::constructor_scalar_from_ast_arguments(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  diagnostic_name : String,
) -> Scalar raise WgslIrLowerError {
  guard wgsl_ir_flatten_expression_arguments(arguments) is [first, ..] else {
    raise WgslIrLowerError::MissingType(diagnostic_name)
  }
  let ty = self.infer_expression_type(first, diagnostic_name)
  wgsl_ir_concrete_constructor_scalar(
    self.scalar_from_type_handle(ty, diagnostic_name),
  )
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
  wgsl_ir_concrete_constructor_scalar(
    self.scalar_from_type_handle(ty, diagnostic_name),
  )
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
fn wgsl_ir_concrete_constructor_scalar(scalar : Scalar) -> Scalar {
  match scalar.kind {
    AbstractInt => Scalar::new(Sint, 4)
    AbstractFloat => Scalar::new(Float, 4)
    _ => scalar
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
    "modf" => Some(Modf)
    "frexp" => Some(Frexp)
    "ldexp" => Some(Ldexp)
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
    "inverse" => Some(Inverse)
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
fn wgsl_ir_literal_from_token(
  token : @ast.WgslExprToken,
) -> Literal raise WgslIrLowerError {
  match token.kind() {
    BoolLiteral(value) => Literal::Bool(value)
    IntLiteral(value) =>
      if wgsl_ir_literal_has_suffix(token.text(), "i") {
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
      match self.shader_module.types.get(ty_handle) {
        Some(ty) =>
          match ty.inner {
            Struct(members, _) =>
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
    Compose(ty, _) | ZeroValue(ty) => Some(ty)
    AccessIndex(base, index) =>
      self.indexed_expression_type(function, base, Some(index))
    Access(base, _) => self.indexed_expression_type(function, base, None)
    Swizzle(size, base, _) => self.swizzle_expression_type(function, base, size)
    Unary(_, inner) => self.function_expression_type(function, inner)
    Binary(_, left, _) => self.function_expression_type(function, left)
    FunctionCall(handle, _) =>
      match self.shader_module.functions.items.get(handle.index()) {
        Some(callee) =>
          match callee.result {
            Some(result) => Some(result.ty)
            None => None
          }
        None => None
      }
    Math(math_function, a, _, _, _) =>
      self.math_expression_result_type(function, math_function, a)
    AtomicCall(atomic_function, arguments) =>
      self.atomic_expression_result_type(function, atomic_function, arguments)
    ImageSample(image, _, gather, _, _, _, _, depth_ref, _) =>
      self.image_expression_result_type(function, image, gather, depth_ref)
    ImageLoad(image, _, _, _, _) =>
      self.image_expression_result_type(function, image, None, None)
    ImageQuery(_, _) => self.type_cache.get("u32")
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
    _ => Some(input_ty)
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
      let bool_ty = self.scalar_type_handle(Scalar::new(Bool, 1))
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
            offset: scalar.width,
          },
        ],
        scalar.width + 1,
      )
    }
    ModfResult(size, scalar) => {
      let value_ty = self.numeric_value_type_handle(size, scalar)
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
            offset: self.type_layout(value_ty).size,
          },
        ],
        self.type_layout(value_ty).size * 2,
      )
    }
    FrexpResult(size, scalar) => {
      let fract_ty = self.numeric_value_type_handle(size, scalar)
      let exponent_scalar = Scalar::new(Sint, 4)
      let exponent_ty = self.numeric_value_type_handle(size, exponent_scalar)
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
            offset: self.type_layout(fract_ty).size,
          },
        ],
        self.type_layout(fract_ty).size + self.type_layout(exponent_ty).size,
      )
    }
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
              TypeInner::Vector(Quad, Scalar::new(kind, 4)),
            ),
          )
        Image(_, _, Depth(_)) =>
          if gather != None {
            Some(
              self.intern_type(
                "vec4<f32>",
                TypeInner::Vector(Quad, Scalar::new(Float, 4)),
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
              TypeInner::Vector(Quad, Scalar::new(kind, 4)),
            ),
          )
        }
        _ => None
      }
    None => None
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
  match self.shader_module.types.get(base_ty) {
    Some(ty) =>
      match ty.inner {
        Struct(members, _) =>
          match index {
            Some(i) =>
              match members.get(i) {
                Some(struct_member) => Some(struct_member.ty)
                None => None
              }
            None => None
          }
        Vector(_, scalar) => Some(self.scalar_type_handle(scalar))
        Array(element, _, _) | BindingArray(element, _) => Some(element)
        Pointer(inner, _) => Some(inner)
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
    F32(_) | AbstractFloat(_) => self.type_cache.get("f32")
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
    AbstractInt => "i32"
    AbstractFloat => "f32"
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
    AbstractInt => "i32"
    AbstractFloat => "f32"
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
