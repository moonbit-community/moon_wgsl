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
  priv kind : WgslSourceOriginKind
  priv source_start : Int
  priv source_end : Int
}

///|
pub struct WgslModuleItemExtraction {
  priv source : String
  priv origins : Array[WgslModuleItemOrigin]
  priv references : Array[WgslReferencePath]
}

///|
pub struct WgslModuleItemExtractor {
  priv source : String
  priv graph : WgslDeclarationGraph
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
pub fn WgslModuleItemOrigin::kind(
  self : WgslModuleItemOrigin,
) -> WgslSourceOriginKind {
  self.kind
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
pub fn WgslModuleItemExtraction::references(
  self : WgslModuleItemExtraction,
) -> Array[WgslReferencePath] {
  self.references.copy()
}

///|
pub fn WgslModuleItemExtraction::declarations(
  self : WgslModuleItemExtraction,
) -> Array[WgslEmittedDeclaration] {
  let declarations : Array[WgslEmittedDeclaration] = []
  for origin in self.origins {
    if origin.name() != "" {
      declarations.push({
        name: origin.name(),
        is_type_declaration: origin.kind() == Type,
        generated_start: origin.source_start(),
        generated_end: origin.source_end(),
      })
    }
  }
  declarations
}

///|
pub fn new_wgsl_module_item_extractor_from_unit(
  source : String,
  unit : WgslTranslationUnit,
) -> WgslModuleItemExtractor {
  { source, graph: build_wgsl_declaration_graph_from_unit(source, unit) }
}

///|
pub fn WgslModuleItemExtractor::extract(
  self : WgslModuleItemExtractor,
  requested_items : Array[String],
) -> WgslModuleItemExtraction {
  extract_wgsl_module_item_extraction_from_graph(
    self.source,
    self.graph,
    requested_items,
  )
}

///|
pub fn WgslModuleItemExtractor::naga_dependency_pulled_item_origins(
  self : WgslModuleItemExtractor,
) -> Array[WgslModuleItemOrigin] {
  collect_wgsl_naga_dependency_pulled_item_origins_from_graph(self.graph)
}

///|
fn wgsl_declaration_graph_block_tokens(
  source_tokens : Array[WgslToken],
  token_start : Int,
  start : Int,
  end_ : Int,
) -> (Array[WgslToken], Int) {
  let tokens : Array[WgslToken] = []
  let mut first_candidate = token_start
  while first_candidate < source_tokens.length() &&
        source_tokens[first_candidate].end() <= start {
    first_candidate = first_candidate + 1
  }
  let mut index = first_candidate
  while index < source_tokens.length() && source_tokens[index].pos() < end_ {
    let token = source_tokens[index]
    if token.pos() >= start && token.end() <= end_ {
      tokens.push(token)
    }
    index = index + 1
  }
  (tokens, first_candidate)
}

///|
fn build_wgsl_declaration_graph_from_unit(
  source : String,
  unit : WgslTranslationUnit,
) -> WgslDeclarationGraph {
  let import_blocks : Array[WgslGraphBlock] = []
  let declaration_blocks : Array[WgslGraphBlock] = []
  let source_tokens = tokenize_wgsl_absolute_source(source)
  let mut token_start = 0
  for decl in unit.declarations() {
    let (tokens, next_token_start) = wgsl_declaration_graph_block_tokens(
      source_tokens,
      token_start,
      decl.start(),
      decl.end(),
    )
    token_start = next_token_start
    let graph_block = WgslGraphBlock::{
      tokens,
      start: decl.start(),
      end: decl.end(),
      data: decl.data(),
    }
    match decl.kind() {
      Import => import_blocks.push(graph_block)
      Function
      | GlobalVariable
      | Const
      | Override
      | Struct
      | TypeAlias
      | ConstAssert
      | Unknown => declaration_blocks.push(graph_block)
      Directive =>
        match decl.data() {
          Directive(directive) =>
            if directive.kind() == Import {
              import_blocks.push(graph_block)
            } else if directive.kind() == Enable ||
              directive.kind() == Requires ||
              directive.kind() == Diagnostic {
              declaration_blocks.push(graph_block)
            }
          _ => ()
        }
      _ => ()
    }
  }

  { import_blocks, declaration_blocks }
}

///|
fn WgslGraphBlock::name(self : WgslGraphBlock) -> String {
  wgsl_decl_data_name(self.data)
}

///|
fn WgslGraphBlock::is_type_declaration(self : WgslGraphBlock) -> Bool {
  match self.data {
    Struct(_) | TypeAlias(_) => true
    _ => false
  }
}

///|
fn WgslGraphBlock::source_origin_kind(
  self : WgslGraphBlock,
) -> WgslSourceOriginKind {
  match self.data {
    Struct(_) | TypeAlias(_) => Type
    Const(_) => Constant
    Override(_) => Override
    GlobalVariable(_) => GlobalVariable
    Function(_) => Function
    Directive(_) | Import(_) | ConstAssert(_) | Raw => Other
  }
}

///|
fn WgslGraphBlock::is_symbol_origin(self : WgslGraphBlock) -> Bool {
  match self.data {
    Function(function) => function.qualifier() != Some(Override)
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
  _source : String,
  graph : WgslDeclarationGraph,
) -> String {
  let out = StringBuilder::new()
  for import_block in graph.import_blocks {
    out.write_string(emit_wgsl_graph_block_canonical(import_block))
  }
  out.to_string()
}

///|
fn wgsl_reachable_declaration_map(
  declaration_blocks : Array[WgslGraphBlock],
  root_items : Array[String],
) -> (@set.Set[String], Array[String], Array[String]) {
  let included_names : @set.Set[String] = Set([])
  let declarations : Array[WgslGlobalDecl] = []
  for block in declaration_blocks {
    declarations.push(
      WgslGlobalDecl(Unknown, block.data, block.start, block.end),
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
    Const(_) | Override(_) => true
    _ => false
  }
}

///|
fn wgsl_graph_block_reference_paths(
  blocks : Array[WgslGraphBlock],
) -> Array[WgslReferencePath] {
  let identifiers : Array[WgslIdent] = []
  for block in blocks {
    collect_wgsl_decl_identifier_nodes(block.data, identifiers)
  }
  wgsl_graph_sort_identifier_nodes_by_source(identifiers)
  let references : Array[WgslReferencePath] = []
  for identifier in identifiers {
    match WgslReferencePath::from_text(identifier.name()) {
      Some(path) => references.push(path)
      None => ()
    }
  }
  references
}

///|
fn wgsl_graph_block_matches_arena_category(
  block : WgslGraphBlock,
  category : WgslSourceOriginKind,
) -> Bool {
  match category {
    Type => block.source_origin_kind() == Type
    Constant => block.source_origin_kind() == Constant
    Override => block.source_origin_kind() == Override
    GlobalVariable => block.source_origin_kind() == GlobalVariable
    Function => block.source_origin_kind() == Function
    Other => block.source_origin_kind() == Other
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
  declaration_blocks : Array[WgslGraphBlock],
  declaration_names : @set.Set[String],
) -> Array[String] {
  let dependencies : Array[String] = []
  let self_name = block.name()
  let identifiers : Array[WgslIdent] = []
  collect_wgsl_decl_identifier_nodes(block.data, identifiers)
  wgsl_graph_sort_identifier_nodes_by_source(identifiers)
  wgsl_analysis_collect_identifier_dependencies(
    identifiers, self_name, declaration_names, dependencies,
  )
  if wgsl_graph_block_is_const_like(block) {
    return dependencies
  }
  let ordered : Array[String] = []
  for dependency in dependencies {
    match wgsl_declaration_graph_block_named(declaration_blocks, dependency) {
      Some(dependency_block) if wgsl_graph_block_is_const_like(dependency_block) =>
        wgsl_analysis_string_list_push_unique(ordered, dependency)
      _ => ()
    }
  }
  for dependency in dependencies {
    match wgsl_declaration_graph_block_named(declaration_blocks, dependency) {
      Some(dependency_block) if wgsl_graph_block_is_const_like(dependency_block) =>
        ()
      _ => wgsl_analysis_string_list_push_unique(ordered, dependency)
    }
  }
  return ordered
}

///|
fn wgsl_graph_sort_identifier_nodes_by_source(nodes : Array[WgslIdent]) -> Unit {
  nodes.sort_by(fn(lhs, rhs) {
    let start_compare = lhs.start() - rhs.start()
    if start_compare != 0 {
      return start_compare
    }
    let end_compare = lhs.end() - rhs.end()
    if end_compare != 0 {
      return end_compare
    }
    String::compare(lhs.name(), rhs.name())
  })
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
    block, declaration_blocks, declaration_names,
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
fn wgsl_declaration_graph_visit_naga_dependency_order(
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
    block, declaration_blocks, declaration_names,
  )
  for dependency in dependencies {
    wgsl_declaration_graph_visit_naga_dependency_order(
      declaration_blocks, declaration_names, dependency, visiting, emitted, ordered,
    )
  }
  wgsl_graph_order_push_unique(ordered, emitted, name)
  ignore(visiting.remove(name))
}

///|
fn wgsl_declaration_graph_naga_dependency_order(
  declaration_blocks : Array[WgslGraphBlock],
) -> Array[String] {
  let ordered : Array[String] = []
  let emitted : @set.Set[String] = Set([])
  let visiting : @set.Set[String] = Set([])
  let declaration_names : @set.Set[String] = Set([])
  for block in declaration_blocks {
    let name = block.name()
    if name != "" {
      declaration_names.add(name)
    }
  }
  for block in declaration_blocks {
    let name = block.name()
    if name != "" {
      wgsl_declaration_graph_visit_naga_dependency_order(
        declaration_blocks, declaration_names, name, visiting, emitted, ordered,
      )
    }
  }
  ordered
}

///|
fn wgsl_declaration_graph_reachable_import_order(
  declaration_blocks : Array[WgslGraphBlock],
  requested_items : Array[String],
  included_names : @set.Set[String],
) -> Array[String] {
  let ordered : Array[String] = []
  let emitted : @set.Set[String] = Set([])
  let visiting : @set.Set[String] = Set([])
  let declaration_names : @set.Set[String] = Set([])
  for block in declaration_blocks {
    if block.name() != "" {
      declaration_names.add(block.name())
    }
  }
  for
    category in [
      WgslSourceOriginKind::Type,
      Constant,
      Override,
      GlobalVariable,
      Function,
    ] {
    for block in declaration_blocks {
      let name = block.name()
      if included_names.contains(name) &&
        requested_items.contains(name) &&
        wgsl_graph_block_matches_arena_category(block, category) {
        wgsl_declaration_graph_visit_import_order(
          declaration_blocks, declaration_names, name, visiting, emitted, ordered,
        )
      }
    }
  }
  for block in declaration_blocks {
    let name = block.name()
    if included_names.contains(name) {
      wgsl_graph_order_push_unique(ordered, emitted, name)
    }
  }
  ordered
}

///|
fn collect_wgsl_named_declarations_from_graph(
  graph : WgslDeclarationGraph,
) -> Array[WgslEmittedDeclaration] {
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
      declarations.push({
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
pub fn collect_wgsl_named_declarations_from_unit(
  source : String,
  unit : WgslTranslationUnit,
) -> Array[WgslEmittedDeclaration] {
  collect_wgsl_named_declarations_from_graph(
    build_wgsl_declaration_graph_from_unit(source, unit),
  )
}

///|
pub fn collect_wgsl_named_declarations_strict(
  source : String,
) -> Array[WgslEmittedDeclaration] raise WgslParseError {
  collect_wgsl_named_declarations_from_unit(
    source,
    parse_wgsl_translation_unit_strict(source),
  )
}

///|
fn strip_wgsl_import_declarations_from_source_unit(
  source : String,
  unit : WgslTranslationUnit,
) -> String {
  let out = StringBuilder::new()
  let source_tokens = tokenize_wgsl_absolute_source(source)
  let mut token_start = 0
  for decl in unit.declarations() {
    let skip = match decl.data() {
      Import(_) => true
      Directive(directive) => directive.kind() == DefineImportPath
      _ => false
    }
    if !skip {
      let (tokens, next_token_start) = wgsl_declaration_graph_block_tokens(
        source_tokens,
        token_start,
        decl.start(),
        decl.end(),
      )
      token_start = next_token_start
      out.write_string(
        emit_wgsl_graph_block_canonical({
          tokens,
          start: decl.start(),
          end: decl.end(),
          data: decl.data(),
        }),
      )
    } else {
      while token_start < source_tokens.length() &&
            source_tokens[token_start].end() <= decl.end() {
        token_start = token_start + 1
      }
    }
  }
  out.to_string()
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
        origins.push({
          name: block.name(),
          kind: block.source_origin_kind(),
          source_start: block.start,
          source_end: block.end,
        })
      }
    }
    return {
      source: emit_wgsl_graph_blocks_canonical(graph.declaration_blocks),
      origins,
      references: wgsl_graph_block_reference_paths(graph.declaration_blocks),
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
    return { source: "", origins, references: [] }
  }
  let out = StringBuilder::new()
  out.write_string(emit_wgsl_import_blocks_for_item_extraction(source, graph))
  let included_blocks : Array[WgslGraphBlock] = []
  for block in graph.declaration_blocks {
    if block.name() == "" {
      out.write_string(emit_wgsl_graph_block_canonical(block))
      included_blocks.push(block)
      if block.is_symbol_origin() {
        origins.push({
          name: block.name(),
          kind: block.source_origin_kind(),
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
    out.write_string(emit_wgsl_graph_block_canonical(block))
    included_blocks.push(block)
    if block.is_symbol_origin() {
      origins.push({
        name: block.name(),
        kind: block.source_origin_kind(),
        source_start: block.start,
        source_end: block.end,
      })
    }
  }
  {
    source: out.to_string(),
    origins,
    references: wgsl_graph_block_reference_paths(included_blocks),
  }
}

///|
pub fn collect_wgsl_naga_dependency_ordered_item_origins_strict(
  source : String,
) -> Array[WgslModuleItemOrigin] raise WgslParseError {
  let graph = build_wgsl_declaration_graph_strict(source)
  let origins : Array[WgslModuleItemOrigin] = []
  let ordered_names = wgsl_declaration_graph_naga_dependency_order(
    graph.declaration_blocks,
  )
  for name in ordered_names {
    guard wgsl_declaration_graph_block_named(graph.declaration_blocks, name)
      is Some(block) else {
      continue
    }
    if block.is_symbol_origin() {
      origins.push({
        name: block.name(),
        kind: block.source_origin_kind(),
        source_start: block.start,
        source_end: block.end,
      })
    }
  }
  origins
}

///|
pub fn collect_wgsl_naga_dependency_pulled_item_origins_strict(
  source : String,
) -> Array[WgslModuleItemOrigin] raise WgslParseError {
  let graph = build_wgsl_declaration_graph_strict(source)
  collect_wgsl_naga_dependency_pulled_item_origins_from_graph(graph)
}

///|
fn collect_wgsl_naga_dependency_pulled_item_origins_from_graph(
  graph : WgslDeclarationGraph,
) -> Array[WgslModuleItemOrigin] {
  let declaration_names : @set.Set[String] = Set([])
  for block in graph.declaration_blocks {
    let name = block.name()
    if name != "" {
      declaration_names.add(name)
    }
  }
  let pulled : Map[String, WgslModuleItemOrigin] = Map([])
  for block in graph.declaration_blocks {
    let dependencies = wgsl_graph_block_dependencies_in_ast_order(
      block,
      graph.declaration_blocks,
      declaration_names,
    )
    for dependency in dependencies {
      guard wgsl_declaration_graph_block_named(
          graph.declaration_blocks,
          dependency,
        )
        is Some(dependency_block) else {
        continue
      }
      if dependency_block.start <= block.start {
        continue
      }
      wgsl_declaration_graph_mark_dependency_pull(
        graph.declaration_blocks,
        declaration_names,
        dependency,
        block.start,
        block.end,
        Set([]),
        pulled,
      )
    }
  }
  let origins : Array[WgslModuleItemOrigin] = []
  for block in graph.declaration_blocks {
    match pulled.get(block.name()) {
      Some(origin) => origins.push(origin)
      None => ()
    }
  }
  origins
}

///|
fn wgsl_declaration_graph_mark_dependency_pull(
  declaration_blocks : Array[WgslGraphBlock],
  declaration_names : @set.Set[String],
  name : String,
  pull_start : Int,
  pull_end : Int,
  visiting : @set.Set[String],
  pulled : Map[String, WgslModuleItemOrigin],
) -> Unit {
  if name == "" || visiting.contains(name) {
    return
  }
  guard wgsl_declaration_graph_block_named(declaration_blocks, name)
    is Some(block) else {
    return
  }
  visiting.add(name)
  let dependencies = wgsl_graph_block_dependencies_in_ast_order(
    block, declaration_blocks, declaration_names,
  )
  for dependency in dependencies {
    wgsl_declaration_graph_mark_dependency_pull(
      declaration_blocks, declaration_names, dependency, pull_start, pull_end, visiting,
      pulled,
    )
  }
  match pulled.get(name) {
    Some(existing) if existing.source_start() <= pull_start => ()
    _ =>
      pulled.set(name, {
        name,
        kind: block.source_origin_kind(),
        source_start: pull_start,
        source_end: pull_end,
      })
  }
  ignore(visiting.remove(name))
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
