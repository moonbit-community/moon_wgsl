///|
test "IR emitter does not reserve builtin function names for struct members" {
  let source =
    #|struct ContactShadowsSettings {
    #|  linear_steps: u32,
    #|  thickness: f32,
    #|  length: f32,
    #|}
    #|
    #|fn helper(settings: ContactShadowsSettings) -> f32 {
    #|  return settings.length;
    #|}
  let emitted = roundtrip_wgsl_source_via_ir(source) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("    length: f32,"), content="true")
  debug_inspect(emitted.contains("length_: f32"), content="false")
  debug_inspect(emitted.contains("return settings.length;"), content="true")
}

///|
test "naga-oil writer allocates global names after function locals" {
  let source =
    #|@group(0) @binding(0) var<uniform> material: vec4<f32>;
    #|
    #|fn helper() -> vec4<f32> {
    #|  var material = vec4<f32>(1.0);
    #|  return material;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("var<uniform> material_1: vec4<f32>;"),
    content="true",
  )
  debug_inspect(emitted.contains("var material: vec4<f32> ="), content="true")
}
