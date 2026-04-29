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
pub fn trim_trailing_semicolons(text : String) -> String {
  let mut out = text.trim().to_owned()
  while out.length() > 0 && out.code_unit_at(out.length() - 1).to_int() == 59 { // ';'
    out = out[:out.length() - 1].to_owned().trim().to_owned()
  }
  out
}

///|
pub(all) struct SourceLineSpan {
  text : String
  start : Int
  end : Int
}

///|
pub fn split_source_lines(source : String) -> Array[String] {
  let lines : Array[String] = []
  for line_item in source.split("\n") {
    lines.push(line_item.to_owned())
  }
  lines
}

///|
pub fn split_source_line_spans(source : String) -> Array[SourceLineSpan] {
  let spans : Array[SourceLineSpan] = []
  let mut offset = 0
  for line in split_source_lines(source) {
    spans.push(SourceLineSpan::{
      text: line,
      start: offset,
      end: offset + line.length(),
    })
    offset = offset + line.length() + 1
  }
  spans
}

///|
pub fn source_lines(source : String) -> Array[String] {
  let lines = split_source_lines(source)
  for i in 0..<lines.length() {
    let line = lines[i]
    if line.has_suffix("\r") {
      lines[i] = line[:line.length() - 1].to_owned()
    }
  }
  if source.has_suffix("\n") && lines.length() > 0 {
    lines.pop() |> ignore
  }
  lines
}

///|
pub fn starts_with_text(text : String, prefix : String) -> Bool {
  text.has_prefix(prefix)
}

///|
fn identifier_code_unit(code : Int) -> Bool {
  (code >= 65 && code <= 90) ||
  (code >= 97 && code <= 122) ||
  (code >= 48 && code <= 57) ||
  code == 95
}

///|
fn skip_ascii_space(text : String, start : Int) -> Int {
  let mut i = start
  while i < text.length() {
    let code = text.code_unit_at(i).to_int()
    if code == 32 || code == 9 {
      i = i + 1
      continue
    }
    break
  }
  i
}

///|
pub fn word_tail(text : String, word : String) -> String? {
  let trimmed = text.trim().to_owned()
  let start = skip_ascii_space(trimmed, 0)
  guard start + word.length() <= trimmed.length() else { return None }
  guard trimmed[start:start + word.length()].to_owned() == word else {
    return None
  }
  let end = start + word.length()
  if end < trimmed.length() &&
    identifier_code_unit(trimmed.code_unit_at(end).to_int()) {
    return None
  }
  Some(trimmed[end:trimmed.length()].to_owned().trim().to_owned())
}

///|
pub fn hash_directive_tail(line : String, directive : String) -> String? {
  let trimmed = line.trim().to_owned()
  guard trimmed.length() > 0 && trimmed.code_unit_at(0).to_int() == 35 else { // '#'
    return None
  }
  word_tail(trimmed[1:trimmed.length()].to_owned(), directive)
}

///|
pub fn import_brace_balance(text : String) -> Int {
  let mut balance = 0
  for i in 0..<text.length() {
    let code = text.code_unit_at(i).to_int()
    if code == 123 { // '{'
      balance = balance + 1
    } else if code == 125 { // '}'
      balance = balance - 1
    }
  }
  balance
}
