///|
test "naga-oil writer policy absorbs implicit void return into complete switch cases" {
  let source =
    #|fn store(mip: u32) {
    #|  switch mip {
    #|    case 0u: {
    #|      workgroupBarrier();
    #|    }
    #|    default: {
    #|    }
    #|  }
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains(
      "case 0u: {\n            workgroupBarrier();\n            return;\n        }",
    ),
    content="true",
  )
  debug_inspect(
    emitted.contains("default: {\n            return;\n        }"),
    content="true",
  )
  debug_inspect(emitted.contains("}\n    return;\n}"), content="false")
}

///|
test "naga-oil writer policy preserves explicit return after switch" {
  let source =
    #|fn store(mip: u32) {
    #|  switch mip {
    #|    case 0u: {
    #|      workgroupBarrier();
    #|    }
    #|    default: {
    #|    }
    #|  }
    #|  return;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("case 0u: {\n            workgroupBarrier();\n        }"),
    content="true",
  )
  debug_inspect(emitted.contains("}\n    return;\n}"), content="true")
}

///|
test "naga-oil writer policy keeps source abstract-int switch labels" {
  let source =
    #|fn choose(value: i32) -> i32 {
    #|  var result: i32 = 0;
    #|  switch value & 7 {
    #|    case 0: {
    #|      result = 1;
    #|    }
    #|    default {
    #|      result = 2;
    #|    }
    #|  }
    #|  return result;
    #|}
  let emitted = roundtrip_wgsl_source_via_ir_with_generated_imports_naga_oil_writer_compatible(
    source,
    [],
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("case 0: {"), content="true")
  debug_inspect(emitted.contains("case 0i: {"), content="false")
}

///|
test "naga-oil writer policy materializes mutable switch selector loads" {
  let source =
    #|fn choose() -> i32 {
    #|  var i: i32 = 0;
    #|  var result: i32 = 0;
    #|  switch i & 7 {
    #|    case 0: {
    #|      result = 1;
    #|    }
    #|    default {
    #|      result = 2;
    #|    }
    #|  }
    #|  return result;
    #|}
  let emitted = roundtrip_wgsl_source_via_ir_with_generated_imports_naga_oil_writer_compatible(
    source,
    [],
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains(": i32 = i;\n    switch (_e"), content="true")
  debug_inspect(emitted.contains("switch (i & 7i)"), content="false")
  debug_inspect(emitted.contains("case 0: {"), content="true")
}

///|
test "naga-oil writer policy absorbs implicit void return into if branches" {
  let source =
    #|fn store(mip: u32) {
    #|  if mip == 0u {
    #|    workgroupBarrier();
    #|  }
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains(
      "if (mip == 0u) {\n        workgroupBarrier();\n        return;\n    } else {\n        return;\n    }",
    ),
    content="true",
  )
  debug_inspect(emitted.contains("}\n    return;\n}"), content="false")
}

///|
test "naga-oil writer policy preserves explicit return after if" {
  let source =
    #|fn store(mip: u32) {
    #|  if mip == 0u {
    #|    workgroupBarrier();
    #|  }
    #|  return;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("if (mip == 0u) {\n        workgroupBarrier();\n    }"),
    content="true",
  )
  debug_inspect(emitted.contains("}\n    return;\n}"), content="true")
}

///|
test "naga-oil writer policy absorbs function-tail implicit return into nested if branches" {
  let source =
    #|fn store(mip: u32, flag: bool) {
    #|  if mip == 0u {
    #|    if flag {
    #|      workgroupBarrier();
    #|    }
    #|  } else {
    #|    storageBarrier();
    #|  }
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains(
      "if flag {\n            workgroupBarrier();\n            return;\n        } else {\n            return;\n        }",
    ),
    content="true",
  )
  debug_inspect(
    emitted.contains(
      "} else {\n        storageBarrier();\n        return;\n    }",
    ),
    content="true",
  )
  debug_inspect(emitted.contains("}\n    return;\n}"), content="false")
}
