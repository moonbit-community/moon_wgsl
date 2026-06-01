///|
fn WgslIrValidator::validate_function(
  self : WgslIrValidator,
  function : Function,
) -> Unit raise WgslIrValidationError {
  for argument in function.arguments {
    self.require_type(argument.ty)
  }
  match function.result {
    Some(result) => self.require_type(result.ty)
    None => ()
  }
  for local_var in function.local_variables.items {
    self.require_type(local_var.ty)
    match local_var.init {
      Some(init) => self.validate_function_expression_handle(function, init)
      None => ()
    }
  }
  for expression in function.expressions.items {
    self.validate_function_expression(function, expression)
  }
  self.validate_block(function, function.body)
}

///|
fn WgslIrValidator::validate_block(
  self : WgslIrValidator,
  function : Function,
  block : Block,
) -> Unit raise WgslIrValidationError {
  for statement in block.statements {
    self.validate_statement(function, statement)
  }
}

///|
fn WgslIrValidator::validate_statement(
  self : WgslIrValidator,
  function : Function,
  statement : Statement,
) -> Unit raise WgslIrValidationError {
  match statement {
    Declare(handle) => self.require_local_variable(function, handle)
    Emit(range) => self.validate_function_expression_range(function, range)
    Phony(handle) => self.validate_function_expression_handle(function, handle)
    Block(block) => self.validate_block(function, block)
    If(condition, accept, reject) => {
      self.validate_function_expression_handle(function, condition)
      self.require_bool_condition(function, condition)
      self.validate_block(function, accept)
      self.validate_block(function, reject)
    }
    Switch(selector, cases) => {
      self.validate_function_expression_handle(function, selector)
      self.require_integer_selector(function, selector)
      for case in cases {
        self.validate_block(function, case.body)
      }
    }
    Loop(body, continuing, break_if) => {
      self.validate_block(function, body)
      self.validate_block(function, continuing)
      match break_if {
        Some(condition) => {
          self.validate_function_expression_handle(function, condition)
          self.require_bool_condition(function, condition)
        }
        None => ()
      }
    }
    Return(value) =>
      match value {
        Some(handle) => {
          self.validate_function_expression_handle(function, handle)
          self.require_return_value(function, handle)
        }
        None => self.require_void_return(function)
      }
    ImplicitReturn => self.require_void_return(function)
    ConstAssert(condition) => {
      self.validate_function_expression_handle(function, condition)
      self.require_bool_condition(function, condition)
    }
    Store(pointer, value) => {
      self.validate_function_expression_handle(function, pointer)
      self.validate_function_expression_handle(function, value)
      self.require_store(function, pointer, value)
    }
    ImageStore(image, coordinate, array_index, value) => {
      self.validate_function_expression_handle(function, image)
      self.validate_function_expression_handle(function, coordinate)
      match array_index {
        Some(index) => self.validate_function_expression_handle(function, index)
        None => ()
      }
      self.validate_function_expression_handle(function, value)
      self.require_image_store_signature(function, image, value)
    }
    Atomic(pointer, atomic_function, value, compare) => {
      self.validate_function_expression_handle(function, pointer)
      self.validate_function_expression_handle(function, value)
      match compare {
        Some(handle) =>
          self.validate_function_expression_handle(function, handle)
        None => ()
      }
      self.require_atomic_statement_signature(
        function, pointer, atomic_function, value, compare,
      )
    }
    ImageAtomic(image, coordinate, array_index, atomic_function, value) => {
      self.validate_function_expression_handle(function, image)
      self.validate_function_expression_handle(function, coordinate)
      match array_index {
        Some(index) => self.validate_function_expression_handle(function, index)
        None => ()
      }
      self.validate_function_expression_handle(function, value)
      self.require_image_atomic_signature(
        function, image, atomic_function, value,
      )
    }
    WorkGroupUniformLoad(pointer, result) => {
      self.validate_function_expression_handle(function, pointer)
      self.validate_function_expression_handle(function, result)
      self.require_workgroup_uniform_load_signature(function, pointer, result)
    }
    Call(callee, arguments, result) => {
      self.require_function(callee)
      for argument in arguments {
        self.validate_function_expression_handle(function, argument)
      }
      self.require_call_signature(function, callee, arguments, result)
      match result {
        Some(handle) =>
          self.validate_function_expression_handle(function, handle)
        None => ()
      }
    }
    RayQuery(handle, _) =>
      self.validate_function_expression_handle(function, handle)
    RayPipelineFunction(_) => ()
    SubgroupBallot(value, result) => {
      self.validate_function_expression_handle(function, value)
      match result {
        Some(handle) =>
          self.validate_function_expression_handle(function, handle)
        None => ()
      }
      self.require_subgroup_ballot_signature(function, value, result)
    }
    SubgroupGather(_, value, result) => {
      self.validate_function_expression_handle(function, value)
      self.validate_function_expression_handle(function, result)
      self.require_matching_statement_result(function, value, result)
    }
    SubgroupCollectiveOperation(_, _, value, result) => {
      self.validate_function_expression_handle(function, value)
      self.validate_function_expression_handle(function, result)
      self.require_matching_statement_result(function, value, result)
    }
    CooperativeStore(_, data) => self.validate_cooperative_data(function, data)
    Break | Continue | Kill | ControlBarrier(_) | MemoryBarrier(_) => ()
  }
}
