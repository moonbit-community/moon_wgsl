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
  tokens : Array[WgslToken]
  start : Int
  end : Int
  data : WgslGlobalDeclData
}

///|
priv struct WgslDeclarationGraph {
  import_blocks : Array[WgslGraphBlock]
  declaration_blocks : Array[WgslGraphBlock]
}

///|
pub struct WgslEmittedDeclaration {
  priv name : String
  priv is_type_declaration : Bool
  priv generated_start : Int
  priv generated_end : Int
}

///|
pub struct WgslTreeShakenSource {
  priv source : String
  priv declarations : Array[WgslEmittedDeclaration]
  priv missing_root_items : Array[String]
}

///|
pub struct WgslModuleItemOrigin {
  priv name : String
  priv source_start : Int
  priv source_end : Int
}

///|
pub struct WgslModuleItemExtraction {
  priv source : String
  priv origins : Array[WgslModuleItemOrigin]
}

///|
pub fn WgslEmittedDeclaration::name(self : WgslEmittedDeclaration) -> String {
  self.name
}

///|
pub fn WgslEmittedDeclaration::is_type_declaration(
  self : WgslEmittedDeclaration,
) -> Bool {
  self.is_type_declaration
}

///|
pub fn WgslEmittedDeclaration::generated_start(
  self : WgslEmittedDeclaration,
) -> Int {
  self.generated_start
}

///|
pub fn WgslEmittedDeclaration::generated_end(
  self : WgslEmittedDeclaration,
) -> Int {
  self.generated_end
}

///|
pub fn WgslTreeShakenSource::source(self : WgslTreeShakenSource) -> String {
  self.source
}

///|
pub fn WgslTreeShakenSource::declarations(
  self : WgslTreeShakenSource,
) -> Array[WgslEmittedDeclaration] {
  self.declarations.copy()
}

///|
pub fn WgslTreeShakenSource::missing_root_items(
  self : WgslTreeShakenSource,
) -> Array[String] {
  self.missing_root_items.copy()
}

///|
pub fn WgslModuleItemOrigin::name(self : WgslModuleItemOrigin) -> String {
  self.name
}

///|
pub fn WgslModuleItemOrigin::source_start(self : WgslModuleItemOrigin) -> Int {
  self.source_start
}

///|
pub fn WgslModuleItemOrigin::source_end(self : WgslModuleItemOrigin) -> Int {
  self.source_end
}

///|
pub fn WgslModuleItemExtraction::source(
  self : WgslModuleItemExtraction,
) -> String {
  self.source
}

///|
pub fn WgslModuleItemExtraction::origins(
  self : WgslModuleItemExtraction,
) -> Array[WgslModuleItemOrigin] {
  self.origins.copy()
}

///|
fn build_wgsl_declaration_graph_from_unit(
  source : String,
  unit : WgslTranslationUnit,
) -> WgslDeclarationGraph {
  let import_blocks : Array[WgslGraphBlock] = []
  let declaration_blocks : Array[WgslGraphBlock] = []
  for decl in unit.declarations() {
    let graph_block = WgslGraphBlock::{
      name: decl.name(),
      tokens: tokenize_wgsl_absolute_fragment(source, decl.start(), decl.end()),
      start: decl.start(),
      end: decl.end(),
      data: decl.data(),
    }
    match decl.kind() {
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
        match decl.data() {
          WgslGlobalDeclData::Directive(directive) =>
            if directive.kind() == WgslDirectiveKind::Enable ||
              directive.kind() == WgslDirectiveKind::Requires ||
              directive.kind() == WgslDirectiveKind::Diagnostic {
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
fn WgslGraphBlock::is_type_declaration(self : WgslGraphBlock) -> Bool {
  match self.data {
    WgslGlobalDeclData::Struct(_) | WgslGlobalDeclData::TypeAlias(_) => true
    _ => false
  }
}

///|
fn build_wgsl_declaration_graph(
  source : String,
) -> WgslDeclarationGraph raise WgslParseError {
  build_wgsl_declaration_graph_from_unit(
    source,
    parse_wgsl_translation_unit_strict(source),
  )
}

///|
fn build_wgsl_declaration_graph_strict(
  source : String,
) -> WgslDeclarationGraph raise WgslParseError {
  build_wgsl_declaration_graph(source)
}

///|
fn wgsl_reachable_declaration_map(
  declaration_blocks : Array[WgslGraphBlock],
  root_items : Array[String],
) -> (@hashmap.HashMap[String, Bool], Array[String]) {
  let included_names : @hashmap.HashMap[String, Bool] = @hashmap.HashMap::new()
  let declarations : Array[WgslGlobalDecl] = []
  for block in declaration_blocks {
    declarations.push(
      WgslGlobalDecl::new(
        WgslGlobalDeclKind::Unknown,
        block.data,
        block.name,
        block.start,
        block.end,
      ),
    )
  }
  let reachable = collect_wgsl_reachable_declaration_names(
    declarations, root_items,
  )
  for name in reachable.included_names {
    included_names.set(name, true)
  }
  (included_names, reachable.missing_root_items)
}

///|
fn emit_wgsl_tree_shaken_source_from_graph(
  graph : WgslDeclarationGraph,
  root_items : Array[String],
) -> WgslTreeShakenSource {
  let (included_names, missing_root_items) = wgsl_reachable_declaration_map(
    graph.declaration_blocks,
    root_items,
  )
  let declarations : Array[WgslEmittedDeclaration] = []
  let mut emitted_source = ""
  let mut generated_start = 0

  for import_block in graph.import_blocks {
    let emitted_block = emit_wgsl_graph_block_canonical(import_block)
    emitted_source = emitted_source + emitted_block
    generated_start = generated_start + emitted_block.length()
  }
  for block in graph.declaration_blocks {
    if block.name != "" && !included_names.contains(block.name) {
      continue
    }
    let emitted_block = emit_wgsl_graph_block_canonical(block)
    let block_generated_start = generated_start
    emitted_source = emitted_source + emitted_block
    generated_start = generated_start + emitted_block.length()
    if block.name != "" {
      declarations.push(WgslEmittedDeclaration::{
        name: block.name,
        is_type_declaration: block.is_type_declaration(),
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
pub fn emit_wgsl_tree_shaken_source_strict(
  source : String,
  root_items : Array[String],
) -> WgslTreeShakenSource raise WgslParseError {
  emit_wgsl_tree_shaken_source_from_graph(
    build_wgsl_declaration_graph_strict(source),
    root_items,
  )
}

///|
pub fn collect_wgsl_named_declarations_strict(
  source : String,
) -> Array[WgslEmittedDeclaration] raise WgslParseError {
  emit_wgsl_tree_shaken_source_strict(source, []).declarations()
}

///|
fn strip_wgsl_import_declarations_from_source_unit(
  source : String,
  unit : WgslTranslationUnit,
) -> String {
  let mut out = ""
  for decl in unit.declarations() {
    let skip = match decl.data() {
      WgslGlobalDeclData::Import(_) => true
      WgslGlobalDeclData::Directive(directive) =>
        directive.kind() == WgslDirectiveKind::DefineImportPath
      _ => false
    }
    if !skip {
      out = out +
        emit_wgsl_graph_block_canonical(WgslGraphBlock::{
          name: decl.name(),
          tokens: tokenize_wgsl_absolute_fragment(
            source,
            decl.start(),
            decl.end(),
          ),
          start: decl.start(),
          end: decl.end(),
          data: decl.data(),
        })
    }
  }
  out
}

///|
pub fn strip_wgsl_import_declarations_strict(
  source : String,
) -> String raise WgslParseError {
  strip_wgsl_import_declarations_from_source_unit(
    source,
    parse_wgsl_translation_unit_strict(source),
  )
}

///|
fn extract_wgsl_module_item_extraction_from_graph(
  _source : String,
  graph : WgslDeclarationGraph,
  requested_items : Array[String],
) -> WgslModuleItemExtraction {
  let origins : Array[WgslModuleItemOrigin] = []
  if requested_items.length() == 0 {
    for block in graph.declaration_blocks {
      if block.name != "" {
        origins.push(WgslModuleItemOrigin::{
          name: block.name,
          source_start: block.start,
          source_end: block.end,
        })
      }
    }
    return WgslModuleItemExtraction::{
      source: emit_wgsl_graph_blocks_canonical(graph.declaration_blocks),
      origins,
    }
  }
  let (included_names, _) = wgsl_reachable_declaration_map(
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
    for block in graph.declaration_blocks {
      if block.name != "" {
        origins.push(WgslModuleItemOrigin::{
          name: block.name,
          source_start: block.start,
          source_end: block.end,
        })
      }
    }
    return WgslModuleItemExtraction::{
      source: emit_wgsl_graph_blocks_canonical(graph.declaration_blocks),
      origins,
    }
  }
  let mut out = ""
  for import_block in graph.import_blocks {
    out = out + emit_wgsl_graph_block_canonical(import_block)
  }
  for block in graph.declaration_blocks {
    if block.name == "" || included_names.contains(block.name) {
      out = out + emit_wgsl_graph_block_canonical(block)
      if block.name != "" {
        origins.push(WgslModuleItemOrigin::{
          name: block.name,
          source_start: block.start,
          source_end: block.end,
        })
      }
    }
  }
  WgslModuleItemExtraction::{ source: out, origins }
}

///|
pub fn extract_wgsl_module_item_origins_strict(
  source : String,
  requested_items : Array[String],
) -> WgslModuleItemExtraction raise WgslParseError {
  extract_wgsl_module_item_extraction_from_graph(
    source,
    build_wgsl_declaration_graph_strict(source),
    requested_items,
  )
}

///|
