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
fn bevy_parity_defines(names : Array[String]) -> @hashmap.HashMap[String, Bool] {
  let defines : @hashmap.HashMap[String, Bool] = @hashmap.HashMap::new()
  for name in names {
    defines.set(name, true)
  }
  defines
}

///|
fn bevy_parity_value_defines() -> @hashmap.HashMap[String, Int] {
  let value_defines = @moon_wgsl.default_wgsl_value_defines()
  value_defines.remove("PER_OBJECT_BUFFER_BATCH_SIZE")
  value_defines
}

///|
fn bevy_parity_compose(rel_path : String, defines : Array[String]) -> String {
  @moon_wgsl.clear_registered_wgsl_source_registry()
  let composer = @moon_wgsl.Composer::default()
  composer.clear_registered_wgsl_source_registry()
  composer.register_wgsl_source_tree(
    "testdata/bevy_wgsl",
    @moon_wgsl.WgslSourceScanOptions::default(),
  ) catch {
    _ => abort("expected Bevy fixture registration success")
  }
  composer.compose_wgsl(rel_path, {
    assets_base: "",
    defines: bevy_parity_defines(defines),
    value_defines: bevy_parity_value_defines(),
    redirects: [],
    additional_imports: [],
  }) catch {
    err =>
      abort("expected complete Bevy WGSL compose success: \{err.message()}")
  }
}

///|
fn bevy_parity_forward_defines() -> Array[String] {
  [
    "VERTEX_POSITIONS", "VERTEX_NORMALS", "VERTEX_UVS", "VERTEX_UVS_A", "VERTEX_COLORS",
    "VERTEX_OUTPUT_INSTANCE_INDEX", "MAY_DISCARD",
  ]
}

///|
test "naga_oil parity: import-only Bevy forward root tree-shakes to empty" {
  let source = bevy_parity_compose(
    "mgstudio/render/renderer/mesh3d_bevy_forward.wgsl",
    bevy_parity_forward_defines(),
  )
  debug_inspect(source.trim().length(), content="0")
}

///|
test "naga_oil parity: import-only Bevy prepass root tree-shakes to empty" {
  let source = bevy_parity_compose(
    "mgstudio/render/renderer/mesh3d_bevy_prepass.wgsl",
    bevy_parity_forward_defines() +
    ["PREPASS_FRAGMENT", "NORMAL_PREPASS", "BINDLESS"],
  )
  debug_inspect(source.trim().length(), content="0")
}

///|
test "naga_oil parity: import-only Bevy mesh root tree-shakes to empty" {
  let source = bevy_parity_compose(
    "mgstudio/render/renderer/mesh3d_bevy_mesh_only.wgsl",
    bevy_parity_forward_defines(),
  )
  debug_inspect(source.trim().length(), content="0")
}
