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
fn wgsl_metadata_first_space_separated_token(text : String) -> String {
  let trimmed = wgsl_regex_trim_whitespace(text)
  let mut end = 0
  while end < trimmed.length() {
    let width = wgsl_regex_whitespace_width(trimmed, end)
    guard width == 0 else { break }
    end = end + 1
  }
  trimmed[0:end].to_owned()
}

///|
pub fn wgsl_source_define_import_path(source : String) -> String? {
  for
    item in parse_wgsl_directive_scan_items(source, include_glsl_version=false) {
    match item.kind() {
      Directive(directive) =>
        if directive.kind() == DefineImportPath {
          let raw_name = directive.tail()
          let import_path = wgsl_metadata_first_space_separated_token(raw_name)
          if import_path != "" {
            return Some(import_path)
          }
        }
      _ => ()
    }
  }
  None
}

///|
