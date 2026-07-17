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
  UnparsedDeclaration(String, Int)
}

///|
fn wgsl_virtual_override_error_from_parse(
  error : WgslParseError,
) -> WgslVirtualOverrideError {
  match error {
    UnparsedDeclaration(text, offset) => UnparsedDeclaration(text, offset)
  }
}

///|
fn wgsl_graph_block_function(block : WgslGraphBlock) -> WgslFunction? {
  match block.data {
    Function(function) => Some(function)
    _ => None
  }
}

///|
fn wgsl_graph_block_is_virtual_fn(block : WgslGraphBlock) -> Bool {
  match wgsl_graph_block_function(block) {
    Some(function) => function.qualifier() == Some(Virtual)
    None => false
  }
}

///|
fn wgsl_graph_block_override_target(block : WgslGraphBlock) -> String? {
  match wgsl_graph_block_function(block) {
    Some(function) =>
      if function.qualifier() == Some(Override) {
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
      Function(function) =>
        if function.qualifier() == Some(Override) {
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
pub fn collect_wgsl_virtual_override_targets_strict(
  source : String,
) -> Array[String] raise WgslParseError {
  let targets : Array[String] = []
  let graph = build_wgsl_declaration_graph(source)
  for block in graph.declaration_blocks {
    match wgsl_graph_block_function(block) {
      Some(function) if function.qualifier() == Some(Override) =>
        if function.name().name() != "" {
          targets.push(function.name().name())
        }
      _ => ()
    }
  }
  targets
}

///|
pub fn rewrite_wgsl_override_targets_with_binding_plan(
  source : String,
  plan : WgslReferenceRewritePlan,
) -> String raise WgslParseError {
  if !plan.has_symbol_bindings() {
    return source
  }
  let graph = build_wgsl_declaration_graph(source)
  let out = StringBuilder::new()
  for import_block in graph.import_blocks {
    out.write_string(emit_wgsl_graph_block_canonical(import_block))
  }
  for block in graph.declaration_blocks {
    guard wgsl_graph_block_function(block) is Some(function) else {
      out.write_string(emit_wgsl_graph_block_canonical(block))
      continue
    }
    if function.qualifier() != Some(Override) {
      out.write_string(emit_wgsl_graph_block_canonical(block))
      continue
    }
    let nodes : Array[WgslTokenReplacement] = []
    let raw_target = function.name().name()
    if split_last_identifier(raw_target) is None {
      out.write_string(emit_wgsl_graph_block_canonical(block))
      continue
    }
    let target = wgsl_binding_plan_redirect_target(raw_target, plan)
    if target != raw_target {
      nodes.push(
        WgslTokenReplacement(
          function.name().start(),
          function.name().end(),
          target,
        ),
      )
    }
    out.write_string(emit_wgsl_token_stream_canonical(block.tokens, nodes))
  }
  out.to_string()
}

///|
fn wgsl_override_body_references_target(
  function : WgslFunction,
  raw_targets : Array[String],
  target_name : String,
) -> Bool {
  let identifiers : Array[WgslIdent] = []
  collect_wgsl_function_body_identifier_nodes(function, identifiers)
  for ident in identifiers {
    if ident.name() == target_name {
      return true
    }
    for raw_target in raw_targets {
      if ident.name() == raw_target {
        return true
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
fn collect_wgsl_virtual_fn_nodes(
  function : WgslFunction,
  nodes : Array[WgslTokenReplacement],
) -> Unit {
  match (function.qualifier_start(), function.qualifier_end()) {
    (Some(start), Some(end_)) =>
      nodes.push(WgslTokenReplacement(start, end_, ""))
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
fn add_wgsl_virtual_rewrite_binding(
  plan : WgslReferenceRewritePlan,
  from_name : String,
  to_name : String,
) -> Unit {
  if from_name == to_name {
    return
  }
  match WgslReferencePath::from_text(from_name) {
    Some(reference_path) =>
      plan.add_symbol_reference_binding(
        WgslComposeSymbolIdentity("", from_name),
        reference_path,
        to_name,
      )
    None => ()
  }
}

///|
fn rewrite_wgsl_virtual_base_block(
  block : WgslGraphBlock,
  function : WgslFunction,
  target_name : String,
  base_name : String,
) -> String {
  let nodes : Array[WgslTokenReplacement] = []
  if target_name != base_name {
    let plan = WgslReferenceRewritePlan()
    add_wgsl_virtual_rewrite_binding(plan, target_name, base_name)
    collect_wgsl_bound_block_rewrite_nodes(block.data, plan, true, nodes)
  }
  collect_wgsl_virtual_fn_nodes(function, nodes)
  emit_wgsl_token_stream_canonical(block.tokens, nodes)
}

///|
fn collect_wgsl_override_body_reference_nodes(
  data : WgslGlobalDeclData,
  target_name : String,
  raw_target : String,
  original_raw_target : String,
  base_name : String,
  nodes : Array[WgslTokenReplacement],
) -> Unit {
  let plan = WgslReferenceRewritePlan()
  add_wgsl_virtual_rewrite_binding(plan, target_name, base_name)
  add_wgsl_virtual_rewrite_binding(plan, raw_target, base_name)
  add_wgsl_virtual_rewrite_binding(plan, original_raw_target, base_name)
  collect_wgsl_function_body_bound_rewrite_nodes(data, plan, nodes)
}

///|
fn rewrite_wgsl_override_fn_block(
  block : WgslGraphBlock,
  function : WgslFunction,
  target_name : String,
  override_name : String,
  raw_target : String,
  original_raw_target : String,
  base_name : String?,
) -> String {
  let nodes : Array[WgslTokenReplacement] = []
  match base_name {
    Some(base) =>
      collect_wgsl_override_body_reference_nodes(
        block.data,
        target_name,
        raw_target,
        original_raw_target,
        base,
        nodes,
      )
    None => ()
  }
  match (function.qualifier_start(), function.qualifier_end()) {
    (Some(start), Some(end_)) => {
      nodes.push(WgslTokenReplacement(start, end_, ""))
      nodes.push(
        WgslTokenReplacement(
          function.name().start(),
          function.name().end(),
          override_name,
        ),
      )
      emit_wgsl_token_stream_canonical(block.tokens, nodes)
    }
    _ => emit_wgsl_token_stream_canonical(block.tokens, nodes)
  }
}

///|
fn rewrite_wgsl_virtual_dispatch_block(
  block : WgslGraphBlock,
  override_names : Map[String, String],
  override_raw_targets : Map[String, String],
) -> String {
  let plan = WgslReferenceRewritePlan()
  for entry in override_names.iter() {
    let (target_name, override_name) = entry
    if target_name != override_name {
      match WgslReferencePath::from_text(target_name) {
        Some(reference_path) =>
          plan.add_symbol_reference_binding(
            WgslComposeSymbolIdentity("", target_name),
            reference_path,
            override_name,
          )
        None => ()
      }
      match override_raw_targets.get(target_name) {
        Some(raw_target) =>
          match WgslReferencePath::from_text(raw_target) {
            Some(reference_path) =>
              plan.add_symbol_reference_binding(
                WgslComposeSymbolIdentity("", raw_target),
                reference_path,
                override_name,
              )
            None => ()
          }
        None => ()
      }
    }
  }
  if !plan.has_symbol_bindings() {
    emit_wgsl_graph_block_canonical(block)
  } else {
    rewrite_wgsl_graph_block_with_binding_plan(block, plan, false)
  }
}

///|
fn wgsl_binding_plan_redirect_target(
  target : String,
  plan : WgslReferenceRewritePlan,
) -> String {
  if split_last_identifier(target) is None {
    return target
  }
  match plan.virtual_target_name_for_raw_target(target) {
    Some(virtual_target) => return virtual_target
    None => ()
  }
  match WgslReferencePath::from_text(target) {
    Some(reference_path) =>
      match plan.bound_binding_for_reference_path(reference_path) {
        Some(binding) => binding.final_name
        None => wgsl_flatten_path_identifier(target)
      }
    None => wgsl_flatten_path_identifier(target)
  }
}

///|
fn apply_wgsl_virtual_overrides_checked_with_binding_plan(
  source : String,
  plan : WgslReferenceRewritePlan,
) -> WgslVirtualOverrideOutput raise WgslParseError {
  let graph = build_wgsl_declaration_graph(source)
  let virtual_names : @set.Set[String] = Set([])
  let overrides : Map[String, String] = Map([])
  let override_base_names : Map[String, String] = Map([])
  let override_names : Map[String, String] = Map([])
  let override_raw_targets : Map[String, String] = Map([])
  for block in graph.declaration_blocks {
    if block.name() != "" && wgsl_graph_block_is_virtual_fn(block) {
      virtual_names.add(block.name())
    }
  }
  for block in graph.declaration_blocks {
    match wgsl_graph_block_function(block) {
      Some(function) if function.qualifier() == Some(Override) => {
        let raw_target = function.name().name()
        let target = wgsl_binding_plan_redirect_target(raw_target, plan)
        let original_raw_target = match
          plan.virtual_raw_target_name_for_target(target) {
          Some(original) => original
          None => raw_target
        }
        if !virtual_names.contains(target) {
          let invalid_target_name = match split_last_identifier(raw_target) {
            Some((_, name)) => name
            None => raw_target
          }
          return { source, invalid_override: Some(invalid_target_name) }
        }
        let needs_base = wgsl_override_body_references_target(
          function,
          [raw_target, original_raw_target],
          target,
        )
        let override_name = match
          plan.virtual_override_name_for_target(original_raw_target, target) {
          Some(name) => name
          None => target
        }
        let base_name = if override_name != target {
          Some(target)
        } else if needs_base {
          Some(wgsl_virtual_base_name(target))
        } else {
          None
        }
        match base_name {
          Some(base) => override_base_names.set(target, base)
          None => ()
        }
        override_names.set(target, override_name)
        override_raw_targets.set(target, original_raw_target)
        overrides.set(
          target,
          rewrite_wgsl_override_fn_block(
            block, function, target, override_name, raw_target, original_raw_target,
            base_name,
          ),
        )
      }
      Some(_) => ()
      None => ()
    }
  }
  if virtual_names.is_empty() || overrides.is_empty() {
    return { source, invalid_override: None }
  }
  let out = StringBuilder::new()
  for import_block in graph.import_blocks {
    out.write_string(emit_wgsl_graph_block_canonical(import_block))
  }
  for block in graph.declaration_blocks {
    match wgsl_graph_block_override_target(block) {
      Some(_) => continue
      None => ()
    }
    match wgsl_graph_block_function(block) {
      Some(function) if block.name() != "" &&
        function.qualifier() == Some(Virtual) => {
        match overrides.get(block.name()) {
          Some(override_block) => {
            let base_block = match override_base_names.get(block.name()) {
              Some(base_name) =>
                Some(
                  rewrite_wgsl_virtual_base_block(
                    block,
                    function,
                    block.name(),
                    base_name,
                  ),
                )
              None => None
            }
            match base_block {
              Some(base) => out.write_string(base)
              None => ()
            }
            out.write_string(override_block)
          }
          None =>
            out.write_string(rewrite_wgsl_virtual_fn_block(block, function))
        }
        continue
      }
      _ => ()
    }
    if overrides.get(block.name()) is Some(_) ||
      override_names.get(block.name()) is Some(_) {
      out.write_string(emit_wgsl_graph_block_canonical(block))
    } else {
      out.write_string(
        rewrite_wgsl_virtual_dispatch_block(
          block, override_names, override_raw_targets,
        ),
      )
    }
  }
  { source: out.to_string(), invalid_override: None }
}

///|
pub fn apply_wgsl_virtual_overrides_with_binding_plan(
  source : String,
  plan : WgslReferenceRewritePlan,
) -> String raise WgslVirtualOverrideError {
  let output = apply_wgsl_virtual_overrides_checked_with_binding_plan(
    source, plan,
  ) catch {
    error => raise wgsl_virtual_override_error_from_parse(error)
  }
  match output.invalid_override {
    Some(name) => raise InvalidOverride(name)
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
  let out = StringBuilder::new()
  let emitted_names : @set.Set[String] = Set([])
  for import_block in graph.import_blocks {
    out.write_string(emit_wgsl_graph_block_canonical(import_block))
  }
  for block in graph.declaration_blocks {
    if wgsl_graph_block_is_virtual_fn(block) {
      if block.name() != "" && emitted_names.contains(block.name()) {
        continue
      }
      match wgsl_graph_block_function(block) {
        Some(function) =>
          out.write_string(rewrite_wgsl_virtual_fn_block(block, function))
        None => out.write_string(emit_wgsl_graph_block_canonical(block))
      }
    } else {
      out.write_string(emit_wgsl_graph_block_canonical(block))
    }
    if block.name() != "" {
      emitted_names.add(block.name())
    }
  }
  out.to_string()
}

///|
