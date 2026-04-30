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
priv struct WgslGlobalBindingInfo {
  name : String
  group : Int
  binding : Int
  type_text : String
}

///|
pub fn dedupe_wgsl_duplicate_declarations(source : String) -> String {
  let graph = build_wgsl_declaration_graph(source)
  let mut deduped = ""
  let emitted_blocks : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
  for import_block in graph.import_blocks {
    deduped = deduped + import_block.text
  }
  for block in graph.declaration_blocks {
    if block.name != "" {
      let normalized_text = block.text.trim().to_owned()
      match emitted_blocks.get(block.name) {
        Some(existing_text) if existing_text == normalized_text => continue
        _ => emitted_blocks.set(block.name, normalized_text)
      }
    }
    deduped = deduped + block.text
  }
  deduped
}

///|
fn record_wgsl_lowered_suffix_redirect_candidate(
  suffix : String,
  lowered_name : String,
  declared_names : @hashmap.HashMap[String, Bool],
  candidate_redirects : @hashmap.HashMap[String, String],
  ambiguous_suffixes : @hashmap.HashMap[String, Bool],
) -> Unit {
  if suffix == "" || declared_names.contains(suffix) {
    return
  }
  match candidate_redirects.get(suffix) {
    Some(existing) if existing != lowered_name =>
      ambiguous_suffixes.set(suffix, true)
    Some(_) => ()
    None => candidate_redirects.set(suffix, lowered_name)
  }
}

///|
pub fn build_wgsl_unique_lowered_suffix_rename_plan(
  source : String,
) -> WgslRenamePlan {
  let graph = build_wgsl_declaration_graph(source)
  let declared_names : @hashmap.HashMap[String, Bool] = @hashmap.HashMap::new()
  let candidate_redirects : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
  let ambiguous_suffixes : @hashmap.HashMap[String, Bool] = @hashmap.HashMap::new()
  for block in graph.declaration_blocks {
    if block.name != "" {
      declared_names.set(block.name, true)
    }
  }
  for block in graph.declaration_blocks {
    let parts : Array[String] = []
    for part in block.name.split("__") {
      parts.push(part.to_owned())
    }
    for i in 1..<parts.length() {
      let mut suffix = ""
      for j in i..<parts.length() {
        if suffix != "" {
          suffix = "\{suffix}__"
        }
        suffix = "\{suffix}\{parts[j]}"
      }
      if suffix != "" {
        record_wgsl_lowered_suffix_redirect_candidate(
          suffix,
          block.name,
          declared_names,
          candidate_redirects,
          ambiguous_suffixes,
        )
      }
    }
  }
  let plan = WgslRenamePlan::empty()
  for entry in candidate_redirects.iter() {
    let (suffix, lowered_name) = entry
    if !ambiguous_suffixes.contains(suffix) {
      plan.add(suffix, lowered_name, ReferencesOnly)
    }
  }
  plan
}

///|
fn parse_wgsl_uint_literal_for_attribute(text : String) -> Int? {
  let trimmed = text.trim()
  let digits = if trimmed.has_suffix("u") || trimmed.has_suffix("U") {
    trimmed[:trimmed.length() - 1].to_owned()
  } else {
    trimmed.to_owned()
  }
  if digits == "" {
    return None
  }
  let mut value = 0
  for ch in digits {
    if ch < '0' || ch > '9' {
      return None
    }
    value = value * 10 + (ch.to_int() - '0'.to_int())
  }
  Some(value)
}

///|
fn wgsl_attribute_uint_value(
  attributes : Array[WgslAttribute],
  name : String,
) -> Int? {
  for attr in attributes {
    if attr.name == name {
      return parse_wgsl_uint_literal_for_attribute(attr.arguments)
    }
  }
  None
}

///|
fn wgsl_global_binding_info(block : WgslGraphBlock) -> WgslGlobalBindingInfo? {
  match block.data {
    WgslGlobalDeclData::GlobalVariable(global) => {
      guard wgsl_attribute_uint_value(global.attributes, "group") is Some(group) else {
        return None
      }
      guard wgsl_attribute_uint_value(global.attributes, "binding")
        is Some(binding) else {
        return None
      }
      guard global.ty is Some(type_text) else { return None }
      Some(WgslGlobalBindingInfo::{
        name: global.name.name,
        group,
        binding,
        type_text,
      })
    }
    _ => None
  }
}

///|
pub fn dedupe_wgsl_duplicate_resource_bindings(source : String) -> String {
  let graph = build_wgsl_declaration_graph(source)
  let binding_owner : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
  let duplicate_names : @hashmap.HashMap[String, Bool] = @hashmap.HashMap::new()
  let redirect_map : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
  for block in graph.declaration_blocks {
    guard wgsl_global_binding_info(block) is Some(info) else { continue }
    let key = "\{info.group}:\{info.binding}:\{info.type_text}"
    match binding_owner.get(key) {
      Some(owner) =>
        if info.name != owner {
          duplicate_names.set(info.name, true)
          redirect_map.set(info.name, owner)
        }
      None => binding_owner.set(key, info.name)
    }
  }
  if redirect_map.is_empty() {
    return source
  }
  let mut out = ""
  for import_block in graph.import_blocks {
    out = out + import_block.text
  }
  for block in graph.declaration_blocks {
    if duplicate_names.contains(block.name) {
      continue
    }
    out = out + block.text
  }
  rewrite_wgsl_declarations_with_rename_plan(
    out,
    build_wgsl_rename_plan_from_redirect_map(redirect_map, ReferencesOnly),
  )
}

///|
pub fn normalize_wgsl_composed_declarations(source : String) -> String {
  let deduped = dedupe_wgsl_duplicate_declarations(source)
  let suffix_plan = build_wgsl_unique_lowered_suffix_rename_plan(deduped)
  let suffix_rewritten = if suffix_plan.is_empty() {
    deduped
  } else {
    rewrite_wgsl_declarations_with_rename_plan(deduped, suffix_plan)
  }
  dedupe_wgsl_duplicate_resource_bindings(suffix_rewritten)
}
