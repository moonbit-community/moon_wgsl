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
priv struct WgslRenameMaps {
  global_declaration_redirects : @hashmap.HashMap[String, String]
  reference_redirects : @hashmap.HashMap[String, String]
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
  let function_local_redirects : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
  for rule in plan.rules {
    match rule.kind {
      GlobalDeclarationAndReferences => {
        global_declaration_redirects.set(rule.from_name, rule.to_name)
        reference_redirects.set(rule.from_name, rule.to_name)
      }
      ReferencesOnly => reference_redirects.set(rule.from_name, rule.to_name)
      FunctionLocal =>
        function_local_redirects.set(rule.from_name, rule.to_name)
    }
  }
  WgslRenameMaps::{
    global_declaration_redirects,
    reference_redirects,
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
      if active_redirects.is_empty() {
        return
      }
      for statement in function.body.statements {
        collect_wgsl_rewrite_nodes_from_identifiers(
          statement.identifiers,
          active_redirects,
          nodes,
        )
      }
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
  collect_wgsl_function_local_rewrite_nodes(
    data,
    maps.function_local_redirects,
    nodes,
  )
}

///|
fn rewrite_wgsl_text_with_nodes(
  text : String,
  nodes : Array[WgslRewriteNode],
  source_start : Int,
) -> String {
  if nodes.length() == 0 {
    return text
  }
  let mut out = ""
  let mut copy_start = 0
  while true {
    let mut next_index = -1
    let mut next_start = text.length() + 1
    for i in 0..<nodes.length() {
      let node = nodes[i]
      let local_start = node.start - source_start
      if local_start >= copy_start &&
        local_start >= 0 &&
        local_start <= text.length() &&
        local_start < next_start {
        next_index = i
        next_start = local_start
      }
    }
    if next_index < 0 {
      break
    }
    let node = nodes[next_index]
    let local_start = node.start - source_start
    let local_end = node.end - source_start
    if local_end < local_start || local_end > text.length() {
      break
    }
    out = out + text[copy_start:local_start].to_owned()
    out = out + node.replacement
    copy_start = local_end
  }
  if copy_start < text.length() {
    out = out + text[copy_start:text.length()].to_owned()
  }
  out
}

///|
fn rewrite_wgsl_graph_block_with_rename_maps(
  block : WgslGraphBlock,
  maps : WgslRenameMaps,
) -> String {
  match block.data {
    WgslGlobalDeclData::Raw => block.text
    WgslGlobalDeclData::Directive(_) | WgslGlobalDeclData::Import(_) =>
      block.text
    _ => {
      let nodes : Array[WgslRewriteNode] = []
      collect_wgsl_block_rewrite_nodes(block.data, maps, nodes)
      rewrite_wgsl_text_with_nodes(block.text, nodes, block.start)
    }
  }
}

///|
pub fn rewrite_wgsl_declarations_with_rename_plan(
  source : String,
  plan : WgslRenamePlan,
) -> String {
  if plan.is_empty() {
    return source
  }
  let graph = build_wgsl_declaration_graph(source)
  let maps = build_wgsl_rename_maps(plan)
  let mut out = ""
  for import_block in graph.import_blocks {
    out = out + import_block.text
  }
  for block in graph.declaration_blocks {
    out = out + rewrite_wgsl_graph_block_with_rename_maps(block, maps)
  }
  out
}
