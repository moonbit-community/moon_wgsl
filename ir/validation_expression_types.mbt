///|
fn WgslIrValidator::function_expression_type(
  self : WgslIrValidator,
  function : Function,
  handle : Handle,
) -> Handle? {
  match wgsl_ir_function_named_expression_type(function, handle) {
    Some(ty) => return Some(ty)
    None => ()
  }
  match function.expressions.items.get(handle.index()) {
    Some(expression) =>
      self.function_expression_inner_type(function, expression)
    None => None
  }
}

///|
fn WgslIrValidator::store_target_value_type(
  self : WgslIrValidator,
  function : Function,
  handle : Handle,
) -> Handle? {
  match function.expressions.items.get(handle.index()) {
    Some(expression) =>
      match expression {
        FunctionArgument(_) =>
          match self.function_expression_inner_type(function, expression) {
            Some(ty) =>
              if self.type_is_pointer_like(ty) &&
                self.pointer_type_is_writable(ty) {
                self.deref_type(ty)
              } else {
                None
              }
            None => None
          }
        LocalVariable(local_handle) =>
          match function.local_variables.items.get(local_handle.index()) {
            Some(local_variable) =>
              if self.type_is_pointer_like(local_variable.ty) &&
                self.pointer_type_is_writable(local_variable.ty) {
                self.deref_type(local_variable.ty)
              } else {
                match local_variable.kind {
                  Var => Some(local_variable.ty)
                  Let => None
                }
              }
            None => None
          }
        GlobalVariable(global) =>
          match self.shader_module.global_variables.items.get(global.index()) {
            Some(variable) =>
              if self.global_address_space_is_writable(variable.space) {
                Some(variable.ty)
              } else {
                None
              }
            None => None
          }
        Load(inner) =>
          match self.function_expression_type(function, inner) {
            Some(ty) =>
              if self.type_is_pointer_like(ty) &&
                self.pointer_type_is_writable(ty) {
                self.deref_type(ty)
              } else {
                None
              }
            None => None
          }
        Access(_, _) | AccessIndex(_, _) | Component(_, _) | Swizzle(_, _, _) =>
          if self.expression_is_addressable(function, handle) {
            self.function_expression_inner_type(function, expression)
          } else {
            None
          }
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrValidator::function_expression_value_type(
  self : WgslIrValidator,
  function : Function,
  handle : Handle,
) -> Handle? {
  match function.expressions.items.get(handle.index()) {
    Some(expression) =>
      match expression {
        FunctionArgument(_) =>
          match self.function_expression_inner_type(function, expression) {
            Some(ty) =>
              if self.type_is_pointer_like(ty) {
                self.deref_type(ty)
              } else {
                None
              }
            None => None
          }
        LocalVariable(local_handle) =>
          match function.local_variables.items.get(local_handle.index()) {
            Some(local_variable) =>
              if local_variable.kind == Var ||
                self.type_is_pointer_like(local_variable.ty) {
                Some(local_variable.ty)
              } else {
                None
              }
            None => None
          }
        GlobalVariable(global) =>
          match self.shader_module.global_variables.items.get(global.index()) {
            Some(variable) => Some(variable.ty)
            None => None
          }
        Load(inner) =>
          match self.function_expression_type(function, inner) {
            Some(ty) =>
              if self.type_is_pointer_like(ty) {
                self.deref_type(ty)
              } else {
                None
              }
            None => None
          }
        Access(_, _) | AccessIndex(_, _) | Component(_, _) | Swizzle(_, _, _) =>
          if self.expression_is_addressable(function, handle) {
            self.function_expression_inner_type(function, expression)
          } else {
            None
          }
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrValidator::function_expression_inner_type(
  self : WgslIrValidator,
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
        Some(ty) => self.deref_type(ty)
        None => None
      }
    AddressOf(ty, _) => Some(ty)
    Compose(ty, _) | ZeroValue(ty) | Bitcast(ty, _) => Some(ty)
    AccessIndex(base, index) =>
      match self.function_expression_type(function, base) {
        Some(base_ty) => self.indexed_type(base_ty, Some(index))
        None => None
      }
    Component(base, _) =>
      match self.function_expression_type(function, base) {
        Some(base_ty) => self.indexed_type(base_ty, Some(0))
        None => None
      }
    Access(base, _) =>
      match self.function_expression_type(function, base) {
        Some(base_ty) => self.indexed_type(base_ty, None)
        None => None
      }
    Splat(size, inner) =>
      match self.function_expression_type(function, inner) {
        Some(ty) => self.vector_type_from_scalar_type(size, ty)
        None => None
      }
    Swizzle(size, base, _) =>
      match self.function_expression_type(function, base) {
        Some(ty) => self.vector_or_scalar_swizzle_type(size, ty)
        None => None
      }
    Unary(_, inner) => self.function_expression_type(function, inner)
    Binary(op, left, right) =>
      self.binary_result_type(
        op,
        self.function_expression_type(function, left),
        self.function_expression_type(function, right),
      )
    FunctionCall(handle, _) | CallResult(handle) =>
      self.function_result_type(handle)
    Select(_, accept, reject) =>
      match self.function_expression_type(function, accept) {
        Some(ty) => Some(ty)
        None => self.function_expression_type(function, reject)
      }
    Derivative(_, _, expr) => self.function_expression_type(function, expr)
    Relational(relational_function, expr) =>
      self.relational_result_type(
        relational_function,
        self.function_expression_type(function, expr),
      )
    Math(math_function, a, _, _, _) =>
      self.math_result_type(
        math_function,
        self.function_expression_type(function, a),
      )
    AtomicCall(atomic_function, arguments) =>
      self.atomic_result_type(function, atomic_function, arguments)
    ImageSample(image, _, gather, _, _, _, _, depth_ref, _) =>
      self.image_result_type(function, image, gather, depth_ref)
    ImageLoad(image, _, _, _, _) =>
      self.image_result_type(function, image, None, None)
    ImageQuery(image, query) =>
      self.image_query_result_type(function, image, query)
    ArrayLength(_) => self.find_scalar_type(Scalar::Scalar(Uint, 4))
    WorkGroupUniformLoad(pointer) | WorkGroupUniformLoadResult(pointer) =>
      match self.function_expression_type(function, pointer) {
        Some(ty) => self.deref_type(ty)
        None => None
      }
    AtomicResult(ty, _) => Some(ty)
    RayQueryProceedResult => self.find_scalar_type(Scalar::Scalar(Bool, 1))
    SubgroupBallotResult => self.vector_type(Quad, Scalar::Scalar(Uint, 4))
    SubgroupOperationResult(handle) =>
      self.function_expression_type(function, handle)
    SubgroupCall(subgroup_function, arguments) =>
      self.subgroup_result_type(function, subgroup_function, arguments)
    CooperativeLoad(columns, rows, role, data) =>
      match self.cooperative_data_scalar(function, data) {
        Some(scalar) =>
          self.cooperative_matrix_type(columns, rows, scalar, role)
        None => None
      }
    CooperativeMultiplyAdd(_, _, c) =>
      self.function_expression_type(function, c)
    Literal(literal) => self.literal_type(literal)
    As(expr, kind, width) =>
      self.as_result_type(
        self.function_expression_type(function, expr),
        kind,
        width.unwrap_or(4),
      )
    RayQueryGetIntersection(_, _) => self.find_type_by_name("RayIntersection")
    RayQueryVertexPositions(_, _) =>
      self.shader_module.special_types.ray_vertex_return
    RayQueryProceed(_) => self.find_scalar_type(Scalar::Scalar(Bool, 1))
    RayQueryInitialize(_, _, _)
    | RayQueryGenerateIntersection(_, _)
    | RayQueryConfirmIntersection(_)
    | RayQueryTerminate(_) => None
  }
}

///|
fn WgslIrValidator::global_expression_type(
  self : WgslIrValidator,
  handle : Handle,
) -> Handle? {
  match self.shader_module.global_expressions.items.get(handle.index()) {
    Some(expression) => self.global_expression_inner_type(expression)
    None => None
  }
}

///|
fn WgslIrValidator::global_expression_inner_type(
  self : WgslIrValidator,
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
    Load(inner) =>
      match self.global_expression_type(inner) {
        Some(ty) => self.deref_type(ty)
        None => None
      }
    AddressOf(ty, _) => Some(ty)
    Compose(ty, _) | ZeroValue(ty) | Bitcast(ty, _) => Some(ty)
    AccessIndex(base, index) =>
      match self.global_expression_type(base) {
        Some(base_ty) => self.indexed_type(base_ty, Some(index))
        None => None
      }
    Component(base, _) =>
      match self.global_expression_type(base) {
        Some(base_ty) => self.indexed_type(base_ty, Some(0))
        None => None
      }
    Access(base, _) =>
      match self.global_expression_type(base) {
        Some(base_ty) => self.indexed_type(base_ty, None)
        None => None
      }
    Unary(_, inner) => self.global_expression_type(inner)
    Binary(op, left, right) =>
      self.binary_result_type(
        op,
        self.global_expression_type(left),
        self.global_expression_type(right),
      )
    FunctionCall(handle, _) => self.function_result_type(handle)
    Select(_, accept, reject) =>
      match self.global_expression_type(accept) {
        Some(ty) => Some(ty)
        None => self.global_expression_type(reject)
      }
    Relational(relational_function, expr) =>
      self.relational_result_type(
        relational_function,
        self.global_expression_type(expr),
      )
    Literal(literal) => self.literal_type(literal)
    As(expr, kind, width) =>
      self.as_result_type(
        self.global_expression_type(expr),
        kind,
        width.unwrap_or(4),
      )
    _ => None
  }
}

///|
fn WgslIrValidator::function_result_type(
  self : WgslIrValidator,
  handle : Handle,
) -> Handle? {
  match self.shader_module.functions.items.get(handle.index()) {
    Some(function) =>
      match function.result {
        Some(result) => Some(result.ty)
        None => None
      }
    None => None
  }
}

///|
fn WgslIrValidator::literal_type(
  self : WgslIrValidator,
  literal : Literal,
) -> Handle? {
  match literal {
    Bool(_) => self.find_scalar_type(Scalar::Scalar(Bool, 1))
    I32(_) => self.find_scalar_type(Scalar::Scalar(Sint, 4))
    U32(_) => self.find_scalar_type(Scalar::Scalar(Uint, 4))
    I64(_) => self.find_scalar_type(Scalar::Scalar(Sint, 8))
    U64(_) => self.find_scalar_type(Scalar::Scalar(Uint, 8))
    I16(_) => self.find_scalar_type(Scalar::Scalar(Sint, 2))
    U16(_) => self.find_scalar_type(Scalar::Scalar(Uint, 2))
    F16(_) => self.find_scalar_type(Scalar::Scalar(Float, 2))
    F32(_) => self.find_scalar_type(Scalar::Scalar(Float, 4))
    F64(_) => self.find_scalar_type(Scalar::Scalar(Float, 8))
    AbstractInt(_) => self.find_scalar_type(Scalar::Scalar(AbstractInt, 8))
    AbstractFloat(_) => self.find_scalar_type(Scalar::Scalar(AbstractFloat, 8))
  }
}

///|
fn WgslIrValidator::indexed_type(
  self : WgslIrValidator,
  ty : Handle,
  index : Int?,
) -> Handle? {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Struct(members, _) | PredeclaredStruct(members, _) =>
          match index {
            Some(i) =>
              match members.get(i) {
                Some(struct_member) => Some(struct_member.ty)
                None => None
              }
            None => None
          }
        Vector(size, scalar) =>
          if self.constant_index_is_in_bounds(index, size.width()) {
            self.find_scalar_type(scalar)
          } else {
            None
          }
        Matrix(columns, rows, scalar) =>
          if self.constant_index_is_in_bounds(index, columns.width()) {
            self.vector_type(rows, scalar)
          } else {
            None
          }
        Array(element, size, _) | BindingArray(element, size) =>
          if self.array_index_is_in_bounds(index, size) {
            Some(element)
          } else {
            None
          }
        Pointer(base, _) => self.indexed_type(base, index)
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrValidator::dynamic_indexed_type(
  self : WgslIrValidator,
  ty : Handle,
) -> Handle? {
  self.indexed_type(ty, None)
}

///|
fn WgslIrValidator::constant_index_is_in_bounds(
  self : WgslIrValidator,
  index : Int?,
  count : Int,
) -> Bool {
  ignore(self)
  match index {
    Some(value) => value >= 0 && value < count
    None => true
  }
}

///|
fn WgslIrValidator::array_index_is_in_bounds(
  self : WgslIrValidator,
  index : Int?,
  size : ArraySize,
) -> Bool {
  ignore(self)
  match (index, size) {
    (Some(value), Constant(count)) => value >= 0 && value < count
    (Some(value), _) => value >= 0
    (None, _) => true
  }
}

///|
fn WgslIrValidator::pointer_pointee_type(
  self : WgslIrValidator,
  ty : Handle,
) -> Handle? {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Pointer(base, _) => Some(base)
        ValuePointer(size, scalar, _) =>
          match size {
            Some(vector_size) => self.vector_type(vector_size, scalar)
            None => self.find_scalar_type(scalar)
          }
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrValidator::pointer_address_space(
  self : WgslIrValidator,
  ty : Handle,
) -> AddressSpace? {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Pointer(_, space) | ValuePointer(_, _, space) => Some(space)
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrValidator::pointer_type_is_writable(
  self : WgslIrValidator,
  ty : Handle,
) -> Bool {
  match self.pointer_address_space(ty) {
    Some(space) => self.global_address_space_is_writable(space)
    None => false
  }
}

///|
fn WgslIrValidator::global_address_space_is_writable(
  self : WgslIrValidator,
  space : AddressSpace,
) -> Bool {
  ignore(self)
  match space {
    Function | Private | WorkGroup | TaskPayload | RayPayload => true
    Storage(access) =>
      access.contains(StorageAccess::store()) ||
      access.contains(StorageAccess::atomic_access())
    _ => false
  }
}

///|
fn WgslIrValidator::expression_is_addressable(
  self : WgslIrValidator,
  function : Function,
  handle : Handle,
) -> Bool {
  match function.expressions.items.get(handle.index()) {
    Some(expression) =>
      match expression {
        FunctionArgument(_) =>
          match self.function_expression_inner_type(function, expression) {
            Some(ty) => self.type_is_pointer_like(ty)
            None => false
          }
        LocalVariable(local_handle) =>
          match function.local_variables.items.get(local_handle.index()) {
            Some(local_variable) =>
              local_variable.kind == Var ||
              self.type_is_pointer_like(local_variable.ty)
            None => false
          }
        GlobalVariable(global) =>
          self.shader_module.global_variables.items.get(global.index()) != None
        Load(inner) =>
          match self.function_expression_type(function, inner) {
            Some(ty) => self.type_is_pointer_like(ty)
            None => false
          }
        Access(base, _)
        | AccessIndex(base, _)
        | Component(base, _)
        | Swizzle(_, base, _) => self.expression_is_addressable(function, base)
        _ => false
      }
    None => false
  }
}

///|
fn WgslIrValidator::global_expression_is_addressable(
  self : WgslIrValidator,
  handle : Handle,
) -> Bool {
  match self.shader_module.global_expressions.items.get(handle.index()) {
    Some(expression) =>
      match expression {
        GlobalVariable(global) =>
          self.shader_module.global_variables.items.get(global.index()) != None
        Load(inner) =>
          match self.global_expression_type(inner) {
            Some(ty) => self.type_is_pointer_like(ty)
            None => false
          }
        Access(base, _) | AccessIndex(base, _) | Component(base, _) =>
          self.global_expression_is_addressable(base)
        _ => false
      }
    None => false
  }
}

///|
fn WgslIrValidator::global_expression_value_type(
  self : WgslIrValidator,
  handle : Handle,
) -> Handle? {
  match self.shader_module.global_expressions.items.get(handle.index()) {
    Some(expression) =>
      match expression {
        GlobalVariable(global) =>
          match self.shader_module.global_variables.items.get(global.index()) {
            Some(variable) => Some(variable.ty)
            None => None
          }
        Load(inner) =>
          match self.global_expression_type(inner) {
            Some(ty) => self.deref_type(ty)
            None => None
          }
        Access(_, _) | AccessIndex(_, _) | Component(_, _) =>
          self.global_expression_inner_type(expression)
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrValidator::deref_type(self : WgslIrValidator, ty : Handle) -> Handle? {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Pointer(base, _) => self.deref_type(base)
        ValuePointer(size, scalar, _) =>
          match size {
            Some(vector_size) => self.vector_type(vector_size, scalar)
            None => self.find_scalar_type(scalar)
          }
        _ => Some(ty)
      }
    None => None
  }
}

///|
fn WgslIrValidator::vector_type_from_scalar_type(
  self : WgslIrValidator,
  size : VectorSize,
  ty : Handle,
) -> Handle? {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Scalar(scalar) => self.vector_type(size, scalar)
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrValidator::vector_or_scalar_swizzle_type(
  self : WgslIrValidator,
  size : VectorSize,
  ty : Handle,
) -> Handle? {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Vector(_, scalar) => self.vector_type(size, scalar)
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrValidator::binary_result_type(
  self : WgslIrValidator,
  op : BinaryOperator,
  left : Handle?,
  right : Handle?,
) -> Handle? {
  if wgsl_ir_validation_binary_operator_is_comparison(op) {
    return self.boolean_result_type(left, right)
  }
  match (left, right) {
    (Some(left_ty), Some(right_ty)) =>
      if op == BinaryOperator::Multiply {
        match self.matrix_vector_multiply_result_type(left_ty, right_ty) {
          Some(ty) => Some(ty)
          None => self.numeric_binary_fallback_type(left_ty, right_ty)
        }
      } else {
        self.numeric_binary_fallback_type(left_ty, right_ty)
      }
    (Some(ty), None) | (None, Some(ty)) => Some(ty)
    (None, None) => None
  }
}

///|
fn WgslIrValidator::numeric_binary_fallback_type(
  self : WgslIrValidator,
  left : Handle,
  right : Handle,
) -> Handle? {
  if self.type_is_scalar(left) && !self.type_is_scalar(right) {
    return Some(right)
  }
  if !self.type_is_scalar(left) && self.type_is_scalar(right) {
    return Some(left)
  }
  Some(left)
}

///|
fn WgslIrValidator::matrix_vector_multiply_result_type(
  self : WgslIrValidator,
  left : Handle,
  right : Handle,
) -> Handle? {
  match self.shader_module.types.get(left) {
    Some(left_type) =>
      match left_type.inner {
        Matrix(left_columns, rows, scalar) =>
          match self.shader_module.types.get(right) {
            Some(right_type) =>
              match right_type.inner {
                Vector(_, _) => self.vector_type(rows, scalar)
                Matrix(columns, right_rows, _) =>
                  if right_rows == left_columns {
                    self.matrix_type(columns, rows, scalar)
                  } else {
                    None
                  }
                _ => None
              }
            None => None
          }
        Vector(_, scalar) =>
          match self.shader_module.types.get(right) {
            Some(right_type) =>
              match right_type.inner {
                Matrix(columns, _, _) => self.vector_type(columns, scalar)
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
fn WgslIrValidator::boolean_result_type(
  self : WgslIrValidator,
  left : Handle?,
  right : Handle?,
) -> Handle? {
  match left {
    Some(ty) =>
      match self.vector_size(ty) {
        Some(size) => return self.vector_type(size, Scalar::Scalar(Bool, 1))
        None => ()
      }
    None => ()
  }
  match right {
    Some(ty) =>
      match self.vector_size(ty) {
        Some(size) => self.vector_type(size, Scalar::Scalar(Bool, 1))
        None => self.find_scalar_type(Scalar::Scalar(Bool, 1))
      }
    None => self.find_scalar_type(Scalar::Scalar(Bool, 1))
  }
}

///|
fn WgslIrValidator::relational_result_type(
  self : WgslIrValidator,
  relational_function : RelationalFunction,
  input : Handle?,
) -> Handle? {
  match relational_function {
    All | Any => self.find_scalar_type(Scalar::Scalar(Bool, 1))
    IsNan | IsInf => self.boolean_result_type(input, input)
  }
}

///|
fn WgslIrValidator::math_result_type(
  self : WgslIrValidator,
  math_function : MathFunction,
  input : Handle?,
) -> Handle? {
  guard input is Some(input_ty) else { return None }
  match math_function {
    Modf => self.predeclared_numeric_result_type(input_ty, false)
    Frexp => self.predeclared_numeric_result_type(input_ty, true)
    Pack4x8snorm
    | Pack4x8unorm
    | Pack2x16snorm
    | Pack2x16unorm
    | Pack2x16float
    | Pack4xI8
    | Pack4xU8
    | Pack4xI8Clamp
    | Pack4xU8Clamp
    | Dot4U8Packed => self.find_scalar_type(Scalar::Scalar(Uint, 4))
    Dot4I8Packed => self.find_scalar_type(Scalar::Scalar(Sint, 4))
    Unpack4x8snorm | Unpack4x8unorm =>
      self.vector_type(Quad, Scalar::Scalar(Float, 4))
    Unpack2x16snorm | Unpack2x16unorm | Unpack2x16float =>
      self.vector_type(Bi, Scalar::Scalar(Float, 4))
    Unpack4xI8 => self.vector_type(Quad, Scalar::Scalar(Sint, 4))
    Unpack4xU8 => self.vector_type(Quad, Scalar::Scalar(Uint, 4))
    Dot | Distance | Length | Determinant =>
      self.scalar_type_from_type(input_ty)
    Transpose => self.transpose_type(input_ty)
    _ => Some(input_ty)
  }
}

///|
fn WgslIrValidator::predeclared_numeric_result_type(
  self : WgslIrValidator,
  input_ty : Handle,
  frexp : Bool,
) -> Handle? {
  match self.shader_module.types.get(input_ty) {
    Some(type_) =>
      match type_.inner {
        Scalar(scalar) =>
          if frexp {
            self.predeclared_type_handle(FrexpResult(None, scalar))
          } else {
            self.predeclared_type_handle(ModfResult(None, scalar))
          }
        Vector(size, scalar) =>
          if frexp {
            self.predeclared_type_handle(FrexpResult(Some(size), scalar))
          } else {
            self.predeclared_type_handle(ModfResult(Some(size), scalar))
          }
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrValidator::predeclared_type_handle(
  self : WgslIrValidator,
  predeclared : PredeclaredType,
) -> Handle? {
  for item in self.shader_module.special_types.predeclared_types {
    let (existing, handle) = item
    if existing == predeclared {
      return Some(handle)
    }
  }
  None
}

///|
fn WgslIrValidator::as_result_type(
  self : WgslIrValidator,
  input : Handle?,
  kind : ScalarKind,
  width : Int,
) -> Handle? {
  guard input is Some(input_ty) else { return None }
  let scalar = Scalar::Scalar(kind, width)
  match self.shader_module.types.get(input_ty) {
    Some(type_) =>
      match type_.inner {
        Scalar(_) => self.find_scalar_type(scalar)
        Vector(size, _) => self.vector_type(size, scalar)
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrValidator::atomic_result_type(
  self : WgslIrValidator,
  function : Function,
  atomic_function : AtomicFunction,
  arguments : Array[Handle],
) -> Handle? {
  guard arguments is [pointer, ..] else { return None }
  let scalar = match self.function_expression_type(function, pointer) {
    Some(ty) => self.atomic_scalar_type(ty)
    None => None
  }
  match atomic_function {
    Store => None
    CompareExchangeWeak =>
      match scalar {
        Some(value) => self.predeclared_atomic_compare_exchange_type(value)
        None => None
      }
    _ =>
      match scalar {
        Some(value) => self.find_scalar_type(value)
        None => None
      }
  }
}

///|
fn WgslIrValidator::image_result_type(
  self : WgslIrValidator,
  function : Function,
  image : Handle,
  gather : SwizzleComponent?,
  depth_ref : Handle?,
) -> Handle? {
  guard self.function_expression_type(function, image) is Some(image_ty) else {
    return None
  }
  match self.shader_module.types.get(image_ty) {
    Some(type_) =>
      match type_.inner {
        Image(_, _, Sampled(kind, _)) =>
          self.vector_type(Quad, Scalar::Scalar(kind, 4))
        Image(_, _, Depth(_)) =>
          if gather != None {
            self.vector_type(Quad, Scalar::Scalar(Float, 4))
          } else {
            ignore(depth_ref)
            self.find_scalar_type(Scalar::Scalar(Float, 4))
          }
        Image(_, _, Storage(format, _)) =>
          self.vector_type(
            Quad,
            wgsl_ir_validation_storage_format_scalar(format),
          )
        Image(_, _, External) =>
          self.vector_type(Quad, Scalar::Scalar(Float, 4))
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrValidator::image_query_result_type(
  self : WgslIrValidator,
  function : Function,
  image : Handle,
  query : ImageQuery,
) -> Handle? {
  match query {
    Size(_) =>
      match self.image_dimension(function, image) {
        Some(D1) => self.find_scalar_type(Scalar::Scalar(Uint, 4))
        Some(D2) | Some(Cube) => self.vector_type(Bi, Scalar::Scalar(Uint, 4))
        Some(D3) => self.vector_type(Tri, Scalar::Scalar(Uint, 4))
        None => None
      }
    NumLevels | NumLayers | NumSamples =>
      self.find_scalar_type(Scalar::Scalar(Uint, 4))
  }
}

///|
fn WgslIrValidator::subgroup_result_type(
  self : WgslIrValidator,
  function : Function,
  subgroup_function : SubgroupFunction,
  arguments : Array[Handle],
) -> Handle? {
  match subgroup_function {
    Ballot => self.vector_type(Quad, Scalar::Scalar(Uint, 4))
    All | Any => self.find_scalar_type(Scalar::Scalar(Bool, 1))
    _ =>
      match arguments.get(0) {
        Some(argument) => self.function_expression_type(function, argument)
        None => None
      }
  }
}

///|
fn WgslIrValidator::image_dimension(
  self : WgslIrValidator,
  function : Function,
  image : Handle,
) -> ImageDimension? {
  guard self.function_expression_type(function, image) is Some(image_ty) else {
    return None
  }
  match self.shader_module.types.get(image_ty) {
    Some(type_) =>
      match type_.inner {
        Image(dimension, _, _) => Some(dimension)
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrValidator::cooperative_data_scalar(
  self : WgslIrValidator,
  function : Function,
  data : CooperativeData,
) -> Scalar? {
  guard self.function_expression_type(function, data.pointer)
    is Some(pointer_ty) else {
    return None
  }
  match self.pointer_pointee_type(pointer_ty) {
    Some(value_ty) => self.scalar_from_type(value_ty)
    None => self.scalar_from_type(pointer_ty)
  }
}

///|
fn WgslIrValidator::atomic_scalar_type(
  self : WgslIrValidator,
  ty : Handle,
) -> Scalar? {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Atomic(scalar) => Some(scalar)
        Pointer(base, _) => self.atomic_scalar_type(base)
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrValidator::predeclared_atomic_compare_exchange_type(
  self : WgslIrValidator,
  scalar : Scalar,
) -> Handle? {
  self.predeclared_type_handle(AtomicCompareExchangeWeakResult(scalar))
}

///|
fn WgslIrValidator::scalar_type_from_type(
  self : WgslIrValidator,
  ty : Handle,
) -> Handle? {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Scalar(_) => Some(ty)
        Vector(_, scalar) | Matrix(_, _, scalar) =>
          self.find_scalar_type(scalar)
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrValidator::scalar_from_type(
  self : WgslIrValidator,
  ty : Handle,
) -> Scalar? {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Scalar(scalar) | Vector(_, scalar) | Matrix(_, _, scalar) =>
          Some(scalar)
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrValidator::transpose_type(
  self : WgslIrValidator,
  ty : Handle,
) -> Handle? {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Matrix(columns, rows, scalar) => self.matrix_type(rows, columns, scalar)
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrValidator::type_assignable(
  self : WgslIrValidator,
  expected : Handle,
  actual : Handle,
) -> Bool {
  if expected == actual {
    return true
  }
  match
    (
      self.shader_module.types.get(expected),
      self.shader_module.types.get(actual),
    ) {
    (Some(expected_ty), Some(actual_ty)) =>
      self.type_inner_assignable(expected_ty.inner, actual_ty.inner)
    _ => false
  }
}

///|
fn WgslIrValidator::type_inner_assignable(
  self : WgslIrValidator,
  expected : TypeInner,
  actual : TypeInner,
) -> Bool {
  ignore(self)
  if expected == actual {
    return true
  }
  match (expected, actual) {
    (Scalar(expected_scalar), Scalar(actual_scalar)) =>
      wgsl_ir_validation_scalar_assignable(expected_scalar, actual_scalar)
    (Vector(expected_size, expected_scalar), Vector(actual_size, actual_scalar)) =>
      expected_size == actual_size &&
      wgsl_ir_validation_scalar_assignable(expected_scalar, actual_scalar)
    (
      Matrix(expected_columns, expected_rows, expected_scalar),
      Matrix(actual_columns, actual_rows, actual_scalar),
    ) =>
      expected_columns == actual_columns &&
      expected_rows == actual_rows &&
      wgsl_ir_validation_scalar_assignable(expected_scalar, actual_scalar)
    _ => false
  }
}

///|
fn WgslIrValidator::types_are_select_compatible(
  self : WgslIrValidator,
  accept : Handle,
  reject : Handle,
) -> Bool {
  self.type_assignable(accept, reject) || self.type_assignable(reject, accept)
}

///|
fn WgslIrValidator::select_condition_type_matches_result(
  self : WgslIrValidator,
  condition : Handle,
  result : Handle,
) -> Bool {
  if self.type_is_bool_scalar(condition) {
    return true
  }
  match self.type_bool_vector_size(condition) {
    Some(condition_size) =>
      match self.vector_size(result) {
        Some(result_size) => condition_size == result_size
        None => false
      }
    None => false
  }
}

///|
fn WgslIrValidator::type_is_bool_scalar(
  self : WgslIrValidator,
  ty : Handle,
) -> Bool {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Scalar(scalar) => scalar.kind == Bool
        _ => false
      }
    None => false
  }
}

///|
fn WgslIrValidator::type_bool_vector_size(
  self : WgslIrValidator,
  ty : Handle,
) -> VectorSize? {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Vector(size, scalar) if scalar.kind == Bool => Some(size)
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrValidator::type_is_integer_scalar(
  self : WgslIrValidator,
  ty : Handle,
) -> Bool {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Scalar(scalar) =>
          scalar.kind == Sint ||
          scalar.kind == Uint ||
          scalar.kind == AbstractInt
        _ => false
      }
    None => false
  }
}

///|
fn WgslIrValidator::type_is_scalar(self : WgslIrValidator, ty : Handle) -> Bool {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Scalar(_) => true
        _ => false
      }
    None => false
  }
}

///|
fn WgslIrValidator::type_is_pointer_like(
  self : WgslIrValidator,
  ty : Handle,
) -> Bool {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Pointer(_, _) | ValuePointer(_, _, _) => true
        _ => false
      }
    None => false
  }
}

///|
fn WgslIrValidator::vector_size(
  self : WgslIrValidator,
  ty : Handle,
) -> VectorSize? {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Vector(size, _) => Some(size)
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrValidator::type_lane_count(self : WgslIrValidator, ty : Handle) -> Int {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Vector(size, _) => size.width()
        Matrix(columns, rows, _) => columns.width() * rows.width()
        _ => 1
      }
    None => 1
  }
}

///|
fn WgslIrValidator::type_is_handle_resource(
  self : WgslIrValidator,
  ty : Handle,
) -> Bool {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Image(_, _, _) | Sampler(_) | AccelerationStructure(_) | RayQuery(_) =>
          true
        BindingArray(element, _) => self.type_is_handle_resource(element)
        _ => false
      }
    None => false
  }
}

///|
fn WgslIrValidator::type_is_runtime_array(
  self : WgslIrValidator,
  ty : Handle,
) -> Bool {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Array(_, Dynamic, _) | BindingArray(_, Dynamic) => true
        _ => false
      }
    None => false
  }
}

///|
fn WgslIrValidator::pointer_targets_runtime_array(
  self : WgslIrValidator,
  ty : Handle,
) -> Bool {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Pointer(base, _) => self.type_or_struct_tail_is_runtime_array(base)
        _ => false
      }
    None => false
  }
}

///|
fn WgslIrValidator::type_or_struct_tail_is_runtime_array(
  self : WgslIrValidator,
  ty : Handle,
) -> Bool {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Array(_, Dynamic, _) => true
        Struct(members, _) | PredeclaredStruct(members, _) =>
          match members.last() {
            Some(struct_member) => self.type_is_runtime_array(struct_member.ty)
            None => false
          }
        _ => false
      }
    None => false
  }
}
