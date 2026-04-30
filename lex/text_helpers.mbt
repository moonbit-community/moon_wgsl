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
fn utf8_byte_width(code_point : Int) -> Int {
  if code_point <= 0x7F {
    1
  } else if code_point <= 0x7FF {
    2
  } else if code_point <= 0xFFFF {
    3
  } else {
    4
  }
}

///|
pub fn utf8_byte_length(text : String) -> Int {
  let mut length = 0
  let mut index = 0
  while index < text.length() {
    match wgsl_code_point_at(text, index) {
      Some((code_point, width)) => {
        length = length + utf8_byte_width(code_point)
        index = index + width
      }
      None => {
        length = length + 3
        index = index + 1
      }
    }
  }
  length
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

///|
pub fn naga_oil_raw_import_brace_balance_next(
  open_count : Int,
  line : String,
) -> Int {
  let mut next = open_count
  for i in 0..<line.length() {
    let code = line.code_unit_at(i).to_int()
    if code == 123 {
      next = next + 1
    } else if code == 125 {
      if next > 0 {
        next = next - 1
      }
    }
  }
  next
}
