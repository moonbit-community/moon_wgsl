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
  let value_defines = @common.default_wgsl_value_defines()
  value_defines.remove("PER_OBJECT_BUFFER_BATCH_SIZE")
  value_defines
}

///|
fn bevy_parity_compose(rel_path : String, defines : Array[String]) -> String {
  let composer = @compose.Composer::default()
  composer.clear_sources()
  composer.register_source_tree(
    "testdata/bevy_wgsl",
    @common.WgslSourceScanOptions::default(),
  ) catch {
    _ => abort("expected Bevy fixture registration success")
  }
  composer.compose_wgsl(rel_path, {
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

///|
test "naga_oil parity: Bevy lighting keeps tree-shaken alias const targets live" {
  let composer = @compose.Composer::default()
  composer.clear_sources()
  composer.register_source_tree(
    "testdata/bevy_wgsl",
    @common.WgslSourceScanOptions::default(),
  ) catch {
    _ => abort("expected Bevy fixture registration success")
  }
  composer.register_source(
    "mgstudio/render/renderer/issue8_lighting_repro.wgsl",
    (
      #|#import bevy_pbr::lighting as lighting
      #|fn entry() -> vec3<f32> {
      #|  var input: lighting::LightingInput;
      #|  return lighting::spot_light(0u, &input, true);
      #|}
      #|
    ),
  )
  let source = composer.compose_wgsl(
    "mgstudio/render/renderer/issue8_lighting_repro.wgsl",
    {
      defines: bevy_parity_defines(bevy_parity_forward_defines()),
      value_defines: bevy_parity_value_defines(),
      redirects: [],
      additional_imports: [],
    },
  ) catch {
    err => abort("expected issue 8 lighting compose success: \{err.message()}")
  }
  debug_inspect(
    source.contains("& types__POINT_LIGHT_FLAGS_SPOT_LIGHT_Y_NEGATIVE"),
    content="false",
  )
  debug_inspect(
    source.contains("const lighting__POINT_LIGHT_FLAGS_SPOT_LIGHT_Y_NEGATIVE"),
    content="true",
  )
  debug_inspect(
    source.contains("& lighting__POINT_LIGHT_FLAGS_SPOT_LIGHT_Y_NEGATIVE"),
    content="true",
  )
  debug_inspect(
    source.contains("view_bindings::clustered_lights"),
    content="false",
  )
  debug_inspect(
    source.contains("lighting__view_bindings__clustered_lights"),
    content="true",
  )
}

///|
test "naga_oil parity: prepared Bevy catalog resolves alias-qualified bindings" {
  let composer = @compose.Composer::default()
  composer.clear_sources()
  composer.register_source_tree(
    "testdata/bevy_wgsl",
    @common.WgslSourceScanOptions::default(),
  ) catch {
    _ => abort("expected Bevy fixture registration success")
  }
  composer.register_source(
    "mgstudio/render/renderer/issue8_lighting_repro.wgsl",
    (
      #|#import bevy_pbr::lighting as lighting
      #|fn entry() -> vec3<f32> {
      #|  var input: lighting::LightingInput;
      #|  return lighting::spot_light(0u, &input, true);
      #|}
      #|
    ),
  )
  let prepared = composer.prepare_wgsl_source(
    "mgstudio/render/renderer/issue8_lighting_repro.wgsl",
    {
      defines: bevy_parity_defines(bevy_parity_forward_defines()),
      value_defines: bevy_parity_value_defines(),
      redirects: [],
      additional_imports: [],
    },
  ) catch {
    err => abort("expected Bevy prepared source success: \{err.message()}")
  }
  let mut unresolved_entries = 0
  let mut resolved_entries = 0
  let mut unresolved_source_files = 0
  for entry in prepared.source_catalog {
    if entry.source_text.contains("view_bindings::clustered_lights") {
      unresolved_entries = unresolved_entries + 1
    }
    if entry.source_text.contains("view_bindings__clustered_lights") {
      resolved_entries = resolved_entries + 1
    }
  }
  for source_file in prepared.source_files {
    if source_file.source.contains("view_bindings::clustered_lights") {
      unresolved_source_files = unresolved_source_files + 1
    }
  }
  debug_inspect(prepared.source_files.length(), content="1")
  debug_inspect(unresolved_source_files, content="0")
  debug_inspect(unresolved_entries, content="0")
  debug_inspect(resolved_entries > 0, content="true")
}
