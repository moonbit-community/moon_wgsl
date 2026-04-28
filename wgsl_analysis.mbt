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
fn ends_with_text(text : String, suffix : String) -> Bool {
  text.length() >= suffix.length() &&
  text[text.length() - suffix.length():text.length()].to_string() == suffix
}

///|
fn text_contains_code_unit(text : String, code : Int) -> Bool {
  for i in 0..<text.length() {
    if text.code_unit_at(i).to_int() == code {
      return true
    }
  }
  false
}

///|
fn wgsl_identifier_char(code : Int) -> Bool {
  (code >= 65 && code <= 90) ||
  (code >= 97 && code <= 122) ||
  (code >= 48 && code <= 57) ||
  code == 95
}

///|
fn wgsl_string_list_push_unique(items : Array[String], item : String) -> Unit {
  for existing in items {
    if existing == item {
      return
    }
  }
  items.push(item)
}

///|
fn wgsl_declaration_name(line : String) -> String {
  let trimmed = line.trim().to_string()
  if trimmed == "" {
    return ""
  }
  if starts_with_text(trimmed, "@") {
    let mut i = 0
    while i + 3 < trimmed.length() {
      if trimmed.code_unit_at(i).to_int() == 32 &&
        trimmed.code_unit_at(i + 1).to_int() == 118 &&
        trimmed.code_unit_at(i + 2).to_int() == 97 &&
        trimmed.code_unit_at(i + 3).to_int() == 114 {
        return wgsl_declaration_name(
          trimmed[i + 1:trimmed.length()].to_string(),
        )
      }
      i = i + 1
    }
    return ""
  }
  if starts_with_text(trimmed, "struct ") {
    let rest = trimmed[7:trimmed.length()].to_string()
    let mut end = 0
    while end < rest.length() &&
          wgsl_identifier_char(rest.code_unit_at(end).to_int()) {
      end = end + 1
    }
    return if end == 0 { "" } else { rest[:end].to_string() }
  }
  if starts_with_text(trimmed, "fn ") {
    let rest = trimmed[3:trimmed.length()].to_string()
    let mut end = 0
    while end < rest.length() &&
          wgsl_identifier_char(rest.code_unit_at(end).to_int()) {
      end = end + 1
    }
    return if end == 0 { "" } else { rest[:end].to_string() }
  }
  if starts_with_text(trimmed, "const ") {
    let rest = trimmed[6:trimmed.length()].to_string()
    let mut end = 0
    while end < rest.length() &&
          wgsl_identifier_char(rest.code_unit_at(end).to_int()) {
      end = end + 1
    }
    return if end == 0 { "" } else { rest[:end].to_string() }
  }
  if starts_with_text(trimmed, "override ") {
    let rest = trimmed[9:trimmed.length()].to_string()
    let mut end = 0
    while end < rest.length() &&
          wgsl_identifier_char(rest.code_unit_at(end).to_int()) {
      end = end + 1
    }
    return if end == 0 { "" } else { rest[:end].to_string() }
  }
  if starts_with_text(trimmed, "alias ") {
    let rest = trimmed[6:trimmed.length()].to_string()
    let mut end = 0
    while end < rest.length() &&
          wgsl_identifier_char(rest.code_unit_at(end).to_int()) {
      end = end + 1
    }
    return if end == 0 { "" } else { rest[:end].to_string() }
  }
  if starts_with_text(trimmed, "type ") {
    let rest = trimmed[5:trimmed.length()].to_string()
    let mut end = 0
    while end < rest.length() &&
          wgsl_identifier_char(rest.code_unit_at(end).to_int()) {
      end = end + 1
    }
    return if end == 0 { "" } else { rest[:end].to_string() }
  }
  if starts_with_text(trimmed, "var") {
    let mut i = 3
    while i < trimmed.length() &&
          (
            trimmed.code_unit_at(i).to_int() == 32 ||
            trimmed.code_unit_at(i).to_int() == 9
          ) {
      i = i + 1
    }
    if i < trimmed.length() && trimmed.code_unit_at(i).to_int() == 60 {
      while i < trimmed.length() && trimmed.code_unit_at(i).to_int() != 62 {
        i = i + 1
      }
      if i < trimmed.length() {
        i = i + 1
      }
    }
    while i < trimmed.length() &&
          (
            trimmed.code_unit_at(i).to_int() == 32 ||
            trimmed.code_unit_at(i).to_int() == 9
          ) {
      i = i + 1
    }
    let start = i
    while i < trimmed.length() &&
          wgsl_identifier_char(trimmed.code_unit_at(i).to_int()) {
      i = i + 1
    }
    return if i == start { "" } else { trimmed[start:i].to_string() }
  }
  ""
}

///|
fn build_wgsl_declaration_graph(source : String) -> WgslDeclarationGraph {
  let lines : Array[String] = []
  let cleaned_lines : Array[String] = []
  let line_starts : Array[Int] = []
  let mut offset = 0
  for line_item in source.split("\n") {
    let line = line_item.to_string()
    lines.push(line)
    line_starts.push(offset)
    offset = offset + line.length() + 1
  }
  for line_item in replace_comments(source).split("\n") {
    cleaned_lines.push(line_item.to_string())
  }

  let pending_prefix : Array[String] = []
  let import_blocks : Array[WgslGraphBlock] = []
  let declaration_blocks : Array[WgslGraphBlock] = []
  let mut pending_prefix_start = 0
  let mut i = 0
  while i < lines.length() {
    let line = lines[i]
    let cleaned_line = cleaned_lines[i]
    let trimmed = cleaned_line.trim().to_string()
    let decl_name_hint = wgsl_declaration_name(trimmed)
    if trimmed == "" || (starts_with_text(trimmed, "@") && decl_name_hint == "") {
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
        balance = balance + import_brace_balance(cleaned_lines[i])
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
      let cleaned_block_line = cleaned_lines[i]
      block_lines.push(block_line)
      if text_contains_code_unit(cleaned_block_line, 123) {
        saw_brace = true
      }
      brace_depth = brace_depth + import_brace_balance(cleaned_block_line)
      let block_trimmed = cleaned_block_line.trim().to_string()
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
fn collect_wgsl_declaration_dependencies(
  declaration_text : String,
  self_name : String,
  declaration_names : @hashmap.HashMap[String, Bool],
  dependencies : Array[String],
) -> Unit {
  for token in tokenize(declaration_text, false) {
    match token {
      Token::Identifier(ident, _) => {
        if ident.contains("\"") {
          continue
        }
        let segments : Array[String] = []
        for raw_segment in ident.split("::") {
          let segment = raw_segment.to_string().trim().to_string()
          if segment != "" {
            segments.push(segment)
          }
        }
        if segments.length() == 0 {
          if ident != self_name && declaration_names.contains(ident) {
            wgsl_string_list_push_unique(dependencies, ident)
          }
          continue
        }
        let dependency_name = segments[segments.length() - 1]
        if dependency_name != self_name &&
          declaration_names.contains(dependency_name) {
          wgsl_string_list_push_unique(dependencies, dependency_name)
        }
      }
      _ => ()
    }
  }
}

///|
fn collect_wgsl_reachable_declaration_names(
  declaration_blocks : Array[WgslGraphBlock],
  root_items : Array[String],
) -> (@hashmap.HashMap[String, Bool], Array[String]) {
  let included_names : @hashmap.HashMap[String, Bool] = @hashmap.HashMap::new()
  if root_items.length() == 0 {
    for block in declaration_blocks {
      if block.name != "" {
        included_names.set(block.name, true)
      }
    }
    return (included_names, [])
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
  if worklist.length() == 0 {
    for block in declaration_blocks {
      if block.name != "" {
        included_names.set(block.name, true)
      }
    }
    return (included_names, missing_root_items)
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
  (included_names, missing_root_items)
}

///|
fn strip_wgsl_import_declarations(source : String) -> String {
  let lines : Array[String] = []
  for line_item in source.split("\n") {
    lines.push(line_item.to_string())
  }
  let mut out = ""
  let mut index = 0
  while index < lines.length() {
    let line = lines[index]
    let trimmed = line.trim().to_string()
    if starts_with_text(trimmed, "#define_import_path") {
      index = index + 1
      continue
    }
    if starts_with_text(trimmed, "#import ") {
      let mut brace_balance = import_brace_balance(
        trimmed[8:trimmed.length()].to_string(),
      )
      while brace_balance > 0 && index + 1 < lines.length() {
        index = index + 1
        brace_balance = brace_balance + import_brace_balance(lines[index])
      }
      index = index + 1
      continue
    }
    out = "\{out}\{line}\n"
    index = index + 1
  }
  out
}

///|
fn extract_wgsl_module_items(
  source : String,
  requested_items : Array[String],
) -> String {
  if requested_items.length() == 0 {
    return source
  }
  let graph = build_wgsl_declaration_graph(source)
  let (included_names, _) = collect_wgsl_reachable_declaration_names(
    graph.declaration_blocks,
    requested_items,
  )
  let mut matched_requested = 0
  for item in requested_items {
    if included_names.contains(item) {
      matched_requested = matched_requested + 1
    }
  }
  if matched_requested == 0 {
    return source
  }
  let mut out = ""
  for import_block in graph.import_blocks {
    out = out + import_block.text
  }
  for block in graph.declaration_blocks {
    if block.name == "" || included_names.contains(block.name) {
      out = out + block.text
    }
  }
  out
}
