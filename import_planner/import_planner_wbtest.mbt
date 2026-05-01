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
    wgsl_source_contains_reference_path(source, "Item") catch {
      _ => abort("strict parser should accept valid source")
    },
    content="false",
  )
  debug_inspect(
    wgsl_source_contains_reference_path(source, "other::Item") catch {
      _ => abort("strict parser should accept valid source")
    },
    content="true",
  )
}

///|
test "strict reference path matcher is AST driven" {
  let source =
    #|fn entry(input: Input) -> f32 {
    #|  return lighting::spot_light(input.value).x + input.member;
    #|}
    #|
  debug_inspect(
    wgsl_source_contains_reference_path_strict(source, "lighting::spot_light") catch {
      _ => abort("strict parser should accept valid source")
    },
    content="true",
  )
  debug_inspect(
    wgsl_source_contains_reference_path_strict(source, "member") catch {
      _ => abort("strict parser should accept valid source")
    },
    content="false",
  )
}

///|
test "strict reference path matcher rejects malformed WGSL" {
  let source =
    #|fn entry( {
    #|  return lighting::spot_light();
    #|}
    #|
  let mut rejected = false
  ignore(
    wgsl_source_contains_reference_path_strict(source, "lighting::spot_light"),
  ) catch {
    _ => rejected = true
  }
  debug_inspect(rejected, content="true")
}
