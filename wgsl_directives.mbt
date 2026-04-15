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
fn join_strings(items : Array[String], sep : String) -> String {
  let mut out = ""
  for i in 0..<items.length() {
    if i > 0 {
      out = out + sep
    }
    out = out + items[i]
  }
  out
}

///|
pub fn WgslDirectives::to_wgsl_string(self : WgslDirectives) -> String {
  let mut result = ""

  let all_enables : @hashset.HashSet[String] = @hashset.HashSet::new()
  for enable in self.enables {
    for extension in enable.extensions {
      all_enables.add(extension)
    }
  }
  if !all_enables.is_empty() {
    let enables = all_enables.to_array()
    enables.sort()
    let joined_enables = join_strings(enables, ", ")
    result = "\{result}enable \{joined_enables};\n"
  }

  let all_requires : @hashset.HashSet[String] = @hashset.HashSet::new()
  for requires in self.requires {
    for extension in requires.extensions {
      all_requires.add(extension)
    }
  }
  if !all_requires.is_empty() {
    let requires = all_requires.to_array()
    requires.sort()
    let joined_requires = join_strings(requires, ", ")
    result = "\{result}requires \{joined_requires};\n"
  }

  for diagnostic in self.diagnostics {
    result = "\{result}diagnostic(\{diagnostic.severity}, \{diagnostic.rule});\n"
  }

  if result != "" {
    result = "\{result}\n"
  }
  result
}
