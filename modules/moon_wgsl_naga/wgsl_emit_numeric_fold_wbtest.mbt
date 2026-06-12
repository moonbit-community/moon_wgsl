///|
test "naga-oil writer policy folds pure literal float expressions in constructor context" {
  let source =
    #|fn specular_occlusion(color: vec3<f32>) -> f32 {
    #|  return dot(color, vec3<f32>(50.0 * 0.33));
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let naga_oil = emit_wgsl_module_from_ir_compat_writer(module_) catch {
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
  let naga_oil = emit_wgsl_module_from_ir_compat_writer(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(naga_oil.contains("0.31830987f"), content="true")
  debug_inspect(naga_oil.contains("1f / PI"), content="false")
}

///|
test "naga-oil writer policy folds pure literal binary operands" {
  let source =
    #|fn w(a: f32) -> f32 {
    #|  return (1.0 / 6.0) * ((a * a) * a);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let naga_oil = emit_wgsl_module_from_ir_compat_writer(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(naga_oil.contains("0.16666667f"), content="true")
  debug_inspect(naga_oil.contains("1f / 6f"), content="false")
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
      ImportedSourceSymbol,
      false,
    ),
  ]) catch {
    error => abort(error.message())
  }
  let naga_oil = emit_wgsl_module_from_ir_compat_writer(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(naga_oil.contains("0.31830987f"), content="true")
  debug_inspect(naga_oil.contains("1f / PIX"), content="false")
}

///|
test "naga-oil writer policy folds generated import scalar constant literal denominators" {
  let source =
    #|const PIX_naga_oil_mod_XABCDX: f32 = 3.1415927;
    #|
    #|fn scale(value: f32) -> f32 {
    #|  return (PIX_naga_oil_mod_XABCDX / 4.0) * value;
    #|}
  let module_ = parse_wgsl_module_to_ir_with_generated_imports(source, [
    WgslIrGeneratedImportProvenance(
      "PIX_naga_oil_mod_XABCDX",
      "imports/math.wgsl",
      "PI",
      ImportedSourceSymbol,
      false,
    ),
  ]) catch {
    error => abort(error.message())
  }
  let naga_oil = emit_wgsl_module_from_ir_compat_writer(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(naga_oil.contains("0.7853982f"), content="true")
  debug_inspect(
    naga_oil.contains("PIX_naga_oil_mod_XABCDX / 4f"),
    content="false",
  )
}

///|
test "naga-oil writer policy retains generated import division by source let denominator" {
  let source =
    #|const PIX_naga_oil_mod_XABCDX: f32 = 3.1415927;
    #|
    #|fn scale(value: f32) -> f32 {
    #|  let slice_count = f32(4);
    #|  return (PIX_naga_oil_mod_XABCDX / slice_count) * value;
    #|}
  let module_ = parse_wgsl_module_to_ir_with_generated_imports(source, [
    WgslIrGeneratedImportProvenance(
      "PIX_naga_oil_mod_XABCDX",
      "imports/math.wgsl",
      "PI",
      ImportedSourceSymbol,
      false,
    ),
  ]) catch {
    error => abort(error.message())
  }
  let naga_oil = emit_wgsl_module_from_ir_compat_writer(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    naga_oil.contains("((PIX_naga_oil_mod_XABCDX / 4f) * value)"),
    content="true",
  )
  debug_inspect(naga_oil.contains("0.7853982f"), content="false")
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
      ImportedSourceSymbol,
      false,
    ),
  ]) catch {
    error => abort(error.message())
  }
  let naga_oil = emit_wgsl_module_from_ir_compat_writer(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    naga_oil.contains("(PIX_naga_oil_mod_XABCDX - value)"),
    content="true",
  )
  debug_inspect(naga_oil.contains("(3.1415927f - value)"), content="false")
}

///|
test "naga-oil writer policy folds generated import scalar constants in vector splats" {
  let source =
    #|const PIX_naga_oil_mod_XABCDX: f32 = 3.1415927;
    #|
    #|fn ground(value: vec3<f32>) -> vec3<f32> {
    #|  return value / vec3(PIX_naga_oil_mod_XABCDX);
    #|}
  let module_ = parse_wgsl_module_to_ir_with_generated_imports(source, [
    WgslIrGeneratedImportProvenance(
      "PIX_naga_oil_mod_XABCDX",
      "imports/math.wgsl",
      "PI",
      ImportedSourceSymbol,
      false,
    ),
  ]) catch {
    error => abort(error.message())
  }
  let naga_oil = emit_wgsl_module_from_ir_compat_writer(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(naga_oil.contains("vec3(3.1415927f)"), content="true")
  debug_inspect(
    naga_oil.contains("vec3(PIX_naga_oil_mod_XABCDX)"),
    content="false",
  )
}

///|
test "naga-oil writer policy folds generated import scalar constants in vector arithmetic" {
  let source =
    #|const PIX_naga_oil_mod_XABCDX: f32 = 3.1415927;
    #|
    #|fn color(h: f32) -> vec3<f32> {
    #|  return cos(vec3(h) + vec3(0.0, 1.0, 2.0) * PIX_naga_oil_mod_XABCDX * 2.0 / 3.0);
    #|}
  let module_ = parse_wgsl_module_to_ir_with_generated_imports(source, [
    WgslIrGeneratedImportProvenance(
      "PIX_naga_oil_mod_XABCDX",
      "imports/math.wgsl",
      "PI",
      ImportedSourceSymbol,
      false,
    ),
  ]) catch {
    error => abort(error.message())
  }
  let naga_oil = emit_wgsl_module_from_ir_compat_writer(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    naga_oil.contains("vec3<f32>(0f, 2.0943952f, 4.1887903f)"),
    content="true",
  )
  debug_inspect(naga_oil.contains("* PIX_naga_oil_mod_XABCDX"), content="false")
}

///|
test "naga-oil writer follows Naga f32 negative-zero spelling state" {
  let source =
    #|const A: f32 = -0.0000;
    #|const B: f32 = 0.0000;
    #|const C = vec2<f32>(0.1250, 0.0000);
    #|
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let naga_oil = emit_wgsl_module_from_ir_compat_writer(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(naga_oil.contains("const A: f32 = -0f;"), content="true")
  debug_inspect(naga_oil.contains("const B: f32 = -0f;"), content="true")
  debug_inspect(
    naga_oil.contains("const C: vec2<f32> = vec2<f32>(0.125f, -0f);"),
    content="true",
  )
  let runtime = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(runtime.contains("const B: f32 = 0f;"), content="true")
}
