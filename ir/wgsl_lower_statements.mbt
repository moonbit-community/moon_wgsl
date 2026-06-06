///|
fn wgsl_ir_block_ends_with_return(block : Block) -> Bool {
  match block.statements {
    [.., Return(_)] | [.., ImplicitReturn] => true
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
  let statements = block.statements()
  for index in 0..<statements.length() {
    self.lower_statement_with_block_context(
      statements[index],
      statements,
      index,
      function,
      scope,
      ir_block,
    )
  }
  ir_block
}

///|
fn WgslIrLowerer::predeclare_function_source_local_prefix(
  self : WgslIrLowerer,
  block : @ast.WgslBlock,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Unit raise WgslIrLowerError {
  self.predeclare_function_source_var_const_initializers(block, function, scope)
}

///|
fn WgslIrLowerer::predeclare_function_source_var_const_initializers(
  self : WgslIrLowerer,
  block : @ast.WgslBlock,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Unit raise WgslIrLowerError {
  for statement in block.statements() {
    for local_decl in statement.local_bindings() {
      self.predeclare_source_var_const_initializer_expression(
        local_decl, function, scope,
      )
    }
    guard wgsl_ir_statement_allows_function_entry_const_initializer_predeclare(
      statement,
    ) else {
      continue
    }
    for child in statement.blocks() {
      self.predeclare_function_source_var_const_initializers(
        child, function, scope,
      )
    }
  }
}

///|
fn wgsl_ir_statement_allows_function_entry_const_initializer_predeclare(
  statement : @ast.WgslStatement,
) -> Bool {
  match statement.kind() {
    For | While | Loop | Continuing => false
    _ => true
  }
}

///|
fn WgslIrLowerer::predeclare_source_var_const_initializer_expression(
  self : WgslIrLowerer,
  local_decl : @ast.WgslLocalDeclaration,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Unit raise WgslIrLowerError {
  guard local_decl.kind() == Var else { return }
  guard local_decl.initializer_ref() is Some(expr_ref) else { return }
  let initializer_is_const = match expr_ref.root() {
    Some(root) => self.expression_node_is_const_initializer(root)
    None => false
  }
  guard initializer_is_const else { return }
  let explicit_ty = match local_decl.ty_ref() {
    Some(ty_ref) => Some(self.lower_function_type_ref(ty_ref, function, scope))
    None => None
  }
  let expected_ty = self.source_local_const_initializer_expected_type(
    local_decl, explicit_ty,
  )
  ignore(
    self.lower_source_local_const_initializer(
      expr_ref, expected_ty, function, scope,
    ),
  )
}

///|
fn WgslIrLowerer::source_local_const_initializer_expected_type(
  self : WgslIrLowerer,
  local_decl : @ast.WgslLocalDeclaration,
  explicit_ty : Handle?,
) -> Handle? raise WgslIrLowerError {
  match explicit_ty {
    Some(ty) => Some(ty)
    None =>
      Some(
        self.infer_local_type_from_initializer(
          local_decl.name().name(),
          local_decl.initializer_ref(),
        ),
      )
  }
}

///|
fn WgslIrLowerer::predeclare_source_local_placeholder(
  self : WgslIrLowerer,
  local_decl : @ast.WgslLocalDeclaration,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Unit raise WgslIrLowerError {
  guard local_decl.kind() == Var else { return }
  let key = wgsl_ir_local_declaration_key(local_decl)
  if scope.predeclared_source_locals.contains(key) {
    return
  }
  let explicit_ty = match local_decl.ty_ref() {
    Some(ty_ref) => Some(self.lower_function_type_ref(ty_ref, function, scope))
    None => None
  }
  let ty = match explicit_ty {
    Some(ty) => ty
    None =>
      match local_decl.initializer_ref() {
        None =>
          self.infer_local_type_from_initializer(
            local_decl.name().name(),
            local_decl.initializer_ref(),
          )
        Some(_) => self.lower_builtin_type_name("i32")
      }
  }
  let ty = self.local_declaration_storage_type(local_decl.kind(), ty)
  let handle = function.local_variables.append({
    name: Some(
      self.naga_oil_generated_import_local_spelling_for_scope(
        local_decl.name().name(),
        scope,
      ),
    ),
    kind: Var,
    generated_temporary: false,
    generated_temporary_store_value_reference: false,
    short_circuit_result: false,
    ty,
    init: None,
  })
  scope.predeclared_source_locals.set(key, handle)
}

///|
fn WgslIrLowerer::lower_source_local_const_initializer(
  self : WgslIrLowerer,
  expr_ref : @ast.WgslExprRef,
  explicit_ty : Handle?,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  let semantic_key = self.source_local_const_initializer_semantic_key(
    expr_ref, explicit_ty,
  )
  match semantic_key {
    Some(key) =>
      match scope.source_local_const_initializer_expressions.get(key) {
        Some(handle) => return handle
        None => ()
      }
    None => ()
  }
  match expr_ref.root() {
    Some(root) =>
      match wgsl_ir_expr_node_literal_token(root) {
        Some(token) =>
          match
            scope.source_local_const_initializer_expressions.get(
              wgsl_ir_source_local_const_literal_key(token, explicit_ty),
            ) {
            Some(handle) => return handle
            None => ()
          }
        None => ()
      }
    None => ()
  }
  let key = match semantic_key {
    Some(value) => value
    None => wgsl_ir_source_local_const_initializer_key(expr_ref, explicit_ty)
  }
  match scope.source_local_const_initializer_expressions.get(key) {
    Some(handle) => handle
    None => {
      let expression_mark = function.expressions.items.length()
      let handle = match
        self.lower_reused_literal_source_local_const_constructor_initializer(
          expr_ref, explicit_ty, function, scope,
        ) {
        Some(handle) => handle
        None =>
          self.lower_function_expression_ref_with_expected(
            expr_ref, function, scope, explicit_ty,
          )
      }
      scope.source_local_const_initializer_expressions.set(key, handle)
      self.record_source_local_const_initializer_literals(
        expr_ref, expression_mark, function, scope, explicit_ty,
      )
      handle
    }
  }
}

///|
fn WgslIrLowerer::lower_reused_literal_source_local_const_constructor_initializer(
  self : WgslIrLowerer,
  expr_ref : @ast.WgslExprRef,
  explicit_ty : Handle?,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle? raise WgslIrLowerError {
  guard explicit_ty is Some(ty) else { return None }
  guard expr_ref.root() is Some(root) else { return None }
  guard root.kind() is Call(callee, arguments) else { return None }
  guard self.expression_callee_is_const_constructor(callee) else { return None }
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard !arguments.is_empty() else { return None }
  if self.source_local_const_constructor_initializer_is_vector_splat(
      ty,
      arguments.length(),
    ) {
    guard arguments is [argument] else { return None }
    guard argument.kind() is Literal(token) else { return None }
    guard self.source_local_const_constructor_initializer_vector_splat_size(
        ty,
        arguments.length(),
      )
      is Some(size) else {
      return None
    }
    guard self.constructor_component_expected_type(ty) is Some(component_ty) else {
      return None
    }
    guard self.source_local_const_literal_semantic_key(
        token,
        Some(component_ty),
      )
      is Some(semantic_key) else {
      return None
    }
    match scope.source_local_const_initializer_expressions.get(semantic_key) {
      Some(handle) =>
        return Some(function.expressions.append(Splat(size, handle)))
      None => ()
    }
    match
      scope.runtime_source_local_const_initializer_expressions.get(semantic_key) {
      Some(handle) =>
        return Some(function.expressions.append(Splat(size, handle)))
      None => ()
    }
    return None
  }
  let literal_handles : Map[String, Handle] = Map([])
  self.lower_reused_literal_source_local_const_constructor_node(
    root, ty, literal_handles, function,
  )
}

///|
fn WgslIrLowerer::lower_reused_literal_source_local_const_constructor_node(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  expected_ty : Handle,
  literal_handles : Map[String, Handle],
  function : Function,
) -> Handle? raise WgslIrLowerError {
  match node.kind() {
    Literal(token) =>
      Some(
        self.reused_source_local_const_constructor_literal_handle(
          token,
          Some(expected_ty),
          literal_handles,
          function,
        ),
      )
    Call(callee, arguments) => {
      guard self.expression_callee_is_const_constructor(callee) else {
        return None
      }
      let arguments = wgsl_ir_flatten_expression_arguments(arguments)
      guard !arguments.is_empty() else { return None }
      let components : Array[Handle] = []
      for index, argument in arguments {
        let argument_ty = match
          self.constructor_literal_argument_expected_type(
            expected_ty,
            index,
            arguments.length(),
          ) {
          Some(value) => value
          None => expected_ty
        }
        match
          self.lower_reused_literal_source_local_const_constructor_node(
            argument, argument_ty, literal_handles, function,
          ) {
          Some(handle) => components.push(handle)
          None => return None
        }
      }
      match
        self.source_local_const_constructor_initializer_vector_splat_size(
          expected_ty,
          arguments.length(),
        ) {
        Some(size) =>
          Some(function.expressions.append(Splat(size, components[0])))
        None =>
          Some(function.expressions.append(Compose(expected_ty, components)))
      }
    }
    Group(inner) =>
      self.lower_reused_literal_source_local_const_constructor_node(
        inner, expected_ty, literal_handles, function,
      )
    Sequence([single]) =>
      self.lower_reused_literal_source_local_const_constructor_node(
        single, expected_ty, literal_handles, function,
      )
    _ => None
  }
}

///|
fn WgslIrLowerer::reused_source_local_const_constructor_literal_handle(
  self : WgslIrLowerer,
  token : @ast.WgslExprToken,
  expected_ty : Handle?,
  literal_handles : Map[String, Handle],
  function : Function,
) -> Handle raise WgslIrLowerError {
  let literal_ty = match expected_ty {
    Some(ty) =>
      match self.constructor_component_expected_type(ty) {
        Some(component_ty) => Some(component_ty)
        None => Some(ty)
      }
    None => None
  }
  let literal = self.literal_from_token_with_expected(token, literal_ty)
  let semantic_key = wgsl_ir_source_local_const_literal_value_key(
    literal_ty, literal,
  )
  match literal_handles.get(semantic_key) {
    Some(existing) => existing
    None => {
      let appended = function.expressions.append(Literal(literal))
      literal_handles.set(semantic_key, appended)
      appended
    }
  }
}

///|
fn WgslIrLowerer::source_local_const_constructor_initializer_is_vector_splat(
  self : WgslIrLowerer,
  ty_handle : Handle,
  argument_count : Int,
) -> Bool {
  guard argument_count == 1 else { return false }
  match self.shader_module.types.get(ty_handle) {
    Some({ inner: Vector(_, _), .. }) => true
    _ => false
  }
}

///|
fn WgslIrLowerer::source_local_const_constructor_initializer_vector_splat_size(
  self : WgslIrLowerer,
  ty_handle : Handle,
  argument_count : Int,
) -> VectorSize? {
  guard argument_count == 1 else { return None }
  match self.shader_module.types.get(ty_handle) {
    Some({ inner: Vector(size, _), .. }) => Some(size)
    _ => None
  }
}

///|
fn WgslIrLowerer::constructor_literal_argument_expected_type(
  self : WgslIrLowerer,
  ty_handle : Handle,
  argument_index : Int,
  argument_count : Int,
) -> Handle? {
  match self.shader_module.types.get(ty_handle) {
    Some(ty) =>
      match ty.inner {
        Vector(size, scalar) =>
          if argument_count == size.width() {
            Some(self.scalar_type_handle(scalar))
          } else {
            None
          }
        Struct(members, _) | PredeclaredStruct(members, _) =>
          match members.get(argument_index) {
            Some(struct_member) => Some(struct_member.ty)
            None => None
          }
        _ => None
      }
    None => None
  }
}

///|
fn wgsl_ir_expr_node_literal_token(
  node : @ast.WgslExprNode,
) -> @ast.WgslExprToken? {
  match node.kind() {
    Literal(token) => Some(token)
    Group(inner) => wgsl_ir_expr_node_literal_token(inner)
    Sequence([single]) => wgsl_ir_expr_node_literal_token(single)
    _ => None
  }
}

///|
fn WgslIrLowerer::record_source_local_const_initializer_literals(
  self : WgslIrLowerer,
  expr_ref : @ast.WgslExprRef,
  expression_mark : Int,
  function : Function,
  scope : WgslIrFunctionScope,
  explicit_ty : Handle?,
) -> Unit raise WgslIrLowerError {
  let literal_tokens : Array[@ast.WgslExprToken] = []
  match expr_ref.root() {
    Some(root) => wgsl_ir_collect_expr_node_literal_tokens(root, literal_tokens)
    None => ()
  }
  guard !literal_tokens.is_empty() else { return }
  let mut token_index = 0
  let expression_end = function.expressions.items.length()
  for expression_index in expression_mark..<expression_end {
    guard token_index < literal_tokens.length() else { break }
    match function.expressions.items.get(expression_index) {
      Some(Literal(_)) => {
        let literal_handle = Handle::Handle(expression_index)
        let literal_ty = match
          self.function_expression_type(function, literal_handle) {
          Some(ty) => Some(ty)
          None => explicit_ty
        }
        self.record_source_local_const_literal_handle(
          scope,
          literal_tokens[token_index],
          literal_ty,
          literal_handle,
        )
        match
          self.source_local_const_literal_initializer_context_type(
            function, literal_handle, expression_end, explicit_ty,
          ) {
          Some(context_ty) =>
            self.record_source_local_const_literal_handle(
              scope,
              literal_tokens[token_index],
              Some(context_ty),
              literal_handle,
            )
          None => ()
        }
        token_index = token_index + 1
      }
      _ => ()
    }
  }
}

///|
fn WgslIrLowerer::source_local_const_literal_initializer_context_type(
  self : WgslIrLowerer,
  function : Function,
  literal : Handle,
  expression_end : Int,
  explicit_ty : Handle?,
) -> Handle? {
  match self.source_local_const_literal_context_type(explicit_ty) {
    Some(ty) => return Some(ty)
    None => ()
  }
  let start = literal.index() + 1
  for expression_index in start..<expression_end {
    match function.expressions.items.get(expression_index) {
      Some(Splat(_, inner)) if inner == literal =>
        match
          self.function_expression_type(function, Handle(expression_index)) {
          Some(ty) =>
            match self.source_local_const_literal_context_type(Some(ty)) {
              Some(context_ty) => return Some(context_ty)
              None => ()
            }
          None => ()
        }
      Some(Compose(ty, components)) =>
        if wgsl_ir_source_local_const_initializer_components_contain(
            components, literal,
          ) {
          match self.source_local_const_literal_context_type(Some(ty)) {
            Some(context_ty) => return Some(context_ty)
            None => ()
          }
        }
      _ => ()
    }
  }
  None
}

///|
fn wgsl_ir_source_local_const_initializer_components_contain(
  components : Array[Handle],
  literal : Handle,
) -> Bool {
  for component in components {
    if component == literal {
      return true
    }
  }
  false
}

///|
fn WgslIrLowerer::record_source_local_const_literal_handle(
  self : WgslIrLowerer,
  scope : WgslIrFunctionScope,
  token : @ast.WgslExprToken,
  ty : Handle?,
  handle : Handle,
) -> Unit raise WgslIrLowerError {
  let key = wgsl_ir_source_local_const_literal_key(token, ty)
  if !scope.source_local_const_initializer_expressions.contains(key) {
    scope.source_local_const_initializer_expressions.set(key, handle)
  }
  match self.source_local_const_literal_semantic_key(token, ty) {
    Some(semantic_key) =>
      if !scope.source_local_const_initializer_expressions.contains(
          semantic_key,
        ) {
        scope.source_local_const_initializer_expressions.set(
          semantic_key, handle,
        )
      }
    None => ()
  }
}

///|
fn WgslIrLowerer::source_local_const_literal_context_type(
  self : WgslIrLowerer,
  explicit_ty : Handle?,
) -> Handle? {
  match explicit_ty {
    Some(ty) =>
      match self.shader_module.types.get(ty) {
        Some({ inner: Scalar(_), .. }) => Some(ty)
        Some({ inner: Vector(_, scalar), .. })
        | Some({ inner: Matrix(_, _, scalar), .. }) =>
          Some(self.scalar_type_handle(scalar))
        _ => None
      }
    None => None
  }
}

///|
fn wgsl_ir_collect_expr_node_literal_tokens(
  node : @ast.WgslExprNode,
  out : Array[@ast.WgslExprToken],
) -> Unit {
  match node.kind() {
    Literal(token) => out.push(token)
    Group(inner) => wgsl_ir_collect_expr_node_literal_tokens(inner, out)
    Unary(_, inner) => wgsl_ir_collect_expr_node_literal_tokens(inner, out)
    Binary(_, left, right) => {
      wgsl_ir_collect_expr_node_literal_tokens(left, out)
      wgsl_ir_collect_expr_node_literal_tokens(right, out)
    }
    Call(callee, arguments) => {
      wgsl_ir_collect_expr_node_literal_tokens(callee, out)
      for argument in arguments {
        wgsl_ir_collect_expr_node_literal_tokens(argument, out)
      }
    }
    Template(base, _) => wgsl_ir_collect_expr_node_literal_tokens(base, out)
    Member(base, _) => wgsl_ir_collect_expr_node_literal_tokens(base, out)
    PathAccess(base, _) => wgsl_ir_collect_expr_node_literal_tokens(base, out)
    Sequence(items) =>
      for item in items {
        wgsl_ir_collect_expr_node_literal_tokens(item, out)
      }
    _ => ()
  }
}

///|
fn WgslIrLowerer::lower_runtime_source_local_const_initializer(
  self : WgslIrLowerer,
  expr_ref : @ast.WgslExprRef,
  explicit_ty : Handle?,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  let key = wgsl_ir_source_local_const_initializer_key(expr_ref, explicit_ty)
  match scope.runtime_source_local_const_initializer_expressions.get(key) {
    Some(handle) => handle
    None => {
      let handle = self.lower_function_expression_ref_with_expected(
        expr_ref, function, scope, explicit_ty,
      )
      scope.runtime_source_local_const_initializer_expressions.set(key, handle)
      handle
    }
  }
}

///|
fn wgsl_ir_source_local_const_initializer_key(
  expr_ref : @ast.WgslExprRef,
  explicit_ty : Handle?,
) -> String {
  wgsl_ir_source_local_const_token_text_key(
    wgsl_ir_expr_ref_token_text(expr_ref),
    explicit_ty,
  )
}

///|
fn wgsl_ir_source_local_const_literal_key(
  token : @ast.WgslExprToken,
  explicit_ty : Handle?,
) -> String {
  wgsl_ir_source_local_const_token_text_key(token.text(), explicit_ty)
}

///|
fn wgsl_ir_source_local_const_token_text_key(
  token_text : String,
  explicit_ty : Handle?,
) -> String {
  let ty_key = match explicit_ty {
    Some(ty) => "\{ty.index()}"
    None => "-"
  }
  "\{ty_key}:\{token_text}"
}

///|
fn WgslIrLowerer::source_local_const_initializer_semantic_key(
  self : WgslIrLowerer,
  expr_ref : @ast.WgslExprRef,
  expected_ty : Handle?,
) -> String? raise WgslIrLowerError {
  guard expr_ref.root() is Some(root) else { return None }
  self.source_local_const_initializer_node_semantic_key(root, expected_ty)
}

///|
fn WgslIrLowerer::source_local_const_initializer_node_semantic_key(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  expected_ty : Handle?,
) -> String? raise WgslIrLowerError {
  match node.kind() {
    Literal(token) =>
      self.source_local_const_literal_semantic_key(token, expected_ty)
    Call(callee, arguments) =>
      self.source_local_const_vector_splat_semantic_key(
        callee,
        wgsl_ir_call_arguments(arguments),
        expected_ty,
      )
    Group(inner) =>
      self.source_local_const_initializer_node_semantic_key(inner, expected_ty)
    Sequence([single]) =>
      self.source_local_const_initializer_node_semantic_key(single, expected_ty)
    _ => None
  }
}

///|
fn WgslIrLowerer::source_local_const_vector_splat_semantic_key(
  self : WgslIrLowerer,
  callee : @ast.WgslExprNode,
  arguments : Array[@ast.WgslExprNode],
  expected_ty : Handle?,
) -> String? raise WgslIrLowerError {
  guard expected_ty is Some(ty) else { return None }
  guard arguments is [argument] else { return None }
  guard wgsl_ir_expr_node_vector_constructor_name(callee) is Some(name) else {
    return None
  }
  guard wgsl_ir_vector_size_from_constructor_name(name) is Some(_) else {
    return None
  }
  guard argument.kind() is Literal(token) else { return None }
  let component_ty = match self.constructor_component_expected_type(ty) {
    Some(value) => value
    None => ty
  }
  match
    self.source_local_const_literal_semantic_key(token, Some(component_ty)) {
    Some(literal_key) => Some("semantic:splat:\{ty.index()}:\{literal_key}")
    None => None
  }
}

///|
fn wgsl_ir_expr_node_vector_constructor_name(
  node : @ast.WgslExprNode,
) -> String? {
  match node.kind() {
    Identifier(name) => Some(name.name())
    Template(base, _) => wgsl_ir_expr_node_vector_constructor_name(base)
    Group(inner) => wgsl_ir_expr_node_vector_constructor_name(inner)
    _ => None
  }
}

///|
fn WgslIrLowerer::source_local_const_literal_semantic_key(
  self : WgslIrLowerer,
  token : @ast.WgslExprToken,
  expected_ty : Handle?,
) -> String? raise WgslIrLowerError {
  let literal_ty = match expected_ty {
    Some(ty) =>
      match self.constructor_component_expected_type(ty) {
        Some(component_ty) => Some(component_ty)
        None => Some(ty)
      }
    None => None
  }
  let literal = self.literal_from_token_with_expected(token, literal_ty)
  Some(
    "semantic:literal:\{wgsl_ir_source_local_const_literal_value_key(literal_ty, literal)}",
  )
}

///|
fn wgsl_ir_source_local_const_literal_value_key(
  ty : Handle?,
  literal : Literal,
) -> String {
  let ty_key = match ty {
    Some(handle) => "\{handle.index()}"
    None => "-"
  }
  let value_key = match literal {
    Bool(value) => "bool:\{value}"
    F64(value) | AbstractFloat(value) | F16(value) => "float:\{value}"
    F32(value) => "float:\{value.to_double()}"
    I16(value) | I32(value) => "int:\{value}"
    I64(value) | AbstractInt(value) => "int:\{value}"
    U16(value) => "uint:\{value}"
    U32(value) => "uint:\{value}"
    U64(value) => "uint:\{value}"
  }
  "\{ty_key}:\{value_key}"
}

///|
fn WgslIrLowerer::lower_child_block(
  self : WgslIrLowerer,
  block : @ast.WgslBlock,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Block raise WgslIrLowerError {
  let child_scope = scope.child()
  let lowered = self.lower_block(block, function, child_scope)
  lowered
}

///|
fn WgslIrLowerer::lower_statement(
  self : WgslIrLowerer,
  statement : @ast.WgslStatement,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
) -> Unit raise WgslIrLowerError {
  self.lower_statement_with_local_constant_placement(
    statement,
    function,
    scope,
    block,
    UseSiteLazyLocalConstant,
    [],
  )
}

///|
fn WgslIrLowerer::lower_statement_with_block_context(
  self : WgslIrLowerer,
  statement : @ast.WgslStatement,
  statements : Array[@ast.WgslStatement],
  statement_index : Int,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
) -> Unit raise WgslIrLowerError {
  if wgsl_ir_statement_is_source_var_declaration(statement) {
    self.predeclare_source_var_suffix_locals(
      statements, statement_index, function, scope,
    )
  }
  let placement = match statement.payload() {
    LocalDeclaration(_) =>
      wgsl_ir_local_constant_arena_placement_for_statement(
        statement, statements, statement_index, scope,
      )
    _ => UseSiteLazyLocalConstant
  }
  let source_var_store_initializers = match statement.payload() {
    LocalDeclaration(locals) =>
      wgsl_ir_source_var_store_initializers_for_statement(
        locals, statements, statement_index, self, scope,
      )
    _ => []
  }
  self.lower_statement_with_local_constant_placement(
    statement, function, scope, block, placement, source_var_store_initializers,
  )
}

///|
fn WgslIrLowerer::predeclare_source_var_suffix_locals(
  self : WgslIrLowerer,
  statements : Array[@ast.WgslStatement],
  statement_index : Int,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Unit raise WgslIrLowerError {
  for index in statement_index..<statements.length() {
    for local_decl in statements[index].local_bindings() {
      if local_decl.kind() == Var {
        self.predeclare_source_local_placeholder(local_decl, function, scope)
      }
    }
  }
}

///|
fn wgsl_ir_statement_is_source_var_declaration(
  statement : @ast.WgslStatement,
) -> Bool {
  statement.local_bindings().any(fn(local_decl) { local_decl.kind() == Var })
}

///|
fn WgslIrLowerer::lower_statement_with_local_constant_placement(
  self : WgslIrLowerer,
  statement : @ast.WgslStatement,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
  local_constant_placement : WgslIrLocalConstantArenaPlacement,
  source_var_store_initializers : Array[String],
) -> Unit raise WgslIrLowerError {
  match statement.payload() {
    Empty => ()
    Compound =>
      match statement.blocks() {
        [child, ..] =>
          block.push(Block(self.lower_child_block(child, function, scope)))
        [] => ()
      }
    LocalDeclaration(locals) =>
      for local_decl in locals {
        self.lower_local_declaration(
          local_decl, function, scope, block, local_constant_placement, source_var_store_initializers,
        )
      }
    Return(expr) => {
      let value = match expr {
        Some(expr_ref) => {
          let expression_mark = function.expressions.items.length()
          let expected_ty = match function.result {
            Some(result) => Some(result.ty)
            None => None
          }
          guard expr_ref.root() is Some(_) else {
            raise UnsupportedExpression("empty return expression")
          }
          let handle = match expr_ref.root() {
            Some(root) if wgsl_ir_expr_node_literal_token(root) is Some(token) =>
              self.lower_function_fresh_literal_node_with_expected(
                token, function, expected_ty,
              )
            Some(root) if wgsl_ir_expr_node_is_short_circuit_binary(root) =>
              self
              .short_circuit_planner(function, scope, block)
              .materialize_return_value_node(root)
            _ =>
              self.lower_expression_ref_with_materialized_short_circuit_inputs(
                expr_ref, function, scope, block, expected_ty,
              )
          }
          let handle = self.materialize_return_expression_if_needed(
            function, scope, block, handle,
          )
          if wgsl_ir_return_expression_should_emit_before_return(
              function, expression_mark, handle,
            ) {
            BodyEmissionPlanner::push_named_expression_emit_ranges(
              block, function, expression_mark, handle,
            )
          } else if !BodyEmissionPlanner::block_contains_expression_emit(
              block, handle,
            ) &&
            !wgsl_ir_function_expression_is_naga_emit_leaf(function, handle) {
            block.push(Emit(HandleRange(handle, handle)))
          }
          Some(handle)
        }
        None => None
      }
      block.push(Return(value))
    }
    If(condition) => {
      guard condition is Some(condition_ref) else {
        raise UnsupportedStatement("if without condition")
      }
      let expression_mark = function.expressions.items.length()
      let condition_handle = self.lower_control_flow_condition_ref(
        condition_ref, function, scope, block,
      )
      let condition_refs = wgsl_ir_statement_condition_refs(
        statement.expressions(),
      )
      guard condition_refs.length() > 0 else {
        raise UnsupportedStatement("if without condition")
      }
      let blocks = statement.blocks()
      let then_block = match statement.blocks() {
        [then_child, ..] => self.lower_child_block(then_child, function, scope)
        [] => Block()
      }
      let else_block = self.lower_if_reject_chain(
        blocks, condition_refs, 1, function, scope,
      )
      let condition_emitted_by_short_circuit = match condition_ref.root() {
        Some(root) => wgsl_ir_expr_node_is_short_circuit_binary(root)
        None => false
      }
      if !condition_emitted_by_short_circuit {
        BodyEmissionPlanner::push_statement_emit_ranges(
          block, function, expression_mark, condition_handle,
        )
      }
      block.push(If(condition_handle, then_block, else_block))
    }
    While(condition) => {
      guard condition is Some(condition_ref) else {
        raise UnsupportedStatement("while without condition")
      }
      let body_statements : Array[Statement] = []
      let guard_block = Block::{ statements: body_statements }
      let cond = self.lower_control_flow_condition_ref(
        condition_ref, function, scope, guard_block,
      )
      body_statements.push(If(cond, Block(), { statements: [Break] }))
      let lowered_body = match statement.blocks() {
        [body_block, ..] => self.lower_child_block(body_block, function, scope)
        [] => Block()
      }
      if lowered_body.statements.length() > 0 {
        body_statements.push(Block(lowered_body))
      }
      block.push(Loop(guard_block, Block(), None))
    }
    Loop => {
      let (body, continuing, break_if) = self.lower_loop_blocks(
        statement, function, scope,
      )
      block.push(Loop(body, continuing, break_if))
    }
    Break(_) => block.push(Break)
    Continue => block.push(Continue)
    Discard => block.push(Kill)
    Assignment(op, lhs, rhs) => {
      guard lhs is Some(lhs_ref) else {
        raise UnsupportedStatement("assignment without lhs")
      }
      guard rhs is Some(rhs_ref) else {
        raise UnsupportedStatement("assignment without rhs")
      }
      let expression_mark = function.expressions.items.length()
      if wgsl_ir_expr_ref_is_phony(lhs_ref) {
        if self.lower_ray_query_statement_expr_ref(
            rhs_ref, function, scope, block,
          ) {
          return
        }
        if self.wgsl_ir_expr_ref_is_user_function_call(rhs_ref) {
          self.lower_call_statement(rhs_ref, function, scope, block)
          return
        }
        let rhs_value = self.lower_expression_ref_with_materialized_short_circuit_inputs(
          rhs_ref,
          function,
          scope,
          block,
          None,
        )
        block.push(Phony(rhs_value))
        return
      }
      let (target, value) = match wgsl_ir_compound_assignment_operator(op) {
        Some(binary_op) => {
          scope.pending_compound_assignment_rhs_local_root = match
            rhs_ref.root() {
            Some(root) =>
              wgsl_ir_expr_node_plain_mutable_local_identifier_name(root, scope)
            None => None
          }
          let raw_target = self.lower_function_lvalue_ref(
            lhs_ref, function, scope,
          )
          scope.pending_compound_assignment_rhs_local_root = None
          let target = self.materialize_store_pointer_if_needed(
            function, scope, block, raw_target,
          )
          if wgsl_ir_expr_ref_plain_local_identifier(lhs_ref, scope) {
            match rhs_ref.root() {
              Some(root) =>
                if wgsl_ir_compound_assignment_rhs_predeclares_reference_roots(
                    root, scope,
                  ) {
                  self.predeclare_function_binary_chain_reference_roots_in_source_order(
                    root, function, scope,
                  )
                }
              None => ()
            }
          }
          let target_value = self.compound_assignment_target_value(
            function, target,
          )
          let materialized_target = self.materialize_function_expression(
            function, scope, block, target_value,
          )
          scope.compound_assignment_rhs_depth += 1
          let rhs_value = self.lower_expression_ref_with_materialized_short_circuit_inputs(
            rhs_ref,
            function,
            scope,
            block,
            None,
          )
          scope.compound_assignment_rhs_depth -= 1
          let rhs_value = self.materialize_store_value_if_needed(
            function, scope, block, rhs_value,
          )
          let (materialized_target, rhs_value) = self.normalize_function_binary_operands(
            function, binary_op, materialized_target, rhs_value,
          )
          let value = function.expressions.append(
            Binary(binary_op, materialized_target, rhs_value),
          )
          (target, value)
        }
        None =>
          if wgsl_ir_expr_ref_plain_local_identifier(lhs_ref, scope) {
            let rhs_value = self.lower_expression_ref_with_materialized_short_circuit_inputs(
              rhs_ref,
              function,
              scope,
              block,
              None,
            )
            let raw_target = self.lower_function_lvalue_ref(
              lhs_ref, function, scope,
            )
            let target = self.materialize_store_pointer_if_needed(
              function, scope, block, raw_target,
            )
            let value = self.materialize_store_value_for_pointer_if_needed(
              function, scope, block, target, rhs_value,
            )
            (target, value)
          } else if self.wgsl_ir_expr_ref_is_function_argument_pointer_deref(
              lhs_ref, function, scope,
            ) {
            let rhs_value = self.lower_expression_ref_with_materialized_short_circuit_inputs(
              rhs_ref,
              function,
              scope,
              block,
              None,
            )
            let raw_target = self.lower_function_lvalue_ref(
              lhs_ref, function, scope,
            )
            let target = self.materialize_store_pointer_if_needed(
              function, scope, block, raw_target,
            )
            let value = self.materialize_store_value_for_pointer_if_needed(
              function, scope, block, target, rhs_value,
            )
            (target, value)
          } else {
            predeclare_assignment_rhs_root_before_target_if_needed(
              rhs_ref, function, scope,
            )
            let raw_target = self.lower_function_lvalue_ref(
              lhs_ref, function, scope,
            )
            let target = self.materialize_store_pointer_if_needed(
              function, scope, block, raw_target,
            )
            let rhs_value = self.lower_expression_ref_with_materialized_short_circuit_inputs(
              rhs_ref,
              function,
              scope,
              block,
              None,
            )
            let value = self.materialize_store_value_for_pointer_if_needed(
              function, scope, block, target, rhs_value,
            )
            (target, value)
          }
      }
      wgsl_ir_record_store_value_temporary_references(function, value)
      BodyEmissionPlanner::push_statement_emit_ranges(
        block,
        function,
        expression_mark,
        wgsl_ir_max_handle(target, value),
      )
      block.push(Store(target, value))
    }
    Increment(target) =>
      self.lower_update_statement(target, function, scope, block, true)
    Decrement(target) =>
      self.lower_update_statement(target, function, scope, block, false)
    FunctionCall(expr) => {
      guard expr is Some(expr_ref) else {
        raise UnsupportedStatement("function call without expression")
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
            block.push(Emit(HandleRange(handle, handle)))
          }
        None => ()
      }
    ConstAssert(expr) => {
      guard expr is Some(expr_ref) else {
        raise UnsupportedStatement("const_assert without expression")
      }
      block.push(
        ConstAssert(
          self.lower_function_expression_ref(expr_ref, function, scope),
        ),
      )
    }
    For(expressions) =>
      self.lower_for_statement(statement, expressions, function, scope, block)
    Switch(selector) => {
      guard selector is Some(selector_ref) else {
        raise UnsupportedStatement("switch without selector")
      }
      let expression_mark = function.expressions.items.length()
      let selector_handle = self.lower_function_expression_ref(
        selector_ref, function, scope,
      )
      let cases : Array[SwitchCase] = []
      match statement.blocks() {
        [switch_block, ..] =>
          self.lower_switch_cases(
            switch_block, function, scope, selector_handle, cases,
          )
        [] => ()
      }
      BodyEmissionPlanner::push_statement_emit_ranges(
        block, function, expression_mark, selector_handle,
      )
      block.push(Switch(selector_handle, cases))
    }
    Case(_) | DefaultCase =>
      raise UnsupportedStatement(
        "structured statement not yet representable by this WGSL IR lowerer",
      )
  }
}

///|
fn WgslIrLowerer::lower_loop_blocks(
  self : WgslIrLowerer,
  statement : @ast.WgslStatement,
  function : Function,
  scope : WgslIrFunctionScope,
) -> (Block, Block, Handle?) raise WgslIrLowerError {
  let body = Block::Block()
  let mut continuing = Block::Block()
  let mut break_if : Handle? = None
  match statement.blocks() {
    [body_block, ..] => {
      let child_scope = scope.loop_child()
      let mut saw_continuing = false
      let body_statements = body_block.statements()
      for index in 0..<body_statements.length() {
        let child = body_statements[index]
        match child.kind() {
          Continuing => {
            saw_continuing = true
            match child.blocks() {
              [continuing_block, ..] => {
                let continuing_scope = child_scope.loop_child()
                let result = self.lower_continuing_block(
                  continuing_block, function, continuing_scope,
                )
                continuing = result.0
                break_if = result.1
              }
              [] => continuing = Block()
            }
          }
          _ =>
            if !saw_continuing {
              self.lower_statement_with_block_context(
                child, body_statements, index, function, child_scope, body,
              )
            } else {
              raise UnsupportedStatement("statement after continuing in loop")
            }
        }
      }
    }
    [] => ()
  }
  (body, continuing, break_if)
}

///|
fn WgslIrLowerer::lower_continuing_block(
  self : WgslIrLowerer,
  block : @ast.WgslBlock,
  function : Function,
  scope : WgslIrFunctionScope,
) -> (Block, Handle?) raise WgslIrLowerError {
  let ir_block = Block::Block()
  let mut break_if : Handle? = None
  for statement in block.statements() {
    match statement.payload() {
      Break(condition) =>
        match condition {
          Some(expr_ref) =>
            break_if = Some(
              self.lower_function_expression_ref(expr_ref, function, scope),
            )
          None => ir_block.push(Break)
        }
      _ => self.lower_statement(statement, function, scope, ir_block)
    }
  }
  (ir_block, break_if)
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
    Call(callee, arguments) => {
      let arguments = wgsl_ir_call_arguments(arguments)
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
fn WgslIrLowerer::wgsl_ir_expr_ref_is_user_function_call(
  self : WgslIrLowerer,
  expr_ref : @ast.WgslExprRef,
) -> Bool {
  match expr_ref.root() {
    Some(root) => self.wgsl_ir_expr_node_is_user_function_call(root)
    None => false
  }
}

///|
fn WgslIrLowerer::wgsl_ir_expr_node_is_user_function_call(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
) -> Bool {
  match node.kind() {
    Group(inner) => self.wgsl_ir_expr_node_is_user_function_call(inner)
    Sequence([single]) => self.wgsl_ir_expr_node_is_user_function_call(single)
    Call(callee, _) =>
      match callee.kind() {
        Identifier(name) => self.function_names.get(name.name()) != None
        _ => false
      }
    _ => false
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
  let loop_scope = scope.loop_child()
  for local_decl in statement.local_bindings() {
    self.lower_local_declaration(
      local_decl,
      function,
      loop_scope,
      block,
      DeclarationArenaLocalConstant,
      [],
    )
  }
  for expr in expressions {
    if expr.role() == ForInitializer {
      self.lower_for_header_statement(
        expr.expression(),
        function,
        loop_scope,
        block,
      )
    }
  }
  let loop_body = Block::Block()
  match wgsl_ir_for_expression_by_role(expressions, ForCondition) {
    Some(condition_ref) => {
      let condition = self.lower_for_loop_condition_ref(
        condition_ref, function, loop_scope, loop_body,
      )
      loop_body.push(If(condition, Block(), { statements: [Break] }))
    }
    None => ()
  }
  match statement.blocks() {
    [body_block, ..] => {
      let body = self.lower_child_block(body_block, function, loop_scope)
      if body.statements.length() > 0 {
        loop_body.push(Block(body))
      }
    }
    [] => ()
  }
  let continuing = Block::Block()
  for expr in expressions {
    if expr.role() == ForUpdate {
      self.lower_for_header_statement(
        expr.expression(),
        function,
        loop_scope,
        continuing,
      )
    }
  }
  block.push(Loop(loop_body, continuing, None))
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
  selector_handle : Handle,
  cases : Array[SwitchCase],
) -> Unit raise WgslIrLowerError {
  for statement in switch_block.statements() {
    match statement.payload() {
      Case(selectors) => {
        let body = match statement.blocks() {
          [case_block, ..] =>
            self.lower_child_block(case_block, function, scope)
          [] => Block()
        }
        for selector in selectors {
          match selector {
            DefaultSelector =>
              cases.push({
                value: Default,
                body,
                fall_through: false,
                constant_dependencies: [],
              })
            ExpressionSelector(expr) =>
              cases.push({
                value: wgsl_ir_switch_value_from_ast_expression(
                  self, function, scope, selector_handle, expr,
                ),
                body,
                fall_through: false,
                constant_dependencies: self.switch_case_constant_dependencies(
                  expr, function, scope,
                ),
              })
          }
        }
      }
      DefaultCase => {
        let body = match statement.blocks() {
          [case_block, ..] =>
            self.lower_child_block(case_block, function, scope)
          [] => Block()
        }
        cases.push({
          value: Default,
          body,
          fall_through: false,
          constant_dependencies: [],
        })
      }
      Empty => ()
      _ => raise UnsupportedStatement("switch body contains non-case statement")
    }
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
      self.lower_update_handle(target, function, scope, block, increment)
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
        block.push(Emit(HandleRange(rhs_value, rhs_value)))
        return
      }
      let (target, value) = match wgsl_ir_compound_assignment_operator(op) {
        Some(binary_op) => {
          let raw_target = self.lower_function_lvalue_node(
            wgsl_ir_expr_node_from_tokens(lhs_tokens),
            function,
            scope,
          )
          let target = self.materialize_store_pointer_if_needed(
            function, scope, block, raw_target,
          )
          let rhs_node = wgsl_ir_expr_node_from_tokens(rhs_tokens)
          let lhs_node = wgsl_ir_expr_node_from_tokens(lhs_tokens)
          if wgsl_ir_expr_node_plain_local_identifier(lhs_node, scope) {
            if wgsl_ir_compound_assignment_rhs_predeclares_reference_roots(
                rhs_node, scope,
              ) {
              self.predeclare_function_binary_chain_reference_roots_in_source_order(
                rhs_node, function, scope,
              )
            }
          }
          let target_value = self.compound_assignment_target_value(
            function, target,
          )
          let materialized_target = self.materialize_function_expression(
            function, scope, block, target_value,
          )
          scope.compound_assignment_rhs_depth += 1
          let rhs_value = self.lower_function_expression_node(
            wgsl_ir_expr_node_from_tokens(rhs_tokens),
            function,
            scope,
          )
          scope.compound_assignment_rhs_depth -= 1
          let rhs_value = self.materialize_store_value_if_needed(
            function, scope, block, rhs_value,
          )
          let (materialized_target, rhs_value) = self.normalize_function_binary_operands(
            function, binary_op, materialized_target, rhs_value,
          )
          let value = function.expressions.append(
            Binary(binary_op, materialized_target, rhs_value),
          )
          (target, value)
        }
        None => {
          let lhs_node = wgsl_ir_expr_node_from_tokens(lhs_tokens)
          let rhs_node = wgsl_ir_expr_node_from_tokens(rhs_tokens)
          if wgsl_ir_expr_node_plain_local_identifier(lhs_node, scope) {
            let rhs_value = self.lower_function_expression_node(
              rhs_node, function, scope,
            )
            let raw_target = self.lower_function_lvalue_node(
              lhs_node, function, scope,
            )
            let target = self.materialize_store_pointer_if_needed(
              function, scope, block, raw_target,
            )
            let value = self.materialize_store_value_for_pointer_if_needed(
              function, scope, block, target, rhs_value,
            )
            (target, value)
          } else if self.wgsl_ir_expr_node_is_function_argument_pointer_deref(
              lhs_node, function, scope,
            ) {
            let rhs_value = self.lower_function_expression_node(
              rhs_node, function, scope,
            )
            let raw_target = self.lower_function_lvalue_node(
              lhs_node, function, scope,
            )
            let target = self.materialize_store_pointer_if_needed(
              function, scope, block, raw_target,
            )
            let value = self.materialize_store_value_for_pointer_if_needed(
              function, scope, block, target, rhs_value,
            )
            (target, value)
          } else {
            predeclare_assignment_rhs_node_root_before_target_if_needed(
              rhs_node, function, scope,
            )
            let raw_target = self.lower_function_lvalue_node(
              lhs_node, function, scope,
            )
            let target = self.materialize_store_pointer_if_needed(
              function, scope, block, raw_target,
            )
            let rhs_value = self.lower_function_expression_node(
              rhs_node, function, scope,
            )
            let value = self.materialize_store_value_for_pointer_if_needed(
              function, scope, block, target, rhs_value,
            )
            (target, value)
          }
        }
      }
      wgsl_ir_record_store_value_temporary_references(function, value)
      block.push(Store(target, value))
      return
    }
    None => ()
  }
  ignore(self.lower_function_expression_ref(expr_ref, function, scope))
}

///|
fn predeclare_assignment_rhs_root_before_target_if_needed(
  rhs_ref : @ast.WgslExprRef,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Unit {
  match rhs_ref.root() {
    Some(root) =>
      predeclare_assignment_rhs_node_root_before_target_if_needed(
        root, function, scope,
      )
    None => ()
  }
}

///|
fn predeclare_assignment_rhs_node_root_before_target_if_needed(
  rhs_node : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Unit {
  match wgsl_ir_expr_node_plain_mutable_local_identifier_name(rhs_node, scope) {
    Some(name) =>
      match scope.locals.get(name) {
        Some(handle) =>
          ignore(scope.local_pointer_expression(name, handle, function))
        None => ()
      }
    None => ()
  }
}

///|
fn wgsl_ir_compound_assignment_rhs_predeclares_reference_roots(
  root : @ast.WgslExprNode,
  scope : WgslIrFunctionScope,
) -> Bool {
  (
    wgsl_ir_expr_node_contains_member_access(root) &&
    wgsl_ir_expr_node_contains_plain_local_identifier(root, scope)
  ) ||
  wgsl_ir_expr_node_is_root_call_with_function_argument_value(root, scope)
}

///|
fn wgsl_ir_expr_node_is_root_call_with_function_argument_value(
  node : @ast.WgslExprNode,
  scope : WgslIrFunctionScope,
) -> Bool {
  match node.kind() {
    Group(inner) =>
      wgsl_ir_expr_node_is_root_call_with_function_argument_value(inner, scope)
    Call(_, arguments) => {
      let arguments = wgsl_ir_call_arguments(arguments)
      arguments.any(fn(argument) {
        wgsl_ir_expr_node_contains_function_argument_value(argument, scope)
      })
    }
    _ => false
  }
}

///|
fn wgsl_ir_expr_node_contains_plain_local_identifier(
  node : @ast.WgslExprNode,
  scope : WgslIrFunctionScope,
) -> Bool {
  match node.kind() {
    Identifier(ident) => scope.locals.contains(ident.name())
    Group(inner) | Unary(_, inner) | PostfixUpdate(_, inner) =>
      wgsl_ir_expr_node_contains_plain_local_identifier(inner, scope)
    Binary(_, left, right) | Assignment(_, left, right) | Index(left, right) =>
      wgsl_ir_expr_node_contains_plain_local_identifier(left, scope) ||
      wgsl_ir_expr_node_contains_plain_local_identifier(right, scope)
    Member(base, _) | Template(base, _) =>
      wgsl_ir_expr_node_contains_plain_local_identifier(base, scope)
    Call(callee, arguments) => {
      if wgsl_ir_expr_node_contains_plain_local_identifier(callee, scope) {
        return true
      }
      let arguments = wgsl_ir_call_arguments(arguments)
      arguments.any(fn(argument) {
        wgsl_ir_expr_node_contains_plain_local_identifier(argument, scope)
      })
    }
    Sequence(items) =>
      items.any(fn(item) {
        wgsl_ir_expr_node_contains_plain_local_identifier(item, scope)
      })
    Literal(_) | ShaderDefTemplate(_) | PathAccess(_, _) => false
  }
}

///|
fn wgsl_ir_local_constant_arena_placement_for_statement(
  statement : @ast.WgslStatement,
  statements : Array[@ast.WgslStatement],
  statement_index : Int,
  scope : WgslIrFunctionScope,
) -> WgslIrLocalConstantArenaPlacement {
  match statement.payload() {
    LocalDeclaration(locals) => {
      for local_decl in locals {
        if (local_decl.kind() == Let || local_decl.kind() == Const) &&
          wgsl_ir_local_const_initializer_uses_declaration_arena(
            local_decl, statements, statement_index, scope,
          ) &&
          wgsl_ir_local_name_has_same_block_use_before_nested_flow(
            local_decl.name().name(),
            statements,
            statement_index,
          ) {
          return DeclarationArenaLocalConstant
        }
      }
      UseSiteLazyLocalConstant
    }
    _ => UseSiteLazyLocalConstant
  }
}

///|
fn wgsl_ir_source_var_store_initializers_for_statement(
  locals : Array[@ast.WgslLocalDeclaration],
  statements : Array[@ast.WgslStatement],
  statement_index : Int,
  lowerer : WgslIrLowerer,
  scope : WgslIrFunctionScope,
) -> Array[String] raise WgslIrLowerError {
  let names : Array[String] = []
  for local_decl in locals {
    if wgsl_ir_source_var_initializer_uses_store_before_next_for(
        local_decl, statements, statement_index, lowerer, scope,
      ) {
      names.push(local_decl.name().name())
    }
  }
  names
}

///|
fn wgsl_ir_source_var_initializer_uses_store_before_next_for(
  local_decl : @ast.WgslLocalDeclaration,
  statements : Array[@ast.WgslStatement],
  statement_index : Int,
  lowerer : WgslIrLowerer,
  scope : WgslIrFunctionScope,
) -> Bool raise WgslIrLowerError {
  guard local_decl.kind() == Var else { return false }
  guard local_decl.initializer_ref() is Some(expr_ref) else { return false }
  guard expr_ref.root() is Some(root) else { return false }
  guard lowerer.expression_node_is_const_initializer(root) else { return false }
  let next_index = statement_index + 1
  guard next_index < statements.length() else { return false }
  guard statements[next_index].kind() == For else { return false }
  ignore(scope)
  wgsl_ir_statement_direct_expressions_mention_identifier(
    statements[next_index],
    local_decl.name().name(),
  )
}

///|
fn wgsl_ir_local_const_initializer_uses_declaration_arena(
  local_decl : @ast.WgslLocalDeclaration,
  statements : Array[@ast.WgslStatement],
  statement_index : Int,
  scope : WgslIrFunctionScope,
) -> Bool {
  if wgsl_ir_local_const_initializer_references_local_let(local_decl, scope) {
    return true
  }
  if wgsl_ir_local_const_initializer_is_literal(local_decl) &&
    wgsl_ir_next_assignment_rhs_mentions_identifier(
      local_decl.name().name(),
      statements,
      statement_index,
    ) {
    return false
  }
  !wgsl_ir_local_const_initializer_is_bool_literal(local_decl) &&
  wgsl_ir_next_statement_mentions_identifier(
    local_decl.name().name(),
    statements,
    statement_index,
  )
}

///|
fn wgsl_ir_local_const_initializer_references_local_let(
  local_decl : @ast.WgslLocalDeclaration,
  scope : WgslIrFunctionScope,
) -> Bool {
  match local_decl.initializer_ref() {
    Some(expr_ref) =>
      match expr_ref.root() {
        Some(root) =>
          wgsl_ir_expr_node_references_local_let_constant(root, scope)
        None => false
      }
    None => false
  }
}

///|
fn wgsl_ir_local_const_initializer_is_literal(
  local_decl : @ast.WgslLocalDeclaration,
) -> Bool {
  match local_decl.initializer_ref() {
    Some(expr_ref) =>
      match expr_ref.root() {
        Some(root) => wgsl_ir_expr_node_is_literal(root)
        None => false
      }
    None => false
  }
}

///|
fn wgsl_ir_local_const_initializer_is_bool_literal(
  local_decl : @ast.WgslLocalDeclaration,
) -> Bool {
  match local_decl.initializer_ref() {
    Some(expr_ref) =>
      match expr_ref.root() {
        Some(root) => wgsl_ir_expr_node_is_bool_literal(root)
        None => false
      }
    None => false
  }
}

///|
fn wgsl_ir_expr_node_is_literal(node : @ast.WgslExprNode) -> Bool {
  match node.kind() {
    Literal(_) => true
    Group(inner) => wgsl_ir_expr_node_is_literal(inner)
    _ => false
  }
}

///|
fn wgsl_ir_expr_node_is_bool_literal(node : @ast.WgslExprNode) -> Bool {
  match node.kind() {
    Literal(token) => token.text() == "true" || token.text() == "false"
    Group(inner) => wgsl_ir_expr_node_is_bool_literal(inner)
    _ => false
  }
}

///|
fn wgsl_ir_next_assignment_rhs_mentions_identifier(
  name : String,
  statements : Array[@ast.WgslStatement],
  statement_index : Int,
) -> Bool {
  let next_index = statement_index + 1
  if next_index >= statements.length() {
    return false
  }
  match statements[next_index].payload() {
    Assignment(_, _, Some(rhs)) =>
      wgsl_ir_expr_ref_mentions_identifier(rhs, name)
    _ => false
  }
}

///|
fn wgsl_ir_next_statement_mentions_identifier(
  name : String,
  statements : Array[@ast.WgslStatement],
  statement_index : Int,
) -> Bool {
  let next_index = statement_index + 1
  if next_index >= statements.length() {
    return false
  }
  wgsl_ir_statement_direct_expressions_mention_identifier(
    statements[next_index],
    name,
  )
}

///|
fn wgsl_ir_local_name_has_same_block_use_before_nested_flow(
  name : String,
  statements : Array[@ast.WgslStatement],
  statement_index : Int,
) -> Bool {
  for index in (statement_index + 1)..<statements.length() {
    let statement = statements[index]
    if wgsl_ir_statement_direct_expressions_mention_identifier(statement, name) {
      return true
    }
    if statement.blocks().length() > 0 {
      return false
    }
  }
  false
}

///|
fn wgsl_ir_statement_direct_expressions_mention_identifier(
  statement : @ast.WgslStatement,
  name : String,
) -> Bool {
  for local_decl in statement.local_bindings() {
    match local_decl.initializer_ref() {
      Some(expr_ref) =>
        if wgsl_ir_expr_ref_mentions_identifier(expr_ref, name) {
          return true
        }
      None => ()
    }
  }
  for expr_ref in statement.expression_refs() {
    if wgsl_ir_expr_ref_mentions_identifier(expr_ref, name) {
      return true
    }
  }
  false
}

///|
fn wgsl_ir_expr_ref_mentions_identifier(
  expr_ref : @ast.WgslExprRef,
  name : String,
) -> Bool {
  match expr_ref.root() {
    Some(root) => wgsl_ir_expr_node_mentions_identifier(root, name)
    None => expr_ref.identifiers().any(fn(ident) { ident.name() == name })
  }
}

///|
fn wgsl_ir_expr_node_mentions_identifier(
  node : @ast.WgslExprNode,
  name : String,
) -> Bool {
  match node.kind() {
    Identifier(ident) => ident.name() == name
    Literal(_) | ShaderDefTemplate(_) => false
    Unary(_, expr) | PostfixUpdate(_, expr) | Group(expr) =>
      wgsl_ir_expr_node_mentions_identifier(expr, name)
    Assignment(_, lhs, rhs) | Binary(_, lhs, rhs) | Index(lhs, rhs) =>
      wgsl_ir_expr_node_mentions_identifier(lhs, name) ||
      wgsl_ir_expr_node_mentions_identifier(rhs, name)
    Call(callee, args) =>
      wgsl_ir_expr_node_mentions_identifier(callee, name) ||
      args.any(fn(arg) { wgsl_ir_expr_node_mentions_identifier(arg, name) })
    Template(callee, args) =>
      wgsl_ir_expr_node_mentions_identifier(callee, name) ||
      args.any(fn(arg) {
        match arg {
          Expression(expr) => wgsl_ir_expr_ref_mentions_identifier(expr, name)
          Type(_) => false
        }
      })
    PathAccess(base, segment) =>
      wgsl_ir_expr_node_mentions_identifier(base, name) ||
      segment.name() == name
    Member(base, _) => wgsl_ir_expr_node_mentions_identifier(base, name)
    Sequence(items) =>
      items.any(fn(item) { wgsl_ir_expr_node_mentions_identifier(item, name) })
  }
}

///|
fn wgsl_ir_expr_ref_plain_local_identifier(
  expr_ref : @ast.WgslExprRef,
  scope : WgslIrFunctionScope,
) -> Bool {
  match expr_ref.root() {
    Some(root) => wgsl_ir_expr_node_plain_local_identifier(root, scope)
    None => false
  }
}

///|
fn WgslIrLowerer::wgsl_ir_expr_ref_is_function_argument_pointer_deref(
  self : WgslIrLowerer,
  expr_ref : @ast.WgslExprRef,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Bool {
  match expr_ref.root() {
    Some(root) =>
      self.wgsl_ir_expr_node_is_function_argument_pointer_deref(
        root, function, scope,
      )
    None => false
  }
}

///|
fn WgslIrLowerer::wgsl_ir_expr_node_is_function_argument_pointer_deref(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Bool {
  match node.kind() {
    Group(inner) =>
      self.wgsl_ir_expr_node_is_function_argument_pointer_deref(
        inner, function, scope,
      )
    Unary(op, inner) =>
      if op == Multiply {
        self.wgsl_ir_expr_node_is_function_argument_pointer(
          inner, function, scope,
        )
      } else {
        false
      }
    _ => false
  }
}

///|
fn WgslIrLowerer::wgsl_ir_expr_node_is_function_argument_pointer(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Bool {
  match node.kind() {
    Group(inner) =>
      self.wgsl_ir_expr_node_is_function_argument_pointer(
        inner, function, scope,
      )
    Identifier(ident) =>
      match scope.arguments.get(ident.name()) {
        Some(index) =>
          match function.arguments.get(index) {
            Some(argument) => self.lowerer_type_is_pointer(argument.ty)
            None => false
          }
        None => false
      }
    _ => false
  }
}

///|
fn wgsl_ir_expr_node_plain_local_identifier(
  node : @ast.WgslExprNode,
  scope : WgslIrFunctionScope,
) -> Bool {
  match node.kind() {
    Identifier(ident) => scope.locals.contains(ident.name())
    Group(inner) => wgsl_ir_expr_node_plain_local_identifier(inner, scope)
    _ => false
  }
}

///|
fn wgsl_ir_expr_node_references_local_let_constant(
  node : @ast.WgslExprNode,
  scope : WgslIrFunctionScope,
) -> Bool {
  match node.kind() {
    Identifier(name) =>
      match scope.local_constants.get(name.name()) {
        Some(cell) => cell.source == LocalLet
        None => false
      }
    Literal(_) | ShaderDefTemplate(_) => false
    Unary(_, inner) | PostfixUpdate(_, inner) | Group(inner) =>
      wgsl_ir_expr_node_references_local_let_constant(inner, scope)
    Assignment(_, left, right) | Binary(_, left, right) | Index(left, right) =>
      wgsl_ir_expr_node_references_local_let_constant(left, scope) ||
      wgsl_ir_expr_node_references_local_let_constant(right, scope)
    Call(callee, arguments) => {
      let arguments = wgsl_ir_call_arguments(arguments)
      wgsl_ir_expr_node_references_local_let_constant(callee, scope) ||
      wgsl_ir_expr_node_list_references_local_let_constant(arguments, scope)
    }
    Template(callee, arguments) =>
      wgsl_ir_expr_node_references_local_let_constant(callee, scope) ||
      arguments.any(fn(argument) {
        match argument {
          Expression(expr_ref) =>
            match expr_ref.root() {
              Some(root) =>
                wgsl_ir_expr_node_references_local_let_constant(root, scope)
              None => false
            }
          Type(_) => false
        }
      })
    PathAccess(base, _) | Member(base, _) =>
      wgsl_ir_expr_node_references_local_let_constant(base, scope)
    Sequence(items) =>
      wgsl_ir_expr_node_list_references_local_let_constant(items, scope)
  }
}

///|
fn wgsl_ir_expr_node_list_references_local_let_constant(
  items : Array[@ast.WgslExprNode],
  scope : WgslIrFunctionScope,
) -> Bool {
  for item in items {
    if wgsl_ir_expr_node_references_local_let_constant(item, scope) {
      return true
    }
  }
  false
}

///|
fn wgsl_ir_expr_ref_references_local_let_constant(
  expr_ref : @ast.WgslExprRef,
  scope : WgslIrFunctionScope,
) -> Bool {
  match expr_ref.root() {
    Some(root) => wgsl_ir_expr_node_references_local_let_constant(root, scope)
    None => false
  }
}

///|
fn wgsl_ir_expr_node_plain_mutable_local_identifier_name(
  node : @ast.WgslExprNode,
  scope : WgslIrFunctionScope,
) -> String? {
  match node.kind() {
    Identifier(ident) =>
      if scope.locals.contains(ident.name()) {
        Some(ident.name())
      } else {
        None
      }
    Group(inner) =>
      wgsl_ir_expr_node_plain_mutable_local_identifier_name(inner, scope)
    _ => None
  }
}

///|
fn WgslIrLowerer::lower_local_declaration(
  self : WgslIrLowerer,
  local_decl : @ast.WgslLocalDeclaration,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
  local_constant_placement : WgslIrLocalConstantArenaPlacement,
  source_var_store_initializers : Array[String],
) -> Unit raise WgslIrLowerError {
  if local_decl.kind() == Const {
    self.lower_local_const_declaration(
      local_decl, function, scope, local_constant_placement,
    )
    return
  }
  if local_decl.kind() == Var &&
    source_var_store_initializers.any(fn(name) {
      name == local_decl.name().name()
    }) {
    self.lower_local_var_store_declaration(local_decl, function, scope, block)
    return
  }
  if local_decl.kind() == Var &&
    !scope.predeclared_source_locals.contains(
      wgsl_ir_local_declaration_key(local_decl),
    ) &&
    !self.local_var_initializer_uses_store(local_decl) {
    self.predeclare_source_local_placeholder(local_decl, function, scope)
  }
  if local_decl.kind() == Var &&
    scope.predeclared_source_locals.contains(
      wgsl_ir_local_declaration_key(local_decl),
    ) {
    if wgsl_ir_predeclared_source_var_has_init(local_decl, function, scope) {
      ignore(
        wgsl_ir_lower_predeclared_source_var_declaration(
          local_decl, scope, block,
        ),
      )
    } else {
      match local_decl.initializer_ref() {
        Some(expr_ref) => {
          let initializer_is_const = match expr_ref.root() {
            Some(root) => self.expression_node_is_const_initializer(root)
            None => false
          }
          if initializer_is_const {
            let declaration_placement = match local_constant_placement {
              DeclarationArenaLocalConstant => true
              UseSiteLazyLocalConstant => false
            }
            if scope.loop_depth == 0 || declaration_placement {
              self.lower_predeclared_source_var_const_initializer(
                local_decl, expr_ref, function, scope, block,
              )
            } else {
              self.lower_local_var_store_declaration(
                local_decl, function, scope, block,
              )
            }
          } else {
            self.lower_local_var_store_declaration(
              local_decl, function, scope, block,
            )
          }
        }
        None =>
          ignore(
            wgsl_ir_lower_predeclared_source_var_declaration(
              local_decl, scope, block,
            ),
          )
      }
    }
    return
  }
  if local_decl.kind() == Var &&
    self.local_var_initializer_uses_store(local_decl) {
    self.lower_local_var_store_declaration(local_decl, function, scope, block)
    return
  }
  if local_decl.kind() == Var &&
    wgsl_ir_lower_predeclared_source_var_declaration(local_decl, scope, block) {
    return
  }
  let expression_mark = function.expressions.items.length()
  let local_constant_snapshot = wgsl_ir_snapshot_local_constant_values(
    scope.local_constants,
  )
  let explicit_ty = match local_decl.ty_ref() {
    Some(ty_ref) => Some(self.lower_function_type_ref(ty_ref, function, scope))
    None => None
  }
  let mut address_of_ty : Handle? = None
  let mut init = match local_decl.initializer_ref() {
    Some(expr_ref) =>
      match wgsl_ir_address_of_operand_ref(expr_ref) {
        Some(target_ref) => {
          let target = self.lower_function_lvalue_node(
            target_ref, function, scope,
          )
          let pointer_ty = self.pointer_type_for_lvalue(function, target)
          address_of_ty = Some(pointer_ty)
          if local_decl.kind() == Let {
            Some(target)
          } else {
            Some(function.expressions.append(AddressOf(pointer_ty, target)))
          }
        }
        None => {
          let init_is_const = if local_decl.kind() == Var {
            match expr_ref.root() {
              Some(root) => self.expression_node_is_const_initializer(root)
              None => false
            }
          } else {
            false
          }
          Some(
            if init_is_const {
              self.lower_runtime_source_local_const_initializer(
                expr_ref, explicit_ty, function, scope,
              )
            } else if local_decl.kind() == Let &&
              wgsl_ir_expr_ref_references_local_let_constant(expr_ref, scope) {
              scope.source_let_initializer_preserve_depth += 1
              let handle = self.lower_function_expression_ref_with_expected(
                expr_ref, function, scope, explicit_ty,
              )
              scope.source_let_initializer_preserve_depth -= 1
              handle
            } else {
              self.lower_function_expression_ref_with_expected(
                expr_ref, function, scope, explicit_ty,
              )
            },
          )
        }
      }
    None => None
  }
  if local_decl.kind() == Let {
    match init {
      Some(init_handle) => {
        if self.local_let_const_scalar_initializer_should_fold(
            local_decl, init_handle, function, scope,
          ) {
          let normalized = self.normalized_local_constant_initializer(
            function, init_handle,
          )
          function.expressions.set_origin(normalized, FoldedLocalConstant)
          ignore(scope.locals.remove(local_decl.name().name()))
          ignore(
            scope.local_pointer_expressions.remove(local_decl.name().name()),
          )
          match local_constant_placement {
            DeclarationArenaLocalConstant =>
              scope.local_constants.set(
                local_decl.name().name(),
                wgsl_ir_local_let_value_cell(ExpressionAlias(normalized)),
              )
            UseSiteLazyLocalConstant => {
              let normalized_expression = wgsl_ir_lazy_local_constant_expression(
                function, normalized,
              )
              wgsl_ir_rewind_function_expressions(function, expression_mark)
              wgsl_ir_restore_local_constant_values(
                scope.local_constants,
                local_constant_snapshot,
              )
              match local_decl.initializer_ref() {
                Some(expr_ref) =>
                  scope.local_constants.set(
                    local_decl.name().name(),
                    wgsl_ir_local_let_value_cell(
                      LazyConstant({
                        expr_ref,
                        explicit_ty,
                        normalized: normalized_expression,
                      }),
                    ),
                  )
                None => ()
              }
            }
          }
          return
        }
        let materialized = self.materialize_return_subexpressions(
          function, scope, block, init_handle,
        )
        if materialized != init_handle {
          init = Some(materialized)
        }
        match init {
          Some(normalized) =>
            if self.function_expression_should_materialize_as_let_initializer(
                function, normalized,
              ) {
              let materialized_value = self.materialize_function_expression(
                function, scope, block, normalized,
              )
              ignore(scope.locals.remove(local_decl.name().name()))
              ignore(
                scope.local_pointer_expressions.remove(local_decl.name().name()),
              )
              scope.local_constants.set(
                local_decl.name().name(),
                wgsl_ir_local_let_value_cell(
                  ExpressionAlias(materialized_value),
                ),
              )
              return
            } else if wgsl_ir_function_expression_is_materialized_temporary(
                function, normalized,
              ) {
              ignore(scope.locals.remove(local_decl.name().name()))
              ignore(
                scope.local_pointer_expressions.remove(local_decl.name().name()),
              )
              scope.local_constants.set(
                local_decl.name().name(),
                wgsl_ir_local_let_value_cell(ExpressionAlias(normalized)),
              )
              return
            }
          _ => ()
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
  match init {
    Some(init_handle) =>
      self.contextualize_function_expression_for_type(function, init_handle, ty)
    None => ()
  }
  if local_decl.kind() == Var {
    match local_decl.initializer_ref() {
      Some(expr_ref) =>
        match expr_ref.root() {
          Some(root) =>
            if self.expression_node_is_const_initializer(root) {
              self.record_source_local_const_initializer_literals(
                expr_ref,
                expression_mark,
                function,
                scope,
                Some(ty),
              )
            }
          None => ()
        }
      None => ()
    }
  }
  if local_decl.kind() == Let {
    match init {
      Some(init_handle) =>
        if self.function_expression_is_handle_resource_value(
            function, init_handle,
          ) {
          ignore(scope.locals.remove(local_decl.name().name()))
          ignore(
            scope.local_pointer_expressions.remove(local_decl.name().name()),
          )
          scope.local_constants.set(
            local_decl.name().name(),
            wgsl_ir_local_let_value_cell(ExpressionAlias(init_handle)),
          )
          return
        }
      None => ()
    }
  }
  let lowered_name = self.naga_oil_generated_import_local_spelling_for_scope(
    local_decl.name().name(),
    scope,
  )
  if local_decl.kind() == Let {
    match init {
      Some(init_handle) =>
        if wgsl_ir_function_expression_should_use_named_let(
            function, init_handle,
          ) {
          if wgsl_ir_function_replace_named_expression(
              function, init_handle, lowered_name, ty,
            ) {
            ignore(scope.locals.remove(local_decl.name().name()))
            ignore(
              scope.local_pointer_expressions.remove(local_decl.name().name()),
            )
            scope.local_constants.set(
              local_decl.name().name(),
              wgsl_ir_local_let_value_cell(ExpressionAlias(init_handle)),
            )
            return
          }
          function.named_expressions.push({
            handle: init_handle,
            name: lowered_name,
            ty,
          })
          ignore(scope.locals.remove(local_decl.name().name()))
          ignore(
            scope.local_pointer_expressions.remove(local_decl.name().name()),
          )
          scope.local_constants.set(
            local_decl.name().name(),
            wgsl_ir_local_let_value_cell(ExpressionAlias(init_handle)),
          )
          BodyEmissionPlanner::push_named_expression_emit_ranges(
            block, function, expression_mark, init_handle,
          )
          return
        }
      None => ()
    }
  }
  let var_init_in_declaration = if local_decl.kind() == Var {
    match init {
      Some(init_handle) =>
        self.function_expression_is_const_expression(function, init_handle)
      None => false
    }
  } else {
    false
  }
  let handle = function.local_variables.append({
    name: Some(lowered_name),
    kind: wgsl_ir_local_variable_kind(local_decl.kind()),
    generated_temporary: false,
    generated_temporary_store_value_reference: false,
    short_circuit_result: false,
    ty,
    init: if local_decl.kind() == Var {
      if var_init_in_declaration {
        init
      } else {
        None
      }
    } else {
      init
    },
  })
  ignore(scope.local_constants.remove(local_decl.name().name()))
  ignore(scope.local_pointer_expressions.remove(local_decl.name().name()))
  scope.locals.set(local_decl.name().name(), handle)
  block.push(Declare(handle))
  if local_decl.kind() == Var {
    match init {
      Some(init_handle) =>
        if !var_init_in_declaration {
          let materialized = self.materialize_store_value_if_needed(
            function, scope, block, init_handle,
          )
          wgsl_ir_record_store_value_temporary_references(
            function, materialized,
          )
          BodyEmissionPlanner::push_statement_emit_ranges(
            block, function, expression_mark, materialized,
          )
          block.push(
            Store(
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
fn wgsl_ir_predeclared_source_var_has_init(
  local_decl : @ast.WgslLocalDeclaration,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Bool {
  match
    scope.predeclared_source_locals.get(
      wgsl_ir_local_declaration_key(local_decl),
    ) {
    Some(handle) =>
      match function.local_variables.items.get(handle.index()) {
        Some(local_var) => local_var.init != None
        None => false
      }
    None => false
  }
}

///|
fn WgslIrLowerer::lower_predeclared_source_var_const_initializer(
  self : WgslIrLowerer,
  local_decl : @ast.WgslLocalDeclaration,
  expr_ref : @ast.WgslExprRef,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
) -> Unit raise WgslIrLowerError {
  guard scope.predeclared_source_locals.get(
      wgsl_ir_local_declaration_key(local_decl),
    )
    is Some(handle) else {
    return
  }
  self.lower_predeclared_source_var_const_initializer_to_handle(
    local_decl, expr_ref, function, scope, handle,
  )
  ignore(
    wgsl_ir_lower_predeclared_source_var_declaration(local_decl, scope, block),
  )
}

///|
fn WgslIrLowerer::lower_predeclared_source_var_const_initializer_to_handle(
  self : WgslIrLowerer,
  local_decl : @ast.WgslLocalDeclaration,
  expr_ref : @ast.WgslExprRef,
  function : Function,
  scope : WgslIrFunctionScope,
  handle : Handle,
) -> Unit raise WgslIrLowerError {
  let lowered_name = self.naga_oil_generated_import_local_spelling_for_scope(
    local_decl.name().name(),
    scope,
  )
  let explicit_ty = match local_decl.ty_ref() {
    Some(ty_ref) => Some(self.lower_function_type_ref(ty_ref, function, scope))
    None => None
  }
  let expected_ty = self.source_local_const_initializer_expected_type(
    local_decl, explicit_ty,
  )
  let init = self.lower_source_local_const_initializer(
    expr_ref, expected_ty, function, scope,
  )
  let ty = match explicit_ty {
    Some(ty) => ty
    None =>
      match self.function_expression_type(function, init) {
        Some(inferred) => inferred
        None =>
          self.infer_local_type_from_initializer(
            local_decl.name().name(),
            local_decl.initializer_ref(),
          )
      }
  }
  let ty = self.local_declaration_storage_type(local_decl.kind(), ty)
  self.contextualize_function_expression_for_type(function, init, ty)
  function.local_variables.set(handle, {
    name: Some(lowered_name),
    kind: Var,
    generated_temporary: false,
    generated_temporary_store_value_reference: false,
    short_circuit_result: false,
    ty,
    init: Some(init),
  })
}

///|
fn WgslIrLowerer::local_var_initializer_uses_store(
  self : WgslIrLowerer,
  local_decl : @ast.WgslLocalDeclaration,
) -> Bool raise WgslIrLowerError {
  match local_decl.initializer_ref() {
    Some(expr_ref) =>
      match expr_ref.root() {
        Some(root) =>
          !self.expression_node_is_const_initializer(root) &&
          !wgsl_ir_expression_node_contains_call(root)
        None => false
      }
    None => false
  }
}

///|
fn wgsl_ir_lower_predeclared_source_var_declaration(
  local_decl : @ast.WgslLocalDeclaration,
  scope : WgslIrFunctionScope,
  block : Block,
) -> Bool {
  let key = wgsl_ir_local_declaration_key(local_decl)
  match scope.predeclared_source_locals.get(key) {
    Some(handle) => {
      ignore(scope.local_constants.remove(local_decl.name().name()))
      ignore(scope.local_pointer_expressions.remove(local_decl.name().name()))
      scope.locals.set(local_decl.name().name(), handle)
      block.push(Declare(handle))
      true
    }
    None => false
  }
}

///|
fn WgslIrLowerer::expression_node_is_const_initializer(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
) -> Bool raise WgslIrLowerError {
  match node.kind() {
    Literal(_) => true
    Identifier(name) =>
      self.constant_declarations.contains(name.name()) ||
      self.constant_names.contains(name.name())
    Group(inner) => self.expression_node_is_const_initializer(inner)
    Unary(_, inner) => self.expression_node_is_const_initializer(inner)
    Binary(_, left, right) =>
      self.expression_node_is_const_initializer(left) &&
      self.expression_node_is_const_initializer(right)
    Call(callee, arguments) =>
      self.call_expression_is_const_initializer(callee, arguments)
    Sequence([single]) => self.expression_node_is_const_initializer(single)
    _ => false
  }
}

///|
fn WgslIrLowerer::call_expression_is_const_initializer(
  self : WgslIrLowerer,
  callee : @ast.WgslExprNode,
  arguments : Array[@ast.WgslExprNode],
) -> Bool raise WgslIrLowerError {
  guard self.expression_callee_is_const_constructor(callee) else {
    return false
  }
  let arguments = wgsl_ir_call_arguments(arguments)
  for argument in arguments {
    if !self.expression_node_is_const_initializer(argument) {
      return false
    }
  }
  true
}

///|
fn WgslIrLowerer::expression_callee_is_const_constructor(
  self : WgslIrLowerer,
  callee : @ast.WgslExprNode,
) -> Bool raise WgslIrLowerError {
  match callee.kind() {
    Identifier(ident) =>
      self.type_cache.contains(ident.name()) ||
      self.lower_bitcast_callee_type(callee) != None ||
      self.lower_templated_callee_type(callee) != None ||
      wgsl_ir_untemplated_constructor_name_is_const(ident.name())
    Template(base, _) => self.expression_callee_is_const_constructor(base)
    _ => false
  }
}

///|
fn wgsl_ir_untemplated_constructor_name_is_const(name : String) -> Bool {
  name == "bool" ||
  name == "i32" ||
  name == "u32" ||
  name == "f32" ||
  name == "f16" ||
  name == "vec2" ||
  name == "vec3" ||
  name == "vec4" ||
  name == "mat2x2" ||
  name == "mat2x3" ||
  name == "mat2x4" ||
  name == "mat3x2" ||
  name == "mat3x3" ||
  name == "mat3x4" ||
  name == "mat4x2" ||
  name == "mat4x3" ||
  name == "mat4x4" ||
  name == "array"
}

///|
fn wgsl_ir_expression_node_contains_call(node : @ast.WgslExprNode) -> Bool {
  match node.kind() {
    Call(_, _) => true
    Group(inner) => wgsl_ir_expression_node_contains_call(inner)
    Unary(_, inner) => wgsl_ir_expression_node_contains_call(inner)
    Binary(_, left, right) =>
      wgsl_ir_expression_node_contains_call(left) ||
      wgsl_ir_expression_node_contains_call(right)
    Member(base, _) => wgsl_ir_expression_node_contains_call(base)
    Index(base, index) =>
      wgsl_ir_expression_node_contains_call(base) ||
      wgsl_ir_expression_node_contains_call(index)
    Sequence(items) => {
      for item in items {
        if wgsl_ir_expression_node_contains_call(item) {
          return true
        }
      }
      false
    }
    Template(base, _) => wgsl_ir_expression_node_contains_call(base)
    _ => false
  }
}

///|
fn WgslIrLowerer::lower_local_var_store_declaration(
  self : WgslIrLowerer,
  local_decl : @ast.WgslLocalDeclaration,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
) -> Unit raise WgslIrLowerError {
  let explicit_ty = match local_decl.ty_ref() {
    Some(ty_ref) => Some(self.lower_function_type_ref(ty_ref, function, scope))
    None => None
  }
  let placeholder_ty = match explicit_ty {
    Some(ty) => ty
    None => self.lower_builtin_type_name("i32")
  }
  let placeholder_ty = self.local_declaration_storage_type(
    local_decl.kind(),
    placeholder_ty,
  )
  let lowered_name = self.naga_oil_generated_import_local_spelling_for_scope(
    local_decl.name().name(),
    scope,
  )
  let handle = match
    scope.predeclared_source_locals.get(
      wgsl_ir_local_declaration_key(local_decl),
    ) {
    Some(predeclared) => predeclared
    None =>
      function.local_variables.append({
        name: Some(lowered_name),
        kind: Var,
        generated_temporary: false,
        generated_temporary_store_value_reference: false,
        short_circuit_result: false,
        ty: placeholder_ty,
        init: None,
      })
  }
  function.local_variables.set(handle, {
    name: Some(lowered_name),
    kind: Var,
    generated_temporary: false,
    generated_temporary_store_value_reference: false,
    short_circuit_result: false,
    ty: placeholder_ty,
    init: None,
  })
  block.push(Declare(handle))
  let predeclare_pointer = self.local_var_store_initializer_predeclares_pointer(
    local_decl, scope,
  )
  let mut pointer : Handle? = if predeclare_pointer {
    Some(function.expressions.append(LocalVariable(handle)))
  } else {
    None
  }
  guard local_decl.initializer_ref() is Some(expr_ref) else { return }
  let expression_mark = function.expressions.items.length()
  let init = match wgsl_ir_address_of_operand_ref(expr_ref) {
    Some(target_ref) => {
      let target = self.lower_function_lvalue_node(target_ref, function, scope)
      function.expressions.append(
        AddressOf(self.pointer_type_for_lvalue(function, target), target),
      )
    }
    None =>
      self.lower_expression_ref_with_materialized_short_circuit_inputs(
        expr_ref, function, scope, block, explicit_ty,
      )
  }
  if pointer == None {
    pointer = Some(function.expressions.append(LocalVariable(handle)))
  }
  let ty = match explicit_ty {
    Some(ty) => ty
    None =>
      match self.address_of_expression_type(function, init) {
        Some(inferred) => inferred
        None =>
          match self.function_expression_type(function, init) {
            Some(inferred) => inferred
            None =>
              self.infer_local_type_from_initializer(
                local_decl.name().name(),
                local_decl.initializer_ref(),
              )
          }
      }
  }
  let ty = self.local_declaration_storage_type(local_decl.kind(), ty)
  function.local_variables.set(handle, {
    name: Some(lowered_name),
    kind: Var,
    generated_temporary: false,
    generated_temporary_store_value_reference: false,
    short_circuit_result: false,
    ty,
    init: None,
  })
  ignore(scope.local_constants.remove(local_decl.name().name()))
  ignore(scope.local_pointer_expressions.remove(local_decl.name().name()))
  scope.locals.set(local_decl.name().name(), handle)
  guard pointer is Some(pointer) else {
    raise UnsupportedStatement(
      "missing local pointer for var \{local_decl.name().name()}",
    )
  }
  scope.local_pointer_expressions.set(local_decl.name().name(), pointer)
  self.contextualize_function_expression_for_type(function, init, ty)
  let materialized = self.materialize_store_value_if_needed(
    function, scope, block, init,
  )
  wgsl_ir_record_store_value_temporary_references(function, materialized)
  BodyEmissionPlanner::push_statement_emit_ranges(
    block, function, expression_mark, materialized,
  )
  block.push(Store(pointer, materialized))
}

///|
fn WgslIrLowerer::local_var_store_initializer_predeclares_pointer(
  self : WgslIrLowerer,
  local_decl : @ast.WgslLocalDeclaration,
  scope : WgslIrFunctionScope,
) -> Bool raise WgslIrLowerError {
  match local_decl.initializer_ref() {
    Some(expr_ref) =>
      match expr_ref.root() {
        Some(root) =>
          self.expression_node_is_const_initializer(root) ||
          wgsl_ir_expr_node_is_direct_function_argument_value(root, scope)
        None => false
      }
    None => false
  }
}

///|
fn wgsl_ir_expr_node_is_direct_function_argument_value(
  node : @ast.WgslExprNode,
  scope : WgslIrFunctionScope,
) -> Bool {
  match node.kind() {
    Group(inner) =>
      wgsl_ir_expr_node_is_direct_function_argument_value(inner, scope)
    Identifier(name) => scope.arguments.contains(name.name())
    _ => false
  }
}

///|
fn wgsl_ir_function_expression_should_use_named_let(
  function : Function,
  handle : Handle,
) -> Bool {
  match function.expressions.items.get(handle.index()) {
    Some(Literal(_))
    | Some(Constant(_))
    | Some(Override(_))
    | Some(ZeroValue(_))
    | Some(FunctionArgument(_))
    | Some(GlobalVariable(_))
    | Some(LocalVariable(_))
    | Some(AddressOf(_, _))
    | Some(FunctionCall(_, _))
    | Some(AtomicCall(_, _))
    | Some(WorkGroupUniformLoad(_)) => false
    Some(_) => true
    None => false
  }
}

///|
fn wgsl_ir_function_expression_is_materialized_temporary(
  function : Function,
  handle : Handle,
) -> Bool {
  match function.expressions.items.get(handle.index()) {
    Some(CallResult(_)) => true
    _ => false
  }
}

///|
fn wgsl_ir_max_handle(left : Handle, right : Handle) -> Handle {
  if left.index() >= right.index() {
    left
  } else {
    right
  }
}

///|
fn wgsl_ir_function_expression_is_naga_emit_leaf(
  function : Function,
  handle : Handle,
) -> Bool {
  match function.expressions.items.get(handle.index()) {
    Some(expression) => wgsl_ir_expression_is_naga_emit_leaf(expression)
    None => false
  }
}

///|
fn wgsl_ir_return_expression_should_emit_before_return(
  function : Function,
  expression_mark : Int,
  value : Handle,
) -> Bool {
  if wgsl_ir_function_expression_has_arena_name(function, value) {
    return false
  }
  for index in expression_mark..<=value.index() {
    match function.expressions.items.get(index) {
      Some(FunctionCall(_, _))
      | Some(CallResult(_))
      | Some(AtomicCall(_, _))
      | Some(ImageSample(_, _, _, _, _, _, _, _, _))
      | Some(ImageLoad(_, _, _, _, _))
      | Some(ImageQuery(_, _))
      | Some(WorkGroupUniformLoad(_)) => return false
      _ => ()
    }
  }
  match function.expressions.items.get(value.index()) {
    Some(expression) => !wgsl_ir_expression_is_naga_emit_leaf(expression)
    None => false
  }
}

///|
fn wgsl_ir_expression_is_naga_emit_leaf(expression : Expression) -> Bool {
  match expression {
    Literal(_)
    | Constant(_)
    | Override(_)
    | FunctionArgument(_)
    | CallResult(_)
    | AtomicResult(_, _)
    | GlobalVariable(_)
    | LocalVariable(_) => true
    _ => false
  }
}

///|
fn WgslIrLowerer::function_expression_should_materialize_as_let_initializer(
  self : WgslIrLowerer,
  function : Function,
  value : Handle,
) -> Bool {
  ignore(self)
  match function.expressions.items.get(value.index()) {
    Some(FunctionCall(_, _))
    | Some(AtomicCall(_, _))
    | Some(WorkGroupUniformLoad(_)) => true
    _ => false
  }
}

///|
fn WgslIrLowerer::lower_local_const_declaration(
  self : WgslIrLowerer,
  local_decl : @ast.WgslLocalDeclaration,
  function : Function,
  scope : WgslIrFunctionScope,
  local_constant_placement : WgslIrLocalConstantArenaPlacement,
) -> Unit raise WgslIrLowerError {
  let expression_mark = function.expressions.items.length()
  let local_constant_snapshot = wgsl_ir_snapshot_local_constant_values(
    scope.local_constants,
  )
  let explicit_ty = match local_decl.ty_ref() {
    Some(ty_ref) => Some(self.lower_function_type_ref(ty_ref, function, scope))
    None => None
  }
  let init = match local_decl.initializer_ref() {
    Some(expr_ref) =>
      self.lower_function_expression_ref_with_expected(
        expr_ref, function, scope, explicit_ty,
      )
    None => raise MissingType(local_decl.name().name())
  }
  if !self.function_expression_is_const_expression(function, init) {
    raise UnsupportedExpression(
      "local const initializer is not a const expression",
    )
  }
  let normalized = self.normalized_local_constant_initializer(function, init)
  function.expressions.set_origin(normalized, FoldedLocalConstant)
  ignore(scope.locals.remove(local_decl.name().name()))
  match local_constant_placement {
    DeclarationArenaLocalConstant =>
      scope.local_constants.set(
        local_decl.name().name(),
        wgsl_ir_local_const_value_cell(ExpressionAlias(normalized)),
      )
    UseSiteLazyLocalConstant => {
      let normalized_expression = wgsl_ir_lazy_local_constant_expression(
        function, normalized,
      )
      wgsl_ir_rewind_function_expressions(function, expression_mark)
      wgsl_ir_restore_local_constant_values(
        scope.local_constants,
        local_constant_snapshot,
      )
      match local_decl.initializer_ref() {
        Some(expr_ref) =>
          scope.local_constants.set(
            local_decl.name().name(),
            wgsl_ir_local_const_value_cell(
              LazyConstant({
                expr_ref,
                explicit_ty,
                normalized: normalized_expression,
              }),
            ),
          )
        None => ()
      }
    }
  }
}

///|
fn wgsl_ir_lazy_local_constant_expression(
  function : Function,
  handle : Handle,
) -> WgslIrLazyLocalConstantExpression? {
  match function.expressions.items.get(handle.index()) {
    Some(Literal(literal)) =>
      Some({ expression: Literal(literal), origin: FoldedLocalConstant })
    _ => None
  }
}

///|
fn wgsl_ir_rewind_function_expressions(
  function : Function,
  length : Int,
) -> Unit {
  function.expressions.truncate(length)
}

///|
fn WgslIrLowerer::local_let_const_scalar_initializer_should_fold(
  self : WgslIrLowerer,
  local_decl : @ast.WgslLocalDeclaration,
  init_handle : Handle,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Bool {
  if !self.function_expression_is_const_expression(function, init_handle) ||
    !self.function_expression_has_scalar_type(function, init_handle) {
    return false
  }
  if wgsl_ir_function_expression_should_use_named_let(function, init_handle) {
    match local_decl.initializer_ref() {
      Some(expr_ref) =>
        match expr_ref.root() {
          Some(root) =>
            if wgsl_ir_expr_node_references_local_let_constant(root, scope) {
              return false
            }
          None => ()
        }
      None => ()
    }
  }
  true
}

///|
fn WgslIrLowerer::function_expression_has_scalar_type(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle,
) -> Bool {
  match self.function_expression_type(function, handle) {
    Some(ty_handle) =>
      match self.shader_module.types.get(ty_handle) {
        Some(type_) =>
          match type_.inner {
            Scalar(_) => true
            _ => false
          }
        None => false
      }
    None => false
  }
}

///|
fn WgslIrLowerer::function_expression_is_handle_resource_value(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle,
) -> Bool {
  match self.function_expression_type(function, handle) {
    Some(ty) => self.type_is_global_handle_value(ty)
    None => false
  }
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
    | WorkGroupUniformLoad(_)
    | ArrayLength(_)
    | RayQueryInitialize(_, _, _)
    | RayQueryProceed(_)
    | RayQueryGenerateIntersection(_, _)
    | RayQueryConfirmIntersection(_)
    | RayQueryTerminate(_)
    | RayQueryVertexPositions(_, _)
    | RayQueryProceedResult
    | RayQueryGetIntersection(_, _)
    | SubgroupCall(_, _)
    | SubgroupBallotResult
    | SubgroupOperationResult(_)
    | CooperativeLoad(_, _, _, _)
    | CooperativeMultiplyAdd(_, _, _) => false
    Compose(_, components) =>
      self.function_expression_list_is_const_expression(function, components)
    Access(base, index) =>
      self.function_expression_is_const_expression(function, base) &&
      self.function_expression_is_const_expression(function, index)
    AccessIndex(base, _)
    | Component(base, _)
    | Splat(_, base)
    | Swizzle(_, base, _) =>
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
