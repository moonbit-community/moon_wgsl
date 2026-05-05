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
fn naga_oil_raw_import_brace_balance_next(
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
