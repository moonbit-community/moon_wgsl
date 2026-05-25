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
  match self.optional_function_expression_temporary_name(handle) {
    Some(name) => return name
    None => ()
  }
  self.function_expression_inline(function, handle)
}

///|
fn WgslIrEmitter::function_expression_inline(
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
  match expression {
    CallResult(_) =>
      raise WgslIrEmitError::Unsupported(
        "raw call result \{handle.index()} without arena temporary name",
      )
    _ => self.emit_expression(expression, Some(function))
  }
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
    self.options.pointer_dereference_text(expression)
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
    Access(_, _) | AccessIndex(_, _) | Component(_, _) | Swizzle(_, _, _) =>
      false
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
  if self.expression_is_pointer(function, base) {
    return "(*\{expression})"
  }
  let needs_parens = match function {
    Some(function) =>
      match function.expressions.items.get(base.index()) {
        Some(Load(inner)) =>
          self.load_expression_requires_explicit_deref(Some(function), inner)
        _ => false
      }
    None =>
      match self.shader_module.global_expressions.items.get(base.index()) {
        Some(Load(inner)) =>
          self.load_expression_requires_explicit_deref(None, inner)
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
    Splat(size, inner) => self.splat_expression(function, size, inner)
    Access(base, index) =>
      match
        self.folded_static_constant_array_access_by_index_expression(
          function, base, index,
        ) {
        Some(value) => value
        None =>
          "\{self.access_base_expression(function, base)}[\{self.access_index_operand_expression(function, index)}]"
      }
    AccessIndex(base, index) =>
      self.access_index_expression(function, base, index)
    Component(base, component) =>
      "\{self.access_base_expression(function, base)}.\{wgsl_ir_swizzle_component(wgsl_ir_gather_component_index(component))}"
    Swizzle(_, base, components) =>
      "\{self.access_base_expression(function, base)}.\{self.swizzle_components(components)}"
    FunctionArgument(index) => self.function_argument_name(function, index)
    GlobalVariable(handle) => self.global_variable_name(handle)
    LocalVariable(handle) => self.local_variable_name(function, handle)
    Load(pointer) => self.load_expression(function, pointer)
    AddressOf(_, target) =>
      match function {
        Some(func) =>
          self.options.address_of_text(
            self.function_pointer_expression(func, target),
          )
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
      "arrayLength(\{self.pointer_builtin_argument_expression(function, pointer)})"
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
      self.select_expression(function, condition, accept, reject)
    Bitcast(ty, expr) =>
      "bitcast<\{self.type_name(ty)}>(\{self.required_function_expression(function, expr)})"
    Derivative(axis, control, expr) =>
      "\{wgsl_ir_derivative_function_name(axis, control)}(\{self.required_function_expression(function, expr)})"
    FunctionCall(handle, arguments) =>
      "\{self.function_name(handle)}(\{self.function_call_argument_list(handle, arguments, function)})"
    Math(math_function, a, b, c, d) =>
      self.math_expression(function, math_function, a, b, c, d)
    Relational(relational_function, expr) =>
      "\{self.relational_function_name(relational_function)}(\{self.required_function_expression(function, expr)})"
    CallResult(_) => raise WgslIrEmitError::Unsupported("raw call result")
    _ => raise WgslIrEmitError::Unsupported("expression kind")
  }
}

///|
fn WgslIrEmitter::math_expression(
  self : WgslIrEmitter,
  function : Function?,
  math_function : MathFunction,
  a : Handle,
  b : Handle?,
  c : Handle?,
  d : Handle?,
) -> String raise WgslIrEmitError {
  match self.folded_float_math_expression(function, math_function, a, b, c, d) {
    Some(value) => value
    None =>
      "\{self.math_function_name(math_function)}(\{self.math_argument_list(math_function, a, b, c, d, function)})"
  }
}

///|
fn WgslIrEmitter::folded_float_math_expression(
  self : WgslIrEmitter,
  function : Function?,
  math_function : MathFunction,
  a : Handle,
  b : Handle?,
  c : Handle?,
  d : Handle?,
) -> String? raise WgslIrEmitError {
  guard self.options.fold_numeric_constant_expressions() else { return None }
  guard b == None && c == None && d == None else { return None }
  guard math_function == MathFunction::Sqrt else { return None }
  match self.eval_float_expression_with_retained_constants(function, a) {
    Some(value) => self.float_value_literal_for_width(value.sqrt(), 4)
    None =>
      match self.eval_float_expression_for_writer(function, a) {
        Some(value) => self.float_value_literal_for_width(value.sqrt(), 4)
        None => None
      }
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
  let left_text = self.binary_operand_expression(
    function, op, left, right, false,
  )
  let right_text = self.binary_operand_expression(
    function, op, right, left, true,
  )
  "(\{left_text} \{self.binary_operator(op)} \{right_text})"
}

///|
fn WgslIrEmitter::binary_operand_expression(
  self : WgslIrEmitter,
  function : Function?,
  op : BinaryOperator,
  operand : Handle,
  sibling : Handle,
  is_right_operand : Bool,
) -> String raise WgslIrEmitError {
  if is_right_operand && (op == ShiftLeft || op == ShiftRight) {
    return self.required_function_expression(function, operand)
  }
  if wgsl_ir_binary_operator_uses_numeric_argument_context(op) &&
    self.options.contextualize_numeric_literals() {
    match self.binary_operand_scalar_context(function, operand, sibling) {
      Some(scalar) =>
        match self.contextual_scalar_literal(function, operand, scalar) {
          Some(text) => return text
          None => ()
        }
      None => ()
    }
  }
  self.required_function_expression(function, operand)
}

///|
fn WgslIrEmitter::binary_operand_scalar_context(
  self : WgslIrEmitter,
  function : Function?,
  operand : Handle,
  sibling : Handle,
) -> Scalar? {
  match self.expression_component_scalar(function, sibling) {
    Some(scalar) if !wgsl_ir_scalar_kind_is_abstract(scalar.kind) =>
      return Some(scalar)
    _ => ()
  }
  match self.expression_component_scalar(function, operand) {
    Some(scalar) if !wgsl_ir_scalar_kind_is_abstract(scalar.kind) =>
      Some(scalar)
    _ => None
  }
}

///|
fn wgsl_ir_binary_operator_uses_numeric_argument_context(
  op : BinaryOperator,
) -> Bool {
  match op {
    Add
    | Subtract
    | Multiply
    | Divide
    | Modulo
    | Equal
    | NotEqual
    | Less
    | LessEqual
    | Greater
    | GreaterEqual
    | And
    | ExclusiveOr
    | InclusiveOr
    | ShiftLeft
    | ShiftRight => true
    _ => false
  }
}

///|
fn WgslIrEmitter::select_expression(
  self : WgslIrEmitter,
  function : Function?,
  condition : Handle,
  accept : Handle,
  reject : Handle,
) -> String raise WgslIrEmitError {
  let scalar_context = if self.options.contextualize_numeric_literals() {
    self.select_scalar_context(function, accept, reject)
  } else {
    None
  }
  let reject_text = self.contextual_argument_expression(
    function, reject, scalar_context,
  )
  let accept_text = self.contextual_argument_expression(
    function, accept, scalar_context,
  )
  let condition_text = self.required_function_expression(function, condition)
  "select(\{reject_text}, \{accept_text}, \{condition_text})"
}

///|
fn WgslIrEmitter::select_scalar_context(
  self : WgslIrEmitter,
  function : Function?,
  accept : Handle,
  reject : Handle,
) -> Scalar? {
  let accept_scalar = self.expression_component_scalar(function, accept)
  let reject_scalar = self.expression_component_scalar(function, reject)
  match (accept_scalar, reject_scalar) {
    (Some(scalar), _) if !wgsl_ir_scalar_kind_is_abstract(scalar.kind) =>
      Some(scalar)
    (_, Some(scalar)) if !wgsl_ir_scalar_kind_is_abstract(scalar.kind) =>
      Some(scalar)
    (Some(left), Some(right)) if wgsl_ir_select_abstract_operands_are_float(
        left.kind,
        right.kind,
      ) => Some(Scalar::Scalar(Float, 4))
    (Some(scalar), _) => Some(scalar)
    (_, Some(scalar)) => Some(scalar)
    _ => None
  }
}

///|
fn wgsl_ir_select_abstract_operands_are_float(
  left : ScalarKind,
  right : ScalarKind,
) -> Bool {
  (left == AbstractFloat && right == AbstractInt) ||
  (left == AbstractInt && right == AbstractFloat) ||
  (left == AbstractFloat && right == AbstractFloat)
}

///|
fn wgsl_ir_scalar_kind_is_abstract(kind : ScalarKind) -> Bool {
  match kind {
    AbstractInt | AbstractFloat => true
    _ => false
  }
}

///|
fn WgslIrEmitter::function_call_argument_list(
  self : WgslIrEmitter,
  callee : Handle,
  arguments : Array[Handle],
  function : Function?,
) -> String raise WgslIrEmitError {
  let out = StringBuilder::new()
  let callee_function = self.shader_module.functions.items.get(callee.index())
  for i in 0..<arguments.length() {
    if i > 0 {
      out.write_string(", ")
    }
    let scalar_context = if self.options.contextualize_numeric_literals() {
      match callee_function {
        Some(callee_function) =>
          match callee_function.arguments.get(i) {
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
        function,
        arguments[i],
        scalar_context,
      ),
    )
  }
  out.to_string()
}

///|
fn WgslIrEmitter::contextual_argument_expression(
  self : WgslIrEmitter,
  function : Function?,
  argument : Handle,
  scalar_context : Scalar?,
) -> String raise WgslIrEmitError {
  match scalar_context {
    Some(scalar) =>
      match self.contextual_scalar_literal(function, argument, scalar) {
        Some(value) => value
        None => self.required_function_expression(function, argument)
      }
    None => self.required_function_expression(function, argument)
  }
}

///|
fn WgslIrEmitter::expression_component_scalar(
  self : WgslIrEmitter,
  function : Function?,
  handle : Handle,
) -> Scalar? {
  match self.expression_type(function, handle) {
    Some(ty_handle) => self.type_component_scalar(ty_handle)
    None => None
  }
}

///|
fn WgslIrEmitter::type_component_scalar(
  self : WgslIrEmitter,
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
fn WgslIrEmitter::splat_expression(
  self : WgslIrEmitter,
  function : Function?,
  size : VectorSize,
  inner : Handle,
) -> String raise WgslIrEmitError {
  let value = match
    self.constructor_component_folded_expression(function, inner) {
    Some(value) => value
    None => self.required_function_expression(function, inner)
  }
  "vec\{size.width()}(\{value})"
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
fn WgslIrEmitter::compose_component_list(
  self : WgslIrEmitter,
  ty : Handle,
  components : Array[Handle],
  function : Function?,
) -> String raise WgslIrEmitError {
  match self.matrix_scalar_component_list(ty, components, function) {
    Some(value) => value
    None => {
      let out = StringBuilder::new()
      let scalar_context = if self.options.contextualize_numeric_literals() {
        self.compose_component_scalar_context(ty, components, function)
      } else {
        None
      }
      for i in 0..<components.length() {
        if i > 0 {
          out.write_string(", ")
        }
        out.write_string(
          self.compose_component_expression(
            function,
            components[i],
            scalar_context,
          ),
        )
      }
      out.to_string()
    }
  }
}

///|
fn WgslIrEmitter::contextual_scalar_literal(
  self : WgslIrEmitter,
  function : Function?,
  operand : Handle,
  scalar : Scalar,
) -> String? raise WgslIrEmitError {
  if self.options.fold_numeric_constant_expressions() {
    match self.folded_expression_for_scalar_context(function, operand, scalar) {
      Some(value) => return Some(value)
      None => ()
    }
  }
  let expression = match function {
    Some(function) => function.expressions.items.get(operand.index())
    None => self.shader_module.global_expressions.items.get(operand.index())
  }
  match expression {
    Some(Literal(literal)) => self.literal_for_scalar_context(literal, scalar)
    Some(Unary(UnaryOperator::Negate, inner)) =>
      match self.required_expression(function, inner) {
        Literal(literal) =>
          match wgsl_ir_negate_literal(literal) {
            Some(negated) => self.literal_for_scalar_context(negated, scalar)
            None => None
          }
        _ => None
      }
    Some(Splat(size, inner)) =>
      match self.contextual_scalar_literal(function, inner, scalar) {
        Some(value) => Some("vec\{size.width()}(\{value})")
        None => None
      }
    Some(Compose(ty, components)) => {
      match
        self.folded_scalar_constructor_expression(ty, components, function) {
        Some(value) => return Some(value)
        None => ()
      }
      let out = StringBuilder::new()
      for i in 0..<components.length() {
        if i > 0 {
          out.write_string(", ")
        }
        out.write_string(
          self.compose_component_expression(
            function,
            components[i],
            Some(scalar),
          ),
        )
      }
      Some(
        "\{self.compose_constructor_name_for_components(ty, components, function)}(\{out.to_string()})",
      )
    }
    _ => None
  }
}

///|
fn WgslIrEmitter::folded_expression_for_scalar_context(
  self : WgslIrEmitter,
  function : Function?,
  operand : Handle,
  scalar : Scalar,
) -> String? raise WgslIrEmitError {
  match scalar.kind {
    Float | AbstractFloat =>
      match self.required_expression(function, operand) {
        Constant(handle) =>
          match self.eval_constant_float_expression_for_writer(handle) {
            Some(value) =>
              self.float_value_literal_for_width(value, scalar.width)
            None => None
          }
        _ =>
          match
            self.eval_float_expression_with_retained_constants(
              function, operand,
            ) {
            Some(value) =>
              self.float_value_literal_for_width(value, scalar.width)
            None =>
              if self.expression_tree_contains_folded_local_constant(
                  function, operand,
                ) {
                None
              } else {
                match self.eval_float_expression_for_writer(function, operand) {
                  Some(value) =>
                    self.float_value_literal_for_width(value, scalar.width)
                  None => None
                }
              }
          }
      }
    Uint =>
      match self.eval_integer_expression_for_writer(function, operand) {
        Some(value) => self.integer_value_literal_for_kind(value, Uint)
        None => None
      }
    Sint =>
      match self.eval_integer_expression_for_writer(function, operand) {
        Some(value) => self.integer_value_literal_for_kind(value, Sint)
        None => None
      }
    AbstractInt =>
      match self.eval_integer_expression_for_writer(function, operand) {
        Some(value) => self.integer_value_literal_for_kind(value, AbstractInt)
        None => None
      }
    _ => None
  }
}

///|
fn WgslIrEmitter::literal_for_scalar_context(
  self : WgslIrEmitter,
  literal : Literal,
  scalar : Scalar,
) -> String? {
  match scalar.kind {
    Float | AbstractFloat =>
      match wgsl_ir_float_value_from_numeric_literal(literal) {
        Some(value) => self.float_value_literal_for_width(value, scalar.width)
        None => None
      }
    Uint =>
      match literal {
        AbstractInt(value) =>
          self.integer_value_literal_for_kind(Abstract(value), Uint)
        U32(value) => self.integer_value_literal_for_kind(Unsigned(value), Uint)
        I32(value) => self.integer_value_literal_for_kind(Signed(value), Uint)
        _ => None
      }
    Sint =>
      match literal {
        AbstractInt(value) =>
          self.integer_value_literal_for_kind(Abstract(value), Sint)
        I32(value) => self.integer_value_literal_for_kind(Signed(value), Sint)
        U32(value) => self.integer_value_literal_for_kind(Unsigned(value), Sint)
        _ => None
      }
    AbstractInt =>
      match literal {
        AbstractInt(value) =>
          self.integer_value_literal_for_kind(Abstract(value), AbstractInt)
        I32(value) =>
          self.integer_value_literal_for_kind(Signed(value), AbstractInt)
        U32(value) =>
          self.integer_value_literal_for_kind(Unsigned(value), AbstractInt)
        _ => None
      }
    _ => None
  }
}

///|
fn WgslIrEmitter::matrix_scalar_component_list(
  self : WgslIrEmitter,
  ty : Handle,
  components : Array[Handle],
  function : Function?,
) -> String? raise WgslIrEmitError {
  if !self.options.expand_matrix_scalar_constructors() {
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
fn WgslIrEmitter::optional_expression(
  self : WgslIrEmitter,
  function : Function?,
  handle : Handle,
) -> Expression? {
  match function {
    Some(function) => function.expressions.items.get(handle.index())
    None => self.shader_module.global_expressions.items.get(handle.index())
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
  let pointer_text = self.pointer_builtin_argument_expression(function, pointer)
  out.write_string(
    "\{self.atomic_function_name(atomic_function)}(\{pointer_text}",
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
fn wgsl_ir_pointer_builtin_argument_text(text : String) -> String {
  if text.length() > 0 && text[0:1] == "&" {
    "(\{text})"
  } else {
    text
  }
}

///|
fn WgslIrEmitter::pointer_builtin_argument_expression(
  self : WgslIrEmitter,
  function : Function?,
  pointer : Handle,
) -> String raise WgslIrEmitError {
  wgsl_ir_pointer_builtin_argument_text(
    self.pointer_expression(function, pointer),
  )
}

///|
fn WgslIrEmitter::pointer_expression(
  self : WgslIrEmitter,
  function : Function?,
  pointer : Handle,
) -> String raise WgslIrEmitError {
  if self.expression_is_pointer(function, pointer) {
    self.required_function_expression(function, pointer)
  } else {
    self.options.address_of_text(
      self.required_function_expression(function, pointer),
    )
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
    "\{wgsl_ir_indent(indent)}coopStore\{suffix}(\{self.function_expression(function, target)}, \{self.pointer_expression(Some(function), data.pointer)}, \{self.function_expression(function, data.stride)});\n",
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
  "coopLoad\{suffix}<coop_mat\{wgsl_ir_cooperative_size_name(columns)}x\{wgsl_ir_cooperative_size_name(rows)}<\{self.scalar_name(scalar)}, \{wgsl_ir_cooperative_role_name(role)}>>(\{self.pointer_expression(function, data.pointer)}, \{self.required_function_expression(function, data.stride)})"
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
  if depth_ref == None && !self.image_expression_is_depth(function, image) {
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
fn WgslIrEmitter::image_expression_is_depth(
  self : WgslIrEmitter,
  function : Function?,
  image : Handle,
) -> Bool {
  match self.expression_type(function, image) {
    Some(ty) =>
      match self.shader_module.types.get(ty) {
        Some(type_) =>
          match type_.inner {
            Image(_, _, Depth(_)) => true
            _ => false
          }
        None => false
      }
    None => false
  }
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
fn WgslIrEmitter::access_index_expression(
  self : WgslIrEmitter,
  function : Function?,
  base : Handle,
  index : Int,
) -> String raise WgslIrEmitError {
  match self.folded_static_constant_array_access(function, base, index) {
    Some(value) => return value
    None => ()
  }
  let base_expression = self.access_base_expression(function, base)
  match self.expression_type(function, base) {
    Some(ty_handle) => {
      let base_type_handle = self.deref_pointer_type_handle(ty_handle)
      match self.shader_module.types.items.get(base_type_handle.index()) {
        Some(ty) =>
          match ty.inner {
            Struct(members, _) | PredeclaredStruct(members, _) =>
              match members.get(index) {
                Some(_) => {
                  let member_name = self.required_emit_name(
                    wgsl_ir_emit_name_key2(
                      "member",
                      base_type_handle.index(),
                      index,
                    ),
                  )
                  "\{base_expression}.\{member_name}"
                }
                None =>
                  raise WgslIrEmitError::Unsupported(
                    "struct member index \{index}",
                  )
              }
            Vector(_, _) =>
              if self.vector_static_index_keeps_bracket(function, base) {
                "\{base_expression}[\{index}]"
              } else {
                "\{base_expression}.\{wgsl_ir_swizzle_component(index)}"
              }
            Matrix(_, _, _)
            | Array(_, _, _)
            | BindingArray(_, _)
            | ValuePointer(_, _, _) => "\{base_expression}[\{index}]"
            _ =>
              raise WgslIrEmitError::Unsupported(
                "access-index base type \{base_type_handle.index()}",
              )
          }
        None =>
          raise WgslIrEmitError::MissingHandle(
            "access-index base type \{base_type_handle.index()}",
          )
      }
    }
    None =>
      raise WgslIrEmitError::Unsupported(
        "access-index expression without base type",
      )
  }
}

///|
fn WgslIrEmitter::vector_static_index_keeps_bracket(
  self : WgslIrEmitter,
  function : Function?,
  base : Handle,
) -> Bool {
  ignore(self)
  match function {
    Some(func) => wgsl_ir_emit_expression_reads_global_binding(func, base)
    None => false
  }
}

///|
fn wgsl_ir_emit_expression_reads_global_binding(
  function : Function,
  handle : Handle,
) -> Bool {
  match function.expressions.items.get(handle.index()) {
    Some(GlobalVariable(_)) => true
    Some(LocalVariable(local_handle)) =>
      match function.local_variables.items.get(local_handle.index()) {
        Some(local_var) =>
          if local_var.generated_temporary {
            match local_var.init {
              Some(init) =>
                wgsl_ir_emit_expression_reads_global_binding(function, init)
              None => false
            }
          } else {
            false
          }
        None => false
      }
    Some(Load(inner)) =>
      wgsl_ir_emit_expression_reads_global_binding(function, inner)
    Some(Access(base, index)) =>
      wgsl_ir_emit_expression_reads_global_binding(function, base) ||
      wgsl_ir_emit_expression_reads_global_binding(function, index)
    Some(AccessIndex(base, _))
    | Some(Component(base, _))
    | Some(Swizzle(_, base, _)) =>
      wgsl_ir_emit_expression_reads_global_binding(function, base)
    _ => false
  }
}

///|
fn WgslIrEmitter::folded_static_constant_array_access(
  self : WgslIrEmitter,
  function : Function?,
  base : Handle,
  index : Int,
) -> String? raise WgslIrEmitError {
  guard self.options.fold_numeric_constant_expressions() else { return None }
  guard index >= 0 else { return None }
  match self.required_expression(function, base) {
    Compose(ty, components) =>
      self.folded_static_array_constructor_access(
        function, ty, components, index,
      )
    Constant(constant_handle) =>
      self.folded_static_constant_array_constructor_access(
        constant_handle, index,
      )
    _ => None
  }
}

///|
fn WgslIrEmitter::folded_static_constant_array_constructor_access(
  self : WgslIrEmitter,
  constant_handle : Handle,
  index : Int,
) -> String? raise WgslIrEmitError {
  guard self.shader_module.constants.items.get(constant_handle.index())
    is Some(constant) else {
    raise WgslIrEmitError::MissingHandle("constant \{constant_handle.index()}")
  }
  guard self.should_inline_constant_expression(constant) else { return None }
  guard self.shader_module.global_expressions.items.get(constant.init.index())
    is Some(Compose(ty, components)) else {
    return None
  }
  self.folded_static_array_constructor_access(None, ty, components, index)
}

///|
fn WgslIrEmitter::folded_static_array_constructor_access(
  self : WgslIrEmitter,
  function : Function?,
  ty : Handle,
  components : Array[Handle],
  index : Int,
) -> String? raise WgslIrEmitError {
  guard self.shader_module.types.items.get(ty.index())
    is Some({ inner: Array(_, _, _), .. }) else {
    return None
  }
  match components.get(index) {
    Some(component) =>
      Some(self.required_function_expression(function, component))
    None =>
      raise WgslIrEmitError::Unsupported(
        "constant array index \{index} out of bounds",
      )
  }
}

///|
fn WgslIrEmitter::folded_static_constant_array_access_by_index_expression(
  self : WgslIrEmitter,
  function : Function?,
  base : Handle,
  index : Handle,
) -> String? raise WgslIrEmitError {
  guard self.options.fold_numeric_constant_expressions() else { return None }
  guard self.eval_integer_expression_for_access_index(function, index)
    is Some(value) else {
    return None
  }
  guard value.to_signed_int() is Some(static_index) else { return None }
  self.folded_static_constant_array_access(function, base, static_index)
}

///|
fn WgslIrEmitter::access_index_operand_expression(
  self : WgslIrEmitter,
  function : Function?,
  index : Handle,
) -> String raise WgslIrEmitError {
  if self.options.fold_numeric_constant_expressions() {
    match self.eval_integer_expression_for_access_index(function, index) {
      Some(value) =>
        match value.to_unsigned() {
          Some(value) => return "\{value}"
          None => ()
        }
      None => ()
    }
  }
  self.required_function_expression(function, index)
}

///|
fn WgslIrEmitter::eval_integer_expression_for_access_index(
  self : WgslIrEmitter,
  function : Function?,
  index : Handle,
) -> WgslIrEmitIntegerValue? raise WgslIrEmitError {
  match self.required_expression(function, index) {
    Constant(handle) =>
      match self.shader_module.constants.items.get(handle.index()) {
        Some(constant) =>
          self.eval_global_integer_expression_for_emit(
            constant.init,
            @set.Set([]),
          )
        None => None
      }
    _ => self.eval_integer_expression_for_writer(function, index)
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
  math_function : MathFunction,
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
  let scalar_context = if self.options.contextualize_numeric_literals() {
    self.math_argument_scalar_context(math_function, handles, function)
  } else {
    None
  }
  let out = StringBuilder::new()
  for index in 0..<handles.length() {
    if index > 0 {
      out.write_string(", ")
    }
    out.write_string(
      self.contextual_math_argument_expression(
        function,
        handles[index],
        scalar_context,
      ),
    )
  }
  out.to_string()
}

///|
fn WgslIrEmitter::contextual_math_argument_expression(
  self : WgslIrEmitter,
  function : Function?,
  argument : Handle,
  scalar_context : Scalar?,
) -> String raise WgslIrEmitError {
  match scalar_context {
    Some(scalar) => {
      match self.contextual_scalar_literal(function, argument, scalar) {
        Some(value) => return value
        None => ()
      }
      if self.options.fold_numeric_constant_expressions() {
        match scalar.kind {
          Float | AbstractFloat =>
            match self.eval_float_expression_for_writer(function, argument) {
              Some(value) =>
                match self.float_value_literal_for_width(value, scalar.width) {
                  Some(text) => return text
                  None => ()
                }
              None => ()
            }
          _ => ()
        }
      }
      self.required_function_expression(function, argument)
    }
    None => self.required_function_expression(function, argument)
  }
}

///|
fn WgslIrEmitter::math_argument_scalar_context(
  self : WgslIrEmitter,
  math_function : MathFunction,
  arguments : Array[Handle],
  function : Function?,
) -> Scalar? {
  if !wgsl_ir_math_function_uses_uniform_numeric_argument_context(math_function) {
    return None
  }
  for argument in arguments {
    match self.expression_component_scalar(function, argument) {
      Some(scalar) if !wgsl_ir_scalar_kind_is_abstract(scalar.kind) =>
        return Some(scalar)
      _ => ()
    }
  }
  None
}

///|
fn wgsl_ir_math_function_uses_uniform_numeric_argument_context(
  math_function : MathFunction,
) -> Bool {
  match math_function {
    Min
    | Max
    | Clamp
    | Step
    | SmoothStep
    | Mix
    | Dot
    | Distance
    | Reflect
    | FaceForward
    | Refract
    | Fma
    | Pow
    | Atan2 => true
    _ => false
  }
}
