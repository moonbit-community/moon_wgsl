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
fn wgsl_source_contains_override_directive(source : String) -> Bool {
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
  let local_names = collect_wgsl_decl_local_names(
    WgslGlobalDeclData::Function(function),
  )
  for statement in function.body.statements {
    for ident in statement.identifiers {
      if local_names.contains(ident.name) {
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
) -> String {
  match (function.qualifier_start, function.qualifier_end) {
    (Some(start), Some(_)) =>
      block_text[:start].to_owned() +
      block_text[function.fn_start:block_text.length()].to_owned()
    _ => block_text
  }
}

///|
fn rewrite_wgsl_virtual_identifier_spans(
  block_text : String,
  function : WgslFunction,
  redirect_map : @hashmap.HashMap[String, String],
  include_function_name : Bool,
) -> String {
  let identifiers : Array[WgslIdent] = []
  if include_function_name {
    identifiers.push(function.name)
  }
  collect_wgsl_decl_identifier_nodes(
    WgslGlobalDeclData::Function(function),
    identifiers,
  )
  let mut out = ""
  let mut copy_start = 0
  while true {
    let mut next_index = -1
    let mut next_start = block_text.length() + 1
    for i in 0..<identifiers.length() {
      let ident = identifiers[i]
      if ident.start >= copy_start &&
        ident.start < next_start &&
        redirect_map.contains(ident.name) {
        next_index = i
        next_start = ident.start
      }
    }
    if next_index < 0 {
      break
    }
    let ident = identifiers[next_index]
    guard redirect_map.get(ident.name) is Some(rewritten) else { break }
    out = out + block_text[copy_start:ident.start].to_owned()
    out = out + rewritten
    copy_start = ident.end
  }
  if copy_start < block_text.length() {
    out = out + block_text[copy_start:block_text.length()].to_owned()
  }
  out
}

///|
fn rewrite_wgsl_virtual_base_block(
  block_text : String,
  function : WgslFunction,
  target_name : String,
  base_name : String,
) -> String {
  let rename_map : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
  rename_map.set(target_name, base_name)
  rewrite_wgsl_virtual_fn_block(
    rewrite_wgsl_virtual_identifier_spans(
      block_text, function, rename_map, true,
    ),
    function,
  )
}

///|
fn rewrite_wgsl_override_fn_block(
  block_text : String,
  function : WgslFunction,
  target_name : String,
  raw_target : String,
  base_name : String?,
) -> String {
  let rewritten_body = match base_name {
    Some(base) => {
      let redirect_map : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
      redirect_map.set(target_name, base)
      redirect_map.set(raw_target, base)
      rewrite_wgsl_virtual_identifier_spans(
        block_text, function, redirect_map, false,
      )
    }
    None => block_text
  }
  match function.qualifier_start {
    Some(start) =>
      rewritten_body[:start].to_owned() +
      "fn " +
      target_name +
      rewritten_body[function.name.end:rewritten_body.length()].to_owned()
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
fn apply_wgsl_virtual_overrides(
  source : String,
  alias_redirect_map : @hashmap.HashMap[String, String],
) -> String raise ComposerError {
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
          raise ComposerError::InvalidOverride(raw_target)
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
    return source
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
                  block.name,
                  wgsl_virtual_base_name(block.name),
                )
            }
            out = out + override_block
          }
          None =>
            out = out + rewrite_wgsl_virtual_fn_block(block.text, function)
        }
        continue
      }
      _ => ()
    }
    out = out + block.text
  }
  out
}

///|
fn strip_wgsl_virtual_functions(source : String) -> String {
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
          out = out + rewrite_wgsl_virtual_fn_block(block.text, function)
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
