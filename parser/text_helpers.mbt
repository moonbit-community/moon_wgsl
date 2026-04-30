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
priv struct SourceLineSpan {
  text : String
  start : Int
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
fn split_source_line_spans(source : String) -> Array[SourceLineSpan] {
  let spans : Array[SourceLineSpan] = []
  let mut offset = 0
  for line in split_source_lines(source) {
    spans.push(SourceLineSpan::{ text: line, start: offset })
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
fn tokenize_wgsl_directive_line(
  line : String,
) -> Array[(@generated.Token, Int, Int)]? {
  let trimmed = line.trim().to_owned()
  guard trimmed.length() > 0 && trimmed.code_unit_at(0).to_int() == 35 else {
    return None
  }
  let body_start = skip_ascii_space(trimmed, 1)
  let mut end = 0
  let body = trimmed[body_start:trimmed.length()].to_owned()
  while end < body.length() &&
        identifier_code_unit(body.code_unit_at(end).to_int()) {
    end = end + 1
  }
  if end == 0 {
    return None
  }
  let name = body[:end].to_owned()
  let tail = body[end:body.length()].to_owned().trim().to_owned()
  let tokens : Array[(@generated.Token, Int, Int)] = [
    (@generated.Token::HASH, 0, 1),
    (
      @generated.Token::DIRECTIVE_HEAD((name, trimmed)),
      body_start,
      body_start + end,
    ),
  ]
  if tail != "" {
    let tail_start = trimmed.length() - tail.length()
    tokens.push(
      (@generated.Token::DIRECTIVE_TAIL(tail), tail_start, trimmed.length()),
    )
  }
  tokens.push((@generated.Token::EOF, trimmed.length(), trimmed.length()))
  Some(tokens)
}

///|
fn parse_wgsl_directive_line(line : String) -> WgslDirective? {
  guard tokenize_wgsl_directive_line(line) is Some(tokens) else { return None }
  let parsed = @generated.directive_line(tokens) catch { _ => return None }
  Some(parsed)
}

///|
pub fn wgsl_directive_tail(line : String, kind : WgslDirectiveKind) -> String? {
  match parse_wgsl_directive_line(line) {
    Some(parsed) => if parsed.kind == kind { Some(parsed.tail) } else { None }
    None => None
  }
}

///|
pub fn wgsl_directive_prefix_tail(
  line : String,
  kind : WgslDirectiveKind,
) -> String? {
  let prefix = match kind {
    WgslDirectiveKind::Else => "else"
    WgslDirectiveKind::Endif => "endif"
    _ => return wgsl_directive_tail(line, kind)
  }
  let trimmed = line.trim().to_owned()
  guard trimmed.length() > 0 && trimmed.code_unit_at(0).to_int() == 35 else {
    return None
  }
  let mut start = skip_ascii_space(trimmed, 1)
  guard start + prefix.length() <= trimmed.length() else { return None }
  guard trimmed[start:start + prefix.length()].to_owned() == prefix else {
    return None
  }
  start = start + prefix.length()
  let tail = trimmed[start:trimmed.length()].to_owned()
  let tokens : Array[(@generated.Token, Int, Int)] = [
    (@generated.Token::HASH, 0, 1),
    (@generated.Token::PREFIX, start - prefix.length(), start),
  ]
  if tail != "" {
    tokens.push(
      (@generated.Token::DIRECTIVE_TAIL(tail), start, trimmed.length()),
    )
  }
  tokens.push((@generated.Token::EOF, trimmed.length(), trimmed.length()))
  let parsed = @generated.directive_prefix_tail(tokens) catch {
    _ => return None
  }
  Some(parsed)
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
