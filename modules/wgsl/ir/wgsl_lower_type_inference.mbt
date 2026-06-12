///|
fn WgslIrLowerer::infer_local_type_from_initializer(
  self : WgslIrLowerer,
  name : String,
  initializer : @ast.WgslExprRef?,
) -> Handle raise WgslIrLowerError {
  guard initializer is Some(expr_ref) else { raise MissingType(name) }
  match expr_ref.root() {
    Some(root) => self.infer_expression_type(root, name)
    None => raise MissingType(name)
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
    raise MissingType(name)
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
        _ => raise MissingType(name)
      }
    Identifier(identifier) =>
      self.infer_named_expression_type(identifier.name(), name)
    Group(inner) => self.infer_expression_type(inner, name)
    Unary(op, inner) =>
      match op {
        Not => self.lower_builtin_type_name("bool")
        Subtract | Complement => self.infer_expression_type(inner, name)
        _ => raise MissingType(name)
      }
    Member(base, member_ident) =>
      match self.infer_member_expression_type(base, member_ident.name(), name) {
        Some(ty) => ty
        None => raise MissingType(name)
      }
    Index(base, _) =>
      match self.infer_index_expression_type(base, name) {
        Some(ty) => ty
        None => raise MissingType(name)
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
                    match self.function_names.get(ident.name()) {
                      Some(handle) =>
                        match
                          self.shader_module.functions.items.get(handle.index()) {
                          Some(function) =>
                            match function.result {
                              Some(result) => result.ty
                              None => raise MissingType(name)
                            }
                          None => raise MissingType(name)
                        }
                      None =>
                        match
                          wgsl_ir_relational_function_from_name(ident.name()) {
                          Some(relational_function) =>
                            self.infer_relational_expression_type(
                              relational_function, arguments, name,
                            )
                          None =>
                            match
                              wgsl_ir_math_function_from_name(ident.name()) {
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
                  }
                _ => raise MissingType(name)
              }
          }
      }
    }
    _ => raise MissingType(name)
  }
}

///|
fn WgslIrLowerer::infer_expression_type_in_function_scope(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  name : String,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  match node.kind() {
    Identifier(identifier) =>
      self.infer_scoped_named_expression_type(
        identifier.name(),
        name,
        function,
        scope,
      )
    Group(inner) =>
      self.infer_expression_type_in_function_scope(inner, name, function, scope)
    Unary(op, inner) =>
      match op {
        Not => self.lower_builtin_type_name("bool")
        Subtract | Complement =>
          self.infer_expression_type_in_function_scope(
            inner, name, function, scope,
          )
        _ => raise MissingType(name)
      }
    Member(base, member_ident) =>
      match
        self.infer_scoped_member_expression_type(
          base,
          member_ident.name(),
          name,
          function,
          scope,
        ) {
        Some(ty) => ty
        None => raise MissingType(name)
      }
    Index(base, _) =>
      match
        self.infer_scoped_index_expression_type(base, name, function, scope) {
        Some(ty) => ty
        None => raise MissingType(name)
      }
    Binary(op, left, right) => {
      let left_ty = self.infer_expression_type_in_function_scope(
        left, name, function, scope,
      )
      let right_ty = self.infer_expression_type_in_function_scope(
        right, name, function, scope,
      )
      self.binary_expression_result_type(
        wgsl_ir_binary_operator(op),
        left_ty,
        right_ty,
      )
    }
    Call(callee, arguments) =>
      self.infer_scoped_call_expression_type(
        callee,
        wgsl_ir_call_arguments(arguments),
        name,
        function,
        scope,
      )
    _ => self.infer_expression_type(node, name)
  }
}

///|
fn WgslIrLowerer::infer_scoped_named_expression_type(
  self : WgslIrLowerer,
  referenced_name : String,
  diagnostic_name : String,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  match scope.arguments.get(referenced_name) {
    Some(index) =>
      match function.arguments.get(index) {
        Some(argument) => return argument.ty
        None => raise MissingType(diagnostic_name)
      }
    None => ()
  }
  match scope.locals.get(referenced_name) {
    Some(handle) =>
      match function.local_variables.items.get(handle.index()) {
        Some(local_variable) => return local_variable.ty
        None => raise MissingType(diagnostic_name)
      }
    None => ()
  }
  match scope.local_constants.get(referenced_name) {
    Some({ value: ExpressionAlias(handle, _), .. }) =>
      match self.function_expression_type(function, handle) {
        Some(ty) => return ty
        None => raise MissingType(diagnostic_name)
      }
    Some({ value: LazyConstant(local_constant), .. }) =>
      match local_constant.explicit_ty {
        Some(ty) => return ty
        None =>
          match local_constant.expr_ref.root() {
            Some(root) =>
              return self.infer_expression_type_in_function_scope(
                root, diagnostic_name, function, scope,
              )
            None => raise MissingType(diagnostic_name)
          }
      }
    None => ()
  }
  self.infer_named_expression_type(referenced_name, diagnostic_name)
}

///|
fn WgslIrLowerer::infer_scoped_member_expression_type(
  self : WgslIrLowerer,
  base : @ast.WgslExprNode,
  member_name : String,
  diagnostic_name : String,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle? raise WgslIrLowerError {
  let base_ty = self.infer_expression_type_in_function_scope(
    base, diagnostic_name, function, scope,
  )
  self.member_type_from_base_type(base_ty, member_name)
}

///|
fn WgslIrLowerer::infer_scoped_index_expression_type(
  self : WgslIrLowerer,
  base : @ast.WgslExprNode,
  diagnostic_name : String,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle? raise WgslIrLowerError {
  let base_ty = self.infer_expression_type_in_function_scope(
    base, diagnostic_name, function, scope,
  )
  self.indexed_type_from_type_handle(base_ty, None)
}

///|
fn WgslIrLowerer::infer_scoped_call_expression_type(
  self : WgslIrLowerer,
  callee : @ast.WgslExprNode,
  arguments : Array[@ast.WgslExprNode],
  name : String,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  match self.lower_bitcast_callee_type(callee) {
    Some(ty) => ty
    None =>
      match self.lower_templated_callee_type(callee) {
        Some(ty) => ty
        None =>
          match callee.kind() {
            Identifier(ident) =>
              if ident.name() == "select" {
                match wgsl_ir_flatten_expression_arguments(arguments) {
                  [reject, _, _] =>
                    self.infer_expression_type_in_function_scope(
                      reject, name, function, scope,
                    )
                  _ => raise MissingType(name)
                }
              } else if ident.name() == "array" {
                self.infer_scoped_array_constructor_type_from_ast(
                  arguments, name, function, scope,
                )
              } else {
                match self.function_names.get(ident.name()) {
                  Some(handle) =>
                    match
                      self.shader_module.functions.items.get(handle.index()) {
                      Some(function) =>
                        match function.result {
                          Some(result) => result.ty
                          None => raise MissingType(name)
                        }
                      None => raise MissingType(name)
                    }
                  None =>
                    match wgsl_ir_relational_function_from_name(ident.name()) {
                      Some(relational_function) =>
                        self.infer_scoped_relational_expression_type(
                          relational_function, arguments, name, function, scope,
                        )
                      None =>
                        match wgsl_ir_math_function_from_name(ident.name()) {
                          Some(math_function) =>
                            self.infer_scoped_math_expression_type(
                              math_function, arguments, name, function, scope,
                            )
                          None =>
                            self.lower_scoped_untemplated_constructor_type_from_ast(
                              ident.name(),
                              arguments,
                              name,
                              function,
                              scope,
                            )
                        }
                    }
                }
              }
            _ => raise MissingType(name)
          }
      }
  }
}

///|
fn WgslIrLowerer::lower_scoped_untemplated_constructor_type_from_ast(
  self : WgslIrLowerer,
  name : String,
  arguments : Array[@ast.WgslExprNode],
  diagnostic_name : String,
  function : Function,
  scope : WgslIrFunctionScope,
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
                  self.lower_scoped_generic_constructor_type_from_ast(
                    name, arguments, diagnostic_name, function, scope,
                  )
              }
          }
      }
  }
}

///|
fn WgslIrLowerer::lower_scoped_generic_constructor_type_from_ast(
  self : WgslIrLowerer,
  name : String,
  arguments : Array[@ast.WgslExprNode],
  diagnostic_name : String,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  match name {
    "vec2" | "vec3" | "vec4" => {
      let scalar = self.scoped_constructor_scalar_from_ast_arguments(
        arguments, diagnostic_name, function, scope,
      )
      self.intern_type(
        "\{name}<\{wgsl_ir_scalar_name(scalar.kind, scalar.width)}>",
        Vector(wgsl_ir_vector_size_from_name(name), scalar),
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
      let scalar = self.scoped_constructor_scalar_from_ast_arguments(
        arguments, diagnostic_name, function, scope,
      )
      let (columns, rows) = wgsl_ir_matrix_size_from_name(name)
      self.intern_type(
        "\{name}<\{wgsl_ir_scalar_name(scalar.kind, scalar.width)}>",
        Matrix(columns, rows, scalar),
      )
    }
    _ => raise UnsupportedType(name)
  }
}

///|
fn WgslIrLowerer::infer_scoped_array_constructor_type_from_ast(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  diagnostic_name : String,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  let flattened = wgsl_ir_flatten_expression_arguments(arguments)
  guard flattened is [first, ..] else { raise MissingType(diagnostic_name) }
  let element_ty = self.infer_expression_type_in_function_scope(
    first, diagnostic_name, function, scope,
  )
  self.intern_inferred_array_type(element_ty, flattened.length())
}

///|
fn WgslIrLowerer::scoped_constructor_scalar_from_ast_arguments(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  diagnostic_name : String,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Scalar raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments is [first, .. rest] else {
    raise MissingType(diagnostic_name)
  }
  let first_ty = self.infer_expression_type_in_function_scope(
    first, diagnostic_name, function, scope,
  )
  let mut scalar = self.scalar_from_type_handle(first_ty, diagnostic_name)
  for argument in rest {
    let ty = self.infer_expression_type_in_function_scope(
      argument, diagnostic_name, function, scope,
    )
    let next = self.scalar_from_type_handle(ty, diagnostic_name)
    scalar = self.merge_constructor_scalar(scalar, next, diagnostic_name)
  }
  scalar
}

///|
fn WgslIrLowerer::infer_scoped_math_expression_type(
  self : WgslIrLowerer,
  math_function : MathFunction,
  arguments : Array[@ast.WgslExprNode],
  name : String,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  guard arguments is [first, .. rest] else { raise MissingType(name) }
  match math_function {
    Dot | Distance | Length | Determinant =>
      match
        self.infer_expression_type_in_function_scope(
          first, name, function, scope,
        ) {
        ty => self.scalar_type_from_composite_type(ty)
      }
    Modf | Frexp =>
      self.infer_expression_type_in_function_scope(first, name, function, scope)
    _ =>
      match rest {
        _ =>
          self.infer_expression_type_in_function_scope(
            first, name, function, scope,
          )
      }
  }
}

///|
fn WgslIrLowerer::infer_scoped_relational_expression_type(
  self : WgslIrLowerer,
  relational_function : RelationalFunction,
  arguments : Array[@ast.WgslExprNode],
  name : String,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  guard arguments is [first, ..] else { raise MissingType(name) }
  match relational_function {
    All | Any => self.scalar_type_handle(Scalar(Bool, 1))
    IsNan | IsInf =>
      match
        self.infer_expression_type_in_function_scope(
          first, name, function, scope,
        ) {
        ty => self.boolean_result_type(ty, ty)
      }
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
  self.member_type_from_base_type(base_ty, member_name)
}

///|
fn WgslIrLowerer::member_type_from_base_type(
  self : WgslIrLowerer,
  base_ty : Handle,
  member_name : String,
) -> Handle? {
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
              raise UnsupportedExpression(
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
    _ => raise MissingType(name)
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
  guard arguments is [first, .. rest] else { raise MissingType(name) }
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
  guard arguments is [first, ..] else { raise MissingType(name) }
  match relational_function {
    All | Any => self.scalar_type_handle(Scalar(Bool, 1))
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
            None => raise MissingType(diagnostic_name)
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
    "RAY_FLAG_NONE" => Some(U32(0))
    "RAY_FLAG_FORCE_OPAQUE" => Some(U32(0x1))
    "RAY_FLAG_FORCE_NO_OPAQUE" => Some(U32(0x2))
    "RAY_FLAG_TERMINATE_ON_FIRST_HIT" => Some(U32(0x4))
    "RAY_FLAG_SKIP_CLOSEST_HIT_SHADER" => Some(U32(0x8))
    "RAY_FLAG_CULL_BACK_FACING" => Some(U32(0x10))
    "RAY_FLAG_CULL_FRONT_FACING" => Some(U32(0x20))
    "RAY_FLAG_CULL_OPAQUE" => Some(U32(0x40))
    "RAY_FLAG_CULL_NO_OPAQUE" => Some(U32(0x80))
    "RAY_FLAG_SKIP_TRIANGLES" => Some(U32(0x100))
    "RAY_FLAG_SKIP_AABBS" => Some(U32(0x200))
    "RAY_QUERY_INTERSECTION_NONE" => Some(U32(0))
    "RAY_QUERY_INTERSECTION_TRIANGLE" => Some(U32(1))
    "RAY_QUERY_INTERSECTION_GENERATED" => Some(U32(2))
    "RAY_QUERY_INTERSECTION_AABB" => Some(U32(3))
    _ => None
  }
}

///|
fn WgslIrLowerer::global_identifier_expression(
  self : WgslIrLowerer,
  name : @ast.WgslIdent,
) -> Expression raise WgslIrLowerError {
  match self.ensure_constant_declaration_lowered(name.name()) {
    Some(handle) => Constant(handle)
    None =>
      match self.ensure_override_declaration_predeclared(name.name()) {
        Some(handle) => Override(handle)
        None =>
          match self.global_names.get(name.name()) {
            Some(handle) => GlobalVariable(handle)
            None =>
              match wgsl_ir_predeclared_u32_constant_literal(name.name()) {
                Some(literal) => Literal(literal)
                None => raise UnknownIdentifier(name.name())
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
        None => raise MissingType(diagnostic_name)
      }
    None =>
      match self.override_declarations.get(referenced_name) {
        Some(override_decl) => {
          self.predeclare_override_declaration(override_decl)
          match self.override_names.get(referenced_name) {
            Some(handle) =>
              match self.shader_module.overrides.items.get(handle.index()) {
                Some(override_) => override_.ty
                None => raise MissingType(diagnostic_name)
              }
            None => raise MissingType(diagnostic_name)
          }
        }
        None =>
          match self.global_names.get(referenced_name) {
            Some(handle) =>
              match
                self.shader_module.global_variables.items.get(handle.index()) {
                Some(global) => global.ty
                None => raise MissingType(diagnostic_name)
              }
            None => raise MissingType(diagnostic_name)
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
    None => raise MissingType(name)
  }
}
