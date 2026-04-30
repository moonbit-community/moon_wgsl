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
fn wgsl_source_contains_override_directive(source : String) -> Bool {
  @virtual_overrides.wgsl_source_contains_override_directive(source)
}

///|
fn wgsl_source_contains_virtual_directive(source : String) -> Bool {
  @virtual_overrides.wgsl_source_contains_virtual_directive(source)
}

///|
fn apply_wgsl_virtual_overrides(
  source : String,
  alias_redirect_map : @hashmap.HashMap[String, String],
) -> String raise ComposerError {
  let output = @virtual_overrides.apply_wgsl_virtual_overrides_raw(
    source, alias_redirect_map,
  )
  match output.invalid_override {
    Some(name) => raise ComposerError::InvalidOverride(name)
    None => output.source
  }
}

///|
fn rewrite_wgsl_override_targets_with_redirects(
  source : String,
  alias_redirect_map : @hashmap.HashMap[String, String],
) -> String {
  @virtual_overrides.rewrite_wgsl_override_targets_with_redirects(
    source, alias_redirect_map,
  )
}

///|
fn strip_wgsl_virtual_functions(source : String) -> String {
  @virtual_overrides.strip_wgsl_virtual_functions(source)
}

///|
