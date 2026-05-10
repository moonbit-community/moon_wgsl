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
