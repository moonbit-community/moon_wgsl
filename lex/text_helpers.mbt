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
  let mut out = wgsl_regex_trim_whitespace(text)
  while out.length() > 0 && out.code_unit_at(out.length() - 1).to_int() == 59 { // ';'
    out = wgsl_regex_trim_whitespace(out[:out.length() - 1].to_owned())
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
pub fn split_last_identifier(text : String) -> (String, String)? {
  let mut found = -1
  let mut i = 0
  while i + 1 < text.length() {
    if text.code_unit_at(i).to_int() == 58 &&
      text.code_unit_at(i + 1).to_int() == 58 {
      found = i
    }
    i = i + 1
  }
  if found < 0 {
    return None
  }
  Some((text[:found].to_owned(), text[found + 2:text.length()].to_owned()))
}

///|
pub fn wgsl_token_brace_balance(text : String) -> Int {
  let mut balance = 0
  for token in tokenize(text, false) {
    match token {
      WgslToken::Other(123, _) => balance = balance + 1
      WgslToken::Other(125, _) => balance = balance - 1
      _ => ()
    }
  }
  balance
}
