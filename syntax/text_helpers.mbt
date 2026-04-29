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
pub fn starts_with_text(text : String, prefix : String) -> Bool {
  text.has_prefix(prefix)
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
