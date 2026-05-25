///|
fn WgslIrEmitter::emit_block_statements(
  self : WgslIrEmitter,
  out : StringBuilder,
  function : Function,
  body_plan : WgslIrNagaFunctionBodyPlan,
  block : Block,
  indent : Int,
) -> Unit raise WgslIrEmitError {
  let plan = body_plan.statement_plan(function, block)
  let mut index = 0
  while index < plan.length() {
    let item = plan[index]
    if item.skip {
      index = index + 1
      continue
    }
    if item.blank_before {
      out.write_string("\n")
    }
    let consumed_next = self.emit_statement_with_following_context(
      out,
      function,
      body_plan,
      item.statement,
      plan.get(index + 1),
      indent,
    )
    index = if consumed_next { index + 2 } else { index + 1 }
  }
}

///|
fn WgslIrEmitter::emit_statement_with_following_context(
  self : WgslIrEmitter,
  out : StringBuilder,
  function : Function,
  body_plan : WgslIrNagaFunctionBodyPlan,
  statement : Statement,
  following : WgslIrNagaStatementPlanItem?,
  indent : Int,
) -> Bool raise WgslIrEmitError {
  match (statement, following) {
    (
      Switch(selector, cases),
      Some({ statement: ImplicitReturn, skip: false, .. }),
    ) =>
      if wgsl_ir_switch_can_absorb_implicit_return(cases) {
        self.emit_switch_statement(
          out, function, body_plan, selector, cases, true, indent,
        )
        true
      } else {
        self.emit_statement(out, function, body_plan, statement, indent)
        false
      }
    (
      If(condition, accept, reject),
      Some({ statement: ImplicitReturn, skip: false, .. }),
    ) => {
      self.emit_if_statement(
        out, function, body_plan, condition, accept, reject, true, indent,
      )
      true
    }
    _ => {
      self.emit_statement(out, function, body_plan, statement, indent)
      false
    }
  }
}

///|
fn WgslIrEmitter::emit_statement(
  self : WgslIrEmitter,
  out : StringBuilder,
  function : Function,
  body_plan : WgslIrNagaFunctionBodyPlan,
  statement : Statement,
  indent : Int,
) -> Unit raise WgslIrEmitError {
  let pad = wgsl_ir_indent(indent)
  match statement {
    Declare(handle) =>
      self.emit_local_declaration(out, function, handle, indent)
    Emit(range) =>
      for index in range.start.index()..<=range.end.index() {
        let handle = Handle::Handle(index)
        let expr = self.function_expression(function, handle)
        if self.expression_type(Some(function), handle) == None &&
          !self.function_expression_requires_phony_assignment(function, handle) {
          out.write_string("\{pad}\{expr};\n")
        } else {
          out.write_string("\{pad}_ = \{expr};\n")
        }
      }
    Block(child) => {
      out.write_string("\{pad}{\n")
      self.emit_block_statements(out, function, body_plan, child, indent + 1)
      out.write_string("\{pad}}\n")
    }
    If(condition, accept, reject) =>
      self.emit_if_statement(
        out, function, body_plan, condition, accept, reject, false, indent,
      )
    Loop(body, continuing, break_if) => {
      out.write_string("\{pad}loop {\n")
      self.emit_block_statements(out, function, body_plan, body, indent + 1)
      let has_break_if = match break_if {
        Some(_) => true
        None => false
      }
      if !continuing.statements.is_empty() || has_break_if {
        out.write_string("\{wgsl_ir_indent(indent + 1)}continuing {\n")
        self.emit_block_statements(
          out,
          function,
          body_plan,
          continuing,
          indent + 2,
        )
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
    Switch(selector, cases) =>
      self.emit_switch_statement(
        out, function, body_plan, selector, cases, false, indent,
      )
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
    ImplicitReturn => out.write_string("\{pad}return;\n")
    Kill => out.write_string("\{pad}discard;\n")
    ConstAssert(condition) =>
      out.write_string(
        "\{pad}const_assert \{self.abstract_float_function_expression(function, condition)};\n",
      )
    ControlBarrier(barrier) =>
      self.emit_control_barrier_statement(out, barrier, indent)
    MemoryBarrier(barrier) =>
      self.emit_memory_barrier_statement(out, barrier, indent)
    Store(pointer, value) =>
      out.write_string(
        "\{pad}\{self.function_store_pointer_expression(function, pointer)} = \{self.function_store_value_expression(function, pointer, value)};\n",
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
    ImageAtomic(image, coordinate, array_index, atomic_function, value) => {
      out.write_string(
        "\{pad}\{self.texture_atomic_function_name(atomic_function)}(\{self.function_expression(function, image)}, \{self.function_expression(function, coordinate)}",
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
        Some(result_handle) => {
          let ty = match self.expression_type(Some(function), result_handle) {
            Some(value) => value
            None =>
              raise WgslIrEmitError::MissingHandle(
                "call result type \{result_handle.index()}",
              )
          }
          out.write_string(
            "\{pad}let \{self.function_expression_temporary_name(result_handle)}: \{self.type_name(ty)} = ",
          )
        }
        None => out.write_string(pad)
      }
      out.write_string("\{self.function_name(function_handle)}(")
      self.emit_function_call_arguments(
        out, function, function_handle, arguments,
      )
      out.write_string(");\n")
    }
    RayQuery(query, query_function) =>
      self.emit_ray_query_statement(
        out, function, query, query_function, indent,
      )
    CooperativeStore(target, data) =>
      self.emit_cooperative_store_statement(out, function, target, data, indent)
    _ => raise WgslIrEmitError::Unsupported("statement kind")
  }
}

///|
fn WgslIrEmitter::emit_if_statement(
  self : WgslIrEmitter,
  out : StringBuilder,
  function : Function,
  body_plan : WgslIrNagaFunctionBodyPlan,
  condition : Handle,
  accept : Block,
  reject : Block,
  absorb_implicit_return : Bool,
  indent : Int,
) -> Unit raise WgslIrEmitError {
  let pad = wgsl_ir_indent(indent)
  out.write_string(
    "\{pad}if \{self.function_expression(function, condition)} {\n",
  )
  self.emit_block_statements(out, function, body_plan, accept, indent + 1)
  if absorb_implicit_return && !wgsl_ir_block_ends_with_return(accept) {
    out.write_string("\{wgsl_ir_indent(indent + 1)}return;\n")
  }
  out.write_string("\{pad}}")
  if reject.statements.is_empty() && !absorb_implicit_return {
    out.write_string("\n")
  } else {
    out.write_string(" else {\n")
    self.emit_block_statements(out, function, body_plan, reject, indent + 1)
    if absorb_implicit_return && !wgsl_ir_block_ends_with_return(reject) {
      out.write_string("\{wgsl_ir_indent(indent + 1)}return;\n")
    }
    out.write_string("\{pad}}\n")
  }
}

///|
fn WgslIrEmitter::function_store_value_expression(
  self : WgslIrEmitter,
  function : Function,
  pointer : Handle,
  value : Handle,
) -> String raise WgslIrEmitError {
  let scalar_context = if self.options.contextualize_numeric_literals() {
    match self.expression_type(Some(function), pointer) {
      Some(pointer_ty) => {
        let value_ty = self.deref_pointer_type_handle(pointer_ty)
        self.store_numeric_literal_context(value_ty)
      }
      None => None
    }
  } else {
    None
  }
  self.contextual_argument_expression(Some(function), value, scalar_context)
}

///|
fn WgslIrEmitter::store_numeric_literal_context(
  self : WgslIrEmitter,
  value_ty : Handle,
) -> Scalar? {
  match self.shader_module.types.items.get(value_ty.index()) {
    Some(type_) =>
      match type_.inner {
        Scalar(scalar) | Vector(_, scalar) => Some(scalar)
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrEmitter::function_expression_requires_phony_assignment(
  self : WgslIrEmitter,
  function : Function,
  handle : Handle,
) -> Bool {
  ignore(self)
  match function.expressions.items.get(handle.index()) {
    Some(expression) =>
      match expression {
        ImageSample(_, _, _, _, _, _, _, _, _)
        | ImageLoad(_, _, _, _, _)
        | ImageQuery(_, _)
        | WorkGroupUniformLoad(_)
        | SubgroupCall(_, _) => true
        _ => false
      }
    None => false
  }
}

///|
fn WgslIrEmitter::emit_switch_statement(
  self : WgslIrEmitter,
  out : StringBuilder,
  function : Function,
  body_plan : WgslIrNagaFunctionBodyPlan,
  selector : Handle,
  cases : Array[SwitchCase],
  absorb_implicit_return : Bool,
  indent : Int,
) -> Unit raise WgslIrEmitError {
  let pad = wgsl_ir_indent(indent)
  out.write_string(
    "\{pad}switch \{self.function_expression(function, selector)} {\n",
  )
  for case in cases {
    out.write_string(
      "\{wgsl_ir_indent(indent + 1)}\{wgsl_ir_switch_case_label(case.value)}: {\n",
    )
    self.emit_block_statements(out, function, body_plan, case.body, indent + 2)
    if absorb_implicit_return && !wgsl_ir_block_ends_with_return(case.body) {
      out.write_string("\{wgsl_ir_indent(indent + 2)}return;\n")
    }
    out.write_string("\{wgsl_ir_indent(indent + 1)}}\n")
  }
  out.write_string("\{pad}}\n")
}

///|
fn wgsl_ir_switch_can_absorb_implicit_return(cases : Array[SwitchCase]) -> Bool {
  let mut has_default = false
  for case in cases {
    if case.fall_through {
      return false
    }
    match case.value {
      Default => has_default = true
      _ => ()
    }
  }
  has_default
}

///|
fn WgslIrEmitter::function_store_pointer_expression(
  self : WgslIrEmitter,
  function : Function,
  handle : Handle,
) -> String raise WgslIrEmitError {
  let expression = match function.expressions.items.get(handle.index()) {
    Some(value) => value
    None =>
      raise WgslIrEmitError::MissingHandle(
        "function store pointer expression \{handle.index()}",
      )
  }
  let text = self.function_pointer_expression(function, handle)
  match expression {
    Access(_, _) | AccessIndex(_, _) | Component(_, _) | Swizzle(_, _, _) =>
      text
    _ =>
      match self.expression_type(Some(function), handle) {
        Some(ty) =>
          match self.shader_module.types.items.get(ty.index()) {
            Some(type_) =>
              match type_.inner {
                Pointer(_, _) => self.options.pointer_dereference_text(text)
                _ => text
              }
            None => text
          }
        None => text
      }
  }
}

///|
fn WgslIrEmitter::emit_control_barrier_statement(
  self : WgslIrEmitter,
  out : StringBuilder,
  barrier : Barrier,
  indent : Int,
) -> Unit raise WgslIrEmitError {
  let pad = wgsl_ir_indent(indent)
  if barrier == Barrier::work_group() {
    out.write_string("\{pad}workgroupBarrier();\n")
  } else if barrier == Barrier::sub_group() {
    out.write_string("\{pad}subgroupBarrier();\n")
  } else {
    ignore(self)
    raise WgslIrEmitError::Unsupported("control barrier flags")
  }
}

///|
fn WgslIrEmitter::emit_memory_barrier_statement(
  self : WgslIrEmitter,
  out : StringBuilder,
  barrier : Barrier,
  indent : Int,
) -> Unit raise WgslIrEmitError {
  let pad = wgsl_ir_indent(indent)
  if barrier == Barrier::storage() {
    out.write_string("\{pad}storageBarrier();\n")
  } else if barrier == Barrier::texture() {
    out.write_string("\{pad}textureBarrier();\n")
  } else {
    ignore(self)
    raise WgslIrEmitError::Unsupported("memory barrier flags")
  }
}

///|
fn WgslIrEmitter::emit_ray_query_statement(
  self : WgslIrEmitter,
  out : StringBuilder,
  function : Function,
  query : Handle,
  query_function : RayQueryFunction,
  indent : Int,
) -> Unit raise WgslIrEmitError {
  let pad = wgsl_ir_indent(indent)
  match query_function {
    Initialize(acceleration, ray_desc) =>
      out.write_string(
        "\{pad}rayQueryInitialize(\{self.function_expression(function, query)}, \{self.function_expression(function, acceleration)}, \{self.function_expression(function, ray_desc)});\n",
      )
    Proceed(_) =>
      out.write_string(
        "\{pad}rayQueryProceed(\{self.function_expression(function, query)});\n",
      )
    GenerateIntersection(intersection_t) =>
      out.write_string(
        "\{pad}rayQueryGenerateIntersection(\{self.function_expression(function, query)}, \{self.function_expression(function, intersection_t)});\n",
      )
    ConfirmIntersection =>
      out.write_string(
        "\{pad}rayQueryConfirmIntersection(\{self.function_expression(function, query)});\n",
      )
    Terminate =>
      out.write_string(
        "\{pad}rayQueryTerminate(\{self.function_expression(function, query)});\n",
      )
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
  callee : Handle,
  arguments : Array[Handle],
) -> Unit raise WgslIrEmitError {
  let callee_function = self.shader_module.functions.items.get(callee.index())
  for index in 0..<arguments.length() {
    if index > 0 {
      out.write_string(", ")
    }
    let scalar_context = if self.options.contextualize_numeric_literals() {
      match callee_function {
        Some(callee_function) =>
          match callee_function.arguments.get(index) {
            Some(argument) => self.type_component_scalar(argument.ty)
            None => None
          }
        None => None
      }
    } else {
      None
    }
    out.write_string(
      self.contextual_argument_expression(
        Some(function),
        arguments[index],
        scalar_context,
      ),
    )
  }
}
