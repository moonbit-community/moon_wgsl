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
  let ty = match explicit_ty {
    Some(ty) => Some(ty)
    None =>
      Some(
        self.infer_local_type_from_initializer(
          local_decl.name().name(),
          local_decl.initializer_ref(),
        ),
      )
  }
  match ty {
    Some(value) =>
      if self.source_local_const_initializer_uses_storage_expected_type(value) {
        Some(self.local_declaration_storage_type(local_decl.kind(), value))
      } else {
        Some(value)
      }
    None => None
  }
}

///|
fn WgslIrLowerer::source_local_const_initializer_uses_storage_expected_type(
  self : WgslIrLowerer,
  ty : Handle,
) -> Bool {
  match self.shader_module.types.items.get(ty.index()) {
    Some(type_) =>
      match type_.inner {
        Vector(_, _) | Matrix(_, _, _) => true
        _ => false
      }
    None => false
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
      self.generated_import_local_spelling_for_scope(
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
        Some(handle) => {
          wgsl_ir_mark_source_local_const_initializer_origin(function, handle)
          return handle
        }
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
            Some(handle) => {
              wgsl_ir_mark_source_local_const_initializer_origin(
                function, handle,
              )
              return handle
            }
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
    Some(handle) => {
      wgsl_ir_mark_source_local_const_initializer_origin(function, handle)
      handle
    }
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
      wgsl_ir_mark_source_local_const_initializer_origin(function, handle)
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
    match
      self.source_local_const_initializer_literal_handle(
        token,
        None,
        function,
        scope,
      ) {
      Some(handle) =>
        return Some(function.expressions.append(Splat(size, handle)))
      None => ()
    }
    match
      self.source_local_const_initializer_literal_handle(
        token,
        Some(component_ty),
        function,
        scope,
      ) {
      Some(handle) =>
        return Some(function.expressions.append(Splat(size, handle)))
      None => return None
    }
  }
  let literal_handles : Map[String, Handle] = Map([])
  self.lower_reused_literal_source_local_const_constructor_node(
    root, ty, literal_handles, function,
  )
}

///|
fn WgslIrLowerer::source_local_const_initializer_literal_handle(
  self : WgslIrLowerer,
  token : @ast.WgslExprToken,
  ty : Handle?,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle? raise WgslIrLowerError {
  let text_key = wgsl_ir_source_local_const_literal_key(token, ty)
  match scope.source_local_const_initializer_expressions.get(text_key) {
    Some(handle) => {
      wgsl_ir_mark_source_local_const_initializer_origin(function, handle)
      return Some(handle)
    }
    None => ()
  }
  match scope.runtime_source_local_const_initializer_expressions.get(text_key) {
    Some(handle) => return Some(handle)
    None => ()
  }
  match self.source_local_const_literal_semantic_key(token, ty) {
    Some(semantic_key) => {
      match scope.source_local_const_initializer_expressions.get(semantic_key) {
        Some(handle) => {
          wgsl_ir_mark_source_local_const_initializer_origin(function, handle)
          return Some(handle)
        }
        None => ()
      }
      match
        scope.runtime_source_local_const_initializer_expressions.get(
          semantic_key,
        ) {
        Some(handle) => return Some(handle)
        None => ()
      }
    }
    None => ()
  }
  match self.source_local_const_literal_abstract_context_type(ty) {
    Some(abstract_ty) =>
      match
        self.source_local_const_initializer_literal_handle(
          token,
          Some(abstract_ty),
          function,
          scope,
        ) {
        Some(handle) => return Some(handle)
        None => ()
      }
    None => ()
  }
  None
}

///|
fn WgslIrLowerer::source_local_const_literal_abstract_context_type(
  self : WgslIrLowerer,
  ty : Handle?,
) -> Handle? {
  guard ty is Some(handle) else { return None }
  match self.shader_module.types.get(handle) {
    Some({ inner: Scalar({ kind: Float, .. }), .. }) =>
      Some(self.scalar_type_handle(Scalar(AbstractFloat, 8)))
    Some({ inner: Scalar({ kind: Sint | Uint, .. }), .. }) =>
      Some(self.scalar_type_handle(Scalar(AbstractInt, 8)))
    _ => None
  }
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
          Some(
            wgsl_ir_reused_source_local_const_constructor_expression_handle(
              "splat:\{expected_ty.index()}:\{components[0].index()}",
              Splat(size, components[0]),
              literal_handles,
              function,
            ),
          )
        None =>
          Some(
            wgsl_ir_reused_source_local_const_constructor_expression_handle(
              "compose:\{expected_ty.index()}:\{wgsl_ir_handle_index_list_key(components)}",
              Compose(expected_ty, components),
              literal_handles,
              function,
            ),
          )
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
fn wgsl_ir_reused_source_local_const_constructor_expression_handle(
  key : String,
  expression : Expression,
  literal_handles : Map[String, Handle],
  function : Function,
) -> Handle {
  match literal_handles.get(key) {
    Some(existing) => existing
    None => {
      let appended = function.expressions.append(expression)
      literal_handles.set(key, appended)
      appended
    }
  }
}

///|
fn wgsl_ir_handle_index_list_key(handles : Array[Handle]) -> String {
  let parts : Array[String] = []
  for handle in handles {
    parts.push(handle.index().to_string())
  }
  parts.join(",")
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
        Matrix(columns, rows, scalar) =>
          if argument_count == columns.width() {
            Some(self.vector_type_handle(rows, scalar))
          } else if argument_count == columns.width() * rows.width() {
            Some(self.scalar_type_handle(scalar))
          } else {
            None
          }
        Struct(members, _) | PredeclaredStruct(members, _) =>
          match members.get(argument_index) {
            Some(struct_member) => Some(struct_member.ty)
            None => None
          }
        Array(element, _, _) | BindingArray(element, _) => Some(element)
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
        function.expressions.set_origin(
          literal_handle,
          SourceLocalConstInitializer,
        )
        let literal_ty = match
          self.function_expression_type(function, literal_handle) {
          Some(ty) => Some(ty)
          None => explicit_ty
        }
        self.record_source_local_const_literal_handle(
          function,
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
              function,
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
  function : Function,
  scope : WgslIrFunctionScope,
  token : @ast.WgslExprToken,
  ty : Handle?,
  handle : Handle,
) -> Unit raise WgslIrLowerError {
  wgsl_ir_mark_source_local_const_initializer_origin(function, handle)
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
fn wgsl_ir_mark_source_local_const_initializer_origin(
  function : Function,
  handle : Handle,
) -> Unit {
  match function.expressions.items.get(handle.index()) {
    Some(Literal(_)) =>
      function.expressions.set_origin(handle, SourceLocalConstInitializer)
    _ => ()
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
    F32(value) | F32Exact(value) => "float:\{value.to_double()}"
    I16(value) | I32(value) => "int:\{value}"
    I64(value) | AbstractInt(value) => "int:\{value}"
    U16(value) => "uint:\{value}"
    U32(value) => "uint:\{value}"
    U64(value) => "uint:\{value}"
  }
  "\{ty_key}:\{value_key}"
}
