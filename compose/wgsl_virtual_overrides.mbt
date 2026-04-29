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
fn wgsl_index_of_code_unit(text : String, code : Int) -> Int {
  for i in 0..<text.length() {
    if text.code_unit_at(i).to_int() == code {
      return i
    }
  }
  -1
}

///|
fn wgsl_virtual_token_end(token : Token) -> Int {
  match token {
    Token::Identifier(text, pos) | Token::Whitespace(text, pos) =>
      pos + text.length()
    Token::Other(_, pos) => pos + 1
  }
}

///|
fn wgsl_token_rewrite_source(block_text : String) -> String {
  replace_comments(block_text)
}

///|
fn wgsl_source_block_function(block_text : String) -> WgslFunction? {
  let unit = parse_wgsl_translation_unit(block_text)
  for decl in unit.declarations {
    match decl.data {
      WgslGlobalDeclData::Function(function) => return Some(function)
      _ => ()
    }
  }
  None
}

///|
fn wgsl_source_block_is_virtual_fn(block_text : String) -> Bool {
  match wgsl_source_block_function(block_text) {
    Some(function) => function.qualifier == "virtual"
    None => false
  }
}

///|
fn wgsl_source_block_override_target(block_text : String) -> String? {
  match wgsl_source_block_function(block_text) {
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
  let unit = parse_wgsl_translation_unit(source)
  for decl in unit.declarations {
    match decl.data {
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
fn wgsl_override_body_text(block_text : String) -> String {
  let brace = wgsl_index_of_code_unit(block_text, 123)
  if brace < 0 || brace + 1 >= block_text.length() {
    ""
  } else {
    block_text[brace + 1:block_text.length()].to_owned()
  }
}

///|
fn wgsl_override_body_references_target(
  block_text : String,
  raw_target : String,
  target_name : String,
) -> Bool {
  let body = wgsl_override_body_text(block_text)
  wgsl_source_contains_identifier(body, raw_target) ||
  wgsl_source_contains_identifier(body, target_name)
}

///|
fn wgsl_virtual_base_name(target_name : String) -> String {
  "\{target_name}__virtual_base"
}

///|
fn rewrite_wgsl_virtual_fn_block(block_text : String) -> String {
  let tokens = tokenize(wgsl_token_rewrite_source(block_text), false)
  let mut i = 0
  while i + 1 < tokens.length() {
    match (tokens[i], tokens[i + 1]) {
      (Token::Identifier("virtual", start), Token::Identifier("fn", fn_start)) =>
        return block_text[:start].to_owned() +
          block_text[fn_start:block_text.length()].to_owned()
      _ => ()
    }
    i = i + 1
  }
  block_text
}

///|
fn rewrite_wgsl_virtual_base_block(
  block_text : String,
  target_name : String,
  base_name : String,
) -> String {
  let rename_map : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
  rename_map.set(target_name, base_name)
  rewrite_wgsl_declaration_text_with_map(
    rewrite_wgsl_virtual_fn_block(block_text),
    rename_map,
    true,
  )
}

///|
fn rewrite_wgsl_override_fn_block(
  block_text : String,
  target_name : String,
  base_name : String?,
) -> String {
  let tokens = tokenize(wgsl_token_rewrite_source(block_text), false)
  let mut out = block_text
  let mut i = 0
  while i + 2 < tokens.length() {
    match (tokens[i], tokens[i + 1], tokens[i + 2]) {
      (
        Token::Identifier("override", start),
        Token::Identifier("fn", _),
        Token::Identifier(_, _),
      ) => {
        let mut end = wgsl_virtual_token_end(tokens[i + 2])
        let mut j = i + 3
        while j + 2 < tokens.length() {
          match (tokens[j], tokens[j + 1], tokens[j + 2]) {
            (Token::Other(58, _), Token::Other(58, _), Token::Identifier(_, _)) => {
              end = wgsl_virtual_token_end(tokens[j + 2])
              j = j + 3
            }
            _ => break
          }
        }
        out = block_text[:start].to_owned() +
          "fn " +
          target_name +
          block_text[end:block_text.length()].to_owned()
        break
      }
      _ => ()
    }
    i = i + 1
  }
  match base_name {
    Some(base) => {
      let redirect_map : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
      redirect_map.set(target_name, base)
      match wgsl_source_block_override_target(block_text) {
        Some(raw_target) => redirect_map.set(raw_target, base)
        None => ()
      }
      rewrite_wgsl_declaration_text_with_map(out, redirect_map, false)
    }
    None => out
  }
}

///|
fn wgsl_alias_redirect_target(
  target : String,
  alias_redirect_map : @hashmap.HashMap[String, String],
) -> String {
  match alias_redirect_map.get(target) {
    Some(redirected) => redirected
    None =>
      if target.contains("::") {
        let segments : Array[String] = []
        for segment in target.split("::") {
          segments.push(segment.to_owned())
        }
        segments.join("__")
      } else {
        target
      }
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
    if block.name != "" && wgsl_source_block_is_virtual_fn(block.text) {
      virtual_names.set(block.name, true)
    }
  }
  for block in graph.declaration_blocks {
    match wgsl_source_block_override_target(block.text) {
      Some(raw_target) => {
        let target = wgsl_alias_redirect_target(raw_target, alias_redirect_map)
        if !virtual_names.contains(target) {
          raise ComposerError::InvalidOverride(raw_target)
        }
        let needs_base = wgsl_override_body_references_target(
          block.text,
          raw_target,
          target,
        )
        override_needs_base.set(target, needs_base)
        let base_name = if needs_base {
          Some(wgsl_virtual_base_name(target))
        } else {
          None
        }
        overrides.set(
          target,
          rewrite_wgsl_override_fn_block(block.text, target, base_name),
        )
      }
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
    match wgsl_source_block_override_target(block.text) {
      Some(_) => continue
      None => ()
    }
    if block.name != "" && wgsl_source_block_is_virtual_fn(block.text) {
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
                block.name,
                wgsl_virtual_base_name(block.name),
              )
          }
          out = out + override_block
        }
        None => out = out + rewrite_wgsl_virtual_fn_block(block.text)
      }
      continue
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
    if wgsl_source_block_is_virtual_fn(block.text) {
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
    if wgsl_source_block_is_virtual_fn(block.text) {
      if block.name != "" && emitted_names.contains(block.name) {
        continue
      }
      out = out + rewrite_wgsl_virtual_fn_block(block.text)
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
