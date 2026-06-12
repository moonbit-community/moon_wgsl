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
    UnparsedDeclaration(text, offset) =>
      InvalidWgslSyntax("declaration could not be parsed: \{text}", offset)
  }
}

///|
fn push_wgsl_diagnostic(
  diagnostics : Array[WgslDiagnostic],
  severity : WgslDiagnosticSeverity,
  message : String,
  rel_path : String?,
  symbol_name : String?,
) -> Unit {
  diagnostics.push(WgslDiagnostic(severity, message, rel_path, symbol_name))
}

///|
fn build_wgsl_source_catalog_index(
  catalog_entries : Array[WgslSourceCatalogEntry],
) -> Map[String, Array[WgslSourceCatalogEntry]] {
  let catalog : Map[String, Array[WgslSourceCatalogEntry]] = Map([])
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
fn build_wgsl_source_origin_index(
  origin_entries : Array[WgslSourceOriginEntry],
) -> Map[String, Array[WgslSourceOriginEntry]] {
  let origins : Map[String, Array[WgslSourceOriginEntry]] = Map([])
  for entry in origin_entries {
    if origins.get(entry.generated_symbol_name) is Some(entries) {
      entries.push(entry)
    } else {
      origins.set(entry.generated_symbol_name, [entry])
    }
  }
  origins
}

///|
fn match_wgsl_source_catalog_entry(
  catalog : Map[String, Array[WgslSourceCatalogEntry]],
  declaration : WgslEmittedDeclaration,
  diagnostics : Array[WgslDiagnostic],
) -> WgslSourceCatalogEntry? {
  guard catalog.get(declaration.name()) is Some(entries) else {
    push_wgsl_diagnostic(
      diagnostics,
      Warn,
      "source map entry could not be resolved for declaration",
      None,
      Some(declaration.name()),
    )
    return None
  }
  if entries.length() == 1 {
    return Some(entries[0])
  }
  let span_matches : Array[WgslSourceCatalogEntry] = []
  for entry in entries {
    if entry.source_start == declaration.generated_start() &&
      entry.source_end == declaration.generated_end() {
      span_matches.push(entry)
    }
  }
  if span_matches.length() == 1 {
    return Some(span_matches[0])
  }
  push_wgsl_diagnostic(
    diagnostics,
    Warn,
    "source map entry is ambiguous for declaration",
    None,
    Some(declaration.name()),
  )
  None
}

///|
fn match_wgsl_source_origin_entry(
  origins : Map[String, Array[WgslSourceOriginEntry]],
  declaration : WgslEmittedDeclaration,
  diagnostics : Array[WgslDiagnostic],
) -> WgslSourceOriginEntry? {
  guard origins.get(declaration.name()) is Some(entries) else {
    push_wgsl_diagnostic(
      diagnostics,
      Warn,
      "source origin entry could not be resolved for declaration",
      None,
      Some(declaration.name()),
    )
    return None
  }
  if entries.length() == 1 {
    return Some(entries[0])
  }
  push_wgsl_diagnostic(
    diagnostics,
    Warn,
    "source origin entry is ambiguous for declaration",
    None,
    Some(declaration.name()),
  )
  None
}

///|
fn serialize_wgsl_export_output(
  source : String,
  declarations : Array[WgslEmittedDeclaration],
  missing_root_items : Array[String],
  source_catalog : Array[WgslSourceCatalogEntry],
  source_origins : Array[WgslSourceOriginEntry],
) -> WgslExportOutput {
  let diagnostics : Array[WgslDiagnostic] = []
  for missing_root in missing_root_items {
    push_wgsl_diagnostic(
      diagnostics,
      Warn,
      "tree-shake root item was not found in the composed WGSL",
      None,
      Some(missing_root),
    )
  }
  let catalog = build_wgsl_source_catalog_index(source_catalog)
  let origins = build_wgsl_source_origin_index(source_origins)
  let source_map : Array[WgslSourceMapEntry] = []

  for declaration in declarations {
    if match_wgsl_source_origin_entry(origins, declaration, diagnostics)
      is Some(origin) {
      source_map.push(
        WgslSourceMapEntry(origin.rel_path, Some(origin.source_symbol_name)),
      )
    } else if match_wgsl_source_catalog_entry(catalog, declaration, diagnostics)
      is Some(entry) {
      source_map.push(
        WgslSourceMapEntry(entry.rel_path, Some(declaration.name())),
      )
    }
  }

  WgslExportOutput(
    source, source_catalog, source_origins, source_map, diagnostics,
  )
}

///|
fn collect_missing_wgsl_export_roots(
  declarations : Array[WgslEmittedDeclaration],
  root_items : Array[String],
) -> Array[String] {
  let declared : @set.Set[String] = Set([])
  for declaration in declarations {
    declared.add(declaration.name())
  }
  let missing : Array[String] = []
  for root in root_items {
    if !declared.contains(root) {
      missing.push(root)
    }
  }
  missing
}

///|
pub fn export_wgsl_with_options(
  composer : Composer,
  rel : String,
  compose_options : WgslComposeOptions,
  export_options : WgslExportOptions,
) -> WgslExportOutput raise ComposerError {
  let prepared = composer.prepare_wgsl_source(rel, compose_options)
  let tree_shaken_source = tree_shake_wgsl_source_via_ir(
    prepared.source,
    export_options.root_items,
  ) catch {
    error => raise InvalidIr(error.message())
  }
  let declarations = collect_wgsl_named_declarations_strict(tree_shaken_source) catch {
    error => raise export_composer_error_from_wgsl_parse_error(error)
  }
  let output = serialize_wgsl_export_output(
    tree_shaken_source,
    declarations,
    collect_missing_wgsl_export_roots(declarations, export_options.root_items),
    prepared.source_catalog,
    prepared.source_origins,
  )
  for diagnostic in prepared.diagnostics {
    output.diagnostics.push(diagnostic)
  }
  output
}
