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
) -> Array[WgslSourceCatalogEntry] raise ComposerError {
  source_files.sort_by((lhs, rhs) => String::compare(lhs.rel_path, rhs.rel_path))

  let catalog_entries : Array[WgslSourceCatalogEntry] = []
  for source_file in source_files {
    let prepared_source = strip_wgsl_import_declarations_strict(
      source_file.source,
    ) catch {
      error => raise composer_error_from_wgsl_parse_error(error)
    }
    let declarations = collect_wgsl_named_declarations_strict(prepared_source) catch {
      error => raise composer_error_from_wgsl_parse_error(error)
    }
    for declaration in declarations {
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
