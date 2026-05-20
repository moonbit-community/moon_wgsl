///|
test "naga-oil writer policy lowers static vector indexes to swizzles" {
  let source =
    #|fn read_z(m: mat4x4<f32>) -> f32 {
    #|  return m[3][2];
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let naga_oil = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(naga_oil.contains("return m[3].z;"), content="true")
  debug_inspect(naga_oil.contains("return m[3][2];"), content="false")
}

///|
test "naga-oil writer policy preserves typed vector constructors in matrix multiply context" {
  let source =
    #|fn project(m: mat4x4<f32>, z: f32) -> vec4<f32> {
    #|  let view_pos: vec4<f32> = (m * vec4(0.0, 0.0, z, 1.0));
    #|  return view_pos;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let naga_oil = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    naga_oil.contains(
      "let view_pos: vec4<f32> = (m * vec4<f32>(0f, 0f, z, 1f));",
    ),
    content="true",
  )
  debug_inspect(naga_oil.contains("m * vec4(0f, 0f, z, 1f)"), content="false")
}

///|
test "naga-oil writer policy avoids duplicate parentheses around projection bases" {
  let source =
    #|fn project(m: mat4x4<f32>, position: vec3<f32>) -> vec3<f32> {
    #|  return (m * vec4<f32>(position, 1f)).xyz;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let naga_oil = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    naga_oil.contains("return (m * vec4<f32>(position, 1f)).xyz;"),
    content="true",
  )
  debug_inspect(naga_oil.contains("((m * vec4"), content="false")
}
