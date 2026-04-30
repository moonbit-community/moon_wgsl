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
pub fn build_wgsl_source_catalog(
  prepared : PreparedWgslSource,
) -> Array[WgslSourceCatalogEntry] {
  prepared.source_catalog.copy()
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
  source_catalog : Array[WgslSourceCatalogEntry],
  options : WgslExportOptions,
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
pub fn export_wgsl_with_options(
  composer : Composer,
  rel : String,
  compose_options : WgslComposeOptions,
  export_options : WgslExportOptions,
) -> WgslExportOutput raise ComposerError {
  let prepared = composer.prepare_wgsl_source(rel, compose_options)
  let graph = build_wgsl_declaration_graph(prepared.source)
  let output = serialize_wgsl_export_output(
    graph,
    prepared.source_catalog,
    export_options,
  )
  for diagnostic in prepared.diagnostics {
    output.diagnostics.push(diagnostic)
  }
  output
}
