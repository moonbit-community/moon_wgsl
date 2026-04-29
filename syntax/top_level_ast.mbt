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
pub(all) enum WgslTopLevelKind {
  Trivia
  Import
  DefineImportPath
  Define
  Declaration
} derive(Eq, Debug)

///|
pub(all) struct WgslTopLevelItem {
  kind : WgslTopLevelKind
  name : String
  text : String
  start : Int
  end : Int
}

///|
fn top_level_text_contains_code_unit(text : String, code : Int) -> Bool {
  for i in 0..<text.length() {
    if text.code_unit_at(i).to_int() == code {
      return true
    }
  }
  false
}

///|
fn top_level_identifier_char(code : Int) -> Bool {
  (code >= 65 && code <= 90) ||
  (code >= 97 && code <= 122) ||
  (code >= 48 && code <= 57) ||
  code == 95
}

///|
fn top_level_declaration_after_attribute(trimmed : String) -> String {
  let mut i = 0
  while i < trimmed.length() {
    while i < trimmed.length() {
      let code = trimmed.code_unit_at(i).to_int()
      if code == 32 || code == 9 {
        i = i + 1
      } else {
        break
      }
    }
    if i >= trimmed.length() || trimmed.code_unit_at(i).to_int() != 64 {
      break
    }
    i = i + 1
    while i < trimmed.length() &&
          top_level_identifier_char(trimmed.code_unit_at(i).to_int()) {
      i = i + 1
    }
    while i < trimmed.length() {
      let code = trimmed.code_unit_at(i).to_int()
      if code == 32 || code == 9 {
        i = i + 1
      } else {
        break
      }
    }
    if i < trimmed.length() && trimmed.code_unit_at(i).to_int() == 40 {
      let mut depth = 1
      i = i + 1
      while i < trimmed.length() && depth > 0 {
        let code = trimmed.code_unit_at(i).to_int()
        if code == 40 {
          depth = depth + 1
        } else if code == 41 {
          depth = depth - 1
        }
        i = i + 1
      }
    }
  }
  if i >= trimmed.length() {
    ""
  } else {
    top_level_declaration_name(trimmed[i:trimmed.length()].to_owned())
  }
}

///|
fn top_level_declaration_name(line : String) -> String {
  let trimmed = line.trim().to_owned()
  if trimmed == "" {
    return ""
  }
  if starts_with_text(trimmed, "@") {
    return top_level_declaration_after_attribute(trimmed)
  }
  if starts_with_text(trimmed, "struct ") {
    return top_level_name_after_keyword(trimmed, 7)
  }
  if starts_with_text(trimmed, "fn ") {
    return top_level_name_after_keyword(trimmed, 3)
  }
  if starts_with_text(trimmed, "virtual fn ") {
    return top_level_name_after_keyword(trimmed, 11)
  }
  if starts_with_text(trimmed, "override fn ") {
    let rest = trimmed[12:trimmed.length()].to_owned()
    let mut end = 0
    while end < rest.length() {
      let code = rest.code_unit_at(end).to_int()
      if top_level_identifier_char(code) {
        end = end + 1
        continue
      }
      if code == 58 &&
        end + 1 < rest.length() &&
        rest.code_unit_at(end + 1).to_int() == 58 {
        end = end + 2
        continue
      }
      break
    }
    return if end == 0 { "" } else { rest[:end].to_owned() }
  }
  if starts_with_text(trimmed, "const ") {
    return top_level_name_after_keyword(trimmed, 6)
  }
  if starts_with_text(trimmed, "override ") {
    return top_level_name_after_keyword(trimmed, 9)
  }
  if starts_with_text(trimmed, "alias ") {
    return top_level_name_after_keyword(trimmed, 6)
  }
  if starts_with_text(trimmed, "type ") {
    return top_level_name_after_keyword(trimmed, 5)
  }
  if starts_with_text(trimmed, "var") {
    let mut i = 3
    while i < trimmed.length() &&
          (
            trimmed.code_unit_at(i).to_int() == 32 ||
            trimmed.code_unit_at(i).to_int() == 9
          ) {
      i = i + 1
    }
    if i < trimmed.length() && trimmed.code_unit_at(i).to_int() == 60 {
      while i < trimmed.length() && trimmed.code_unit_at(i).to_int() != 62 {
        i = i + 1
      }
      if i < trimmed.length() {
        i = i + 1
      }
    }
    while i < trimmed.length() &&
          (
            trimmed.code_unit_at(i).to_int() == 32 ||
            trimmed.code_unit_at(i).to_int() == 9
          ) {
      i = i + 1
    }
    let start = i
    while i < trimmed.length() &&
          top_level_identifier_char(trimmed.code_unit_at(i).to_int()) {
      i = i + 1
    }
    return if i == start { "" } else { trimmed[start:i].to_owned() }
  }
  ""
}

///|
fn top_level_name_after_keyword(trimmed : String, offset : Int) -> String {
  let rest = trimmed[offset:trimmed.length()].to_owned()
  let mut end = 0
  while end < rest.length() &&
        top_level_identifier_char(rest.code_unit_at(end).to_int()) {
    end = end + 1
  }
  if end == 0 {
    ""
  } else {
    rest[:end].to_owned()
  }
}

///|
fn top_level_push_directive_item(
  items : Array[WgslTopLevelItem],
  kind : WgslTopLevelKind,
  line : String,
  start : Int,
) -> Unit {
  let text = "\{line}\n"
  items.push(WgslTopLevelItem::{
    kind,
    name: "",
    text,
    start,
    end: start + text.length(),
  })
}

///|
fn top_level_push_trivia_item(
  items : Array[WgslTopLevelItem],
  lines : Array[String],
  start : Int,
) -> Unit {
  if lines.length() == 0 {
    return
  }
  let mut text = ""
  for line in lines {
    text = "\{text}\{line}\n"
  }
  items.push(WgslTopLevelItem::{
    kind: WgslTopLevelKind::Trivia,
    name: "",
    text,
    start,
    end: start + text.length(),
  })
}

///|
fn top_level_lines_have_text(lines : Array[String]) -> Bool {
  for line in lines {
    if line.trim() != "" {
      return true
    }
  }
  false
}

///|
pub fn parse_wgsl_top_level_items(source : String) -> Array[WgslTopLevelItem] {
  let lines : Array[String] = []
  let cleaned_lines : Array[String] = []
  let line_starts : Array[Int] = []
  let mut offset = 0
  for line_item in source.split("\n") {
    let line = line_item.to_owned()
    lines.push(line)
    line_starts.push(offset)
    offset = offset + line.length() + 1
  }
  for line_item in replace_comments(source).split("\n") {
    cleaned_lines.push(line_item.to_owned())
  }

  let items : Array[WgslTopLevelItem] = []
  let pending_prefix : Array[String] = []
  let mut pending_prefix_start = 0
  let mut i = 0
  while i < lines.length() {
    let line = lines[i]
    let cleaned_line = cleaned_lines[i]
    let trimmed = cleaned_line.trim().to_owned()
    let decl_name_hint = top_level_declaration_name(trimmed)
    if trimmed == "" || (starts_with_text(trimmed, "@") && decl_name_hint == "") {
      if pending_prefix.length() == 0 {
        pending_prefix_start = line_starts[i]
      }
      pending_prefix.push(line)
      i = i + 1
      continue
    }
    if hash_directive_tail(trimmed, "define_import_path") is Some(_) {
      top_level_push_trivia_item(items, pending_prefix, pending_prefix_start)
      pending_prefix.clear()
      top_level_push_directive_item(
        items,
        WgslTopLevelKind::DefineImportPath,
        line,
        line_starts[i],
      )
      i = i + 1
      continue
    }
    if hash_directive_tail(trimmed, "define") is Some(_) {
      top_level_push_trivia_item(items, pending_prefix, pending_prefix_start)
      pending_prefix.clear()
      top_level_push_directive_item(
        items,
        WgslTopLevelKind::Define,
        line,
        line_starts[i],
      )
      i = i + 1
      continue
    }
    if hash_directive_tail(trimmed, "import") is Some(import_tail) {
      top_level_push_trivia_item(items, pending_prefix, pending_prefix_start)
      pending_prefix.clear()
      let block_start = line_starts[i]
      let mut import_block = line
      let mut balance = import_brace_balance(import_tail)
      while balance > 0 && i + 1 < lines.length() {
        i = i + 1
        let next_line = lines[i]
        import_block = "\{import_block}\n\{next_line}"
        balance = balance + import_brace_balance(cleaned_lines[i])
      }
      import_block = "\{import_block}\n"
      items.push(WgslTopLevelItem::{
        kind: WgslTopLevelKind::Import,
        name: "",
        text: import_block,
        start: block_start,
        end: block_start + import_block.length(),
      })
      i = i + 1
      continue
    }

    let block_lines : Array[String] = []
    let block_start = if pending_prefix.length() > 0 {
      pending_prefix_start
    } else {
      line_starts[i]
    }
    for prefix_line in pending_prefix {
      block_lines.push(prefix_line)
    }
    pending_prefix.clear()
    let mut saw_brace = false
    let mut brace_depth = 0
    let mut done = false
    while !done {
      let block_line = lines[i]
      let cleaned_block_line = cleaned_lines[i]
      block_lines.push(block_line)
      if top_level_text_contains_code_unit(cleaned_block_line, 123) {
        saw_brace = true
      }
      brace_depth = brace_depth + import_brace_balance(cleaned_block_line)
      let block_trimmed = cleaned_block_line.trim().to_owned()
      if saw_brace {
        done = brace_depth == 0
      } else {
        done = block_trimmed.has_suffix(";")
      }
      if !done {
        i = i + 1
        if i >= lines.length() {
          done = true
        }
      }
    }
    let mut block_text = ""
    for block_line in block_lines {
      block_text = "\{block_text}\{block_line}\n"
    }
    items.push(WgslTopLevelItem::{
      kind: WgslTopLevelKind::Declaration,
      name: decl_name_hint,
      text: block_text,
      start: block_start,
      end: block_start + block_text.length(),
    })
    i = i + 1
  }
  if top_level_lines_have_text(pending_prefix) {
    top_level_push_trivia_item(items, pending_prefix, pending_prefix_start)
  }
  items
}
