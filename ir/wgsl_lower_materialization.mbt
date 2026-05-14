///|
fn WgslIrFunctionScope::function_expression_temporary_name(
  self : WgslIrFunctionScope,
  function : Function,
  handle : Handle,
) -> String {
  let index = self.wgsl_ir_function_expression_semantic_index(function, handle)
  let index = if wgsl_ir_function_expression_is_adjacent_materialized_load_after_local_snapshot(
      function, handle,
    ) {
    index - 1
  } else {
    index
  }
  "_e\{index}"
}

///|
fn WgslIrFunctionScope::wgsl_ir_function_expression_semantic_index(
  self : WgslIrFunctionScope,
  function : Function,
  handle : Handle,
) -> Int {
  let mut skipped = 0
  for index in 0..<handle.index() {
    if self.hidden_temporary_name_indices.contains(index) ||
      wgsl_ir_function_expression_is_synthetic_local_reference(
        function,
        Handle::Handle(index),
      ) ||
      wgsl_ir_function_expression_is_atomic_compare_exchange_projection_role(
        function,
        Handle::Handle(index),
      ) {
      skipped += 1
    }
  }
  handle.index() - skipped
}

///|
fn wgsl_ir_function_expression_is_adjacent_materialized_load_after_local_snapshot(
  function : Function,
  handle : Handle,
) -> Bool {
  if handle.index() == 0 {
    return false
  }
  guard function.expressions.items.get(handle.index()) is Some(Load(_)) else {
    return false
  }
  guard function.expressions.items.get(handle.index() - 1)
    is Some(LocalVariable(local_handle)) else {
    return false
  }
  guard function.local_variables.items.get(local_handle.index())
    is Some(local_var) else {
    return false
  }
  guard local_var.kind == Let else { return false }
  guard local_var.name is Some(name) else { return false }
  guard name.length() >= 2 && name[0:2] == "_e" else { return false }
  match local_var.init {
    Some(init) =>
      match function.expressions.items.get(init.index()) {
        Some(Load(_)) => true
        _ => false
      }
    None => false
  }
}

///|
fn wgsl_ir_function_expression_is_atomic_compare_exchange_projection_role(
  function : Function,
  handle : Handle,
) -> Bool {
  wgsl_ir_function_expression_is_atomic_compare_exchange_result_projection(
    function, handle,
  ) ||
  wgsl_ir_function_expression_is_atomic_compare_exchange_old_value_base_load(
    function, handle,
  )
}

///|
fn wgsl_ir_function_expression_is_atomic_compare_exchange_result_projection(
  function : Function,
  handle : Handle,
) -> Bool {
  match function.expressions.items.get(handle.index()) {
    Some(AccessIndex(base, _)) =>
      match function.expressions.items.get(base.index()) {
        Some(Load(inner)) =>
          wgsl_ir_function_expression_is_atomic_compare_exchange_result_ref(
            function, inner,
          )
        _ => false
      }
    _ => false
  }
}

///|
fn wgsl_ir_function_expression_is_atomic_compare_exchange_old_value_base_load(
  function : Function,
  handle : Handle,
) -> Bool {
  guard function.expressions.items.get(handle.index()) is Some(Load(inner)) else {
    return false
  }
  guard wgsl_ir_function_expression_is_atomic_compare_exchange_result_ref(
    function, inner,
  ) else {
    return false
  }
  match function.expressions.items.get(handle.index() + 1) {
    Some(AccessIndex(base, 0)) => base == handle
    _ => false
  }
}

///|
fn wgsl_ir_function_expression_is_atomic_compare_exchange_result_ref(
  function : Function,
  handle : Handle,
) -> Bool {
  match function.expressions.items.get(handle.index()) {
    Some(LocalVariable(local_handle)) =>
      match function.local_variables.items.get(local_handle.index()) {
        Some(local_var) =>
          match local_var.init {
            Some(init) =>
              match function.expressions.items.get(init.index()) {
                Some(AtomicCall(CompareExchangeWeak, _)) => true
                _ => false
              }
            None => false
          }
        None => false
      }
    _ => false
  }
}

///|
fn wgsl_ir_function_expression_is_synthetic_local_reference(
  function : Function,
  handle : Handle,
) -> Bool {
  match function.expressions.items.get(handle.index()) {
    Some(LocalVariable(local_handle)) =>
      match function.local_variables.items.get(local_handle.index()) {
        Some(local_var) =>
          if local_var.kind != Let {
            false
          } else {
            match local_var.name {
              Some(name) =>
                name.length() >= 2 &&
                name[0:2] == "_e" &&
                wgsl_ir_local_variable_initializes_side_effecting_expression(
                  function, local_var,
                )
              None => false
            }
          }
        None => false
      }
    _ => false
  }
}

///|
fn wgsl_ir_local_variable_initializes_side_effecting_expression(
  function : Function,
  local_var : LocalVariable,
) -> Bool {
  match local_var.init {
    Some(init) =>
      match function.expressions.items.get(init.index()) {
        Some(AtomicCall(atomic_function, _)) =>
          match atomic_function {
            Load
            | Add
            | Subtract
            | And
            | ExclusiveOr
            | InclusiveOr
            | Min
            | Max
            | Exchange
            | CompareExchangeWeak => true
            Store => false
          }
        _ => false
      }
    None => false
  }
}

///|
fn WgslIrLowerer::materialize_function_expression(
  self : WgslIrLowerer,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
  value : Handle,
) -> Handle raise WgslIrLowerError {
  let ty = match self.function_expression_type(function, value) {
    Some(ty) => ty
    None =>
      raise WgslIrLowerError::MissingType(
        "\{scope.function_expression_temporary_name(function, value)}: \{wgsl_ir_function_expression_debug(function, value)}",
      )
  }
  let local_handle = function.local_variables.append(LocalVariable::{
    name: Some(scope.function_expression_temporary_name(function, value)),
    kind: Let,
    ty,
    init: Some(value),
  })
  ignore(scope)
  block.push(Statement::Declare(local_handle))
  function.expressions.append(Expression::LocalVariable(local_handle))
}

///|
fn wgsl_ir_function_expression_debug(
  function : Function,
  value : Handle,
) -> String {
  match function.expressions.items.get(value.index()) {
    Some(expression) =>
      match expression {
        Literal(_) => "literal"
        Constant(_) => "constant"
        Override(_) => "override"
        ZeroValue(_) => "zero-value"
        Compose(_, _) => "compose"
        Access(_, _) => "access"
        AccessIndex(_, _) => "access-index"
        Splat(_, _) => "splat"
        Swizzle(_, _, _) => "swizzle"
        FunctionArgument(_) => "function-argument"
        GlobalVariable(_) => "global-variable"
        LocalVariable(_) => "local-variable"
        Load(inner) =>
          "load(\{wgsl_ir_function_expression_debug(function, inner)})"
        AddressOf(_, _) => "address-of"
        AtomicCall(_, _) => "atomic-call"
        ImageSample(_, _, _, _, _, _, _, _, _) => "image-sample"
        ImageLoad(_, _, _, _, _) => "image-load"
        ImageQuery(_, _) => "image-query"
        Unary(_, _) => "unary"
        Binary(_, _, _) => "binary"
        FunctionCall(_, _) => "function-call"
        Select(_, _, _) => "select"
        Bitcast(_, _) => "bitcast"
        Derivative(_, _, _) => "derivative"
        Relational(_, _) => "relational"
        Math(_, _, _, _, _) => "math"
        As(_, _, _) => "as"
        CallResult(_) => "call-result"
        AtomicResult(_, _) => "atomic-result"
        WorkGroupUniformLoadResult(_) => "workgroup-uniform-load-result"
        WorkGroupUniformLoad(_) => "workgroup-uniform-load"
        ArrayLength(_) => "array-length"
        RayQueryInitialize(_, _, _) => "ray-query-initialize"
        RayQueryProceed(_) => "ray-query-proceed"
        RayQueryGenerateIntersection(_, _) => "ray-query-generate-intersection"
        RayQueryConfirmIntersection(_) => "ray-query-confirm-intersection"
        RayQueryTerminate(_) => "ray-query-terminate"
        RayQueryVertexPositions(_, _) => "ray-query-vertex-positions"
        RayQueryProceedResult => "ray-query-proceed-result"
        RayQueryGetIntersection(_, _) => "ray-query-get-intersection"
        SubgroupCall(_, _) => "subgroup-call"
        SubgroupBallotResult => "subgroup-ballot-result"
        SubgroupOperationResult(_) => "subgroup-operation-result"
        CooperativeLoad(_, _, _, _) => "cooperative-load"
        CooperativeMultiplyAdd(_, _, _) => "cooperative-multiply-add"
      }
    None => "missing expression handle \{value.index()}"
  }
}

///|
fn WgslIrLowerer::materialize_return_expression_if_needed(
  self : WgslIrLowerer,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
  value : Handle,
) -> Handle raise WgslIrLowerError {
  let normalized = self.materialize_return_subexpressions(
    function, scope, block, value,
  )
  if self.function_expression_can_return_directly(function, normalized) {
    normalized
  } else {
    self.materialize_function_expression(function, scope, block, normalized)
  }
}

///|
fn WgslIrLowerer::materialize_return_subexpressions(
  self : WgslIrLowerer,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
  value : Handle,
) -> Handle raise WgslIrLowerError {
  match function.expressions.items.get(value.index()) {
    Some(Compose(ty, components)) => {
      let lowered : Array[Handle] = []
      let mut changed = false
      for component in components {
        let lowered_component = self.materialize_nested_constructor_argument(
          function, scope, block, component,
        )
        if lowered_component != component {
          changed = true
        }
        lowered.push(lowered_component)
      }
      if changed {
        function.expressions.append(Expression::Compose(ty, lowered))
      } else {
        value
      }
    }
    Some(Binary(op, left, right)) => {
      if wgsl_ir_binary_operator_is_short_circuit(op) {
        return self.materialize_short_circuit_expression(
          function, scope, block, value,
        )
      }
      let lowered_left = self.materialize_nested_return_argument(
        function, scope, block, left,
      )
      let lowered_right = self.materialize_nested_return_argument(
        function, scope, block, right,
      )
      if lowered_left != left || lowered_right != right {
        function.expressions.append(
          Expression::Binary(op, lowered_left, lowered_right),
        )
      } else {
        value
      }
    }
    Some(Access(base, index)) => {
      let lowered_base = self.materialize_nested_access_base(
        function, scope, block, base,
      )
      let lowered_index = self.materialize_return_subexpressions(
        function, scope, block, index,
      )
      if lowered_base != base || lowered_index != index {
        function.expressions.append(
          Expression::Access(lowered_base, lowered_index),
        )
      } else {
        value
      }
    }
    Some(AccessIndex(base, index)) => {
      let lowered_base = self.materialize_nested_access_base(
        function, scope, block, base,
      )
      if lowered_base != base {
        function.expressions.append(
          Expression::AccessIndex(lowered_base, index),
        )
      } else {
        value
      }
    }
    Some(Swizzle(size, base, pattern)) => {
      let lowered_base = self.materialize_nested_access_base(
        function, scope, block, base,
      )
      if lowered_base != base {
        function.expressions.append(
          Expression::Swizzle(size, lowered_base, pattern),
        )
      } else {
        value
      }
    }
    Some(Unary(op, inner)) => {
      let lowered_inner = self.materialize_return_subexpressions(
        function, scope, block, inner,
      )
      if lowered_inner != inner {
        function.expressions.append(Expression::Unary(op, lowered_inner))
      } else {
        value
      }
    }
    Some(Bitcast(ty, inner)) => {
      let lowered_inner = self.materialize_nested_return_argument(
        function, scope, block, inner,
      )
      if lowered_inner != inner {
        function.expressions.append(Expression::Bitcast(ty, lowered_inner))
      } else {
        value
      }
    }
    Some(Derivative(axis, control, expr)) => {
      let lowered = self.materialize_nested_call_argument(
        function, scope, block, expr,
      )
      if lowered != expr {
        function.expressions.append(
          Expression::Derivative(axis, control, lowered),
        )
      } else {
        value
      }
    }
    Some(Relational(relational_function, expr)) => {
      let lowered = self.materialize_nested_call_argument(
        function, scope, block, expr,
      )
      if lowered != expr {
        function.expressions.append(
          Expression::Relational(relational_function, lowered),
        )
      } else {
        value
      }
    }
    Some(As(expr, kind, width)) => {
      let lowered = self.materialize_nested_call_argument(
        function, scope, block, expr,
      )
      if lowered != expr {
        function.expressions.append(Expression::As(lowered, kind, width))
      } else {
        value
      }
    }
    Some(Select(condition, accept, reject)) => {
      let lowered_condition = self.materialize_nested_call_argument(
        function, scope, block, condition,
      )
      let lowered_accept = self.materialize_nested_call_argument(
        function, scope, block, accept,
      )
      let lowered_reject = self.materialize_nested_call_argument(
        function, scope, block, reject,
      )
      if lowered_condition != condition ||
        lowered_accept != accept ||
        lowered_reject != reject {
        function.expressions.append(
          Expression::Select(lowered_condition, lowered_accept, lowered_reject),
        )
      } else {
        value
      }
    }
    Some(FunctionCall(handle, arguments)) => {
      let lowered : Array[Handle] = []
      let mut changed = false
      for argument in arguments {
        let lowered_argument = self.materialize_nested_call_argument(
          function, scope, block, argument,
        )
        if lowered_argument != argument {
          changed = true
        }
        lowered.push(lowered_argument)
      }
      if changed {
        function.expressions.set(
          value,
          Expression::FunctionCall(handle, lowered),
        )
      }
      value
    }
    Some(
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
      )
    ) => {
      let lowered_coordinate = self.materialize_nested_call_argument(
        function, scope, block, coordinate,
      )
      let lowered_array_index = self.materialize_optional_nested_call_argument(
        function, scope, block, array_index,
      )
      let lowered_offset = self.materialize_optional_nested_call_argument(
        function, scope, block, offset,
      )
      let lowered_level = self.materialize_sample_level(
        function, scope, block, level,
      )
      let lowered_depth_ref = self.materialize_optional_nested_call_argument(
        function, scope, block, depth_ref,
      )
      if lowered_coordinate != coordinate ||
        lowered_array_index != array_index ||
        lowered_offset != offset ||
        lowered_level != level ||
        lowered_depth_ref != depth_ref {
        function.expressions.append(
          Expression::ImageSample(
            image, sampler, gather, lowered_coordinate, lowered_array_index, lowered_offset,
            lowered_level, lowered_depth_ref, clamp_to_edge,
          ),
        )
      } else {
        value
      }
    }
    Some(ImageLoad(image, coordinate, array_index, sample, level)) => {
      let lowered_coordinate = self.materialize_nested_call_argument(
        function, scope, block, coordinate,
      )
      let lowered_array_index = self.materialize_optional_nested_call_argument(
        function, scope, block, array_index,
      )
      let lowered_sample = self.materialize_optional_nested_call_argument(
        function, scope, block, sample,
      )
      let lowered_level = self.materialize_optional_nested_call_argument(
        function, scope, block, level,
      )
      if lowered_coordinate != coordinate ||
        lowered_array_index != array_index ||
        lowered_sample != sample ||
        lowered_level != level {
        function.expressions.append(
          Expression::ImageLoad(
            image, lowered_coordinate, lowered_array_index, lowered_sample, lowered_level,
          ),
        )
      } else {
        value
      }
    }
    Some(ImageQuery(image, query)) => {
      let lowered_query = self.materialize_image_query(
        function, scope, block, query,
      )
      if lowered_query != query {
        function.expressions.append(
          Expression::ImageQuery(image, lowered_query),
        )
      } else {
        value
      }
    }
    Some(AtomicCall(atomic_function, arguments)) => {
      let lowered : Array[Handle] = []
      let mut changed = false
      for argument in arguments {
        let lowered_argument = self.materialize_nested_call_argument(
          function, scope, block, argument,
        )
        if lowered_argument != argument {
          changed = true
        }
        lowered.push(lowered_argument)
      }
      if changed {
        function.expressions.set(
          value,
          Expression::AtomicCall(atomic_function, lowered),
        )
      }
      value
    }
    Some(Math(math_function, a, b, c, d)) => {
      let lowered_a = self.materialize_nested_call_argument(
        function, scope, block, a,
      )
      let lowered_b = self.materialize_optional_nested_call_argument(
        function, scope, block, b,
      )
      let lowered_c = self.materialize_optional_nested_call_argument(
        function, scope, block, c,
      )
      let lowered_d = self.materialize_optional_nested_call_argument(
        function, scope, block, d,
      )
      if lowered_a != a || lowered_b != b || lowered_c != c || lowered_d != d {
        function.expressions.append(
          Expression::Math(
            math_function, lowered_a, lowered_b, lowered_c, lowered_d,
          ),
        )
      } else {
        value
      }
    }
    Some(SubgroupCall(subgroup_function, arguments)) => {
      let lowered : Array[Handle] = []
      let mut changed = false
      for argument in arguments {
        let lowered_argument = self.materialize_nested_call_argument(
          function, scope, block, argument,
        )
        if lowered_argument != argument {
          changed = true
        }
        lowered.push(lowered_argument)
      }
      if changed {
        function.expressions.append(
          Expression::SubgroupCall(subgroup_function, lowered),
        )
      } else {
        value
      }
    }
    Some(CooperativeLoad(columns, rows, role, data)) => {
      let lowered_data = self.materialize_cooperative_data(
        function, scope, block, data,
      )
      if lowered_data != data {
        function.expressions.append(
          Expression::CooperativeLoad(columns, rows, role, lowered_data),
        )
      } else {
        value
      }
    }
    Some(CooperativeMultiplyAdd(a, b, c)) => {
      let lowered_a = self.materialize_nested_call_argument(
        function, scope, block, a,
      )
      let lowered_b = self.materialize_nested_call_argument(
        function, scope, block, b,
      )
      let lowered_c = self.materialize_nested_call_argument(
        function, scope, block, c,
      )
      if lowered_a != a || lowered_b != b || lowered_c != c {
        function.expressions.append(
          Expression::CooperativeMultiplyAdd(lowered_a, lowered_b, lowered_c),
        )
      } else {
        value
      }
    }
    _ => value
  }
}

///|
fn WgslIrLowerer::materialize_short_circuit_expression(
  self : WgslIrLowerer,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
  value : Handle,
) -> Handle raise WgslIrLowerError {
  guard function.expressions.items.get(value.index())
    is Some(Binary(op, left, right)) else {
    return value
  }
  guard wgsl_ir_binary_operator_is_short_circuit(op) else { return value }
  let ty = match self.function_expression_type(function, value) {
    Some(ty) => ty
    None =>
      raise WgslIrLowerError::MissingType(
        "\{scope.function_expression_temporary_name(function, value)}: short-circuit boolean expression",
      )
  }
  let mut result_ptr : Handle? = None
  match op {
    LogicalAnd => {
      let condition = self.materialize_short_circuit_condition(
        function, scope, block, left,
      )
      let local_ptr = self.append_short_circuit_result_local(
        function, block, ty,
      )
      result_ptr = Some(local_ptr)
      let accept = Block::Block()
      let reject = Block::Block()
      let right_value = self.materialize_short_circuit_branch_value(
        function, scope, accept, right,
      )
      accept.push(Statement::Store(local_ptr, right_value))
      reject.push(
        Statement::Store(
          local_ptr,
          function.expressions.append(Expression::Literal(Bool(false))),
        ),
      )
      block.push(Statement::If(condition, accept, reject))
    }
    LogicalOr => {
      let condition = self.materialize_short_circuit_condition(
        function, scope, block, left,
      )
      let inverted = function.expressions.append(
        Expression::Unary(UnaryOperator::LogicalNot, condition),
      )
      let local_ptr = self.append_short_circuit_result_local(
        function, block, ty,
      )
      result_ptr = Some(local_ptr)
      let accept = Block::Block()
      let reject = Block::Block()
      let right_value = self.materialize_short_circuit_branch_value(
        function, scope, accept, right,
      )
      accept.push(Statement::Store(local_ptr, right_value))
      reject.push(
        Statement::Store(
          local_ptr,
          function.expressions.append(Expression::Literal(Bool(true))),
        ),
      )
      block.push(Statement::If(inverted, accept, reject))
    }
    _ => ()
  }
  match result_ptr {
    Some(local_ptr) => function.expressions.append(Expression::Load(local_ptr))
    _ =>
      raise WgslIrLowerError::UnsupportedExpression(
        "short-circuit result local was not emitted",
      )
  }
}

///|
fn WgslIrLowerer::append_short_circuit_result_local(
  self : WgslIrLowerer,
  function : Function,
  block : Block,
  ty : Handle,
) -> Handle {
  ignore(self)
  let local_handle = function.local_variables.append(LocalVariable::{
    name: Some("local"),
    kind: Var,
    ty,
    init: None,
  })
  block.push(Statement::Declare(local_handle))
  function.expressions.append(Expression::LocalVariable(local_handle))
}

///|
fn WgslIrLowerer::materialize_short_circuit_condition(
  self : WgslIrLowerer,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
  value : Handle,
) -> Handle raise WgslIrLowerError {
  match function.expressions.items.get(value.index()) {
    Some(Binary(op, _, _)) if wgsl_ir_binary_operator_is_short_circuit(op) => {
      let lowered = self.materialize_short_circuit_expression(
        function, scope, block, value,
      )
      if self.function_expression_should_materialize_as_nested_value(
          function, lowered,
        ) {
        self.materialize_function_expression(function, scope, block, lowered)
      } else {
        lowered
      }
    }
    _ => {
      let normalized = self.materialize_return_subexpressions(
        function, scope, block, value,
      )
      if self.function_expression_should_materialize_as_nested_value(
          function, normalized,
        ) {
        self.materialize_function_expression(function, scope, block, normalized)
      } else {
        normalized
      }
    }
  }
}

///|
fn WgslIrLowerer::materialize_short_circuit_branch_value(
  self : WgslIrLowerer,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
  value : Handle,
) -> Handle raise WgslIrLowerError {
  match function.expressions.items.get(value.index()) {
    Some(Binary(op, _, _)) if wgsl_ir_binary_operator_is_short_circuit(op) => {
      let lowered = self.materialize_short_circuit_expression(
        function, scope, block, value,
      )
      if self.function_expression_should_materialize_as_nested_value(
          function, lowered,
        ) {
        self.materialize_function_expression(function, scope, block, lowered)
      } else {
        lowered
      }
    }
    _ => self.materialize_store_value_if_needed(function, scope, block, value)
  }
}

///|
fn wgsl_ir_binary_operator_is_short_circuit(op : BinaryOperator) -> Bool {
  op == LogicalAnd || op == LogicalOr
}

///|
fn WgslIrLowerer::materialize_sample_level(
  self : WgslIrLowerer,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
  level : SampleLevel,
) -> SampleLevel raise WgslIrLowerError {
  match level {
    Exact(handle) =>
      Exact(
        self.materialize_nested_call_argument(function, scope, block, handle),
      )
    Bias(handle) =>
      Bias(
        self.materialize_nested_call_argument(function, scope, block, handle),
      )
    Gradient(x, y) =>
      Gradient(
        self.materialize_nested_call_argument(function, scope, block, x),
        self.materialize_nested_call_argument(function, scope, block, y),
      )
    Auto | Zero => level
  }
}

///|
fn WgslIrLowerer::materialize_image_query(
  self : WgslIrLowerer,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
  query : ImageQuery,
) -> ImageQuery raise WgslIrLowerError {
  match query {
    Size(level) =>
      Size(
        self.materialize_optional_nested_call_argument(
          function, scope, block, level,
        ),
      )
    NumLevels | NumLayers | NumSamples => query
  }
}

///|
fn WgslIrLowerer::materialize_cooperative_data(
  self : WgslIrLowerer,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
  data : CooperativeData,
) -> CooperativeData raise WgslIrLowerError {
  CooperativeData::{
    pointer: data.pointer,
    stride: self.materialize_nested_call_argument(
      function,
      scope,
      block,
      data.stride,
    ),
    row_major: data.row_major,
  }
}

///|
fn WgslIrLowerer::materialize_optional_nested_call_argument(
  self : WgslIrLowerer,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
  value : Handle?,
) -> Handle? raise WgslIrLowerError {
  match value {
    Some(handle) =>
      Some(
        self.materialize_nested_call_argument(function, scope, block, handle),
      )
    None => None
  }
}

///|
fn WgslIrLowerer::materialize_nested_return_argument(
  self : WgslIrLowerer,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
  value : Handle,
) -> Handle raise WgslIrLowerError {
  let normalized = self.materialize_return_subexpressions(
    function, scope, block, value,
  )
  if self.function_expression_should_materialize_as_nested_value(
      function, normalized,
    ) {
    self.materialize_function_expression(function, scope, block, normalized)
  } else {
    normalized
  }
}

///|
fn WgslIrLowerer::materialize_nested_access_base(
  self : WgslIrLowerer,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
  value : Handle,
) -> Handle raise WgslIrLowerError {
  let normalized = self.materialize_return_subexpressions(
    function, scope, block, value,
  )
  if self.function_expression_should_materialize_as_access_base(
      function, normalized,
    ) {
    self.materialize_function_expression(function, scope, block, normalized)
  } else {
    normalized
  }
}

///|
fn WgslIrLowerer::materialize_nested_call_argument(
  self : WgslIrLowerer,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
  value : Handle,
) -> Handle raise WgslIrLowerError {
  let normalized = self.materialize_return_subexpressions(
    function, scope, block, value,
  )
  if self.function_expression_should_materialize_as_call_argument(
      function, normalized,
    ) {
    self.materialize_function_expression(function, scope, block, normalized)
  } else {
    normalized
  }
}

///|
fn WgslIrLowerer::materialize_nested_constructor_argument(
  self : WgslIrLowerer,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
  value : Handle,
) -> Handle raise WgslIrLowerError {
  let normalized = self.materialize_return_subexpressions(
    function, scope, block, value,
  )
  if self.function_expression_should_materialize_as_nested_value(
      function, normalized,
    ) ||
    self.function_expression_should_materialize_as_call_argument(
      function, normalized,
    ) {
    self.materialize_function_expression(function, scope, block, normalized)
  } else {
    normalized
  }
}

///|
fn WgslIrLowerer::materialize_side_effecting_expression(
  self : WgslIrLowerer,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
  value : Handle,
) -> Handle raise WgslIrLowerError {
  let normalized = self.materialize_return_subexpressions(
    function, scope, block, value,
  )
  if self.function_expression_is_side_effecting(function, Some(normalized)) {
    self.materialize_function_expression(function, scope, block, normalized)
  } else {
    normalized
  }
}

///|
fn WgslIrLowerer::materialize_store_value_if_needed(
  self : WgslIrLowerer,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
  value : Handle,
) -> Handle raise WgslIrLowerError {
  if self.function_expression_should_materialize_as_store_value(function, value) {
    let normalized = self.materialize_return_subexpressions(
      function, scope, block, value,
    )
    self.materialize_function_expression(function, scope, block, normalized)
  } else {
    value
  }
}

///|
fn WgslIrLowerer::function_expression_is_side_effecting(
  self : WgslIrLowerer,
  function : Function,
  value : Handle?,
) -> Bool {
  ignore(self)
  match value {
    Some(handle) =>
      match function.expressions.items.get(handle.index()) {
        Some(AtomicCall(atomic_function, _)) =>
          match atomic_function {
            Load
            | Add
            | Subtract
            | And
            | ExclusiveOr
            | InclusiveOr
            | Min
            | Max
            | Exchange
            | CompareExchangeWeak => true
            Store => false
          }
        _ => false
      }
    None => false
  }
}

///|
fn WgslIrLowerer::function_expression_should_materialize_as_store_value(
  self : WgslIrLowerer,
  function : Function,
  value : Handle,
) -> Bool {
  let should_materialize = match function.expressions.items.get(value.index()) {
    Some(FunctionCall(_, _))
    | Some(AtomicCall(_, _))
    | Some(ImageSample(_, _, _, _, _, _, _, _, _))
    | Some(ImageLoad(_, _, _, _, _))
    | Some(ImageQuery(_, _))
    | Some(WorkGroupUniformLoad(_)) => true
    _ => false
  }
  should_materialize &&
  self.function_expression_can_materialize_to_let(function, value)
}

///|
fn WgslIrLowerer::function_expression_should_materialize_as_nested_value(
  self : WgslIrLowerer,
  function : Function,
  value : Handle,
) -> Bool {
  let should_materialize = match function.expressions.items.get(value.index()) {
    Some(FunctionCall(_, _))
    | Some(AtomicCall(_, _))
    | Some(CooperativeLoad(_, _, _, _))
    | Some(CooperativeMultiplyAdd(_, _, _))
    | Some(ImageSample(_, _, _, _, _, _, _, _, _))
    | Some(ImageLoad(_, _, _, _, _))
    | Some(ImageQuery(_, _))
    | Some(WorkGroupUniformLoad(_)) => true
    Some(Load(_)) =>
      self.function_expression_reads_global_binding(function, value) ||
      self.function_expression_reads_var_pointer_load(function, value)
    Some(Access(_, _)) | Some(AccessIndex(_, _)) | Some(Swizzle(_, _, _)) =>
      self.function_expression_reads_global_binding(function, value) ||
      self.function_expression_reads_var_pointer_load(function, value)
    _ => false
  }
  should_materialize &&
  self.function_expression_can_materialize_to_let(function, value)
}

///|
fn WgslIrLowerer::function_expression_should_materialize_as_access_base(
  self : WgslIrLowerer,
  function : Function,
  value : Handle,
) -> Bool {
  ignore(self)
  match function.expressions.items.get(value.index()) {
    Some(FunctionCall(_, _))
    | Some(AtomicCall(_, _))
    | Some(ImageSample(_, _, _, _, _, _, _, _, _))
    | Some(ImageLoad(_, _, _, _, _))
    | Some(ImageQuery(_, _)) => true
    _ => false
  }
}

///|
fn WgslIrLowerer::function_expression_should_materialize_as_call_argument(
  self : WgslIrLowerer,
  function : Function,
  value : Handle,
) -> Bool {
  self.function_expression_is_var_pointer_load(function, value) &&
  self.function_expression_can_materialize_to_let(function, value)
}

///|
fn WgslIrLowerer::function_expression_is_var_pointer_load(
  self : WgslIrLowerer,
  function : Function,
  value : Handle,
) -> Bool {
  ignore(self)
  match function.expressions.items.get(value.index()) {
    Some(Load(pointer)) =>
      match function.expressions.items.get(pointer.index()) {
        Some(LocalVariable(handle)) =>
          match function.local_variables.items.get(handle.index()) {
            Some(local_variable) => local_variable.kind == Var
            None => false
          }
        _ => false
      }
    _ => false
  }
}

///|
fn WgslIrLowerer::function_expression_reads_global_binding(
  self : WgslIrLowerer,
  function : Function,
  value : Handle,
) -> Bool {
  match function.expressions.items.get(value.index()) {
    Some(GlobalVariable(_)) => true
    Some(Load(inner)) =>
      self.function_expression_reads_global_binding(function, inner)
    Some(Access(base, index)) =>
      self.function_expression_reads_global_binding(function, base) ||
      self.function_expression_reads_global_binding(function, index)
    Some(AccessIndex(base, _)) | Some(Swizzle(_, base, _)) =>
      self.function_expression_reads_global_binding(function, base)
    _ => false
  }
}

///|
fn WgslIrLowerer::function_expression_reads_var_pointer_load(
  self : WgslIrLowerer,
  function : Function,
  value : Handle,
) -> Bool {
  match function.expressions.items.get(value.index()) {
    Some(Load(pointer)) =>
      match function.expressions.items.get(pointer.index()) {
        Some(LocalVariable(handle)) =>
          match function.local_variables.items.get(handle.index()) {
            Some(local_variable) => local_variable.kind == Var
            None => false
          }
        _ => false
      }
    Some(Access(base, index)) =>
      self.function_expression_reads_var_pointer_load(function, base) ||
      self.function_expression_reads_var_pointer_load(function, index)
    Some(AccessIndex(base, _)) | Some(Swizzle(_, base, _)) =>
      self.function_expression_reads_var_pointer_load(function, base)
    _ => false
  }
}

///|
fn WgslIrLowerer::function_expression_can_materialize_to_let(
  self : WgslIrLowerer,
  function : Function,
  value : Handle,
) -> Bool {
  match self.function_expression_type(function, value) {
    Some(ty) => self.type_can_materialize_to_local_let(ty)
    None => false
  }
}

///|
fn WgslIrLowerer::type_can_materialize_to_local_let(
  self : WgslIrLowerer,
  ty : Handle,
) -> Bool {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Scalar(_)
        | Vector(_, _)
        | Matrix(_, _, _)
        | CooperativeMatrix(_, _, _, _)
        | ValuePointer(_, _, _) => true
        Array(element, size, _) =>
          match size {
            Dynamic => false
            Constant(_) | Pending(_) =>
              self.type_can_materialize_to_local_let(element)
          }
        Struct(members, _) | PredeclaredStruct(members, _) => {
          for struct_member in members {
            if !self.type_can_materialize_to_local_let(struct_member.ty) {
              return false
            }
          }
          true
        }
        Atomic(_)
        | Pointer(_, _)
        | BindingArray(_, _)
        | Image(_, _, _)
        | Sampler(_)
        | AccelerationStructure(_)
        | RayQuery(_) => false
      }
    None => false
  }
}

///|
fn WgslIrLowerer::function_expression_can_return_directly(
  self : WgslIrLowerer,
  function : Function,
  value : Handle,
) -> Bool {
  match function.expressions.items.get(value.index()) {
    Some(expression) =>
      match expression {
        Literal(_)
        | Constant(_)
        | Override(_)
        | FunctionArgument(_)
        | Binary(_, _, _)
        | Compose(_, _)
        | Access(_, _)
        | AccessIndex(_, _)
        | Swizzle(_, _, _)
        | Unary(_, _)
        | Select(_, _, _)
        | Bitcast(_, _)
        | Math(_, _, _, _, _)
        | Relational(_, _)
        | CooperativeLoad(_, _, _, _)
        | CooperativeMultiplyAdd(_, _, _) => true
        Load(inner) =>
          self.function_pointer_expression_can_return_directly(function, inner)
        _ => false
      }
    None => false
  }
}

///|
fn WgslIrLowerer::function_pointer_expression_can_return_directly(
  self : WgslIrLowerer,
  function : Function,
  value : Handle,
) -> Bool {
  ignore(self)
  match function.expressions.items.get(value.index()) {
    Some(Expression::LocalVariable(handle)) =>
      match function.local_variables.items.get(handle.index()) {
        Some(local_variable) => local_variable.kind == Let
        None => false
      }
    _ => false
  }
}
