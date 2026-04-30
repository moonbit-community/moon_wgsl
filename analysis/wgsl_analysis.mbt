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
pub struct WgslGraphBlock {
  name : String
  text : String
  start : Int
  data : WgslGlobalDeclData
}

///|
pub struct WgslDeclarationGraph {
  import_blocks : Array[WgslGraphBlock]
  declaration_blocks : Array[WgslGraphBlock]
}

///|
pub struct WgslEmittedDeclaration {
  name : String
  text : String
  generated_start : Int
  generated_end : Int
}

///|
pub struct WgslTreeShakenSource {
  source : String
  declarations : Array[WgslEmittedDeclaration]
  missing_root_items : Array[String]
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
pub fn build_wgsl_declaration_graph(source : String) -> WgslDeclarationGraph {
  let import_blocks : Array[WgslGraphBlock] = []
  let declaration_blocks : Array[WgslGraphBlock] = []
  for decl in parse_wgsl_translation_unit(source).declarations {
    let graph_block = WgslGraphBlock::{
      name: decl.name,
      text: decl.text,
      start: decl.start,
      data: decl.data,
    }
    match decl.kind {
      WgslGlobalDeclKind::Import => import_blocks.push(graph_block)
      WgslGlobalDeclKind::Function
      | WgslGlobalDeclKind::GlobalVariable
      | WgslGlobalDeclKind::Const
      | WgslGlobalDeclKind::Override
      | WgslGlobalDeclKind::Struct
      | WgslGlobalDeclKind::TypeAlias
      | WgslGlobalDeclKind::ConstAssert
      | WgslGlobalDeclKind::Unknown => declaration_blocks.push(graph_block)
      WgslGlobalDeclKind::Directive =>
        match decl.data {
          WgslGlobalDeclData::Directive(directive) =>
            if directive.kind == WgslDirectiveKind::Enable ||
              directive.kind == WgslDirectiveKind::Requires ||
              directive.kind == WgslDirectiveKind::Diagnostic {
              declaration_blocks.push(graph_block)
            }
          _ => ()
        }
      _ => ()
    }
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
fn collect_wgsl_identifier_dependencies(
  identifiers : Array[WgslIdent],
  self_name : String,
  declaration_names : @hashmap.HashMap[String, Bool],
  dependencies : Array[String],
) -> Unit {
  for identifier in identifiers {
    let dependency_name = match split_last_identifier(identifier.name) {
      Some((_, suffix)) => suffix
      None => identifier.name
    }
    if dependency_name != self_name &&
      declaration_names.contains(dependency_name) {
      wgsl_string_list_push_unique(dependencies, dependency_name)
    }
  }
}

///|
fn collect_wgsl_declaration_dependencies(
  declaration_data : WgslGlobalDeclData,
  self_name : String,
  declaration_names : @hashmap.HashMap[String, Bool],
  dependencies : Array[String],
) -> Unit {
  match declaration_data {
    WgslGlobalDeclData::Raw => ()
    WgslGlobalDeclData::Directive(_) | WgslGlobalDeclData::Import(_) => ()
    _ => {
      let identifiers : Array[WgslIdent] = []
      collect_wgsl_decl_identifier_nodes(declaration_data, identifiers)
      collect_wgsl_identifier_dependencies(
        identifiers, self_name, declaration_names, dependencies,
      )
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
      block.data,
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
pub fn emit_wgsl_tree_shaken_source(
  source : String,
  root_items : Array[String],
) -> WgslTreeShakenSource {
  let graph = build_wgsl_declaration_graph(source)
  let (included_names, missing_root_items) = collect_wgsl_reachable_declaration_names(
    graph.declaration_blocks,
    root_items,
  )
  let declarations : Array[WgslEmittedDeclaration] = []
  let mut emitted_source = ""
  let mut generated_start = 0

  for import_block in graph.import_blocks {
    emitted_source = emitted_source + import_block.text
    generated_start = generated_start + import_block.text.length()
  }
  for block in graph.declaration_blocks {
    if block.name != "" && !included_names.contains(block.name) {
      continue
    }
    let block_generated_start = generated_start
    emitted_source = emitted_source + block.text
    generated_start = generated_start + block.text.length()
    if block.name != "" {
      declarations.push(WgslEmittedDeclaration::{
        name: block.name,
        text: block.text,
        generated_start: block_generated_start,
        generated_end: generated_start,
      })
    }
  }

  WgslTreeShakenSource::{
    source: emitted_source,
    declarations,
    missing_root_items,
  }
}

///|
pub fn collect_wgsl_named_declarations(
  source : String,
) -> Array[WgslEmittedDeclaration] {
  emit_wgsl_tree_shaken_source(source, []).declarations
}

///|
pub fn strip_wgsl_import_declarations(source : String) -> String {
  let mut out = ""
  for decl in parse_wgsl_translation_unit(source).declarations {
    match decl.data {
      WgslGlobalDeclData::Import(_) => ()
      WgslGlobalDeclData::Directive(directive) =>
        if directive.kind == WgslDirectiveKind::DefineImportPath {
          ()
        } else {
          out = out + decl.text
        }
      _ => out = out + decl.text
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
