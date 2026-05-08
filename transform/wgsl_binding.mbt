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
priv enum WgslRenameRuleKind {
  GlobalDeclarationAndReferences
  ReferencesOnly
  FunctionBodyReferencesOnly
  FunctionLocal
}

///|
priv struct WgslRenameRule {
  from_name : String
  to_name : String
  kind : WgslRenameRuleKind
}

///|
priv struct WgslRenamePlan {
  rules : Array[WgslRenameRule]
}

///|
priv struct WgslRenameMaps {
  global_declaration_rules : Array[WgslRenameRule]
  reference_rules : Array[WgslRenameRule]
  function_body_reference_rules : Array[WgslRenameRule]
  function_local_rules : Array[WgslRenameRule]
}

///|
pub struct WgslReferenceRewritePlan {
  priv bindings : Array[WgslReferenceRewriteBinding]
  priv virtual_overrides : Array[WgslVirtualOverrideRewriteBinding]
}

///|
pub struct WgslReferencePath {
  priv segments : Array[String]
} derive(Debug)

///|
priv struct WgslReferenceRewriteBinding {
  reference_path : WgslReferencePath
  final_name : String
  identity : WgslIrSymbolIdentity
}

///|
priv struct WgslVirtualOverrideRewriteBinding {
  raw_target_name : String
  target_name : String
  override_name : String
}

///|
fn WgslReferenceRewriteBinding::key(
  self : WgslReferenceRewriteBinding,
) -> String {
  "\{self.identity.key()}|\{self.reference_path.text()}|\{self.final_name}"
}

///|
fn WgslVirtualOverrideRewriteBinding::key(
  self : WgslVirtualOverrideRewriteBinding,
) -> String {
  "\{self.raw_target_name}|\{self.target_name}|\{self.override_name}"
}

///|
pub fn WgslReferenceRewritePlan::WgslReferenceRewritePlan() -> WgslReferenceRewritePlan {
  WgslReferenceRewritePlan::{ bindings: [], virtual_overrides: [] }
}

///|
pub fn WgslReferencePath::from_segments(
  segments : Array[String],
) -> WgslReferencePath? {
  let normalized : Array[String] = []
  for segment in segments {
    let segment = segment.trim().to_owned()
    if segment == "" {
      return None
    }
    normalized.push(segment)
  }
  if normalized.length() == 0 {
    None
  } else {
    Some(WgslReferencePath::{ segments: normalized })
  }
}

///|
pub fn WgslReferencePath::from_text(text : String) -> WgslReferencePath? {
  let segments : Array[String] = []
  for raw_segment in text.trim().split("::") {
    let segment = raw_segment.trim().to_owned()
    if segment == "" {
      return None
    }
    segments.push(segment)
  }
  WgslReferencePath::from_segments(segments)
}

///|
pub fn WgslReferencePath::text(self : WgslReferencePath) -> String {
  self.segments.join("::")
}

///|
fn WgslReferencePath::matches(
  self : WgslReferencePath,
  other : WgslReferencePath,
) -> Bool {
  if self.segments.length() != other.segments.length() {
    return false
  }
  for i in 0..<self.segments.length() {
    if self.segments[i] != other.segments[i] {
      return false
    }
  }
  true
}

///|
pub fn WgslReferenceRewritePlan::add_symbol_reference_binding(
  self : WgslReferenceRewritePlan,
  identity : WgslIrSymbolIdentity,
  reference_path : WgslReferencePath,
  final_name : String,
) -> Unit {
  let final_name = final_name.trim().to_owned()
  if final_name == "" || reference_path.text() == final_name {
    return
  }
  let binding = WgslReferenceRewriteBinding::{
    reference_path,
    final_name,
    identity,
  }
  let key = binding.key()
  for existing in self.bindings {
    if existing.key() == key {
      return
    }
  }
  self.bindings.push(binding)
}

///|
pub fn WgslReferenceRewritePlan::add_virtual_override_binding(
  self : WgslReferenceRewritePlan,
  raw_target_name : String,
  target_name : String,
  override_name : String,
) -> Unit {
  let raw_target_name = raw_target_name.trim().to_owned()
  let target_name = target_name.trim().to_owned()
  let override_name = override_name.trim().to_owned()
  if raw_target_name == "" || target_name == "" || override_name == "" {
    return
  }
  let binding = WgslVirtualOverrideRewriteBinding::{
    raw_target_name,
    target_name,
    override_name,
  }
  let key = binding.key()
  for existing in self.virtual_overrides {
    if existing.key() == key {
      return
    }
  }
  self.virtual_overrides.push(binding)
}

///|
fn WgslRenamePlan::empty() -> WgslRenamePlan {
  WgslRenamePlan::{ rules: [] }
}

///|
fn WgslRenamePlan::is_empty(self : WgslRenamePlan) -> Bool {
  self.rules.length() == 0
}

///|
fn WgslRenamePlan::add(
  self : WgslRenamePlan,
  from_name : String,
  to_name : String,
  kind : WgslRenameRuleKind,
) -> Unit {
  let from_name = from_name.trim().to_owned()
  let to_name = to_name.trim().to_owned()
  if from_name == "" || to_name == "" || from_name == to_name {
    return
  }
  self.rules.push(WgslRenameRule::{ from_name, to_name, kind })
}

///|
fn WgslReferenceRewritePlan::target_for_reference(
  self : WgslReferenceRewritePlan,
  from_name : String,
) -> String? {
  match WgslReferencePath::from_text(from_name) {
    Some(reference_path) =>
      match wgsl_symbol_binding_for_reference(self.bindings, reference_path) {
        Some(binding) => Some(binding.final_name)
        None => None
      }
    None => None
  }
}

///|
fn WgslReferenceRewritePlan::has_symbol_bindings(
  self : WgslReferenceRewritePlan,
) -> Bool {
  self.bindings.length() > 0
}

///|
fn WgslReferenceRewritePlan::virtual_override_name_for_target(
  self : WgslReferenceRewritePlan,
  raw_target_name : String,
  target_name : String,
) -> String? {
  let mut override_name : String? = None
  for binding in self.virtual_overrides {
    if binding.raw_target_name != raw_target_name &&
      binding.target_name != target_name {
      continue
    }
    if binding.target_name != target_name {
      continue
    }
    match override_name {
      Some(existing) if existing != binding.override_name => return None
      Some(_) => ()
      None => override_name = Some(binding.override_name)
    }
  }
  override_name
}

///|
fn build_wgsl_rename_maps(plan : WgslRenamePlan) -> WgslRenameMaps {
  let global_declaration_rules : Array[WgslRenameRule] = []
  let reference_rules : Array[WgslRenameRule] = []
  let function_body_reference_rules : Array[WgslRenameRule] = []
  let function_local_rules : Array[WgslRenameRule] = []
  for rule in plan.rules {
    match rule.kind {
      GlobalDeclarationAndReferences => {
        global_declaration_rules.push(rule)
        reference_rules.push(rule)
      }
      ReferencesOnly => reference_rules.push(rule)
      FunctionBodyReferencesOnly => function_body_reference_rules.push(rule)
      FunctionLocal => function_local_rules.push(rule)
    }
  }
  WgslRenameMaps::{
    global_declaration_rules,
    reference_rules,
    function_body_reference_rules,
    function_local_rules,
  }
}

///|
fn wgsl_rename_rules_target(
  rules : Array[WgslRenameRule],
  from_name : String,
) -> String? {
  let mut target : String? = None
  for rule in rules {
    if rule.from_name != from_name {
      continue
    }
    match target {
      Some(existing) if existing != rule.to_name => return None
      Some(_) => ()
      None => target = Some(rule.to_name)
    }
  }
  target
}

///|
fn wgsl_symbol_binding_for_reference(
  bindings : Array[WgslReferenceRewriteBinding],
  reference_path : WgslReferencePath,
) -> WgslReferenceRewriteBinding? {
  let mut target : WgslReferenceRewriteBinding? = None
  for binding in bindings {
    if !binding.reference_path.matches(reference_path) {
      continue
    }
    let current_identity_key = binding.identity.key()
    match target {
      Some(existing) if existing.final_name != binding.final_name =>
        if existing.identity.key() == current_identity_key {
          target = Some(binding)
        } else {
          return None
        }
      Some(existing) =>
        if existing.identity.key() != current_identity_key {
          return None
        }
      None => target = Some(binding)
    }
  }
  target
}

///|
fn collect_wgsl_bound_rewrite_nodes_from_identifiers(
  identifiers : Array[WgslIdent],
  bindings : Array[WgslReferenceRewriteBinding],
  nodes : Array[WgslTokenReplacement],
) -> Unit {
  for identifier in identifiers {
    match WgslReferencePath::from_text(identifier.name()) {
      Some(reference_path) =>
        match wgsl_symbol_binding_for_reference(bindings, reference_path) {
          Some(binding) =>
            nodes.push(
              WgslTokenReplacement(
                identifier.start(),
                identifier.end(),
                binding.final_name,
              ),
            )
          None => ()
        }
      None => ()
    }
  }
}

///|
fn collect_wgsl_rewrite_nodes_from_identifiers(
  identifiers : Array[WgslIdent],
  rules : Array[WgslRenameRule],
  nodes : Array[WgslTokenReplacement],
) -> Unit {
  for identifier in identifiers {
    match wgsl_rename_rules_target(rules, identifier.name()) {
      Some(replacement) =>
        nodes.push(
          WgslTokenReplacement(
            identifier.start(),
            identifier.end(),
            replacement,
          ),
        )
      None => ()
    }
  }
}

///|
fn collect_wgsl_rewrite_nodes_from_expr_ref(
  expr_ref : WgslExprRef?,
  rules : Array[WgslRenameRule],
  nodes : Array[WgslTokenReplacement],
) -> Unit {
  match expr_ref {
    Some(expr) =>
      collect_wgsl_rewrite_nodes_from_identifiers(
        expr.identifiers(),
        rules,
        nodes,
      )
    None => ()
  }
}

///|
fn collect_wgsl_rewrite_nodes_from_type_ref(
  ty_ref : WgslTypeRef?,
  rules : Array[WgslRenameRule],
  nodes : Array[WgslTokenReplacement],
) -> Unit {
  match ty_ref {
    Some(ty) => {
      match ty.atom().identifier() {
        Some(identifier) =>
          match wgsl_rename_rules_target(rules, identifier.name()) {
            Some(replacement) =>
              nodes.push(
                WgslTokenReplacement(
                  identifier.start(),
                  identifier.end(),
                  replacement,
                ),
              )
            None => ()
          }
        None => ()
      }
      for argument in ty.template_arguments() {
        match argument {
          Type(ty) =>
            collect_wgsl_rewrite_nodes_from_type_ref(Some(ty), rules, nodes)
          Expression(expr) =>
            collect_wgsl_rewrite_nodes_from_expr_ref(Some(expr), rules, nodes)
        }
      }
    }
    None => ()
  }
}

///|
fn collect_wgsl_local_binding_rewrite_node(
  binding : WgslLocalDeclaration,
  source_rules : Array[WgslRenameRule],
  active_rules : Array[WgslRenameRule],
  nodes : Array[WgslTokenReplacement],
) -> Unit {
  match wgsl_rename_rules_target(source_rules, binding.name().name()) {
    Some(replacement) => {
      active_rules.push(WgslRenameRule::{
        from_name: binding.name().name(),
        to_name: replacement,
        kind: FunctionLocal,
      })
      nodes.push(
        WgslTokenReplacement(
          binding.name().start(),
          binding.name().end(),
          replacement,
        ),
      )
    }
    None => ()
  }
}

///|
fn collect_wgsl_statement_local_rewrite_nodes(
  statement : WgslStatement,
  active_rules : Array[WgslRenameRule],
  source_rules : Array[WgslRenameRule],
  nodes : Array[WgslTokenReplacement],
) -> Unit {
  let block_rules = active_rules.copy()
  for binding in statement.local_bindings() {
    collect_wgsl_rewrite_nodes_from_type_ref(
      binding.ty_ref(),
      block_rules,
      nodes,
    )
    collect_wgsl_rewrite_nodes_from_expr_ref(
      binding.initializer_ref(),
      block_rules,
      nodes,
    )
    collect_wgsl_local_binding_rewrite_node(
      binding, source_rules, block_rules, nodes,
    )
  }
  for expr_ref in statement.expression_refs() {
    collect_wgsl_rewrite_nodes_from_expr_ref(Some(expr_ref), block_rules, nodes)
  }
  for block in statement.blocks() {
    collect_wgsl_block_local_rewrite_nodes(
      block, block_rules, source_rules, nodes,
    )
  }
}

///|
fn collect_wgsl_block_local_rewrite_nodes(
  block : WgslBlock,
  inherited_rules : Array[WgslRenameRule],
  source_rules : Array[WgslRenameRule],
  nodes : Array[WgslTokenReplacement],
) -> Unit {
  let active_rules = inherited_rules.copy()
  for statement in block.statements() {
    collect_wgsl_statement_local_rewrite_nodes(
      statement, active_rules, source_rules, nodes,
    )
    for binding in statement.exported_local_bindings() {
      match wgsl_rename_rules_target(source_rules, binding.name().name()) {
        Some(replacement) =>
          active_rules.push(WgslRenameRule::{
            from_name: binding.name().name(),
            to_name: replacement,
            kind: FunctionLocal,
          })
        None => ()
      }
    }
  }
}

///|
fn collect_wgsl_function_local_rewrite_nodes(
  data : WgslGlobalDeclData,
  rules : Array[WgslRenameRule],
  nodes : Array[WgslTokenReplacement],
) -> Unit {
  match data {
    WgslGlobalDeclData::Function(function) => {
      let active_rules : Array[WgslRenameRule] = []
      for argument in function.arguments() {
        match wgsl_rename_rules_target(rules, argument.name().name()) {
          Some(replacement) => {
            active_rules.push(WgslRenameRule::{
              from_name: argument.name().name(),
              to_name: replacement,
              kind: FunctionLocal,
            })
            nodes.push(
              WgslTokenReplacement(
                argument.name().start(),
                argument.name().end(),
                replacement,
              ),
            )
          }
          None => ()
        }
      }
      collect_wgsl_block_local_rewrite_nodes(
        function.body(),
        active_rules,
        rules,
        nodes,
      )
    }
    _ => ()
  }
}

///|
fn collect_wgsl_function_body_reference_rewrite_nodes(
  data : WgslGlobalDeclData,
  rules : Array[WgslRenameRule],
  nodes : Array[WgslTokenReplacement],
) -> Unit {
  match data {
    WgslGlobalDeclData::Function(function) => {
      let identifiers : Array[WgslIdent] = []
      collect_wgsl_function_body_identifier_nodes(function, identifiers)
      collect_wgsl_rewrite_nodes_from_identifiers(identifiers, rules, nodes)
    }
    _ => ()
  }
}

///|
fn collect_wgsl_block_rewrite_nodes(
  data : WgslGlobalDeclData,
  maps : WgslRenameMaps,
  nodes : Array[WgslTokenReplacement],
) -> Unit {
  let identifiers : Array[WgslIdent] = []
  collect_wgsl_decl_global_declared_identifier_nodes(data, identifiers)
  collect_wgsl_rewrite_nodes_from_identifiers(
    identifiers,
    maps.global_declaration_rules,
    nodes,
  )
  identifiers.clear()
  collect_wgsl_decl_identifier_nodes(data, identifiers)
  collect_wgsl_rewrite_nodes_from_identifiers(
    identifiers,
    maps.reference_rules,
    nodes,
  )
  collect_wgsl_function_body_reference_rewrite_nodes(
    data,
    maps.function_body_reference_rules,
    nodes,
  )
  collect_wgsl_function_local_rewrite_nodes(
    data,
    maps.function_local_rules,
    nodes,
  )
}

///|
fn collect_wgsl_bound_block_rewrite_nodes(
  data : WgslGlobalDeclData,
  bindings : Array[WgslReferenceRewriteBinding],
  rewrite_declarations : Bool,
  nodes : Array[WgslTokenReplacement],
) -> Unit {
  let identifiers : Array[WgslIdent] = []
  if rewrite_declarations {
    collect_wgsl_decl_global_declared_identifier_nodes(data, identifiers)
    collect_wgsl_bound_rewrite_nodes_from_identifiers(
      identifiers, bindings, nodes,
    )
    identifiers.clear()
  }
  collect_wgsl_decl_identifier_nodes(data, identifiers)
  collect_wgsl_bound_rewrite_nodes_from_identifiers(
    identifiers, bindings, nodes,
  )
}

///|
fn wgsl_canonical_top_level_block_text(text : String) -> String {
  if text == "" || text.has_suffix("\n") {
    text
  } else {
    "\{text}\n"
  }
}

///|
fn rewrite_wgsl_graph_block_with_binding_plan(
  block : WgslGraphBlock,
  plan : WgslReferenceRewritePlan,
  rewrite_declarations : Bool,
) -> String {
  let rewritten = match block.data {
    WgslGlobalDeclData::Raw =>
      emit_wgsl_token_stream_canonical(block.tokens, [])
    WgslGlobalDeclData::Directive(_) | WgslGlobalDeclData::Import(_) =>
      emit_wgsl_token_stream_canonical(block.tokens, [])
    _ => {
      let nodes : Array[WgslTokenReplacement] = []
      collect_wgsl_bound_block_rewrite_nodes(
        block.data,
        plan.bindings,
        rewrite_declarations,
        nodes,
      )
      emit_wgsl_token_stream_canonical(block.tokens, nodes)
    }
  }
  wgsl_canonical_top_level_block_text(rewritten)
}

///|
fn emit_wgsl_graph_block_canonical(block : WgslGraphBlock) -> String {
  wgsl_canonical_top_level_block_text(
    emit_wgsl_token_stream_canonical(block.tokens, []),
  )
}

///|
fn emit_wgsl_graph_blocks_canonical(blocks : Array[WgslGraphBlock]) -> String {
  let mut out = ""
  for block in blocks {
    out = out + emit_wgsl_graph_block_canonical(block)
  }
  out
}

///|
pub fn rewrite_wgsl_references_with_binding_plan(
  source : String,
  plan : WgslReferenceRewritePlan,
) -> String raise WgslParseError {
  if !plan.has_symbol_bindings() {
    return source
  }
  let graph = build_wgsl_declaration_graph(source)
  let mut out = ""
  for import_block in graph.import_blocks {
    out = out + emit_wgsl_graph_block_canonical(import_block)
  }
  for block in graph.declaration_blocks {
    out = out + rewrite_wgsl_graph_block_with_binding_plan(block, plan, false)
  }
  out
}

///|
pub fn rewrite_wgsl_declarations_with_binding_plan(
  source : String,
  plan : WgslReferenceRewritePlan,
) -> String raise WgslParseError {
  if !plan.has_symbol_bindings() {
    return source
  }
  let graph = build_wgsl_declaration_graph(source)
  let mut out = ""
  for import_block in graph.import_blocks {
    out = out + emit_wgsl_graph_block_canonical(import_block)
  }
  for block in graph.declaration_blocks {
    out = out + rewrite_wgsl_graph_block_with_binding_plan(block, plan, true)
  }
  out
}
