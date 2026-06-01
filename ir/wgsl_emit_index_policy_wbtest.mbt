///|
test "naga-oil writer policy lowers value vector indexes to swizzles" {
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
test "naga-oil writer policy preserves global binding vector indexes" {
  let source =
    #|struct View {
    #|  clip_from_view: mat4x4<f32>,
    #|}
    #|
    #|@group(0) @binding(0) var<uniform> view: View;
    #|
    #|fn near() -> f32 {
    #|  return view.clip_from_view[3][2];
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let naga_oil = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(naga_oil.contains("view.clip_from_view[3][2]"), content="true")
  debug_inspect(naga_oil.contains("view.clip_from_view[3].z"), content="false")
}

///|
test "naga-oil writer policy preserves global binding matrix column components as indexes" {
  let source =
    #|struct View {
    #|  clip_from_view: mat4x4<f32>,
    #|}
    #|
    #|@group(0) @binding(0) var<uniform> view: View;
    #|
    #|fn near() -> f32 {
    #|  return view.clip_from_view[3].w;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let naga_oil = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(naga_oil.contains("view.clip_from_view[3][3]"), content="true")
  debug_inspect(naga_oil.contains("view.clip_from_view[3].w"), content="false")
}

///|
test "naga-oil writer policy preserves vector component members" {
  let source =
    #|fn read_z(v: vec4<f32>) -> f32 {
    #|  return v.z;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let naga_oil = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(naga_oil.contains("return v.z;"), content="true")
  debug_inspect(naga_oil.contains("return v[2];"), content="false")
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
test "naga-oil writer policy contextualizes matrix column constructors" {
  let source =
    #|fn affine(value: mat3x4<f32>) -> mat4x4<f32> {
    #|  return mat4x4<f32>(value[0], value[1], value[2], vec4(0.0, 0.0, 0.0, 1.0));
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let naga_oil = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    naga_oil.contains(
      "return mat4x4<f32>(value[0], value[1], value[2], vec4<f32>(0f, 0f, 0f, 1f));",
    ),
    content="true",
  )
  debug_inspect(
    naga_oil.contains("value[2], vec4(0.0, 0.0, 0.0, 1.0)"),
    content="false",
  )
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

///|
test "naga-oil writer policy folds integer constants in access index context" {
  let source =
    #|const LAYER_BASE: u32 = 0u;
    #|struct Layer {
    #|  roughness: f32,
    #|}
    #|struct Input {
    #|  layers: array<Layer, 2>,
    #|}
    #|fn roughness(input: Input) -> f32 {
    #|  return input.layers[LAYER_BASE].roughness;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let valid = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  let naga_oil = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(valid.contains("input.layers[0].roughness"), content="true")
  debug_inspect(naga_oil.contains("input.layers[0].roughness"), content="true")
  debug_inspect(naga_oil.contains("input.layers[LAYER_BASE]"), content="false")
}
