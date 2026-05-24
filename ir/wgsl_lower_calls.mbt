///|
fn WgslIrLowerer::address_of_expression_type(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle,
) -> Handle? {
  ignore(self)
  match function.expressions.items.get(handle.index()) {
    Some(Expression::AddressOf(ty, _)) => Some(ty)
    _ => None
  }
}

///|
fn wgsl_ir_address_of_operand_ref(
  expr_ref : @ast.WgslExprRef,
) -> @ast.WgslExprNode? {
  match expr_ref.root() {
    Some(root) => wgsl_ir_address_of_operand_node(root)
    None => None
  }
}

///|
fn wgsl_ir_address_of_operand_node(
  node : @ast.WgslExprNode,
) -> @ast.WgslExprNode? {
  match node.kind() {
    Group(inner) => wgsl_ir_address_of_operand_node(inner)
    Unary(op, expr) =>
      if op == @ast.WgslExprOperator::BitAnd {
        Some(expr)
      } else {
        None
      }
    _ => None
  }
}

///|
fn wgsl_ir_local_variable_kind(
  kind : @ast.WgslLocalDeclarationKind,
) -> LocalVariableKind {
  match kind {
    Var => LocalVariableKind::Var
    Let => LocalVariableKind::Let
    Const => abort("local const declarations are not local variables")
  }
}

///|
fn WgslIrLowerer::lower_call_statement(
  self : WgslIrLowerer,
  expr_ref : @ast.WgslExprRef,
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
) -> Unit raise WgslIrLowerError {
  guard expr_ref.root() is Some(root) else {
    raise WgslIrLowerError::UnsupportedExpression("empty function call")
  }
  match wgsl_ir_expr_call_node(root).kind() {
    Call(callee, arguments) => {
      let arguments = wgsl_ir_call_arguments(arguments)
      match callee.kind() {
        Identifier(name) =>
          match wgsl_ir_barrier_statement_from_call(name.name(), arguments) {
            Some(statement) => block.push(statement)
            None =>
              match wgsl_ir_atomic_function_from_name(name.name()) {
                Some(atomic_function) => {
                  let handle = self.lower_function_atomic_call(
                    atomic_function, arguments, function, scope,
                  )
                  if self.function_expression_type(function, handle) != None {
                    ignore(
                      self.materialize_function_expression(
                        function, scope, block, handle,
                      ),
                    )
                  } else {
                    block.push(Statement::Emit(HandleRange(handle, handle)))
                  }
                }
                None =>
                  match self.function_names.get(name.name()) {
                    Some(handle) => {
                      let values = self.lower_user_function_call_arguments(
                        handle, arguments, function, scope,
                      )
                      block.push(Statement::Call(handle, values, None))
                    }
                    None =>
                      if !self.lower_ray_query_statement_call(
                          name.name(),
                          arguments,
                          function,
                          scope,
                          block,
                        ) &&
                        !self.lower_texture_statement_call(
                          name.name(),
                          arguments,
                          function,
                          scope,
                          block,
                        ) &&
                        !self.lower_cooperative_statement_call(
                          name.name(),
                          arguments,
                          function,
                          scope,
                          block,
                        ) {
                        ignore(
                          self.lower_function_expression_node(
                            root, function, scope,
                          ),
                        )
                      }
                  }
              }
          }
        _ => ignore(self.lower_function_expression_node(root, function, scope))
      }
    }
    _ => ignore(self.lower_function_expression_node(root, function, scope))
  }
}

///|
priv enum WgslIrBarrierBuiltin {
  BarrierControl(Barrier)
  BarrierMemory(Barrier)
}

///|
fn wgsl_ir_barrier_builtin_from_name(name : String) -> WgslIrBarrierBuiltin? {
  match name {
    "workgroupBarrier" => Some(BarrierControl(Barrier::work_group()))
    "storageBarrier" => Some(BarrierMemory(Barrier::storage()))
    "textureBarrier" => Some(BarrierMemory(Barrier::texture()))
    "subgroupBarrier" => Some(BarrierControl(Barrier::sub_group()))
    _ => None
  }
}

///|
fn wgsl_ir_barrier_statement_from_call(
  name : String,
  arguments : Array[@ast.WgslExprNode],
) -> Statement? raise WgslIrLowerError {
  match wgsl_ir_barrier_builtin_from_name(name) {
    Some(barrier) => {
      guard arguments.length() == 0 else {
        raise WgslIrLowerError::UnsupportedExpression(
          "\{name} expects no arguments",
        )
      }
      match barrier {
        BarrierControl(barrier) => Some(Statement::ControlBarrier(barrier))
        BarrierMemory(barrier) => Some(Statement::MemoryBarrier(barrier))
      }
    }
    None => None
  }
}

///|
fn wgsl_ir_barrier_value_error(name : String) -> WgslIrLowerError {
  WgslIrLowerError::UnsupportedExpression(
    "barrier builtin has no value: \{name}",
  )
}

///|
fn WgslIrLowerer::lower_user_function_call_arguments(
  self : WgslIrLowerer,
  callee : Handle,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Array[Handle] raise WgslIrLowerError {
  let flattened = wgsl_ir_flatten_expression_arguments(arguments)
  let handles : Array[Handle] = []
  let callee_function = match
    self.shader_module.functions.items.get(callee.index()) {
    Some(value) => value
    None =>
      raise WgslIrLowerError::UnsupportedExpression(
        "invalid function call target",
      )
  }
  for index in 0..<flattened.length() {
    let expected_ty = match callee_function.arguments.get(index) {
      Some(argument) => Some(argument.ty)
      None => None
    }
    let lowered = self.lower_function_expression_node_with_expected(
      flattened[index],
      function,
      scope,
      expected_ty,
    )
    let argument = match expected_ty {
      Some(ty) if self.lowerer_type_is_pointer(ty) => lowered
      Some(_) => self.apply_function_load_rule(function, lowered)
      None => lowered
    }
    handles.push(argument)
  }
  handles
}

///|
fn wgsl_ir_expr_call_node(node : @ast.WgslExprNode) -> @ast.WgslExprNode {
  match node.kind() {
    Group(inner) => wgsl_ir_expr_call_node(inner)
    Sequence([single]) => wgsl_ir_expr_call_node(single)
    _ => node
  }
}

///|
fn wgsl_ir_call_arguments(
  arguments : Array[@ast.WgslExprNode],
) -> Array[@ast.WgslExprNode] {
  wgsl_ir_flatten_expression_arguments(arguments)
}

///|
fn WgslIrLowerer::lower_ray_query_statement_call(
  self : WgslIrLowerer,
  name : String,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
) -> Bool raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  match name {
    "rayQueryInitialize" => {
      guard arguments is [query, acceleration, ray_desc] else { return false }
      let query_handle = self.lower_function_expression_node(
        query, function, scope,
      )
      let acceleration_handle = self.lower_function_expression_node(
        acceleration, function, scope,
      )
      let ray_desc_handle = self.lower_function_expression_node(
        ray_desc, function, scope,
      )
      block.push(
        Statement::RayQuery(
          query_handle,
          RayQueryFunction::Initialize(acceleration_handle, ray_desc_handle),
        ),
      )
      true
    }
    "rayQueryProceed" => {
      guard arguments is [query] else { return false }
      let query_handle = self.lower_function_expression_node(
        query, function, scope,
      )
      block.push(
        Statement::RayQuery(
          query_handle,
          RayQueryFunction::Proceed(query_handle),
        ),
      )
      true
    }
    "rayQueryGenerateIntersection" => {
      guard arguments is [query, intersection_t] else { return false }
      let query_handle = self.lower_function_expression_node(
        query, function, scope,
      )
      let t_handle = self.lower_function_expression_node(
        intersection_t, function, scope,
      )
      block.push(
        Statement::RayQuery(
          query_handle,
          RayQueryFunction::GenerateIntersection(t_handle),
        ),
      )
      true
    }
    "rayQueryConfirmIntersection" => {
      guard arguments is [query] else { return false }
      let query_handle = self.lower_function_expression_node(
        query, function, scope,
      )
      block.push(
        Statement::RayQuery(query_handle, RayQueryFunction::ConfirmIntersection),
      )
      true
    }
    "rayQueryTerminate" => {
      guard arguments is [query] else { return false }
      let query_handle = self.lower_function_expression_node(
        query, function, scope,
      )
      block.push(Statement::RayQuery(query_handle, RayQueryFunction::Terminate))
      true
    }
    _ => false
  }
}

///|
fn WgslIrLowerer::lower_texture_statement_call(
  self : WgslIrLowerer,
  name : String,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
) -> Bool raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  match name {
    "textureAtomicAdd"
    | "textureAtomicAnd"
    | "textureAtomicMax"
    | "textureAtomicMin"
    | "textureAtomicOr"
    | "textureAtomicXor" => {
      let atomic_function = match
        wgsl_ir_texture_atomic_function_from_name(name) {
        Some(function) => function
        None => abort("unreachable texture atomic builtin")
      }
      self.lower_texture_atomic_statement(
        name, atomic_function, arguments, function, scope, block,
      )
      true
    }
    "textureStore" => {
      guard arguments.length() == 3 || arguments.length() == 4 else {
        raise WgslIrLowerError::UnsupportedExpression(
          "textureStore expects 3 or 4 arguments",
        )
      }
      let image = self.lower_function_expression_node(
        arguments[0],
        function,
        scope,
      )
      let coordinate = self.lower_function_expression_node(
        arguments[1],
        function,
        scope,
      )
      let (array_index, value_index) = if arguments.length() == 4 {
        (
          Some(
            self.lower_function_expression_node(arguments[2], function, scope),
          ),
          3,
        )
      } else {
        (None, 2)
      }
      let value = self.lower_function_expression_node(
        arguments[value_index],
        function,
        scope,
      )
      block.push(Statement::ImageStore(image, coordinate, array_index, value))
      true
    }
    _ => false
  }
}

///|
fn wgsl_ir_texture_atomic_function_from_name(name : String) -> AtomicFunction? {
  match name {
    "textureAtomicAdd" => Some(Add)
    "textureAtomicAnd" => Some(And)
    "textureAtomicMax" => Some(Max)
    "textureAtomicMin" => Some(Min)
    "textureAtomicOr" => Some(InclusiveOr)
    "textureAtomicXor" => Some(ExclusiveOr)
    _ => None
  }
}

///|
fn WgslIrLowerer::lower_texture_atomic_statement(
  self : WgslIrLowerer,
  name : String,
  atomic_function : AtomicFunction,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
) -> Unit raise WgslIrLowerError {
  guard arguments.length() == 3 || arguments.length() == 4 else {
    raise WgslIrLowerError::UnsupportedExpression(
      "\{name} expects 3 arguments for non-arrayed storage textures or 4 arguments for arrayed storage textures",
    )
  }
  let image = self.lower_function_expression_node(arguments[0], function, scope)
  let coordinate = self.lower_function_expression_node(
    arguments[1],
    function,
    scope,
  )
  let arrayed = self.image_expression_is_arrayed(function, image)
  let (array_index, value_index) = if arrayed {
    guard arguments.length() == 4 else {
      raise WgslIrLowerError::UnsupportedExpression(
        "\{name} on arrayed storage texture expects array index",
      )
    }
    (
      Some(self.lower_function_expression_node(arguments[2], function, scope)),
      3,
    )
  } else {
    guard arguments.length() == 3 else {
      raise WgslIrLowerError::UnsupportedExpression(
        "\{name} on non-arrayed storage texture does not accept array index",
      )
    }
    (None, 2)
  }
  let value = self.lower_function_expression_node(
    arguments[value_index],
    function,
    scope,
  )
  block.push(
    Statement::ImageAtomic(
      image, coordinate, array_index, atomic_function, value,
    ),
  )
}

///|
fn WgslIrLowerer::lower_texture_expression_call(
  self : WgslIrLowerer,
  name : String,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle? raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  match name {
    "textureSample" =>
      Some(
        self.lower_image_sample_expression(
          arguments,
          function,
          scope,
          SampleLevel::Auto,
        ),
      )
    "textureSampleBias" =>
      Some(
        self.lower_image_sample_with_level_argument(
          arguments, function, scope, "textureSampleBias", "bias",
        ),
      )
    "textureSampleGrad" =>
      Some(self.lower_image_sample_grad_expression(arguments, function, scope))
    "textureSampleLevel" =>
      Some(
        self.lower_image_sample_with_level_argument(
          arguments, function, scope, "textureSampleLevel", "level",
        ),
      )
    "textureSampleCompare" =>
      Some(
        self.lower_image_sample_compare_expression(
          arguments,
          function,
          scope,
          SampleLevel::Auto,
          "textureSampleCompare",
        ),
      )
    "textureSampleCompareLevel" =>
      Some(
        self.lower_image_sample_compare_expression(
          arguments,
          function,
          scope,
          SampleLevel::Zero,
          "textureSampleCompareLevel",
        ),
      )
    "textureSampleBaseClampToEdge" =>
      Some(
        self.lower_image_sample_base_clamp_to_edge_expression(
          arguments, function, scope,
        ),
      )
    "textureGather" =>
      Some(self.lower_image_gather_expression(arguments, function, scope))
    "textureGatherCompare" =>
      Some(
        self.lower_image_gather_compare_expression(arguments, function, scope),
      )
    "textureLoad" =>
      Some(self.lower_image_load_expression(arguments, function, scope))
    "textureDimensions" =>
      Some(self.lower_image_query_expression(arguments, function, scope))
    "textureNumLevels" =>
      Some(
        self.lower_image_query_kind_expression(
          arguments,
          function,
          scope,
          ImageQuery::NumLevels,
          "textureNumLevels",
        ),
      )
    "textureNumLayers" =>
      Some(
        self.lower_image_query_kind_expression(
          arguments,
          function,
          scope,
          ImageQuery::NumLayers,
          "textureNumLayers",
        ),
      )
    "textureNumSamples" =>
      Some(
        self.lower_image_query_kind_expression(
          arguments,
          function,
          scope,
          ImageQuery::NumSamples,
          "textureNumSamples",
        ),
      )
    _ => None
  }
}

///|
priv struct WgslIrTextureTrailingArgs {
  array_index : Handle?
  trailing : Array[Handle]
  offset : Handle?
}

///|
fn WgslIrLowerer::lower_texture_trailing_args(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
  image : Handle,
  base_count : Int,
  trailing_count : Int,
  callee : String,
) -> WgslIrTextureTrailingArgs raise WgslIrLowerError {
  let arrayed = self.image_expression_is_arrayed(function, image)
  let remaining = arguments.length() - base_count
  guard remaining >= trailing_count else {
    raise WgslIrLowerError::UnsupportedExpression(
      "\{callee} has too few arguments",
    )
  }
  let (array_index, trailing_start) = if arrayed {
    guard remaining == trailing_count + 1 || remaining == trailing_count + 2 else {
      raise WgslIrLowerError::UnsupportedExpression(
        "\{callee} argument list does not match arrayed texture signature",
      )
    }
    (
      Some(
        self.lower_function_expression_node(
          arguments[base_count],
          function,
          scope,
        ),
      ),
      base_count + 1,
    )
  } else {
    guard remaining == trailing_count || remaining == trailing_count + 1 else {
      raise WgslIrLowerError::UnsupportedExpression(
        "\{callee} argument list does not match texture signature",
      )
    }
    (None, base_count)
  }
  let trailing : Array[Handle] = []
  for i in 0..<trailing_count {
    trailing.push(
      self.lower_function_expression_node(
        arguments[trailing_start + i],
        function,
        scope,
      ),
    )
  }
  let offset_index = trailing_start + trailing_count
  let offset = if offset_index < arguments.length() {
    Some(
      self.lower_function_expression_node(
        arguments[offset_index],
        function,
        scope,
      ),
    )
  } else {
    None
  }
  WgslIrTextureTrailingArgs::{ array_index, trailing, offset }
}

///|
fn WgslIrLowerer::lower_texture_mip_level_argument(
  self : WgslIrLowerer,
  argument : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  self.lower_function_expression_node_with_expected(
    argument,
    function,
    scope,
    Some(self.scalar_type_handle(Scalar::Scalar(Sint, 4))),
  )
}

///|
fn WgslIrLowerer::image_expression_is_arrayed(
  self : WgslIrLowerer,
  function : Function,
  image : Handle,
) -> Bool {
  match self.image_expression_inner(function, image) {
    Some((_, arrayed, _)) => arrayed
    None => false
  }
}

///|
fn WgslIrLowerer::image_expression_is_multisampled(
  self : WgslIrLowerer,
  function : Function,
  image : Handle,
) -> Bool {
  match self.image_expression_inner(function, image) {
    Some((_, _, Sampled(_, multisampled))) => multisampled
    Some((_, _, Depth(multisampled))) => multisampled
    _ => false
  }
}

///|
fn WgslIrLowerer::image_expression_is_storage(
  self : WgslIrLowerer,
  function : Function,
  image : Handle,
) -> Bool {
  match self.image_expression_inner(function, image) {
    Some((_, _, Storage(_, _))) => true
    _ => false
  }
}

///|
fn WgslIrLowerer::image_expression_is_external(
  self : WgslIrLowerer,
  function : Function,
  image : Handle,
) -> Bool {
  match self.image_expression_inner(function, image) {
    Some((_, _, External)) => true
    _ => false
  }
}

///|
fn WgslIrLowerer::image_expression_is_depth(
  self : WgslIrLowerer,
  function : Function,
  image : Handle,
) -> Bool {
  match self.image_expression_inner(function, image) {
    Some((_, _, Depth(_))) => true
    _ => false
  }
}

///|
fn WgslIrLowerer::image_expression_inner(
  self : WgslIrLowerer,
  function : Function,
  image : Handle,
) -> (ImageDimension, Bool, ImageClass)? {
  match self.function_expression_type(function, image) {
    Some(ty_handle) =>
      match self.shader_module.types.get(ty_handle) {
        Some(ty) =>
          match ty.inner {
            Image(dimension, arrayed, image_class) =>
              Some((dimension, arrayed, image_class))
            _ => None
          }
        None => None
      }
    None => None
  }
}

///|
fn WgslIrLowerer::lower_image_sample_expression(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
  level : SampleLevel,
) -> Handle raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments.length() >= 3 else {
    raise WgslIrLowerError::UnsupportedExpression(
      "textureSample expects at least 3 arguments",
    )
  }
  let image = self.lower_function_expression_node(arguments[0], function, scope)
  let sampler = self.lower_function_expression_node(
    arguments[1],
    function,
    scope,
  )
  let coordinate = self.lower_function_expression_node(
    arguments[2],
    function,
    scope,
  )
  let parsed = self.lower_texture_trailing_args(
    arguments, function, scope, image, 3, 0, "textureSample",
  )
  function.expressions.append(
    Expression::ImageSample(
      image,
      sampler,
      None,
      coordinate,
      parsed.array_index,
      parsed.offset,
      level,
      None,
      false,
    ),
  )
}

///|
fn WgslIrLowerer::lower_image_sample_with_level_argument(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
  callee : String,
  level_name : String,
) -> Handle raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments.length() >= 4 else {
    raise WgslIrLowerError::UnsupportedExpression(
      "\{callee} expects at least 4 arguments",
    )
  }
  let image = self.lower_function_expression_node(arguments[0], function, scope)
  let sampler = self.lower_function_expression_node(
    arguments[1],
    function,
    scope,
  )
  let coordinate = self.lower_function_expression_node(
    arguments[2],
    function,
    scope,
  )
  let parsed = self.lower_texture_trailing_args(
    arguments, function, scope, image, 3, 1, callee,
  )
  guard parsed.trailing is [level_handle] else {
    raise WgslIrLowerError::UnsupportedExpression(
      "\{callee} missing \{level_name} argument",
    )
  }
  let level = if level_name == "bias" {
    SampleLevel::Bias(level_handle)
  } else {
    SampleLevel::Exact(level_handle)
  }
  function.expressions.append(
    Expression::ImageSample(
      image,
      sampler,
      None,
      coordinate,
      parsed.array_index,
      parsed.offset,
      level,
      None,
      false,
    ),
  )
}

///|
fn WgslIrLowerer::lower_image_sample_grad_expression(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments.length() >= 5 else {
    raise WgslIrLowerError::UnsupportedExpression(
      "textureSampleGrad expects at least 5 arguments",
    )
  }
  let image = self.lower_function_expression_node(arguments[0], function, scope)
  let sampler = self.lower_function_expression_node(
    arguments[1],
    function,
    scope,
  )
  let coordinate = self.lower_function_expression_node(
    arguments[2],
    function,
    scope,
  )
  let parsed = self.lower_texture_trailing_args(
    arguments, function, scope, image, 3, 2, "textureSampleGrad",
  )
  guard parsed.trailing is [ddx, ddy] else {
    raise WgslIrLowerError::UnsupportedExpression(
      "textureSampleGrad missing gradient arguments",
    )
  }
  function.expressions.append(
    Expression::ImageSample(
      image,
      sampler,
      None,
      coordinate,
      parsed.array_index,
      parsed.offset,
      SampleLevel::Gradient(ddx, ddy),
      None,
      false,
    ),
  )
}

///|
fn WgslIrLowerer::lower_image_sample_compare_expression(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
  level : SampleLevel,
  callee : String,
) -> Handle raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments.length() >= 4 else {
    raise WgslIrLowerError::UnsupportedExpression(
      "\{callee} expects at least 4 arguments",
    )
  }
  let image = self.lower_function_expression_node(arguments[0], function, scope)
  let sampler = self.lower_function_expression_node(
    arguments[1],
    function,
    scope,
  )
  let coordinate = self.lower_function_expression_node(
    arguments[2],
    function,
    scope,
  )
  let parsed = self.lower_texture_trailing_args(
    arguments, function, scope, image, 3, 1, callee,
  )
  guard parsed.trailing is [depth_ref] else {
    raise WgslIrLowerError::UnsupportedExpression(
      "\{callee} missing depth reference argument",
    )
  }
  function.expressions.append(
    Expression::ImageSample(
      image,
      sampler,
      None,
      coordinate,
      parsed.array_index,
      parsed.offset,
      level,
      Some(depth_ref),
      false,
    ),
  )
}

///|
fn WgslIrLowerer::lower_image_sample_base_clamp_to_edge_expression(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments.length() == 3 else {
    raise WgslIrLowerError::UnsupportedExpression(
      "textureSampleBaseClampToEdge expects 3 arguments",
    )
  }
  let image = self.lower_function_expression_node(arguments[0], function, scope)
  let sampler = self.lower_function_expression_node(
    arguments[1],
    function,
    scope,
  )
  let coordinate = self.lower_function_expression_node(
    arguments[2],
    function,
    scope,
  )
  function.expressions.append(
    Expression::ImageSample(
      image,
      sampler,
      None,
      coordinate,
      None,
      None,
      SampleLevel::Zero,
      None,
      true,
    ),
  )
}

///|
fn WgslIrLowerer::lower_image_gather_expression(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments.length() >= 3 else {
    raise WgslIrLowerError::UnsupportedExpression(
      "textureGather expects at least 3 arguments",
    )
  }
  let probe_image_index = if wgsl_ir_expr_node_is_gather_component(arguments[0]) {
    1
  } else {
    0
  }
  let probe_image = self.lower_function_expression_node(
    arguments[probe_image_index],
    function,
    scope,
  )
  let depth = self.image_expression_is_depth(function, probe_image)
  let has_component = probe_image_index == 1
  let (component, image, sampler, coordinate, base_count) = if depth {
    let (component, sampler_index, coordinate_index, base_count) = if has_component {
      guard arguments.length() >= 4 else {
        raise WgslIrLowerError::UnsupportedExpression(
          "textureGather with a component argument expects image, sampler, and coordinate arguments",
        )
      }
      (wgsl_ir_gather_component_from_node(arguments[0]), 2, 3, 4)
    } else {
      (SwizzleComponent::X, 1, 2, 3)
    }
    let sampler = self.lower_function_expression_node(
      arguments[sampler_index],
      function,
      scope,
    )
    let coordinate = self.lower_function_expression_node(
      arguments[coordinate_index],
      function,
      scope,
    )
    (Some(component), probe_image, sampler, coordinate, base_count)
  } else {
    guard arguments.length() >= 4 else {
      raise WgslIrLowerError::UnsupportedExpression(
        "textureGather for non-depth textures expects a component argument",
      )
    }
    let component = wgsl_ir_gather_component_from_node(arguments[0])
    let sampler = self.lower_function_expression_node(
      arguments[2],
      function,
      scope,
    )
    let coordinate = self.lower_function_expression_node(
      arguments[3],
      function,
      scope,
    )
    (Some(component), probe_image, sampler, coordinate, 4)
  }
  let parsed = self.lower_texture_trailing_args(
    arguments, function, scope, image, base_count, 0, "textureGather",
  )
  function.expressions.append(
    Expression::ImageSample(
      image,
      sampler,
      component,
      coordinate,
      parsed.array_index,
      parsed.offset,
      SampleLevel::Auto,
      None,
      false,
    ),
  )
}

///|
fn WgslIrLowerer::lower_image_gather_compare_expression(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments.length() >= 4 else {
    raise WgslIrLowerError::UnsupportedExpression(
      "textureGatherCompare expects at least 4 arguments",
    )
  }
  let image = self.lower_function_expression_node(arguments[0], function, scope)
  let sampler = self.lower_function_expression_node(
    arguments[1],
    function,
    scope,
  )
  let coordinate = self.lower_function_expression_node(
    arguments[2],
    function,
    scope,
  )
  let parsed = self.lower_texture_trailing_args(
    arguments, function, scope, image, 3, 1, "textureGatherCompare",
  )
  guard parsed.trailing is [depth_ref] else {
    raise WgslIrLowerError::UnsupportedExpression(
      "textureGatherCompare missing depth reference argument",
    )
  }
  function.expressions.append(
    Expression::ImageSample(
      image,
      sampler,
      Some(SwizzleComponent::X),
      coordinate,
      parsed.array_index,
      parsed.offset,
      SampleLevel::Auto,
      Some(depth_ref),
      false,
    ),
  )
}

///|
fn WgslIrLowerer::lower_image_load_expression(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments.length() >= 2 && arguments.length() <= 4 else {
    raise WgslIrLowerError::UnsupportedExpression(
      "textureLoad expects 2 to 4 arguments",
    )
  }
  let image = self.lower_function_expression_node(arguments[0], function, scope)
  let coordinate = self.lower_function_expression_node(
    arguments[1],
    function,
    scope,
  )
  let arrayed = self.image_expression_is_arrayed(function, image)
  let multisampled = self.image_expression_is_multisampled(function, image)
  let storage = self.image_expression_is_storage(function, image)
  let external = self.image_expression_is_external(function, image)
  let no_handle : Handle? = None
  let (array_index, sample, level) = if multisampled {
    guard !arrayed && arguments.length() == 3 else {
      raise WgslIrLowerError::UnsupportedExpression(
        "textureLoad multisampled texture expects sample index",
      )
    }
    (
      no_handle,
      Some(self.lower_function_expression_node(arguments[2], function, scope)),
      no_handle,
    )
  } else if arrayed {
    if storage {
      guard arguments.length() == 3 else {
        raise WgslIrLowerError::UnsupportedExpression(
          "textureLoad storage texture array expects array index",
        )
      }
      (
        Some(self.lower_function_expression_node(arguments[2], function, scope)),
        no_handle,
        no_handle,
      )
    } else {
      guard arguments.length() == 4 else {
        raise WgslIrLowerError::UnsupportedExpression(
          "textureLoad sampled texture array expects array index and level",
        )
      }
      (
        Some(self.lower_function_expression_node(arguments[2], function, scope)),
        no_handle,
        Some(
          self.lower_texture_mip_level_argument(arguments[3], function, scope),
        ),
      )
    }
  } else if storage || external {
    guard arguments.length() == 2 else {
      raise WgslIrLowerError::UnsupportedExpression(
        "textureLoad storage/external texture expects no level argument",
      )
    }
    (no_handle, no_handle, no_handle)
  } else {
    guard arguments.length() == 3 else {
      raise WgslIrLowerError::UnsupportedExpression(
        "textureLoad sampled texture expects mip level",
      )
    }
    (
      no_handle,
      no_handle,
      Some(self.lower_texture_mip_level_argument(arguments[2], function, scope)),
    )
  }
  ignore(self.image_expression_result_type(function, image, None, None))
  function.expressions.append(
    Expression::ImageLoad(image, coordinate, array_index, sample, level),
  )
}

///|
fn WgslIrLowerer::lower_image_query_expression(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments.length() == 1 || arguments.length() == 2 else {
    raise WgslIrLowerError::UnsupportedExpression(
      "textureDimensions expects 1 or 2 arguments",
    )
  }
  let image = self.lower_function_expression_node(arguments[0], function, scope)
  let level = if arguments.length() == 2 {
    Some(self.lower_texture_mip_level_argument(arguments[1], function, scope))
  } else {
    None
  }
  function.expressions.append(
    Expression::ImageQuery(image, ImageQuery::Size(level)),
  )
}

///|
fn WgslIrLowerer::lower_image_query_kind_expression(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
  query : ImageQuery,
  callee : String,
) -> Handle raise WgslIrLowerError {
  let arguments = wgsl_ir_flatten_expression_arguments(arguments)
  guard arguments.length() == 1 else {
    raise WgslIrLowerError::UnsupportedExpression(
      "\{callee} expects 1 argument",
    )
  }
  let image = self.lower_function_expression_node(arguments[0], function, scope)
  function.expressions.append(Expression::ImageQuery(image, query))
}
