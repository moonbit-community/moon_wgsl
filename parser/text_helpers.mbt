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
pub fn split_source_lines(source : String) -> Array[String] {
  let lines : Array[String] = []
  for line_item in source.split("\n") {
    lines.push(line_item.to_owned())
  }
  lines
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
fn trim_ascii_space_end(text : String, start : Int) -> Int {
  let mut end = text.length()
  while end > start {
    let code = text.code_unit_at(end - 1).to_int()
    if code == 32 || code == 9 || code == 10 || code == 13 {
      end = end - 1
      continue
    }
    break
  }
  end
}

///|
fn tokenize_wgsl_directive_line(
  line : String,
  source_start : Int,
) -> Array[(@generated.Token, Int, Int)]? {
  let hash_start = skip_ascii_space(line, 0)
  guard hash_start < line.length() &&
    line.code_unit_at(hash_start).to_int() == 35 else {
    return None
  }
  let body_start = skip_ascii_space(line, hash_start + 1)
  let mut end = 0
  let body = line[body_start:line.length()].to_owned()
  while end < body.length() &&
        identifier_code_unit(body.code_unit_at(end).to_int()) {
    end = end + 1
  }
  if end == 0 {
    return None
  }
  let name = body[:end].to_owned()
  let name_start = body_start
  let name_end = body_start + end
  let tail_start = skip_ascii_space(line, name_end)
  let tail_end = trim_ascii_space_end(line, tail_start)
  let tail = if tail_end > tail_start {
    line[tail_start:tail_end].to_owned()
  } else {
    ""
  }
  let text_end = if tail != "" { tail_end } else { name_end }
  let text = line[hash_start:text_end].to_owned()
  let absolute_hash_start = source_start + hash_start
  let absolute_text_end = source_start + text_end
  let absolute_name_start = source_start + name_start
  let absolute_name_end = source_start + name_end
  let absolute_tail_start = source_start + tail_start
  let absolute_tail_end = source_start + tail_end
  let tokens : Array[(@generated.Token, Int, Int)] = [
    (@generated.Token::HASH, absolute_hash_start, absolute_hash_start + 1),
    (
      @generated.Token::DIRECTIVE_HEAD(
        (
          name, text, absolute_hash_start, absolute_text_end, absolute_name_start,
          absolute_name_end,
        ),
      ),
      absolute_name_start,
      absolute_name_end,
    ),
  ]
  if tail != "" {
    tokens.push(
      (
        @generated.Token::DIRECTIVE_TAIL(
          (tail, absolute_tail_start, absolute_tail_end),
        ),
        absolute_tail_start,
        absolute_tail_end,
      ),
    )
  }
  tokens.push((@generated.Token::EOF, absolute_text_end, absolute_text_end))
  Some(tokens)
}

///|
fn parse_wgsl_directive_line_at(
  line : String,
  source_start : Int,
) -> WgslDirective? {
  guard tokenize_wgsl_directive_line(line, source_start) is Some(tokens) else {
    return None
  }
  let parsed = @generated.directive_line(tokens) catch { _ => return None }
  Some(parsed)
}

///|
fn parse_wgsl_directive_line(line : String) -> WgslDirective? {
  parse_wgsl_directive_line_at(line, 0)
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
      (
        @generated.Token::DIRECTIVE_TAIL((tail, start, trimmed.length())),
        start,
        trimmed.length(),
      ),
    )
  }
  tokens.push((@generated.Token::EOF, trimmed.length(), trimmed.length()))
  let parsed = @generated.directive_prefix_tail(tokens) catch {
    _ => return None
  }
  Some(parsed)
}

///|
pub fn wgsl_token_brace_balance(text : String) -> Int {
  let mut balance = 0
  for token in tokenize(text, false) {
    match token {
      Token::Other(123, _) => balance = balance + 1
      Token::Other(125, _) => balance = balance - 1
      _ => ()
    }
  }
  balance
}
