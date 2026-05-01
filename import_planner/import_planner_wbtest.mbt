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
test "reference path matcher distinguishes qualified suffixes" {
  let source =
    #|fn entry() -> u32 {
    #|  return other::Item();
    #|}
    #|
  debug_inspect(
    wgsl_source_contains_reference_path(source, "Item"),
    content="false",
  )
  debug_inspect(
    wgsl_source_contains_reference_path(source, "other::Item"),
    content="true",
  )
}
