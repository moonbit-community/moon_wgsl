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
fn wgsl_redirect_declaration_keyword(ident : String) -> Bool {
  ident == "fn" ||
  ident == "struct" ||
  ident == "const" ||
  ident == "override" ||
  ident == "alias" ||
  ident == "var" ||
  ident == "let"
}

///|
fn build_wgsl_symbol_redirect_map(
  redirects : Array[WgslSymbolRedirect],
) -> @hashmap.HashMap[String, String] {
  let redirect_map : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
  for redirect in redirects {
    let from_name = redirect.from_name.trim().to_string()
    let to_name = redirect.to_name.trim().to_string()
    if from_name == "" || to_name == "" || from_name == to_name {
      continue
    }
    redirect_map.set(from_name, to_name)
  }
  redirect_map
}

///|
fn wgsl_identifier_is_reserved_or_invalid(ident : String) -> Bool {
  if ident == "" {
    return false
  }
  ident == "alias" ||
  ident == "break" ||
  ident == "case" ||
  ident == "const" ||
  ident == "const_assert" ||
  ident == "continue" ||
  ident == "continuing" ||
  ident == "default" ||
  ident == "diagnostic" ||
  ident == "discard" ||
  ident == "else" ||
  ident == "enable" ||
  ident == "false" ||
  ident == "fn" ||
  ident == "for" ||
  ident == "if" ||
  ident == "let" ||
  ident == "loop" ||
  ident == "override" ||
  ident == "requires" ||
  ident == "return" ||
  ident == "struct" ||
  ident == "switch" ||
  ident == "true" ||
  ident == "var" ||
  ident == "while" ||
  ident == "in" ||
  ident.has_suffix("_") ||
  starts_with_text(ident, "__")
}

///|
fn sanitize_wgsl_identifier(ident : String) -> String {
  let mut out = ident
  while out.has_suffix("_") {
    out = out[:out.length() - 1].to_string()
  }
  while starts_with_text(out, "__") {
    out = out[1:out.length()].to_string()
  }
  if out == "" {
    out = "wgsl"
  }
  if wgsl_identifier_is_reserved_or_invalid(out) {
    out = "\{out}_wgsl"
  }
  out
}

///|
fn wgsl_redirect_map_set_sanitized(
  redirect_map : @hashmap.HashMap[String, String],
  ident : String,
) -> Unit {
  if wgsl_identifier_is_reserved_or_invalid(ident) {
    let sanitized = sanitize_wgsl_identifier(ident)
    if sanitized != ident {
      redirect_map.set(ident, sanitized)
    }
  }
}

///|
fn rewrite_wgsl_declaration_text_with_map(
  source : String,
  redirect_map : @hashmap.HashMap[String, String],
  rewrite_declaration_names : Bool,
) -> String {
  let mut output = ""
  let mut i = 0
  let mut in_substitution_position = true
  let mut in_line_comment = false
  let mut in_string = false
  let mut block_comment_depth = 0
  let mut pending_declaration_name = false
  let mut pending_template_depth = 0

  while i < source.length() {
    let code = source.code_unit_at(i).to_int()
    if in_line_comment {
      output = output + code_unit_to_string(code)
      i = i + 1
      if code == 10 {
        in_line_comment = false
        in_substitution_position = true
      }
      continue
    }
    if block_comment_depth > 0 {
      if code == 47 &&
        i + 1 < source.length() &&
        source.code_unit_at(i + 1).to_int() == 42 {
        output = output + source[i:i + 2].to_string()
        block_comment_depth = block_comment_depth + 1
        i = i + 2
        continue
      }
      if code == 42 &&
        i + 1 < source.length() &&
        source.code_unit_at(i + 1).to_int() == 47 {
        output = output + source[i:i + 2].to_string()
        block_comment_depth = block_comment_depth - 1
        i = i + 2
        continue
      }
      output = output + code_unit_to_string(code)
      i = i + 1
      continue
    }
    if in_string {
      if code == 92 && i + 1 < source.length() {
        output = output + source[i:i + 2].to_string()
        i = i + 2
        continue
      }
      output = output + code_unit_to_string(code)
      i = i + 1
      if code == 34 {
        in_string = false
        in_substitution_position = true
      }
      continue
    }
    if code == 47 &&
      i + 1 < source.length() &&
      source.code_unit_at(i + 1).to_int() == 47 {
      output = output + source[i:i + 2].to_string()
      in_line_comment = true
      i = i + 2
      continue
    }
    if code == 47 &&
      i + 1 < source.length() &&
      source.code_unit_at(i + 1).to_int() == 42 {
      output = output + source[i:i + 2].to_string()
      block_comment_depth = 1
      i = i + 2
      continue
    }
    if code == 34 {
      output = output + code_unit_to_string(code)
      in_string = true
      i = i + 1
      continue
    }
    if tokenizer_identifier_start(code) {
      let start = i
      i = i + 1
      while i < source.length() {
        let next_code = source.code_unit_at(i).to_int()
        if tokenizer_identifier_continue(next_code) {
          i = i + 1
          continue
        }
        if next_code == 58 &&
          i + 1 < source.length() &&
          source.code_unit_at(i + 1).to_int() == 58 {
          i = i + 2
          continue
        }
        break
      }
      let ident = source[start:i].to_string()
      if pending_declaration_name && pending_template_depth == 0 {
        if rewrite_declaration_names {
          match redirect_map.get(ident) {
            Some(rewritten_ident) => output = output + rewritten_ident
            None => output = output + ident
          }
        } else {
          output = output + ident
        }
        pending_declaration_name = false
      } else if in_substitution_position {
        match redirect_map.get(ident) {
          Some(rewritten_ident) => output = output + rewritten_ident
          None => output = output + ident
        }
      } else {
        output = output + ident
      }
      if wgsl_redirect_declaration_keyword(ident) {
        pending_declaration_name = true
        pending_template_depth = 0
      }
      in_substitution_position = true
      continue
    }
    if pending_declaration_name {
      if code == 60 {
        pending_template_depth = pending_template_depth + 1
      } else if code == 62 && pending_template_depth > 0 {
        pending_template_depth = pending_template_depth - 1
      }
    }
    output = output + code_unit_to_string(code)
    i = i + 1
    if code == 46 || code == 64 {
      in_substitution_position = false
    } else {
      in_substitution_position = true
    }
  }

  output
}

///|
fn rewrite_wgsl_declaration_text_with_redirects(
  source : String,
  redirect_map : @hashmap.HashMap[String, String],
) -> String {
  rewrite_wgsl_declaration_text_with_map(source, redirect_map, false)
}

///|
fn rewrite_wgsl_declaration_text_with_renamed_declarations(
  source : String,
  redirect_map : @hashmap.HashMap[String, String],
) -> String {
  rewrite_wgsl_declaration_text_with_map(source, redirect_map, true)
}

///|
fn collect_wgsl_function_parameter_sanitizers(
  block_text : String,
  redirect_map : @hashmap.HashMap[String, String],
) -> Unit {
  let header_end = match block_text.find("{") {
    Some(index) => index
    None => block_text.length()
  }
  let header = block_text[:header_end].to_string()
  guard header.find("fn ") is Some(fn_index) else { return }
  let fn_header = header[fn_index:header.length()].to_string()
  guard fn_header.find("(") is Some(open_index) else { return }
  guard fn_header.find(")") is Some(close_index) else { return }
  if close_index <= open_index {
    return
  }
  let params = fn_header[open_index + 1:close_index].to_string()
  for param_item in params.split(",") {
    let param = param_item.to_string().trim().to_string()
    if param == "" {
      continue
    }
    let mut end = 0
    while end < param.length() &&
          wgsl_identifier_char(param.code_unit_at(end).to_int()) {
      end = end + 1
    }
    if end > 0 {
      wgsl_redirect_map_set_sanitized(redirect_map, param[:end].to_string())
    }
  }
}

///|
fn sanitize_wgsl_invalid_identifiers(source : String) -> String {
  let graph = build_wgsl_declaration_graph(source)
  let global_redirects : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
  for block in graph.declaration_blocks {
    wgsl_redirect_map_set_sanitized(global_redirects, block.name)
  }
  if global_redirects.is_empty() {
    let mut has_parameter_sanitizers = false
    for block in graph.declaration_blocks {
      let block_redirects : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
      collect_wgsl_function_parameter_sanitizers(block.text, block_redirects)
      if !block_redirects.is_empty() {
        has_parameter_sanitizers = true
      }
    }
    if !has_parameter_sanitizers {
      return source
    }
  }
  let mut sanitized = ""
  for import_block in graph.import_blocks {
    sanitized = sanitized + import_block.text
  }
  for block in graph.declaration_blocks {
    let block_redirects : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
    for entry in global_redirects.iter() {
      let (from_name, to_name) = entry
      block_redirects.set(from_name, to_name)
    }
    collect_wgsl_function_parameter_sanitizers(block.text, block_redirects)
    sanitized = sanitized +
      rewrite_wgsl_declaration_text_with_renamed_declarations(
        block.text,
        block_redirects,
      )
  }
  sanitized
}

///|
pub fn rewrite_wgsl_symbol_redirects(
  source : String,
  redirects : Array[WgslSymbolRedirect],
) -> String {
  if redirects.length() == 0 {
    return source
  }
  let graph = build_wgsl_declaration_graph(source)
  let redirect_map = build_wgsl_symbol_redirect_map(redirects)
  let mut rewritten = ""
  for import_block in graph.import_blocks {
    rewritten = rewritten + import_block.text
  }
  for block in graph.declaration_blocks {
    rewritten = rewritten +
      rewrite_wgsl_declaration_text_with_redirects(block.text, redirect_map)
  }
  rewritten
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
        source_text: block.text.trim().to_string(),
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
pub fn Composer::build_wgsl_source_catalog(
  self : Composer,
  options : WgslComposeOptions,
) -> Array[WgslSourceCatalogEntry] {
  build_wgsl_source_catalog_from_files(
    self.copy_registered_wgsl_source_files(),
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
  let trimmed_block = block.text.trim().to_string()
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
    let from_name = redirect.from_name.trim().to_string()
    let to_name = redirect.to_name.trim().to_string()
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
fn Composer::export_wgsl_from_session(
  self : Composer,
  rel : String,
  session : WgslComposeSession,
  options : WgslExportOptions,
) -> WgslExportOutput raise ComposerError {
  let source = sanitize_wgsl_invalid_identifiers(
    self.load_root_wgsl_preprocessed_into_session(rel, session),
  )
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
pub fn Composer::export_wgsl_with_options(
  self : Composer,
  rel : String,
  compose_options : WgslComposeOptions,
  export_options : WgslExportOptions,
) -> WgslExportOutput raise ComposerError {
  let session = self.new_wgsl_compose_session(compose_options)
  self.export_wgsl_from_session(rel, session, export_options)
}

///|
pub fn Composer::export_wgsl_from_assets_base_required(
  self : Composer,
  assets_base : String,
  rel : String,
  options : WgslExportOptions,
) -> WgslExportOutput raise ComposerError {
  self.export_wgsl_from_assets_base_required_with_redirects(
    assets_base,
    rel,
    options,
    [],
  )
}

///|
pub fn Composer::export_wgsl_from_assets_base_required_with_redirects(
  self : Composer,
  assets_base : String,
  rel : String,
  options : WgslExportOptions,
  redirects : Array[WgslSymbolRedirect],
) -> WgslExportOutput raise ComposerError {
  let base = assets_base.trim().to_string()
  if base == "" {
    raise ComposerError::EmptyAssetsBase(rel)
  }
  self.export_wgsl_with_options(
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
