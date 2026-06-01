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
    Component(base, _) =>
      match self.global_expression_type(base) {
        Some(ty) => self.indexed_type_from_type_handle(ty, Some(0))
        None => None
      }
    Access(base, _) =>
      match self.global_expression_type(base) {
        Some(ty) => self.indexed_type_from_type_handle(ty, None)
        None => None
      }
    Splat(size, inner) =>
      match self.global_expression_type(inner) {
        Some(ty) => self.vector_type_from_scalar_type_handle(size, ty)
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
    Math(math_function, a, b, c, d) =>
      self.math_expression_result_type(
        Function::Function(None),
        math_function,
        a,
        b,
        c,
        d,
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
      match
        self.shader_module.types.get(self.deref_pointer_type_handle(ty_handle)) {
        Some(ty) =>
          match ty.inner {
            Vector(_, _) =>
              match wgsl_ir_swizzle_components(member_name) {
                Some(components) => {
                  let value_base = self.apply_function_load_rule(
                    function, base_handle,
                  )
                  if components.length() == 1 {
                    function.expressions.append(
                      Expression::AccessIndex(
                        value_base,
                        wgsl_ir_gather_component_index(components[0]),
                      ),
                    )
                  } else {
                    function.expressions.append(
                      Expression::Swizzle(
                        wgsl_ir_vector_size_from_component_count(
                          components.length(),
                        ),
                        value_base,
                        components,
                      ),
                    )
                  }
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
fn WgslIrLowerer::apply_function_load_rule(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle,
) -> Handle {
  if self.function_expression_is_reference(function, handle) {
    function.expressions.append(Expression::Load(handle))
  } else {
    handle
  }
}

///|
fn WgslIrLowerer::function_expression_is_reference(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle,
) -> Bool {
  match function.expressions.items.get(handle.index()) {
    Some(expression) =>
      match expression {
        FunctionArgument(index) =>
          self.function_argument_is_pointer(function, index)
        LocalVariable(local_handle) =>
          match function.local_variables.items.get(local_handle.index()) {
            Some(local_variable) => local_variable.kind == Var
            None => false
          }
        GlobalVariable(global_handle) =>
          !self.global_variable_is_handle_value(global_handle)
        Access(base, _) | AccessIndex(base, _) | Swizzle(_, base, _) =>
          self.function_expression_is_reference(function, base) ||
          self.function_expression_has_pointer_type(function, base)
        Load(_) | AddressOf(_, _) => false
        _ => false
      }
    None => false
  }
}

///|
fn WgslIrLowerer::function_expression_has_pointer_type(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle,
) -> Bool {
  match self.function_expression_type(function, handle) {
    Some(ty) => self.lowerer_type_is_pointer(ty)
    None => false
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
    Component(base, _) => self.indexed_expression_type(function, base, Some(0))
    Access(base, _) => self.indexed_expression_type(function, base, None)
    Splat(size, inner) =>
      match self.function_expression_type(function, inner) {
        Some(ty) => self.vector_type_from_scalar_type_handle(size, ty)
        None => None
      }
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
    FunctionCall(handle, _) | CallResult(handle) =>
      match self.shader_module.functions.items.get(handle.index()) {
        Some(callee) =>
          match callee.result {
            Some(result) => Some(result.ty)
            None => None
          }
        None => None
      }
    Derivative(_, _, expr) => self.function_expression_type(function, expr)
    Math(math_function, a, b, c, d) =>
      self.math_expression_result_type(function, math_function, a, b, c, d)
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
  b : Handle?,
  c : Handle?,
  d : Handle?,
) -> Handle? {
  guard self.function_expression_type(function, argument) is Some(input_ty) else {
    return None
  }
  match math_function {
    Modf => return self.predeclared_modf_result_type(input_ty)
    Frexp => return self.predeclared_frexp_result_type(input_ty)
    Pack4x8snorm
    | Pack4x8unorm
    | Pack2x16snorm
    | Pack2x16unorm
    | Pack2x16float
    | Pack4xI8
    | Pack4xU8
    | Pack4xI8Clamp
    | Pack4xU8Clamp
    | Dot4U8Packed =>
      return Some(self.scalar_type_handle(Scalar::Scalar(Uint, 4)))
    Dot4I8Packed =>
      return Some(self.scalar_type_handle(Scalar::Scalar(Sint, 4)))
    Unpack4x8snorm | Unpack4x8unorm =>
      return Some(self.vector_type_handle(Quad, Scalar::Scalar(Float, 4)))
    Unpack2x16snorm | Unpack2x16unorm | Unpack2x16float =>
      return Some(self.vector_type_handle(Bi, Scalar::Scalar(Float, 4)))
    Unpack4xI8 =>
      return Some(self.vector_type_handle(Quad, Scalar::Scalar(Sint, 4)))
    Unpack4xU8 =>
      return Some(self.vector_type_handle(Quad, Scalar::Scalar(Uint, 4)))
    Dot | Distance | Length | Determinant =>
      return Some(self.scalar_type_from_composite_type(input_ty))
    _ => ()
  }
  if wgsl_ir_math_function_uses_uniform_numeric_argument_context(math_function) {
    let arguments : Array[Handle] = [argument]
    match b {
      Some(value) => arguments.push(value)
      None => ()
    }
    match c {
      Some(value) => arguments.push(value)
      None => ()
    }
    match d {
      Some(value) => arguments.push(value)
      None => ()
    }
    for value in arguments {
      match self.function_expression_type(function, value) {
        Some(ty) =>
          match self.scalar_from_numeric_type_handle(ty) {
            Some(scalar) if !wgsl_ir_scalar_kind_is_abstract(scalar.kind) =>
              return Some(ty)
            _ => ()
          }
        None => ()
      }
    }
  }
  match math_function {
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
fn WgslIrLowerer::vector_type_from_scalar_type_handle(
  self : WgslIrLowerer,
  size : VectorSize,
  ty : Handle,
) -> Handle? {
  match self.shader_module.types.get(ty) {
    Some({ inner: Scalar(scalar), .. }) =>
      Some(self.vector_type_handle(size, scalar))
    _ => None
  }
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
fn WgslIrLowerer::type_is_vector(
  self : WgslIrLowerer,
  ty_handle : Handle,
  size : VectorSize,
  scalar : Scalar,
) -> Bool {
  match self.shader_module.types.get(ty_handle) {
    Some(type_) =>
      match type_.inner {
        Vector(existing_size, existing_scalar) =>
          existing_size == size && existing_scalar == scalar
        _ => false
      }
    None => false
  }
}

///|
fn WgslIrLowerer::identity_vector_constructor_argument(
  self : WgslIrLowerer,
  ty : Handle,
  arguments : Array[Handle],
  function : Function,
) -> Handle? {
  guard arguments.length() == 1 else { return None }
  guard self.shader_module.types.get(ty) is Some(type_) else { return None }
  match type_.inner {
    Vector(size, scalar) =>
      match self.function_expression_type(function, arguments[0]) {
        Some(argument_ty) =>
          if self.type_is_vector(argument_ty, size, scalar) {
            Some(arguments[0])
          } else {
            None
          }
        None => None
      }
    _ => None
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
