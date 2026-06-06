///|
fn WgslIrLowerer::address_of_expression_type(
  self : WgslIrLowerer,
  function : Function,
  handle : Handle,
) -> Handle? {
  ignore(self)
  match function.expressions.items.get(handle.index()) {
    Some(AddressOf(ty, _)) => Some(ty)
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
    Unary(op, expr) => if op == BitAnd { Some(expr) } else { None }
    _ => None
  }
}

///|
fn wgsl_ir_local_variable_kind(
  kind : @ast.WgslLocalDeclarationKind,
) -> LocalVariableKind {
  match kind {
    Var => Var
    Let => Let
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
    raise UnsupportedExpression("empty function call")
  }
  let expression_mark = function.expressions.items.length()
  match wgsl_ir_expr_call_node(root).kind() {
    Call(callee, arguments) => {
      let arguments = wgsl_ir_call_arguments(arguments)
      match callee.kind() {
        Identifier(name) =>
          match wgsl_ir_barrier_statement_from_call(name.name(), arguments) {
            Some(statement) => block.push(statement)
            None =>
              match wgsl_ir_atomic_function_from_name(name.name()) {
                Some(atomic_function) =>
                  self.lower_atomic_statement_call(
                    atomic_function, arguments, function, scope, block,
                  )
                None =>
                  match self.function_names.get(name.name()) {
                    Some(handle) => {
                      let values = self.lower_user_function_call_statement_arguments(
                        handle, arguments, function, scope, block,
                      )
                      match wgsl_ir_last_call_argument_handle(values) {
                        Some(last_value) =>
                          self.push_user_function_call_emit_ranges(
                            block, function, expression_mark, handle, values, last_value,
                          )
                        None => ()
                      }
                      block.push(Call(handle, values, None))
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
fn wgsl_ir_last_call_argument_handle(values : Array[Handle]) -> Handle? {
  let mut result : Handle? = None
  for value in values {
    match result {
      Some(current) =>
        if value.index() > current.index() {
          result = Some(value)
        }
      None => result = Some(value)
    }
  }
  result
}

///|
fn WgslIrLowerer::push_user_function_call_emit_ranges(
  self : WgslIrLowerer,
  block : Block,
  function : Function,
  expression_mark : Int,
  callee : Handle,
  arguments : Array[Handle],
  end : Handle,
) -> Unit {
  let suppressed : @set.Set[Int] = Set([])
  match self.shader_module.functions.items.get(callee.index()) {
    Some(callee_function) =>
      for index in 0..<arguments.length() {
        match callee_function.arguments.get(index) {
          Some(parameter) if self.lowerer_type_is_pointer(parameter.ty) =>
            wgsl_ir_collect_pointer_call_lvalue_emit_suppression(
              function,
              arguments[index],
              suppressed,
            )
          _ => ()
        }
      }
    None => ()
  }
  BodyEmissionPlanner::push_statement_emit_ranges_skipping(
    block, function, expression_mark, end, suppressed,
  )
}

///|
fn wgsl_ir_collect_pointer_call_lvalue_emit_suppression(
  function : Function,
  handle : Handle,
  suppressed : @set.Set[Int],
) -> Unit {
  if suppressed.contains(handle.index()) {
    return
  }
  match function.expressions.items.get(handle.index()) {
    Some(Access(base, _))
    | Some(AccessIndex(base, _))
    | Some(Component(base, _))
    | Some(Swizzle(_, base, _)) => {
      suppressed.add(handle.index())
      wgsl_ir_collect_pointer_call_lvalue_emit_suppression(
        function, base, suppressed,
      )
    }
    _ => ()
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
        raise UnsupportedExpression("\{name} expects no arguments")
      }
      match barrier {
        BarrierControl(barrier) => Some(ControlBarrier(barrier))
        BarrierMemory(barrier) => Some(MemoryBarrier(barrier))
      }
    }
    None => None
  }
}

///|
fn wgsl_ir_barrier_value_error(name : String) -> WgslIrLowerError {
  UnsupportedExpression("barrier builtin has no value: \{name}")
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
  let callee_function = match
    self.shader_module.functions.items.get(callee.index()) {
    Some(value) => value
    None => raise UnsupportedExpression("invalid function call target")
  }
  let planner = self.call_argument_planner(
    flattened, callee_function, function, scope,
  )
  planner.lower_arguments()
}

///|
fn WgslIrLowerer::callee_parameter_is_pointer(
  self : WgslIrLowerer,
  callee_function : Function,
  index : Int,
) -> Bool {
  match callee_function.arguments.get(index) {
    Some(parameter) => self.lowerer_type_is_pointer(parameter.ty)
    None => false
  }
}

///|
fn wgsl_ir_expr_node_is_call_value(node : @ast.WgslExprNode) -> Bool {
  match node.kind() {
    Group(inner) => wgsl_ir_expr_node_is_call_value(inner)
    Call(_, _) => true
    _ => false
  }
}

///|
fn wgsl_ir_expr_node_is_static_literal_index(node : @ast.WgslExprNode) -> Bool {
  match node.kind() {
    Group(inner) => wgsl_ir_expr_node_is_static_literal_index(inner)
    _ => wgsl_ir_int_literal_from_expr_node(node) != None
  }
}

///|
fn WgslIrLowerer::lower_user_function_call_argument_at(
  self : WgslIrLowerer,
  argument : @ast.WgslExprNode,
  callee_function : Function,
  index : Int,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  let expected_ty = match callee_function.arguments.get(index) {
    Some(argument) => Some(argument.ty)
    None => None
  }
  match expected_ty {
    Some(ty) if self.lowerer_type_is_pointer(ty) =>
      match wgsl_ir_address_of_operand_node(argument) {
        Some(target) =>
          return self.lower_function_lvalue_node(target, function, scope)
        None => ()
      }
    _ => ()
  }
  let lowered = self.lower_function_expression_node_with_expected(
    argument, function, scope, expected_ty,
  )
  match expected_ty {
    Some(ty) if self.lowerer_type_is_pointer(ty) => lowered
    Some(_) => self.apply_function_load_rule(function, lowered)
    None => lowered
  }
}

///|
fn WgslIrLowerer::expression_node_contains_user_function_call(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
) -> Bool {
  match node.kind() {
    Group(inner) | Template(inner, _) =>
      self.expression_node_contains_user_function_call(inner)
    Call(callee, arguments) => {
      let arguments = wgsl_ir_call_arguments(arguments)
      let callee_is_user_function = match callee.kind() {
        Identifier(name) => self.function_names.contains(name.name())
        _ => false
      }
      callee_is_user_function ||
      arguments.any(fn(argument) {
        self.expression_node_contains_user_function_call(argument)
      })
    }
    Sequence(items) =>
      items.any(fn(item) {
        self.expression_node_contains_user_function_call(item)
      })
    Unary(_, expr) => self.expression_node_contains_user_function_call(expr)
    Binary(_, left, right) =>
      self.expression_node_contains_user_function_call(left) ||
      self.expression_node_contains_user_function_call(right)
    Member(base, _) => self.expression_node_contains_user_function_call(base)
    Index(base, index) =>
      self.expression_node_contains_user_function_call(base) ||
      self.expression_node_contains_user_function_call(index)
    _ => false
  }
}

///|
fn WgslIrLowerer::lower_user_function_call_statement_arguments(
  self : WgslIrLowerer,
  callee : Handle,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
) -> Array[Handle] raise WgslIrLowerError {
  let lowered = self.lower_user_function_call_arguments(
    callee, arguments, function, scope,
  )
  let materialized : Array[Handle] = []
  for index in 0..<lowered.length() {
    let argument = lowered[index]
    materialized.push(
      self.materialize_nested_user_call_argument(
        function, scope, block, callee, index, argument,
      ),
    )
  }
  materialized
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
        RayQuery(query_handle, Initialize(acceleration_handle, ray_desc_handle)),
      )
      true
    }
    "rayQueryProceed" => {
      guard arguments is [query] else { return false }
      let query_handle = self.lower_function_expression_node(
        query, function, scope,
      )
      block.push(RayQuery(query_handle, Proceed(query_handle)))
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
      block.push(RayQuery(query_handle, GenerateIntersection(t_handle)))
      true
    }
    "rayQueryConfirmIntersection" => {
      guard arguments is [query] else { return false }
      let query_handle = self.lower_function_expression_node(
        query, function, scope,
      )
      block.push(RayQuery(query_handle, ConfirmIntersection))
      true
    }
    "rayQueryTerminate" => {
      guard arguments is [query] else { return false }
      let query_handle = self.lower_function_expression_node(
        query, function, scope,
      )
      block.push(RayQuery(query_handle, Terminate))
      true
    }
    _ => false
  }
}

///|
fn WgslIrLowerer::lower_atomic_statement_call(
  self : WgslIrLowerer,
  atomic_function : AtomicFunction,
  arguments : Array[@ast.WgslExprNode],
  function : Function,
  scope : WgslIrFunctionScope,
  block : Block,
) -> Unit raise WgslIrLowerError {
  if atomic_function == Store {
    guard arguments is [pointer_argument, value_argument] else {
      raise UnsupportedExpression("atomicStore expects 2 arguments")
    }
    let pointer = self.lower_atomic_pointer_argument(
      pointer_argument, function, scope,
    )
    let value = self.lower_function_expression_node(
      value_argument, function, scope,
    )
    block.push(Atomic(pointer, Store, value, None, None))
    return
  }
  let handle = self.lower_function_atomic_call(
    atomic_function, arguments, function, scope,
  )
  if self.function_expression_type(function, handle) != None {
    ignore(self.materialize_function_expression(function, scope, block, handle))
  } else {
    block.push(Emit(HandleRange(handle, handle)))
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
        raise UnsupportedExpression("textureStore expects 3 or 4 arguments")
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
      let (raw_array_index, value_index) = if arguments.length() == 4 {
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
      block.push(
        ImageStore(
          image,
          self.materialize_image_store_operand(
            function, scope, block, coordinate,
          ),
          self.materialize_optional_image_store_operand(
            function, scope, block, raw_array_index,
          ),
          self.materialize_image_store_operand(function, scope, block, value),
        ),
      )
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
    raise UnsupportedExpression(
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
      raise UnsupportedExpression(
        "\{name} on arrayed storage texture expects array index",
      )
    }
    (
      Some(self.lower_function_expression_node(arguments[2], function, scope)),
      3,
    )
  } else {
    guard arguments.length() == 3 else {
      raise UnsupportedExpression(
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
    ImageAtomic(image, coordinate, array_index, atomic_function, value),
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
      Some(self.lower_image_sample_expression(arguments, function, scope, Auto))
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
          Auto,
          "textureSampleCompare",
        ),
      )
    "textureSampleCompareLevel" =>
      Some(
        self.lower_image_sample_compare_expression(
          arguments,
          function,
          scope,
          Zero,
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
          NumLevels,
          "textureNumLevels",
        ),
      )
    "textureNumLayers" =>
      Some(
        self.lower_image_query_kind_expression(
          arguments,
          function,
          scope,
          NumLayers,
          "textureNumLayers",
        ),
      )
    "textureNumSamples" =>
      Some(
        self.lower_image_query_kind_expression(
          arguments,
          function,
          scope,
          NumSamples,
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
priv enum WgslIrTextureOffsetPlan {
  LowerTextureOffsetNode(@ast.WgslExprNode)
  FinishNamedTextureOffsetConstructor(
    String,
    Array[@ast.WgslExprNode],
    Array[Handle],
    Int
  )
  FinishTemplatedTextureOffsetConstructor(Handle, Array[Handle])
}

///|
fn WgslIrLowerer::prelower_texture_offset_plan(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
  function : Function,
  scope : WgslIrFunctionScope,
) -> WgslIrTextureOffsetPlan raise WgslIrLowerError {
  match node.kind() {
    Group(inner) => self.prelower_texture_offset_plan(inner, function, scope)
    Call(callee, arguments) => {
      let arguments = wgsl_ir_call_arguments(arguments)
      match callee.kind() {
        Template(_, _) => {
          let ty = self.lower_templated_callee_type(callee)
          match ty {
            Some(ty) =>
              FinishTemplatedTextureOffsetConstructor(
                ty,
                self.lower_function_constructor_arguments(
                  ty, arguments, function, scope,
                ),
              )
            None => LowerTextureOffsetNode(node)
          }
        }
        Identifier(name) => {
          let ty = Some(
            self.lower_untemplated_constructor_type_from_ast(
              name.name(),
              arguments,
              "texture offset constructor",
            ),
          ) catch {
            _ => None
          }
          match ty {
            Some(_) => {
              let expression_mark = function.expressions.items.length()
              let lowered_arguments = self.lower_function_constructor_arguments_with_expected(
                arguments,
                function,
                scope,
                None,
              )
              FinishNamedTextureOffsetConstructor(
                name.name(),
                arguments,
                lowered_arguments,
                expression_mark,
              )
            }
            None => LowerTextureOffsetNode(node)
          }
        }
        _ => LowerTextureOffsetNode(node)
      }
    }
    _ => LowerTextureOffsetNode(node)
  }
}

///|
fn WgslIrLowerer::finish_texture_offset_plan(
  self : WgslIrLowerer,
  plan : WgslIrTextureOffsetPlan,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Handle raise WgslIrLowerError {
  match plan {
    LowerTextureOffsetNode(node) =>
      self.lower_function_expression_node(node, function, scope)
    FinishNamedTextureOffsetConstructor(
      name,
      arguments,
      lowered_arguments,
      expression_mark
    ) =>
      self.finish_function_constructor_call(
        name,
        arguments,
        lowered_arguments,
        function,
        scope,
        None,
        expression_mark,
      )
    FinishTemplatedTextureOffsetConstructor(ty, lowered_arguments) =>
      self.lower_function_constructor_expression_from_handles(
        ty, lowered_arguments, function,
      )
  }
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
    raise UnsupportedExpression("\{callee} has too few arguments")
  }
  let (array_index, trailing_start) = if arrayed {
    guard remaining == trailing_count + 1 || remaining == trailing_count + 2 else {
      raise UnsupportedExpression(
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
      raise UnsupportedExpression(
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
  { array_index, trailing, offset }
}

///|
fn WgslIrLowerer::image_type_handle_is_depth(
  self : WgslIrLowerer,
  ty : Handle,
) -> Bool {
  match self.shader_module.types.get(self.deref_pointer_type_handle(ty)) {
    Some(type_) =>
      match type_.inner {
        Image(_, _, Depth(_)) => true
        _ => false
      }
    None => false
  }
}

///|
fn WgslIrLowerer::image_type_handle_is_arrayed(
  self : WgslIrLowerer,
  ty : Handle,
) -> Bool {
  match self.shader_module.types.get(self.deref_pointer_type_handle(ty)) {
    Some(type_) =>
      match type_.inner {
        Image(_, arrayed, _) => arrayed
        _ => false
      }
    None => false
  }
}

///|
fn WgslIrLowerer::texture_offset_index_from_image_type(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  image_ty : Handle,
  base_count : Int,
  trailing_count : Int,
  callee : String,
) -> Int? raise WgslIrLowerError {
  let arrayed = self.image_type_handle_is_arrayed(image_ty)
  let remaining = arguments.length() - base_count
  guard remaining >= trailing_count else {
    raise UnsupportedExpression("\{callee} has too few arguments")
  }
  let trailing_start = if arrayed {
    guard remaining == trailing_count + 1 || remaining == trailing_count + 2 else {
      raise UnsupportedExpression(
        "\{callee} argument list does not match arrayed texture signature",
      )
    }
    base_count + 1
  } else {
    guard remaining == trailing_count || remaining == trailing_count + 1 else {
      raise UnsupportedExpression(
        "\{callee} argument list does not match texture signature",
      )
    }
    base_count
  }
  let offset_index = trailing_start + trailing_count
  if offset_index < arguments.length() {
    Some(offset_index)
  } else {
    None
  }
}

///|
fn WgslIrLowerer::predeclare_texture_coordinate_root(
  self : WgslIrLowerer,
  arguments : Array[@ast.WgslExprNode],
  coordinate_index : Int,
  function : Function,
  scope : WgslIrFunctionScope,
) -> Unit raise WgslIrLowerError {
  match arguments.get(coordinate_index) {
    Some(coordinate) =>
      self.predeclare_function_member_root_expression(
        coordinate, function, scope,
      )
    None => ()
  }
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
    Some(self.scalar_type_handle(Scalar(Sint, 4))),
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
    raise UnsupportedExpression("textureSample expects at least 3 arguments")
  }
  self.predeclare_texture_coordinate_root(arguments, 2, function, scope)
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
    ImageSample(
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
    raise UnsupportedExpression("\{callee} expects at least 4 arguments")
  }
  self.predeclare_texture_coordinate_root(arguments, 2, function, scope)
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
    raise UnsupportedExpression("\{callee} missing \{level_name} argument")
  }
  let level = if level_name == "bias" {
    SampleLevel::Bias(level_handle)
  } else {
    Exact(level_handle)
  }
  function.expressions.append(
    ImageSample(
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
    raise UnsupportedExpression(
      "textureSampleGrad expects at least 5 arguments",
    )
  }
  self.predeclare_texture_coordinate_root(arguments, 2, function, scope)
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
    raise UnsupportedExpression("textureSampleGrad missing gradient arguments")
  }
  function.expressions.append(
    ImageSample(
      image,
      sampler,
      None,
      coordinate,
      parsed.array_index,
      parsed.offset,
      Gradient(ddx, ddy),
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
    raise UnsupportedExpression("\{callee} expects at least 4 arguments")
  }
  self.predeclare_texture_coordinate_root(arguments, 2, function, scope)
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
    raise UnsupportedExpression("\{callee} missing depth reference argument")
  }
  function.expressions.append(
    ImageSample(
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
    raise UnsupportedExpression(
      "textureSampleBaseClampToEdge expects 3 arguments",
    )
  }
  self.predeclare_texture_coordinate_root(arguments, 2, function, scope)
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
    ImageSample(image, sampler, None, coordinate, None, None, Zero, None, true),
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
    raise UnsupportedExpression("textureGather expects at least 3 arguments")
  }
  let probe_image_index = if wgsl_ir_expr_node_is_gather_component(arguments[0]) {
    1
  } else {
    0
  }
  let probe_image_ty = self.infer_expression_type(
    arguments[probe_image_index],
    "textureGather image",
  )
  let depth = self.image_type_handle_is_depth(probe_image_ty)
  let has_component = probe_image_index == 1
  let (component, image_index, sampler_index, coordinate_index, base_count) = if depth {
    let (component, sampler_index, coordinate_index, base_count) = if has_component {
      guard arguments.length() >= 4 else {
        raise UnsupportedExpression(
          "textureGather with a component argument expects image, sampler, and coordinate arguments",
        )
      }
      (wgsl_ir_gather_component_from_node(arguments[0]), 2, 3, 4)
    } else {
      (X, 1, 2, 3)
    }
    (
      Some(component),
      probe_image_index,
      sampler_index,
      coordinate_index,
      base_count,
    )
  } else {
    guard arguments.length() >= 4 else {
      raise UnsupportedExpression(
        "textureGather for non-depth textures expects a component argument",
      )
    }
    let component = wgsl_ir_gather_component_from_node(arguments[0])
    (Some(component), probe_image_index, 2, 3, 4)
  }
  let offset_plan = match
    self.texture_offset_index_from_image_type(
      arguments, probe_image_ty, base_count, 0, "textureGather",
    ) {
    Some(offset_index) =>
      Some(
        self.prelower_texture_offset_plan(
          arguments[offset_index],
          function,
          scope,
        ),
      )
    None => None
  }
  let image = self.lower_function_expression_node(
    arguments[image_index],
    function,
    scope,
  )
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
  let array_index = if self.image_type_handle_is_arrayed(probe_image_ty) {
    Some(
      self.lower_function_expression_node(
        arguments[base_count],
        function,
        scope,
      ),
    )
  } else {
    None
  }
  let offset = match offset_plan {
    Some(plan) => Some(self.finish_texture_offset_plan(plan, function, scope))
    None => None
  }
  function.expressions.append(
    ImageSample(
      image,
      sampler,
      component,
      coordinate,
      array_index,
      offset,
      Auto,
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
    raise UnsupportedExpression(
      "textureGatherCompare expects at least 4 arguments",
    )
  }
  self.predeclare_texture_coordinate_root(arguments, 2, function, scope)
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
    raise UnsupportedExpression(
      "textureGatherCompare missing depth reference argument",
    )
  }
  function.expressions.append(
    ImageSample(
      image,
      sampler,
      Some(X),
      coordinate,
      parsed.array_index,
      parsed.offset,
      Auto,
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
    raise UnsupportedExpression("textureLoad expects 2 to 4 arguments")
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
      raise UnsupportedExpression(
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
        raise UnsupportedExpression(
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
        raise UnsupportedExpression(
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
      raise UnsupportedExpression(
        "textureLoad storage/external texture expects no level argument",
      )
    }
    (no_handle, no_handle, no_handle)
  } else {
    guard arguments.length() == 3 else {
      raise UnsupportedExpression(
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
    ImageLoad(image, coordinate, array_index, sample, level),
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
    raise UnsupportedExpression("textureDimensions expects 1 or 2 arguments")
  }
  let image = self.lower_function_expression_node(arguments[0], function, scope)
  let level = if arguments.length() == 2 {
    Some(self.lower_texture_mip_level_argument(arguments[1], function, scope))
  } else {
    None
  }
  function.expressions.append(ImageQuery(image, Size(level)))
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
    raise UnsupportedExpression("\{callee} expects 1 argument")
  }
  let image = self.lower_function_expression_node(arguments[0], function, scope)
  function.expressions.append(ImageQuery(image, query))
}
