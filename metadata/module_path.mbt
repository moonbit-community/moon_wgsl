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
fn wgsl_metadata_code_unit_to_string(code : Int) -> String {
  String::from_array([Int::unsafe_to_char(code)])
}

///|
fn wgsl_metadata_token_text(token : WgslToken) -> String {
  match token {
    WgslToken::Identifier(text, _) => text
    WgslToken::Whitespace(text, _) => text
    WgslToken::Other(code, _) => wgsl_metadata_code_unit_to_string(code)
  }
}

///|
fn wgsl_metadata_first_space_separated_token(text : String) -> String {
  let trimmed = text.trim().to_owned()
  let tokens = tokenize(trimmed, true)
  let mut output = ""
  for token in tokens {
    match token {
      WgslToken::Whitespace(_, _) => break
      _ => output = output + wgsl_metadata_token_text(token)
    }
  }
  output
}

///|
pub fn wgsl_source_define_import_path(source : String) -> String? {
  let stripped = replace_comments(source)
  for line in source_lines(stripped) {
    let trimmed = line.trim().to_owned()
    match wgsl_directive_tail(trimmed, WgslDirectiveKind::DefineImportPath) {
      Some(raw_name) => {
        let import_path = trim_trailing_semicolons(
          wgsl_metadata_first_space_separated_token(raw_name),
        )
        if import_path != "" {
          return Some(import_path)
        }
      }
      None => ()
    }
  }
  None
}

///|
