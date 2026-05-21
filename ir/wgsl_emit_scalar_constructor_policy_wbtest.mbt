///|
test "naga-oil writer policy folds scalar float constructors from integer literals" {
  let source =
    #|fn pack(depth: f32, alpha: f32) -> u32 {
    #|  let depth_bits = u32(saturate(depth) * f32(0xFFFFFFu) + 0.5);
    #|  let alpha_bits = u32(saturate(alpha) * f32(0xFFu) + 0.5);
    #|  return (depth_bits << 8u) | alpha_bits;
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
  debug_inspect(valid.contains("f32(16777215u)"), content="true")
  debug_inspect(
    naga_oil.contains("saturate(depth) * 16777215f"),
    content="true",
  )
  debug_inspect(naga_oil.contains("saturate(alpha) * 255f"), content="true")
  debug_inspect(naga_oil.contains("f32(16777215u)"), content="false")
}

///|
test "naga-oil writer policy folds scalar constructors from retained constants" {
  let source =
    #|const SAMPLES: i32 = 4;
    #|fn step_size(start: f32, end: f32) -> f32 {
    #|  return (end - start) / f32(SAMPLES);
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
  debug_inspect(valid.contains("f32(SAMPLES)"), content="true")
  debug_inspect(naga_oil.contains("f32(SAMPLES)"), content="false")
  debug_inspect(naga_oil.contains("(end - start) / 4f"), content="true")
  debug_inspect(naga_oil.contains("const SAMPLES: i32 = 4i;"), content="true")
}

///|
test "naga-oil writer policy keeps parent expressions around normalized local constants" {
  let source =
    #|fn neutral(max_channel: f32) -> f32 {
    #|  const start_compression: f32 = 0.8 - 0.04;
    #|  let d = 1.0 - start_compression;
    #|  return 1.0 - d * d / (max_channel + d - start_compression);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let naga_oil = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(naga_oil.contains("0.24f * 0.24f"), content="true")
  debug_inspect(naga_oil.contains("0.0576f"), content="false")
}

///|
test "naga-oil writer policy emits unsigned bit masks in u32 context" {
  let source =
    #|fn copysign(a: f32, b: f32) -> f32 {
    #|  return bitcast<f32>((bitcast<u32>(a) & 0x7FFFFFFF) | (bitcast<u32>(b) & 0x80000000));
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let naga_oil = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(naga_oil.contains("2147483647u"), content="true")
  debug_inspect(naga_oil.contains("2147483648u"), content="true")
}

///|
test "naga-oil writer policy contextualizes integer constructor literals" {
  let source =
    #|const MASK: vec4<u32> = vec4<u32>(167905280, 101581836, 151063299, 84739855);
    #|const OFFSET: vec2<i32> = vec2<i32>(1, 0);
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let naga_oil = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    naga_oil.contains("vec4<u32>(167905280u, 101581836u"),
    content="true",
  )
  debug_inspect(naga_oil.contains("vec2<i32>(1i, 0i)"), content="true")
}

///|
test "naga-oil writer policy contextualizes scalar call literals" {
  let source =
    #|fn pick(flag: bool) -> f32 {
    #|  return select(1.0, -1, flag);
    #|}
    #|fn passthrough(value: f32) -> f32 {
    #|  return value;
    #|}
    #|fn call_arg() -> f32 {
    #|  return passthrough(-1);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let naga_oil = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(naga_oil.contains("select(1f, -1f, flag)"), content="true")
  debug_inspect(naga_oil.contains("passthrough(-1f)"), content="true")
}
