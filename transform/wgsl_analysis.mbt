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
            if directive.kind() == WgslDirectiveKind::Import {
              import_blocks.push(graph_block)
            } else if directive.kind() == WgslDirectiveKind::Enable ||
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
fn WgslGraphBlock::name(self : WgslGraphBlock) -> String {
  wgsl_decl_data_name(self.data)
}

///|
fn WgslGraphBlock::is_type_declaration(self : WgslGraphBlock) -> Bool {
  match self.data {
    WgslGlobalDeclData::Struct(_) | WgslGlobalDeclData::TypeAlias(_) => true
    _ => false
  }
}

///|
fn WgslGraphBlock::is_symbol_origin(self : WgslGraphBlock) -> Bool {
  match self.data {
    WgslGlobalDeclData::Function(function) =>
      function.qualifier() != Some(WgslFunctionQualifier::Override)
    _ => self.name() != ""
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
fn emit_wgsl_import_blocks_for_item_extraction(
  source : String,
  graph : WgslDeclarationGraph,
) -> String {
  let imported_starts : @set.Set[Int] = @set.Set([])
  let mut out = ""
  for import_block in graph.import_blocks {
    imported_starts.add(import_block.start)
    out = out + emit_wgsl_graph_block_canonical(import_block)
  }
  for
    item in parse_wgsl_directive_scan_items(source, include_glsl_version=false) {
    match item.kind() {
      WgslDirectiveScanItemKind::Directive(directive) if directive.kind() ==
        WgslDirectiveKind::Import =>
        if !imported_starts.contains(item.start()) {
          out = out + item.source().original_text()
        }
      _ => ()
    }
  }
  out
}

///|
fn wgsl_reachable_declaration_map(
  declaration_blocks : Array[WgslGraphBlock],
  root_items : Array[String],
) -> (@set.Set[String], Array[String], Array[String]) {
  let included_names : @set.Set[String] = @set.Set([])
  let declarations : Array[WgslGlobalDecl] = []
  for block in declaration_blocks {
    declarations.push(
      WgslGlobalDecl(
        WgslGlobalDeclKind::Unknown,
        block.data,
        block.start,
        block.end,
      ),
    )
  }
  let reachable = collect_wgsl_reachable_declaration_names(
    declarations, root_items,
  )
  for name in reachable.included_names {
    included_names.add(name)
  }
  (included_names, reachable.included_names, reachable.missing_root_items)
}

///|
fn wgsl_declaration_graph_block_named(
  declaration_blocks : Array[WgslGraphBlock],
  name : String,
) -> WgslGraphBlock? {
  for block in declaration_blocks {
    if block.name() == name {
      return Some(block)
    }
  }
  None
}

///|
fn wgsl_graph_block_is_const_like(block : WgslGraphBlock) -> Bool {
  match block.data {
    WgslGlobalDeclData::Const(_) | WgslGlobalDeclData::Override(_) => true
    _ => false
  }
}

///|
fn wgsl_graph_order_push_unique(
  ordered : Array[String],
  emitted : @set.Set[String],
  name : String,
) -> Unit {
  if name == "" || emitted.contains(name) {
    return
  }
  emitted.add(name)
  ordered.push(name)
}

///|
fn wgsl_graph_block_dependencies_in_ast_order(
  block : WgslGraphBlock,
  declaration_names : @set.Set[String],
) -> Array[String] {
  let dependencies : Array[String] = []
  let self_name = block.name()
  let identifiers : Array[WgslIdent] = []
  collect_wgsl_decl_identifier_nodes(block.data, identifiers)
  wgsl_analysis_collect_identifier_dependencies(
    identifiers, self_name, declaration_names, dependencies,
  )
  dependencies
}

///|
fn wgsl_declaration_graph_visit_import_order(
  declaration_blocks : Array[WgslGraphBlock],
  declaration_names : @set.Set[String],
  name : String,
  visiting : @set.Set[String],
  emitted : @set.Set[String],
  ordered : Array[String],
) -> Unit {
  if name == "" || emitted.contains(name) || visiting.contains(name) {
    return
  }
  guard wgsl_declaration_graph_block_named(declaration_blocks, name)
    is Some(block) else {
    return
  }
  visiting.add(name)
  let dependencies = wgsl_graph_block_dependencies_in_ast_order(
    block, declaration_names,
  )
  if wgsl_graph_block_is_const_like(block) {
    wgsl_graph_order_push_unique(ordered, emitted, name)
    for dependency in dependencies {
      wgsl_declaration_graph_visit_import_order(
        declaration_blocks, declaration_names, dependency, visiting, emitted, ordered,
      )
    }
  } else {
    for dependency in dependencies {
      wgsl_declaration_graph_visit_import_order(
        declaration_blocks, declaration_names, dependency, visiting, emitted, ordered,
      )
    }
    wgsl_graph_order_push_unique(ordered, emitted, name)
  }
  ignore(visiting.remove(name))
}

///|
fn wgsl_graph_const_like_source_order(
  declaration_blocks : Array[WgslGraphBlock],
  included_names : @set.Set[String],
) -> Array[String] {
  let ordered : Array[String] = []
  for block in declaration_blocks {
    if included_names.contains(block.name()) &&
      wgsl_graph_block_is_const_like(block) {
      ordered.push(block.name())
    }
  }
  ordered
}

///|
fn wgsl_declaration_graph_normalize_const_like_order(
  ordered : Array[String],
  declaration_blocks : Array[WgslGraphBlock],
  included_names : @set.Set[String],
) -> Array[String] {
  let source_order = wgsl_graph_const_like_source_order(
    declaration_blocks, included_names,
  )
  if source_order.length() < 2 {
    return ordered
  }
  let const_like_emitted : @set.Set[String] = @set.Set([])
  for name in ordered {
    match wgsl_declaration_graph_block_named(declaration_blocks, name) {
      Some(block) if wgsl_graph_block_is_const_like(block) =>
        const_like_emitted.add(name)
      _ => ()
    }
  }
  let const_like_names : Array[String] = []
  for name in source_order {
    if const_like_emitted.contains(name) {
      const_like_names.push(name)
    }
  }
  let normalized : Array[String] = []
  let mut const_index = 0
  for name in ordered {
    match wgsl_declaration_graph_block_named(declaration_blocks, name) {
      Some(block) if wgsl_graph_block_is_const_like(block) => {
        normalized.push(const_like_names[const_index])
        const_index = const_index + 1
      }
      _ => normalized.push(name)
    }
  }
  normalized
}

///|
fn wgsl_declaration_graph_reachable_import_order(
  declaration_blocks : Array[WgslGraphBlock],
  requested_items : Array[String],
  included_names : @set.Set[String],
) -> Array[String] {
  let ordered : Array[String] = []
  let emitted : @set.Set[String] = @set.Set([])
  let visiting : @set.Set[String] = @set.Set([])
  let declaration_names : @set.Set[String] = @set.Set([])
  for block in declaration_blocks {
    if block.name() != "" {
      declaration_names.add(block.name())
    }
  }
  for block in declaration_blocks {
    let name = block.name()
    if included_names.contains(name) && requested_items.contains(name) {
      wgsl_declaration_graph_visit_import_order(
        declaration_blocks, declaration_names, name, visiting, emitted, ordered,
      )
    }
  }
  for requested_item in requested_items {
    if included_names.contains(requested_item) {
      wgsl_declaration_graph_visit_import_order(
        declaration_blocks, declaration_names, requested_item, visiting, emitted,
        ordered,
      )
    }
  }
  for block in declaration_blocks {
    let name = block.name()
    if included_names.contains(name) {
      wgsl_graph_order_push_unique(ordered, emitted, name)
    }
  }
  wgsl_declaration_graph_normalize_const_like_order(
    ordered, declaration_blocks, included_names,
  )
}

///|
pub fn collect_wgsl_named_declarations_strict(
  source : String,
) -> Array[WgslEmittedDeclaration] raise WgslParseError {
  let graph = build_wgsl_declaration_graph_strict(source)
  let declarations : Array[WgslEmittedDeclaration] = []
  let mut generated_start = 0
  for import_block in graph.import_blocks {
    generated_start = generated_start +
      emit_wgsl_graph_block_canonical(import_block).length()
  }
  for block in graph.declaration_blocks {
    let emitted_block = emit_wgsl_graph_block_canonical(block)
    let block_generated_start = generated_start
    generated_start = generated_start + emitted_block.length()
    if block.is_symbol_origin() {
      declarations.push(WgslEmittedDeclaration::{
        name: block.name(),
        is_type_declaration: block.is_type_declaration(),
        generated_start: block_generated_start,
        generated_end: generated_start,
      })
    }
  }
  declarations
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
fn strip_wgsl_import_declarations_strict(
  source : String,
) -> String raise WgslParseError {
  strip_wgsl_import_declarations_from_source_unit(
    source,
    parse_wgsl_translation_unit_strict(source),
  )
}

///|
pub fn collect_wgsl_source_catalog_declarations_strict(
  source : String,
) -> Array[WgslEmittedDeclaration] raise WgslParseError {
  collect_wgsl_named_declarations_strict(
    strip_wgsl_import_declarations_strict(source),
  )
}

///|
fn extract_wgsl_module_item_extraction_from_graph(
  source : String,
  graph : WgslDeclarationGraph,
  requested_items : Array[String],
) -> WgslModuleItemExtraction {
  let origins : Array[WgslModuleItemOrigin] = []
  if requested_items.length() == 0 {
    for block in graph.declaration_blocks {
      if block.is_symbol_origin() {
        origins.push(WgslModuleItemOrigin::{
          name: block.name(),
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
  let (included_names, _, _) = wgsl_reachable_declaration_map(
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
    return WgslModuleItemExtraction::{ source: "", origins }
  }
  let mut out = emit_wgsl_import_blocks_for_item_extraction(source, graph)
  for block in graph.declaration_blocks {
    if block.name() == "" {
      out = out + emit_wgsl_graph_block_canonical(block)
      if block.is_symbol_origin() {
        origins.push(WgslModuleItemOrigin::{
          name: block.name(),
          source_start: block.start,
          source_end: block.end,
        })
      }
    }
  }
  let reachable_order = wgsl_declaration_graph_reachable_import_order(
    graph.declaration_blocks,
    requested_items,
    included_names,
  )
  for name in reachable_order {
    guard wgsl_declaration_graph_block_named(graph.declaration_blocks, name)
      is Some(block) else {
      continue
    }
    guard included_names.contains(block.name()) else { continue }
    out = out + emit_wgsl_graph_block_canonical(block)
    if block.is_symbol_origin() {
      origins.push(WgslModuleItemOrigin::{
        name: block.name(),
        source_start: block.start,
        source_end: block.end,
      })
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
