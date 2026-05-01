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
fn export_composer_error_from_wgsl_parse_error(
  error : WgslParseError,
) -> ComposerError {
  match error {
    Parse(message, offset) => ComposerError::InvalidWgslSyntax(message, offset)
    UnparsedDeclaration(text, offset) =>
      ComposerError::InvalidWgslSyntax(
        "declaration could not be parsed: \{text}",
        offset,
      )
  }
}

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
  declaration : WgslEmittedDeclaration,
  diagnostics : Array[WgslDiagnostic],
) -> WgslSourceCatalogEntry? {
  guard catalog.get(declaration.name) is Some(entries) else {
    push_wgsl_diagnostic(
      diagnostics,
      WgslDiagnosticSeverity::Warn,
      "source map entry could not be resolved for declaration",
      None,
      Some(declaration.name),
      Some(declaration.generated_start),
      None,
    )
    return None
  }
  if entries.length() == 1 {
    return Some(entries[0])
  }
  let trimmed_block = declaration.text.trim().to_owned()
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
    Some(declaration.name),
    Some(declaration.generated_start),
    None,
  )
  None
}

///|
fn serialize_wgsl_export_output(
  tree_shaken : WgslTreeShakenSource,
  source_catalog : Array[WgslSourceCatalogEntry],
) -> WgslExportOutput {
  let diagnostics : Array[WgslDiagnostic] = []
  for missing_root in tree_shaken.missing_root_items {
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

  for declaration in tree_shaken.declarations {
    if match_wgsl_source_catalog_entry(catalog, declaration, diagnostics)
      is Some(entry) {
      source_map.push(WgslSourceMapEntry::{
        generated_start: declaration.generated_start,
        generated_end: declaration.generated_end,
        rel_path: entry.rel_path,
        source_start: entry.source_start,
        source_end: entry.source_end,
        symbol_name: Some(declaration.name),
      })
    }
  }

  WgslExportOutput::{
    source: tree_shaken.source,
    source_catalog,
    source_map,
    diagnostics,
  }
}

///|
pub fn export_wgsl_with_options(
  composer : Composer,
  rel : String,
  compose_options : WgslComposeOptions,
  export_options : WgslExportOptions,
) -> WgslExportOutput raise ComposerError {
  let prepared = composer.prepare_wgsl_source(rel, compose_options)
  let tree_shaken = emit_wgsl_tree_shaken_source_strict(
    prepared.source,
    export_options.root_items,
  ) catch {
    error => raise export_composer_error_from_wgsl_parse_error(error)
  }
  let output = serialize_wgsl_export_output(
    tree_shaken,
    prepared.source_catalog,
  )
  for diagnostic in prepared.diagnostics {
    output.diagnostics.push(diagnostic)
  }
  output
}
