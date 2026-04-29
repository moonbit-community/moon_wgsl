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
fn bevy_parity_compose_with_entrypoint_mode(
  rel_path : String,
  defines : Array[String],
  preserve_imported_entry_points : Bool,
) -> String {
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
    preserve_imported_entry_points,
  }) catch {
    err =>
      abort("expected complete Bevy WGSL compose success: \{err.message()}")
  }
}

///|
fn bevy_parity_compose(rel_path : String, defines : Array[String]) -> String {
  bevy_parity_compose_with_entrypoint_mode(rel_path, defines, true)
}

///|
fn bevy_parity_forward_defines() -> Array[String] {
  [
    "VERTEX_POSITIONS", "VERTEX_NORMALS", "VERTEX_UVS", "VERTEX_UVS_A", "VERTEX_COLORS",
    "VERTEX_OUTPUT_INSTANCE_INDEX", "MAY_DISCARD",
  ]
}

///|
fn bevy_parity_has_bare_mesh_access(source : String) -> Bool {
  source.contains("= mesh[in_wgsl.instance_index]") ||
  source.contains("= mesh[in.instance_index]") ||
  source.contains(" mesh[in_wgsl.instance_index]") ||
  source.contains(" mesh[in.instance_index]")
}

///|
test "complete Bevy forward mesh3d shader rewrites shared mesh binding" {
  let source = bevy_parity_compose(
    "mgstudio/render/renderer/mesh3d_bevy_forward.wgsl",
    bevy_parity_forward_defines(),
  )
  debug_inspect(
    source.contains("@group(2) @binding(0) var<storage> mesh_functions__mesh"),
    content="true",
  )
  debug_inspect(
    source.contains(
      "pbr_input.flags = mesh_functions__mesh[in_wgsl.instance_index].flags",
    ),
    content="true",
  )
  debug_inspect(bevy_parity_has_bare_mesh_access(source), content="false")
}

///|
test "complete Bevy prepass mesh3d shader rewrites shared mesh binding" {
  let source = bevy_parity_compose(
    "mgstudio/render/renderer/mesh3d_bevy_prepass.wgsl",
    bevy_parity_forward_defines() +
    ["PREPASS_FRAGMENT", "NORMAL_PREPASS", "BINDLESS"],
  )
  debug_inspect(
    source.contains("@group(2) @binding(0) var<storage> mesh_functions__mesh"),
    content="true",
  )
  debug_inspect(
    source.contains(
      "let slot = mesh_functions__mesh[in_wgsl.instance_index].material_and_lightmap_bind_group_slot & 0xffffu",
    ),
    content="true",
  )
  debug_inspect(bevy_parity_has_bare_mesh_access(source), content="false")
}

///|
test "complete Bevy mesh vertex shader keeps non-empty vertex output" {
  let source = bevy_parity_compose(
    "mgstudio/render/renderer/mesh3d_bevy_mesh_only.wgsl",
    bevy_parity_forward_defines(),
  )
  debug_inspect(source.contains("@vertex\nfn vertex("), content="true")
  debug_inspect(source.contains("var out: VertexOutput;"), content="true")
  debug_inspect(
    source.contains(
      "out.position = position_world_to_clip(out.world_position.xyz);",
    ),
    content="true",
  )
}

///|
test "strict naga_oil mode does not retain import-only Bevy entrypoints" {
  let source = bevy_parity_compose_with_entrypoint_mode(
    "mgstudio/render/renderer/mesh3d_bevy_forward.wgsl",
    bevy_parity_forward_defines(),
    false,
  )
  debug_inspect(source.trim().length(), content="0")
}
