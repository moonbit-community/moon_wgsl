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
          let scalar = wgsl_ir_storage_format_scalar(format)
          Some(
            self.intern_type(
              "vec4<\{wgsl_ir_scalar_name(scalar.kind, scalar.width)}>",
              TypeInner::Vector(Quad, scalar),
            ),
          )
        }
        Image(_, _, External) =>
          Some(
            self.intern_type(
              "vec4<f32>",
              TypeInner::Vector(Quad, Scalar::Scalar(Float, 4)),
            ),
          )
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
fn WgslIrLowerer::numeric_binary_scalar_result_type(
  self : WgslIrLowerer,
  left_ty : Handle,
  right_ty : Handle,
) -> Handle? {
  guard self.scalar_from_numeric_type_handle(left_ty) is Some(left) else {
    return None
  }
  guard self.scalar_from_numeric_type_handle(right_ty) is Some(right) else {
    return None
  }
  if left.kind == AbstractInt {
    match right.kind {
      Sint | Uint | Float | AbstractFloat => return Some(right_ty)
      AbstractInt => return Some(left_ty)
      _ => ()
    }
  }
  if left.kind == AbstractFloat {
    match right.kind {
      Float => return Some(right_ty)
      AbstractInt | AbstractFloat => return Some(left_ty)
      _ => ()
    }
  }
  match right.kind {
    AbstractInt => Some(left_ty)
    AbstractFloat =>
      match left.kind {
        Float => Some(left_ty)
        AbstractInt => Some(right_ty)
        _ => Some(left_ty)
      }
    _ => Some(left_ty)
  }
}

///|
fn wgsl_ir_binary_operator_is_arithmetic(op : BinaryOperator) -> Bool {
  match op {
    Add | Subtract | Multiply | Divide | Modulo => true
    _ => false
  }
}

///|
fn wgsl_ir_binary_operator_requires_vector_splat(op : BinaryOperator) -> Bool {
  match op {
    Add | Subtract | Divide | Modulo => true
    _ => false
  }
}

///|
fn WgslIrLowerer::scalar_from_numeric_type_handle(
  self : WgslIrLowerer,
  ty_handle : Handle,
) -> Scalar? {
  match self.shader_module.types.get(ty_handle) {
    Some(ty) =>
      match ty.inner {
        Scalar(scalar) =>
          match scalar.kind {
            Sint | Uint | Float | AbstractInt | AbstractFloat => Some(scalar)
            _ => None
          }
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
fn WgslIrLowerer::contextualized_component_constructor_type(
  self : WgslIrLowerer,
  name : String,
  actual_ty : Handle,
  expected_ty : Handle?,
) -> Handle? {
  guard expected_ty is Some(expected_handle) else { return None }
  guard wgsl_ir_vector_size_from_constructor_name(name) is Some(size) else {
    return None
  }
  guard self.shader_module.types.get(expected_handle) is Some(expected) else {
    return None
  }
  match expected.inner {
    Scalar(scalar) =>
      self.contextualized_constructor_type(
        actual_ty,
        self.vector_type_handle(size, scalar),
      )
    _ => None
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
fn WgslIrLowerer::constructor_argument_expected_type(
  self : WgslIrLowerer,
  ty_handle : Handle,
  argument_count : Int,
) -> Handle? {
  match self.shader_module.types.get(ty_handle) {
    Some(ty) =>
      match ty.inner {
        Vector(_, scalar) => Some(self.scalar_type_handle(scalar))
        Matrix(columns, rows, scalar) => {
          let column_count = columns.width()
          let row_count = rows.width()
          if argument_count == column_count {
            Some(self.vector_type_handle(rows, scalar))
          } else if argument_count == column_count * row_count {
            Some(self.scalar_type_handle(scalar))
          } else {
            None
          }
        }
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
    F16(_) => self.type_cache.get("f16")
    F32(_) => self.type_cache.get("f32")
    F64(_) => self.type_cache.get("f64")
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
    Float =>
      if scalar.width == 2 {
        "f16"
      } else if scalar.width == 8 {
        "f64"
      } else {
        "f32"
      }
    AbstractInt => "__abstract_int"
    AbstractFloat => "__abstract_float"
  }
  self.intern_type(name, TypeInner::Scalar(scalar))
}

///|
fn wgsl_ir_scalar_name(kind : ScalarKind, width : Int) -> String {
  match kind {
    Bool => "bool"
    Sint => if width == 8 { "i64" } else { "i32" }
    Uint => if width == 8 { "u64" } else { "u32" }
    Float => if width == 2 { "f16" } else if width == 8 { "f64" } else { "f32" }
    AbstractInt => "__abstract_int"
    AbstractFloat => "__abstract_float"
  }
}

///|
fn wgsl_ir_storage_format_scalar(format : StorageFormat) -> Scalar {
  match format {
    R64Uint => Scalar::Scalar(Uint, 8)
    R8Uint
    | R16Uint
    | Rg8Uint
    | R32Uint
    | Rg16Uint
    | Rgba8Uint
    | Rgb10a2Uint
    | Rg32Uint
    | Rgba16Uint
    | Rgba32Uint => Scalar::Scalar(Uint, 4)
    R8Sint
    | R16Sint
    | Rg8Sint
    | R32Sint
    | Rg16Sint
    | Rgba8Sint
    | Rg32Sint
    | Rgba16Sint
    | Rgba32Sint => Scalar::Scalar(Sint, 4)
    _ => Scalar::Scalar(Float, 4)
  }
}

///|
fn wgsl_ir_gather_component_from_node(
  node : @ast.WgslExprNode,
) -> SwizzleComponent raise WgslIrLowerError {
  match node.kind() {
    Literal(token) =>
      match token.kind() {
        NumericLiteral(literal) =>
          match wgsl_ir_numeric_literal_to_small_int(literal) {
            Some(value) =>
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
            None =>
              raise WgslIrLowerError::UnsupportedExpression(
                "textureGather component must be an integer literal",
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
        NumericLiteral(literal) =>
          match wgsl_ir_numeric_literal_to_small_int(literal) {
            Some(value) =>
              match value {
                0 | 1 | 2 | 3 => true
                _ => false
              }
            None => false
          }
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
    | Component(base, _)
    | Splat(_, base)
    | Swizzle(_, base, _)
    | Load(base)
    | Unary(_, base)
    | Bitcast(_, base)
    | Derivative(_, _, base)
    | Relational(_, base)
    | As(base, _, _)
    | CallResult(base)
    | WorkGroupUniformLoadResult(base)
    | WorkGroupUniformLoad(base)
    | ArrayLength(base)
    | RayQueryProceed(base)
    | RayQueryConfirmIntersection(base)
    | RayQueryTerminate(base)
    | RayQueryVertexPositions(base, _)
    | RayQueryGetIntersection(base, _)
    | SubgroupOperationResult(base) =>
      self.global_expression_references_override(base)
    AtomicResult(_, _) => false
    SubgroupCall(_, arguments) =>
      wgsl_ir_global_expression_list_references_override(self, arguments)
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
    "rgb10a2uint" => Rgb10a2Uint
    "rgb10a2unorm" => Rgb10a2Unorm
    "rg11b10ufloat" => Rg11b10Ufloat
    "r64uint" => R64Uint
    "rg32uint" => Rg32Uint
    "rg32sint" => Rg32Sint
    "rg32float" => Rg32Float
    "rgba16uint" => Rgba16Uint
    "rgba16sint" => Rgba16Sint
    "rgba16float" => Rgba16Float
    "rgba32uint" => Rgba32Uint
    "rgba32sint" => Rgba32Sint
    "rgba32float" => Rgba32Float
    "r16unorm" => R16Unorm
    "r16snorm" => R16Snorm
    "rg16unorm" => Rg16Unorm
    "rg16snorm" => Rg16Snorm
    "rgba16unorm" => Rgba16Unorm
    "rgba16snorm" => Rgba16Snorm
    _ => raise WgslIrLowerError::UnsupportedType("storage format \{name}")
  }
}
