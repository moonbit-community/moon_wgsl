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
pub fn build_wgsl_symbol_redirect_map(
  redirects : Array[WgslSymbolRedirect],
) -> @hashmap.HashMap[String, String] {
  let redirect_map : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
  for redirect in redirects {
    let from_name = redirect.from_name.trim().to_owned()
    let to_name = redirect.to_name.trim().to_owned()
    if from_name == "" || to_name == "" || from_name == to_name {
      continue
    }
    redirect_map.set(from_name, to_name)
  }
  redirect_map
}

///|
fn rewrite_wgsl_decl_identifier_nodes_with_map(
  text : String,
  data : WgslGlobalDeclData,
  redirect_map : @hashmap.HashMap[String, String],
  rewrite_declaration_names : Bool,
) -> String {
  let identifiers : Array[WgslIdent] = []
  if rewrite_declaration_names {
    collect_wgsl_decl_declared_identifier_nodes(data, identifiers)
  }
  collect_wgsl_decl_identifier_nodes(data, identifiers)
  let mut out = ""
  let mut copy_start = 0
  while true {
    let mut next_index = -1
    let mut next_start = text.length() + 1
    for i in 0..<identifiers.length() {
      let identifier = identifiers[i]
      if identifier.start >= copy_start &&
        identifier.start < next_start &&
        redirect_map.contains(identifier.name) {
        next_index = i
        next_start = identifier.start
      }
    }
    if next_index < 0 {
      break
    }
    let identifier = identifiers[next_index]
    guard redirect_map.get(identifier.name) is Some(rewritten_name) else {
      break
    }
    out = out + text[copy_start:identifier.start].to_owned()
    out = out + rewritten_name
    copy_start = identifier.end
  }
  if copy_start < text.length() {
    out = out + text[copy_start:text.length()].to_owned()
  }
  out
}

///|
fn rewrite_wgsl_declaration_block_with_redirects(
  block : WgslGraphBlock,
  redirect_map : @hashmap.HashMap[String, String],
  rewrite_declaration_names : Bool,
) -> String {
  match block.data {
    WgslGlobalDeclData::Raw => block.text
    WgslGlobalDeclData::Directive(_) | WgslGlobalDeclData::Import(_) =>
      block.text
    _ =>
      rewrite_wgsl_decl_identifier_nodes_with_map(
        block.text,
        block.data,
        redirect_map,
        rewrite_declaration_names,
      )
  }
}

///|
pub fn rewrite_wgsl_declaration_text_with_map(
  source : String,
  redirect_map : @hashmap.HashMap[String, String],
  rewrite_declaration_names : Bool,
) -> String {
  if redirect_map.is_empty() {
    return source
  }
  let graph = build_wgsl_declaration_graph(source)
  let mut out = ""
  for block in graph.source_blocks {
    out = out +
      rewrite_wgsl_declaration_block_with_redirects(
        block, redirect_map, rewrite_declaration_names,
      )
  }
  out
}

///|
pub fn rewrite_wgsl_declaration_text_with_redirects(
  source : String,
  redirect_map : @hashmap.HashMap[String, String],
) -> String {
  rewrite_wgsl_declaration_text_with_map(source, redirect_map, false)
}

///|
pub fn rewrite_wgsl_declaration_text_with_renamed_declarations(
  source : String,
  redirect_map : @hashmap.HashMap[String, String],
) -> String {
  rewrite_wgsl_declaration_text_with_map(source, redirect_map, true)
}

///|
pub fn rewrite_wgsl_symbol_redirects(
  source : String,
  redirects : Array[WgslSymbolRedirect],
) -> String {
  if redirects.length() == 0 {
    return source
  }
  let graph = build_wgsl_declaration_graph(source)
  let redirect_map = build_wgsl_symbol_redirect_map(redirects)
  let mut rewritten = ""
  for import_block in graph.import_blocks {
    rewritten = rewritten + import_block.text
  }
  for block in graph.declaration_blocks {
    rewritten = rewritten +
      rewrite_wgsl_declaration_block_with_redirects(block, redirect_map, false)
  }
  rewritten
}
