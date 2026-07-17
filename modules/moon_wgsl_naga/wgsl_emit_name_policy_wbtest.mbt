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
test "naga-oil writer applies root visible import spelling to struct members" {
  let source =
    #|struct Material {
    #|  value: u32,
    #|}
    #|
    #|struct ImportedInputX_naga_oil_mod_IMPORT {
    #|  material: u32,
    #|}
    #|
    #|@group(0) @binding(0)
    #|var<uniform> materialX_naga_oil_mod_IMPORT: Material;
    #|
    #|struct RootData {
    #|  material: u32,
    #|}
    #|
    #|fn read(input: RootData) -> u32 {
    #|  return input.material + materialX_naga_oil_mod_IMPORT.value;
    #|}
  let (module_, compatibility) = wgsl_naga_test_parse_with_generated_imports(
    source,
    [
      WgslNagaGeneratedImportProvenance(
        "ImportedInputX_naga_oil_mod_IMPORT",
        "types.wgsl",
        "ImportedInput",
        ImportedSourceSymbol,
        false,
      ),
      WgslNagaGeneratedImportProvenance(
        "materialX_naga_oil_mod_IMPORT",
        "bindings.wgsl",
        "material",
        ImportedSourceSymbol,
        false,
        root_local_spelling=true,
      ),
    ],
  ) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir_compat_writer(module_, compatibility~) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("    materialX_naga_oil_mod_IMPORT: u32,"),
    content="true",
  )
  debug_inspect(
    emitted.contains(
      (
        #|struct ImportedInputX_naga_oil_mod_IMPORT {
        #|    material: u32,
      ),
    ),
    content="true",
  )
  debug_inspect(
    emitted.contains("input.materialX_naga_oil_mod_IMPORT"),
    content="true",
  )
  debug_inspect(
    emitted.contains("materialX_naga_oil_mod_IMPORT.value"),
    content="true",
  )
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
  let emitted = emit_wgsl_module_from_ir_compat_writer(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("var<uniform> material_1: vec4<f32>;"),
    content="true",
  )
  debug_inspect(emitted.contains("var material: vec4<f32> ="), content="true")
}
