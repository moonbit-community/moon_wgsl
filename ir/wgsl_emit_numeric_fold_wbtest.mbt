///|
test "naga-oil writer policy folds pure literal float expressions in constructor context" {
  let source =
    #|fn specular_occlusion(color: vec3<f32>) -> f32 {
    #|  return dot(color, vec3<f32>(50.0 * 0.33));
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let naga_oil = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(naga_oil.contains("16.5f"), content="true")
  debug_inspect(naga_oil.contains("50f * 0.33f"), content="false")
}

///|
test "naga-oil writer policy folds typed constant binary operands" {
  let source =
    #|const PI: f32 = 3.1415927;
    #|
    #|fn scale(value: f32) -> f32 {
    #|  return value * (1.0 / PI);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let naga_oil = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(naga_oil.contains("0.31830987f"), content="true")
  debug_inspect(naga_oil.contains("1f / PI"), content="false")
}

///|
test "naga-oil writer policy folds retained generated import scalar constants" {
  let source =
    #|const PIX_naga_oil_mod_XABCDX: f32 = 3.1415927;
    #|
    #|fn scale(value: f32) -> f32 {
    #|  return value * (1.0 / PIX_naga_oil_mod_XABCDX);
    #|}
  let module_ = parse_wgsl_module_to_ir_with_generated_imports(source, [
    WgslIrGeneratedImportProvenance(
      "PIX_naga_oil_mod_XABCDX",
      "imports/math.wgsl",
      "PI",
      WgslIrGeneratedImportProvenanceKind::ImportedSourceSymbol,
      false,
    ),
  ]) catch {
    error => abort(error.message())
  }
  let naga_oil = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(naga_oil.contains("0.31830987f"), content="true")
  debug_inspect(naga_oil.contains("1f / PIX"), content="false")
}

///|
test "naga-oil writer policy retains direct generated import scalar constant operands" {
  let source =
    #|const PIX_naga_oil_mod_XABCDX: f32 = 3.1415927;
    #|
    #|fn wrap(value: f32) -> f32 {
    #|  return PIX_naga_oil_mod_XABCDX - value;
    #|}
  let module_ = parse_wgsl_module_to_ir_with_generated_imports(source, [
    WgslIrGeneratedImportProvenance(
      "PIX_naga_oil_mod_XABCDX",
      "imports/math.wgsl",
      "PI",
      WgslIrGeneratedImportProvenanceKind::ImportedSourceSymbol,
      false,
    ),
  ]) catch {
    error => abort(error.message())
  }
  let naga_oil = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    naga_oil.contains("(PIX_naga_oil_mod_XABCDX - value)"),
    content="true",
  )
  debug_inspect(naga_oil.contains("(3.1415927f - value)"), content="false")
}
