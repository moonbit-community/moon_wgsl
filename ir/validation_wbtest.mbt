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
