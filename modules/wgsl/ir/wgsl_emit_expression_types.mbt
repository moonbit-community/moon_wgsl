///|
/// Semantic type queries shared by valid-WGSL and compatibility writers.
///
/// The query owns no naming, ordering, formatting, or compatibility policy.
pub struct WgslIrTypeInference {
  priv shader_module : Module
}

///|
pub fn WgslIrTypeInference::from_module(
  shader_module : Module,
) -> WgslIrTypeInference {
  { shader_module, }
}

///|
pub fn WgslIrTypeInference::expression_type(
  self : WgslIrTypeInference,
  function : Function?,
  handle : Handle,
) -> Handle? {
  match function {
    Some(function) => {
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
    None =>
      match self.shader_module.global_expressions.items.get(handle.index()) {
        Some(expression) => self.global_expression_inner_type(expression)
        None => None
      }
  }
}

///|
fn WgslIrTypeInference::function_expression_inner_type(
  self : WgslIrTypeInference,
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
    AddressOf(ty, _) => Some(ty)
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
      match self.expression_type(Some(function), inner) {
        Some(ty) => self.load_result_type(ty)
        None => None
      }
    Compose(ty, _) | ZeroValue(ty) => Some(ty)
    AccessIndex(base, index) =>
      self.indexed_expression_type(Some(function), base, Some(index))
    Component(base, _) =>
      self.indexed_expression_type(Some(function), base, Some(0))
    Access(base, _) => self.indexed_expression_type(Some(function), base, None)
    Splat(size, inner) =>
      match self.expression_type(Some(function), inner) {
        Some(ty) => self.vector_type_from_scalar_type(size, ty)
        None => None
      }
    Swizzle(size, base, _) =>
      self.swizzle_expression_type(Some(function), base, size)
    Unary(_, inner) => self.expression_type(Some(function), inner)
    Binary(op, left, right) =>
      match self.expression_type(Some(function), left) {
        Some(left_ty) =>
          match self.expression_type(Some(function), right) {
            Some(right_ty) =>
              self.binary_expression_result_type(op, left_ty, right_ty)
            None => Some(left_ty)
          }
        None => self.expression_type(Some(function), right)
      }
    Select(_, accept, reject) =>
      match self.expression_type(Some(function), accept) {
        Some(ty) => Some(ty)
        None => self.expression_type(Some(function), reject)
      }
    Bitcast(ty, _) => Some(ty)
    Derivative(_, _, expr) => self.expression_type(Some(function), expr)
    FunctionCall(handle, _) | CallResult(handle) =>
      match self.shader_module.functions.items.get(handle.index()) {
        Some(callee) =>
          match callee.result {
            Some(result) => Some(result.ty)
            None => None
          }
        None => None
      }
    Math(math_function, a, b, c, d) =>
      self.math_expression_result_type(
        Some(function),
        math_function,
        a,
        b,
        c,
        d,
      )
    Relational(relational_function, expr) =>
      self.relational_expression_result_type(
        Some(function),
        relational_function,
        expr,
      )
    As(expr, kind, width) =>
      self.as_expression_result_type(
        self.expression_type(Some(function), expr),
        kind,
        width.unwrap_or(4),
      )
    AtomicCall(atomic_function, arguments) =>
      self.atomic_expression_result_type(
        Some(function),
        atomic_function,
        arguments,
      )
    AtomicResult(ty, _) => Some(ty)
    ImageSample(image, _, gather, _, _, _, _, depth_ref, _) =>
      self.image_expression_result_type(
        Some(function),
        image,
        gather,
        depth_ref,
      )
    ImageLoad(image, _, _, _, _) =>
      self.image_expression_result_type(Some(function), image, None, None)
    ImageQuery(image, query) =>
      self.image_query_expression_result_type(Some(function), image, query)
    ArrayLength(_) => self.type_handle_named("u32")
    RayQueryVertexPositions(_, _) =>
      self.shader_module.special_types.ray_vertex_return
    RayQueryGetIntersection(_, _) => self.type_handle_named("RayIntersection")
    RayQueryProceedResult => self.type_handle_named("bool")
    WorkGroupUniformLoad(pointer) =>
      match self.expression_type(Some(function), pointer) {
        Some(ty) => Some(self.deref_pointer_type_handle(ty))
        None => None
      }
    CooperativeLoad(columns, rows, role, data) =>
      match self.cooperative_data_scalar(Some(function), data) {
        Some(scalar) =>
          self.cooperative_matrix_type_handle(columns, rows, scalar, role)
        None => None
      }
    CooperativeMultiplyAdd(_, _, c) => self.expression_type(Some(function), c)
    SubgroupCall(subgroup_function, arguments) =>
      self.subgroup_expression_result_type(
        Some(function),
        subgroup_function,
        arguments,
      )
    Literal(literal) => self.literal_type(literal)
    _ => None
  }
}

///|
pub fn WgslIrTypeInference::as_expression_result_type(
  self : WgslIrTypeInference,
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
        Vector(size, _) => self.find_vector_type(size, scalar)
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrTypeInference::cooperative_matrix_type_handle(
  self : WgslIrTypeInference,
  columns : CooperativeSize,
  rows : CooperativeSize,
  scalar : Scalar,
  role : CooperativeRole,
) -> Handle? {
  for index in 0..<self.shader_module.types.items.length() {
    match self.shader_module.types.items[index].inner {
      CooperativeMatrix(
        existing_columns,
        existing_rows,
        existing_scalar,
        existing_role
      ) =>
        if existing_columns == columns &&
          existing_rows == rows &&
          existing_scalar == scalar &&
          existing_role == role {
          return Some(Handle(index))
        }
      _ => ()
    }
  }
  None
}

///|
fn WgslIrTypeInference::type_handle_named(
  self : WgslIrTypeInference,
  name : String,
) -> Handle? {
  for index in 0..<self.shader_module.types.items.length() {
    match self.shader_module.types.items[index].name {
      Some(existing) if existing == name => return Some(Handle(index))
      _ => ()
    }
  }
  None
}

///|
fn WgslIrTypeInference::global_expression_inner_type(
  self : WgslIrTypeInference,
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
      match self.expression_type(None, inner) {
        Some(ty) => self.load_result_type(ty)
        None => None
      }
    Compose(ty, _) | ZeroValue(ty) => Some(ty)
    AccessIndex(base, index) =>
      self.indexed_expression_type(None, base, Some(index))
    Component(base, _) => self.indexed_expression_type(None, base, Some(0))
    Access(base, _) => self.indexed_expression_type(None, base, None)
    Swizzle(size, base, _) => self.swizzle_expression_type(None, base, size)
    Unary(_, inner) => self.expression_type(None, inner)
    Binary(op, left, right) =>
      match self.expression_type(None, left) {
        Some(left_ty) =>
          match self.expression_type(None, right) {
            Some(right_ty) =>
              self.binary_expression_result_type(op, left_ty, right_ty)
            None => Some(left_ty)
          }
        None => self.expression_type(None, right)
      }
    Select(_, accept, reject) =>
      match self.expression_type(None, accept) {
        Some(ty) => Some(ty)
        None => self.expression_type(None, reject)
      }
    Bitcast(ty, _) => Some(ty)
    Derivative(_, _, expr) => self.expression_type(None, expr)
    Math(math_function, a, b, c, d) =>
      self.math_expression_result_type(None, math_function, a, b, c, d)
    Relational(relational_function, expr) =>
      self.relational_expression_result_type(None, relational_function, expr)
    As(expr, kind, width) =>
      self.as_expression_result_type(
        self.expression_type(None, expr),
        kind,
        width.unwrap_or(4),
      )
    AtomicCall(atomic_function, arguments) =>
      self.atomic_expression_result_type(None, atomic_function, arguments)
    AtomicResult(ty, _) => Some(ty)
    ImageQuery(image, query) =>
      self.image_query_expression_result_type(None, image, query)
    ArrayLength(_) => self.type_handle_named("u32")
    SubgroupCall(subgroup_function, arguments) =>
      self.subgroup_expression_result_type(None, subgroup_function, arguments)
    Literal(literal) => self.literal_type(literal)
    _ => None
  }
}

///|
fn WgslIrTypeInference::literal_type(
  self : WgslIrTypeInference,
  literal : Literal,
) -> Handle? {
  match literal {
    Bool(_) => self.type_handle_named("bool")
    I32(_) => self.type_handle_named("i32")
    AbstractInt(_) => self.type_handle_named("__abstract_int")
    U32(_) => self.type_handle_named("u32")
    F16(_) => self.type_handle_named("f16")
    F32(_) | F32Exact(_) => self.type_handle_named("f32")
    F64(_) => self.type_handle_named("f64")
    AbstractFloat(_) => self.type_handle_named("__abstract_float")
    _ => None
  }
}

///|
fn WgslIrTypeInference::subgroup_expression_result_type(
  self : WgslIrTypeInference,
  function : Function?,
  subgroup_function : SubgroupFunction,
  arguments : Array[Handle],
) -> Handle? {
  match subgroup_function {
    Ballot => self.find_vector_type(Quad, Scalar(Uint, 4))
    All | Any => self.type_handle_named("bool")
    _ =>
      match arguments.get(0) {
        Some(first) => self.expression_type(function, first)
        None => None
      }
  }
}

///|
fn WgslIrTypeInference::image_expression_result_type(
  self : WgslIrTypeInference,
  function : Function?,
  image : Handle,
  gather : SwizzleComponent?,
  depth_ref : Handle?,
) -> Handle? {
  guard self.expression_type(function, image) is Some(image_ty) else {
    return None
  }
  match self.shader_module.types.items.get(image_ty.index()) {
    Some(ty) =>
      match ty.inner {
        Image(_, _, Sampled(kind, _)) =>
          self.find_vector_type(Quad, Scalar(kind, 4))
        Image(_, _, Depth(_)) =>
          if gather != None {
            self.find_vector_type(Quad, Scalar(Float, 4))
          } else if depth_ref != None {
            self.type_handle_named("f32")
          } else {
            self.type_handle_named("f32")
          }
        Image(_, _, Storage(format, _)) =>
          self.find_vector_type(
            Quad,
            wgsl_ir_emit_storage_format_scalar(format),
          )
        Image(_, _, External) => self.find_vector_type(Quad, Scalar(Float, 4))
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrTypeInference::image_query_expression_result_type(
  self : WgslIrTypeInference,
  function : Function?,
  image : Handle,
  query : ImageQuery,
) -> Handle? {
  match query {
    Size(_) =>
      match self.expression_type(function, image) {
        Some(image_ty) =>
          match self.shader_module.types.items.get(image_ty.index()) {
            Some(ty) =>
              match ty.inner {
                Image(dimension, _, _) =>
                  self.image_dimension_size_type_handle(dimension)
                _ => None
              }
            None => None
          }
        None => None
      }
    NumLevels | NumLayers | NumSamples => self.type_handle_named("u32")
  }
}

///|
fn WgslIrTypeInference::image_dimension_size_type_handle(
  self : WgslIrTypeInference,
  dimension : ImageDimension,
) -> Handle? {
  match dimension {
    D1 => self.type_handle_named("u32")
    D2 | Cube => self.type_handle_named("vec2<u32>")
    D3 => self.type_handle_named("vec3<u32>")
  }
}

///|
fn WgslIrTypeInference::indexed_expression_type(
  self : WgslIrTypeInference,
  function : Function?,
  base : Handle,
  index : Int?,
) -> Handle? {
  guard self.expression_type(function, base) is Some(base_ty) else {
    return None
  }
  self.indexed_type_from_type_handle(base_ty, index)
}

///|
fn WgslIrTypeInference::indexed_type_from_type_handle(
  self : WgslIrTypeInference,
  ty_handle : Handle,
  index : Int?,
) -> Handle? {
  match self.shader_module.types.items.get(ty_handle.index()) {
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
        Vector(_, scalar) => self.find_vector_scalar_type(scalar)
        Matrix(_, rows, scalar) => self.find_vector_type(rows, scalar)
        Array(element, _, _) | BindingArray(element, _) => Some(element)
        Pointer(inner, _) => self.indexed_type_from_type_handle(inner, index)
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrTypeInference::load_result_type(
  self : WgslIrTypeInference,
  ty_handle : Handle,
) -> Handle? {
  let deref = self.deref_pointer_type_handle(ty_handle)
  match self.shader_module.types.get(deref) {
    Some(type_) =>
      match type_.inner {
        Atomic(scalar) => self.find_scalar_type(scalar)
        _ => Some(deref)
      }
    None => Some(deref)
  }
}

///|
fn WgslIrTypeInference::swizzle_expression_type(
  self : WgslIrTypeInference,
  function : Function?,
  base : Handle,
  size : VectorSize,
) -> Handle? {
  guard self.expression_type(function, base) is Some(base_ty) else {
    return None
  }
  match self.shader_module.types.get(base_ty) {
    Some(ty) =>
      match ty.inner {
        Vector(_, scalar) => self.find_vector_type(size, scalar)
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrTypeInference::find_vector_scalar_type(
  self : WgslIrTypeInference,
  scalar : Scalar,
) -> Handle? {
  let scalar_inner = TypeInner::Scalar(scalar)
  for i in 0..<self.shader_module.types.items.length() {
    if self.shader_module.types.items[i].inner == scalar_inner {
      return Some(Handle(i))
    }
  }
  None
}

///|
fn WgslIrTypeInference::find_vector_type(
  self : WgslIrTypeInference,
  size : VectorSize,
  scalar : Scalar,
) -> Handle? {
  let vector_inner = TypeInner::Vector(size, scalar)
  for i in 0..<self.shader_module.types.items.length() {
    if self.shader_module.types.items[i].inner == vector_inner {
      return Some(Handle(i))
    }
  }
  None
}

///|
fn WgslIrTypeInference::vector_type_from_scalar_type(
  self : WgslIrTypeInference,
  size : VectorSize,
  ty : Handle,
) -> Handle? {
  match self.shader_module.types.get(ty) {
    Some({ inner: Scalar(scalar), .. }) => self.find_vector_type(size, scalar)
    _ => None
  }
}

///|
fn WgslIrTypeInference::math_expression_result_type(
  self : WgslIrTypeInference,
  function : Function?,
  math_function : MathFunction,
  argument : Handle,
  b : Handle?,
  c : Handle?,
  d : Handle?,
) -> Handle? {
  guard self.expression_type(function, argument) is Some(input_ty) else {
    return None
  }
  match math_function {
    Dot | Distance | Length | Determinant =>
      return self.scalar_type_from_composite_type(input_ty)
    _ => ()
  }
  if wgsl_ir_math_function_uses_uniform_numeric_argument_context(math_function) {
    match
      wgsl_ir_math_primary_result_operand(math_function, argument, b, c, d) {
      Some(primary) =>
        match self.expression_component_scalar(function, primary) {
          Some(scalar) if !wgsl_ir_scalar_kind_is_abstract(scalar.kind) =>
            return self.expression_type(function, primary)
          _ => ()
        }
      None => ()
    }
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
      match self.expression_component_scalar(function, value) {
        Some(scalar) if !wgsl_ir_scalar_kind_is_abstract(scalar.kind) =>
          match self.expression_type(function, value) {
            Some(ty) => return Some(ty)
            None => ()
          }
        _ => ()
      }
    }
  }
  match math_function {
    Modf | Frexp =>
      self.predeclared_numeric_result_type(input_ty, math_function)
    Pack4x8snorm
    | Pack4x8unorm
    | Pack2x16snorm
    | Pack2x16unorm
    | Pack2x16float
    | Pack4xI8
    | Pack4xU8
    | Pack4xI8Clamp
    | Pack4xU8Clamp
    | Dot4U8Packed => self.type_handle_named("u32")
    Dot4I8Packed => self.type_handle_named("i32")
    Unpack4x8snorm | Unpack4x8unorm =>
      self.find_vector_type(Quad, Scalar(Float, 4))
    Unpack2x16snorm | Unpack2x16unorm | Unpack2x16float =>
      self.find_vector_type(Bi, Scalar(Float, 4))
    Unpack4xI8 => self.find_vector_type(Quad, Scalar(Sint, 4))
    Unpack4xU8 => self.find_vector_type(Quad, Scalar(Uint, 4))
    Transpose => self.transpose_expression_result_type(input_ty)
    _ => Some(input_ty)
  }
}

///|
fn WgslIrTypeInference::transpose_expression_result_type(
  self : WgslIrTypeInference,
  input_ty : Handle,
) -> Handle? {
  match self.shader_module.types.get(input_ty) {
    Some(type_) =>
      match type_.inner {
        Matrix(columns, rows, scalar) =>
          self.find_matrix_type(rows, columns, scalar)
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrTypeInference::scalar_type_from_composite_type(
  self : WgslIrTypeInference,
  ty_handle : Handle,
) -> Handle? {
  match self.shader_module.types.get(ty_handle) {
    Some(ty) =>
      match ty.inner {
        Vector(_, scalar) | Matrix(_, _, scalar) =>
          self.find_scalar_type(scalar)
        _ => Some(ty_handle)
      }
    None => None
  }
}

///|
fn WgslIrTypeInference::relational_expression_result_type(
  self : WgslIrTypeInference,
  function : Function?,
  relational_function : RelationalFunction,
  argument : Handle,
) -> Handle? {
  match relational_function {
    All | Any => self.find_scalar_type(Scalar(Bool, 1))
    IsNan | IsInf =>
      match self.expression_type(function, argument) {
        Some(input_ty) => self.boolean_result_type(input_ty, input_ty)
        None => None
      }
  }
}

///|
fn WgslIrTypeInference::binary_expression_result_type(
  self : WgslIrTypeInference,
  op : BinaryOperator,
  left_ty : Handle,
  right_ty : Handle,
) -> Handle? {
  if wgsl_ir_binary_operator_is_comparison(op) {
    return self.boolean_result_type(left_ty, right_ty)
  }
  if op == Multiply {
    match self.matrix_vector_multiply_result_type(left_ty, right_ty) {
      Some(ty) => return Some(ty)
      None => ()
    }
  }
  match self.contextual_numeric_binary_result_type(left_ty, right_ty) {
    Some(ty) => return Some(ty)
    None => ()
  }
  if self.type_is_scalar(left_ty) && !self.type_is_scalar(right_ty) {
    return Some(right_ty)
  }
  if !self.type_is_scalar(left_ty) && self.type_is_scalar(right_ty) {
    return Some(left_ty)
  }
  Some(left_ty)
}

///|
fn WgslIrTypeInference::contextual_numeric_binary_result_type(
  self : WgslIrTypeInference,
  left_ty : Handle,
  right_ty : Handle,
) -> Handle? {
  let left = match self.shader_module.types.get(left_ty) {
    Some(value) => value.inner
    None => return None
  }
  let right = match self.shader_module.types.get(right_ty) {
    Some(value) => value.inner
    None => return None
  }
  match (left, right) {
    (Scalar(left_scalar), Scalar(right_scalar)) =>
      self.contextual_numeric_scalar_result_type(
        left_ty, left_scalar, right_ty, right_scalar,
      )
    (Vector(left_size, left_scalar), Vector(right_size, right_scalar)) =>
      if left_size == right_size {
        self.contextual_numeric_scalar_result_type(
          left_ty, left_scalar, right_ty, right_scalar,
        )
      } else {
        None
      }
    (
      Matrix(left_columns, left_rows, left_scalar),
      Matrix(right_columns, right_rows, right_scalar),
    ) =>
      if left_columns == right_columns && left_rows == right_rows {
        self.contextual_numeric_scalar_result_type(
          left_ty, left_scalar, right_ty, right_scalar,
        )
      } else {
        None
      }
    _ => None
  }
}

///|
fn WgslIrTypeInference::contextual_numeric_scalar_result_type(
  self : WgslIrTypeInference,
  left_ty : Handle,
  left_scalar : Scalar,
  right_ty : Handle,
  right_scalar : Scalar,
) -> Handle? {
  ignore(self)
  let left_is_abstract = wgsl_ir_scalar_kind_is_abstract(left_scalar.kind)
  let right_is_abstract = wgsl_ir_scalar_kind_is_abstract(right_scalar.kind)
  match (left_is_abstract, right_is_abstract) {
    (true, false) => Some(right_ty)
    (false, true) => Some(left_ty)
    _ => None
  }
}

///|
fn WgslIrTypeInference::matrix_vector_multiply_result_type(
  self : WgslIrTypeInference,
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
                Vector(_, _) => self.find_vector_type(rows, scalar)
                Matrix(columns, right_rows, _) =>
                  if right_rows == left_columns {
                    self.find_matrix_type(columns, rows, scalar)
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
                Matrix(columns, _, _) => self.find_vector_type(columns, scalar)
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
fn WgslIrTypeInference::find_matrix_type(
  self : WgslIrTypeInference,
  columns : VectorSize,
  rows : VectorSize,
  scalar : Scalar,
) -> Handle? {
  let matrix_inner = TypeInner::Matrix(columns, rows, scalar)
  for i in 0..<self.shader_module.types.items.length() {
    if self.shader_module.types.items[i].inner == matrix_inner {
      return Some(Handle(i))
    }
  }
  None
}

///|
fn WgslIrTypeInference::boolean_result_type(
  self : WgslIrTypeInference,
  left_ty : Handle,
  right_ty : Handle,
) -> Handle? {
  match self.vector_size_from_type(left_ty) {
    Some(size) => self.find_vector_type(size, Scalar(Bool, 1))
    None =>
      match self.vector_size_from_type(right_ty) {
        Some(size) => self.find_vector_type(size, Scalar(Bool, 1))
        None => self.find_scalar_type(Scalar(Bool, 1))
      }
  }
}

///|
fn WgslIrTypeInference::type_is_scalar(
  self : WgslIrTypeInference,
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
fn WgslIrTypeInference::vector_size_from_type(
  self : WgslIrTypeInference,
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
fn WgslIrTypeInference::find_scalar_type(
  self : WgslIrTypeInference,
  scalar : Scalar,
) -> Handle? {
  let scalar_inner = TypeInner::Scalar(scalar)
  for i in 0..<self.shader_module.types.items.length() {
    if self.shader_module.types.items[i].inner == scalar_inner {
      return Some(Handle(i))
    }
  }
  None
}

///|
fn WgslIrTypeInference::predeclared_numeric_result_type(
  self : WgslIrTypeInference,
  input_ty : Handle,
  math_function : MathFunction,
) -> Handle? {
  let key = match self.shader_module.types.items.get(input_ty.index()) {
    Some(ty) =>
      match ty.inner {
        Scalar(scalar) =>
          if math_function == Modf {
            Some(PredeclaredType::ModfResult(None, scalar))
          } else {
            Some(FrexpResult(None, scalar))
          }
        Vector(size, scalar) =>
          if math_function == Modf {
            Some(ModfResult(Some(size), scalar))
          } else {
            Some(FrexpResult(Some(size), scalar))
          }
        _ => None
      }
    None => None
  }
  match key {
    Some(predeclared) => self.predeclared_type_handle(predeclared)
    None => None
  }
}

///|
fn WgslIrTypeInference::atomic_expression_result_type(
  self : WgslIrTypeInference,
  function : Function?,
  atomic_function : AtomicFunction,
  arguments : Array[Handle],
) -> Handle? {
  guard arguments is [_, ..] else { return None }
  let scalar = self.atomic_call_result_scalar_type(function, arguments)
  match atomic_function {
    Store => None
    CompareExchangeWeak =>
      match scalar {
        Some(value) =>
          self.predeclared_type_handle(AtomicCompareExchangeWeakResult(value))
        None => None
      }
    _ =>
      match scalar {
        Some(value) => self.find_vector_scalar_type(value)
        None => None
      }
  }
}

///|
fn WgslIrTypeInference::atomic_call_result_scalar_type(
  self : WgslIrTypeInference,
  function : Function?,
  arguments : Array[Handle],
) -> Scalar? {
  guard arguments is [pointer, .. rest] else { return None }
  match self.atomic_pointer_scalar_type(function, pointer) {
    Some(scalar) => Some(scalar)
    None =>
      match rest {
        [value, ..] =>
          match self.expression_type(function, value) {
            Some(ty) => self.scalar_from_numeric_type_handle(ty)
            None => None
          }
        [] => None
      }
  }
}

///|
fn WgslIrTypeInference::scalar_from_numeric_type_handle(
  self : WgslIrTypeInference,
  ty : Handle,
) -> Scalar? {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Scalar(scalar) => Some(scalar)
        Vector(_, scalar) | Matrix(_, _, scalar) => Some(scalar)
        _ => None
      }
    None => None
  }
}

///|
pub fn WgslIrTypeInference::atomic_pointer_scalar_type(
  self : WgslIrTypeInference,
  function : Function?,
  pointer : Handle,
) -> Scalar? {
  guard self.expression_type(function, pointer) is Some(ty_handle) else {
    return None
  }
  self.atomic_scalar_type_from_handle(ty_handle)
}

///|
fn WgslIrTypeInference::deref_pointer_type_handle(
  self : WgslIrTypeInference,
  ty_handle : Handle,
) -> Handle {
  match self.shader_module.types.items.get(ty_handle.index()) {
    Some(ty) =>
      match ty.inner {
        Pointer(inner, _) => self.deref_pointer_type_handle(inner)
        _ => ty_handle
      }
    None => ty_handle
  }
}

///|
fn WgslIrTypeInference::expression_component_scalar(
  self : WgslIrTypeInference,
  function : Function?,
  handle : Handle,
) -> Scalar? {
  match self.expression_type(function, handle) {
    Some(ty_handle) => self.type_component_scalar(ty_handle)
    None => None
  }
}

///|
fn WgslIrTypeInference::type_component_scalar(
  self : WgslIrTypeInference,
  ty : Handle,
) -> Scalar? {
  match self.shader_module.types.items.get(ty.index()) {
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
fn WgslIrTypeInference::cooperative_data_scalar(
  self : WgslIrTypeInference,
  function : Function?,
  data : CooperativeData,
) -> Scalar? {
  match self.expression_type(function, data.pointer) {
    Some(ty) => self.cooperative_pointer_scalar(ty)
    None => None
  }
}

///|
fn WgslIrTypeInference::cooperative_pointer_scalar(
  self : WgslIrTypeInference,
  ty : Handle,
) -> Scalar? {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Pointer(base, _) => self.cooperative_pointer_scalar(base)
        ValuePointer(_, scalar, _) => Some(scalar)
        Scalar(scalar) => Some(scalar)
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrTypeInference::atomic_scalar_type_from_handle(
  self : WgslIrTypeInference,
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
fn WgslIrTypeInference::predeclared_type_handle(
  self : WgslIrTypeInference,
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
