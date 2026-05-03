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
test "semantic alias graph resolves global binding member access" {
  let source =
    #|fn read() -> u32 {
    #|  return view_bindings::clustered_lights.data[0u].value;
    #|}
    #|
  let requested_paths : Array[String] = []
  collect_wgsl_semantic_alias_requested_paths(
    source, "view_bindings", requested_paths,
  ) catch {
    _ => abort("expected semantic alias collection to parse valid WGSL")
  }
  debug_inspect(requested_paths.join(","), content="\"clustered_lights\"")
}

///|
test "semantic alias graph resolves nested module alias paths" {
  let source =
    #|fn read() -> u32 {
    #|  return pbr::bindings::view.value;
    #|}
    #|
  let requested_paths : Array[String] = []
  collect_wgsl_semantic_alias_requested_paths(source, "pbr", requested_paths) catch {
    _ => abort("expected semantic alias collection to parse valid WGSL")
  }
  debug_inspect(requested_paths.join(","), content="\"bindings::view\"")
}

///|
test "semantic reference matcher distinguishes qualified suffixes" {
  let source =
    #|fn entry() -> u32 {
    #|  return other::Item();
    #|}
    #|
  debug_inspect(
    wgsl_semantic_source_contains_reference_path(source, "Item") catch {
      _ => abort("expected semantic matcher to parse valid WGSL")
    },
    content="false",
  )
  debug_inspect(
    wgsl_semantic_source_contains_reference_path(source, "other::Item") catch {
      _ => abort("expected semantic matcher to parse valid WGSL")
    },
    content="true",
  )
}

///|
test "semantic reference matcher ignores struct member names" {
  let source =
    #|fn entry(input: Input) -> f32 {
    #|  return lighting::spot_light(input.value).x + input.member;
    #|}
    #|
  debug_inspect(
    wgsl_semantic_source_contains_reference_path(source, "lighting::spot_light") catch {
      _ => abort("expected semantic matcher to parse valid WGSL")
    },
    content="true",
  )
  debug_inspect(
    wgsl_semantic_source_contains_reference_path(source, "member") catch {
      _ => abort("expected semantic matcher to parse valid WGSL")
    },
    content="false",
  )
}
