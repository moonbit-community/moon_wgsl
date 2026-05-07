///|
test "IR emitter prints WGSL lowered from AST without source writeback" {
  let source =
    #|struct VertexIn {
    #|  @location(0) value: f32,
    #|}
    #|
    #|@group(0) @binding(1)
    #|var<uniform> scale: f32;
    #|
    #|const COUNT: u32 = 4u;
    #|
    #|fn helper(x: u32) -> u32 {
    #|  return x + COUNT;
    #|}
    #|
    #|@compute @workgroup_size(2, 3, 4)
    #|fn main(@builtin(global_invocation_id) id: vec3u) {
    #|  var local_value: u32 = COUNT + 1u;
    #|  local_value = local_value + 1u;
    #|  helper(local_value);
    #|  return;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  ignore(
    @parser.parse_wgsl_translation_unit_strict(emitted) catch {
      error => abort(error.message())
    },
  )
  debug_inspect(emitted.contains("struct VertexIn"), content="true")
  debug_inspect(emitted.contains("@group(0) @binding(1)"), content="true")
  debug_inspect(emitted.contains("const COUNT: u32 = 4u;"), content="true")
  debug_inspect(
    emitted.contains("@compute @workgroup_size(2, 3, 4)"),
    content="true",
  )
  debug_inspect(emitted.contains("helper(local_value);"), content="true")
}

///|
test "IR emitter mirrors naga entry-point stage attribute spacing" {
  let source =
    #|@fragment
    #|fn fragment() -> @location(0) f32 {
    #|  return 1.0;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("@fragment \nfn fragment"), content="true")
}

///|
test "IR emitter fails on invalid handles instead of inventing output" {
  let module_ = Module::new()
  let constant = Constant::{
    name: Some("BAD"),
    ty: Handle::new(99),
    init: Handle::new(0),
  }
  ignore(module_.append_constant(constant))
  let message = try {
    ignore(emit_wgsl_module_from_ir(module_))
    "ok"
  } catch {
    error => error.message()
  }
  debug_inspect(
    message,
    content="\"unsupported IR emission: invalid IR type handle: 99\"",
  )
}
