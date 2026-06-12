///|
test "IR lowerer preserves generated import struct source order before first-use reordering" {
  let source =
    #|struct ImportedA_naga_oil_mod_XABCDX {
    #|  value: u32,
    #|}
    #|
    #|struct ImportedB_naga_oil_mod_XABCDX {
    #|  value: u32,
    #|}
    #|
    #|fn root(value: ImportedB_naga_oil_mod_XABCDX) -> ImportedA_naga_oil_mod_XABCDX {
    #|  var out: ImportedA_naga_oil_mod_XABCDX;
    #|  return out;
    #|}
  let emitted = roundtrip_wgsl_source_via_ir_with_generated_imports_compat_writer(
    source,
    [
      WgslIrGeneratedImportProvenance(
        "ImportedA_naga_oil_mod_XABCDX",
        "imports/types.wgsl",
        "ImportedA",
        ImportedSourceSymbol,
        false,
      ),
      WgslIrGeneratedImportProvenance(
        "ImportedB_naga_oil_mod_XABCDX",
        "imports/types.wgsl",
        "ImportedB",
        ImportedSourceSymbol,
        false,
      ),
    ],
  ) catch {
    error => abort(error.message())
  }
  let imported_a = emitted.find("struct ImportedA_naga_oil_mod_XABCDX")
  let imported_b = emitted.find("struct ImportedB_naga_oil_mod_XABCDX")
  debug_inspect(imported_a != None, content="true")
  debug_inspect(imported_b != None, content="true")
  debug_inspect(
    match (imported_a, imported_b) {
      (Some(a), Some(b)) => a < b
      _ => false
    },
    content="true",
  )
}
