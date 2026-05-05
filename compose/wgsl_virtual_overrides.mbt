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
fn wgsl_source_contains_override_directive(
  source : String,
) -> Bool raise ComposerError {
  @analysis.wgsl_source_contains_override_directive(source) catch {
    error => raise composer_error_from_wgsl_parse_error(error)
  }
}

///|
fn wgsl_source_contains_virtual_directive(
  source : String,
) -> Bool raise ComposerError {
  @analysis.wgsl_source_contains_virtual_directive(source) catch {
    error => raise composer_error_from_wgsl_parse_error(error)
  }
}

///|
fn apply_wgsl_virtual_overrides(
  source : String,
  alias_redirect_map : @hashmap.HashMap[String, String],
) -> String raise ComposerError {
  @analysis.apply_wgsl_virtual_overrides(source, alias_redirect_map) catch {
    InvalidOverride(name) => raise ComposerError::InvalidOverride(name)
    Parse(message, offset) =>
      raise ComposerError::InvalidWgslSyntax(message, offset)
    UnparsedDeclaration(text, offset) =>
      raise ComposerError::InvalidWgslSyntax(
        "declaration could not be parsed: \{text}",
        offset,
      )
  }
}

///|
fn rewrite_wgsl_override_targets_with_redirects(
  source : String,
  alias_redirect_map : @hashmap.HashMap[String, String],
) -> String raise ComposerError {
  @analysis.rewrite_wgsl_override_targets_with_redirects(
    source, alias_redirect_map,
  ) catch {
    error => raise composer_error_from_wgsl_parse_error(error)
  }
}

///|
fn strip_wgsl_virtual_functions(source : String) -> String raise ComposerError {
  @analysis.strip_wgsl_virtual_functions(source) catch {
    error => raise composer_error_from_wgsl_parse_error(error)
  }
}

///|
