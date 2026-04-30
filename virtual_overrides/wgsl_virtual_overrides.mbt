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
pub struct WgslVirtualOverrideOutput {
  source : String
  invalid_override : String?
}

///|
fn wgsl_virtual_name_list_contains(
  names : Array[String],
  name : String,
) -> Bool {
  for existing in names {
    if existing == name {
      return true
    }
  }
  false
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
    Some(function) => function.qualifier == "virtual"
    None => false
  }
}

///|
fn wgsl_graph_block_override_target(block : WgslGraphBlock) -> String? {
  match wgsl_graph_block_function(block) {
    Some(function) =>
      if function.qualifier == "override" {
        Some(function.name.name)
      } else {
        None
      }
    None => None
  }
}

///|
pub fn wgsl_source_contains_override_directive(source : String) -> Bool {
  let graph = build_wgsl_declaration_graph(source)
  for block in graph.declaration_blocks {
    match block.data {
      WgslGlobalDeclData::Function(function) =>
        if function.qualifier == "override" {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn wgsl_override_body_references_target(
  function : WgslFunction,
  raw_target : String,
  target_name : String,
) -> Bool {
  let active_local_names : Array[String] = []
  for argument in function.arguments {
    active_local_names.push(argument.name)
  }
  for statement in function.body.statements {
    for ident in statement.identifiers {
      if wgsl_virtual_name_list_contains(active_local_names, ident.name) {
        continue
      }
      if ident.name == raw_target || ident.name == target_name {
        return true
      }
      match split_last_identifier(ident.name) {
        Some((_, suffix)) =>
          if suffix == raw_target || suffix == target_name {
            return true
          }
        None => ()
      }
    }
    for binding in statement.exported_locals {
      active_local_names.push(binding.name)
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
fn rewrite_wgsl_virtual_fn_block(
  block_text : String,
  function : WgslFunction,
  block_start : Int,
) -> String {
  match (function.qualifier_start, function.qualifier_end) {
    (Some(start), Some(_)) => {
      let local_start = start - block_start
      let local_fn_start = function.fn_start - block_start
      block_text[:local_start].to_owned() +
      block_text[local_fn_start:block_text.length()].to_owned()
    }
    _ => block_text
  }
}

///|
fn rewrite_wgsl_virtual_base_block(
  block_text : String,
  function : WgslFunction,
  block_start : Int,
  target_name : String,
  base_name : String,
) -> String {
  let plan = WgslRenamePlan::empty()
  plan.add(target_name, base_name, GlobalDeclarationAndReferences)
  rewrite_wgsl_virtual_fn_block(
    rewrite_wgsl_declarations_with_rename_plan(block_text, plan),
    function,
    block_start,
  )
}

///|
fn rewrite_wgsl_override_fn_block(
  block_text : String,
  function : WgslFunction,
  block_start : Int,
  target_name : String,
  raw_target : String,
  base_name : String?,
) -> String {
  let rewritten_body = match base_name {
    Some(base) => {
      let plan = WgslRenamePlan::empty()
      plan.add(target_name, base, ReferencesOnly)
      plan.add(raw_target, base, ReferencesOnly)
      rewrite_wgsl_declarations_with_rename_plan(block_text, plan)
    }
    None => block_text
  }
  match function.qualifier_start {
    Some(start) => {
      let local_start = start - block_start
      let local_name_end = function.name.end - block_start
      rewritten_body[:local_start].to_owned() +
      "fn " +
      target_name +
      rewritten_body[local_name_end:rewritten_body.length()].to_owned()
    }
    None => rewritten_body
  }
}

///|
fn wgsl_alias_redirect_target(
  target : String,
  alias_redirect_map : @hashmap.HashMap[String, String],
) -> String {
  match alias_redirect_map.get(target) {
    Some(redirected) => redirected
    None => wgsl_flatten_path_identifier(target)
  }
}

///|
pub fn apply_wgsl_virtual_overrides_raw(
  source : String,
  alias_redirect_map : @hashmap.HashMap[String, String],
) -> WgslVirtualOverrideOutput {
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
      Some(function) if function.qualifier == "override" => {
        let raw_target = function.name.name
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
            block.text,
            function,
            block.start,
            target,
            raw_target,
            base_name,
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
    out = out + import_block.text
  }
  for block in graph.declaration_blocks {
    match wgsl_graph_block_override_target(block) {
      Some(_) => continue
      None => ()
    }
    match wgsl_graph_block_function(block) {
      Some(function) if block.name != "" && function.qualifier == "virtual" => {
        match overrides.get(block.name) {
          Some(override_block) => {
            let needs_base = match override_needs_base.get(block.name) {
              Some(value) => value
              None => false
            }
            if needs_base {
              out = out +
                rewrite_wgsl_virtual_base_block(
                  block.text,
                  function,
                  block.start,
                  block.name,
                  wgsl_virtual_base_name(block.name),
                )
            }
            out = out + override_block
          }
          None =>
            out = out +
              rewrite_wgsl_virtual_fn_block(block.text, function, block.start)
        }
        continue
      }
      _ => ()
    }
    out = out + block.text
  }
  WgslVirtualOverrideOutput::{ source: out, invalid_override: None }
}

///|
pub fn strip_wgsl_virtual_functions(source : String) -> String {
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
    out = out + import_block.text
  }
  for block in graph.declaration_blocks {
    if wgsl_graph_block_is_virtual_fn(block) {
      if block.name != "" && emitted_names.contains(block.name) {
        continue
      }
      match wgsl_graph_block_function(block) {
        Some(function) =>
          out = out +
            rewrite_wgsl_virtual_fn_block(block.text, function, block.start)
        None => out = out + block.text
      }
    } else {
      out = out + block.text
    }
    if block.name != "" {
      emitted_names.set(block.name, true)
    }
  }
  out
}

///|
