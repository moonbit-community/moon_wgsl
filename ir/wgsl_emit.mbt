///|
pub suberror WgslIrEmitError {
  MissingHandle(String)
  MissingName(String)
  Unsupported(String)
}

///|
pub fn WgslIrEmitError::message(self : WgslIrEmitError) -> String {
  match self {
    MissingHandle(message) => "missing IR handle: \{message}"
    MissingName(message) => "missing IR name: \{message}"
    Unsupported(message) => "unsupported IR emission: \{message}"
  }
}

///|
pub fn emit_wgsl_module_from_ir(
  shader_module : Module,
) -> String raise WgslIrEmitError {
  validate_wgsl_ir_module(shader_module) catch {
    error => raise WgslIrEmitError::Unsupported(error.message())
  }
  let emitter = WgslIrEmitter::{ shader_module, }
  emitter.emit_module()
}

///|
priv struct WgslIrEmitter {
  shader_module : Module
}

///|
fn WgslIrEmitter::emit_module(
  self : WgslIrEmitter,
) -> String raise WgslIrEmitError {
  let out = StringBuilder::new()
  let mut needs_blank = false
  for index in 0..<self.shader_module.types.items.length() {
    let ty = self.shader_module.types.items[index]
    match ty.inner {
      Struct(_, _) => {
        if needs_blank {
          out.write_string("\n")
        }
        self.emit_struct_type(out, ty)
        needs_blank = true
      }
      _ => ()
    }
  }
  for index in 0..<self.shader_module.constants.items.length() {
    if needs_blank {
      out.write_string("\n")
    }
    self.emit_constant(out, self.shader_module.constants.items[index])
    needs_blank = true
  }
  for index in 0..<self.shader_module.overrides.items.length() {
    if needs_blank {
      out.write_string("\n")
    }
    self.emit_override(out, self.shader_module.overrides.items[index])
    needs_blank = true
  }
  for index in 0..<self.shader_module.global_variables.items.length() {
    if needs_blank {
      out.write_string("\n")
    }
    self.emit_global_variable(
      out,
      self.shader_module.global_variables.items[index],
    )
    needs_blank = true
  }
  for index in 0..<self.shader_module.functions.items.length() {
    if needs_blank {
      out.write_string("\n")
    }
    self.emit_function(out, self.shader_module.functions.items[index], None)
    needs_blank = true
  }
  for entry_point in self.shader_module.entry_points {
    if needs_blank {
      out.write_string("\n")
    }
    self.emit_entry_point(out, entry_point)
    needs_blank = true
  }
  out.to_string()
}

///|
fn WgslIrEmitter::emit_struct_type(
  self : WgslIrEmitter,
  out : StringBuilder,
  ty : Type,
) -> Unit raise WgslIrEmitError {
  guard ty.name is Some(name) else {
    raise WgslIrEmitError::MissingName("struct type")
  }
  guard ty.inner is Struct(members, _) else {
    raise WgslIrEmitError::Unsupported(
      "non-struct type passed to struct emitter",
    )
  }
  out.write_string("struct \{name} {\n")
  for struct_member in members {
    out.write_string("  ")
    self.emit_binding_attribute_prefix(out, struct_member.binding)
    let member_name = match struct_member.name {
      Some(value) => value
      None => raise WgslIrEmitError::MissingName("struct member")
    }
    out.write_string("\{member_name}: \{self.type_name(struct_member.ty)},\n")
  }
  out.write_string("}\n")
}

///|
fn WgslIrEmitter::emit_constant(
  self : WgslIrEmitter,
  out : StringBuilder,
  constant : Constant,
) -> Unit raise WgslIrEmitError {
  guard constant.name is Some(name) else {
    raise WgslIrEmitError::MissingName("constant")
  }
  if self.type_is_abstract_scalar(constant.ty) {
    out.write_string(
      "const \{name} = \{self.global_expression(constant.init)};\n",
    )
  } else {
    out.write_string(
      "const \{name}: \{self.type_name(constant.ty)} = \{self.global_expression(constant.init)};\n",
    )
  }
}

///|
fn WgslIrEmitter::emit_override(
  self : WgslIrEmitter,
  out : StringBuilder,
  override_ : Override,
) -> Unit raise WgslIrEmitError {
  match override_.id {
    Some(id) => out.write_string("@id(\{id}) ")
    None => ()
  }
  guard override_.name is Some(name) else {
    raise WgslIrEmitError::MissingName("override")
  }
  out.write_string("override \{name}: \{self.type_name(override_.ty)}")
  match override_.init {
    Some(init) => out.write_string(" = \{self.global_expression(init)}")
    None => ()
  }
  out.write_string(";\n")
}

///|
fn WgslIrEmitter::emit_global_variable(
  self : WgslIrEmitter,
  out : StringBuilder,
  global : GlobalVariable,
) -> Unit raise WgslIrEmitError {
  match global.binding {
    Some(binding) =>
      out.write_string(
        "@group(\{binding.group}) @binding(\{binding.binding})\n",
      )
    None => ()
  }
  guard global.name is Some(name) else {
    raise WgslIrEmitError::MissingName("global variable")
  }
  let space = self.address_space_template(global.space)
  out.write_string("var\{space} \{name}: \{self.type_name(global.ty)}")
  match global.init {
    Some(init) => out.write_string(" = \{self.global_expression(init)}")
    None => ()
  }
  out.write_string(";\n")
}

///|
fn WgslIrEmitter::type_is_pointer(
  self : WgslIrEmitter,
  handle : Handle,
) -> Bool {
  match self.shader_module.types.get(handle) {
    Some(ty) =>
      match ty.inner {
        Pointer(_, _) | ValuePointer(_, _, _) => true
        _ => false
      }
    None => false
  }
}

///|
fn WgslIrEmitter::type_is_abstract_scalar(
  self : WgslIrEmitter,
  handle : Handle,
) -> Bool {
  match self.shader_module.types.get(handle) {
    Some(ty) =>
      match ty.inner {
        Scalar(scalar) =>
          scalar.kind == AbstractInt || scalar.kind == AbstractFloat
        _ => false
      }
    None => false
  }
}

///|
fn WgslIrEmitter::emit_entry_point(
  self : WgslIrEmitter,
  out : StringBuilder,
  entry_point : EntryPoint,
) -> Unit raise WgslIrEmitError {
  out.write_string(self.stage_attribute(entry_point.stage))
  if entry_point.stage == Compute {
    match entry_point.workgroup_size {
      [x, y, z, ..] => out.write_string(" @workgroup_size(\{x}, \{y}, \{z})")
      [x, y] => out.write_string(" @workgroup_size(\{x}, \{y}, 1)")
      [x] => out.write_string(" @workgroup_size(\{x}, 1, 1)")
      [] => out.write_string(" @workgroup_size(1, 1, 1)")
    }
  }
  out.write_string("\n")
  self.emit_function(out, entry_point.function, Some(entry_point.name))
}

///|
fn WgslIrEmitter::emit_function(
  self : WgslIrEmitter,
  out : StringBuilder,
  function : Function,
  name_override : String?,
) -> Unit raise WgslIrEmitError {
  let name = match name_override {
    Some(value) => value
    None =>
      match function.name {
        Some(value) => value
        None => raise WgslIrEmitError::MissingName("function")
      }
  }
  out.write_string("fn \{name}(")
  for index in 0..<function.arguments.length() {
    if index > 0 {
      out.write_string(", ")
    }
    self.emit_function_argument(out, function.arguments[index], index)
  }
  out.write_string(")")
  match function.result {
    Some(result) => {
      out.write_string(" -> ")
      self.emit_binding_attribute_prefix(out, result.binding)
      out.write_string(self.type_name(result.ty))
    }
    None => ()
  }
  out.write_string(" {\n")
  self.emit_function_locals(out, function)
  self.emit_block_statements(out, function, function.body, 1)
  out.write_string("}\n")
}

///|
fn WgslIrEmitter::emit_function_argument(
  self : WgslIrEmitter,
  out : StringBuilder,
  argument : FunctionArgument,
  index : Int,
) -> Unit raise WgslIrEmitError {
  self.emit_binding_attribute_prefix(out, argument.binding)
  let name = match argument.name {
    Some(value) => value
    None => "arg\{index}"
  }
  out.write_string("\{name}: \{self.type_name(argument.ty)}")
}

///|
fn WgslIrEmitter::emit_function_locals(
  self : WgslIrEmitter,
  out : StringBuilder,
  function : Function,
) -> Unit raise WgslIrEmitError {
  for index in 0..<function.local_variables.items.length() {
    let local_var = function.local_variables.items[index]
    let name = match local_var.name {
      Some(value) => value
      None => "local\{index}"
    }
    out.write_string("  \{self.local_variable_keyword(local_var.kind)} \{name}")
    if !self.type_is_abstract_scalar(local_var.ty) {
      out.write_string(": \{self.type_name(local_var.ty)}")
    }
    match local_var.init {
      Some(init) =>
        if self.type_is_pointer(local_var.ty) {
          out.write_string(
            " = &\{self.function_pointer_expression(function, init)}",
          )
        } else {
          out.write_string(" = \{self.function_expression(function, init)}")
        }
      None => ()
    }
    out.write_string(";\n")
  }
}

///|
fn WgslIrEmitter::local_variable_keyword(
  self : WgslIrEmitter,
  kind : LocalVariableKind,
) -> String {
  ignore(self)
  match kind {
    Var => "var"
    Let => "let"
    Const => "const"
  }
}

///|
fn WgslIrEmitter::emit_block_statements(
  self : WgslIrEmitter,
  out : StringBuilder,
  function : Function,
  block : Block,
  indent : Int,
) -> Unit raise WgslIrEmitError {
  for statement in block.statements {
    self.emit_statement(out, function, statement, indent)
  }
}

///|
fn WgslIrEmitter::emit_statement(
  self : WgslIrEmitter,
  out : StringBuilder,
  function : Function,
  statement : Statement,
  indent : Int,
) -> Unit raise WgslIrEmitError {
  let pad = wgsl_ir_indent(indent)
  match statement {
    Emit(range) =>
      for index in range.start.index()..<=range.end.index() {
        out.write_string(
          "\{pad}_ = \{self.function_expression(function, Handle::new(index))};\n",
        )
      }
    Block(child) => {
      out.write_string("\{pad}{\n")
      self.emit_block_statements(out, function, child, indent + 1)
      out.write_string("\{pad}}\n")
    }
    If(condition, accept, reject) => {
      out.write_string(
        "\{pad}if (\{self.function_expression(function, condition)}) {\n",
      )
      self.emit_block_statements(out, function, accept, indent + 1)
      out.write_string("\{pad}}")
      if reject.statements.is_empty() {
        out.write_string("\n")
      } else {
        out.write_string(" else {\n")
        self.emit_block_statements(out, function, reject, indent + 1)
        out.write_string("\{pad}}\n")
      }
    }
    Loop(body, continuing, break_if) => {
      out.write_string("\{pad}loop {\n")
      self.emit_block_statements(out, function, body, indent + 1)
      let has_break_if = match break_if {
        Some(_) => true
        None => false
      }
      if !continuing.statements.is_empty() || has_break_if {
        out.write_string("\{wgsl_ir_indent(indent + 1)}continuing {\n")
        self.emit_block_statements(out, function, continuing, indent + 2)
        match break_if {
          Some(condition) =>
            out.write_string(
              "\{wgsl_ir_indent(indent + 2)}break if \{self.function_expression(function, condition)};\n",
            )
          None => ()
        }
        out.write_string("\{wgsl_ir_indent(indent + 1)}}\n")
      }
      out.write_string("\{pad}}\n")
    }
    Switch(selector, cases) => {
      out.write_string(
        "\{pad}switch \{self.function_expression(function, selector)} {\n",
      )
      for case in cases {
        out.write_string(
          "\{wgsl_ir_indent(indent + 1)}\{wgsl_ir_switch_case_label(case.value)} {\n",
        )
        self.emit_block_statements(out, function, case.body, indent + 2)
        out.write_string("\{wgsl_ir_indent(indent + 1)}}\n")
      }
      out.write_string("\{pad}}\n")
    }
    Break => out.write_string("\{pad}break;\n")
    Continue => out.write_string("\{pad}continue;\n")
    Return(value) =>
      match value {
        Some(handle) =>
          out.write_string(
            "\{pad}return \{self.function_expression(function, handle)};\n",
          )
        None => out.write_string("\{pad}return;\n")
      }
    Kill => out.write_string("\{pad}discard;\n")
    Store(pointer, value) =>
      out.write_string(
        "\{pad}\{self.function_pointer_expression(function, pointer)} = \{self.function_expression(function, value)};\n",
      )
    ImageStore(image, coordinate, array_index, value) => {
      out.write_string(
        "\{pad}textureStore(\{self.function_expression(function, image)}, \{self.function_expression(function, coordinate)}",
      )
      match array_index {
        Some(index) =>
          out.write_string(", \{self.function_expression(function, index)}")
        None => ()
      }
      out.write_string(", \{self.function_expression(function, value)});\n")
    }
    Call(function_handle, arguments, result) => {
      match result {
        Some(_) =>
          raise WgslIrEmitError::Unsupported(
            "call statement with result handle",
          )
        None => ()
      }
      out.write_string("\{pad}\{self.function_name(function_handle)}(")
      self.emit_function_call_arguments(out, function, arguments)
      out.write_string(");\n")
    }
    _ => raise WgslIrEmitError::Unsupported("statement kind")
  }
}

///|
fn wgsl_ir_switch_case_label(value : SwitchValue) -> String {
  match value {
    I32(value) => "case \{value}i"
    U32(value) => "case \{value}u"
    Default => "default"
  }
}

///|
fn WgslIrEmitter::emit_function_call_arguments(
  self : WgslIrEmitter,
  out : StringBuilder,
  function : Function,
  arguments : Array[Handle],
) -> Unit raise WgslIrEmitError {
  for index in 0..<arguments.length() {
    if index > 0 {
      out.write_string(", ")
    }
    out.write_string(self.function_expression(function, arguments[index]))
  }
}

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
fn WgslIrEmitter::emit_expression(
  self : WgslIrEmitter,
  expression : Expression,
  function : Function?,
) -> String raise WgslIrEmitError {
  match expression {
    Literal(literal) => self.literal(literal)
    Constant(handle) => self.constant_name(handle)
    Override(handle) => self.override_name(handle)
    ZeroValue(ty) => "\{self.type_name(ty)}()"
    Compose(ty, components) =>
      "\{self.type_name(ty)}(\{self.expression_list(components, function)})"
    Access(base, index) =>
      "\{self.required_function_expression(function, base)}[\{self.required_function_expression(function, index)}]"
    AccessIndex(base, index) =>
      "\{self.required_function_expression(function, base)}.\{self.member_name_for_expression(function, base, index)}"
    Swizzle(_, base, components) =>
      "\{self.required_function_expression(function, base)}.\{self.swizzle_components(components)}"
    FunctionArgument(index) => self.function_argument_name(function, index)
    GlobalVariable(handle) => self.global_variable_name(handle)
    LocalVariable(handle) => self.local_variable_name(function, handle)
    Load(pointer) => self.required_function_expression(function, pointer)
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
    Unary(op, expr) =>
      "\{self.unary_operator(op)}\{self.required_function_expression(function, expr)}"
    Binary(op, left, right) =>
      "(\{self.required_function_expression(function, left)} \{self.binary_operator(op)} \{self.required_function_expression(function, right)})"
    FunctionCall(handle, arguments) =>
      "\{self.function_name(handle)}(\{self.expression_list(arguments, function)})"
    Math(math_function, a, b, c, d) =>
      "\{self.math_function_name(math_function)}(\{self.math_argument_list(a, b, c, d, function)})"
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
  let depth = self.expression_is_depth_image(function, image)
  let callee = if depth_ref != None {
    "textureGatherCompare"
  } else {
    "textureGather"
  }
  let out = StringBuilder::new()
  out.write_string("\{callee}(")
  if !depth {
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
fn WgslIrEmitter::expression_is_depth_image(
  self : WgslIrEmitter,
  function : Function?,
  handle : Handle,
) -> Bool {
  match self.expression_type(function, handle) {
    Some(ty_handle) =>
      match self.shader_module.types.get(ty_handle) {
        Some(ty) =>
          match ty.inner {
            Image(_, _, Depth(_)) => true
            _ => false
          }
        None => false
      }
    None => false
  }
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
      match self.shader_module.types.items.get(ty_handle.index()) {
        Some(ty) =>
          match ty.inner {
            Struct(members, _) =>
              match members.get(index) {
                Some(struct_member) =>
                  match struct_member.name {
                    Some(name) => name
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
    Load(inner) => self.expression_type(Some(function), inner)
    Compose(ty, _) | ZeroValue(ty) => Some(ty)
    AccessIndex(base, index) =>
      self.indexed_expression_type(Some(function), base, Some(index))
    Access(base, _) => self.indexed_expression_type(Some(function), base, None)
    Swizzle(size, base, _) =>
      self.swizzle_expression_type(Some(function), base, size)
    Unary(_, inner) => self.expression_type(Some(function), inner)
    Binary(_, left, _) => self.expression_type(Some(function), left)
    FunctionCall(handle, _) =>
      match self.shader_module.functions.items.get(handle.index()) {
        Some(callee) =>
          match callee.result {
            Some(result) => Some(result.ty)
            None => None
          }
        None => None
      }
    Math(_, a, _, _, _) => self.expression_type(Some(function), a)
    _ => None
  }
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
    Load(inner) => self.expression_type(None, inner)
    Compose(ty, _) | ZeroValue(ty) => Some(ty)
    AccessIndex(base, index) =>
      self.indexed_expression_type(None, base, Some(index))
    Access(base, _) => self.indexed_expression_type(None, base, None)
    Swizzle(size, base, _) => self.swizzle_expression_type(None, base, size)
    Unary(_, inner) => self.expression_type(None, inner)
    Binary(_, left, _) => self.expression_type(None, left)
    _ => None
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
  match self.shader_module.types.items.get(base_ty.index()) {
    Some(ty) =>
      match ty.inner {
        Struct(members, _) =>
          match index {
            Some(i) =>
              match members.get(i) {
                Some(struct_member) => Some(struct_member.ty)
                None => None
              }
            None => None
          }
        Vector(_, scalar) => self.find_vector_scalar_type(scalar)
        Array(element, _, _) | BindingArray(element, _) => Some(element)
        Pointer(inner, _) => Some(inner)
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
      return Some(Handle::new(i))
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
      return Some(Handle::new(i))
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

///|
fn WgslIrEmitter::type_name(
  self : WgslIrEmitter,
  handle : Handle,
) -> String raise WgslIrEmitError {
  let ty = match self.shader_module.types.items.get(handle.index()) {
    Some(value) => value
    None => raise WgslIrEmitError::MissingHandle("type \{handle.index()}")
  }
  match ty.name {
    Some(name) =>
      match ty.inner {
        Scalar(_) => name
        Struct(_, _) => name
        _ => self.type_inner_name(ty.inner)
      }
    None => self.type_inner_name(ty.inner)
  }
}

///|
fn WgslIrEmitter::type_inner_name(
  self : WgslIrEmitter,
  inner : TypeInner,
) -> String raise WgslIrEmitError {
  match inner {
    Scalar(scalar) => self.scalar_name(scalar)
    Vector(size, scalar) => "vec\{size.width()}<\{self.scalar_name(scalar)}>"
    Matrix(columns, rows, scalar) =>
      "mat\{columns.width()}x\{rows.width()}<\{self.scalar_name(scalar)}>"
    Atomic(scalar) => "atomic<\{self.scalar_name(scalar)}>"
    Pointer(base, space) =>
      "ptr<\{self.address_space_name(space)}, \{self.type_name(base)}>"
    Array(base, size, _) =>
      match size {
        Constant(value) => "array<\{self.type_name(base)}, \{value}>"
        Dynamic => "array<\{self.type_name(base)}>"
        Pending(_) => raise WgslIrEmitError::Unsupported("pending array size")
      }
    Struct(_, _) => raise WgslIrEmitError::Unsupported("anonymous struct type")
    Image(dimension, arrayed, image_class) =>
      self.image_type_name(dimension, arrayed, image_class)
    Sampler(comparison) =>
      if comparison {
        "sampler_comparison"
      } else {
        "sampler"
      }
    BindingArray(base, size) =>
      match size {
        Constant(value) => "binding_array<\{self.type_name(base)}, \{value}>"
        Dynamic => "binding_array<\{self.type_name(base)}>"
        Pending(_) =>
          raise WgslIrEmitError::Unsupported("pending binding array size")
      }
    _ => raise WgslIrEmitError::Unsupported("type kind")
  }
}

///|
fn WgslIrEmitter::image_type_name(
  self : WgslIrEmitter,
  dimension : ImageDimension,
  arrayed : Bool,
  image_class : ImageClass,
) -> String {
  match image_class {
    Sampled(kind, multisampled) => {
      let prefix = if multisampled { "texture_multisampled" } else { "texture" }
      "\{prefix}_\{self.image_dimension_suffix(dimension, arrayed)}<\{self.scalar_kind_name(kind)}>"
    }
    Depth(multisampled) => {
      let prefix = if multisampled {
        "texture_depth_multisampled"
      } else {
        "texture_depth"
      }
      "\{prefix}_\{self.image_dimension_suffix(dimension, arrayed)}"
    }
    External => "texture_external"
    Storage(format, access) =>
      "texture_storage_\{self.image_dimension_suffix(dimension, arrayed)}<\{self.storage_format_name(format)}, \{self.storage_access_name(access)}>"
  }
}

///|
fn WgslIrEmitter::image_dimension_suffix(
  self : WgslIrEmitter,
  dimension : ImageDimension,
  arrayed : Bool,
) -> String {
  ignore(self)
  let base = match dimension {
    D1 => "1d"
    D2 => "2d"
    D3 => "3d"
    Cube => "cube"
  }
  if arrayed {
    "\{base}_array"
  } else {
    base
  }
}

///|
fn WgslIrEmitter::scalar_name(self : WgslIrEmitter, scalar : Scalar) -> String {
  ignore(self)
  match scalar.kind {
    Bool => "bool"
    Sint => if scalar.width == 8 { "i64" } else { "i32" }
    Uint => if scalar.width == 8 { "u64" } else { "u32" }
    Float => if scalar.width == 2 { "f16" } else { "f32" }
    AbstractInt => "abstract-int"
    AbstractFloat => "abstract-float"
  }
}

///|
fn WgslIrEmitter::scalar_kind_name(
  self : WgslIrEmitter,
  kind : ScalarKind,
) -> String {
  ignore(self)
  match kind {
    Sint => "i32"
    Uint => "u32"
    Float => "f32"
    Bool => "bool"
    AbstractInt => "i32"
    AbstractFloat => "f32"
  }
}

///|
fn WgslIrEmitter::address_space_template(
  self : WgslIrEmitter,
  space : AddressSpace,
) -> String {
  match space {
    Private => "<private>"
    WorkGroup => "<workgroup>"
    Uniform => "<uniform>"
    Storage(access) => "<storage, \{self.storage_access_name(access)}>"
    Handle => ""
    Function => "<function>"
    Immediate => "<immediate>"
    TaskPayload => "<task_payload>"
    RayPayload => "<ray_payload>"
    IncomingRayPayload => "<incoming_ray_payload>"
  }
}

///|
fn WgslIrEmitter::address_space_name(
  self : WgslIrEmitter,
  space : AddressSpace,
) -> String {
  ignore(self)
  match space {
    Function => "function"
    Private => "private"
    WorkGroup => "workgroup"
    Uniform => "uniform"
    Storage(_) => "storage"
    Handle => "handle"
    Immediate => "immediate"
    TaskPayload => "task_payload"
    RayPayload => "ray_payload"
    IncomingRayPayload => "incoming_ray_payload"
  }
}

///|
fn WgslIrEmitter::storage_access_name(
  self : WgslIrEmitter,
  access : StorageAccess,
) -> String {
  ignore(self)
  if access.contains(StorageAccess::load()) &&
    access.contains(StorageAccess::store()) {
    "read_write"
  } else if access.contains(StorageAccess::store()) {
    "write"
  } else {
    "read"
  }
}

///|
fn WgslIrEmitter::stage_attribute(
  self : WgslIrEmitter,
  stage : ShaderStage,
) -> String raise WgslIrEmitError {
  ignore(self)
  match stage {
    Vertex => "@vertex"
    Fragment => "@fragment"
    Compute => "@compute"
    _ => raise WgslIrEmitError::Unsupported("shader stage")
  }
}

///|
fn WgslIrEmitter::emit_binding_attribute_prefix(
  self : WgslIrEmitter,
  out : StringBuilder,
  binding : Binding?,
) -> Unit raise WgslIrEmitError {
  match binding {
    Some(BuiltIn(builtin)) =>
      out.write_string("@builtin(\{self.builtin_name(builtin)}) ")
    Some(Location(location, interpolation, sampling, _, _)) => {
      out.write_string("@location(\{location}) ")
      match interpolation {
        Some(value) => {
          out.write_string("@interpolate(\{self.interpolation_name(value)}")
          match sampling {
            Some(sampling_value) =>
              out.write_string(", \{self.sampling_name(sampling_value)}")
            None => ()
          }
          out.write_string(") ")
        }
        None => ()
      }
    }
    None => ()
  }
}

///|
fn WgslIrEmitter::builtin_name(
  self : WgslIrEmitter,
  builtin : BuiltIn,
) -> String raise WgslIrEmitError {
  ignore(self)
  match builtin {
    Position(_) => "position"
    VertexIndex => "vertex_index"
    InstanceIndex => "instance_index"
    FrontFacing => "front_facing"
    FragDepth => "frag_depth"
    SampleIndex => "sample_index"
    SampleMask => "sample_mask"
    GlobalInvocationId => "global_invocation_id"
    LocalInvocationId => "local_invocation_id"
    LocalInvocationIndex => "local_invocation_index"
    WorkGroupId => "workgroup_id"
    NumWorkGroups => "num_workgroups"
    _ => raise WgslIrEmitError::Unsupported("builtin")
  }
}

///|
fn WgslIrEmitter::interpolation_name(
  self : WgslIrEmitter,
  interpolation : Interpolation,
) -> String {
  ignore(self)
  match interpolation {
    Perspective => "perspective"
    Linear => "linear"
    Flat => "flat"
    PerVertex => "per_vertex"
  }
}

///|
fn WgslIrEmitter::sampling_name(
  self : WgslIrEmitter,
  sampling : Sampling,
) -> String {
  ignore(self)
  match sampling {
    Center => "center"
    Centroid => "centroid"
    Sample => "sample"
    First => "first"
    Either => "either"
  }
}

///|
fn WgslIrEmitter::literal(self : WgslIrEmitter, literal : Literal) -> String {
  ignore(self)
  match literal {
    F64(value) => "\{value}"
    F32(value) => "\{value}"
    F16Bits(value) => "\{value}h"
    U16(value) => "\{value}u"
    I16(value) => "\{value}"
    U32(value) => "\{value}u"
    I32(value) => "\{value}"
    U64(value) => "\{value}u"
    I64(value) => "\{value}"
    Bool(value) => if value { "true" } else { "false" }
    AbstractInt(value) => "\{value}"
    AbstractFloat(value) => "\{value}"
  }
}

///|
fn WgslIrEmitter::constant_name(
  self : WgslIrEmitter,
  handle : Handle,
) -> String raise WgslIrEmitError {
  match self.shader_module.constants.items.get(handle.index()) {
    Some(constant) =>
      match constant.name {
        Some(name) => name
        None => raise WgslIrEmitError::MissingName("constant \{handle.index()}")
      }
    None => raise WgslIrEmitError::MissingHandle("constant \{handle.index()}")
  }
}

///|
fn WgslIrEmitter::override_name(
  self : WgslIrEmitter,
  handle : Handle,
) -> String raise WgslIrEmitError {
  match self.shader_module.overrides.items.get(handle.index()) {
    Some(override_) =>
      match override_.name {
        Some(name) => name
        None => raise WgslIrEmitError::MissingName("override \{handle.index()}")
      }
    None => raise WgslIrEmitError::MissingHandle("override \{handle.index()}")
  }
}

///|
fn WgslIrEmitter::global_variable_name(
  self : WgslIrEmitter,
  handle : Handle,
) -> String raise WgslIrEmitError {
  match self.shader_module.global_variables.items.get(handle.index()) {
    Some(global) =>
      match global.name {
        Some(name) => name
        None =>
          raise WgslIrEmitError::MissingName(
            "global variable \{handle.index()}",
          )
      }
    None =>
      raise WgslIrEmitError::MissingHandle("global variable \{handle.index()}")
  }
}

///|
fn WgslIrEmitter::function_name(
  self : WgslIrEmitter,
  handle : Handle,
) -> String raise WgslIrEmitError {
  match self.shader_module.functions.items.get(handle.index()) {
    Some(function) =>
      match function.name {
        Some(name) => name
        None => raise WgslIrEmitError::MissingName("function \{handle.index()}")
      }
    None => raise WgslIrEmitError::MissingHandle("function \{handle.index()}")
  }
}

///|
fn WgslIrEmitter::function_argument_name(
  self : WgslIrEmitter,
  function : Function?,
  index : Int,
) -> String raise WgslIrEmitError {
  ignore(self)
  guard function is Some(func) else {
    raise WgslIrEmitError::Unsupported("function argument outside function")
  }
  match func.arguments.get(index) {
    Some(argument) =>
      match argument.name {
        Some(name) => name
        None => "arg\{index}"
      }
    None => raise WgslIrEmitError::MissingHandle("function argument \{index}")
  }
}

///|
fn WgslIrEmitter::local_variable_name(
  self : WgslIrEmitter,
  function : Function?,
  handle : Handle,
) -> String raise WgslIrEmitError {
  ignore(self)
  guard function is Some(func) else {
    raise WgslIrEmitError::Unsupported("local variable outside function")
  }
  match func.local_variables.items.get(handle.index()) {
    Some(local_var) =>
      match local_var.name {
        Some(name) => name
        None => "local\{handle.index()}"
      }
    None =>
      raise WgslIrEmitError::MissingHandle("local variable \{handle.index()}")
  }
}

///|
fn WgslIrEmitter::unary_operator(
  self : WgslIrEmitter,
  op : UnaryOperator,
) -> String {
  ignore(self)
  match op {
    Negate => "-"
    LogicalNot => "!"
    BitwiseNot => "~"
  }
}

///|
fn WgslIrEmitter::binary_operator(
  self : WgslIrEmitter,
  op : BinaryOperator,
) -> String {
  ignore(self)
  match op {
    Add => "+"
    Subtract => "-"
    Multiply => "*"
    Divide => "/"
    Modulo => "%"
    Equal => "=="
    NotEqual => "!="
    Less => "<"
    LessEqual => "<="
    Greater => ">"
    GreaterEqual => ">="
    And => "&"
    ExclusiveOr => "^"
    InclusiveOr => "|"
    LogicalAnd => "&&"
    LogicalOr => "||"
    ShiftLeft => "<<"
    ShiftRight => ">>"
  }
}

///|
fn WgslIrEmitter::math_function_name(
  self : WgslIrEmitter,
  math_function : MathFunction,
) -> String raise WgslIrEmitError {
  ignore(self)
  match math_function {
    Abs => "abs"
    Min => "min"
    Max => "max"
    Clamp => "clamp"
    Saturate => "saturate"
    Cos => "cos"
    Sin => "sin"
    Tan => "tan"
    Acos => "acos"
    Asin => "asin"
    Atan => "atan"
    Atan2 => "atan2"
    Ceil => "ceil"
    Floor => "floor"
    Round => "round"
    Fract => "fract"
    Trunc => "trunc"
    Exp => "exp"
    Exp2 => "exp2"
    Log => "log"
    Log2 => "log2"
    Pow => "pow"
    Dot => "dot"
    Cross => "cross"
    Distance => "distance"
    Length => "length"
    Normalize => "normalize"
    FaceForward => "faceForward"
    Reflect => "reflect"
    Refract => "refract"
    Sign => "sign"
    Fma => "fma"
    Mix => "mix"
    Step => "step"
    SmoothStep => "smoothstep"
    Sqrt => "sqrt"
    InverseSqrt => "inverseSqrt"
    Transpose => "transpose"
    Determinant => "determinant"
    CountTrailingZeros => "countTrailingZeros"
    CountLeadingZeros => "countLeadingZeros"
    CountOneBits => "countOneBits"
    ReverseBits => "reverseBits"
    ExtractBits => "extractBits"
    InsertBits => "insertBits"
    FirstTrailingBit => "firstTrailingBit"
    FirstLeadingBit => "firstLeadingBit"
    _ => raise WgslIrEmitError::Unsupported("math function")
  }
}

///|
fn WgslIrEmitter::storage_format_name(
  self : WgslIrEmitter,
  format : StorageFormat,
) -> String {
  ignore(self)
  match format {
    R8Unorm => "r8unorm"
    R8Snorm => "r8snorm"
    R8Uint => "r8uint"
    R8Sint => "r8sint"
    R16Uint => "r16uint"
    R16Sint => "r16sint"
    R16Float => "r16float"
    Rg8Unorm => "rg8unorm"
    Rg8Snorm => "rg8snorm"
    Rg8Uint => "rg8uint"
    Rg8Sint => "rg8sint"
    R32Uint => "r32uint"
    R32Sint => "r32sint"
    R32Float => "r32float"
    Rg16Uint => "rg16uint"
    Rg16Sint => "rg16sint"
    Rg16Float => "rg16float"
    Rgba8Unorm => "rgba8unorm"
    Rgba8Snorm => "rgba8snorm"
    Rgba8Uint => "rgba8uint"
    Rgba8Sint => "rgba8sint"
    Bgra8Unorm => "bgra8unorm"
    Rgb10a2Uint => "rgb10a2uint"
    Rgb10a2Unorm => "rgb10a2unorm"
    Rg11b10Ufloat => "rg11b10ufloat"
    R64Uint => "r64uint"
    Rg32Uint => "rg32uint"
    Rg32Sint => "rg32sint"
    Rg32Float => "rg32float"
    Rgba16Uint => "rgba16uint"
    Rgba16Sint => "rgba16sint"
    Rgba16Float => "rgba16float"
    Rgba32Uint => "rgba32uint"
    Rgba32Sint => "rgba32sint"
    Rgba32Float => "rgba32float"
    R16Unorm => "r16unorm"
    R16Snorm => "r16snorm"
    Rg16Unorm => "rg16unorm"
    Rg16Snorm => "rg16snorm"
    Rgba16Unorm => "rgba16unorm"
    Rgba16Snorm => "rgba16snorm"
  }
}

///|
fn wgsl_ir_swizzle_component(index : Int) -> String raise WgslIrEmitError {
  match index {
    0 => "x"
    1 => "y"
    2 => "z"
    3 => "w"
    _ => raise WgslIrEmitError::Unsupported("access index \{index}")
  }
}

///|
fn wgsl_ir_gather_component_index(component : SwizzleComponent) -> Int {
  match component {
    X => 0
    Y => 1
    Z => 2
    W => 3
  }
}

///|
fn wgsl_ir_swizzle_component_name(component : SwizzleComponent) -> String {
  match component {
    X => "x"
    Y => "y"
    Z => "z"
    W => "w"
  }
}

///|
fn wgsl_ir_indent(count : Int) -> String {
  let out = StringBuilder::new()
  for _ in 0..<count {
    out.write_string("  ")
  }
  out.to_string()
}
