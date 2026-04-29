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
pub(all) struct WgslGraphBlock {
  name : String
  text : String
  start : Int
  end : Int
}

///|
pub(all) struct WgslDeclarationGraph {
  import_blocks : Array[WgslGraphBlock]
  declaration_blocks : Array[WgslGraphBlock]
}

///|
pub fn wgsl_identifier_char(code : Int) -> Bool {
  (code >= 65 && code <= 90) ||
  (code >= 97 && code <= 122) ||
  (code >= 48 && code <= 57) ||
  code == 95
}

///|
pub fn wgsl_string_list_push_unique(
  items : Array[String],
  item : String,
) -> Unit {
  for existing in items {
    if existing == item {
      return
    }
  }
  items.push(item)
}

///|
pub fn build_wgsl_declaration_graph(source : String) -> WgslDeclarationGraph {
  let import_blocks : Array[WgslGraphBlock] = []
  let declaration_blocks : Array[WgslGraphBlock] = []
  for item in parse_wgsl_top_level_items(source) {
    match item.kind {
      WgslTopLevelKind::Import =>
        import_blocks.push(WgslGraphBlock::{
          name: item.name,
          text: item.text,
          start: item.start,
          end: item.end,
        })
      WgslTopLevelKind::Declaration =>
        declaration_blocks.push(WgslGraphBlock::{
          name: item.name,
          text: item.text,
          start: item.start,
          end: item.end,
        })
      _ => ()
    }
  }

  WgslDeclarationGraph::{ import_blocks, declaration_blocks }
}

///|
pub fn build_wgsl_declaration_indexes(
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
          let segment = raw_segment.to_owned().trim().to_owned()
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
pub fn collect_wgsl_reachable_declaration_names(
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
fn wgsl_declaration_block_has_entry_point_attribute(text : String) -> Bool {
  let cleaned = replace_comments(text)
  cleaned.contains("@vertex") ||
  cleaned.contains("@fragment") ||
  cleaned.contains("@compute")
}

///|
pub fn wgsl_source_declares_entry_point(
  source : String,
  item_name : String,
) -> Bool {
  if item_name == "" {
    return false
  }
  let graph = build_wgsl_declaration_graph(source)
  for block in graph.declaration_blocks {
    if block.name == item_name &&
      wgsl_declaration_block_has_entry_point_attribute(block.text) {
      return true
    }
  }
  false
}

///|
pub fn strip_wgsl_import_declarations(source : String) -> String {
  let mut out = ""
  for item in parse_wgsl_top_level_items(source) {
    match item.kind {
      WgslTopLevelKind::DefineImportPath | WgslTopLevelKind::Import => ()
      _ => out = out + item.text
    }
  }
  out
}

///|
pub fn extract_wgsl_module_items(
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
