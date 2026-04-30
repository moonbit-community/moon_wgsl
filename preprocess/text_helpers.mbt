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
fn preprocess_identifier_code_unit(code : Int) -> Bool {
  (code >= 65 && code <= 90) ||
  (code >= 97 && code <= 122) ||
  (code >= 48 && code <= 57) ||
  code == 95
}

///|
fn code_unit_to_string(code : Int) -> String {
  String::from_array([Int::unsafe_to_char(code)])
}

///|
fn preprocess_skip_ascii_space(text : String, start : Int) -> Int {
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
fn word_tail(text : String, word : String) -> String? {
  let trimmed = text.trim().to_owned()
  let start = preprocess_skip_ascii_space(trimmed, 0)
  guard start + word.length() <= trimmed.length() else { return None }
  guard trimmed[start:start + word.length()].to_owned() == word else {
    return None
  }
  let end = start + word.length()
  if end < trimmed.length() &&
    preprocess_identifier_code_unit(trimmed.code_unit_at(end).to_int()) {
    return None
  }
  Some(trimmed[end:trimmed.length()].to_owned().trim().to_owned())
}
