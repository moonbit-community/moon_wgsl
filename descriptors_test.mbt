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
test "naga_oil: composable descriptor defaults to empty source" {
  let composable = @common.ComposableModuleDescriptor::default()
  debug_inspect(composable.source, content="\"\"")
  debug_inspect(composable.file_path, content="\"\"")
  debug_inspect(composable.as_name, content="None")
  debug_inspect(composable.additional_imports.length(), content="0")
  debug_inspect(composable.shader_defs.length(), content="0")
}

///|
test "naga_oil: composable definition exposes only semantic registration state" {
  let definition = @common.ComposableModuleDefinition::new(
    "demo",
    @hashmap.HashMap::new(),
    ["HDR"],
    @hashset.HashSet::new(),
  )
  debug_inspect(definition.name, content="\"demo\"")
  debug_inspect(definition.shader_defs.length(), content="0")
  debug_inspect(definition.effective_defs, content="[\"HDR\"]")
  debug_inspect(definition.all_imports.length(), content="0")
}
