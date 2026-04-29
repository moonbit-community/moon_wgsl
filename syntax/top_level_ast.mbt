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
priv struct WgslTopLevelLine {
  text : String
  cleaned : String
  start : Int
}

///|
priv struct WgslTopLevelParser {
  mut line_view : ArrayView[WgslTopLevelLine]
  pending_prefix : Array[String]
  mut pending_prefix_start : Int
}

///|
fn WgslTopLevelParser::new(source : String) -> WgslTopLevelParser {
  let lines : Array[WgslTopLevelLine] = []
  let cleaned_lines = split_source_lines(replace_comments(source))
  let spans = split_source_line_spans(source)
  for i in 0..<spans.length() {
    let cleaned = if i < cleaned_lines.length() { cleaned_lines[i] } else { "" }
    lines.push(WgslTopLevelLine::{
      text: spans[i].text,
      cleaned,
      start: spans[i].start,
    })
  }
  WgslTopLevelParser::{
    line_view: lines[:],
    pending_prefix: [],
    pending_prefix_start: 0,
  }
}

///|
fn WgslTopLevelParser::view(
  self : WgslTopLevelParser,
) -> ArrayView[WgslTopLevelLine] {
  self.line_view
}

///|
fn WgslTopLevelParser::update_view(
  self : WgslTopLevelParser,
  view : ArrayView[WgslTopLevelLine],
) -> Unit {
  self.line_view = view
}

///|
fn WgslTopLevelParser::push_pending_prefix(
  self : WgslTopLevelParser,
  line : WgslTopLevelLine,
) -> Unit {
  if self.pending_prefix.length() == 0 {
    self.pending_prefix_start = line.start
  }
  self.pending_prefix.push(line.text)
}

///|
fn WgslTopLevelParser::flush_trivia(
  self : WgslTopLevelParser,
  items : Array[WgslTopLevelItem],
) -> Unit {
  top_level_push_trivia_item(
    items,
    self.pending_prefix,
    self.pending_prefix_start,
  )
  self.pending_prefix.clear()
}

///|
fn WgslTopLevelParser::parse_directive_item(
  self : WgslTopLevelParser,
  items : Array[WgslTopLevelItem],
  line : WgslTopLevelLine,
  rest : ArrayView[WgslTopLevelLine],
  kind : WgslTopLevelKind,
) -> Unit {
  self.flush_trivia(items)
  top_level_push_directive_item(items, kind, line.text, line.start)
  self.update_view(rest)
}

///|
fn WgslTopLevelParser::parse_import_item(
  self : WgslTopLevelParser,
  items : Array[WgslTopLevelItem],
  line : WgslTopLevelLine,
  rest : ArrayView[WgslTopLevelLine],
  directive : WgslDirective,
) -> Unit {
  self.flush_trivia(items)
  let block_start = line.start
  let mut import_block = line.text
  let mut balance = import_brace_balance(directive.tail)
  self.update_view(rest)
  while balance > 0 {
    match self.view() {
      [next_line, .. next_rest] => {
        import_block = "\{import_block}\n\{next_line.text}"
        balance = balance + import_brace_balance(next_line.cleaned)
        self.update_view(next_rest)
        continue
      }
      [] => break
    }
  }
  import_block = "\{import_block}\n"
  items.push(WgslTopLevelItem::{
    kind: WgslTopLevelKind::Import,
    name: "",
    text: import_block,
    start: block_start,
    end: block_start + import_block.length(),
  })
}

///|
fn WgslTopLevelParser::parse_declaration_item(
  self : WgslTopLevelParser,
  items : Array[WgslTopLevelItem],
  decl_name_hint : String,
) -> Unit {
  let block_lines : Array[String] = []
  let block_start = if self.pending_prefix.length() > 0 {
    self.pending_prefix_start
  } else {
    match self.view() {
      [line, ..] => line.start
      [] => 0
    }
  }
  for prefix_line in self.pending_prefix {
    block_lines.push(prefix_line)
  }
  self.pending_prefix.clear()
  let mut saw_brace = false
  let mut brace_depth = 0
  while true {
    let (block_line, cleaned_block_line) = match self.view() {
      [line, .. rest] => {
        self.update_view(rest)
        (line.text, line.cleaned)
      }
      [] => break
    }
    block_lines.push(block_line)
    if top_level_text_contains_code_unit(cleaned_block_line, 123) {
      saw_brace = true
    }
    brace_depth = brace_depth + import_brace_balance(cleaned_block_line)
    let block_trimmed = cleaned_block_line.trim().to_owned()
    let done = if saw_brace {
      brace_depth == 0
    } else {
      block_trimmed.has_suffix(";")
    }
    if done {
      break
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
}

///|
fn WgslTopLevelParser::parse_items(
  self : WgslTopLevelParser,
) -> Array[WgslTopLevelItem] {
  let items : Array[WgslTopLevelItem] = []
  while true {
    match self.view() {
      [line, .. rest] => {
        let trimmed = line.cleaned.trim().to_owned()
        let decl_name_hint = top_level_declaration_name(trimmed)
        if trimmed == "" ||
          (starts_with_text(trimmed, "@") && decl_name_hint == "") {
          self.push_pending_prefix(line)
          self.update_view(rest)
          continue
        }
        if parse_wgsl_directive_line(trimmed) is Some(directive) {
          match directive.kind {
            WgslDirectiveKind::DefineImportPath => {
              self.parse_directive_item(
                items,
                line,
                rest,
                WgslTopLevelKind::DefineImportPath,
              )
              continue
            }
            WgslDirectiveKind::Define => {
              self.parse_directive_item(
                items,
                line,
                rest,
                WgslTopLevelKind::Define,
              )
              continue
            }
            WgslDirectiveKind::Import => {
              self.parse_import_item(items, line, rest, directive)
              continue
            }
            _ => ()
          }
        }
        self.parse_declaration_item(items, decl_name_hint)
      }
      [] => break
    }
  }
  if top_level_lines_have_text(self.pending_prefix) {
    self.flush_trivia(items)
  }
  items
}

///|
pub fn parse_wgsl_top_level_items(source : String) -> Array[WgslTopLevelItem] {
  WgslTopLevelParser::new(source).parse_items()
}
