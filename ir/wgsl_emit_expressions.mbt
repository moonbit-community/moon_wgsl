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
    Compose(ty, components) =>
      "\{self.compose_constructor_name_for_components(ty, components, function)}(\{self.expression_list(components, function)})"
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
    Unary(op, expr) =>
      "\{self.unary_operator(op)}(\{self.required_function_expression(function, expr)})"
    Binary(op, left, right) =>
      "(\{self.required_function_expression(function, left)} \{self.binary_operator(op)} \{self.required_function_expression(function, right)})"
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
    CallResult(handle) => self.function_name(handle)
    _ => raise WgslIrEmitError::Unsupported("expression kind")
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
    Some(ty_handle) =>
      match
        self.shader_module.types.items.get(
          self.deref_pointer_type_handle(ty_handle).index(),
        ) {
        Some(ty) =>
          match ty.inner {
            Struct(members, _) | PredeclaredStruct(members, _) =>
              match members.get(index) {
                Some(struct_member) =>
                  match struct_member.name {
                    Some(name) => sanitize_wgsl_ir_identifier(name)
                    None => wgsl_ir_swizzle_component(index)
                  }
                None => wgsl_ir_swizzle_component(index)
              }
            _ => wgsl_ir_swizzle_component(index)
          }
        None => wgsl_ir_swizzle_component(index)
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
fn WgslIrEmitter::expression_type(
  self : WgslIrEmitter,
  function : Function?,
  handle : Handle,
) -> Handle? {
  match function {
    Some(function) =>
      match function.expressions.items.get(handle.index()) {
        Some(expression) =>
          self.function_expression_inner_type(function, expression)
        None => None
      }
    None =>
      match self.shader_module.global_expressions.items.get(handle.index()) {
        Some(expression) => self.global_expression_inner_type(expression)
        None => None
      }
  }
}

///|
fn WgslIrEmitter::function_expression_inner_type(
  self : WgslIrEmitter,
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
        Some(ty) => Some(self.deref_pointer_type_handle(ty))
        None => None
      }
    Compose(ty, _) | ZeroValue(ty) => Some(ty)
    AccessIndex(base, index) =>
      self.indexed_expression_type(Some(function), base, Some(index))
    Access(base, _) => self.indexed_expression_type(Some(function), base, None)
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
      self.math_expression_result_type(Some(function), math_function, a)
    Relational(relational_function, expr) =>
      self.relational_expression_result_type(
        Some(function),
        relational_function,
        expr,
      )
    AtomicCall(atomic_function, arguments) =>
      self.atomic_expression_result_type(
        Some(function),
        atomic_function,
        arguments,
      )
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
fn WgslIrEmitter::cooperative_matrix_type_handle(
  self : WgslIrEmitter,
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
          return Some(Handle::Handle(index))
        }
      _ => ()
    }
  }
  None
}

///|
fn WgslIrEmitter::type_handle_named(
  self : WgslIrEmitter,
  name : String,
) -> Handle? {
  for index in 0..<self.shader_module.types.items.length() {
    match self.shader_module.types.items[index].name {
      Some(existing) if existing == name => return Some(Handle::Handle(index))
      _ => ()
    }
  }
  None
}

///|
fn WgslIrEmitter::global_expression_inner_type(
  self : WgslIrEmitter,
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
        Some(ty) => Some(self.deref_pointer_type_handle(ty))
        None => None
      }
    Compose(ty, _) | ZeroValue(ty) => Some(ty)
    AccessIndex(base, index) =>
      self.indexed_expression_type(None, base, Some(index))
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
    Math(math_function, a, _, _, _) =>
      self.math_expression_result_type(None, math_function, a)
    Relational(relational_function, expr) =>
      self.relational_expression_result_type(None, relational_function, expr)
    AtomicCall(atomic_function, arguments) =>
      self.atomic_expression_result_type(None, atomic_function, arguments)
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
fn WgslIrEmitter::literal_type(
  self : WgslIrEmitter,
  literal : Literal,
) -> Handle? {
  match literal {
    Bool(_) => self.type_handle_named("bool")
    I32(_) => self.type_handle_named("i32")
    AbstractInt(_) => self.type_handle_named("__abstract_int")
    U32(_) => self.type_handle_named("u32")
    F16(_) => self.type_handle_named("f16")
    F32(_) => self.type_handle_named("f32")
    F64(_) => self.type_handle_named("f64")
    AbstractFloat(_) => self.type_handle_named("__abstract_float")
    _ => None
  }
}

///|
fn WgslIrEmitter::subgroup_expression_result_type(
  self : WgslIrEmitter,
  function : Function?,
  subgroup_function : SubgroupFunction,
  arguments : Array[Handle],
) -> Handle? {
  match subgroup_function {
    Ballot => self.find_vector_type(Quad, Scalar::Scalar(Uint, 4))
    All | Any => self.type_handle_named("bool")
    _ =>
      match arguments.get(0) {
        Some(first) => self.expression_type(function, first)
        None => None
      }
  }
}

///|
fn wgsl_ir_emit_subgroup_function_name(function : SubgroupFunction) -> String {
  match function {
    Ballot => "subgroupBallot"
    All => "subgroupAll"
    Any => "subgroupAny"
    Add => "subgroupAdd"
    Mul => "subgroupMul"
    Max => "subgroupMax"
    Min => "subgroupMin"
    And => "subgroupAnd"
    Or => "subgroupOr"
    Xor => "subgroupXor"
    ExclusiveAdd => "subgroupExclusiveAdd"
    ExclusiveMul => "subgroupExclusiveMul"
    InclusiveAdd => "subgroupInclusiveAdd"
    InclusiveMul => "subgroupInclusiveMul"
    BroadcastFirst => "subgroupBroadcastFirst"
    Broadcast => "subgroupBroadcast"
    Shuffle => "subgroupShuffle"
    ShuffleDown => "subgroupShuffleDown"
    ShuffleUp => "subgroupShuffleUp"
    ShuffleXor => "subgroupShuffleXor"
    QuadBroadcast => "quadBroadcast"
    QuadSwapX => "quadSwapX"
    QuadSwapY => "quadSwapY"
    QuadSwapDiagonal => "quadSwapDiagonal"
  }
}

///|
fn WgslIrEmitter::image_expression_result_type(
  self : WgslIrEmitter,
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
          self.find_vector_type(Quad, Scalar::Scalar(kind, 4))
        Image(_, _, Depth(_)) =>
          if gather != None {
            self.find_vector_type(Quad, Scalar::Scalar(Float, 4))
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
        Image(_, _, External) =>
          self.find_vector_type(Quad, Scalar::Scalar(Float, 4))
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrEmitter::image_query_expression_result_type(
  self : WgslIrEmitter,
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
fn WgslIrEmitter::image_dimension_size_type_handle(
  self : WgslIrEmitter,
  dimension : ImageDimension,
) -> Handle? {
  match dimension {
    D1 => self.type_handle_named("u32")
    D2 | Cube => self.type_handle_named("vec2<u32>")
    D3 => self.type_handle_named("vec3<u32>")
  }
}

///|
fn WgslIrEmitter::indexed_expression_type(
  self : WgslIrEmitter,
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
fn WgslIrEmitter::indexed_type_from_type_handle(
  self : WgslIrEmitter,
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
fn WgslIrEmitter::swizzle_expression_type(
  self : WgslIrEmitter,
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
fn WgslIrEmitter::find_vector_scalar_type(
  self : WgslIrEmitter,
  scalar : Scalar,
) -> Handle? {
  let scalar_inner = TypeInner::Scalar(scalar)
  for i in 0..<self.shader_module.types.items.length() {
    if self.shader_module.types.items[i].inner == scalar_inner {
      return Some(Handle::Handle(i))
    }
  }
  None
}

///|
fn WgslIrEmitter::find_vector_type(
  self : WgslIrEmitter,
  size : VectorSize,
  scalar : Scalar,
) -> Handle? {
  let vector_inner = TypeInner::Vector(size, scalar)
  for i in 0..<self.shader_module.types.items.length() {
    if self.shader_module.types.items[i].inner == vector_inner {
      return Some(Handle::Handle(i))
    }
  }
  None
}

///|
fn WgslIrEmitter::math_expression_result_type(
  self : WgslIrEmitter,
  function : Function?,
  math_function : MathFunction,
  argument : Handle,
) -> Handle? {
  guard self.expression_type(function, argument) is Some(input_ty) else {
    return None
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
      self.find_vector_type(Quad, Scalar::Scalar(Float, 4))
    Unpack2x16snorm | Unpack2x16unorm | Unpack2x16float =>
      self.find_vector_type(Bi, Scalar::Scalar(Float, 4))
    Unpack4xI8 => self.find_vector_type(Quad, Scalar::Scalar(Sint, 4))
    Unpack4xU8 => self.find_vector_type(Quad, Scalar::Scalar(Uint, 4))
    Dot | Distance | Length | Determinant =>
      self.scalar_type_from_composite_type(input_ty)
    Transpose => self.transpose_expression_result_type(input_ty)
    _ => Some(input_ty)
  }
}

///|
fn WgslIrEmitter::transpose_expression_result_type(
  self : WgslIrEmitter,
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
fn WgslIrEmitter::scalar_type_from_composite_type(
  self : WgslIrEmitter,
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
fn WgslIrEmitter::relational_expression_result_type(
  self : WgslIrEmitter,
  function : Function?,
  relational_function : RelationalFunction,
  argument : Handle,
) -> Handle? {
  match relational_function {
    All | Any => self.find_scalar_type(Scalar::Scalar(Bool, 1))
    IsNan | IsInf =>
      match self.expression_type(function, argument) {
        Some(input_ty) => self.boolean_result_type(input_ty, input_ty)
        None => None
      }
  }
}

///|
fn WgslIrEmitter::binary_expression_result_type(
  self : WgslIrEmitter,
  op : BinaryOperator,
  left_ty : Handle,
  right_ty : Handle,
) -> Handle? {
  if wgsl_ir_binary_operator_is_comparison(op) {
    return self.boolean_result_type(left_ty, right_ty)
  }
  if op == BinaryOperator::Multiply {
    match self.matrix_vector_multiply_result_type(left_ty, right_ty) {
      Some(ty) => return Some(ty)
      None => ()
    }
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
fn WgslIrEmitter::matrix_vector_multiply_result_type(
  self : WgslIrEmitter,
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
fn WgslIrEmitter::find_matrix_type(
  self : WgslIrEmitter,
  columns : VectorSize,
  rows : VectorSize,
  scalar : Scalar,
) -> Handle? {
  let matrix_inner = TypeInner::Matrix(columns, rows, scalar)
  for i in 0..<self.shader_module.types.items.length() {
    if self.shader_module.types.items[i].inner == matrix_inner {
      return Some(Handle::Handle(i))
    }
  }
  None
}

///|
fn WgslIrEmitter::boolean_result_type(
  self : WgslIrEmitter,
  left_ty : Handle,
  right_ty : Handle,
) -> Handle? {
  match self.vector_size_from_type(left_ty) {
    Some(size) => self.find_vector_type(size, Scalar::Scalar(Bool, 1))
    None =>
      match self.vector_size_from_type(right_ty) {
        Some(size) => self.find_vector_type(size, Scalar::Scalar(Bool, 1))
        None => self.find_scalar_type(Scalar::Scalar(Bool, 1))
      }
  }
}

///|
fn WgslIrEmitter::type_is_scalar(
  self : WgslIrEmitter,
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
fn WgslIrEmitter::vector_size_from_type(
  self : WgslIrEmitter,
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
fn WgslIrEmitter::find_scalar_type(
  self : WgslIrEmitter,
  scalar : Scalar,
) -> Handle? {
  let scalar_inner = TypeInner::Scalar(scalar)
  for i in 0..<self.shader_module.types.items.length() {
    if self.shader_module.types.items[i].inner == scalar_inner {
      return Some(Handle::Handle(i))
    }
  }
  None
}

///|
fn WgslIrEmitter::predeclared_numeric_result_type(
  self : WgslIrEmitter,
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
            Some(PredeclaredType::FrexpResult(None, scalar))
          }
        Vector(size, scalar) =>
          if math_function == Modf {
            Some(PredeclaredType::ModfResult(Some(size), scalar))
          } else {
            Some(PredeclaredType::FrexpResult(Some(size), scalar))
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
fn WgslIrEmitter::atomic_expression_result_type(
  self : WgslIrEmitter,
  function : Function?,
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
fn WgslIrEmitter::atomic_pointer_scalar_type(
  self : WgslIrEmitter,
  function : Function?,
  pointer : Handle,
) -> Scalar? {
  guard self.expression_type(function, pointer) is Some(ty_handle) else {
    return None
  }
  self.atomic_scalar_type_from_handle(ty_handle)
}

///|
fn WgslIrEmitter::atomic_scalar_type_from_handle(
  self : WgslIrEmitter,
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
fn WgslIrEmitter::predeclared_type_handle(
  self : WgslIrEmitter,
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
