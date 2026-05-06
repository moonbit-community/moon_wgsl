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
  rel_path : String
  original_name : String
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
}

///|
priv struct WgslReferenceRewriteBinding {
  from_name : String
  to_name : String
  rel_path : String
  original_name : String
}

///|
fn WgslReferenceRewriteBinding::key(
  self : WgslReferenceRewriteBinding,
) -> String {
  "\{self.rel_path}|\{self.original_name}|\{self.from_name}|\{self.to_name}"
}

///|
pub fn WgslReferenceRewritePlan::new() -> WgslReferenceRewritePlan {
  WgslReferenceRewritePlan::{ bindings: [] }
}

///|
pub fn WgslReferenceRewritePlan::add_symbol_binding(
  self : WgslReferenceRewritePlan,
  rel_path : String,
  original_name : String,
  from_name : String,
  to_name : String,
) -> Unit {
  let from_name = from_name.trim().to_owned()
  let to_name = to_name.trim().to_owned()
  if from_name == "" || to_name == "" || from_name == to_name {
    return
  }
  let binding = WgslReferenceRewriteBinding::{
    from_name,
    to_name,
    rel_path,
    original_name,
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
pub fn WgslReferenceRewritePlan::add(
  self : WgslReferenceRewritePlan,
  from_name : String,
  to_name : String,
) -> Unit {
  self.add_symbol_binding("", "", from_name, to_name)
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
  self.add_symbol_binding("", "", from_name, to_name, kind)
}

///|
fn WgslRenamePlan::add_symbol_binding(
  self : WgslRenamePlan,
  rel_path : String,
  original_name : String,
  from_name : String,
  to_name : String,
  kind : WgslRenameRuleKind,
) -> Unit {
  let from_name = from_name.trim().to_owned()
  let to_name = to_name.trim().to_owned()
  if from_name == "" || to_name == "" || from_name == to_name {
    return
  }
  self.rules.push(WgslRenameRule::{
    from_name,
    to_name,
    kind,
    rel_path,
    original_name,
  })
}

///|
fn WgslRenamePlan::add_redirect_map(
  self : WgslRenamePlan,
  redirect_map : @hashmap.HashMap[String, String],
  kind : WgslRenameRuleKind,
) -> Unit {
  for entry in redirect_map.iter() {
    let (from_name, to_name) = entry
    self.add(from_name, to_name, kind)
  }
}

///|
fn build_wgsl_rename_plan_from_redirect_map(
  redirect_map : @hashmap.HashMap[String, String],
  kind : WgslRenameRuleKind,
) -> WgslRenamePlan {
  let plan = WgslRenamePlan::empty()
  plan.add_redirect_map(redirect_map, kind)
  plan
}

///|
fn build_wgsl_reference_rename_plan_from_redirect_map(
  redirect_map : @hashmap.HashMap[String, String],
) -> WgslRenamePlan {
  build_wgsl_rename_plan_from_redirect_map(redirect_map, ReferencesOnly)
}

///|
fn WgslReferenceRewritePlan::reference_rename_plan(
  self : WgslReferenceRewritePlan,
) -> WgslRenamePlan {
  let plan = WgslRenamePlan::empty()
  for binding in self.bindings {
    plan.add_symbol_binding(
      binding.rel_path,
      binding.original_name,
      binding.from_name,
      binding.to_name,
      ReferencesOnly,
    )
  }
  plan
}

///|
fn WgslReferenceRewritePlan::global_declaration_rename_plan(
  self : WgslReferenceRewritePlan,
) -> WgslRenamePlan {
  let plan = WgslRenamePlan::empty()
  for binding in self.bindings {
    plan.add_symbol_binding(
      binding.rel_path,
      binding.original_name,
      binding.from_name,
      binding.to_name,
      GlobalDeclarationAndReferences,
    )
  }
  plan
}

///|
fn WgslReferenceRewritePlan::target_for_reference(
  self : WgslReferenceRewritePlan,
  from_name : String,
) -> String? {
  let mut target : String? = None
  for binding in self.bindings {
    if binding.from_name != from_name {
      continue
    }
    match target {
      Some(existing) if existing != binding.to_name => return None
      Some(_) => ()
      None => target = Some(binding.to_name)
    }
  }
  target
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
  let mut identity_key : String? = None
  for rule in rules {
    if rule.from_name != from_name {
      continue
    }
    let current_identity_key = "\{rule.rel_path}|\{rule.original_name}"
    match target {
      Some(existing) if existing != rule.to_name =>
        match identity_key {
          Some(existing_identity_key) if existing_identity_key ==
            current_identity_key => return Some(rule.to_name)
          _ => return None
        }
      Some(_) => ()
      None => {
        target = Some(rule.to_name)
        identity_key = Some(current_identity_key)
      }
    }
  }
  target
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
          WgslTokenReplacement::new(
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
                WgslTokenReplacement::new(
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
        rel_path: "",
        original_name: "",
      })
      nodes.push(
        WgslTokenReplacement::new(
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
            rel_path: "",
            original_name: "",
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
              rel_path: "",
              original_name: "",
            })
            nodes.push(
              WgslTokenReplacement::new(
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
fn wgsl_canonical_top_level_block_text(text : String) -> String {
  if text == "" || text.has_suffix("\n") {
    text
  } else {
    "\{text}\n"
  }
}

///|
fn rewrite_wgsl_graph_block_with_rename_maps(
  block : WgslGraphBlock,
  maps : WgslRenameMaps,
) -> String {
  let rewritten = match block.data {
    WgslGlobalDeclData::Raw =>
      emit_wgsl_token_stream_canonical(block.tokens, [])
    WgslGlobalDeclData::Directive(_) | WgslGlobalDeclData::Import(_) =>
      emit_wgsl_token_stream_canonical(block.tokens, [])
    _ => {
      let nodes : Array[WgslTokenReplacement] = []
      collect_wgsl_block_rewrite_nodes(block.data, maps, nodes)
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
fn rewrite_wgsl_declarations_with_rename_plan(
  source : String,
  plan : WgslRenamePlan,
) -> String raise WgslParseError {
  if plan.is_empty() {
    return source
  }
  let graph = build_wgsl_declaration_graph(source)
  let maps = build_wgsl_rename_maps(plan)
  let mut out = ""
  for import_block in graph.import_blocks {
    out = out + emit_wgsl_graph_block_canonical(import_block)
  }
  for block in graph.declaration_blocks {
    out = out + rewrite_wgsl_graph_block_with_rename_maps(block, maps)
  }
  out
}

///|
pub fn rewrite_wgsl_references_with_rename_map(
  source : String,
  redirect_map : @hashmap.HashMap[String, String],
) -> String raise WgslParseError {
  rewrite_wgsl_declarations_with_rename_plan(
    source,
    build_wgsl_reference_rename_plan_from_redirect_map(redirect_map),
  )
}

///|
pub fn rewrite_wgsl_references_with_binding_plan(
  source : String,
  plan : WgslReferenceRewritePlan,
) -> String raise WgslParseError {
  rewrite_wgsl_declarations_with_rename_plan(
    source,
    plan.reference_rename_plan(),
  )
}

///|
pub fn rewrite_wgsl_declarations_with_binding_plan(
  source : String,
  plan : WgslReferenceRewritePlan,
) -> String raise WgslParseError {
  rewrite_wgsl_declarations_with_rename_plan(
    source,
    plan.global_declaration_rename_plan(),
  )
}
