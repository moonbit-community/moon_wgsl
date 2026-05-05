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
priv struct WgslRewriteNode {
  start : Int
  end : Int
  replacement : String
}

///|
priv struct WgslRenameMaps {
  global_declaration_redirects : @hashmap.HashMap[String, String]
  reference_redirects : @hashmap.HashMap[String, String]
  function_body_reference_redirects : @hashmap.HashMap[String, String]
  function_local_redirects : @hashmap.HashMap[String, String]
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
fn build_wgsl_global_rename_plan_from_redirect_map(
  redirect_map : @hashmap.HashMap[String, String],
) -> WgslRenamePlan {
  build_wgsl_rename_plan_from_redirect_map(
    redirect_map,
    GlobalDeclarationAndReferences,
  )
}

///|
fn build_wgsl_reference_rename_plan_from_redirect_map(
  redirect_map : @hashmap.HashMap[String, String],
) -> WgslRenamePlan {
  build_wgsl_rename_plan_from_redirect_map(redirect_map, ReferencesOnly)
}

///|
fn build_wgsl_rename_maps(plan : WgslRenamePlan) -> WgslRenameMaps {
  let global_declaration_redirects : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
  let reference_redirects : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
  let function_body_reference_redirects : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
  let function_local_redirects : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
  for rule in plan.rules {
    match rule.kind {
      GlobalDeclarationAndReferences => {
        global_declaration_redirects.set(rule.from_name, rule.to_name)
        reference_redirects.set(rule.from_name, rule.to_name)
      }
      ReferencesOnly => reference_redirects.set(rule.from_name, rule.to_name)
      FunctionBodyReferencesOnly =>
        function_body_reference_redirects.set(rule.from_name, rule.to_name)
      FunctionLocal =>
        function_local_redirects.set(rule.from_name, rule.to_name)
    }
  }
  WgslRenameMaps::{
    global_declaration_redirects,
    reference_redirects,
    function_body_reference_redirects,
    function_local_redirects,
  }
}

///|
fn collect_wgsl_rewrite_nodes_from_identifiers(
  identifiers : Array[WgslIdent],
  redirect_map : @hashmap.HashMap[String, String],
  nodes : Array[WgslRewriteNode],
) -> Unit {
  for identifier in identifiers {
    match redirect_map.get(identifier.name()) {
      Some(replacement) =>
        nodes.push(WgslRewriteNode::{
          start: identifier.start(),
          end: identifier.end(),
          replacement,
        })
      None => ()
    }
  }
}

///|
fn collect_wgsl_rewrite_nodes_from_expr_ref(
  expr_ref : WgslExprRef?,
  redirect_map : @hashmap.HashMap[String, String],
  nodes : Array[WgslRewriteNode],
) -> Unit {
  match expr_ref {
    Some(expr) =>
      collect_wgsl_rewrite_nodes_from_identifiers(
        expr.identifiers(),
        redirect_map,
        nodes,
      )
    None => ()
  }
}

///|
fn collect_wgsl_rewrite_nodes_from_type_ref(
  ty_ref : WgslTypeRef?,
  redirect_map : @hashmap.HashMap[String, String],
  nodes : Array[WgslRewriteNode],
) -> Unit {
  match ty_ref {
    Some(ty) => {
      let ty_name = ty.name()
      let ty_start = ty.start()
      match redirect_map.get(ty_name) {
        Some(replacement) =>
          nodes.push(WgslRewriteNode::{
            start: ty_start,
            end: ty_start + ty_name.length(),
            replacement,
          })
        None => ()
      }
      for argument in ty.arguments() {
        collect_wgsl_rewrite_nodes_from_type_ref(
          Some(argument),
          redirect_map,
          nodes,
        )
      }
    }
    None => ()
  }
}

///|
fn copy_wgsl_redirect_map(
  redirect_map : @hashmap.HashMap[String, String],
) -> @hashmap.HashMap[String, String] {
  let copied : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
  for entry in redirect_map.iter() {
    let (from_name, to_name) = entry
    copied.set(from_name, to_name)
  }
  copied
}

///|
fn collect_wgsl_local_binding_rewrite_node(
  binding : WgslLocalDeclaration,
  source_redirects : @hashmap.HashMap[String, String],
  active_redirects : @hashmap.HashMap[String, String],
  nodes : Array[WgslRewriteNode],
) -> Unit {
  match source_redirects.get(binding.name().name()) {
    Some(replacement) => {
      active_redirects.set(binding.name().name(), replacement)
      nodes.push(WgslRewriteNode::{
        start: binding.name().start(),
        end: binding.name().end(),
        replacement,
      })
    }
    None => ()
  }
}

///|
fn collect_wgsl_statement_local_rewrite_nodes(
  statement : WgslStatement,
  active_redirects : @hashmap.HashMap[String, String],
  source_redirects : @hashmap.HashMap[String, String],
  nodes : Array[WgslRewriteNode],
) -> Unit {
  let block_redirects = copy_wgsl_redirect_map(active_redirects)
  for binding in statement.local_bindings() {
    collect_wgsl_rewrite_nodes_from_type_ref(
      binding.ty_ref(),
      block_redirects,
      nodes,
    )
    collect_wgsl_rewrite_nodes_from_expr_ref(
      binding.initializer_ref(),
      block_redirects,
      nodes,
    )
    collect_wgsl_local_binding_rewrite_node(
      binding, source_redirects, block_redirects, nodes,
    )
  }
  for expr_ref in statement.expression_refs() {
    collect_wgsl_rewrite_nodes_from_expr_ref(
      Some(expr_ref),
      block_redirects,
      nodes,
    )
  }
  for block in statement.blocks() {
    collect_wgsl_block_local_rewrite_nodes(
      block, block_redirects, source_redirects, nodes,
    )
  }
}

///|
fn collect_wgsl_block_local_rewrite_nodes(
  block : WgslBlock,
  inherited_redirects : @hashmap.HashMap[String, String],
  source_redirects : @hashmap.HashMap[String, String],
  nodes : Array[WgslRewriteNode],
) -> Unit {
  let active_redirects = copy_wgsl_redirect_map(inherited_redirects)
  for statement in block.statements() {
    collect_wgsl_statement_local_rewrite_nodes(
      statement, active_redirects, source_redirects, nodes,
    )
    for binding in statement.exported_local_bindings() {
      match source_redirects.get(binding.name().name()) {
        Some(replacement) =>
          active_redirects.set(binding.name().name(), replacement)
        None => ()
      }
    }
  }
}

///|
fn collect_wgsl_function_local_rewrite_nodes(
  data : WgslGlobalDeclData,
  redirect_map : @hashmap.HashMap[String, String],
  nodes : Array[WgslRewriteNode],
) -> Unit {
  match data {
    WgslGlobalDeclData::Function(function) => {
      let active_redirects : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
      for argument in function.arguments() {
        match redirect_map.get(argument.name()) {
          Some(replacement) => {
            active_redirects.set(argument.name(), replacement)
            nodes.push(WgslRewriteNode::{
              start: argument.name_start(),
              end: argument.name_end(),
              replacement,
            })
          }
          None => ()
        }
      }
      collect_wgsl_block_local_rewrite_nodes(
        function.body(),
        active_redirects,
        redirect_map,
        nodes,
      )
    }
    _ => ()
  }
}

///|
fn collect_wgsl_function_body_reference_rewrite_nodes(
  data : WgslGlobalDeclData,
  redirect_map : @hashmap.HashMap[String, String],
  nodes : Array[WgslRewriteNode],
) -> Unit {
  match data {
    WgslGlobalDeclData::Function(function) => {
      let identifiers : Array[WgslIdent] = []
      collect_wgsl_function_body_identifier_nodes(function, identifiers)
      collect_wgsl_rewrite_nodes_from_identifiers(
        identifiers, redirect_map, nodes,
      )
    }
    _ => ()
  }
}

///|
fn collect_wgsl_block_rewrite_nodes(
  data : WgslGlobalDeclData,
  maps : WgslRenameMaps,
  nodes : Array[WgslRewriteNode],
) -> Unit {
  let identifiers : Array[WgslIdent] = []
  collect_wgsl_decl_global_declared_identifier_nodes(data, identifiers)
  collect_wgsl_rewrite_nodes_from_identifiers(
    identifiers,
    maps.global_declaration_redirects,
    nodes,
  )
  identifiers.clear()
  collect_wgsl_decl_identifier_nodes(data, identifiers)
  collect_wgsl_rewrite_nodes_from_identifiers(
    identifiers,
    maps.reference_redirects,
    nodes,
  )
  collect_wgsl_function_body_reference_rewrite_nodes(
    data,
    maps.function_body_reference_redirects,
    nodes,
  )
  collect_wgsl_function_local_rewrite_nodes(
    data,
    maps.function_local_redirects,
    nodes,
  )
}

///|
fn tokenize_wgsl_absolute_fragment(
  source : String,
  start : Int,
  end_ : Int,
) -> Array[WgslToken] {
  let tokens : Array[WgslToken] = []
  if start < 0 || end_ < start || end_ > source.length() {
    return tokens
  }
  let fragment = replace_comments(source[start:end_].to_owned())
  for token in tokenize_wgsl(fragment, false) {
    tokens.push(token.shift(start))
  }
  tokens
}

///|
fn wgsl_token_text(token : WgslToken) -> String {
  match token.identifier_text() {
    Some(text) => return text
    None => ()
  }
  match token.number_text() {
    Some(text) => return text
    None => ()
  }
  match token.operator_text() {
    Some(text) => return text
    None => ()
  }
  match token.punctuation_code() {
    Some(35) => "#"
    Some(37) => "%"
    Some(38) => "&"
    Some(40) => "("
    Some(41) => ")"
    Some(42) => "*"
    Some(43) => "+"
    Some(44) => ","
    Some(45) => "-"
    Some(46) => "."
    Some(47) => "/"
    Some(58) => ":"
    Some(59) => ";"
    Some(60) => "<"
    Some(61) => "="
    Some(62) => ">"
    Some(64) => "@"
    Some(91) => "["
    Some(93) => "]"
    Some(94) => "^"
    Some(123) => "{"
    Some(124) => "|"
    Some(125) => "}"
    Some(126) => "~"
    _ => ""
  }
}

///|
fn wgsl_token_replacement(
  token : WgslToken,
  nodes : Array[WgslRewriteNode],
) -> String? {
  for node in nodes {
    if node.start == token.pos() && node.end == token.end() {
      return Some(node.replacement)
    }
  }
  None
}

///|
fn wgsl_token_is_wordlike(text : String) -> Bool {
  if text == "" {
    return false
  }
  let code = text.code_unit_at(0).to_int()
  (code >= 48 && code <= 57) ||
  (code >= 65 && code <= 90) ||
  (code >= 97 && code <= 122) ||
  code == 95 ||
  code == 34
}

///|
fn wgsl_emit_needs_space(previous : String, current : String) -> Bool {
  if previous == "" || current == "" {
    return false
  }
  if previous == "\n" {
    return false
  }
  if current == ")" ||
    current == "]" ||
    current == ">" ||
    current == "," ||
    current == ";" ||
    current == ":" ||
    current == "." {
    return false
  }
  if previous == "(" ||
    previous == "[" ||
    previous == "." ||
    previous == "@" ||
    previous == "<" {
    return false
  }
  if current == "(" {
    return previous == "if" ||
      previous == "for" ||
      previous == "while" ||
      previous == "switch" ||
      previous == "const_assert"
  }
  if current == "{" {
    return true
  }
  if current == "@" {
    return previous != ""
  }
  if (previous == ")" || previous == ">") && wgsl_token_is_wordlike(current) {
    return true
  }
  if previous == "&" && wgsl_token_is_wordlike(current) {
    return true
  }
  if previous == "," || previous == ":" || previous == ";" || previous == "}" {
    return true
  }
  if previous == "->" || current == "->" || previous == "=" || current == "=" {
    return true
  }
  if previous == "==" ||
    previous == "!=" ||
    previous == "<=" ||
    previous == ">=" ||
    previous == "&&" ||
    previous == "||" ||
    previous == "+=" ||
    previous == "-=" ||
    previous == "*=" ||
    previous == "/=" ||
    previous == "%=" ||
    previous == "&=" ||
    previous == "|=" ||
    previous == "^=" ||
    previous == "+" ||
    previous == "-" ||
    previous == "*" ||
    previous == "/" ||
    previous == "%" ||
    current == "==" ||
    current == "!=" ||
    current == "<=" ||
    current == ">=" ||
    current == "&&" ||
    current == "||" ||
    current == "+=" ||
    current == "-=" ||
    current == "*=" ||
    current == "/=" ||
    current == "%=" ||
    current == "&=" ||
    current == "|=" ||
    current == "^=" ||
    current == "+" ||
    current == "-" ||
    current == "*" ||
    current == "/" ||
    current == "%" {
    return true
  }
  wgsl_token_is_wordlike(previous) && wgsl_token_is_wordlike(current)
}

///|
fn wgsl_emit_token_stream_with_nodes(
  tokens : Array[WgslToken],
  nodes : Array[WgslRewriteNode],
) -> String {
  let mut out = ""
  let mut previous = ""
  for token in tokens {
    let text = match wgsl_token_replacement(token, nodes) {
      Some(replacement) => replacement
      None => wgsl_token_text(token)
    }
    if text == "" {
      continue
    }
    if wgsl_emit_needs_space(previous, text) {
      out = out + " "
    }
    out = out + text
    if text == ";" || text == "}" {
      out = out + "\n"
      previous = "\n"
    } else {
      previous = text
    }
  }
  out
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
      wgsl_emit_token_stream_with_nodes(block.tokens, [])
    WgslGlobalDeclData::Directive(_) | WgslGlobalDeclData::Import(_) =>
      wgsl_emit_token_stream_with_nodes(block.tokens, [])
    _ => {
      let nodes : Array[WgslRewriteNode] = []
      collect_wgsl_block_rewrite_nodes(block.data, maps, nodes)
      wgsl_emit_token_stream_with_nodes(block.tokens, nodes)
    }
  }
  wgsl_canonical_top_level_block_text(rewritten)
}

///|
fn emit_wgsl_graph_block_canonical(block : WgslGraphBlock) -> String {
  wgsl_canonical_top_level_block_text(
    wgsl_emit_token_stream_with_nodes(block.tokens, []),
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
pub fn rewrite_wgsl_declarations_with_global_rename_map(
  source : String,
  redirect_map : @hashmap.HashMap[String, String],
) -> String raise WgslParseError {
  rewrite_wgsl_declarations_with_rename_plan(
    source,
    build_wgsl_global_rename_plan_from_redirect_map(redirect_map),
  )
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
