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
fn apply_wgsl_virtual_overrides_with_binding_plan(
  source : String,
  plan : WgslReferenceRewritePlan,
) -> String raise ComposerError {
  @transform.apply_wgsl_virtual_overrides_with_binding_plan(source, plan) catch {
    InvalidOverride(name) => raise InvalidOverride(name)
    UnparsedDeclaration(text, offset) =>
      raise InvalidWgslSyntax(
        "declaration could not be parsed: \{text}",
        offset,
      )
  }
}

///|
fn rewrite_wgsl_override_targets_with_binding_plan(
  source : String,
  plan : WgslReferenceRewritePlan,
) -> String raise ComposerError {
  @transform.rewrite_wgsl_override_targets_with_binding_plan(source, plan) catch {
    error => raise composer_error_from_wgsl_parse_error(error)
  }
}

///|
fn strip_wgsl_virtual_functions(source : String) -> String raise ComposerError {
  @transform.strip_wgsl_virtual_functions(source) catch {
    error => raise composer_error_from_wgsl_parse_error(error)
  }
}

///|
