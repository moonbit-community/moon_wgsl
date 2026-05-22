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
          } else if local_var.generated_temporary {
            if wgsl_ir_local_variable_initializes_materialized_value_call(
                function, local_var,
              ) {
              true
            } else {
              local_var.generated_temporary_store_value_reference
            }
          } else {
            true
          }
        None => false
      }
    _ => false
  }
}

///|
fn wgsl_ir_function_expression_is_generated_temporary_reference(
  function : Function,
  handle : Handle,
) -> Bool {
  match function.expressions.items.get(handle.index()) {
    Some(Load(inner)) =>
      wgsl_ir_function_expression_is_generated_temporary_reference(
        function, inner,
      )
    Some(LocalVariable(local_handle)) =>
      match function.local_variables.items.get(local_handle.index()) {
        Some(local_var) => local_var.generated_temporary
        None => false
      }
    _ => false
  }
}

///|
fn wgsl_ir_local_variable_initializes_materialized_value_call(
  function : Function,
  local_var : LocalVariable,
) -> Bool {
  match local_var.init {
    Some(init) =>
      match function.expressions.items.get(init.index()) {
        Some(FunctionCall(_, _))
        | Some(AtomicCall(_, _))
        | Some(ImageSample(_, _, _, _, _, _, _, _, _))
        | Some(ImageLoad(_, _, _, _, _))
        | Some(ImageQuery(_, _))
        | Some(WorkGroupUniformLoad(_)) => true
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
  match function.expressions.items.get(value.index()) {
    Some(FunctionCall(function_handle, arguments)) => {
      function.expressions.set(value, Expression::CallResult(function_handle))
      block.push(Statement::Call(function_handle, arguments, Some(value)))
      return value
    }
    _ => ()
  }
  let ty = match self.function_expression_type(function, value) {
    Some(ty) => ty
    None =>
      raise WgslIrLowerError::MissingType(
        "materialized expression \{value.index()}: \{wgsl_ir_function_expression_debug(function, value)}",
      )
  }
  let local_handle = function.local_variables.append(LocalVariable::{
    name: None,
    kind: Let,
    generated_temporary: true,
    generated_temporary_store_value_reference: false,
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
  if self.function_expression_should_materialize_as_nested_value(
      function, normalized,
    ) {
    self.materialize_function_expression(function, scope, block, normalized)
  } else if self.function_expression_can_return_directly(function, normalized) {
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
        let parent_component = wgsl_ir_parent_expression_operand(
          function, component, lowered_component,
        )
        if parent_component != component {
          changed = true
        }
        lowered.push(parent_component)
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
      let parent_left = wgsl_ir_parent_expression_operand(
        function, left, lowered_left,
      )
      let parent_right = wgsl_ir_parent_expression_operand(
        function, right, lowered_right,
      )
      if parent_left != left || parent_right != right {
        function.expressions.append(
          Expression::Binary(op, parent_left, parent_right),
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
      let parent_base = wgsl_ir_parent_expression_operand(
        function, base, lowered_base,
      )
      let parent_index = wgsl_ir_parent_expression_operand(
        function, index, lowered_index,
      )
      if parent_base != base || parent_index != index {
        function.expressions.append(
          Expression::Access(parent_base, parent_index),
        )
      } else {
        value
      }
    }
    Some(AccessIndex(base, index)) => {
      let lowered_base = self.materialize_nested_access_base(
        function, scope, block, base,
      )
      let parent_base = wgsl_ir_parent_expression_operand(
        function, base, lowered_base,
      )
      if parent_base != base {
        function.expressions.append(Expression::AccessIndex(parent_base, index))
      } else {
        value
      }
    }
    Some(Swizzle(size, base, pattern)) => {
      let lowered_base = self.materialize_nested_swizzle_base(
        function, scope, block, base,
      )
      let parent_base = wgsl_ir_parent_expression_operand(
        function, base, lowered_base,
      )
      if parent_base != base {
        function.expressions.append(
          Expression::Swizzle(size, parent_base, pattern),
        )
      } else {
        value
      }
    }
    Some(Unary(op, inner)) => {
      let lowered_inner = self.materialize_nested_return_argument(
        function, scope, block, inner,
      )
      let parent_inner = wgsl_ir_parent_expression_operand(
        function, inner, lowered_inner,
      )
      if parent_inner != inner {
        function.expressions.append(Expression::Unary(op, parent_inner))
      } else {
        value
      }
    }
    Some(Bitcast(ty, inner)) => {
      let lowered_inner = self.materialize_nested_return_argument(
        function, scope, block, inner,
      )
      let parent_inner = wgsl_ir_parent_expression_operand(
        function, inner, lowered_inner,
      )
      if parent_inner != inner {
        function.expressions.append(Expression::Bitcast(ty, parent_inner))
      } else {
        value
      }
    }
    Some(Derivative(axis, control, expr)) => {
      let lowered = self.materialize_nested_call_argument(
        function, scope, block, expr,
      )
      let parent = wgsl_ir_parent_expression_operand(function, expr, lowered)
      if parent != expr {
        function.expressions.append(
          Expression::Derivative(axis, control, parent),
        )
      } else {
        value
      }
    }
    Some(Relational(relational_function, expr)) => {
      let lowered = self.materialize_nested_call_argument(
        function, scope, block, expr,
      )
      let parent = wgsl_ir_parent_expression_operand(function, expr, lowered)
      if parent != expr {
        function.expressions.append(
          Expression::Relational(relational_function, parent),
        )
      } else {
        value
      }
    }
    Some(As(expr, kind, width)) => {
      let lowered = self.materialize_nested_call_argument(
        function, scope, block, expr,
      )
      let parent = wgsl_ir_parent_expression_operand(function, expr, lowered)
      if parent != expr {
        function.expressions.append(Expression::As(parent, kind, width))
      } else {
        value
      }
    }
    Some(Select(condition, accept, reject)) => {
      let lowered_reject = self.materialize_nested_call_argument(
        function, scope, block, reject,
      )
      let lowered_accept = self.materialize_nested_call_argument(
        function, scope, block, accept,
      )
      let lowered_condition = self.materialize_nested_call_argument(
        function, scope, block, condition,
      )
      let parent_condition = wgsl_ir_parent_expression_operand(
        function, condition, lowered_condition,
      )
      let parent_accept = wgsl_ir_parent_expression_operand(
        function, accept, lowered_accept,
      )
      let parent_reject = wgsl_ir_parent_expression_operand(
        function, reject, lowered_reject,
      )
      if parent_condition != condition ||
        parent_accept != accept ||
        parent_reject != reject {
        function.expressions.append(
          Expression::Select(parent_condition, parent_accept, parent_reject),
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
        let parent_argument = wgsl_ir_parent_expression_operand(
          function, argument, lowered_argument,
        )
        if parent_argument != argument {
          changed = true
        }
        lowered.push(parent_argument)
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
      let parent_coordinate = wgsl_ir_parent_expression_operand(
        function, coordinate, lowered_coordinate,
      )
      let parent_array_index = wgsl_ir_parent_optional_expression_operand(
        function, array_index, lowered_array_index,
      )
      let parent_offset = wgsl_ir_parent_optional_expression_operand(
        function, offset, lowered_offset,
      )
      let parent_level = wgsl_ir_parent_sample_level_operand(
        function, level, lowered_level,
      )
      let parent_depth_ref = wgsl_ir_parent_optional_expression_operand(
        function, depth_ref, lowered_depth_ref,
      )
      if parent_coordinate != coordinate ||
        parent_array_index != array_index ||
        parent_offset != offset ||
        parent_level != level ||
        parent_depth_ref != depth_ref {
        function.expressions.append(
          Expression::ImageSample(
            image, sampler, gather, parent_coordinate, parent_array_index, parent_offset,
            parent_level, parent_depth_ref, clamp_to_edge,
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
      let parent_coordinate = wgsl_ir_parent_expression_operand(
        function, coordinate, lowered_coordinate,
      )
      let parent_array_index = wgsl_ir_parent_optional_expression_operand(
        function, array_index, lowered_array_index,
      )
      let parent_sample = wgsl_ir_parent_optional_expression_operand(
        function, sample, lowered_sample,
      )
      let parent_level = wgsl_ir_parent_optional_expression_operand(
        function, level, lowered_level,
      )
      if parent_coordinate != coordinate ||
        parent_array_index != array_index ||
        parent_sample != sample ||
        parent_level != level {
        function.expressions.append(
          Expression::ImageLoad(
            image, parent_coordinate, parent_array_index, parent_sample, parent_level,
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
        let parent_argument = wgsl_ir_parent_expression_operand(
          function, argument, lowered_argument,
        )
        if parent_argument != argument {
          changed = true
        }
        lowered.push(parent_argument)
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
      let parent_a = wgsl_ir_parent_expression_operand(function, a, lowered_a)
      let parent_b = wgsl_ir_parent_optional_expression_operand(
        function, b, lowered_b,
      )
      let parent_c = wgsl_ir_parent_optional_expression_operand(
        function, c, lowered_c,
      )
      let parent_d = wgsl_ir_parent_optional_expression_operand(
        function, d, lowered_d,
      )
      if parent_a != a || parent_b != b || parent_c != c || parent_d != d {
        function.expressions.append(
          Expression::Math(
            math_function, parent_a, parent_b, parent_c, parent_d,
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
        let parent_argument = wgsl_ir_parent_expression_operand(
          function, argument, lowered_argument,
        )
        if parent_argument != argument {
          changed = true
        }
        lowered.push(parent_argument)
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
      let parent_a = wgsl_ir_parent_expression_operand(function, a, lowered_a)
      let parent_b = wgsl_ir_parent_expression_operand(function, b, lowered_b)
      let parent_c = wgsl_ir_parent_expression_operand(function, c, lowered_c)
      if parent_a != a || parent_b != b || parent_c != c {
        function.expressions.append(
          Expression::CooperativeMultiplyAdd(parent_a, parent_b, parent_c),
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
        "materialized short-circuit expression \{value.index()}: boolean expression",
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
    generated_temporary: false,
    generated_temporary_store_value_reference: false,
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
fn WgslIrLowerer::materialize_nested_swizzle_base(
  self : WgslIrLowerer,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
  value : Handle,
) -> Handle raise WgslIrLowerError {
  if self.function_expression_should_materialize_projection_base_value(
      function, value,
    ) {
    self.materialize_function_expression(function, scope, block, value)
  } else {
    self.materialize_nested_access_base(function, scope, block, value)
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
  if wgsl_ir_function_expression_is_projection_of_generated_temporary(
      function, normalized,
    ) {
    return normalized
  }
  if self.function_expression_should_materialize_as_call_argument(
      function, normalized,
    ) ||
    self.function_expression_should_materialize_as_nested_value(
      function, normalized,
    ) ||
    self.function_expression_should_materialize_as_store_value(
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
fn WgslIrLowerer::materialize_store_value_if_needed(
  self : WgslIrLowerer,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
  value : Handle,
) -> Handle raise WgslIrLowerError {
  let normalized = self.materialize_return_subexpressions(
    function, scope, block, value,
  )
  if self.function_expression_should_materialize_as_store_value(
      function, normalized,
    ) {
    self.materialize_function_expression(function, scope, block, normalized)
  } else {
    normalized
  }
}

///|
fn WgslIrLowerer::compound_assignment_target_value(
  self : WgslIrLowerer,
  function : Function,
  target : Handle,
) -> Handle {
  let direct_projection = match function.expressions.items.get(target.index()) {
    Some(Access(_, _)) | Some(AccessIndex(_, _)) | Some(Swizzle(_, _, _)) =>
      true
    _ => false
  }
  if direct_projection {
    match self.function_expression_type(function, target) {
      Some(ty) => if !self.lowerer_type_is_pointer(ty) { return target }
      None => return target
    }
  }
  function.expressions.append(Expression::Load(target))
}

///|
fn WgslIrLowerer::lowerer_type_is_pointer(
  self : WgslIrLowerer,
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
    Some(Load(_))
    | Some(Access(_, _))
    | Some(AccessIndex(_, _))
    | Some(Swizzle(_, _, _)) =>
      self.function_expression_reads_global_binding(function, value)
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
  if wgsl_ir_function_expression_is_projection_of_generated_temporary(
      function, value,
    ) {
    return false
  }
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
    Some(Access(base, _))
    | Some(AccessIndex(base, _))
    | Some(Swizzle(_, base, _)) =>
      !wgsl_ir_function_expression_is_generated_temporary_reference(
        function, base,
      ) &&
      (
        self.function_expression_reads_global_binding(function, value) ||
        self.function_expression_reads_var_pointer_load(function, value)
      )
    _ => false
  }
  should_materialize &&
  self.function_expression_can_materialize_to_let(function, value)
}

///|
fn wgsl_ir_function_expression_is_projection_of_generated_temporary(
  function : Function,
  handle : Handle,
) -> Bool {
  match function.expressions.items.get(handle.index()) {
    Some(Access(base, _))
    | Some(AccessIndex(base, _))
    | Some(Swizzle(_, base, _)) =>
      wgsl_ir_function_expression_is_generated_temporary_reference(
        function, base,
      ) ||
      wgsl_ir_function_expression_has_generated_temporary_snapshot(
        function, base,
      )
    _ => false
  }
}

///|
fn wgsl_ir_function_expression_has_generated_temporary_snapshot(
  function : Function,
  handle : Handle,
) -> Bool {
  for local_var in function.local_variables.items {
    if local_var.generated_temporary && local_var.init == Some(handle) {
      return true
    }
  }
  false
}

///|
fn WgslIrLowerer::function_expression_should_materialize_as_access_base(
  self : WgslIrLowerer,
  function : Function,
  value : Handle,
) -> Bool {
  ignore(self)
  let should_materialize = match function.expressions.items.get(value.index()) {
    Some(FunctionCall(_, _))
    | Some(AtomicCall(_, _))
    | Some(ImageSample(_, _, _, _, _, _, _, _, _))
    | Some(ImageLoad(_, _, _, _, _))
    | Some(ImageQuery(_, _)) => true
    _ => false
  }
  should_materialize
}

///|
fn WgslIrLowerer::function_expression_should_materialize_projection_base_value(
  self : WgslIrLowerer,
  function : Function,
  value : Handle,
) -> Bool {
  let should_materialize = match function.expressions.items.get(value.index()) {
    Some(Load(_))
    | Some(Access(_, _))
    | Some(AccessIndex(_, _))
    | Some(Swizzle(_, _, _)) =>
      self.function_expression_reads_global_binding(function, value) ||
      self.function_expression_reads_var_pointer_load(function, value)
    _ => false
  }
  should_materialize &&
  self.function_expression_can_materialize_to_let(function, value)
}

///|
fn WgslIrLowerer::function_expression_should_materialize_as_call_argument(
  self : WgslIrLowerer,
  function : Function,
  value : Handle,
) -> Bool {
  if wgsl_ir_function_expression_is_projection_of_generated_temporary(
      function, value,
    ) {
    return false
  }
  self.function_expression_is_var_pointer_load(function, value) &&
  self.function_expression_can_materialize_to_let(function, value)
}

///|
fn WgslIrLowerer::function_expression_is_var_pointer_load(
  self : WgslIrLowerer,
  function : Function,
  value : Handle,
) -> Bool {
  match function.expressions.items.get(value.index()) {
    Some(Load(pointer)) =>
      self.function_pointer_expression_is_var_pointer(function, pointer)
    _ => false
  }
}

///|
fn WgslIrLowerer::function_pointer_expression_is_var_pointer(
  self : WgslIrLowerer,
  function : Function,
  value : Handle,
) -> Bool {
  match function.expressions.items.get(value.index()) {
    Some(LocalVariable(handle)) =>
      match function.local_variables.items.get(handle.index()) {
        Some(local_variable) =>
          local_variable.kind == Var ||
          self.local_variable_is_handle_value(function, handle)
        None => false
      }
    Some(FunctionArgument(index)) =>
      match function.arguments.get(index) {
        Some(argument) =>
          self.function_argument_type_is_function_pointer(argument.ty)
        None => false
      }
    Some(Access(base, index)) =>
      self.function_pointer_expression_is_var_pointer(function, base) ||
      self.function_expression_reads_var_pointer_load(function, index)
    Some(AccessIndex(base, _)) | Some(Swizzle(_, base, _)) =>
      self.function_pointer_expression_is_var_pointer(function, base)
    _ => false
  }
}

///|
fn WgslIrLowerer::function_argument_type_is_function_pointer(
  self : WgslIrLowerer,
  ty : Handle,
) -> Bool {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Pointer(_, Function) | ValuePointer(_, _, Function) => true
        _ => false
      }
    None => false
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
      self.function_pointer_expression_is_var_pointer(function, pointer)
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
        LocalVariable(local_handle) =>
          match function.local_variables.items.get(local_handle.index()) {
            Some(local_variable) => local_variable.kind == Let
            None => false
          }
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
