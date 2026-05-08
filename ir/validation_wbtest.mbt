///|
test "IR validator accepts lowered WGSL module" {
  let source =
    #|const COUNT: u32 = 4u;
    #|
    #|fn helper(x: u32) -> u32 {
    #|  return x + COUNT;
    #|}
    #|
    #|@compute
    #|fn main() {
    #|  helper(1u);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  validate_wgsl_ir_module(module_) catch {
    error => abort(error.message())
  }
}

///|
test "IR validator rejects invalid type handles" {
  let module_ = Module()
  let init = module_.append_global_expression(
    Expression::Literal(Literal::I32(1)),
  )
  ignore(
    module_.append_constant(Constant::{
      name: Some("BAD"),
      ty: Handle::Handle(99),
      init,
    }),
  )
  let message = try {
    validate_wgsl_ir_module(module_)
    "ok"
  } catch {
    error => error.message()
  }
  debug_inspect(message, content="\"invalid IR type handle: 99\"")
}

///|
test "IR validator rejects invalid function call handles" {
  let module_ = Module()
  let function = Function::Function(Some("main"))
  function.body.push(Statement::Call(Handle::Handle(42), [], None))
  module_.append_entry_point(EntryPoint::{
    name: "main",
    stage: Compute,
    early_depth_test: None,
    workgroup_size: [1, 1, 1],
    workgroup_size_overrides: None,
    function,
    mesh_info: None,
    task_payload: None,
    incoming_ray_payload: None,
  })
  let message = try {
    validate_wgsl_ir_module(module_)
    "ok"
  } catch {
    error => error.message()
  }
  debug_inspect(message, content="\"invalid IR function handle: 42\"")
}

///|
test "IR validator rejects invalid const_assert handles" {
  let module_ = Module()
  module_.append_const_assert(Handle::Handle(42))
  let message = try {
    validate_wgsl_ir_module(module_)
    "ok"
  } catch {
    error => error.message()
  }
  debug_inspect(message, content="\"invalid IR global expression handle: 42\"")
}

///|
test "IR validator rejects invalid function-call expression handles" {
  let module_ = Module()
  let function = Function::Function(Some("main"))
  ignore(
    function.expressions.append(
      Expression::FunctionCall(Handle::Handle(42), []),
    ),
  )
  module_.append_entry_point(EntryPoint::{
    name: "main",
    stage: Compute,
    early_depth_test: None,
    workgroup_size: [1, 1, 1],
    workgroup_size_overrides: None,
    function,
    mesh_info: None,
    task_payload: None,
    incoming_ray_payload: None,
  })
  let message = try {
    validate_wgsl_ir_module(module_)
    "ok"
  } catch {
    error => error.message()
  }
  debug_inspect(message, content="\"invalid IR function handle: 42\"")
}

///|
test "IR validator rejects non-bool branch condition" {
  let module_ = Module()
  ignore(
    module_.append_type(Type::{
      name: Some("u32"),
      inner: TypeInner::Scalar(Scalar::Scalar(Uint, 4)),
    }),
  )
  let function = Function::Function(Some("main"))
  let condition = function.expressions.append(
    Expression::Literal(Literal::U32(1)),
  )
  function.body.push(Statement::If(condition, Block::Block(), Block::Block()))
  module_.append_entry_point(validation_test_entry_point(function))
  let message = try {
    validate_wgsl_ir_module(module_)
    "ok"
  } catch {
    error => error.message()
  }
  debug_inspect(
    message,
    content="\"invalid IR condition expression type in main for handle: 0 (Literal(U32(1))) with type { name: Some(\\\"u32\\\"), inner: Scalar({ kind: Uint, width: 4 }) }\"",
  )
}

///|
test "IR validator rejects non-pointer store target" {
  let module_ = Module()
  ignore(
    module_.append_type(Type::{
      name: Some("u32"),
      inner: TypeInner::Scalar(Scalar::Scalar(Uint, 4)),
    }),
  )
  let function = Function::Function(Some("main"))
  let target = function.expressions.append(Expression::Literal(Literal::U32(1)))
  let value = function.expressions.append(Expression::Literal(Literal::U32(2)))
  function.body.push(Statement::Store(target, value))
  module_.append_entry_point(validation_test_entry_point(function))
  let message = try {
    validate_wgsl_ir_module(module_)
    "ok"
  } catch {
    error => error.message()
  }
  debug_inspect(
    message,
    content="\"invalid IR store target expression type for handle: 0\"",
  )
}

///|
test "IR validator rejects function call argument count mismatch" {
  let module_ = Module()
  let u32_ty = module_.append_type(Type::{
    name: Some("u32"),
    inner: TypeInner::Scalar(Scalar::Scalar(Uint, 4)),
  })
  let callee = Function::Function(Some("callee"))
  callee.arguments.push(FunctionArgument::{
    name: Some("x"),
    ty: u32_ty,
    binding: None,
  })
  let callee_handle = module_.append_function(callee)
  let caller = Function::Function(Some("main"))
  caller.body.push(Statement::Call(callee_handle, [], None))
  module_.append_entry_point(validation_test_entry_point(caller))
  let message = try {
    validate_wgsl_ir_module(module_)
    "ok"
  } catch {
    error => error.message()
  }
  debug_inspect(
    message,
    content="\"invalid IR function call argument count for callee: expected 1, got 0\"",
  )
}

///|
test "IR validator rejects function call argument type mismatch" {
  let module_ = Module()
  let u32_ty = module_.append_type(Type::{
    name: Some("u32"),
    inner: TypeInner::Scalar(Scalar::Scalar(Uint, 4)),
  })
  ignore(
    module_.append_type(Type::{
      name: Some("bool"),
      inner: TypeInner::Scalar(Scalar::Scalar(Bool, 1)),
    }),
  )
  let callee = Function::Function(Some("callee"))
  callee.arguments.push(FunctionArgument::{
    name: Some("x"),
    ty: u32_ty,
    binding: None,
  })
  let callee_handle = module_.append_function(callee)
  let caller = Function::Function(Some("main"))
  let argument = caller.expressions.append(
    Expression::Literal(Literal::Bool(true)),
  )
  caller.body.push(Statement::Call(callee_handle, [argument], None))
  module_.append_entry_point(validation_test_entry_point(caller))
  let message = try {
    validate_wgsl_ir_module(module_)
    "ok"
  } catch {
    error => error.message()
  }
  debug_inspect(
    message,
    content="\"invalid IR function call argument type for callee at argument 0\"",
  )
}

///|
test "IR validator accepts vector select masks" {
  let module_ = Module()
  let f32_ty = module_.append_type(Type::{
    name: Some("f32"),
    inner: TypeInner::Scalar(Scalar::Scalar(Float, 4)),
  })
  ignore(f32_ty)
  let vec2_f32_ty = module_.append_type(Type::{
    name: Some("vec2<f32>"),
    inner: TypeInner::Vector(Bi, Scalar::Scalar(Float, 4)),
  })
  let vec2_bool_ty = module_.append_type(Type::{
    name: Some("vec2<bool>"),
    inner: TypeInner::Vector(Bi, Scalar::Scalar(Bool, 1)),
  })
  let function = Function::Function(Some("select_mask"))
  let condition = function.expressions.append(
    Expression::ZeroValue(vec2_bool_ty),
  )
  let accept = function.expressions.append(Expression::ZeroValue(vec2_f32_ty))
  let reject = function.expressions.append(Expression::ZeroValue(vec2_f32_ty))
  ignore(
    function.expressions.append(Expression::Select(condition, accept, reject)),
  )
  ignore(module_.append_function(function))
  let message = try {
    validate_wgsl_ir_module(module_)
    "ok"
  } catch {
    error => error.message()
  }
  debug_inspect(message, content="\"ok\"")
}

///|
test "IR validator rejects mismatched vector select masks" {
  let module_ = Module()
  let vec2_f32_ty = module_.append_type(Type::{
    name: Some("vec2<f32>"),
    inner: TypeInner::Vector(Bi, Scalar::Scalar(Float, 4)),
  })
  let vec3_bool_ty = module_.append_type(Type::{
    name: Some("vec3<bool>"),
    inner: TypeInner::Vector(Tri, Scalar::Scalar(Bool, 1)),
  })
  let function = Function::Function(Some("select_mask"))
  let condition = function.expressions.append(
    Expression::ZeroValue(vec3_bool_ty),
  )
  let accept = function.expressions.append(Expression::ZeroValue(vec2_f32_ty))
  let reject = function.expressions.append(Expression::ZeroValue(vec2_f32_ty))
  ignore(
    function.expressions.append(Expression::Select(condition, accept, reject)),
  )
  ignore(module_.append_function(function))
  let message = try {
    validate_wgsl_ir_module(module_)
    "ok"
  } catch {
    error => error.message()
  }
  debug_inspect(
    message,
    content="\"invalid IR condition expression type in select_mask for handle: 0 (ZeroValue({ index: 1 })) with type {\\n  name: Some(\\\"vec3<bool>\\\"),\\n  inner: Vector(Tri, { kind: Bool, width: 1 }),\\n}\"",
  )
}

///|
fn validation_test_entry_point(function : Function) -> EntryPoint {
  EntryPoint::{
    name: "main",
    stage: Compute,
    early_depth_test: None,
    workgroup_size: [1, 1, 1],
    workgroup_size_overrides: None,
    function,
    mesh_info: None,
    task_payload: None,
    incoming_ray_payload: None,
  }
}
