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
fn finalize_wgsl_writeback_source(
  source : String,
) -> String raise ComposerError {
  let invalid_identifier = invalid_wgsl_struct_member_identifier(source) catch {
    error => raise composer_error_from_wgsl_parse_error(error)
  }
  match invalid_identifier {
    Some(name) => raise ComposerError::InvalidStructMemberIdentifier(name)
    None =>
      sanitize_wgsl_writeback_identifiers(source) catch {
        error => raise composer_error_from_wgsl_parse_error(error)
      }
  }
}
