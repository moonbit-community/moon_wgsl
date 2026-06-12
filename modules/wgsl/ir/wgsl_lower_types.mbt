// Copyright 2026 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

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
fn WgslIrLowerer::lower_function_type_ref(
  self : WgslIrLowerer,
  ty_ref : @ast.WgslTypeRef,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  if ty_ref.name() == "array" {
    self.lower_function_array_type_ref(ty_ref, function, scope)
  } else {
    self.lower_type_ref(ty_ref)
  }
}

///|
fn WgslIrLowerer::lower_function_array_type_ref(
  self : WgslIrLowerer,
  ty_ref : @ast.WgslTypeRef,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  let args = ty_ref.template_arguments()
  guard args is [Type(element_ty), .. rest] else {
    raise UnsupportedType(ty_ref.canonical_text())
  }
  let element = self.lower_function_type_ref(element_ty, function, scope)
  let size = match rest {
    [size_arg, ..] =>
      self.lower_function_type_template_array_size(size_arg, function, scope)
    _ => Dynamic
  }
  let layout = self.type_layout(element)
  let stride = wgsl_ir_align_to(layout.size, layout.align)
  self.intern_type(
    "array<\{self.type_cache_name(element)}, \{wgsl_ir_array_size_key(size)}>",
    Array(element, size, stride),
  )
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
      let scalar = self.required_scalar_type_argument(ty_ref)
      let (columns, rows) = wgsl_ir_matrix_size_from_name(name)
      self.intern_type(ty_ref.canonical_text(), Matrix(columns, rows, scalar))
    }
    "coop_mat8x8" | "coop_mat16x16" => {
      let (columns, rows, scalar, role) = self.required_cooperative_matrix_type(
        ty_ref,
      )
      self.intern_type(
        ty_ref.canonical_text(),
        CooperativeMatrix(columns, rows, scalar, role),
      )
    }
    "array" => {
      let args = ty_ref.template_arguments()
      guard args is [Type(element_ty), .. rest] else {
        raise UnsupportedType(ty_ref.canonical_text())
      }
      let element = self.lower_type_ref(element_ty)
      let size = match rest {
        [size_arg, ..] => self.lower_type_template_array_size(size_arg)
        _ => Dynamic
      }
      let layout = self.type_layout(element)
      let stride = wgsl_ir_align_to(layout.size, layout.align)
      self.intern_type(ty_ref.canonical_text(), Array(element, size, stride))
    }
    "ptr" => {
      let args = ty_ref.template_arguments()
      guard args is [Type(space_ref), Type(target_ref), .. rest] else {
        raise UnsupportedType(ty_ref.canonical_text())
      }
      let space = if space_ref.name() == "storage" {
        match rest {
          [Type(access_ref), ..] =>
            AddressSpace::Storage(
              wgsl_ir_storage_access_from_name(access_ref.name()),
            )
          _ => Storage(StorageAccess::load())
        }
      } else {
        wgsl_ir_address_space_from_type_name(space_ref.name())
      }
      self.intern_type(
        ty_ref.canonical_text(),
        Pointer(self.lower_type_ref(target_ref), space),
      )
    }
    "atomic" => {
      let scalar = self.required_scalar_type_argument(ty_ref)
      self.intern_type(ty_ref.canonical_text(), Atomic(scalar))
    }
    "sampler" => self.intern_type(name, Sampler(false))
    "sampler_comparison" => self.intern_type(name, Sampler(true))
    "acceleration_structure" =>
      self.intern_type(
        ty_ref.canonical_text(),
        AccelerationStructure(wgsl_ir_type_ref_uses_vertex_return(ty_ref)),
      )
    "ray_query" =>
      self.intern_type(
        ty_ref.canonical_text(),
        RayQuery(wgsl_ir_type_ref_uses_vertex_return(ty_ref)),
      )
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
        Image(
          wgsl_ir_image_dimension_from_name(name),
          name.contains("array"),
          Sampled(scalar.kind, name.contains("multisampled")),
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
        Image(
          wgsl_ir_image_dimension_from_name(name),
          name.contains("array"),
          Depth(name.contains("multisampled")),
        ),
      )
    "texture_external" => self.intern_type(name, Image(D2, false, External))
    "texture_storage_1d"
    | "texture_storage_2d"
    | "texture_storage_2d_array"
    | "texture_storage_3d" => {
      let args = ty_ref.template_arguments()
      guard args is [Type(format_ref), .. rest] else {
        raise UnsupportedType(ty_ref.canonical_text())
      }
      let access = match rest {
        [Type(access_ref), ..] =>
          wgsl_ir_storage_access_from_name(access_ref.name())
        _ => StorageAccess::load()
      }
      self.intern_type(
        ty_ref.canonical_text(),
        Image(
          wgsl_ir_image_dimension_from_name(name),
          name.contains("array"),
          Storage(wgsl_ir_storage_format_from_name(format_ref.name()), access),
        ),
      )
    }
    "binding_array" => {
      let args = ty_ref.template_arguments()
      guard args is [Type(element_ty), .. rest] else {
        raise UnsupportedType(ty_ref.canonical_text())
      }
      let size = match rest {
        [size_arg, ..] => self.lower_type_template_array_size(size_arg)
        _ => Dynamic
      }
      self.intern_type(
        ty_ref.canonical_text(),
        BindingArray(self.lower_type_ref(element_ty), size),
      )
    }
    _ =>
      raise UnsupportedType("\{ty_ref.canonical_text()} before \{ty_ref.end()}")
  }
}

///|
fn WgslIrLowerer::required_cooperative_matrix_type(
  self : WgslIrLowerer,
  ty_ref : @ast.WgslTypeRef,
) -> (CooperativeSize, CooperativeSize, Scalar, CooperativeRole) raise WgslIrLowerError {
  let (columns, rows) = match ty_ref.name() {
    "coop_mat8x8" => (CooperativeSize::Eight, CooperativeSize::Eight)
    "coop_mat16x16" => (Sixteen, Sixteen)
    _ => raise UnsupportedType(ty_ref.canonical_text())
  }
  match ty_ref.template_arguments() {
    [Type(scalar_ref), Type(role_ref)] =>
      (
        columns,
        rows,
        self.scalar_from_type_ref(scalar_ref),
        wgsl_ir_cooperative_role_from_name(role_ref.name()),
      )
    _ => raise UnsupportedType(ty_ref.canonical_text())
  }
}

///|
fn WgslIrLowerer::cooperative_matrix_type_handle(
  self : WgslIrLowerer,
  columns : CooperativeSize,
  rows : CooperativeSize,
  scalar : Scalar,
  role : CooperativeRole,
) -> Handle {
  let key = "coop_mat\{wgsl_ir_cooperative_size_name(columns)}x\{wgsl_ir_cooperative_size_name(rows)}<\{wgsl_ir_scalar_name(scalar.kind, scalar.width)}, \{wgsl_ir_cooperative_role_name(role)}>"
  self.intern_type(key, CooperativeMatrix(columns, rows, scalar, role))
}

///|
fn wgsl_ir_cooperative_role_from_name(
  name : String,
) -> CooperativeRole raise WgslIrLowerError {
  match name {
    "A" => A
    "B" => B
    "C" => C
    _ => raise UnsupportedType("unsupported cooperative matrix role: \{name}")
  }
}

///|
fn wgsl_ir_cooperative_role_name(role : CooperativeRole) -> String {
  match role {
    A => "A"
    B => "B"
    C => "C"
  }
}

///|
fn wgsl_ir_cooperative_size_name(size : CooperativeSize) -> String {
  match size {
    Eight => "8"
    Sixteen => "16"
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
        Some(value) => Constant(value)
        None => {
          let handle = self.lower_global_expression_ref(expr)
          self.lower_constant_array_size_expression(handle)
        }
      }
    Type(ty_ref) => self.lower_type_template_array_size_type_ref(ty_ref)
  }
}

///|
fn WgslIrLowerer::lower_function_type_template_array_size(
  self : WgslIrLowerer,
  argument : @ast.WgslTypeArgument,
  function : Function,
  scope : WgslIrFunctionScope,
) -> ArraySize raise WgslIrLowerError {
  match argument {
    Expression(expr) =>
      match wgsl_ir_int_literal_from_expr_ref(expr) {
        Some(value) => Constant(value)
        None => {
          let handle = self.lower_function_expression_ref(expr, function, scope)
          self.lower_function_constant_array_size_expression(function, handle)
        }
      }
    Type(ty_ref) =>
      self.lower_function_type_template_array_size_type_ref(
        ty_ref, function, scope,
      )
  }
}

///|
fn WgslIrLowerer::lower_function_type_template_array_size_type_ref(
  self : WgslIrLowerer,
  ty_ref : @ast.WgslTypeRef,
  function : Function,
  scope : WgslIrFunctionScope,
) -> ArraySize raise WgslIrLowerError {
  let name = ty_ref.name()
  let literal = wgsl_ir_array_size_literal_from_type_name(name)
  match literal {
    Some(value) => Constant(value)
    None =>
      match scope.local_constants.get(name) {
        Some({ value: LazyConstant(local_constant), .. }) => {
          let handle = match local_constant.normalized {
            Some(normalized) =>
              function.expressions.append_with_origin(
                normalized.expression,
                normalized.origin,
              )
            None =>
              self.lower_function_expression_ref_with_expected(
                local_constant.expr_ref,
                function,
                scope,
                local_constant.explicit_ty,
              )
          }
          match scope.local_constants.get(name) {
            Some(cell) =>
              cell.value = ExpressionAlias(handle, Some(local_constant))
            None => ()
          }
          self.lower_function_constant_array_size_expression(function, handle)
        }
        Some({ value: ExpressionAlias(handle, _), .. }) =>
          self.lower_function_constant_array_size_expression(function, handle)
        None => self.lower_type_template_array_size_type_ref(ty_ref)
      }
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
    Some(value) => Constant(value)
    None =>
      match self.ensure_constant_declaration_lowered(name) {
        Some(handle) =>
          self.lower_constant_array_size_from_constant_handle(handle)
        None =>
          match self.ensure_override_declaration_predeclared(name) {
            Some(handle) =>
              Pending(
                self.shader_module.append_global_expression(Override(handle)),
              )
            None => Dynamic
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
    None => raise UnsupportedType("array size references missing constant")
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
    Some(value) => Constant(value.to_non_negative_int())
    None => Pending(handle)
  }
}

///|
fn wgsl_ir_array_size_key(size : ArraySize) -> String {
  match size {
    Constant(value) => "\{value}"
    Dynamic => ""
    Pending(handle) => "expr#\{handle.index()}"
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
fn wgsl_ir_type_ref_uses_vertex_return(ty_ref : @ast.WgslTypeRef) -> Bool {
  for argument in ty_ref.template_arguments() {
    match argument {
      Type(type_arg) if type_arg.name() == "vertex_return" => return true
      _ => ()
    }
  }
  false
}

///|
fn WgslIrLowerer::required_scalar_type_argument(
  self : WgslIrLowerer,
  ty_ref : @ast.WgslTypeRef,
) -> Scalar raise WgslIrLowerError {
  match ty_ref.template_arguments() {
    [Type(arg), ..] => self.scalar_from_type_ref(arg)
    _ => raise UnsupportedType(ty_ref.canonical_text())
  }
}

///|
fn WgslIrLowerer::scalar_from_type_ref(
  self : WgslIrLowerer,
  ty_ref : @ast.WgslTypeRef,
) -> Scalar raise WgslIrLowerError {
  match ty_ref.name() {
    "bool" => Scalar(Bool, 1)
    "i32" => Scalar(Sint, 4)
    "i64" => Scalar(Sint, 8)
    "u32" => Scalar(Uint, 4)
    "u64" => Scalar(Uint, 8)
    "f32" => Scalar(Float, 4)
    "f16" => Scalar(Float, 2)
    _ => {
      let handle = self.lower_type_ref(ty_ref)
      match self.shader_module.types.get(handle) {
        Some(ty) =>
          match ty.inner {
            Scalar(scalar) => scalar
            _ => raise UnsupportedType(ty_ref.canonical_text())
          }
        None => raise UnsupportedType(ty_ref.canonical_text())
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
            Identifier,
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
          raise UnsupportedExpression(
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
      let scalar = self.constructor_scalar_from_ast_arguments(
        arguments, diagnostic_name,
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
fn WgslIrLowerer::infer_array_constructor_type_from_ast(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  diagnostic_name : String,
) -> Handle raise WgslIrLowerError {
  let flattened = wgsl_ir_flatten_expression_arguments(arguments)
  guard flattened is [first, ..] else { raise MissingType(diagnostic_name) }
  let element_ty = self.infer_expression_type(first, diagnostic_name)
  self.intern_inferred_array_type(element_ty, flattened.length())
}

///|
fn WgslIrLowerer::constructor_scalar_from_ast_arguments(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  diagnostic_name : String,
) -> Scalar raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments is [first, .. rest] else {
    raise MissingType(diagnostic_name)
  }
  let first_ty = self.infer_expression_type(first, diagnostic_name)
  let mut scalar = self.scalar_from_type_handle(first_ty, diagnostic_name)
  for argument in rest {
    let ty = self.infer_expression_type(argument, diagnostic_name)
    let next = self.scalar_from_type_handle(ty, diagnostic_name)
    scalar = self.merge_constructor_scalar(scalar, next, diagnostic_name)
  }
  scalar
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
      let scalar = self.constructor_scalar_from_handles(
        lowered_arguments, function, name,
      )
      let (columns, rows) = wgsl_ir_matrix_size_from_name(name)
      self.intern_type(
        "\{name}<\{wgsl_ir_scalar_name(scalar.kind, scalar.width)}>",
        Matrix(columns, rows, scalar),
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
    raise MissingType(diagnostic_name)
  }
  guard self.function_expression_type(function, first) is Some(element_ty) else {
    raise MissingType(diagnostic_name)
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
  guard lowered_arguments is [first, .. rest] else {
    raise MissingType(diagnostic_name)
  }
  guard self.function_expression_type(function, first) is Some(ty) else {
    raise MissingType(diagnostic_name)
  }
  let mut scalar = self.scalar_from_type_handle(ty, diagnostic_name)
  for argument in rest {
    guard self.function_expression_type(function, argument) is Some(ty) else {
      raise MissingType(diagnostic_name)
    }
    let next = self.scalar_from_type_handle(ty, diagnostic_name)
    scalar = self.merge_constructor_scalar(scalar, next, diagnostic_name)
  }
  scalar
}

///|
fn WgslIrLowerer::merge_constructor_scalar(
  self : WgslIrLowerer,
  left : Scalar,
  right : Scalar,
  diagnostic_name : String,
) -> Scalar raise WgslIrLowerError {
  ignore(self)
  if !wgsl_ir_scalar_kind_is_abstract(left.kind) &&
    !wgsl_ir_scalar_kind_is_abstract(right.kind) {
    if left == right {
      return left
    }
    raise UnsupportedType(diagnostic_name)
  }
  if !wgsl_ir_scalar_kind_is_abstract(left.kind) {
    if wgsl_ir_abstract_scalar_can_convert_to(right.kind, left.kind) {
      return left
    }
    raise UnsupportedType(diagnostic_name)
  }
  if !wgsl_ir_scalar_kind_is_abstract(right.kind) {
    if wgsl_ir_abstract_scalar_can_convert_to(left.kind, right.kind) {
      return right
    }
    raise UnsupportedType(diagnostic_name)
  }
  match (left.kind, right.kind) {
    (AbstractFloat, _) | (_, AbstractFloat) => Scalar(AbstractFloat, 8)
    _ => left
  }
}

///|
fn wgsl_ir_abstract_scalar_can_convert_to(
  from : ScalarKind,
  to : ScalarKind,
) -> Bool {
  match (from, to) {
    (AbstractInt, Sint | Uint | Float | AbstractInt | AbstractFloat) => true
    (AbstractFloat, Float | AbstractFloat) => true
    _ => false
  }
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
    Array(element_ty, Constant(length), stride),
  )
}

///|
fn WgslIrLowerer::local_declaration_storage_type(
  self : WgslIrLowerer,
  kind : @ast.WgslLocalDeclarationKind,
  ty : Handle,
) -> Handle raise WgslIrLowerError {
  match kind {
    Var | Let => self.concretize_abstract_storage_type(ty)
    Const => ty
  }
}

///|
fn WgslIrLowerer::concretize_abstract_storage_type(
  self : WgslIrLowerer,
  ty : Handle,
) -> Handle raise WgslIrLowerError {
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
                Matrix(columns, rows, concrete),
              )
            None => ty
          }
        Array(element, size, _) => {
          let concrete_element = self.concretize_abstract_storage_type(element)
          if concrete_element == element {
            ty
          } else {
            let layout = self.type_layout(concrete_element)
            let stride = wgsl_ir_align_to(layout.size, layout.align)
            self.intern_type(
              "array<\{self.type_key(concrete_element)}, \{wgsl_ir_array_size_key(size)}>",
              Array(concrete_element, size, stride),
            )
          }
        }
        BindingArray(element, size) => {
          let concrete_element = self.concretize_abstract_storage_type(element)
          if concrete_element == element {
            ty
          } else {
            self.intern_type(
              "binding_array<\{self.type_key(concrete_element)}, \{wgsl_ir_array_size_key(size)}>",
              BindingArray(concrete_element, size),
            )
          }
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
    AbstractInt => Some(Scalar(Sint, 4))
    AbstractFloat => Some(Scalar(Float, 4))
    _ => None
  }
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
    None => raise MissingType("type handle")
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
        _ => raise MissingType(diagnostic_name)
      }
    None => raise MissingType(diagnostic_name)
  }
}

///|
priv struct WgslIrLayout {
  align : Int
  size : Int
}
