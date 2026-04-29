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
// This layer mirrors naga_oil's writeback boundary: composable-module
// identifiers that naga's WGSL writer would rename are rejected before output,
// while final generated source still gets our compatibility sanitizer.
fn wgsl_writeback_identifier_requires_substitution(ident : String) -> Bool {
  if ident == "" {
    return false
  }
  ident == "alias" ||
  ident == "break" ||
  ident == "case" ||
  ident == "const" ||
  ident == "const_assert" ||
  ident == "continue" ||
  ident == "continuing" ||
  ident == "default" ||
  ident == "diagnostic" ||
  ident == "discard" ||
  ident == "else" ||
  ident == "enable" ||
  ident == "false" ||
  ident == "fn" ||
  ident == "for" ||
  ident == "if" ||
  ident == "let" ||
  ident == "loop" ||
  ident == "override" ||
  ident == "requires" ||
  ident == "return" ||
  ident == "struct" ||
  ident == "switch" ||
  ident == "true" ||
  ident == "var" ||
  ident == "while" ||
  ident == "in" ||
  ident.has_suffix("_") ||
  starts_with_text(ident, "__")
}

///|
fn sanitize_wgsl_writeback_identifier(ident : String) -> String {
  let mut out = ident
  while out.has_suffix("_") {
    out = out[:out.length() - 1].to_owned()
  }
  while starts_with_text(out, "__") {
    out = out[1:out.length()].to_owned()
  }
  if out == "" {
    out = "wgsl"
  }
  if wgsl_writeback_identifier_requires_substitution(out) {
    out = "\{out}_wgsl"
  }
  out
}

///|
fn wgsl_redirect_map_set_sanitized(
  redirect_map : @hashmap.HashMap[String, String],
  ident : String,
) -> Unit {
  if wgsl_writeback_identifier_requires_substitution(ident) {
    let sanitized = sanitize_wgsl_writeback_identifier(ident)
    if sanitized != ident {
      redirect_map.set(ident, sanitized)
    }
  }
}

///|
fn collect_wgsl_function_parameter_sanitizers(
  block_text : String,
  redirect_map : @hashmap.HashMap[String, String],
) -> Unit {
  let header_end = match block_text.find("{") {
    Some(index) => index
    None => block_text.length()
  }
  let header = block_text[:header_end].to_owned()
  guard header.find("fn ") is Some(fn_index) else { return }
  let fn_header = header[fn_index:header.length()].to_owned()
  guard fn_header.find("(") is Some(open_index) else { return }
  guard fn_header.find(")") is Some(close_index) else { return }
  if close_index <= open_index {
    return
  }
  let params = fn_header[open_index + 1:close_index].to_owned()
  for param_item in params.split(",") {
    let param = param_item.to_owned().trim().to_owned()
    if param == "" {
      continue
    }
    let mut end = 0
    while end < param.length() &&
          wgsl_identifier_char(param.code_unit_at(end).to_int()) {
      end = end + 1
    }
    if end > 0 {
      wgsl_redirect_map_set_sanitized(redirect_map, param[:end].to_owned())
    }
  }
}

///|
fn sanitize_wgsl_writeback_identifiers(source : String) -> String {
  let graph = build_wgsl_declaration_graph(source)
  let global_redirects : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
  for block in graph.declaration_blocks {
    wgsl_redirect_map_set_sanitized(global_redirects, block.name)
  }
  if global_redirects.is_empty() {
    let mut has_parameter_sanitizers = false
    for block in graph.declaration_blocks {
      let block_redirects : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
      collect_wgsl_function_parameter_sanitizers(block.text, block_redirects)
      if !block_redirects.is_empty() {
        has_parameter_sanitizers = true
      }
    }
    if !has_parameter_sanitizers {
      return source
    }
  }
  let mut sanitized = ""
  for import_block in graph.import_blocks {
    sanitized = sanitized + import_block.text
  }
  for block in graph.declaration_blocks {
    let block_redirects : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
    for entry in global_redirects.iter() {
      let (from_name, to_name) = entry
      block_redirects.set(from_name, to_name)
    }
    collect_wgsl_function_parameter_sanitizers(block.text, block_redirects)
    sanitized = sanitized +
      rewrite_wgsl_declaration_text_with_renamed_declarations(
        block.text,
        block_redirects,
      )
  }
  sanitized
}

///|
fn last_wgsl_identifier_in_text(text : String) -> String {
  let mut out = ""
  for token in tokenize(text, false) {
    match token {
      Token::Identifier(ident, _) => out = ident
      _ => ()
    }
  }
  out
}

///|
fn wgsl_line_contains_blend_src_attribute(line : String) -> Bool {
  let tokens = tokenize(line, false)
  let mut pending_attribute = false
  for token in tokens {
    match token {
      Token::Other(code, _) => pending_attribute = code == 64
      Token::Identifier(ident, _) => {
        if pending_attribute && ident == "blend_src" {
          return true
        }
        pending_attribute = false
      }
      _ => pending_attribute = false
    }
  }
  false
}

///|
fn wgsl_struct_member_allows_writeback_substitution(
  line : String,
  pending_blend_src : Bool,
) -> Bool {
  pending_blend_src || wgsl_line_contains_blend_src_attribute(line)
}

///|
fn validate_wgsl_struct_member_identifiers(
  source : String,
) -> Unit raise ComposerError {
  let graph = build_wgsl_declaration_graph(source)
  for block in graph.declaration_blocks {
    let trimmed = replace_comments(block.text).trim().to_owned()
    if !starts_with_text(trimmed, "struct ") {
      continue
    }
    let mut pending_blend_src = false
    for line_item in replace_comments(block.text).split("\n") {
      let line = line_item.to_owned()
      if wgsl_line_contains_blend_src_attribute(line) {
        pending_blend_src = true
      }
      let colon = wgsl_index_of_code_unit(line, 58)
      if colon < 0 {
        continue
      }
      let allows_writeback_substitution = wgsl_struct_member_allows_writeback_substitution(
        line, pending_blend_src,
      )
      pending_blend_src = false
      let member_name = last_wgsl_identifier_in_text(
        line[:colon].to_owned().trim().to_owned(),
      )
      if !allows_writeback_substitution &&
        member_name != "" &&
        wgsl_writeback_identifier_requires_substitution(member_name) {
        raise ComposerError::InvalidStructMemberIdentifier(member_name)
      }
    }
  }
}

///|
fn finalize_wgsl_writeback_source(
  source : String,
) -> String raise ComposerError {
  validate_wgsl_struct_member_identifiers(source)
  sanitize_wgsl_writeback_identifiers(source)
}
