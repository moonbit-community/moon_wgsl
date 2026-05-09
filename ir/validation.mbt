///|
pub suberror WgslIrValidationError {
  InvalidTypeHandle(Int)
  InvalidConstantHandle(Int)
  InvalidOverrideHandle(Int)
  InvalidGlobalVariableHandle(Int)
  InvalidGlobalExpressionHandle(Int)
  InvalidFunctionHandle(Int)
  InvalidLocalVariableHandle(Int)
  InvalidFunctionExpressionHandle(Int)
  InvalidHandleRange(Int, Int)
  InvalidEntryPoint(String)
  MissingExpressionType(Int, String)
  InvalidConditionType(String, Int, String, String)
  InvalidStoreTarget(Int)
  InvalidReturnValue(String)
  InvalidFunctionArgumentCount(String, Int, Int)
  InvalidFunctionArgumentType(String, Int)
  InvalidFunctionResult(String)
  InvalidType(String)
  InvalidGlobalVariable(String)
  InvalidExpression(String, Int)
  InvalidStatement(String)
}

///|
pub fn WgslIrValidationError::message(self : WgslIrValidationError) -> String {
  match self {
    InvalidTypeHandle(index) => "invalid IR type handle: \{index}"
    InvalidConstantHandle(index) => "invalid IR constant handle: \{index}"
    InvalidOverrideHandle(index) => "invalid IR override handle: \{index}"
    InvalidGlobalVariableHandle(index) =>
      "invalid IR global variable handle: \{index}"
    InvalidGlobalExpressionHandle(index) =>
      "invalid IR global expression handle: \{index}"
    InvalidFunctionHandle(index) => "invalid IR function handle: \{index}"
    InvalidLocalVariableHandle(index) =>
      "invalid IR local variable handle: \{index}"
    InvalidFunctionExpressionHandle(index) =>
      "invalid IR function expression handle: \{index}"
    InvalidHandleRange(start, end) =>
      "invalid IR handle range: \{start}..\{end}"
    InvalidEntryPoint(name) => "invalid IR entry point: \{name}"
    MissingExpressionType(index, expression) =>
      "missing IR expression type for handle: \{index} (\{expression})"
    InvalidConditionType(function_name, index, expression, ty) =>
      "invalid IR condition expression type in \{function_name} for handle: \{index} (\{expression}) with type \{ty}"
    InvalidStoreTarget(index) =>
      "invalid IR store target expression type for handle: \{index}"
    InvalidReturnValue(name) => "invalid IR return value for function: \{name}"
    InvalidFunctionArgumentCount(name, expected, actual) =>
      "invalid IR function call argument count for \{name}: expected \{expected}, got \{actual}"
    InvalidFunctionArgumentType(name, index) =>
      "invalid IR function call argument type for \{name} at argument \{index}"
    InvalidFunctionResult(name) => "invalid IR function call result for \{name}"
    InvalidType(message) => "invalid IR type: \{message}"
    InvalidGlobalVariable(message) => "invalid IR global variable: \{message}"
    InvalidExpression(message, index) =>
      "invalid IR expression for handle \{index}: \{message}"
    InvalidStatement(message) => "invalid IR statement: \{message}"
  }
}

///|
pub fn validate_wgsl_ir_module(
  shader_module : Module,
) -> Unit raise WgslIrValidationError {
  let validator = WgslIrValidator::{ shader_module, filter: None }
  validator.validate_module()
}

///|
fn validate_wgsl_ir_module_with_filter(
  shader_module : Module,
  filter : WgslIrEmitFilter,
) -> Unit raise WgslIrValidationError {
  let validator = WgslIrValidator::{ shader_module, filter: Some(filter) }
  validator.validate_module()
}

///|
priv struct WgslIrValidator {
  shader_module : Module
  filter : WgslIrEmitFilter?
}

///|
priv struct WgslIrValidationLayout {
  align : Int
  size : Int
}

///|
fn WgslIrValidator::validate_module(
  self : WgslIrValidator,
) -> Unit raise WgslIrValidationError {
  for index in 0..<self.shader_module.types.items.length() {
    if self.should_validate_type(index) {
      self.validate_type_inner(self.shader_module.types.items[index].inner)
    }
  }
  for index in 0..<self.shader_module.constants.items.length() {
    if self.should_validate_constant(index) {
      let constant = self.shader_module.constants.items[index]
      self.require_type(constant.ty)
      self.validate_global_expression_handle(constant.init)
    }
  }
  for condition in self.shader_module.const_asserts {
    self.validate_global_expression_handle(condition)
  }
  for index in 0..<self.shader_module.overrides.items.length() {
    if self.should_validate_override(index) {
      let override_ = self.shader_module.overrides.items[index]
      self.require_type(override_.ty)
      match override_.init {
        Some(init) => self.validate_global_expression_handle(init)
        None => ()
      }
    }
  }
  for index in 0..<self.shader_module.global_variables.items.length() {
    if self.should_validate_global_variable(index) {
      let global = self.shader_module.global_variables.items[index]
      self.validate_global_variable(global)
    }
  }
  for index in 0..<self.shader_module.global_expressions.items.length() {
    if self.should_validate_global_expression(index) {
      self.validate_global_expression(
        self.shader_module.global_expressions.items[index],
      )
    }
  }
  for index in 0..<self.shader_module.functions.items.length() {
    if self.should_validate_function(index) {
      self.validate_function(self.shader_module.functions.items[index])
    }
  }
  for index in 0..<self.shader_module.entry_points.length() {
    if self.should_validate_entry_point(index) {
      self.validate_entry_point(self.shader_module.entry_points[index])
    }
  }
}

///|
fn WgslIrValidator::validate_entry_point(
  self : WgslIrValidator,
  entry_point : EntryPoint,
) -> Unit raise WgslIrValidationError {
  if entry_point.name == "" {
    raise WgslIrValidationError::InvalidEntryPoint(entry_point.name)
  }
  self.validate_function(entry_point.function)
}

///|
fn WgslIrValidator::should_validate_type(
  self : WgslIrValidator,
  index : Int,
) -> Bool {
  match self.filter {
    Some(filter) => filter.contains_type(index)
    None => true
  }
}

///|
fn WgslIrValidator::should_validate_constant(
  self : WgslIrValidator,
  index : Int,
) -> Bool {
  match self.filter {
    Some(filter) => filter.contains_constant(index)
    None => true
  }
}

///|
fn WgslIrValidator::should_validate_override(
  self : WgslIrValidator,
  index : Int,
) -> Bool {
  match self.filter {
    Some(filter) => filter.contains_override(index)
    None => true
  }
}

///|
fn WgslIrValidator::should_validate_global_variable(
  self : WgslIrValidator,
  index : Int,
) -> Bool {
  match self.filter {
    Some(filter) => filter.contains_global_variable(index)
    None => true
  }
}

///|
fn WgslIrValidator::should_validate_global_expression(
  self : WgslIrValidator,
  index : Int,
) -> Bool {
  ignore(index)
  match self.filter {
    Some(_) => false
    None => true
  }
}

///|
fn WgslIrValidator::should_validate_function(
  self : WgslIrValidator,
  index : Int,
) -> Bool {
  match self.filter {
    Some(filter) => filter.contains_function(index)
    None => true
  }
}

///|
fn WgslIrValidator::should_validate_entry_point(
  self : WgslIrValidator,
  index : Int,
) -> Bool {
  match self.filter {
    Some(filter) => filter.contains_entry_point(index)
    None => true
  }
}

///|
fn WgslIrValidator::validate_type_inner(
  self : WgslIrValidator,
  inner : TypeInner,
) -> Unit raise WgslIrValidationError {
  match inner {
    Pointer(base, space) => {
      self.require_type(base)
      self.validate_pointer_address_space(space)
    }
    ValuePointer(_, _, space) => self.validate_pointer_address_space(space)
    Array(base, size, stride) => {
      self.require_type(base)
      self.validate_array_size(size)
      self.validate_array_stride(base, stride)
    }
    BindingArray(base, size) => {
      self.require_type(base)
      self.validate_array_size(size)
    }
    Struct(members, span) => self.validate_struct_layout(members, span)
    PredeclaredStruct(members, _) =>
      for struct_member in members {
        self.require_type(struct_member.ty)
      }
    Atomic(scalar) => self.validate_atomic_scalar(scalar)
    _ => ()
  }
}

///|
fn WgslIrValidator::validate_array_size(
  self : WgslIrValidator,
  size : ArraySize,
) -> Unit raise WgslIrValidationError {
  match size {
    Pending(handle) => self.validate_global_expression_handle(handle)
    Constant(_) | Dynamic => ()
  }
}

///|
fn WgslIrValidator::validate_global_variable(
  self : WgslIrValidator,
  global : GlobalVariable,
) -> Unit raise WgslIrValidationError {
  self.require_type(global.ty)
  self.validate_global_address_space(global)
  match global.binding {
    Some(binding) => {
      if binding.group < 0 || binding.binding < 0 {
        raise WgslIrValidationError::InvalidGlobalVariable(
          "negative resource binding",
        )
      }
      if !self.global_address_space_accepts_resource_binding(global.space) {
        raise WgslIrValidationError::InvalidGlobalVariable(
          "resource binding on non-resource address space",
        )
      }
    }
    None => ()
  }
  match global.init {
    Some(init) => {
      if !self.global_address_space_accepts_initializer(global.space) {
        raise WgslIrValidationError::InvalidGlobalVariable(
          "initializer on non-initializable address space",
        )
      }
      self.validate_global_expression_handle(init)
    }
    None => ()
  }
}

///|
fn WgslIrValidator::validate_global_address_space(
  self : WgslIrValidator,
  global : GlobalVariable,
) -> Unit raise WgslIrValidationError {
  match global.space {
    Handle =>
      if !self.type_is_handle_resource(global.ty) {
        raise WgslIrValidationError::InvalidGlobalVariable(
          "handle address space requires handle resource type",
        )
      }
    Storage(access) =>
      if access == StorageAccess::empty() {
        raise WgslIrValidationError::InvalidGlobalVariable(
          "storage address space has empty access",
        )
      }
    _ => ()
  }
}

///|
fn WgslIrValidator::global_address_space_accepts_resource_binding(
  self : WgslIrValidator,
  space : AddressSpace,
) -> Bool {
  ignore(self)
  match space {
    Uniform | Storage(_) | Handle => true
    _ => false
  }
}

///|
fn WgslIrValidator::global_address_space_accepts_initializer(
  self : WgslIrValidator,
  space : AddressSpace,
) -> Bool {
  ignore(self)
  match space {
    Private => true
    _ => false
  }
}

///|
fn WgslIrValidator::validate_pointer_address_space(
  self : WgslIrValidator,
  space : AddressSpace,
) -> Unit raise WgslIrValidationError {
  ignore(self)
  match space {
    Function
    | Private
    | WorkGroup
    | Uniform
    | Storage(_)
    | TaskPayload
    | RayPayload
    | IncomingRayPayload => ()
    Handle | Immediate =>
      raise WgslIrValidationError::InvalidType(
        "pointer uses non-addressable address space",
      )
  }
}

///|
fn WgslIrValidator::validate_atomic_scalar(
  self : WgslIrValidator,
  scalar : Scalar,
) -> Unit raise WgslIrValidationError {
  ignore(self)
  if !(scalar.kind == Sint || scalar.kind == Uint) || scalar.width != 4 {
    raise WgslIrValidationError::InvalidType(
      "atomic type must use i32 or u32 scalar",
    )
  }
}

///|
fn WgslIrValidator::validate_array_stride(
  self : WgslIrValidator,
  base : Handle,
  stride : Int,
) -> Unit raise WgslIrValidationError {
  if stride <= 0 {
    raise WgslIrValidationError::InvalidType("array stride must be positive")
  }
  let layout = self.type_layout(base)
  if stride < layout.size {
    raise WgslIrValidationError::InvalidType(
      "array stride is smaller than element size",
    )
  }
  if stride % layout.align != 0 {
    raise WgslIrValidationError::InvalidType(
      "array stride is not aligned to element alignment",
    )
  }
}

///|
fn WgslIrValidator::validate_struct_layout(
  self : WgslIrValidator,
  members : Array[StructMember],
  span : Int,
) -> Unit raise WgslIrValidationError {
  if span <= 0 {
    raise WgslIrValidationError::InvalidType("struct span must be positive")
  }
  let mut end = 0
  let mut max_align = 1
  for index in 0..<members.length() {
    let struct_member = members[index]
    self.require_type(struct_member.ty)
    if self.type_is_runtime_array(struct_member.ty) &&
      index != members.length() - 1 {
      raise WgslIrValidationError::InvalidType(
        "runtime array is only valid as the last struct member",
      )
    }
    let layout = self.type_layout(struct_member.ty)
    let member_align = match struct_member.align {
      Some(value) => value
      None => layout.align
    }
    if !wgsl_ir_validation_is_power_of_two(member_align) ||
      member_align < layout.align {
      raise WgslIrValidationError::InvalidType(
        "struct member alignment is invalid",
      )
    }
    let member_size = match struct_member.size {
      Some(value) => value
      None => layout.size
    }
    if member_size < layout.size {
      raise WgslIrValidationError::InvalidType(
        "struct member size is smaller than type size",
      )
    }
    if struct_member.offset < end {
      raise WgslIrValidationError::InvalidType(
        "struct member offset overlaps previous member",
      )
    }
    if struct_member.offset % member_align != 0 {
      raise WgslIrValidationError::InvalidType(
        "struct member offset is not aligned",
      )
    }
    end = struct_member.offset + member_size
    if member_align > max_align {
      max_align = member_align
    }
  }
  if span < end {
    raise WgslIrValidationError::InvalidType(
      "struct span is smaller than member range",
    )
  }
  if span % max_align != 0 {
    raise WgslIrValidationError::InvalidType(
      "struct span is not aligned to struct alignment",
    )
  }
}

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

///|
fn WgslIrValidator::validate_global_expression(
  self : WgslIrValidator,
  expression : Expression,
) -> Unit raise WgslIrValidationError {
  match expression {
    Constant(handle) => self.require_constant(handle)
    Override(handle) => self.require_override(handle)
    ZeroValue(ty) => self.require_type(ty)
    Compose(ty, components) => {
      self.require_type(ty)
      for component in components {
        self.validate_global_expression_handle(component)
      }
      self.require_global_compose_signature(ty, components)
    }
    Access(base, index) => {
      self.validate_global_expression_handle(base)
      self.validate_global_expression_handle(index)
      self.require_global_access_signature(base, index)
    }
    AccessIndex(base, index) => {
      self.validate_global_expression_handle(base)
      self.require_global_access_index_signature(base, index)
    }
    GlobalVariable(handle) => self.require_global_variable(handle)
    Load(pointer) => self.validate_global_expression_handle(pointer)
    AddressOf(ty, target) => {
      self.require_type(ty)
      self.validate_global_expression_handle(target)
      self.require_global_address_of_signature(ty, target)
    }
    Unary(_, expr) => self.validate_global_expression_handle(expr)
    Binary(_, left, right) => {
      self.validate_global_expression_handle(left)
      self.validate_global_expression_handle(right)
    }
    FunctionCall(handle, arguments) => {
      self.require_function(handle)
      for argument in arguments {
        self.validate_global_expression_handle(argument)
      }
      self.require_global_call_signature(handle, arguments)
    }
    Select(condition, accept, reject) => {
      self.validate_global_expression_handle(condition)
      self.validate_global_expression_handle(accept)
      self.validate_global_expression_handle(reject)
      self.require_global_select_signature(condition, accept, reject)
    }
    Bitcast(ty, expr) => {
      self.require_type(ty)
      self.validate_global_expression_handle(expr)
    }
    As(expr, kind, width) => {
      self.validate_global_expression_handle(expr)
      self.require_as_width(kind, width)
    }
    Relational(_, expr) => self.validate_global_expression_handle(expr)
    Literal(_) => ()
    _ => ()
  }
}

///|
fn WgslIrValidator::validate_function_expression(
  self : WgslIrValidator,
  function : Function,
  expression : Expression,
) -> Unit raise WgslIrValidationError {
  match expression {
    Constant(handle) => self.require_constant(handle)
    Override(handle) => self.require_override(handle)
    ZeroValue(ty) => self.require_type(ty)
    Compose(ty, components) => {
      self.require_type(ty)
      for component in components {
        self.validate_function_expression_handle(function, component)
      }
      self.require_function_compose_signature(function, ty, components)
    }
    Access(base, index) => {
      self.validate_function_expression_handle(function, base)
      self.validate_function_expression_handle(function, index)
      self.require_function_access_signature(function, base, index)
    }
    AccessIndex(base, index) => {
      self.validate_function_expression_handle(function, base)
      self.require_function_access_index_signature(function, base, index)
    }
    FunctionArgument(index) =>
      if index < 0 || index >= function.arguments.length() {
        raise WgslIrValidationError::InvalidFunctionExpressionHandle(index)
      }
    GlobalVariable(handle) => self.require_global_variable(handle)
    LocalVariable(handle) => self.require_local_variable(function, handle)
    Load(pointer) => self.validate_function_expression_handle(function, pointer)
    AddressOf(ty, target) => {
      self.require_type(ty)
      self.validate_function_expression_handle(function, target)
      self.require_function_address_of_signature(function, ty, target)
    }
    Unary(_, expr) => self.validate_function_expression_handle(function, expr)
    Binary(_, left, right) => {
      self.validate_function_expression_handle(function, left)
      self.validate_function_expression_handle(function, right)
    }
    FunctionCall(handle, arguments) => {
      self.require_function(handle)
      for argument in arguments {
        self.validate_function_expression_handle(function, argument)
      }
      self.require_call_signature(function, handle, arguments, None)
    }
    Select(condition, accept, reject) => {
      self.validate_function_expression_handle(function, condition)
      self.validate_function_expression_handle(function, accept)
      self.validate_function_expression_handle(function, reject)
      self.require_select_signature(function, condition, accept, reject)
    }
    ImageSample(
      image,
      sampler,
      gather,
      coordinate,
      array_index,
      offset,
      level,
      depth_ref,
      _
    ) => {
      self.validate_function_expression_handle(function, image)
      self.validate_function_expression_handle(function, sampler)
      match gather {
        Some(_) => ()
        None => ()
      }
      self.validate_function_expression_handle(function, coordinate)
      match array_index {
        Some(handle) =>
          self.validate_function_expression_handle(function, handle)
        None => ()
      }
      match offset {
        Some(handle) =>
          self.validate_function_expression_handle(function, handle)
        None => ()
      }
      self.validate_sample_level(function, level)
      match depth_ref {
        Some(handle) =>
          self.validate_function_expression_handle(function, handle)
        None => ()
      }
    }
    ImageLoad(image, coordinate, array_index, sample, level) => {
      self.validate_function_expression_handle(function, image)
      self.validate_function_expression_handle(function, coordinate)
      match array_index {
        Some(handle) =>
          self.validate_function_expression_handle(function, handle)
        None => ()
      }
      match sample {
        Some(handle) =>
          self.validate_function_expression_handle(function, handle)
        None => ()
      }
      match level {
        Some(handle) =>
          self.validate_function_expression_handle(function, handle)
        None => ()
      }
    }
    ImageQuery(image, query) => {
      self.validate_function_expression_handle(function, image)
      match query {
        Size(level) =>
          match level {
            Some(handle) =>
              self.validate_function_expression_handle(function, handle)
            None => ()
          }
        _ => ()
      }
    }
    RayQueryInitialize(query, acceleration, ray_desc) => {
      self.validate_function_expression_handle(function, query)
      self.validate_function_expression_handle(function, acceleration)
      self.validate_function_expression_handle(function, ray_desc)
    }
    RayQueryProceed(query)
    | RayQueryConfirmIntersection(query)
    | RayQueryTerminate(query)
    | RayQueryGetIntersection(query, _) =>
      self.validate_function_expression_handle(function, query)
    RayQueryGenerateIntersection(query, intersection_t) => {
      self.validate_function_expression_handle(function, query)
      self.validate_function_expression_handle(function, intersection_t)
    }
    Math(_, a, b, c, d) => {
      self.validate_function_expression_handle(function, a)
      self.validate_optional_function_expression(function, b)
      self.validate_optional_function_expression(function, c)
      self.validate_optional_function_expression(function, d)
    }
    AtomicCall(atomic_function, arguments) => {
      for argument in arguments {
        self.validate_function_expression_handle(function, argument)
      }
      self.require_atomic_call_signature(function, atomic_function, arguments)
    }
    Bitcast(ty, expr) => {
      self.require_type(ty)
      self.validate_function_expression_handle(function, expr)
    }
    As(expr, kind, width) => {
      self.validate_function_expression_handle(function, expr)
      self.require_as_width(kind, width)
    }
    CallResult(handle) => self.require_function(handle)
    AtomicResult(handle, _) =>
      self.validate_function_expression_handle(function, handle)
    WorkGroupUniformLoadResult(handle) =>
      self.validate_function_expression_handle(function, handle)
    WorkGroupUniformLoad(handle) =>
      self.validate_function_expression_handle(function, handle)
    ArrayLength(handle) => {
      self.validate_function_expression_handle(function, handle)
      self.require_array_length_argument(function, handle)
    }
    Derivative(_, _, expr) =>
      self.validate_function_expression_handle(function, expr)
    Relational(_, expr) =>
      self.validate_function_expression_handle(function, expr)
    SubgroupCall(_, arguments) =>
      for argument in arguments {
        self.validate_function_expression_handle(function, argument)
      }
    CooperativeLoad(_, _, _, data) =>
      self.validate_cooperative_data(function, data)
    CooperativeMultiplyAdd(a, b, c) => {
      self.validate_function_expression_handle(function, a)
      self.validate_function_expression_handle(function, b)
      self.validate_function_expression_handle(function, c)
    }
    Splat(_, expr) => self.validate_function_expression_handle(function, expr)
    Swizzle(size, expr, components) => {
      self.validate_function_expression_handle(function, expr)
      self.require_swizzle_signature(function, size, expr, components)
    }
    Literal(_) => ()
    _ => ()
  }
}

///|
fn WgslIrValidator::validate_sample_level(
  self : WgslIrValidator,
  function : Function,
  level : SampleLevel,
) -> Unit raise WgslIrValidationError {
  match level {
    Exact(handle) | Bias(handle) =>
      self.validate_function_expression_handle(function, handle)
    Gradient(x, y) => {
      self.validate_function_expression_handle(function, x)
      self.validate_function_expression_handle(function, y)
    }
    Auto | Zero => ()
  }
}

///|
fn WgslIrValidator::validate_cooperative_data(
  self : WgslIrValidator,
  function : Function,
  data : CooperativeData,
) -> Unit raise WgslIrValidationError {
  self.validate_function_expression_handle(function, data.pointer)
  self.validate_function_expression_handle(function, data.stride)
}

///|
fn WgslIrValidator::validate_optional_function_expression(
  self : WgslIrValidator,
  function : Function,
  handle : Handle?,
) -> Unit raise WgslIrValidationError {
  match handle {
    Some(value) => self.validate_function_expression_handle(function, value)
    None => ()
  }
}

///|
fn WgslIrValidator::missing_function_expression_type(
  self : WgslIrValidator,
  function : Function,
  handle : Handle,
) -> WgslIrValidationError {
  ignore(self)
  let expression = match function.expressions.items.get(handle.index()) {
    Some(value) => @debug.to_string(value)
    None => "<invalid function expression handle>"
  }
  WgslIrValidationError::MissingExpressionType(handle.index(), expression)
}

///|
fn WgslIrValidator::missing_global_expression_type(
  self : WgslIrValidator,
  handle : Handle,
) -> WgslIrValidationError {
  let expression = match
    self.shader_module.global_expressions.items.get(handle.index()) {
    Some(value) => @debug.to_string(value)
    None => "<invalid global expression handle>"
  }
  WgslIrValidationError::MissingExpressionType(handle.index(), expression)
}

///|
fn WgslIrValidator::invalid_condition_type(
  self : WgslIrValidator,
  function : Function,
  handle : Handle,
  ty : Handle,
) -> WgslIrValidationError {
  let expression = match function.expressions.items.get(handle.index()) {
    Some(value) => @debug.to_string(value)
    None => "<invalid function expression handle>"
  }
  let ty_text = match self.shader_module.types.items.get(ty.index()) {
    Some(value) => @debug.to_string(value)
    None => "<invalid type handle>"
  }
  WgslIrValidationError::InvalidConditionType(
    self.function_display_name(function),
    handle.index(),
    expression,
    ty_text,
  )
}

///|
fn WgslIrValidator::require_bool_condition(
  self : WgslIrValidator,
  function : Function,
  handle : Handle,
) -> Unit raise WgslIrValidationError {
  guard self.function_expression_type(function, handle) is Some(ty) else {
    raise self.missing_function_expression_type(function, handle)
  }
  guard self.type_is_bool_scalar(ty) else {
    raise self.invalid_condition_type(function, handle, ty)
  }
}

///|
fn WgslIrValidator::require_integer_selector(
  self : WgslIrValidator,
  function : Function,
  handle : Handle,
) -> Unit raise WgslIrValidationError {
  guard self.function_expression_type(function, handle) is Some(ty) else {
    raise self.missing_function_expression_type(function, handle)
  }
  guard self.type_is_integer_scalar(ty) else {
    raise self.invalid_condition_type(function, handle, ty)
  }
}

///|
fn WgslIrValidator::require_return_value(
  self : WgslIrValidator,
  function : Function,
  handle : Handle,
) -> Unit raise WgslIrValidationError {
  guard function.result is Some(result) else {
    raise WgslIrValidationError::InvalidReturnValue(
      self.function_display_name(function),
    )
  }
  match self.function_expression_type(function, handle) {
    Some(actual) =>
      if !self.type_assignable(result.ty, actual) {
        raise WgslIrValidationError::InvalidReturnValue(
          self.function_display_name(function),
        )
      }
    None => ()
  }
}

///|
fn WgslIrValidator::require_void_return(
  self : WgslIrValidator,
  function : Function,
) -> Unit raise WgslIrValidationError {
  if function.result != None {
    raise WgslIrValidationError::InvalidReturnValue(
      self.function_display_name(function),
    )
  }
}

///|
fn WgslIrValidator::require_store(
  self : WgslIrValidator,
  function : Function,
  pointer : Handle,
  value : Handle,
) -> Unit raise WgslIrValidationError {
  guard self.store_target_value_type(function, pointer) is Some(value_ty) else {
    raise WgslIrValidationError::InvalidStoreTarget(pointer.index())
  }
  match self.function_expression_type(function, value) {
    Some(actual) =>
      if !self.type_assignable(value_ty, actual) {
        raise WgslIrValidationError::InvalidStoreTarget(pointer.index())
      }
    None => ()
  }
}

///|
fn WgslIrValidator::require_function_compose_signature(
  self : WgslIrValidator,
  function : Function,
  ty : Handle,
  components : Array[Handle],
) -> Unit raise WgslIrValidationError {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Scalar(_) =>
          if components.length() != 1 {
            raise WgslIrValidationError::InvalidExpression(
              "scalar constructor component count mismatch",
              ty.index(),
            )
          }
        Vector(size, _) =>
          self.require_composite_component_capacity(
            function,
            components,
            size.width(),
            ty.index(),
          )
        Matrix(columns, rows, _) =>
          self.require_composite_component_capacity(
            function,
            components,
            columns.width() * rows.width(),
            ty.index(),
          )
        Struct(members, _) | PredeclaredStruct(members, _) =>
          if components.length() != members.length() {
            raise WgslIrValidationError::InvalidExpression(
              "struct constructor component count mismatch",
              ty.index(),
            )
          }
        Array(_, Constant(count), _) | BindingArray(_, Constant(count)) =>
          if components.length() != count {
            raise WgslIrValidationError::InvalidExpression(
              "array constructor component count mismatch",
              ty.index(),
            )
          }
        Array(_, Dynamic, _) | BindingArray(_, Dynamic) =>
          raise WgslIrValidationError::InvalidExpression(
            "runtime array constructor is not valid",
            ty.index(),
          )
        _ => ()
      }
    None => ()
  }
}

///|
fn WgslIrValidator::require_global_compose_signature(
  self : WgslIrValidator,
  ty : Handle,
  components : Array[Handle],
) -> Unit raise WgslIrValidationError {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Scalar(_) =>
          if components.length() != 1 {
            raise WgslIrValidationError::InvalidExpression(
              "scalar constructor component count mismatch",
              ty.index(),
            )
          }
        Vector(size, _) =>
          self.require_global_composite_component_capacity(
            components,
            size.width(),
            ty.index(),
          )
        Matrix(columns, rows, _) =>
          self.require_global_composite_component_capacity(
            components,
            columns.width() * rows.width(),
            ty.index(),
          )
        Struct(members, _) | PredeclaredStruct(members, _) =>
          if components.length() != members.length() {
            raise WgslIrValidationError::InvalidExpression(
              "struct constructor component count mismatch",
              ty.index(),
            )
          }
        Array(_, Constant(count), _) | BindingArray(_, Constant(count)) =>
          if components.length() != count {
            raise WgslIrValidationError::InvalidExpression(
              "array constructor component count mismatch",
              ty.index(),
            )
          }
        Array(_, Dynamic, _) | BindingArray(_, Dynamic) =>
          raise WgslIrValidationError::InvalidExpression(
            "runtime array constructor is not valid",
            ty.index(),
          )
        _ => ()
      }
    None => ()
  }
}

///|
fn WgslIrValidator::require_composite_component_capacity(
  self : WgslIrValidator,
  function : Function,
  components : Array[Handle],
  expected_lanes : Int,
  expression_index : Int,
) -> Unit raise WgslIrValidationError {
  if components.length() == 0 {
    return
  }
  let mut lanes = 0
  for component in components {
    match self.function_expression_lane_count(function, component) {
      Some(count) => lanes += count
      None => raise self.missing_function_expression_type(function, component)
    }
  }
  if lanes != expected_lanes && !(components.length() == 1 && lanes == 1) {
    raise WgslIrValidationError::InvalidExpression(
      "vector constructor lane count mismatch", expression_index,
    )
  }
}

///|
fn WgslIrValidator::function_expression_lane_count(
  self : WgslIrValidator,
  function : Function,
  handle : Handle,
) -> Int? {
  match function.expressions.items.get(handle.index()) {
    Some(expression) =>
      match expression {
        Swizzle(size, _, _) | Splat(size, _) => Some(size.width())
        Compose(ty, _) | ZeroValue(ty) =>
          match self.shader_module.types.get(ty) {
            Some(_) => Some(self.type_lane_count(ty))
            None => None
          }
        Literal(_) => Some(1)
        _ =>
          match self.function_expression_type(function, handle) {
            Some(ty) => Some(self.type_lane_count(ty))
            None => None
          }
      }
    None => None
  }
}

///|
fn WgslIrValidator::global_expression_lane_count(
  self : WgslIrValidator,
  handle : Handle,
) -> Int? {
  match self.shader_module.global_expressions.items.get(handle.index()) {
    Some(expression) =>
      match expression {
        Swizzle(size, _, _) | Splat(size, _) => Some(size.width())
        Compose(ty, _) | ZeroValue(ty) =>
          match self.shader_module.types.get(ty) {
            Some(_) => Some(self.type_lane_count(ty))
            None => None
          }
        Literal(_) => Some(1)
        _ =>
          match self.global_expression_type(handle) {
            Some(ty) => Some(self.type_lane_count(ty))
            None => None
          }
      }
    None => None
  }
}

///|
fn WgslIrValidator::require_global_composite_component_capacity(
  self : WgslIrValidator,
  components : Array[Handle],
  expected_lanes : Int,
  expression_index : Int,
) -> Unit raise WgslIrValidationError {
  if components.length() == 0 {
    return
  }
  let mut lanes = 0
  for component in components {
    match self.global_expression_lane_count(component) {
      Some(count) => lanes += count
      None => {
        guard self.global_expression_type(component) is Some(_) else {
          raise self.missing_global_expression_type(component)
        }
      }
    }
  }
  if lanes != expected_lanes && !(components.length() == 1 && lanes == 1) {
    raise WgslIrValidationError::InvalidExpression(
      "vector constructor lane count mismatch", expression_index,
    )
  }
}

///|
fn WgslIrValidator::require_function_access_signature(
  self : WgslIrValidator,
  function : Function,
  base : Handle,
  index : Handle,
) -> Unit raise WgslIrValidationError {
  guard self.function_expression_type(function, base) is Some(base_ty) else {
    raise self.missing_function_expression_type(function, base)
  }
  guard self.dynamic_indexed_type(base_ty) is Some(_) else {
    raise WgslIrValidationError::InvalidExpression(
      "dynamic access base is not indexable",
      base.index(),
    )
  }
  guard self.function_expression_type(function, index) is Some(index_ty) else {
    raise self.missing_function_expression_type(function, index)
  }
  if !self.type_is_integer_scalar(index_ty) {
    raise WgslIrValidationError::InvalidExpression(
      "dynamic access index is not an integer scalar",
      index.index(),
    )
  }
}

///|
fn WgslIrValidator::require_global_access_signature(
  self : WgslIrValidator,
  base : Handle,
  index : Handle,
) -> Unit raise WgslIrValidationError {
  guard self.global_expression_type(base) is Some(base_ty) else {
    raise self.missing_global_expression_type(base)
  }
  guard self.dynamic_indexed_type(base_ty) is Some(_) else {
    raise WgslIrValidationError::InvalidExpression(
      "dynamic access base is not indexable",
      base.index(),
    )
  }
  guard self.global_expression_type(index) is Some(index_ty) else {
    raise self.missing_global_expression_type(index)
  }
  if !self.type_is_integer_scalar(index_ty) {
    raise WgslIrValidationError::InvalidExpression(
      "dynamic access index is not an integer scalar",
      index.index(),
    )
  }
}

///|
fn WgslIrValidator::require_function_access_index_signature(
  self : WgslIrValidator,
  function : Function,
  base : Handle,
  index : Int,
) -> Unit raise WgslIrValidationError {
  guard self.function_expression_type(function, base) is Some(base_ty) else {
    raise self.missing_function_expression_type(function, base)
  }
  guard self.indexed_type(base_ty, Some(index)) is Some(_) else {
    raise WgslIrValidationError::InvalidExpression(
      "constant access index is out of range or not indexable",
      base.index(),
    )
  }
}

///|
fn WgslIrValidator::require_global_access_index_signature(
  self : WgslIrValidator,
  base : Handle,
  index : Int,
) -> Unit raise WgslIrValidationError {
  guard self.global_expression_type(base) is Some(base_ty) else {
    raise self.missing_global_expression_type(base)
  }
  guard self.indexed_type(base_ty, Some(index)) is Some(_) else {
    raise WgslIrValidationError::InvalidExpression(
      "constant access index is out of range or not indexable",
      base.index(),
    )
  }
}

///|
fn WgslIrValidator::require_function_address_of_signature(
  self : WgslIrValidator,
  function : Function,
  ty : Handle,
  target : Handle,
) -> Unit raise WgslIrValidationError {
  guard self.expression_is_addressable(function, target) else {
    raise WgslIrValidationError::InvalidExpression(
      "address-of target is not addressable",
      target.index(),
    )
  }
  guard self.pointer_pointee_type(ty) is Some(pointee) else {
    raise WgslIrValidationError::InvalidExpression(
      "address-of result type is not pointer-like",
      target.index(),
    )
  }
  guard self.store_target_value_type(function, target) is Some(target_ty) else {
    raise WgslIrValidationError::InvalidExpression(
      "address-of target has no value type",
      target.index(),
    )
  }
  if !self.type_assignable(pointee, target_ty) {
    raise WgslIrValidationError::InvalidExpression(
      "address-of result pointee type does not match target",
      target.index(),
    )
  }
}

///|
fn WgslIrValidator::require_global_address_of_signature(
  self : WgslIrValidator,
  ty : Handle,
  target : Handle,
) -> Unit raise WgslIrValidationError {
  guard self.global_expression_is_addressable(target) else {
    raise WgslIrValidationError::InvalidExpression(
      "address-of target is not addressable",
      target.index(),
    )
  }
  guard self.pointer_pointee_type(ty) is Some(pointee) else {
    raise WgslIrValidationError::InvalidExpression(
      "address-of result type is not pointer-like",
      target.index(),
    )
  }
  guard self.global_expression_value_type(target) is Some(target_ty) else {
    raise WgslIrValidationError::InvalidExpression(
      "address-of target has no value type",
      target.index(),
    )
  }
  if !self.type_assignable(pointee, target_ty) {
    raise WgslIrValidationError::InvalidExpression(
      "address-of result pointee type does not match target",
      target.index(),
    )
  }
}

///|
fn WgslIrValidator::require_as_width(
  self : WgslIrValidator,
  kind : ScalarKind,
  width : Int?,
) -> Unit raise WgslIrValidationError {
  ignore(self)
  match width {
    Some(value) =>
      if !wgsl_ir_validation_scalar_width_is_valid(kind, value) {
        raise WgslIrValidationError::InvalidType("invalid scalar cast width")
      }
    None => ()
  }
}

///|
fn WgslIrValidator::require_call_signature(
  self : WgslIrValidator,
  function : Function,
  callee : Handle,
  arguments : Array[Handle],
  result : Handle?,
) -> Unit raise WgslIrValidationError {
  let callee_function = match
    self.shader_module.functions.items.get(callee.index()) {
    Some(value) => value
    None => return
  }
  let name = self.function_display_name(callee_function)
  if arguments.length() != callee_function.arguments.length() {
    raise WgslIrValidationError::InvalidFunctionArgumentCount(
      name,
      callee_function.arguments.length(),
      arguments.length(),
    )
  }
  for index in 0..<arguments.length() {
    let argument = arguments[index]
    match self.function_expression_type(function, argument) {
      Some(actual) =>
        if !self.type_assignable(callee_function.arguments[index].ty, actual) {
          raise WgslIrValidationError::InvalidFunctionArgumentType(name, index)
        }
      None => ()
    }
  }
  match (callee_function.result, result) {
    (Some(expected), Some(actual_handle)) =>
      match self.function_expression_type(function, actual_handle) {
        Some(actual) =>
          if !self.type_assignable(expected.ty, actual) {
            raise WgslIrValidationError::InvalidFunctionResult(name)
          }
        None => ()
      }
    (None, None) => ()
    (Some(_), None) => ()
    (None, Some(_)) => raise WgslIrValidationError::InvalidFunctionResult(name)
  }
}

///|
fn WgslIrValidator::require_global_call_signature(
  self : WgslIrValidator,
  callee : Handle,
  arguments : Array[Handle],
) -> Unit raise WgslIrValidationError {
  let callee_function = match
    self.shader_module.functions.items.get(callee.index()) {
    Some(value) => value
    None => return
  }
  let name = self.function_display_name(callee_function)
  if arguments.length() != callee_function.arguments.length() {
    raise WgslIrValidationError::InvalidFunctionArgumentCount(
      name,
      callee_function.arguments.length(),
      arguments.length(),
    )
  }
  for index in 0..<arguments.length() {
    let argument = arguments[index]
    match self.global_expression_type(argument) {
      Some(actual) =>
        if !self.type_assignable(callee_function.arguments[index].ty, actual) {
          raise WgslIrValidationError::InvalidFunctionArgumentType(name, index)
        }
      None => ()
    }
  }
}

///|
fn WgslIrValidator::require_select_signature(
  self : WgslIrValidator,
  function : Function,
  condition : Handle,
  accept : Handle,
  reject : Handle,
) -> Unit raise WgslIrValidationError {
  guard self.function_expression_type(function, condition) is Some(cond_ty) else {
    raise self.missing_function_expression_type(function, condition)
  }
  guard self.function_expression_type(function, accept) is Some(accept_ty) else {
    raise self.missing_function_expression_type(function, accept)
  }
  guard self.function_expression_type(function, reject) is Some(reject_ty) else {
    raise self.missing_function_expression_type(function, reject)
  }
  guard self.types_are_select_compatible(accept_ty, reject_ty) else {
    raise WgslIrValidationError::InvalidFunctionArgumentType("select", 1)
  }
  guard self.select_condition_type_matches_result(cond_ty, accept_ty) else {
    raise self.invalid_condition_type(function, condition, cond_ty)
  }
}

///|
fn WgslIrValidator::require_global_select_signature(
  self : WgslIrValidator,
  condition : Handle,
  accept : Handle,
  reject : Handle,
) -> Unit raise WgslIrValidationError {
  guard self.global_expression_type(condition) is Some(cond_ty) else {
    raise self.missing_global_expression_type(condition)
  }
  guard self.global_expression_type(accept) is Some(accept_ty) else {
    raise self.missing_global_expression_type(accept)
  }
  guard self.global_expression_type(reject) is Some(reject_ty) else {
    raise self.missing_global_expression_type(reject)
  }
  guard self.types_are_select_compatible(accept_ty, reject_ty) else {
    raise WgslIrValidationError::InvalidFunctionArgumentType("select", 1)
  }
  guard self.select_condition_type_matches_result(cond_ty, accept_ty) else {
    let expression = match
      self.shader_module.global_expressions.items.get(condition.index()) {
      Some(value) => @debug.to_string(value)
      None => "<invalid global expression handle>"
    }
    let ty_text = match self.shader_module.types.items.get(cond_ty.index()) {
      Some(value) => @debug.to_string(value)
      None => "<invalid type handle>"
    }
    raise WgslIrValidationError::InvalidConditionType(
      "<global>",
      condition.index(),
      expression,
      ty_text,
    )
  }
}

///|
fn WgslIrValidator::require_image_store_signature(
  self : WgslIrValidator,
  function : Function,
  image : Handle,
  value : Handle,
) -> Unit raise WgslIrValidationError {
  guard self.function_expression_type(function, image) is Some(image_ty) else {
    raise self.missing_function_expression_type(function, image)
  }
  let scalar = match self.shader_module.types.get(image_ty) {
    Some(type_) =>
      match type_.inner {
        Image(_, _, Storage(format, access)) =>
          if access.contains(StorageAccess::store()) {
            Some(wgsl_ir_validation_storage_format_scalar(format))
          } else {
            None
          }
        _ => None
      }
    None => None
  }
  guard scalar is Some(value_scalar) else {
    raise WgslIrValidationError::InvalidStatement(
      "imageStore target is not a writable storage texture",
    )
  }
  guard self.function_expression_type(function, value) is Some(actual) else {
    raise self.missing_function_expression_type(function, value)
  }
  guard self.vector_type(Quad, value_scalar) is Some(expected) else {
    raise WgslIrValidationError::InvalidStatement(
      "imageStore value has unsupported storage format",
    )
  }
  if !self.type_assignable(expected, actual) {
    raise WgslIrValidationError::InvalidStatement(
      "imageStore value type does not match storage texture format",
    )
  }
}

///|
fn WgslIrValidator::require_image_atomic_signature(
  self : WgslIrValidator,
  function : Function,
  image : Handle,
  atomic_function : AtomicFunction,
  value : Handle,
) -> Unit raise WgslIrValidationError {
  ignore(atomic_function)
  guard self.function_expression_type(function, image) is Some(image_ty) else {
    raise self.missing_function_expression_type(function, image)
  }
  let scalar = match self.shader_module.types.get(image_ty) {
    Some(type_) =>
      match type_.inner {
        Image(_, _, Storage(format, access)) =>
          if access.contains(StorageAccess::atomic_access()) {
            Some(wgsl_ir_validation_storage_format_scalar(format))
          } else {
            None
          }
        _ => None
      }
    None => None
  }
  guard scalar is Some(expected_scalar) else {
    raise WgslIrValidationError::InvalidStatement(
      "image atomic target is not an atomic storage texture",
    )
  }
  guard self.function_expression_type(function, value) is Some(actual) else {
    raise self.missing_function_expression_type(function, value)
  }
  guard self.find_scalar_type(expected_scalar) is Some(expected) else {
    raise WgslIrValidationError::InvalidStatement(
      "image atomic value has unsupported storage format",
    )
  }
  if !self.type_assignable(expected, actual) {
    raise WgslIrValidationError::InvalidStatement(
      "image atomic value type does not match storage texture format",
    )
  }
}

///|
fn WgslIrValidator::require_atomic_statement_signature(
  self : WgslIrValidator,
  function : Function,
  pointer : Handle,
  atomic_function : AtomicFunction,
  value : Handle,
  compare : Handle?,
) -> Unit raise WgslIrValidationError {
  guard self.function_expression_type(function, pointer) is Some(pointer_ty) else {
    raise self.missing_function_expression_type(function, pointer)
  }
  guard self.atomic_scalar_type(pointer_ty) is Some(scalar) else {
    raise WgslIrValidationError::InvalidStatement(
      "atomic statement target is not atomic",
    )
  }
  guard self.find_scalar_type(scalar) is Some(expected) else {
    raise WgslIrValidationError::InvalidStatement(
      "atomic statement scalar type is unavailable",
    )
  }
  guard self.function_expression_type(function, value) is Some(actual) else {
    raise self.missing_function_expression_type(function, value)
  }
  if !self.type_assignable(expected, actual) {
    raise WgslIrValidationError::InvalidStatement(
      "atomic statement value type mismatch",
    )
  }
  match (atomic_function, compare) {
    (CompareExchangeWeak, Some(compare_handle)) => {
      guard self.function_expression_type(function, compare_handle)
        is Some(compare_ty) else {
        raise self.missing_function_expression_type(function, compare_handle)
      }
      if !self.type_assignable(expected, compare_ty) {
        raise WgslIrValidationError::InvalidStatement(
          "atomic compare value type mismatch",
        )
      }
    }
    (CompareExchangeWeak, None) =>
      raise WgslIrValidationError::InvalidStatement(
        "atomic compare-exchange requires compare value",
      )
    (_, Some(_)) =>
      raise WgslIrValidationError::InvalidStatement(
        "atomic compare value is only valid for compare-exchange",
      )
    _ => ()
  }
}

///|
fn WgslIrValidator::require_atomic_call_signature(
  self : WgslIrValidator,
  function : Function,
  atomic_function : AtomicFunction,
  arguments : Array[Handle],
) -> Unit raise WgslIrValidationError {
  let expected_count = match atomic_function {
    Load => 1
    Store => 2
    CompareExchangeWeak => 3
    _ => 2
  }
  if arguments.length() != expected_count {
    raise WgslIrValidationError::InvalidFunctionArgumentCount(
      "atomic",
      expected_count,
      arguments.length(),
    )
  }
  guard arguments.get(0) is Some(pointer) else { return }
  guard self.function_expression_type(function, pointer) is Some(pointer_ty) else {
    raise self.missing_function_expression_type(function, pointer)
  }
  guard self.atomic_scalar_type(pointer_ty) is Some(scalar) else {
    raise WgslIrValidationError::InvalidFunctionArgumentType("atomic", 0)
  }
  guard self.find_scalar_type(scalar) is Some(expected) else { return }
  for index in 1..<arguments.length() {
    let argument = arguments[index]
    guard self.function_expression_type(function, argument) is Some(actual) else {
      raise self.missing_function_expression_type(function, argument)
    }
    if !self.type_assignable(expected, actual) {
      raise WgslIrValidationError::InvalidFunctionArgumentType("atomic", index)
    }
  }
}

///|
fn WgslIrValidator::require_workgroup_uniform_load_signature(
  self : WgslIrValidator,
  function : Function,
  pointer : Handle,
  result : Handle,
) -> Unit raise WgslIrValidationError {
  guard self.function_expression_type(function, pointer) is Some(pointer_ty) else {
    raise self.missing_function_expression_type(function, pointer)
  }
  if self.pointer_address_space(pointer_ty) != Some(AddressSpace::WorkGroup) {
    raise WgslIrValidationError::InvalidStatement(
      "workgroupUniformLoad pointer is not in workgroup address space",
    )
  }
  guard self.deref_type(pointer_ty) is Some(expected) else {
    raise WgslIrValidationError::InvalidStatement(
      "workgroupUniformLoad pointer has no value type",
    )
  }
  guard self.function_expression_type(function, result) is Some(actual) else {
    raise self.missing_function_expression_type(function, result)
  }
  if !self.type_assignable(expected, actual) {
    raise WgslIrValidationError::InvalidStatement(
      "workgroupUniformLoad result type mismatch",
    )
  }
}

///|
fn WgslIrValidator::require_subgroup_ballot_signature(
  self : WgslIrValidator,
  function : Function,
  value : Handle,
  result : Handle?,
) -> Unit raise WgslIrValidationError {
  guard self.function_expression_type(function, value) is Some(value_ty) else {
    raise self.missing_function_expression_type(function, value)
  }
  if !self.type_is_bool_scalar(value_ty) {
    raise WgslIrValidationError::InvalidStatement(
      "subgroupBallot value is not bool",
    )
  }
  match result {
    Some(handle) => {
      guard self.function_expression_type(function, handle) is Some(actual) else {
        raise self.missing_function_expression_type(function, handle)
      }
      guard self.vector_type(Quad, Scalar::Scalar(Uint, 4)) is Some(expected) else {
        return
      }
      if !self.type_assignable(expected, actual) {
        raise WgslIrValidationError::InvalidStatement(
          "subgroupBallot result type mismatch",
        )
      }
    }
    None => ()
  }
}

///|
fn WgslIrValidator::require_matching_statement_result(
  self : WgslIrValidator,
  function : Function,
  value : Handle,
  result : Handle,
) -> Unit raise WgslIrValidationError {
  guard self.function_expression_type(function, value) is Some(expected) else {
    raise self.missing_function_expression_type(function, value)
  }
  guard self.function_expression_type(function, result) is Some(actual) else {
    raise self.missing_function_expression_type(function, result)
  }
  if !self.type_assignable(expected, actual) {
    raise WgslIrValidationError::InvalidStatement(
      "statement result type mismatch",
    )
  }
}

///|
fn WgslIrValidator::require_array_length_argument(
  self : WgslIrValidator,
  function : Function,
  handle : Handle,
) -> Unit raise WgslIrValidationError {
  guard self.function_expression_type(function, handle) is Some(ty) else {
    raise self.missing_function_expression_type(function, handle)
  }
  if !self.pointer_targets_runtime_array(ty) &&
    !self.type_or_struct_tail_is_runtime_array(ty) {
    raise WgslIrValidationError::InvalidExpression(
      "arrayLength argument does not point at a runtime array",
      handle.index(),
    )
  }
}

///|
fn WgslIrValidator::require_swizzle_signature(
  self : WgslIrValidator,
  function : Function,
  size : VectorSize,
  expr : Handle,
  components : Array[SwizzleComponent],
) -> Unit raise WgslIrValidationError {
  if components.length() != size.width() {
    raise WgslIrValidationError::InvalidExpression(
      "swizzle component count does not match result size",
      expr.index(),
    )
  }
  guard self.function_expression_type(function, expr) is Some(ty) else {
    return
  }
  guard self.vector_size(ty) is Some(base_size) else {
    raise WgslIrValidationError::InvalidExpression(
      "swizzle base is not a vector",
      expr.index(),
    )
  }
  for component in components {
    if wgsl_ir_validation_swizzle_index(component) >= base_size.width() {
      raise WgslIrValidationError::InvalidExpression(
        "swizzle component is out of range",
        expr.index(),
      )
    }
  }
}

///|
fn WgslIrValidator::function_expression_type(
  self : WgslIrValidator,
  function : Function,
  handle : Handle,
) -> Handle? {
  match function.expressions.items.get(handle.index()) {
    Some(expression) =>
      self.function_expression_inner_type(function, expression)
    None => None
  }
}

///|
fn WgslIrValidator::store_target_value_type(
  self : WgslIrValidator,
  function : Function,
  handle : Handle,
) -> Handle? {
  match function.expressions.items.get(handle.index()) {
    Some(expression) =>
      match expression {
        FunctionArgument(_) =>
          match self.function_expression_inner_type(function, expression) {
            Some(ty) =>
              if self.type_is_pointer_like(ty) &&
                self.pointer_type_is_writable(ty) {
                self.deref_type(ty)
              } else {
                None
              }
            None => None
          }
        LocalVariable(local_handle) =>
          match function.local_variables.items.get(local_handle.index()) {
            Some(local_variable) =>
              if self.type_is_pointer_like(local_variable.ty) &&
                self.pointer_type_is_writable(local_variable.ty) {
                self.deref_type(local_variable.ty)
              } else {
                match local_variable.kind {
                  Var => Some(local_variable.ty)
                  Let => None
                }
              }
            None => None
          }
        GlobalVariable(global) =>
          match self.shader_module.global_variables.items.get(global.index()) {
            Some(variable) =>
              if self.global_address_space_is_writable(variable.space) {
                Some(variable.ty)
              } else {
                None
              }
            None => None
          }
        Load(inner) =>
          match self.function_expression_type(function, inner) {
            Some(ty) =>
              if self.type_is_pointer_like(ty) &&
                self.pointer_type_is_writable(ty) {
                self.deref_type(ty)
              } else {
                None
              }
            None => None
          }
        Access(_, _) | AccessIndex(_, _) | Swizzle(_, _, _) =>
          if self.expression_is_addressable(function, handle) {
            self.function_expression_inner_type(function, expression)
          } else {
            None
          }
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrValidator::function_expression_inner_type(
  self : WgslIrValidator,
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
    Load(inner) =>
      match self.function_expression_type(function, inner) {
        Some(ty) => self.deref_type(ty)
        None => None
      }
    AddressOf(ty, _) => Some(ty)
    Compose(ty, _) | ZeroValue(ty) | Bitcast(ty, _) => Some(ty)
    AccessIndex(base, index) =>
      match self.function_expression_type(function, base) {
        Some(base_ty) => self.indexed_type(base_ty, Some(index))
        None => None
      }
    Access(base, _) =>
      match self.function_expression_type(function, base) {
        Some(base_ty) => self.indexed_type(base_ty, None)
        None => None
      }
    Splat(size, inner) =>
      match self.function_expression_type(function, inner) {
        Some(ty) => self.vector_type_from_scalar_type(size, ty)
        None => None
      }
    Swizzle(size, base, _) =>
      match self.function_expression_type(function, base) {
        Some(ty) => self.vector_or_scalar_swizzle_type(size, ty)
        None => None
      }
    Unary(_, inner) => self.function_expression_type(function, inner)
    Binary(op, left, right) =>
      self.binary_result_type(
        op,
        self.function_expression_type(function, left),
        self.function_expression_type(function, right),
      )
    FunctionCall(handle, _) | CallResult(handle) =>
      self.function_result_type(handle)
    Select(_, accept, reject) =>
      match self.function_expression_type(function, accept) {
        Some(ty) => Some(ty)
        None => self.function_expression_type(function, reject)
      }
    Derivative(_, _, expr) => self.function_expression_type(function, expr)
    Relational(relational_function, expr) =>
      self.relational_result_type(
        relational_function,
        self.function_expression_type(function, expr),
      )
    Math(math_function, a, _, _, _) =>
      self.math_result_type(
        math_function,
        self.function_expression_type(function, a),
      )
    AtomicCall(atomic_function, arguments) =>
      self.atomic_result_type(function, atomic_function, arguments)
    ImageSample(image, _, gather, _, _, _, _, depth_ref, _) =>
      self.image_result_type(function, image, gather, depth_ref)
    ImageLoad(image, _, _, _, _) =>
      self.image_result_type(function, image, None, None)
    ImageQuery(image, query) =>
      self.image_query_result_type(function, image, query)
    ArrayLength(_) => self.find_scalar_type(Scalar::Scalar(Uint, 4))
    WorkGroupUniformLoad(pointer) | WorkGroupUniformLoadResult(pointer) =>
      match self.function_expression_type(function, pointer) {
        Some(ty) => self.deref_type(ty)
        None => None
      }
    AtomicResult(handle, _) => self.function_expression_type(function, handle)
    RayQueryProceedResult => self.find_scalar_type(Scalar::Scalar(Bool, 1))
    SubgroupBallotResult => self.vector_type(Quad, Scalar::Scalar(Uint, 4))
    SubgroupOperationResult(handle) =>
      self.function_expression_type(function, handle)
    SubgroupCall(subgroup_function, arguments) =>
      self.subgroup_result_type(function, subgroup_function, arguments)
    CooperativeLoad(columns, rows, role, data) =>
      match self.cooperative_data_scalar(function, data) {
        Some(scalar) =>
          self.cooperative_matrix_type(columns, rows, scalar, role)
        None => None
      }
    CooperativeMultiplyAdd(_, _, c) =>
      self.function_expression_type(function, c)
    Literal(literal) => self.literal_type(literal)
    As(expr, kind, width) =>
      self.as_result_type(
        self.function_expression_type(function, expr),
        kind,
        width.unwrap_or(4),
      )
    RayQueryGetIntersection(_, _) => self.find_type_by_name("RayIntersection")
    RayQueryVertexPositions(_, _) =>
      self.shader_module.special_types.ray_vertex_return
    RayQueryProceed(_) => self.find_scalar_type(Scalar::Scalar(Bool, 1))
    RayQueryInitialize(_, _, _)
    | RayQueryGenerateIntersection(_, _)
    | RayQueryConfirmIntersection(_)
    | RayQueryTerminate(_) => None
  }
}

///|
fn WgslIrValidator::global_expression_type(
  self : WgslIrValidator,
  handle : Handle,
) -> Handle? {
  match self.shader_module.global_expressions.items.get(handle.index()) {
    Some(expression) => self.global_expression_inner_type(expression)
    None => None
  }
}

///|
fn WgslIrValidator::global_expression_inner_type(
  self : WgslIrValidator,
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
      match self.global_expression_type(inner) {
        Some(ty) => self.deref_type(ty)
        None => None
      }
    AddressOf(ty, _) => Some(ty)
    Compose(ty, _) | ZeroValue(ty) | Bitcast(ty, _) => Some(ty)
    AccessIndex(base, index) =>
      match self.global_expression_type(base) {
        Some(base_ty) => self.indexed_type(base_ty, Some(index))
        None => None
      }
    Access(base, _) =>
      match self.global_expression_type(base) {
        Some(base_ty) => self.indexed_type(base_ty, None)
        None => None
      }
    Unary(_, inner) => self.global_expression_type(inner)
    Binary(op, left, right) =>
      self.binary_result_type(
        op,
        self.global_expression_type(left),
        self.global_expression_type(right),
      )
    FunctionCall(handle, _) => self.function_result_type(handle)
    Select(_, accept, reject) =>
      match self.global_expression_type(accept) {
        Some(ty) => Some(ty)
        None => self.global_expression_type(reject)
      }
    Relational(relational_function, expr) =>
      self.relational_result_type(
        relational_function,
        self.global_expression_type(expr),
      )
    Literal(literal) => self.literal_type(literal)
    As(expr, kind, width) =>
      self.as_result_type(
        self.global_expression_type(expr),
        kind,
        width.unwrap_or(4),
      )
    _ => None
  }
}

///|
fn WgslIrValidator::function_result_type(
  self : WgslIrValidator,
  handle : Handle,
) -> Handle? {
  match self.shader_module.functions.items.get(handle.index()) {
    Some(function) =>
      match function.result {
        Some(result) => Some(result.ty)
        None => None
      }
    None => None
  }
}

///|
fn WgslIrValidator::literal_type(
  self : WgslIrValidator,
  literal : Literal,
) -> Handle? {
  match literal {
    Bool(_) => self.find_scalar_type(Scalar::Scalar(Bool, 1))
    I32(_) => self.find_scalar_type(Scalar::Scalar(Sint, 4))
    U32(_) => self.find_scalar_type(Scalar::Scalar(Uint, 4))
    I64(_) => self.find_scalar_type(Scalar::Scalar(Sint, 8))
    U64(_) => self.find_scalar_type(Scalar::Scalar(Uint, 8))
    I16(_) => self.find_scalar_type(Scalar::Scalar(Sint, 2))
    U16(_) => self.find_scalar_type(Scalar::Scalar(Uint, 2))
    F16(_) => self.find_scalar_type(Scalar::Scalar(Float, 2))
    F32(_) => self.find_scalar_type(Scalar::Scalar(Float, 4))
    F64(_) => self.find_scalar_type(Scalar::Scalar(Float, 8))
    AbstractInt(_) => self.find_scalar_type(Scalar::Scalar(AbstractInt, 8))
    AbstractFloat(_) => self.find_scalar_type(Scalar::Scalar(AbstractFloat, 8))
  }
}

///|
fn WgslIrValidator::indexed_type(
  self : WgslIrValidator,
  ty : Handle,
  index : Int?,
) -> Handle? {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Struct(members, _) | PredeclaredStruct(members, _) =>
          match index {
            Some(i) =>
              match members.get(i) {
                Some(struct_member) => Some(struct_member.ty)
                None => None
              }
            None => None
          }
        Vector(size, scalar) =>
          if self.constant_index_is_in_bounds(index, size.width()) {
            self.find_scalar_type(scalar)
          } else {
            None
          }
        Matrix(columns, rows, scalar) =>
          if self.constant_index_is_in_bounds(index, columns.width()) {
            self.vector_type(rows, scalar)
          } else {
            None
          }
        Array(element, size, _) | BindingArray(element, size) =>
          if self.array_index_is_in_bounds(index, size) {
            Some(element)
          } else {
            None
          }
        Pointer(base, _) => self.indexed_type(base, index)
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrValidator::dynamic_indexed_type(
  self : WgslIrValidator,
  ty : Handle,
) -> Handle? {
  self.indexed_type(ty, None)
}

///|
fn WgslIrValidator::constant_index_is_in_bounds(
  self : WgslIrValidator,
  index : Int?,
  count : Int,
) -> Bool {
  ignore(self)
  match index {
    Some(value) => value >= 0 && value < count
    None => true
  }
}

///|
fn WgslIrValidator::array_index_is_in_bounds(
  self : WgslIrValidator,
  index : Int?,
  size : ArraySize,
) -> Bool {
  ignore(self)
  match (index, size) {
    (Some(value), Constant(count)) => value >= 0 && value < count
    (Some(value), _) => value >= 0
    (None, _) => true
  }
}

///|
fn WgslIrValidator::pointer_pointee_type(
  self : WgslIrValidator,
  ty : Handle,
) -> Handle? {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Pointer(base, _) => Some(base)
        ValuePointer(size, scalar, _) =>
          match size {
            Some(vector_size) => self.vector_type(vector_size, scalar)
            None => self.find_scalar_type(scalar)
          }
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrValidator::pointer_address_space(
  self : WgslIrValidator,
  ty : Handle,
) -> AddressSpace? {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Pointer(_, space) | ValuePointer(_, _, space) => Some(space)
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrValidator::pointer_type_is_writable(
  self : WgslIrValidator,
  ty : Handle,
) -> Bool {
  match self.pointer_address_space(ty) {
    Some(space) => self.global_address_space_is_writable(space)
    None => false
  }
}

///|
fn WgslIrValidator::global_address_space_is_writable(
  self : WgslIrValidator,
  space : AddressSpace,
) -> Bool {
  ignore(self)
  match space {
    Function | Private | WorkGroup | TaskPayload | RayPayload => true
    Storage(access) =>
      access.contains(StorageAccess::store()) ||
      access.contains(StorageAccess::atomic_access())
    _ => false
  }
}

///|
fn WgslIrValidator::expression_is_addressable(
  self : WgslIrValidator,
  function : Function,
  handle : Handle,
) -> Bool {
  match function.expressions.items.get(handle.index()) {
    Some(expression) =>
      match expression {
        FunctionArgument(_) =>
          match self.function_expression_inner_type(function, expression) {
            Some(ty) => self.type_is_pointer_like(ty)
            None => false
          }
        LocalVariable(local_handle) =>
          match function.local_variables.items.get(local_handle.index()) {
            Some(local_variable) =>
              local_variable.kind == Var ||
              self.type_is_pointer_like(local_variable.ty)
            None => false
          }
        GlobalVariable(global) =>
          self.shader_module.global_variables.items.get(global.index()) != None
        Load(inner) =>
          match self.function_expression_type(function, inner) {
            Some(ty) => self.type_is_pointer_like(ty)
            None => false
          }
        Access(base, _) | AccessIndex(base, _) | Swizzle(_, base, _) =>
          self.expression_is_addressable(function, base)
        _ => false
      }
    None => false
  }
}

///|
fn WgslIrValidator::global_expression_is_addressable(
  self : WgslIrValidator,
  handle : Handle,
) -> Bool {
  match self.shader_module.global_expressions.items.get(handle.index()) {
    Some(expression) =>
      match expression {
        GlobalVariable(global) =>
          self.shader_module.global_variables.items.get(global.index()) != None
        Load(inner) =>
          match self.global_expression_type(inner) {
            Some(ty) => self.type_is_pointer_like(ty)
            None => false
          }
        Access(base, _) | AccessIndex(base, _) =>
          self.global_expression_is_addressable(base)
        _ => false
      }
    None => false
  }
}

///|
fn WgslIrValidator::global_expression_value_type(
  self : WgslIrValidator,
  handle : Handle,
) -> Handle? {
  match self.shader_module.global_expressions.items.get(handle.index()) {
    Some(expression) =>
      match expression {
        GlobalVariable(global) =>
          match self.shader_module.global_variables.items.get(global.index()) {
            Some(variable) => Some(variable.ty)
            None => None
          }
        Load(inner) =>
          match self.global_expression_type(inner) {
            Some(ty) => self.deref_type(ty)
            None => None
          }
        Access(_, _) | AccessIndex(_, _) =>
          self.global_expression_inner_type(expression)
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrValidator::deref_type(self : WgslIrValidator, ty : Handle) -> Handle? {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Pointer(base, _) => self.deref_type(base)
        ValuePointer(size, scalar, _) =>
          match size {
            Some(vector_size) => self.vector_type(vector_size, scalar)
            None => self.find_scalar_type(scalar)
          }
        _ => Some(ty)
      }
    None => None
  }
}

///|
fn WgslIrValidator::vector_type_from_scalar_type(
  self : WgslIrValidator,
  size : VectorSize,
  ty : Handle,
) -> Handle? {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Scalar(scalar) => self.vector_type(size, scalar)
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrValidator::vector_or_scalar_swizzle_type(
  self : WgslIrValidator,
  size : VectorSize,
  ty : Handle,
) -> Handle? {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Vector(_, scalar) => self.vector_type(size, scalar)
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrValidator::binary_result_type(
  self : WgslIrValidator,
  op : BinaryOperator,
  left : Handle?,
  right : Handle?,
) -> Handle? {
  if wgsl_ir_validation_binary_operator_is_comparison(op) {
    return self.boolean_result_type(left, right)
  }
  match (left, right) {
    (Some(left_ty), Some(right_ty)) =>
      if op == BinaryOperator::Multiply {
        match self.matrix_vector_multiply_result_type(left_ty, right_ty) {
          Some(ty) => Some(ty)
          None => self.numeric_binary_fallback_type(left_ty, right_ty)
        }
      } else {
        self.numeric_binary_fallback_type(left_ty, right_ty)
      }
    (Some(ty), None) | (None, Some(ty)) => Some(ty)
    (None, None) => None
  }
}

///|
fn WgslIrValidator::numeric_binary_fallback_type(
  self : WgslIrValidator,
  left : Handle,
  right : Handle,
) -> Handle? {
  if self.type_is_scalar(left) && !self.type_is_scalar(right) {
    return Some(right)
  }
  if !self.type_is_scalar(left) && self.type_is_scalar(right) {
    return Some(left)
  }
  Some(left)
}

///|
fn WgslIrValidator::matrix_vector_multiply_result_type(
  self : WgslIrValidator,
  left : Handle,
  right : Handle,
) -> Handle? {
  match self.shader_module.types.get(left) {
    Some(left_type) =>
      match left_type.inner {
        Matrix(left_columns, rows, scalar) =>
          match self.shader_module.types.get(right) {
            Some(right_type) =>
              match right_type.inner {
                Vector(_, _) => self.vector_type(rows, scalar)
                Matrix(columns, right_rows, _) =>
                  if right_rows == left_columns {
                    self.matrix_type(columns, rows, scalar)
                  } else {
                    None
                  }
                _ => None
              }
            None => None
          }
        Vector(_, scalar) =>
          match self.shader_module.types.get(right) {
            Some(right_type) =>
              match right_type.inner {
                Matrix(columns, _, _) => self.vector_type(columns, scalar)
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
fn WgslIrValidator::boolean_result_type(
  self : WgslIrValidator,
  left : Handle?,
  right : Handle?,
) -> Handle? {
  match left {
    Some(ty) =>
      match self.vector_size(ty) {
        Some(size) => return self.vector_type(size, Scalar::Scalar(Bool, 1))
        None => ()
      }
    None => ()
  }
  match right {
    Some(ty) =>
      match self.vector_size(ty) {
        Some(size) => self.vector_type(size, Scalar::Scalar(Bool, 1))
        None => self.find_scalar_type(Scalar::Scalar(Bool, 1))
      }
    None => self.find_scalar_type(Scalar::Scalar(Bool, 1))
  }
}

///|
fn WgslIrValidator::relational_result_type(
  self : WgslIrValidator,
  relational_function : RelationalFunction,
  input : Handle?,
) -> Handle? {
  match relational_function {
    All | Any => self.find_scalar_type(Scalar::Scalar(Bool, 1))
    IsNan | IsInf => self.boolean_result_type(input, input)
  }
}

///|
fn WgslIrValidator::math_result_type(
  self : WgslIrValidator,
  math_function : MathFunction,
  input : Handle?,
) -> Handle? {
  guard input is Some(input_ty) else { return None }
  match math_function {
    Pack4x8snorm
    | Pack4x8unorm
    | Pack2x16snorm
    | Pack2x16unorm
    | Pack2x16float
    | Pack4xI8
    | Pack4xU8
    | Pack4xI8Clamp
    | Pack4xU8Clamp
    | Dot4U8Packed => self.find_scalar_type(Scalar::Scalar(Uint, 4))
    Dot4I8Packed => self.find_scalar_type(Scalar::Scalar(Sint, 4))
    Unpack4x8snorm | Unpack4x8unorm =>
      self.vector_type(Quad, Scalar::Scalar(Float, 4))
    Unpack2x16snorm | Unpack2x16unorm | Unpack2x16float =>
      self.vector_type(Bi, Scalar::Scalar(Float, 4))
    Unpack4xI8 => self.vector_type(Quad, Scalar::Scalar(Sint, 4))
    Unpack4xU8 => self.vector_type(Quad, Scalar::Scalar(Uint, 4))
    Dot | Distance | Length | Determinant =>
      self.scalar_type_from_type(input_ty)
    Transpose => self.transpose_type(input_ty)
    _ => Some(input_ty)
  }
}

///|
fn WgslIrValidator::as_result_type(
  self : WgslIrValidator,
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
        Vector(size, _) => self.vector_type(size, scalar)
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrValidator::atomic_result_type(
  self : WgslIrValidator,
  function : Function,
  atomic_function : AtomicFunction,
  arguments : Array[Handle],
) -> Handle? {
  guard arguments is [pointer, ..] else { return None }
  let scalar = match self.function_expression_type(function, pointer) {
    Some(ty) => self.atomic_scalar_type(ty)
    None => None
  }
  match atomic_function {
    Store => None
    CompareExchangeWeak =>
      match scalar {
        Some(value) => self.predeclared_atomic_compare_exchange_type(value)
        None => None
      }
    _ =>
      match scalar {
        Some(value) => self.find_scalar_type(value)
        None => None
      }
  }
}

///|
fn WgslIrValidator::image_result_type(
  self : WgslIrValidator,
  function : Function,
  image : Handle,
  gather : SwizzleComponent?,
  depth_ref : Handle?,
) -> Handle? {
  guard self.function_expression_type(function, image) is Some(image_ty) else {
    return None
  }
  match self.shader_module.types.get(image_ty) {
    Some(type_) =>
      match type_.inner {
        Image(_, _, Sampled(kind, _)) =>
          self.vector_type(Quad, Scalar::Scalar(kind, 4))
        Image(_, _, Depth(_)) =>
          if gather != None {
            self.vector_type(Quad, Scalar::Scalar(Float, 4))
          } else {
            ignore(depth_ref)
            self.find_scalar_type(Scalar::Scalar(Float, 4))
          }
        Image(_, _, Storage(format, _)) =>
          self.vector_type(
            Quad,
            wgsl_ir_validation_storage_format_scalar(format),
          )
        Image(_, _, External) =>
          self.vector_type(Quad, Scalar::Scalar(Float, 4))
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrValidator::image_query_result_type(
  self : WgslIrValidator,
  function : Function,
  image : Handle,
  query : ImageQuery,
) -> Handle? {
  match query {
    Size(_) =>
      match self.image_dimension(function, image) {
        Some(D1) => self.find_scalar_type(Scalar::Scalar(Uint, 4))
        Some(D2) | Some(Cube) => self.vector_type(Bi, Scalar::Scalar(Uint, 4))
        Some(D3) => self.vector_type(Tri, Scalar::Scalar(Uint, 4))
        None => None
      }
    NumLevels | NumLayers | NumSamples =>
      self.find_scalar_type(Scalar::Scalar(Uint, 4))
  }
}

///|
fn WgslIrValidator::subgroup_result_type(
  self : WgslIrValidator,
  function : Function,
  subgroup_function : SubgroupFunction,
  arguments : Array[Handle],
) -> Handle? {
  match subgroup_function {
    Ballot => self.vector_type(Quad, Scalar::Scalar(Uint, 4))
    All | Any => self.find_scalar_type(Scalar::Scalar(Bool, 1))
    _ =>
      match arguments.get(0) {
        Some(argument) => self.function_expression_type(function, argument)
        None => None
      }
  }
}

///|
fn WgslIrValidator::image_dimension(
  self : WgslIrValidator,
  function : Function,
  image : Handle,
) -> ImageDimension? {
  guard self.function_expression_type(function, image) is Some(image_ty) else {
    return None
  }
  match self.shader_module.types.get(image_ty) {
    Some(type_) =>
      match type_.inner {
        Image(dimension, _, _) => Some(dimension)
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrValidator::cooperative_data_scalar(
  self : WgslIrValidator,
  function : Function,
  data : CooperativeData,
) -> Scalar? {
  guard self.function_expression_type(function, data.pointer)
    is Some(pointer_ty) else {
    return None
  }
  match self.pointer_pointee_type(pointer_ty) {
    Some(value_ty) => self.scalar_from_type(value_ty)
    None => self.scalar_from_type(pointer_ty)
  }
}

///|
fn WgslIrValidator::atomic_scalar_type(
  self : WgslIrValidator,
  ty : Handle,
) -> Scalar? {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Atomic(scalar) => Some(scalar)
        Pointer(base, _) => self.atomic_scalar_type(base)
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrValidator::predeclared_atomic_compare_exchange_type(
  self : WgslIrValidator,
  scalar : Scalar,
) -> Handle? {
  for index in 0..<self.shader_module.types.items.length() {
    let ty = self.shader_module.types.items[index]
    match ty.inner {
      PredeclaredStruct(_, _) =>
        if ty.name ==
          Some(
            "atomic_compare_exchange_result_\{wgsl_ir_validation_scalar_name(scalar)}",
          ) {
          return Some(Handle::Handle(index))
        }
      _ => ()
    }
  }
  None
}

///|
fn WgslIrValidator::scalar_type_from_type(
  self : WgslIrValidator,
  ty : Handle,
) -> Handle? {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Scalar(_) => Some(ty)
        Vector(_, scalar) | Matrix(_, _, scalar) =>
          self.find_scalar_type(scalar)
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrValidator::scalar_from_type(
  self : WgslIrValidator,
  ty : Handle,
) -> Scalar? {
  match self.shader_module.types.get(ty) {
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
fn WgslIrValidator::transpose_type(
  self : WgslIrValidator,
  ty : Handle,
) -> Handle? {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Matrix(columns, rows, scalar) => self.matrix_type(rows, columns, scalar)
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrValidator::type_assignable(
  self : WgslIrValidator,
  expected : Handle,
  actual : Handle,
) -> Bool {
  if expected == actual {
    return true
  }
  match
    (
      self.shader_module.types.get(expected),
      self.shader_module.types.get(actual),
    ) {
    (Some(expected_ty), Some(actual_ty)) =>
      self.type_inner_assignable(expected_ty.inner, actual_ty.inner)
    _ => false
  }
}

///|
fn WgslIrValidator::type_inner_assignable(
  self : WgslIrValidator,
  expected : TypeInner,
  actual : TypeInner,
) -> Bool {
  ignore(self)
  if expected == actual {
    return true
  }
  match (expected, actual) {
    (Scalar(expected_scalar), Scalar(actual_scalar)) =>
      wgsl_ir_validation_scalar_assignable(expected_scalar, actual_scalar)
    (Vector(expected_size, expected_scalar), Vector(actual_size, actual_scalar)) =>
      expected_size == actual_size &&
      wgsl_ir_validation_scalar_assignable(expected_scalar, actual_scalar)
    (
      Matrix(expected_columns, expected_rows, expected_scalar),
      Matrix(actual_columns, actual_rows, actual_scalar),
    ) =>
      expected_columns == actual_columns &&
      expected_rows == actual_rows &&
      wgsl_ir_validation_scalar_assignable(expected_scalar, actual_scalar)
    _ => false
  }
}

///|
fn WgslIrValidator::types_are_select_compatible(
  self : WgslIrValidator,
  accept : Handle,
  reject : Handle,
) -> Bool {
  self.type_assignable(accept, reject) || self.type_assignable(reject, accept)
}

///|
fn WgslIrValidator::select_condition_type_matches_result(
  self : WgslIrValidator,
  condition : Handle,
  result : Handle,
) -> Bool {
  if self.type_is_bool_scalar(condition) {
    return true
  }
  match self.type_bool_vector_size(condition) {
    Some(condition_size) =>
      match self.vector_size(result) {
        Some(result_size) => condition_size == result_size
        None => false
      }
    None => false
  }
}

///|
fn WgslIrValidator::type_is_bool_scalar(
  self : WgslIrValidator,
  ty : Handle,
) -> Bool {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Scalar(scalar) => scalar.kind == Bool
        _ => false
      }
    None => false
  }
}

///|
fn WgslIrValidator::type_bool_vector_size(
  self : WgslIrValidator,
  ty : Handle,
) -> VectorSize? {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Vector(size, scalar) if scalar.kind == Bool => Some(size)
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrValidator::type_is_integer_scalar(
  self : WgslIrValidator,
  ty : Handle,
) -> Bool {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Scalar(scalar) =>
          scalar.kind == Sint ||
          scalar.kind == Uint ||
          scalar.kind == AbstractInt
        _ => false
      }
    None => false
  }
}

///|
fn WgslIrValidator::type_is_scalar(self : WgslIrValidator, ty : Handle) -> Bool {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Scalar(_) => true
        _ => false
      }
    None => false
  }
}

///|
fn WgslIrValidator::type_is_pointer_like(
  self : WgslIrValidator,
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
fn WgslIrValidator::vector_size(
  self : WgslIrValidator,
  ty : Handle,
) -> VectorSize? {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Vector(size, _) => Some(size)
        _ => None
      }
    None => None
  }
}

///|
fn WgslIrValidator::type_lane_count(self : WgslIrValidator, ty : Handle) -> Int {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Vector(size, _) => size.width()
        Matrix(columns, rows, _) => columns.width() * rows.width()
        _ => 1
      }
    None => 1
  }
}

///|
fn WgslIrValidator::type_is_handle_resource(
  self : WgslIrValidator,
  ty : Handle,
) -> Bool {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Image(_, _, _) | Sampler(_) | AccelerationStructure(_) | RayQuery(_) =>
          true
        BindingArray(element, _) => self.type_is_handle_resource(element)
        _ => false
      }
    None => false
  }
}

///|
fn WgslIrValidator::type_is_runtime_array(
  self : WgslIrValidator,
  ty : Handle,
) -> Bool {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Array(_, Dynamic, _) | BindingArray(_, Dynamic) => true
        _ => false
      }
    None => false
  }
}

///|
fn WgslIrValidator::pointer_targets_runtime_array(
  self : WgslIrValidator,
  ty : Handle,
) -> Bool {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Pointer(base, _) => self.type_or_struct_tail_is_runtime_array(base)
        _ => false
      }
    None => false
  }
}

///|
fn WgslIrValidator::type_or_struct_tail_is_runtime_array(
  self : WgslIrValidator,
  ty : Handle,
) -> Bool {
  match self.shader_module.types.get(ty) {
    Some(type_) =>
      match type_.inner {
        Array(_, Dynamic, _) => true
        Struct(members, _) | PredeclaredStruct(members, _) =>
          match members.last() {
            Some(struct_member) => self.type_is_runtime_array(struct_member.ty)
            None => false
          }
        _ => false
      }
    None => false
  }
}

///|
fn WgslIrValidator::type_layout(
  self : WgslIrValidator,
  ty : Handle,
) -> WgslIrValidationLayout raise WgslIrValidationError {
  match self.shader_module.types.get(ty) {
    Some(type_) => self.type_inner_layout(type_.inner)
    None => raise WgslIrValidationError::InvalidTypeHandle(ty.index())
  }
}

///|
fn WgslIrValidator::type_inner_layout(
  self : WgslIrValidator,
  inner : TypeInner,
) -> WgslIrValidationLayout raise WgslIrValidationError {
  match inner {
    Scalar(scalar) | Atomic(scalar) =>
      WgslIrValidationLayout::{ align: scalar.width, size: scalar.width }
    Vector(size, scalar) => {
      let lanes = size.width()
      let raw_size = lanes * scalar.width
      WgslIrValidationLayout::{
        align: if lanes == 3 {
          4 * scalar.width
        } else {
          raw_size
        },
        size: raw_size,
      }
    }
    Matrix(columns, rows, scalar) => {
      let row_lanes = rows.width()
      let column_align = if row_lanes == 3 {
        4 * scalar.width
      } else {
        row_lanes * scalar.width
      }
      let column_size = wgsl_ir_validation_align_to(
        row_lanes * scalar.width,
        column_align,
      )
      WgslIrValidationLayout::{
        align: column_align,
        size: column_size * columns.width(),
      }
    }
    Array(base, size, stride) => {
      let count = match size {
        Constant(value) => value
        Dynamic | Pending(_) => 1
      }
      WgslIrValidationLayout::{
        align: self.type_layout(base).align,
        size: count * stride,
      }
    }
    Struct(members, span) | PredeclaredStruct(members, span) => {
      let mut align = 1
      for struct_member in members {
        let member_layout = self.type_layout(struct_member.ty)
        let member_align = match struct_member.align {
          Some(value) => value
          None => member_layout.align
        }
        if member_align > align {
          align = member_align
        }
      }
      WgslIrValidationLayout::{ align, size: span }
    }
    Pointer(_, _) | ValuePointer(_, _, _) =>
      WgslIrValidationLayout::{ align: 1, size: 4 }
    Image(_, _, _)
    | Sampler(_)
    | AccelerationStructure(_)
    | RayQuery(_)
    | BindingArray(_, _) => WgslIrValidationLayout::{ align: 1, size: 0 }
    CooperativeMatrix(columns, rows, scalar, _) =>
      WgslIrValidationLayout::{
        align: scalar.width,
        size: wgsl_ir_validation_cooperative_size_width(columns) *
        wgsl_ir_validation_cooperative_size_width(rows) *
        scalar.width,
      }
  }
}

///|
fn WgslIrValidator::find_type_by_name(
  self : WgslIrValidator,
  name : String,
) -> Handle? {
  for index in 0..<self.shader_module.types.items.length() {
    let ty = self.shader_module.types.items[index]
    if ty.name == Some(name) {
      return Some(Handle::Handle(index))
    }
  }
  None
}

///|
fn WgslIrValidator::find_scalar_type(
  self : WgslIrValidator,
  scalar : Scalar,
) -> Handle? {
  self.find_type_inner(TypeInner::Scalar(scalar))
}

///|
fn WgslIrValidator::vector_type(
  self : WgslIrValidator,
  size : VectorSize,
  scalar : Scalar,
) -> Handle? {
  self.find_type_inner(TypeInner::Vector(size, scalar))
}

///|
fn WgslIrValidator::matrix_type(
  self : WgslIrValidator,
  columns : VectorSize,
  rows : VectorSize,
  scalar : Scalar,
) -> Handle? {
  self.find_type_inner(TypeInner::Matrix(columns, rows, scalar))
}

///|
fn WgslIrValidator::cooperative_matrix_type(
  self : WgslIrValidator,
  columns : CooperativeSize,
  rows : CooperativeSize,
  scalar : Scalar,
  role : CooperativeRole,
) -> Handle? {
  self.find_type_inner(
    TypeInner::CooperativeMatrix(columns, rows, scalar, role),
  )
}

///|
fn WgslIrValidator::find_type_inner(
  self : WgslIrValidator,
  inner : TypeInner,
) -> Handle? {
  for index in 0..<self.shader_module.types.items.length() {
    if self.shader_module.types.items[index].inner == inner {
      return Some(Handle::Handle(index))
    }
  }
  None
}

///|
fn WgslIrValidator::function_display_name(
  self : WgslIrValidator,
  function : Function,
) -> String {
  ignore(self)
  match function.name {
    Some(name) => name
    None => "<anonymous>"
  }
}

///|
fn wgsl_ir_validation_binary_operator_is_comparison(
  op : BinaryOperator,
) -> Bool {
  match op {
    Equal | NotEqual | Less | LessEqual | Greater | GreaterEqual => true
    _ => false
  }
}

///|
fn wgsl_ir_validation_scalar_assignable(
  expected : Scalar,
  actual : Scalar,
) -> Bool {
  if expected == actual {
    return true
  }
  match (expected.kind, actual.kind) {
    (Sint, AbstractInt) | (Uint, AbstractInt) | (Float, AbstractFloat) => true
    (Float, AbstractInt) => true
    (AbstractFloat, AbstractInt) | (AbstractInt, AbstractFloat) => true
    _ => false
  }
}

///|
fn wgsl_ir_validation_scalar_name(scalar : Scalar) -> String {
  match scalar.kind {
    Bool => "bool"
    Sint => if scalar.width == 8 { "i64" } else { "i32" }
    Uint => if scalar.width == 8 { "u64" } else { "u32" }
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
}

///|
fn wgsl_ir_validation_storage_format_scalar(format : StorageFormat) -> Scalar {
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
    R8Sint | R16Sint | Rg8Sint | R32Sint | Rg16Sint | Rgba8Sint | Rgba32Sint =>
      Scalar::Scalar(Sint, 4)
    _ => Scalar::Scalar(Float, 4)
  }
}

///|
fn wgsl_ir_validation_scalar_width_is_valid(
  kind : ScalarKind,
  width : Int,
) -> Bool {
  match kind {
    Bool => width == 1
    Sint | Uint | Float => width == 2 || width == 4 || width == 8
    AbstractInt | AbstractFloat => width == 8
  }
}

///|
fn wgsl_ir_validation_swizzle_index(component : SwizzleComponent) -> Int {
  match component {
    X => 0
    Y => 1
    Z => 2
    W => 3
  }
}

///|
fn wgsl_ir_validation_is_power_of_two(value : Int) -> Bool {
  value > 0 && (value & (value - 1)) == 0
}

///|
fn wgsl_ir_validation_align_to(value : Int, align : Int) -> Int {
  if align <= 1 {
    value
  } else {
    (value + align - 1) / align * align
  }
}

///|
fn wgsl_ir_validation_cooperative_size_width(size : CooperativeSize) -> Int {
  match size {
    Eight => 8
    Sixteen => 16
  }
}

///|
fn WgslIrValidator::validate_global_expression_handle(
  self : WgslIrValidator,
  handle : Handle,
) -> Unit raise WgslIrValidationError {
  if handle.index() < 0 ||
    handle.index() >= self.shader_module.global_expressions.items.length() {
    raise WgslIrValidationError::InvalidGlobalExpressionHandle(handle.index())
  }
}

///|
fn WgslIrValidator::validate_function_expression_handle(
  self : WgslIrValidator,
  function : Function,
  handle : Handle,
) -> Unit raise WgslIrValidationError {
  ignore(self)
  if handle.index() < 0 || handle.index() >= function.expressions.items.length() {
    raise WgslIrValidationError::InvalidFunctionExpressionHandle(handle.index())
  }
}

///|
fn WgslIrValidator::validate_function_expression_range(
  self : WgslIrValidator,
  function : Function,
  range : HandleRange,
) -> Unit raise WgslIrValidationError {
  ignore(self)
  if range.start.index() < 0 ||
    range.end.index() < range.start.index() ||
    range.end.index() > function.expressions.items.length() {
    raise WgslIrValidationError::InvalidHandleRange(
      range.start.index(),
      range.end.index(),
    )
  }
}

///|
fn WgslIrValidator::require_type(
  self : WgslIrValidator,
  handle : Handle,
) -> Unit raise WgslIrValidationError {
  if handle.index() < 0 ||
    handle.index() >= self.shader_module.types.items.length() {
    raise WgslIrValidationError::InvalidTypeHandle(handle.index())
  }
}

///|
fn WgslIrValidator::require_constant(
  self : WgslIrValidator,
  handle : Handle,
) -> Unit raise WgslIrValidationError {
  if handle.index() < 0 ||
    handle.index() >= self.shader_module.constants.items.length() {
    raise WgslIrValidationError::InvalidConstantHandle(handle.index())
  }
}

///|
fn WgslIrValidator::require_override(
  self : WgslIrValidator,
  handle : Handle,
) -> Unit raise WgslIrValidationError {
  if handle.index() < 0 ||
    handle.index() >= self.shader_module.overrides.items.length() {
    raise WgslIrValidationError::InvalidOverrideHandle(handle.index())
  }
}

///|
fn WgslIrValidator::require_global_variable(
  self : WgslIrValidator,
  handle : Handle,
) -> Unit raise WgslIrValidationError {
  if handle.index() < 0 ||
    handle.index() >= self.shader_module.global_variables.items.length() {
    raise WgslIrValidationError::InvalidGlobalVariableHandle(handle.index())
  }
}

///|
fn WgslIrValidator::require_function(
  self : WgslIrValidator,
  handle : Handle,
) -> Unit raise WgslIrValidationError {
  if handle.index() < 0 ||
    handle.index() >= self.shader_module.functions.items.length() {
    raise WgslIrValidationError::InvalidFunctionHandle(handle.index())
  }
}

///|
fn WgslIrValidator::require_local_variable(
  self : WgslIrValidator,
  function : Function,
  handle : Handle,
) -> Unit raise WgslIrValidationError {
  ignore(self)
  if handle.index() < 0 ||
    handle.index() >= function.local_variables.items.length() {
    raise WgslIrValidationError::InvalidLocalVariableHandle(handle.index())
  }
}
