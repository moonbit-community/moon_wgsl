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
fn wgsl_redirect_declaration_keyword(ident : String) -> Bool {
  ident == "fn" ||
  ident == "struct" ||
  ident == "const" ||
  ident == "override" ||
  ident == "alias" ||
  ident == "var" ||
  ident == "let"
}

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
pub fn rewrite_wgsl_declaration_text_with_map(
  source : String,
  redirect_map : @hashmap.HashMap[String, String],
  rewrite_declaration_names : Bool,
) -> String {
  let mut output = ""
  let mut i = 0
  let mut in_substitution_position = true
  let mut in_line_comment = false
  let mut in_string = false
  let mut block_comment_depth = 0
  let mut pending_declaration_name = false
  let mut pending_template_depth = 0

  while i < source.length() {
    let code = source.code_unit_at(i).to_int()
    if in_line_comment {
      output = output + code_unit_to_string(code)
      i = i + 1
      if code == 10 {
        in_line_comment = false
        in_substitution_position = true
      }
      continue
    }
    if block_comment_depth > 0 {
      if code == 47 &&
        i + 1 < source.length() &&
        source.code_unit_at(i + 1).to_int() == 42 {
        output = output + source[i:i + 2].to_owned()
        block_comment_depth = block_comment_depth + 1
        i = i + 2
        continue
      }
      if code == 42 &&
        i + 1 < source.length() &&
        source.code_unit_at(i + 1).to_int() == 47 {
        output = output + source[i:i + 2].to_owned()
        block_comment_depth = block_comment_depth - 1
        i = i + 2
        continue
      }
      output = output + code_unit_to_string(code)
      i = i + 1
      continue
    }
    if in_string {
      if code == 92 && i + 1 < source.length() {
        output = output + source[i:i + 2].to_owned()
        i = i + 2
        continue
      }
      output = output + code_unit_to_string(code)
      i = i + 1
      if code == 34 {
        in_string = false
        in_substitution_position = true
      }
      continue
    }
    if code == 47 &&
      i + 1 < source.length() &&
      source.code_unit_at(i + 1).to_int() == 47 {
      output = output + source[i:i + 2].to_owned()
      in_line_comment = true
      i = i + 2
      continue
    }
    if code == 47 &&
      i + 1 < source.length() &&
      source.code_unit_at(i + 1).to_int() == 42 {
      output = output + source[i:i + 2].to_owned()
      block_comment_depth = 1
      i = i + 2
      continue
    }
    if code == 34 {
      output = output + code_unit_to_string(code)
      in_string = true
      i = i + 1
      continue
    }
    if tokenizer_identifier_start(code) {
      let start = i
      i = i + 1
      while i < source.length() {
        let next_code = source.code_unit_at(i).to_int()
        if tokenizer_identifier_continue(next_code) {
          i = i + 1
          continue
        }
        if next_code == 58 &&
          i + 1 < source.length() &&
          source.code_unit_at(i + 1).to_int() == 58 {
          i = i + 2
          continue
        }
        break
      }
      let ident = source[start:i].to_owned()
      if pending_declaration_name && pending_template_depth == 0 {
        if rewrite_declaration_names {
          match redirect_map.get(ident) {
            Some(rewritten_ident) => output = output + rewritten_ident
            None => output = output + ident
          }
        } else {
          output = output + ident
        }
        pending_declaration_name = false
      } else if in_substitution_position {
        match redirect_map.get(ident) {
          Some(rewritten_ident) => output = output + rewritten_ident
          None => output = output + ident
        }
      } else {
        output = output + ident
      }
      if wgsl_redirect_declaration_keyword(ident) {
        pending_declaration_name = true
        pending_template_depth = 0
      }
      in_substitution_position = true
      continue
    }
    if pending_declaration_name {
      if code == 60 {
        pending_template_depth = pending_template_depth + 1
      } else if code == 62 && pending_template_depth > 0 {
        pending_template_depth = pending_template_depth - 1
      }
    }
    output = output + code_unit_to_string(code)
    i = i + 1
    if code == 46 || code == 64 {
      in_substitution_position = false
    } else {
      in_substitution_position = true
    }
  }

  output
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
      rewrite_wgsl_declaration_text_with_redirects(block.text, redirect_map)
  }
  rewritten
}
