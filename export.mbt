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
priv struct WgslGraphBlock {
  name : String
  text : String
  start : Int
  end : Int
}

///|
priv struct WgslDeclarationGraph {
  import_blocks : Array[WgslGraphBlock]
  declaration_blocks : Array[WgslGraphBlock]
}

///|
priv struct WgslSourceCatalogEntry {
  rel_path : String
  name : String
  text : String
  source_start : Int
  source_end : Int
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
fn build_wgsl_declaration_graph(source : String) -> WgslDeclarationGraph {
  let lines : Array[String] = []
  let line_starts : Array[Int] = []
  let mut offset = 0
  for line_item in source.split("\n") {
    let line = line_item.to_string()
    lines.push(line)
    line_starts.push(offset)
    offset = offset + line.length() + 1
  }

  let pending_prefix : Array[String] = []
  let import_blocks : Array[WgslGraphBlock] = []
  let declaration_blocks : Array[WgslGraphBlock] = []
  let mut pending_prefix_start = 0
  let mut i = 0
  while i < lines.length() {
    let line = lines[i]
    let trimmed = line.trim().to_string()
    let decl_name_hint = wgsl_declaration_name(trimmed)
    if trimmed == "" ||
      starts_with_text(trimmed, "//") ||
      (starts_with_text(trimmed, "@") && decl_name_hint == "") {
      if pending_prefix.length() == 0 {
        pending_prefix_start = line_starts[i]
      }
      pending_prefix.push(line)
      i = i + 1
      continue
    }
    if starts_with_text(trimmed, "#define_import_path") {
      i = i + 1
      continue
    }
    if starts_with_text(trimmed, "#import ") {
      let block_start = line_starts[i]
      let mut import_block = line
      let mut balance = import_brace_balance(
        trimmed[8:trimmed.length()].to_string(),
      )
      while balance > 0 && i + 1 < lines.length() {
        i = i + 1
        let next_line = lines[i]
        import_block = "\{import_block}\n\{next_line}"
        balance = balance + import_brace_balance(next_line)
      }
      import_block = "\{import_block}\n"
      import_blocks.push(WgslGraphBlock::{
        name: "",
        text: import_block,
        start: block_start,
        end: block_start + import_block.length(),
      })
      pending_prefix.clear()
      i = i + 1
      continue
    }
    let block_lines : Array[String] = []
    let block_start = if pending_prefix.length() > 0 {
      pending_prefix_start
    } else {
      line_starts[i]
    }
    for prefix_line in pending_prefix {
      block_lines.push(prefix_line)
    }
    pending_prefix.clear()
    let decl_name = decl_name_hint
    let mut saw_brace = false
    let mut brace_depth = 0
    let mut done = false
    while !done {
      let block_line = lines[i]
      block_lines.push(block_line)
      if text_contains_code_unit(block_line, 123) {
        saw_brace = true
      }
      brace_depth = brace_depth + import_brace_balance(block_line)
      let block_trimmed = block_line.trim().to_string()
      if saw_brace {
        done = brace_depth == 0
      } else {
        done = ends_with_text(block_trimmed, ";")
      }
      if !done {
        i = i + 1
        if i >= lines.length() {
          done = true
        }
      }
    }
    let mut block_text = ""
    for block_line in block_lines {
      block_text = "\{block_text}\{block_line}\n"
    }
    declaration_blocks.push(WgslGraphBlock::{
      name: decl_name,
      text: block_text,
      start: block_start,
      end: block_start + block_text.length(),
    })
    i = i + 1
  }

  WgslDeclarationGraph::{ import_blocks, declaration_blocks }
}

///|
fn build_wgsl_declaration_indexes(
  declaration_blocks : Array[WgslGraphBlock],
) -> (@hashmap.HashMap[String, Bool], @hashmap.HashMap[String, Int]) {
  let declaration_names : @hashmap.HashMap[String, Bool] = @hashmap.HashMap::new()
  let declaration_indexes : @hashmap.HashMap[String, Int] = @hashmap.HashMap::new()
  for i in 0..<declaration_blocks.length() {
    let block = declaration_blocks[i]
    if block.name != "" {
      declaration_names.set(block.name, true)
      declaration_indexes.set(block.name, i)
    }
  }
  (declaration_names, declaration_indexes)
}

///|
fn collect_wgsl_reachable_declarations(
  declaration_blocks : Array[WgslGraphBlock],
  root_items : Array[String],
  diagnostics : Array[WgslDiagnostic],
) -> @hashmap.HashMap[String, Bool] {
  let included_names : @hashmap.HashMap[String, Bool] = @hashmap.HashMap::new()
  if root_items.length() == 0 {
    for block in declaration_blocks {
      if block.name != "" {
        included_names.set(block.name, true)
      }
    }
    return included_names
  }

  let (declaration_names, declaration_indexes) = build_wgsl_declaration_indexes(
    declaration_blocks,
  )
  let worklist : Array[String] = []
  let missing_root_items : Array[String] = []
  for root_item in root_items {
    if declaration_names.contains(root_item) {
      worklist.push(root_item)
    } else {
      missing_root_items.push(root_item)
    }
  }
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
  if worklist.length() == 0 {
    for block in declaration_blocks {
      if block.name != "" {
        included_names.set(block.name, true)
      }
    }
    return included_names
  }

  while worklist.length() > 0 {
    let name = worklist.pop().unwrap()
    if included_names.contains(name) {
      continue
    }
    included_names.set(name, true)
    guard declaration_indexes.get(name) is Some(index) else { continue }
    let block = declaration_blocks[index]
    let dependencies : Array[String] = []
    collect_wgsl_declaration_dependencies(
      block.text,
      name,
      declaration_names,
      dependencies,
    )
    for dependency in dependencies {
      if !included_names.contains(dependency) {
        worklist.push(dependency)
      }
    }
  }
  included_names
}

///|
fn build_wgsl_source_catalog(
  defines : @hashmap.HashMap[String, Bool],
  value_defines : @hashmap.HashMap[String, Int],
) -> @hashmap.HashMap[String, Array[WgslSourceCatalogEntry]] {
  let catalog : @hashmap.HashMap[String, Array[WgslSourceCatalogEntry]] = @hashmap.HashMap::new()
  for source_file in copy_registered_wgsl_source_files() {
    let prepared_source = strip_wgsl_import_declarations(
      apply_wgsl_template_consts(
        apply_wgsl_ifdefs(source_file.source, defines, value_defines),
        value_defines,
      ),
    )
    let graph = build_wgsl_declaration_graph(prepared_source)
    for block in graph.declaration_blocks {
      guard block.name != "" else { continue }
      let entry = WgslSourceCatalogEntry::{
        rel_path: source_file.rel_path,
        name: block.name,
        text: block.text.trim().to_string(),
        source_start: block.start,
        source_end: block.end,
      }
      if catalog.get(block.name) is Some(entries) {
        entries.push(entry)
      } else {
        catalog.set(block.name, [entry])
      }
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
    if entry.text == trimmed_block {
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
  options : WgslExportOptions,
  defines : @hashmap.HashMap[String, Bool],
  value_defines : @hashmap.HashMap[String, Int],
) -> WgslExportOutput {
  let diagnostics : Array[WgslDiagnostic] = []
  let included_names = collect_wgsl_reachable_declarations(
    graph.declaration_blocks,
    options.root_items,
    diagnostics,
  )
  let catalog = build_wgsl_source_catalog(defines, value_defines)
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
        symbol_name: Some(entry.name),
      })
    }
  }

  WgslExportOutput::{ source, source_map, diagnostics }
}

///|
pub fn Composer::export_wgsl(
  self : Composer,
  assets_base : String,
  rel : String,
  defines : @hashmap.HashMap[String, Bool],
  value_defines : @hashmap.HashMap[String, Int],
  modules : @hashmap.HashMap[String, String],
  options : WgslExportOptions,
) -> WgslExportOutput raise ComposerError {
  let visited : @hashmap.HashMap[String, Bool] = @hashmap.HashMap::new()
  let source = self.load_wgsl_preprocessed(
    assets_base, rel, defines, value_defines, visited, modules,
  )
  let graph = build_wgsl_declaration_graph(source)
  serialize_wgsl_export_output(graph, options, defines, value_defines)
}

///|
pub fn Composer::export_wgsl_from_assets_base_required(
  self : Composer,
  assets_base : String,
  rel : String,
  options : WgslExportOptions,
) -> WgslExportOutput raise ComposerError {
  let base = assets_base.trim().to_string()
  if base == "" {
    raise ComposerError::EmptyAssetsBase(rel)
  }
  let normalized_rel = normalize_shader_rel_path(rel)
  let defines : @hashmap.HashMap[String, Bool] = @hashmap.HashMap::new()
  let value_defines = default_wgsl_value_defines()
  let modules = build_wgsl_import_module_paths(base)
  self.export_wgsl(
    base, normalized_rel, defines, value_defines, modules, options,
  )
}
