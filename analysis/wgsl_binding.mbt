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
pub(all) enum WgslRenameRuleKind {
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
pub struct WgslRenamePlan {
  priv rules : Array[WgslRenameRule]
}

///|
priv struct WgslRewriteNode {
  start : Int
  end : Int
  replacement : String
}

///|
priv struct WgslCanonicalTokenEdit {
  start : Int
  end : Int
  replacement : String
}

///|
priv enum WgslEmitTokenClass {
  Word
  Number
  Other
}

///|
priv struct WgslEmittedToken {
  text : String
  start : Int
  end : Int
  kind : WgslEmitTokenClass
}

///|
priv struct WgslRenameMaps {
  global_declaration_redirects : @hashmap.HashMap[String, String]
  reference_redirects : @hashmap.HashMap[String, String]
  function_body_reference_redirects : @hashmap.HashMap[String, String]
  function_local_redirects : @hashmap.HashMap[String, String]
}

///|
pub fn WgslRenamePlan::empty() -> WgslRenamePlan {
  WgslRenamePlan::{ rules: [] }
}

///|
pub fn WgslRenamePlan::is_empty(self : WgslRenamePlan) -> Bool {
  self.rules.length() == 0
}

///|
pub fn WgslRenamePlan::add(
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
pub fn build_wgsl_rename_plan_from_redirect_map(
  redirect_map : @hashmap.HashMap[String, String],
  kind : WgslRenameRuleKind,
) -> WgslRenamePlan {
  let plan = WgslRenamePlan::empty()
  plan.add_redirect_map(redirect_map, kind)
  plan
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
    match redirect_map.get(identifier.name) {
      Some(replacement) =>
        nodes.push(WgslRewriteNode::{
          start: identifier.start,
          end: identifier.end,
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
        expr.identifiers,
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
      match redirect_map.get(ty.name) {
        Some(replacement) =>
          nodes.push(WgslRewriteNode::{
            start: ty.start,
            end: ty.start + ty.name.length(),
            replacement,
          })
        None => ()
      }
      for argument in ty.arguments {
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
  match source_redirects.get(binding.name.name) {
    Some(replacement) => {
      active_redirects.set(binding.name.name, replacement)
      nodes.push(WgslRewriteNode::{
        start: binding.name.start,
        end: binding.name.end,
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
  for binding in statement.local_bindings {
    collect_wgsl_rewrite_nodes_from_type_ref(
      binding.ty_ref,
      block_redirects,
      nodes,
    )
    collect_wgsl_rewrite_nodes_from_expr_ref(
      binding.initializer_ref,
      block_redirects,
      nodes,
    )
    collect_wgsl_local_binding_rewrite_node(
      binding, source_redirects, block_redirects, nodes,
    )
  }
  for expr_ref in statement.expression_refs {
    collect_wgsl_rewrite_nodes_from_expr_ref(
      Some(expr_ref),
      block_redirects,
      nodes,
    )
  }
  for block in statement.blocks {
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
  for statement in block.statements {
    collect_wgsl_statement_local_rewrite_nodes(
      statement, active_redirects, source_redirects, nodes,
    )
    for binding in statement.exported_local_bindings {
      match source_redirects.get(binding.name.name) {
        Some(replacement) =>
          active_redirects.set(binding.name.name, replacement)
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
      for argument in function.arguments {
        match redirect_map.get(argument.name) {
          Some(replacement) => {
            active_redirects.set(argument.name, replacement)
            nodes.push(WgslRewriteNode::{
              start: argument.name_start,
              end: argument.name_end,
              replacement,
            })
          }
          None => ()
        }
      }
      collect_wgsl_block_local_rewrite_nodes(
        function.body,
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
fn wgsl_ascii_code_text(code : Int) -> String {
  match code {
    9 => "\t"
    10 => "\n"
    13 => "\r"
    32 => " "
    33 => "!"
    34 => "\""
    35 => "#"
    36 => "$"
    37 => "%"
    38 => "&"
    39 => "'"
    40 => "("
    41 => ")"
    42 => "*"
    43 => "+"
    44 => ","
    45 => "-"
    46 => "."
    47 => "/"
    48 => "0"
    49 => "1"
    50 => "2"
    51 => "3"
    52 => "4"
    53 => "5"
    54 => "6"
    55 => "7"
    56 => "8"
    57 => "9"
    58 => ":"
    59 => ";"
    60 => "<"
    61 => "="
    62 => ">"
    63 => "?"
    64 => "@"
    65 => "A"
    66 => "B"
    67 => "C"
    68 => "D"
    69 => "E"
    70 => "F"
    71 => "G"
    72 => "H"
    73 => "I"
    74 => "J"
    75 => "K"
    76 => "L"
    77 => "M"
    78 => "N"
    79 => "O"
    80 => "P"
    81 => "Q"
    82 => "R"
    83 => "S"
    84 => "T"
    85 => "U"
    86 => "V"
    87 => "W"
    88 => "X"
    89 => "Y"
    90 => "Z"
    91 => "["
    92 => "\\"
    93 => "]"
    94 => "^"
    95 => "_"
    96 => "`"
    97 => "a"
    98 => "b"
    99 => "c"
    100 => "d"
    101 => "e"
    102 => "f"
    103 => "g"
    104 => "h"
    105 => "i"
    106 => "j"
    107 => "k"
    108 => "l"
    109 => "m"
    110 => "n"
    111 => "o"
    112 => "p"
    113 => "q"
    114 => "r"
    115 => "s"
    116 => "t"
    117 => "u"
    118 => "v"
    119 => "w"
    120 => "x"
    121 => "y"
    122 => "z"
    123 => "{"
    124 => "|"
    125 => "}"
    126 => "~"
    _ => ""
  }
}

///|
fn wgsl_emit_token_text(
  token : WgslToken,
  replacements : @hashmap.HashMap[String, String],
  source_start : Int,
) -> String {
  match token {
    WgslToken::Identifier(text, pos) => {
      let absolute_pos = source_start + pos
      let key = "\{absolute_pos}:\{absolute_pos + text.length()}"
      match replacements.get(key) {
        Some(replacement) => replacement
        None => text
      }
    }
    WgslToken::Number(text, _) => text
    WgslToken::Operator(text, _) => text
    WgslToken::Punctuation(code, _) => wgsl_ascii_code_text(code)
    WgslToken::Whitespace(text, _) => text
  }
}

///|
fn wgsl_emit_token_class(token : WgslToken) -> WgslEmitTokenClass {
  match token {
    WgslToken::Identifier(_, _) => Word
    WgslToken::Number(_, _) => Number
    _ => Other
  }
}

///|
fn wgsl_emit_token_at(
  tokens : Array[WgslToken],
  index : Int,
  replacements : @hashmap.HashMap[String, String],
  source_start : Int,
) -> (WgslEmittedToken, Int)? {
  guard index >= 0 && index < tokens.length() else { return None }
  let token = tokens[index]
  Some(
    (
      WgslEmittedToken::{
        text: wgsl_emit_token_text(token, replacements, source_start),
        start: token.pos(),
        end: token.end(),
        kind: wgsl_emit_token_class(token),
      },
      1,
    ),
  )
}

///|
fn wgsl_emit_tokens_need_space(
  previous : WgslEmittedToken,
  current : WgslEmittedToken,
  previous_text : String,
  current_text : String,
) -> Bool {
  if previous_text == "if" ||
    previous_text == "for" ||
    previous_text == "while" ||
    previous_text == "switch" ||
    previous_text == "return" ||
    previous_text == "break" ||
    previous_text == "case" ||
    previous_text == "fn" ||
    previous_text == "struct" ||
    previous_text == "alias" ||
    previous_text == "let" ||
    previous_text == "const" ||
    previous_text == "override" ||
    previous_text == "virtual" {
    return true
  }
  if previous_text == ":" ||
    previous_text == "," ||
    previous_text == "=" ||
    previous_text == "+" ||
    previous_text == "-" ||
    previous_text == "*" ||
    previous_text == "/" ||
    previous_text == "%" ||
    previous_text == "&" ||
    previous_text == "|" ||
    previous_text == "==" ||
    previous_text == "!=" ||
    previous_text == "<=" ||
    previous_text == ">=" ||
    previous_text == "&&" ||
    previous_text == "||" ||
    previous_text == "+=" ||
    previous_text == "-=" ||
    previous_text == "*=" ||
    previous_text == "/=" ||
    previous_text == "%=" ||
    previous_text == "->" {
    return true
  }
  if current_text == "{" || current_text == "=" || current_text == "->" {
    return true
  }
  if previous_text == ">" && current.kind is Word {
    return true
  }
  if current_text == "+" ||
    current_text == "-" ||
    current_text == "*" ||
    current_text == "/" ||
    current_text == "%" ||
    current_text == "&" ||
    current_text == "|" ||
    current_text == "==" ||
    current_text == "!=" ||
    current_text == "<=" ||
    current_text == ">=" ||
    current_text == "&&" ||
    current_text == "||" ||
    current_text == "+=" ||
    current_text == "-=" ||
    current_text == "*=" ||
    current_text == "/=" ||
    current_text == "%=" {
    return true
  }
  if previous.end == current.start {
    return false
  }
  match (previous.kind, current.kind) {
    (Word, Word) | (Word, Number) | (Number, Word) => true
    _ => false
  }
}

///|
fn emit_wgsl_text_with_nodes(
  text : String,
  nodes : Array[WgslRewriteNode],
  source_start : Int,
) -> String {
  let rewrites : Array[WgslCanonicalTokenEdit] = []
  for node in nodes {
    rewrites.push(WgslCanonicalTokenEdit::{
      start: node.start,
      end: node.end,
      replacement: node.replacement,
    })
  }
  emit_wgsl_canonical_tokens_with_edits(text, rewrites, source_start)
}

///|
fn emit_wgsl_canonical_tokens_with_edits(
  text : String,
  rewrites : Array[WgslCanonicalTokenEdit],
  source_start : Int,
) -> String {
  let replacements : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
  for rewrite in rewrites {
    replacements.set("\{rewrite.start}:\{rewrite.end}", rewrite.replacement)
  }
  let tokens = tokenize_wgsl(replace_comments(text), false)
  let mut out = ""
  let mut previous : WgslEmittedToken? = None
  let mut previous_text = ""
  let mut i = 0
  while i < tokens.length() {
    guard wgsl_emit_token_at(tokens, i, replacements, source_start)
      is Some((token, consumed)) else {
      break
    }
    i = i + consumed
    let token_text = token.text
    if token_text == "" {
      continue
    }
    match previous {
      Some(previous_token) =>
        if wgsl_emit_tokens_need_space(
            previous_token, token, previous_text, token_text,
          ) {
          out = out + " "
        }
      None => ()
    }
    out = out + token_text
    previous = Some(token)
    previous_text = token_text
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
      emit_wgsl_text_with_nodes(block.text, [], block.start)
    WgslGlobalDeclData::Directive(_) | WgslGlobalDeclData::Import(_) =>
      emit_wgsl_text_with_nodes(block.text, [], block.start)
    _ => {
      let nodes : Array[WgslRewriteNode] = []
      collect_wgsl_block_rewrite_nodes(block.data, maps, nodes)
      emit_wgsl_text_with_nodes(block.text, nodes, block.start)
    }
  }
  wgsl_canonical_top_level_block_text(rewritten)
}

///|
fn emit_wgsl_graph_block_canonical(block : WgslGraphBlock) -> String {
  wgsl_canonical_top_level_block_text(
    emit_wgsl_text_with_nodes(block.text, [], block.start),
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
pub fn rewrite_wgsl_declarations_with_rename_plan(
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
