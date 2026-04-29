// Copyright 2026 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
fn push_wgsl_diagnostic(
  diagnostics : Array[WgslDiagnostic],
  severity : WgslDiagnosticSeverity,
  message : String,
  rel_path : String?,
  symbol_name : String?,
  generated_start : Int?,
  source_start : Int?,
) -> Unit {
  diagnostics.push(WgslDiagnostic::{
    severity,
    message,
    rel_path,
    symbol_name,
    generated_start,
    source_start,
  })
}

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

///|
pub fn rewrite_wgsl_symbol_redirects(
  source : String,
  redirects : Array[WgslSymbolRedirect],
) -> String {
  @analysis.rewrite_wgsl_symbol_redirects(source, redirects)
}

///|
fn build_wgsl_source_catalog_from_files(
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
    let graph = build_wgsl_declaration_graph(prepared_source)
    for block in graph.declaration_blocks {
      guard block.name != "" else { continue }
      catalog_entries.push(WgslSourceCatalogEntry::{
        rel_path: source_file.rel_path,
        symbol_name: block.name,
        source_text: block.text.trim().to_owned(),
        source_start: block.start,
        source_end: block.end,
      })
    }
  }
  catalog_entries.sort_by(compare_wgsl_source_catalog_entries)
  catalog_entries
}

///|
pub fn build_registered_wgsl_source_catalog(
  defines : @hashmap.HashMap[String, Bool],
  value_defines : @hashmap.HashMap[String, Int],
) -> Array[WgslSourceCatalogEntry] {
  build_wgsl_source_catalog_from_files(
    copy_registered_wgsl_source_files(),
    defines,
    value_defines,
  )
}

///|
pub fn build_wgsl_source_catalog(
  composer : Composer,
  options : WgslComposeOptions,
) -> Array[WgslSourceCatalogEntry] {
  build_wgsl_source_catalog_from_files(
    composer.copy_registered_wgsl_source_files(),
    options.defines,
    options.value_defines,
  )
}

///|
fn build_wgsl_source_catalog_index(
  catalog_entries : Array[WgslSourceCatalogEntry],
) -> @hashmap.HashMap[String, Array[WgslSourceCatalogEntry]] {
  let catalog : @hashmap.HashMap[String, Array[WgslSourceCatalogEntry]] = @hashmap.HashMap::new()
  for entry in catalog_entries {
    if catalog.get(entry.symbol_name) is Some(entries) {
      entries.push(entry)
    } else {
      catalog.set(entry.symbol_name, [entry])
    }
  }
  catalog
}

///|
fn match_wgsl_source_catalog_entry(
  catalog : @hashmap.HashMap[String, Array[WgslSourceCatalogEntry]],
  block : WgslGraphBlock,
  diagnostics : Array[WgslDiagnostic],
  generated_start : Int,
) -> WgslSourceCatalogEntry? {
  guard block.name != "" else { return None }
  guard catalog.get(block.name) is Some(entries) else {
    push_wgsl_diagnostic(
      diagnostics,
      WgslDiagnosticSeverity::Warn,
      "source map entry could not be resolved for declaration",
      None,
      Some(block.name),
      Some(generated_start),
      None,
    )
    return None
  }
  if entries.length() == 1 {
    return Some(entries[0])
  }
  let trimmed_block = block.text.trim().to_owned()
  let exact_matches : Array[WgslSourceCatalogEntry] = []
  for entry in entries {
    if entry.source_text == trimmed_block {
      exact_matches.push(entry)
    }
  }
  if exact_matches.length() == 1 {
    return Some(exact_matches[0])
  }
  push_wgsl_diagnostic(
    diagnostics,
    WgslDiagnosticSeverity::Warn,
    "source map entry is ambiguous for declaration",
    None,
    Some(block.name),
    Some(generated_start),
    None,
  )
  None
}

///|
fn serialize_wgsl_export_output(
  graph : WgslDeclarationGraph,
  source_files : Array[WgslSourceFile],
  options : WgslExportOptions,
  defines : @hashmap.HashMap[String, Bool],
  value_defines : @hashmap.HashMap[String, Int],
) -> WgslExportOutput {
  let diagnostics : Array[WgslDiagnostic] = []
  let (included_names, missing_root_items) = collect_wgsl_reachable_declaration_names(
    graph.declaration_blocks,
    options.root_items,
  )
  for missing_root in missing_root_items {
    push_wgsl_diagnostic(
      diagnostics,
      WgslDiagnosticSeverity::Warn,
      "tree-shake root item was not found in the composed WGSL",
      None,
      Some(missing_root),
      None,
      None,
    )
  }
  let source_catalog = build_wgsl_source_catalog_from_files(
    source_files, defines, value_defines,
  )
  let catalog = build_wgsl_source_catalog_index(source_catalog)
  let source_map : Array[WgslSourceMapEntry] = []
  let mut source = ""
  let mut generated_start = 0

  for import_block in graph.import_blocks {
    source = source + import_block.text
    generated_start = generated_start + import_block.text.length()
  }
  for block in graph.declaration_blocks {
    if block.name != "" && !included_names.contains(block.name) {
      continue
    }
    let block_generated_start = generated_start
    source = source + block.text
    generated_start = generated_start + block.text.length()
    if match_wgsl_source_catalog_entry(
        catalog, block, diagnostics, block_generated_start,
      )
      is Some(entry) {
      source_map.push(WgslSourceMapEntry::{
        generated_start: block_generated_start,
        generated_end: generated_start,
        rel_path: entry.rel_path,
        source_start: entry.source_start,
        source_end: entry.source_end,
        symbol_name: Some(entry.symbol_name),
      })
    }
  }

  WgslExportOutput::{ source, source_catalog, source_map, diagnostics }
}

///|
fn append_wgsl_unused_redirect_diagnostics(
  diagnostics : Array[WgslDiagnostic],
  session : WgslComposeSession,
) -> Unit {
  for redirect in session.redirects {
    let from_name = redirect.from_name.trim().to_owned()
    let to_name = redirect.to_name.trim().to_owned()
    if from_name == "" || to_name == "" || from_name == to_name {
      continue
    }
    let matched = match session.redirect_match_counts.get(from_name) {
      Some(count) => count > 0
      None => false
    }
    if !matched {
      push_wgsl_diagnostic(
        diagnostics,
        WgslDiagnosticSeverity::Warn,
        "symbol redirect did not match any source identifier",
        None,
        Some(from_name),
        None,
        None,
      )
    }
  }
}

///|
fn export_wgsl_from_session(
  composer : Composer,
  rel : String,
  session : WgslComposeSession,
  options : WgslExportOptions,
) -> WgslExportOutput raise ComposerError {
  let source = composer.load_root_wgsl_preprocessed_into_session(rel, session)
  let source = finalize_wgsl_writeback_source(source)
  let graph = build_wgsl_declaration_graph(source)
  let output = serialize_wgsl_export_output(
    graph,
    copy_wgsl_source_files_from_registry(session.resolved_source_files),
    options,
    session.defines,
    session.value_defines,
  )
  append_wgsl_unused_redirect_diagnostics(output.diagnostics, session)
  output
}

///|
pub fn export_wgsl_with_options(
  composer : Composer,
  rel : String,
  compose_options : WgslComposeOptions,
  export_options : WgslExportOptions,
) -> WgslExportOutput raise ComposerError {
  let session = composer.new_wgsl_compose_session(compose_options)
  export_wgsl_from_session(composer, rel, session, export_options)
}

///|
pub fn export_wgsl_from_assets_base_required(
  composer : Composer,
  assets_base : String,
  rel : String,
  options : WgslExportOptions,
) -> WgslExportOutput raise ComposerError {
  export_wgsl_from_assets_base_required_with_redirects(
    composer,
    assets_base,
    rel,
    options,
    [],
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
  let base = assets_base.trim().to_owned()
  if base == "" {
    raise ComposerError::EmptyAssetsBase(rel)
  }
  export_wgsl_with_options(
    composer,
    rel,
    WgslComposeOptions::{
      assets_base: base,
      defines: @hashmap.HashMap::new(),
      value_defines: default_wgsl_value_defines(),
      redirects,
      additional_imports: [],
    },
    options,
  )
}
