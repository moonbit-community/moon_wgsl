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
    let declarations = collect_wgsl_source_catalog_declarations_strict(
      source_file.source,
    ) catch {
      error => raise composer_error_from_wgsl_parse_error(error)
    }
    for declaration in declarations {
      catalog_entries.push(
        WgslSourceCatalogEntry(
          source_file.rel_path,
          declaration.name(),
          declaration.generated_start(),
          declaration.generated_end(),
        ),
      )
    }
  }
  catalog_entries.sort_by(compare_wgsl_source_catalog_entries)
  catalog_entries
}

///|
fn push_wgsl_source_origin(
  session : WgslComposeSession,
  generated_symbol_name : String,
  rel_path : String,
  source_symbol_name : String,
  source_start : Int,
  source_end : Int,
) -> Unit {
  if generated_symbol_name == "" || rel_path == "" {
    return
  }
  session.source_origins.push(
    WgslSourceOriginEntry(
      generated_symbol_name, rel_path, source_symbol_name, source_start, source_end,
    ),
  )
}

///|
fn record_wgsl_source_origins_from_source(
  session : WgslComposeSession,
  rel_path : String,
  source : String,
) -> Unit {
  let extraction = extract_wgsl_module_item_origins_strict(source, []) catch {
    _ => return
  }
  for origin in extraction.origins() {
    push_wgsl_source_origin(
      session,
      origin.name(),
      rel_path,
      origin.name(),
      origin.source_start(),
      origin.source_end(),
    )
  }
}

///|
fn record_wgsl_source_origins_from_extraction(
  session : WgslComposeSession,
  rel_path : String,
  extraction : WgslModuleItemExtraction,
) -> Unit {
  for origin in extraction.origins() {
    push_wgsl_source_origin(
      session,
      origin.name(),
      rel_path,
      origin.name(),
      origin.source_start(),
      origin.source_end(),
    )
  }
}

///|
