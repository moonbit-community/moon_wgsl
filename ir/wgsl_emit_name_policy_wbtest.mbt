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
