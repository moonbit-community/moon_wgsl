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
priv struct WgslVirtualOverrideOutput {
  source : String
  invalid_override : String?
}

///|
pub suberror WgslVirtualOverrideError {
  InvalidOverride(String)
  Parse(String, Int)
  UnparsedDeclaration(String, Int)
}

///|
fn wgsl_virtual_override_error_from_parse(
  error : WgslParseError,
) -> WgslVirtualOverrideError {
  match error {
    Parse(message, offset) => WgslVirtualOverrideError::Parse(message, offset)
    UnparsedDeclaration(text, offset) =>
      WgslVirtualOverrideError::UnparsedDeclaration(text, offset)
  }
}

///|
fn wgsl_graph_block_function(block : WgslGraphBlock) -> WgslFunction? {
  match block.data {
    WgslGlobalDeclData::Function(function) => Some(function)
    _ => None
  }
}

///|
fn wgsl_graph_block_is_virtual_fn(block : WgslGraphBlock) -> Bool {
  match wgsl_graph_block_function(block) {
    Some(function) => function.qualifier() == "virtual"
    None => false
  }
}

///|
fn wgsl_graph_block_override_target(block : WgslGraphBlock) -> String? {
  match wgsl_graph_block_function(block) {
    Some(function) =>
      if function.qualifier() == "override" {
        Some(function.name().name())
      } else {
        None
      }
    None => None
  }
}

///|
pub fn wgsl_source_contains_override_directive(
  source : String,
) -> Bool raise WgslParseError {
  let graph = build_wgsl_declaration_graph(source)
  for block in graph.declaration_blocks {
    match block.data {
      WgslGlobalDeclData::Function(function) =>
        if function.qualifier() == "override" {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
pub fn wgsl_source_contains_virtual_directive(
  source : String,
) -> Bool raise WgslParseError {
  let graph = build_wgsl_declaration_graph(source)
  for block in graph.declaration_blocks {
    if wgsl_graph_block_is_virtual_fn(block) {
      return true
    }
  }
  false
}

///|
pub fn rewrite_wgsl_override_targets_with_redirects(
  source : String,
  alias_redirect_map : @hashmap.HashMap[String, String],
) -> String raise WgslParseError {
  if alias_redirect_map.is_empty() {
    return source
  }
  let graph = build_wgsl_declaration_graph(source)
  let mut out = ""
  for import_block in graph.import_blocks {
    out = out + emit_wgsl_graph_block_canonical(import_block)
  }
  for block in graph.declaration_blocks {
    guard wgsl_graph_block_function(block) is Some(function) else {
      out = out + emit_wgsl_graph_block_canonical(block)
      continue
    }
    if function.qualifier() != "override" {
      out = out + emit_wgsl_graph_block_canonical(block)
      continue
    }
    let nodes : Array[WgslTokenReplacement] = []
    let raw_target = function.name().name()
    if split_last_identifier(raw_target) is None {
      out = out + emit_wgsl_graph_block_canonical(block)
      continue
    }
    let target = wgsl_alias_redirect_target(raw_target, alias_redirect_map)
    if target != raw_target {
      nodes.push(
        WgslTokenReplacement::new(
          function.name().start(),
          function.name().end(),
          target,
        ),
      )
    }
    out = out + emit_wgsl_token_stream_canonical(block.tokens, nodes)
  }
  out
}

///|
fn wgsl_override_body_references_target(
  function : WgslFunction,
  raw_target : String,
  target_name : String,
) -> Bool {
  let identifiers : Array[WgslIdent] = []
  collect_wgsl_function_body_identifier_nodes(function, identifiers)
  for ident in identifiers {
    if ident.name() == raw_target || ident.name() == target_name {
      return true
    }
  }
  false
}

///|
fn wgsl_virtual_base_name(target_name : String) -> String {
  "\{target_name}__virtual_base"
}

///|
fn wgsl_flatten_path_identifier(path : String) -> String {
  match split_last_identifier(path) {
    Some((prefix, suffix)) =>
      "\{wgsl_flatten_path_identifier(prefix)}__\{suffix}"
    None => path
  }
}

///|
fn collect_wgsl_virtual_fn_nodes(
  function : WgslFunction,
  nodes : Array[WgslTokenReplacement],
) -> Unit {
  match (function.qualifier_start(), function.qualifier_end()) {
    (Some(start), Some(end_)) =>
      nodes.push(WgslTokenReplacement::new(start, end_, ""))
    _ => ()
  }
}

///|
fn rewrite_wgsl_virtual_fn_block(
  block : WgslGraphBlock,
  function : WgslFunction,
) -> String {
  let nodes : Array[WgslTokenReplacement] = []
  collect_wgsl_virtual_fn_nodes(function, nodes)
  emit_wgsl_token_stream_canonical(block.tokens, nodes)
}

///|
fn rewrite_wgsl_virtual_base_block(
  block : WgslGraphBlock,
  function : WgslFunction,
  target_name : String,
  base_name : String,
) -> String {
  let plan = WgslRenamePlan::empty()
  plan.add(target_name, base_name, GlobalDeclarationAndReferences)
  let maps = build_wgsl_rename_maps(plan)
  let nodes : Array[WgslTokenReplacement] = []
  collect_wgsl_block_rewrite_nodes(block.data, maps, nodes)
  collect_wgsl_virtual_fn_nodes(function, nodes)
  emit_wgsl_token_stream_canonical(block.tokens, nodes)
}

///|
fn collect_wgsl_override_body_reference_nodes(
  data : WgslGlobalDeclData,
  target_name : String,
  raw_target : String,
  base_name : String,
  nodes : Array[WgslTokenReplacement],
) -> Unit {
  let plan = WgslRenamePlan::empty()
  plan.add(target_name, base_name, FunctionBodyReferencesOnly)
  plan.add(raw_target, base_name, FunctionBodyReferencesOnly)
  collect_wgsl_block_rewrite_nodes(data, build_wgsl_rename_maps(plan), nodes)
}

///|
fn rewrite_wgsl_override_fn_block(
  block : WgslGraphBlock,
  function : WgslFunction,
  target_name : String,
  raw_target : String,
  base_name : String?,
) -> String {
  let nodes : Array[WgslTokenReplacement] = []
  match base_name {
    Some(base) =>
      collect_wgsl_override_body_reference_nodes(
        block.data,
        target_name,
        raw_target,
        base,
        nodes,
      )
    None => ()
  }
  match (function.qualifier_start(), function.qualifier_end()) {
    (Some(start), Some(end_)) => {
      nodes.push(WgslTokenReplacement::new(start, end_, ""))
      nodes.push(
        WgslTokenReplacement::new(
          function.name().start(),
          function.name().end(),
          target_name,
        ),
      )
      emit_wgsl_token_stream_canonical(block.tokens, nodes)
    }
    _ => emit_wgsl_token_stream_canonical(block.tokens, nodes)
  }
}

///|
fn wgsl_alias_redirect_target(
  target : String,
  alias_redirect_map : @hashmap.HashMap[String, String],
) -> String {
  if split_last_identifier(target) is None {
    return target
  }
  match alias_redirect_map.get(target) {
    Some(redirected) => redirected
    None => wgsl_flatten_path_identifier(target)
  }
}

///|
fn apply_wgsl_virtual_overrides_checked(
  source : String,
  alias_redirect_map : @hashmap.HashMap[String, String],
) -> WgslVirtualOverrideOutput raise WgslParseError {
  let graph = build_wgsl_declaration_graph(source)
  let virtual_names : @hashmap.HashMap[String, Bool] = @hashmap.HashMap::new()
  let overrides : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
  let override_needs_base : @hashmap.HashMap[String, Bool] = @hashmap.HashMap::new()
  for block in graph.declaration_blocks {
    if block.name != "" && wgsl_graph_block_is_virtual_fn(block) {
      virtual_names.set(block.name, true)
    }
  }
  for block in graph.declaration_blocks {
    match wgsl_graph_block_function(block) {
      Some(function) if function.qualifier() == "override" => {
        let raw_target = function.name().name()
        let target = wgsl_alias_redirect_target(raw_target, alias_redirect_map)
        if !virtual_names.contains(target) {
          return WgslVirtualOverrideOutput::{
            source,
            invalid_override: Some(raw_target),
          }
        }
        let needs_base = wgsl_override_body_references_target(
          function, raw_target, target,
        )
        override_needs_base.set(target, needs_base)
        let base_name = if needs_base {
          Some(wgsl_virtual_base_name(target))
        } else {
          None
        }
        overrides.set(
          target,
          rewrite_wgsl_override_fn_block(
            block, function, target, raw_target, base_name,
          ),
        )
      }
      Some(_) => ()
      None => ()
    }
  }
  if virtual_names.is_empty() || overrides.is_empty() {
    return WgslVirtualOverrideOutput::{ source, invalid_override: None }
  }
  let mut out = ""
  for import_block in graph.import_blocks {
    out = out + emit_wgsl_graph_block_canonical(import_block)
  }
  for block in graph.declaration_blocks {
    match wgsl_graph_block_override_target(block) {
      Some(_) => continue
      None => ()
    }
    match wgsl_graph_block_function(block) {
      Some(function) if block.name != "" && function.qualifier() == "virtual" => {
        match overrides.get(block.name) {
          Some(override_block) => {
            let needs_base = match override_needs_base.get(block.name) {
              Some(value) => value
              None => false
            }
            if needs_base {
              out = out +
                rewrite_wgsl_virtual_base_block(
                  block,
                  function,
                  block.name,
                  wgsl_virtual_base_name(block.name),
                )
            }
            out = out + override_block
          }
          None => out = out + rewrite_wgsl_virtual_fn_block(block, function)
        }
        continue
      }
      _ => ()
    }
    out = out + emit_wgsl_graph_block_canonical(block)
  }
  WgslVirtualOverrideOutput::{ source: out, invalid_override: None }
}

///|
pub fn apply_wgsl_virtual_overrides(
  source : String,
  alias_redirect_map : @hashmap.HashMap[String, String],
) -> String raise WgslVirtualOverrideError {
  let output = apply_wgsl_virtual_overrides_checked(source, alias_redirect_map) catch {
    error => raise wgsl_virtual_override_error_from_parse(error)
  }
  match output.invalid_override {
    Some(name) => raise WgslVirtualOverrideError::InvalidOverride(name)
    None => output.source
  }
}

///|
pub fn strip_wgsl_virtual_functions(
  source : String,
) -> String raise WgslParseError {
  let graph = build_wgsl_declaration_graph(source)
  let mut saw_virtual = false
  for block in graph.declaration_blocks {
    if wgsl_graph_block_is_virtual_fn(block) {
      saw_virtual = true
      break
    }
  }
  if !saw_virtual {
    return source
  }
  let mut out = ""
  let emitted_names : @hashmap.HashMap[String, Bool] = @hashmap.HashMap::new()
  for import_block in graph.import_blocks {
    out = out + emit_wgsl_graph_block_canonical(import_block)
  }
  for block in graph.declaration_blocks {
    if wgsl_graph_block_is_virtual_fn(block) {
      if block.name != "" && emitted_names.contains(block.name) {
        continue
      }
      match wgsl_graph_block_function(block) {
        Some(function) =>
          out = out + rewrite_wgsl_virtual_fn_block(block, function)
        None => out = out + emit_wgsl_graph_block_canonical(block)
      }
    } else {
      out = out + emit_wgsl_graph_block_canonical(block)
    }
    if block.name != "" {
      emitted_names.set(block.name, true)
    }
  }
  out
}

///|
