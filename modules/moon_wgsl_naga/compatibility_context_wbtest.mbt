///|
fn wgsl_naga_test_parse_with_generated_imports(
  source : String,
  generated_import_provenance : Array[WgslNagaGeneratedImportProvenance],
) -> (Module, WgslNagaCompatibilityView) raise WgslIrLowerError {
  let context = WgslNagaComposeContext::from_import_graph(
    generated_import_provenance,
    [],
  )
  (
    parse_wgsl_module_to_ir(source),
    WgslNagaCompatibilityView::from_context(context),
  )
}

///|
fn wgsl_naga_test_parse_with_import_graph(
  source : String,
  generated_import_provenance : Array[WgslNagaGeneratedImportProvenance],
  import_arena_events : Array[WgslNagaImportArenaEvent],
  root_visible_rel_path? : String = "",
) -> (Module, WgslNagaCompatibilityView) raise WgslIrLowerError {
  let context = WgslNagaComposeContext::from_import_graph(
    generated_import_provenance,
    import_arena_events,
    root_visible_rel_path~,
  )
  (
    parse_wgsl_module_to_ir(source),
    WgslNagaCompatibilityView::from_context(context),
  )
}
