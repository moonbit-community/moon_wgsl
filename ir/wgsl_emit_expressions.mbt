///|
fn WgslIrEmitter::global_expression(
  self : WgslIrEmitter,
  handle : Handle,
) -> String raise WgslIrEmitError {
  let expression = match
    self.shader_module.global_expressions.items.get(handle.index()) {
    Some(value) => value
    None =>
      raise WgslIrEmitError::MissingHandle(
        "global expression \{handle.index()}",
      )
  }
  self.emit_expression(expression, None)
}

///|
fn WgslIrEmitter::abstract_float_global_expression(
  self : WgslIrEmitter,
  handle : Handle,
) -> String raise WgslIrEmitError {
  self.with_preserved_abstract_float_literals().global_expression(handle)
}

///|
fn WgslIrEmitter::function_expression(
  self : WgslIrEmitter,
  function : Function,
  handle : Handle,
) -> String raise WgslIrEmitError {
  let expression = match function.expressions.items.get(handle.index()) {
    Some(value) => value
    None =>
      raise WgslIrEmitError::MissingHandle(
        "function expression \{handle.index()}",
      )
  }
  match self.baked_function_expression_name(handle) {
    Some(name) => return name
    None => ()
  }
  match expression {
    CallResult(_) => return self.function_expression_baked_name(handle)
    _ => ()
  }
  self.emit_expression(expression, Some(function))
}

///|
fn WgslIrEmitter::abstract_float_function_expression(
  self : WgslIrEmitter,
  function : Function,
  handle : Handle,
) -> String raise WgslIrEmitError {
  self
  .with_preserved_abstract_float_literals()
  .function_expression(function, handle)
}

///|
fn WgslIrEmitter::function_pointer_expression(
  self : WgslIrEmitter,
  function : Function,
  handle : Handle,
) -> String raise WgslIrEmitError {
  let expression = match function.expressions.items.get(handle.index()) {
    Some(value) => value
    None =>
      raise WgslIrEmitError::MissingHandle(
        "function pointer expression \{handle.index()}",
      )
  }
  match expression {
    Load(inner) => self.function_pointer_expression(function, inner)
    _ => self.emit_expression(expression, Some(function))
  }
}

///|
fn WgslIrEmitter::load_expression(
  self : WgslIrEmitter,
  function : Function?,
  pointer : Handle,
) -> String raise WgslIrEmitError {
  let expression = self.required_function_expression(function, pointer)
  if self.load_expression_requires_explicit_deref(function, pointer) {
    "*(\{expression})"
  } else {
    expression
  }
}

///|
fn WgslIrEmitter::load_expression_requires_explicit_deref(
  self : WgslIrEmitter,
  function : Function?,
  pointer : Handle,
) -> Bool raise WgslIrEmitError {
  let expression = match function {
    Some(function) =>
      match function.expressions.items.get(pointer.index()) {
        Some(expression) => expression
        None =>
          raise WgslIrEmitError::MissingHandle(
            "function load expression \{pointer.index()}",
          )
      }
    None =>
      match self.shader_module.global_expressions.items.get(pointer.index()) {
        Some(expression) => expression
        None =>
          raise WgslIrEmitError::MissingHandle(
            "global load expression \{pointer.index()}",
          )
      }
  }
  match expression {
    Access(_, _) | AccessIndex(_, _) | Swizzle(_, _, _) => false
    Load(inner) => self.load_expression_requires_explicit_deref(function, inner)
    _ =>
      match self.expression_type(function, pointer) {
        Some(ty) =>
          match self.shader_module.types.items.get(ty.index()) {
            Some(type_) =>
              match type_.inner {
                Pointer(_, _) => true
                _ => false
              }
            None => false
          }
        None => false
      }
  }
}

///|
fn WgslIrEmitter::access_base_expression(
  self : WgslIrEmitter,
  function : Function?,
  base : Handle,
) -> String raise WgslIrEmitError {
  let expression = self.required_function_expression(function, base)
  let needs_parens = match function {
    Some(function) =>
      match function.expressions.items.get(base.index()) {
        Some(Load(inner)) =>
          self.load_expression_requires_explicit_deref(Some(function), inner)
        Some(Binary(_, _, _)) | Some(Select(_, _, _)) => true
        _ => false
      }
    None =>
      match self.shader_module.global_expressions.items.get(base.index()) {
        Some(Load(inner)) =>
          self.load_expression_requires_explicit_deref(None, inner)
        Some(Binary(_, _, _)) | Some(Select(_, _, _)) => true
        _ => false
      }
  }
  if needs_parens {
    "(\{expression})"
  } else {
    expression
  }
}

///|
fn WgslIrEmitter::emit_expression(
  self : WgslIrEmitter,
  expression : Expression,
  function : Function?,
) -> String raise WgslIrEmitError {
  match expression {
    Literal(literal) => self.literal(literal)
    Constant(handle) => self.constant_expression(handle)
    Override(handle) => self.override_name(handle)
    ZeroValue(ty) => "\{self.type_name(ty)}()"
    Compose(ty, components) => self.compose_expression(ty, components, function)
    Splat(size, inner) =>
      "vec\{size.width()}(\{self.required_function_expression(function, inner)})"
    Access(base, index) =>
      "\{self.access_base_expression(function, base)}[\{self.required_function_expression(function, index)}]"
    AccessIndex(base, index) =>
      "\{self.access_base_expression(function, base)}.\{self.member_name_for_expression(function, base, index)}"
    Swizzle(_, base, components) =>
      "\{self.access_base_expression(function, base)}.\{self.swizzle_components(components)}"
    FunctionArgument(index) => self.function_argument_name(function, index)
    GlobalVariable(handle) => self.global_variable_name(handle)
    LocalVariable(handle) => self.local_variable_name(function, handle)
    Load(pointer) => self.load_expression(function, pointer)
    AddressOf(_, target) =>
      match function {
        Some(func) => "&\{self.function_pointer_expression(func, target)}"
        None =>
          raise WgslIrEmitError::Unsupported("global address-of expression")
      }
    AtomicCall(atomic_function, arguments) =>
      self.atomic_call_expression(function, atomic_function, arguments)
    ImageSample(
      image,
      sampler,
      gather,
      coordinate,
      array_index,
      offset,
      level,
      depth_ref,
      clamp_to_edge
    ) =>
      self.image_sample_expression(
        function, image, sampler, gather, coordinate, array_index, offset, level,
        depth_ref, clamp_to_edge,
      )
    ImageLoad(image, coordinate, array_index, sample, level) =>
      self.image_load_expression(
        function, image, coordinate, array_index, sample, level,
      )
    ImageQuery(image, query) =>
      self.image_query_expression(function, image, query)
    ArrayLength(pointer) =>
      "arrayLength(\{self.atomic_pointer_expression(function, pointer)})"
    RayQueryInitialize(query, acceleration, ray_desc) =>
      "rayQueryInitialize(\{self.required_function_expression(function, query)}, \{self.required_function_expression(function, acceleration)}, \{self.required_function_expression(function, ray_desc)})"
    RayQueryProceed(query) =>
      "rayQueryProceed(\{self.required_function_expression(function, query)})"
    RayQueryGenerateIntersection(query, intersection_t) =>
      "rayQueryGenerateIntersection(\{self.required_function_expression(function, query)}, \{self.required_function_expression(function, intersection_t)})"
    RayQueryConfirmIntersection(query) =>
      "rayQueryConfirmIntersection(\{self.required_function_expression(function, query)})"
    RayQueryTerminate(query) =>
      "rayQueryTerminate(\{self.required_function_expression(function, query)})"
    RayQueryVertexPositions(query, committed) =>
      self.ray_query_vertex_positions_expression(function, query, committed)
    RayQueryGetIntersection(query, committed) =>
      self.ray_query_get_intersection_expression(function, query, committed)
    SubgroupCall(subgroup_function, arguments) =>
      "\{wgsl_ir_emit_subgroup_function_name(subgroup_function)}(\{self.expression_list(arguments, function)})"
    CooperativeLoad(columns, rows, role, data) =>
      self.cooperative_load_expression(function, columns, rows, role, data)
    CooperativeMultiplyAdd(a, b, c) =>
      "coopMultiplyAdd(\{self.required_function_expression(function, a)}, \{self.required_function_expression(function, b)}, \{self.required_function_expression(function, c)})"
    WorkGroupUniformLoad(pointer) =>
      "workgroupUniformLoad(\{self.required_function_expression(function, pointer)})"
    Unary(op, expr) => self.unary_expression(function, op, expr)
    Binary(op, left, right) => self.binary_expression(function, op, left, right)
    Select(condition, accept, reject) =>
      "select(\{self.required_function_expression(function, reject)}, \{self.required_function_expression(function, accept)}, \{self.required_function_expression(function, condition)})"
    Bitcast(ty, expr) =>
      "bitcast<\{self.type_name(ty)}>(\{self.required_function_expression(function, expr)})"
    Derivative(axis, control, expr) =>
      "\{wgsl_ir_derivative_function_name(axis, control)}(\{self.required_function_expression(function, expr)})"
    FunctionCall(handle, arguments) =>
      "\{self.function_name(handle)}(\{self.expression_list(arguments, function)})"
    Math(math_function, a, b, c, d) =>
      "\{self.math_function_name(math_function)}(\{self.math_argument_list(a, b, c, d, function)})"
    Relational(relational_function, expr) =>
      "\{self.relational_function_name(relational_function)}(\{self.required_function_expression(function, expr)})"
    CallResult(_) => raise WgslIrEmitError::Unsupported("raw call result")
    _ => raise WgslIrEmitError::Unsupported("expression kind")
  }
}

///|
fn WgslIrEmitter::binary_expression(
  self : WgslIrEmitter,
  function : Function?,
  op : BinaryOperator,
  left : Handle,
  right : Handle,
) -> String raise WgslIrEmitError {
  let left_text = self.binary_operand_expression(function, op, left, right)
  let right_text = self.binary_operand_expression(function, op, right, left)
  "(\{left_text} \{self.binary_operator(op)} \{right_text})"
}

///|
fn WgslIrEmitter::binary_operand_expression(
  self : WgslIrEmitter,
  function : Function?,
  op : BinaryOperator,
  operand : Handle,
  sibling : Handle,
) -> String raise WgslIrEmitError {
  match self.contextual_unsigned_integer_literal(function, operand, sibling) {
    Some(text) if wgsl_ir_binary_operator_uses_integer_bits(op) => text
    _ => self.required_function_expression(function, operand)
  }
}

///|
fn wgsl_ir_binary_operator_uses_integer_bits(op : BinaryOperator) -> Bool {
  match op {
    And | ExclusiveOr | InclusiveOr | ShiftLeft | ShiftRight => true
    _ => false
  }
}

///|
fn WgslIrEmitter::contextual_unsigned_integer_literal(
  self : WgslIrEmitter,
  function : Function?,
  operand : Handle,
  sibling : Handle,
) -> String? {
  guard self.expression_scalar_kind(function, sibling) is Some(Uint) else {
    return None
  }
  let expression = match function {
    Some(function) => function.expressions.items.get(operand.index())
    None => self.shader_module.global_expressions.items.get(operand.index())
  }
  match expression {
    Some(Literal(literal)) =>
      match literal {
        AbstractInt(value) =>
          self.integer_value_literal_for_kind(Abstract(value), Uint)
        U32(value) =>
          self.integer_value_literal_for_kind(Unsigned(value), Uint)
        _ => None
      }
    _ => None
  }
}

///|
fn WgslIrEmitter::expression_scalar_kind(
  self : WgslIrEmitter,
  function : Function?,
  handle : Handle,
) -> ScalarKind? {
  match self.expression_type(function, handle) {
    Some(ty_handle) =>
      match self.shader_module.types.items.get(ty_handle.index()) {
        Some(type_) =>
          match type_.inner {
            Scalar(scalar) => Some(scalar.kind)
            _ => None
          }
        None => None
      }
    None => None
  }
}

///|
fn WgslIrEmitter::compose_expression(
  self : WgslIrEmitter,
  ty : Handle,
  components : Array[Handle],
  function : Function?,
) -> String raise WgslIrEmitError {
  match self.folded_scalar_constructor_expression(ty, components, function) {
    Some(value) => return value
    None => ()
  }
  "\{self.compose_constructor_name_for_components(ty, components, function)}(\{self.compose_component_list(ty, components, function)})"
}

///|
fn WgslIrEmitter::folded_scalar_constructor_expression(
  self : WgslIrEmitter,
  ty : Handle,
  components : Array[Handle],
  function : Function?,
) -> String? raise WgslIrEmitError {
  if !self.options.fold_numeric_constant_expressions || components.length() != 1 {
    return None
  }
  guard self.shader_module.types.items.get(ty.index()) is Some(type_) else {
    raise WgslIrEmitError::MissingHandle("type \{ty.index()}")
  }
  guard type_.inner is Scalar(target) else { return None }
  guard target.kind == Float else { return None }
  let expression = self.required_expression(function, components[0])
  match expression {
    Literal(literal) =>
      match wgsl_ir_float_value_from_numeric_literal(literal) {
        Some(value) => self.float_value_literal_for_width(value, target.width)
        None => None
      }
    Constant(handle) =>
      match self.eval_constant_float_expression_for_emit(handle, @set.Set([])) {
        Some(value) => self.float_value_literal_for_width(value, target.width)
        None =>
          match
            self.eval_constant_integer_expression_for_emit(handle, @set.Set([])) {
            Some(value) =>
              match value.to_double() {
                Some(value) =>
                  self.float_value_literal_for_width(value, target.width)
                None => None
              }
            None => None
          }
      }
    _ => None
  }
}

///|
fn wgsl_ir_float_value_from_numeric_literal(literal : Literal) -> Double? {
  match literal {
    F16(value) | F64(value) | AbstractFloat(value) => Some(value)
    F32(value) => Some(value.to_double())
    I32(value) => Some(Double::from_int(value))
    U32(value) => Some(value.to_double())
    AbstractInt(value) => Some(value.to_double())
    _ => None
  }
}

///|
fn WgslIrEmitIntegerValue::to_double(self : WgslIrEmitIntegerValue) -> Double? {
  match self {
    Signed(value) => Some(Double::from_int(value))
    Unsigned(value) => Some(value.to_double())
    Abstract(value) => Some(value.to_double())
  }
}

///|
fn WgslIrEmitter::compose_component_list(
  self : WgslIrEmitter,
  ty : Handle,
  components : Array[Handle],
  function : Function?,
) -> String raise WgslIrEmitError {
  match self.matrix_scalar_component_list(ty, components, function) {
    Some(value) => value
    None => self.expression_list(components, function)
  }
}

///|
fn WgslIrEmitter::matrix_scalar_component_list(
  self : WgslIrEmitter,
  ty : Handle,
  components : Array[Handle],
  function : Function?,
) -> String? raise WgslIrEmitError {
  if !self.options.expand_matrix_scalar_constructors {
    return None
  }
  guard self.shader_module.types.items.get(ty.index()) is Some(matrix_ty) else {
    raise WgslIrEmitError::MissingHandle("type \{ty.index()}")
  }
  guard matrix_ty.inner is Matrix(columns, rows, scalar) else { return None }
  let columns_len = columns.width()
  let rows_len = rows.width()
  if components.length() != columns_len * rows_len {
    return None
  }
  for component in components {
    if !self.expression_is_scalar_type(function, component, scalar) {
      return None
    }
  }
  let out = StringBuilder::new()
  for column_index in 0..<columns_len {
    if column_index > 0 {
      out.write_string(", ")
    }
    let column_components : Array[Handle] = []
    for row_index in 0..<rows_len {
      column_components.push(components[column_index * rows_len + row_index])
    }
    out.write_string(
      "vec\{rows_len}<\{self.scalar_name(scalar)}>(\{self.expression_list(column_components, function)})",
    )
  }
  Some(out.to_string())
}

///|
fn WgslIrEmitter::unary_expression(
  self : WgslIrEmitter,
  function : Function?,
  op : UnaryOperator,
  expr : Handle,
) -> String raise WgslIrEmitError {
  let inner = self.required_expression(function, expr)
  match (op, inner) {
    (Negate, Literal(literal)) => "-\{self.literal(literal)}"
    _ =>
      "\{self.unary_operator(op)}(\{self.required_function_expression(function, expr)})"
  }
}

///|
fn WgslIrEmitter::required_expression(
  self : WgslIrEmitter,
  function : Function?,
  handle : Handle,
) -> Expression raise WgslIrEmitError {
  match function {
    Some(function) =>
      match function.expressions.items.get(handle.index()) {
        Some(expression) => expression
        None =>
          raise WgslIrEmitError::MissingHandle(
            "function expression \{handle.index()}",
          )
      }
    None =>
      match self.shader_module.global_expressions.items.get(handle.index()) {
        Some(expression) => expression
        None =>
          raise WgslIrEmitError::MissingHandle(
            "global expression \{handle.index()}",
          )
      }
  }
}

///|
fn WgslIrEmitter::image_sample_expression(
  self : WgslIrEmitter,
  function : Function?,
  image : Handle,
  sampler : Handle,
  gather : SwizzleComponent?,
  coordinate : Handle,
  array_index : Handle?,
  offset : Handle?,
  level : SampleLevel,
  depth_ref : Handle?,
  clamp_to_edge : Bool,
) -> String raise WgslIrEmitError {
  match gather {
    Some(component) =>
      return self.image_gather_expression(
        function, image, sampler, component, coordinate, array_index, offset, depth_ref,
      )
    None => ()
  }
  if clamp_to_edge {
    if array_index != None || offset != None || depth_ref != None {
      raise WgslIrEmitError::Unsupported(
        "textureSampleBaseClampToEdge advanced arguments",
      )
    }
    let callee = "textureSampleBaseClampToEdge"
    return "\{callee}(\{self.required_function_expression(function, image)}, \{self.required_function_expression(function, sampler)}, \{self.required_function_expression(function, coordinate)})"
  }
  let callee = match depth_ref {
    Some(_) =>
      match level {
        Auto => "textureSampleCompare"
        Zero => "textureSampleCompareLevel"
        _ =>
          raise WgslIrEmitError::Unsupported(
            "texture compare sampling level mode",
          )
      }
    None =>
      match level {
        Auto => "textureSample"
        Exact(_) => "textureSampleLevel"
        Bias(_) => "textureSampleBias"
        Gradient(_, _) => "textureSampleGrad"
        Zero => "textureSampleLevel"
      }
  }
  let out = StringBuilder::new()
  out.write_string(
    "\{callee}(\{self.required_function_expression(function, image)}, \{self.required_function_expression(function, sampler)}, \{self.required_function_expression(function, coordinate)}",
  )
  match array_index {
    Some(index) =>
      out.write_string(
        ", \{self.required_function_expression(function, index)}",
      )
    None => ()
  }
  match level {
    Exact(handle) =>
      out.write_string(
        ", \{self.required_function_expression(function, handle)}",
      )
    Bias(handle) =>
      out.write_string(
        ", \{self.required_function_expression(function, handle)}",
      )
    Gradient(ddx, ddy) =>
      out.write_string(
        ", \{self.required_function_expression(function, ddx)}, \{self.required_function_expression(function, ddy)}",
      )
    Zero if depth_ref == None => out.write_string(", 0")
    _ => ()
  }
  match depth_ref {
    Some(handle) =>
      out.write_string(
        ", \{self.required_function_expression(function, handle)}",
      )
    None => ()
  }
  match offset {
    Some(handle) =>
      out.write_string(
        ", \{self.required_function_expression(function, handle)}",
      )
    None => ()
  }
  out.write_string(")")
  out.to_string()
}

///|
fn WgslIrEmitter::atomic_call_expression(
  self : WgslIrEmitter,
  function : Function?,
  atomic_function : AtomicFunction,
  arguments : Array[Handle],
) -> String raise WgslIrEmitError {
  guard arguments is [pointer, .. rest] else {
    raise WgslIrEmitError::Unsupported("atomic call without pointer")
  }
  let out = StringBuilder::new()
  let pointer_text = self.atomic_pointer_expression(function, pointer)
  out.write_string(
    "\{self.atomic_function_name(atomic_function)}(\{wgsl_ir_atomic_pointer_argument_text(pointer_text)}",
  )
  for argument in rest {
    out.write_string(
      ", \{self.required_function_expression(function, argument)}",
    )
  }
  out.write_string(")")
  out.to_string()
}

///|
fn wgsl_ir_atomic_pointer_argument_text(text : String) -> String {
  if text.length() > 0 && text[0:1] == "&" {
    "(\{text})"
  } else {
    text
  }
}

///|
fn WgslIrEmitter::atomic_pointer_expression(
  self : WgslIrEmitter,
  function : Function?,
  pointer : Handle,
) -> String raise WgslIrEmitError {
  if self.expression_is_pointer(function, pointer) {
    self.required_function_expression(function, pointer)
  } else {
    "&\{self.required_function_expression(function, pointer)}"
  }
}

///|
fn WgslIrEmitter::emit_cooperative_store_statement(
  self : WgslIrEmitter,
  out : StringBuilder,
  function : Function,
  target : Handle,
  data : CooperativeData,
  indent : Int,
) -> Unit raise WgslIrEmitError {
  let suffix = if data.row_major { "T" } else { "" }
  out.write_string(
    "\{wgsl_ir_indent(indent)}coopStore\{suffix}(\{self.function_expression(function, target)}, \{self.atomic_pointer_expression(Some(function), data.pointer)}, \{self.function_expression(function, data.stride)});\n",
  )
}

///|
fn WgslIrEmitter::cooperative_load_expression(
  self : WgslIrEmitter,
  function : Function?,
  columns : CooperativeSize,
  rows : CooperativeSize,
  role : CooperativeRole,
  data : CooperativeData,
) -> String raise WgslIrEmitError {
  let suffix = if data.row_major { "T" } else { "" }
  let scalar = match self.cooperative_data_scalar(function, data) {
    Some(scalar) => scalar
    None =>
      raise WgslIrEmitError::Unsupported("cooperative load pointer scalar type")
  }
  "coopLoad\{suffix}<coop_mat\{wgsl_ir_cooperative_size_name(columns)}x\{wgsl_ir_cooperative_size_name(rows)}<\{self.scalar_name(scalar)}, \{wgsl_ir_cooperative_role_name(role)}>>(\{self.atomic_pointer_expression(function, data.pointer)}, \{self.required_function_expression(function, data.stride)})"
}

///|
fn WgslIrEmitter::cooperative_data_scalar(
  self : WgslIrEmitter,
  function : Function?,
  data : CooperativeData,
) -> Scalar? {
  match self.expression_type(function, data.pointer) {
    Some(ty) => self.cooperative_pointer_scalar(ty)
    None => None
  }
}

///|
fn WgslIrEmitter::cooperative_pointer_scalar(
  self : WgslIrEmitter,
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
fn WgslIrEmitter::image_gather_expression(
  self : WgslIrEmitter,
  function : Function?,
  image : Handle,
  sampler : Handle,
  component : SwizzleComponent,
  coordinate : Handle,
  array_index : Handle?,
  offset : Handle?,
  depth_ref : Handle?,
) -> String raise WgslIrEmitError {
  let callee = if depth_ref != None {
    "textureGatherCompare"
  } else {
    "textureGather"
  }
  let out = StringBuilder::new()
  out.write_string("\{callee}(")
  if depth_ref == None {
    out.write_string("\{wgsl_ir_gather_component_index(component)}, ")
  }
  out.write_string(
    "\{self.required_function_expression(function, image)}, \{self.required_function_expression(function, sampler)}, \{self.required_function_expression(function, coordinate)}",
  )
  match array_index {
    Some(handle) =>
      out.write_string(
        ", \{self.required_function_expression(function, handle)}",
      )
    None => ()
  }
  match depth_ref {
    Some(handle) =>
      out.write_string(
        ", \{self.required_function_expression(function, handle)}",
      )
    None => ()
  }
  match offset {
    Some(handle) =>
      out.write_string(
        ", \{self.required_function_expression(function, handle)}",
      )
    None => ()
  }
  out.write_string(")")
  out.to_string()
}

///|
fn WgslIrEmitter::image_load_expression(
  self : WgslIrEmitter,
  function : Function?,
  image : Handle,
  coordinate : Handle,
  array_index : Handle?,
  sample : Handle?,
  level : Handle?,
) -> String raise WgslIrEmitError {
  let out = StringBuilder::new()
  out.write_string(
    "textureLoad(\{self.required_function_expression(function, image)}, \{self.required_function_expression(function, coordinate)}",
  )
  match array_index {
    Some(index) =>
      out.write_string(
        ", \{self.required_function_expression(function, index)}",
      )
    None => ()
  }
  match sample {
    Some(handle) =>
      out.write_string(
        ", \{self.required_function_expression(function, handle)}",
      )
    None => ()
  }
  match level {
    Some(handle) =>
      out.write_string(
        ", \{self.required_function_expression(function, handle)}",
      )
    None => ()
  }
  out.write_string(")")
  out.to_string()
}

///|
fn WgslIrEmitter::image_query_expression(
  self : WgslIrEmitter,
  function : Function?,
  image : Handle,
  query : ImageQuery,
) -> String raise WgslIrEmitError {
  match query {
    Size(level) => {
      let out = StringBuilder::new()
      out.write_string(
        "textureDimensions(\{self.required_function_expression(function, image)}",
      )
      match level {
        Some(handle) =>
          out.write_string(
            ", \{self.required_function_expression(function, handle)}",
          )
        None => ()
      }
      out.write_string(")")
      out.to_string()
    }
    NumLevels =>
      "textureNumLevels(\{self.required_function_expression(function, image)})"
    NumLayers =>
      "textureNumLayers(\{self.required_function_expression(function, image)})"
    NumSamples =>
      "textureNumSamples(\{self.required_function_expression(function, image)})"
  }
}

///|
fn WgslIrEmitter::ray_query_get_intersection_expression(
  self : WgslIrEmitter,
  function : Function?,
  query : Handle,
  committed : Bool,
) -> String raise WgslIrEmitError {
  let name = if committed {
    "rayQueryGetCommittedIntersection"
  } else {
    "rayQueryGetCandidateIntersection"
  }
  "\{name}(\{self.required_function_expression(function, query)})"
}

///|
fn WgslIrEmitter::ray_query_vertex_positions_expression(
  self : WgslIrEmitter,
  function : Function?,
  query : Handle,
  committed : Bool,
) -> String raise WgslIrEmitError {
  let name = if committed {
    "getCommittedHitVertexPositions"
  } else {
    "getCandidateHitVertexPositions"
  }
  "\{name}(\{self.required_function_expression(function, query)})"
}

///|
fn WgslIrEmitter::member_name_for_expression(
  self : WgslIrEmitter,
  function : Function?,
  base : Handle,
  index : Int,
) -> String raise WgslIrEmitError {
  match self.expression_type(function, base) {
    Some(ty_handle) => {
      let base_type_handle = self.deref_pointer_type_handle(ty_handle)
      match self.shader_module.types.items.get(base_type_handle.index()) {
        Some(ty) =>
          match ty.inner {
            Struct(members, _) | PredeclaredStruct(members, _) =>
              match members.get(index) {
                Some(_) =>
                  self.required_emit_name(
                    wgsl_ir_emit_name_key2(
                      "member",
                      base_type_handle.index(),
                      index,
                    ),
                  )
                None => wgsl_ir_swizzle_component(index)
              }
            _ => wgsl_ir_swizzle_component(index)
          }
        None => wgsl_ir_swizzle_component(index)
      }
    }
    None => wgsl_ir_swizzle_component(index)
  }
}

///|
fn WgslIrEmitter::deref_pointer_type_handle(
  self : WgslIrEmitter,
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
fn WgslIrEmitter::swizzle_components(
  self : WgslIrEmitter,
  components : Array[SwizzleComponent],
) -> String {
  ignore(self)
  let out = StringBuilder::new()
  for component in components {
    out.write_string(wgsl_ir_swizzle_component_name(component))
  }
  out.to_string()
}

///|
fn WgslIrEmitter::required_function_expression(
  self : WgslIrEmitter,
  function : Function?,
  handle : Handle,
) -> String raise WgslIrEmitError {
  match function {
    Some(value) => self.function_expression(value, handle)
    None => self.global_expression(handle)
  }
}

///|
fn WgslIrEmitter::expression_list(
  self : WgslIrEmitter,
  handles : Array[Handle],
  function : Function?,
) -> String raise WgslIrEmitError {
  let out = StringBuilder::new()
  for index in 0..<handles.length() {
    if index > 0 {
      out.write_string(", ")
    }
    match function {
      Some(func) =>
        out.write_string(self.function_expression(func, handles[index]))
      None => out.write_string(self.global_expression(handles[index]))
    }
  }
  out.to_string()
}

///|
fn WgslIrEmitter::math_argument_list(
  self : WgslIrEmitter,
  a : Handle,
  b : Handle?,
  c : Handle?,
  d : Handle?,
  function : Function?,
) -> String raise WgslIrEmitError {
  let handles : Array[Handle] = [a]
  match b {
    Some(value) => handles.push(value)
    None => ()
  }
  match c {
    Some(value) => handles.push(value)
    None => ()
  }
  match d {
    Some(value) => handles.push(value)
    None => ()
  }
  self.expression_list(handles, function)
}
