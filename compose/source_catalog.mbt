///|
fn compare_wgsl_source_catalog_entries(
  lhs : WgslSourceCatalogEntry,
  rhs : WgslSourceCatalogEntry,
) -> Int {
  let rel_path_compare = String::compare(lhs.rel_path, rhs.rel_path)
  if rel_path_compare != 0 {
    return rel_path_compare
  }
  let source_start_compare = lhs.source_start - rhs.source_start
  if source_start_compare != 0 {
    return source_start_compare
  }
  let source_end_compare = lhs.source_end - rhs.source_end
  if source_end_compare != 0 {
    return source_end_compare
  }
  String::compare(lhs.symbol_name, rhs.symbol_name)
}

///|
fn build_prepared_wgsl_source_catalog(
  source_files : Array[WgslSourceFile],
  defines : @hashmap.HashMap[String, Bool],
  value_defines : @hashmap.HashMap[String, Int],
) -> Array[WgslSourceCatalogEntry] {
  source_files.sort_by((lhs, rhs) => String::compare(lhs.rel_path, rhs.rel_path))

  let catalog_entries : Array[WgslSourceCatalogEntry] = []
  for source_file in source_files {
    let prepared_source = strip_wgsl_import_declarations(
      apply_wgsl_template_consts(
        apply_wgsl_ifdefs(source_file.source, defines, value_defines),
        value_defines,
      ),
    )
    for declaration in collect_wgsl_named_declarations(prepared_source) {
      catalog_entries.push(WgslSourceCatalogEntry::{
        rel_path: source_file.rel_path,
        symbol_name: declaration.name,
        source_text: declaration.text.trim().to_owned(),
        source_start: declaration.generated_start,
        source_end: declaration.generated_end,
      })
    }
  }
  catalog_entries.sort_by(compare_wgsl_source_catalog_entries)
  catalog_entries
}
