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
fn preprocess_regex_whitespace_code_unit(code : Int) -> Bool {
  code == 9 ||
  code == 10 ||
  code == 11 ||
  code == 12 ||
  code == 13 ||
  code == 32
}

///|
fn code_unit_to_string(code : Int) -> String {
  String::from_array([Int::unsafe_to_char(code)])
}

///|
fn preprocess_skip_regex_whitespace(text : String, start : Int) -> Int {
  let mut i = start
  while i < text.length() {
    let code = text.code_unit_at(i).to_int()
    if preprocess_regex_whitespace_code_unit(code) {
      i = i + 1
      continue
    }
    break
  }
  i
}

///|
fn preprocess_trim_regex_whitespace(text : String) -> String {
  let start = preprocess_skip_regex_whitespace(text, 0)
  let mut end = text.length()
  while end > start {
    let code = text.code_unit_at(end - 1).to_int()
    if preprocess_regex_whitespace_code_unit(code) {
      end = end - 1
      continue
    }
    break
  }
  text[start:end].to_owned()
}
