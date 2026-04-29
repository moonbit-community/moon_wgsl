///|
pub fn rewrite_wgsl_symbol_redirects(
  source : String,
  redirects : Array[WgslSymbolRedirect],
) -> String {
  @analysis.rewrite_wgsl_symbol_redirects(source, redirects)
}

///|
pub fn build_registered_wgsl_source_catalog(
  defines : @hashmap.HashMap[String, Bool],
  value_defines : @hashmap.HashMap[String, Int],
) -> Array[WgslSourceCatalogEntry] {
  @export.build_registered_wgsl_source_catalog(defines, value_defines)
}

///|
pub fn build_wgsl_source_catalog(
  composer : Composer,
  options : WgslComposeOptions,
) -> Array[WgslSourceCatalogEntry] {
  @export.build_wgsl_source_catalog(composer, options)
}

///|
pub fn export_wgsl_with_options(
  composer : Composer,
  rel : String,
  compose_options : WgslComposeOptions,
  export_options : WgslExportOptions,
) -> WgslExportOutput raise ComposerError {
  @export.export_wgsl_with_options(
    composer, rel, compose_options, export_options,
  )
}

///|
pub fn export_wgsl_from_assets_base_required(
  composer : Composer,
  assets_base : String,
  rel : String,
  options : WgslExportOptions,
) -> WgslExportOutput raise ComposerError {
  @export.export_wgsl_from_assets_base_required(
    composer, assets_base, rel, options,
  )
}

///|
pub fn export_wgsl_from_assets_base_required_with_redirects(
  composer : Composer,
  assets_base : String,
  rel : String,
  options : WgslExportOptions,
  redirects : Array[WgslSymbolRedirect],
) -> WgslExportOutput raise ComposerError {
  @export.export_wgsl_from_assets_base_required_with_redirects(
    composer, assets_base, rel, options, redirects,
  )
}
