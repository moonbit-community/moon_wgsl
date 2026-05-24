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
