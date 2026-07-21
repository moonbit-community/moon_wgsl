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
fn validation_empty_defines() -> Map[String, Bool] {
  Map([])
}

///|
fn validation_bool_defines(names : Array[String]) -> Map[String, Bool] {
  let defines : Map[String, Bool] = Map([])
  for name in names {
    defines.set(name, true)
  }
  defines
}

///|
fn validation_compose_options(
  defines : Map[String, Bool],
) -> @contract.WgslComposeOptions {
  {
    ..@contract.WgslComposeOptions::default(),
    defines,
    value_defines: @profile.bevy_wgsl_value_defines(),
  }
}

///|
fn validation_bevy_value_defines() -> Map[String, @contract.ShaderDefValue] {
  let value_defines = @profile.bevy_wgsl_value_defines()
  value_defines.remove("PER_OBJECT_BUFFER_BATCH_SIZE")
  value_defines
}

///|
fn validation_bevy_forward_defines() -> Array[String] {
  [
    "VERTEX_POSITIONS", "VERTEX_NORMALS", "VERTEX_UVS", "VERTEX_UVS_A", "VERTEX_COLORS",
    "VERTEX_OUTPUT_INSTANCE_INDEX", "MAY_DISCARD",
  ]
}

///|
fn validation_writer_boundary_source() -> String {
  (
    #|fn prepare_world_normal(world_normal: vec3<f32>) -> vec3<f32> {
    #|  var output: vec3<f32> = world_normal;
    #|  if (output.x >= 1.0) {
    #|    return output;
    #|  }
    #|  return world_normal;
    #|}
    #|
  )
}

///|
fn validation_upstream_compute_source() -> String {
  let composer = @compose.Composer::default()
  composer.clear_sources()
  @wgsl_io.register_source_tree(
    composer,
    "testdata/upstream_compose/compute_test",
    @wgsl_io.WgslSourceScanOptions::default(),
  ) catch {
    _ => abort("expected upstream compute fixture registration success")
  }
  let output = @export.export_wgsl_with_options(
    composer,
    "compute_test.wgsl",
    validation_compose_options(validation_empty_defines()),
    { root_items: ["run_test"] },
  ) catch {
    err => abort("expected upstream compute export success: \{err.message()}")
  }
  output.source
}

///|
fn validation_upstream_diagnostic_filters_source() -> String {
  let composer = @compose.Composer::default()
  composer.clear_sources()
  @wgsl_io.register_source_tree(
    composer,
    "testdata/upstream_compose/diagnostic_filters",
    @wgsl_io.WgslSourceScanOptions::default(),
  ) catch {
    _ => abort("expected diagnostic filters fixture registration success")
  }
  composer.compose_wgsl_runtime_valid(
    "top.wgsl",
    validation_compose_options(validation_empty_defines()),
  ) catch {
    err =>
      abort("expected diagnostic filters compose success: \{err.message()}")
  }
}

///|
fn validation_bevy_issue8_source() -> String {
  let composer = @compose.Composer::default()
  composer.register_source(
    "mesh_view_bindings.wgsl",
    "#define_import_path bevy_pbr::mesh_view_bindings\n" +
    "struct ClusteredLights { value: u32 }\n" +
    "@group(0) @binding(0) var<storage, read> clustered_lights: ClusteredLights;\n",
  )
  composer.register_source(
    "pbr_lighting.wgsl",
    "#define_import_path bevy_pbr::pbr_lighting\n" +
    "#import bevy_pbr::mesh_view_bindings as view_bindings\n" +
    "fn read_clustered_light() -> u32 {\n" +
    "  return view_bindings::clustered_lights.value;\n" +
    "}\n",
  )
  composer.register_source(
    "root.wgsl",
    "#import bevy_pbr::pbr_lighting as lighting\n" +
    "@fragment\n" +
    "fn fragment_main() -> @location(0) u32 {\n" +
    "  return lighting::read_clustered_light();\n" +
    "}\n",
  )
  composer.compose_wgsl_runtime_valid(
    "root.wgsl",
    validation_compose_options(validation_empty_defines()),
  ) catch {
    err => abort("expected issue 8 compose success: \{err.message()}")
  }
}

///|
fn validation_bevy_pbr_functions_source() -> String {
  validation_bevy_source("bevy_pbr/src/render/pbr_functions.wgsl")
}

///|
fn validation_bevy_pbr_forward_source() -> String {
  validation_bevy_source("bevy_pbr/src/render/pbr.wgsl")
}

///|
fn validation_mgstudio_mesh3d_forward_source() -> String {
  validation_bevy_source("mgstudio/render/renderer/mesh3d_bevy_forward.wgsl")
}

///|
fn validation_bevy_source(entry : String) -> String {
  let composer = @compose.Composer::default()
  composer.clear_sources()
  @wgsl_io.register_source_tree(
    composer,
    "testdata/bevy_wgsl",
    @wgsl_io.WgslSourceScanOptions::default(),
  ) catch {
    _ => abort("expected Bevy fixture registration success")
  }
  composer.compose_wgsl_runtime_valid(entry, {
    ..@contract.WgslComposeOptions::default(),
    defines: validation_bool_defines(validation_bevy_forward_defines()),
    value_defines: validation_bevy_value_defines(),
  }) catch {
    err => abort("expected Bevy compose success for \{entry}: \{err.message()}")
  }
}

///|
fn validation_upstream_dual_source_blending_source() -> String {
  let composer = @compose.Composer::default()
  composer.clear_sources()
  @wgsl_io.register_source_tree(
    composer,
    "testdata/upstream_compose/dual_source_blending",
    @wgsl_io.WgslSourceScanOptions::default(),
  ) catch {
    _ => abort("expected upstream dual-source fixture registration success")
  }
  composer.compose_wgsl_runtime_valid(
    "blending.wgsl",
    validation_compose_options(validation_empty_defines()),
  ) catch {
    err =>
      abort("expected upstream dual-source compose success: \{err.message()}")
  }
}

///|
fn validation_issue9_type_identity_source() -> String {
  let composer = @compose.Composer::default()
  composer.register_source(
    "pbr_types.wgsl",
    "#define_import_path bevy_pbr::pbr_types\n" +
    "struct PbrInput { value: u32 }\n" +
    "fn pbr_input_new() -> PbrInput {\n" +
    "  var input: PbrInput;\n" +
    "  input.value = 1u;\n" +
    "  return input;\n" +
    "}\n",
  )
  composer.register_source(
    "pbr_fragment.wgsl",
    "#define_import_path bevy_pbr::pbr_fragment\n" +
    "#import bevy_pbr::pbr_types as pbr_types\n" +
    "fn pbr_input_from_standard_material() -> pbr_types::PbrInput {\n" +
    "  return pbr_types::pbr_input_new();\n" +
    "}\n",
  )
  composer.register_source(
    "clustered.wgsl",
    "#define_import_path bevy_pbr::decal::clustered\n" +
    "#import bevy_pbr::pbr_types::PbrInput\n" +
    "fn apply_decals(pbr_input: ptr<function, PbrInput>) {\n" +
    "  (*pbr_input).value = (*pbr_input).value + 1u;\n" +
    "}\n",
  )
  composer.register_source(
    "pbr.wgsl",
    "#import bevy_pbr::{\n" +
    "  pbr_types,\n" +
    "  pbr_fragment::pbr_input_from_standard_material,\n" +
    "  decal::clustered::apply_decals,\n" +
    "}\n" +
    "@fragment\n" +
    "fn fragment() -> @location(0) u32 {\n" +
    "  var pbr_input = pbr_input_from_standard_material();\n" +
    "  apply_decals(&pbr_input);\n" +
    "  return pbr_input.value;\n" +
    "}\n",
  )
  composer.compose_wgsl_runtime_valid(
    "pbr.wgsl",
    validation_compose_options(validation_empty_defines()),
  ) catch {
    err => abort("expected issue 9 compose success: \{err.message()}")
  }
}

///|
fn validation_issue13_nested_alias_global_source() -> String {
  let composer = @compose.Composer::default()
  composer.clear_sources()
  composer.register_source(
    "bevy_pbr/src/render/mesh_view_bindings.wgsl",
    "#define_import_path bevy_pbr::mesh_view_bindings\n" +
    "struct View { value: f32 }\n" +
    "@group(0) @binding(0) var<uniform> view: View;\n",
  )
  composer.register_source(
    "bevy_pbr/src/render/shadows.wgsl",
    "#define_import_path bevy_pbr::shadows\n" +
    "#import bevy_pbr::mesh_view_bindings as view_bindings\n" +
    "fn shadow_value() -> f32 {\n" +
    "  return view_bindings::view.value;\n" +
    "}\n",
  )
  composer.register_source(
    "bevy_pbr/src/render/pbr_functions.wgsl",
    "#define_import_path bevy_pbr::pbr_functions\n" +
    "#import bevy_pbr::{\n" +
    "  mesh_view_bindings as view_bindings,\n" +
    "  shadows,\n" +
    "}\n" +
    "fn pbr_value() -> f32 {\n" +
    "  return view_bindings::view.value + shadows::shadow_value();\n" +
    "}\n",
  )
  composer.register_source(
    "bevy_pbr/src/render/pbr.wgsl",
    "#define_import_path bevy_pbr::pbr\n" +
    "#import bevy_pbr::pbr_functions::pbr_value\n" +
    "@fragment\n" +
    "fn fragment() -> @location(0) f32 {\n" +
    "  return pbr_value();\n" +
    "}\n",
  )
  composer.compose_wgsl_runtime_valid(
    "bevy_pbr/src/render/pbr.wgsl",
    validation_compose_options(validation_empty_defines()),
  ) catch {
    err => abort("expected issue 13 compose success: \{err.message()}")
  }
}

///|
fn validation_storage_array_length_ir_source() -> String {
  let source =
    #|@group(2) @binding(0) var<storage> values: array<u32>;
    #|@group(2) @binding(1) var<storage, read_write> output: array<u32>;
    #|@compute
    #|fn main(@builtin(global_invocation_id) id: vec3u) {
    #|  if id.x >= arrayLength(&values) {
    #|    return;
    #|  }
    #|  output[id.x] = values[id.x];
    #|}
  @ir.roundtrip_wgsl_source_via_ir(source) catch {
    err =>
      abort(
        "expected storage arrayLength IR roundtrip success: \{err.message()}",
      )
  }
}

///|
fn validation_case_arg() -> String {
  let args = @env.args()
  if args.length() == 0 {
    abort(
      "usage: moon run tools/wgsl_validation_cases -- writer-boundary|upstream-compute|upstream-diagnostic-filters|bevy-issue8|bevy-pbr-functions|bevy-pbr-forward|mgstudio-mesh3d-forward|upstream-dual-source-blending|issue9-type-identity|issue13-nested-alias-global|storage-array-length-ir",
    )
  }
  args[args.length() - 1]
}

///|
fn main {
  let source = match validation_case_arg() {
    "writer-boundary" => validation_writer_boundary_source()
    "upstream-compute" => validation_upstream_compute_source()
    "upstream-diagnostic-filters" =>
      validation_upstream_diagnostic_filters_source()
    "bevy-issue8" => validation_bevy_issue8_source()
    "bevy-pbr-functions" => validation_bevy_pbr_functions_source()
    "bevy-pbr-forward" => validation_bevy_pbr_forward_source()
    "mgstudio-mesh3d-forward" => validation_mgstudio_mesh3d_forward_source()
    "upstream-dual-source-blending" =>
      validation_upstream_dual_source_blending_source()
    "issue9-type-identity" => validation_issue9_type_identity_source()
    "issue13-nested-alias-global" =>
      validation_issue13_nested_alias_global_source()
    "storage-array-length-ir" => validation_storage_array_length_ir_source()
    _ =>
      abort(
        "usage: moon run tools/wgsl_validation_cases -- writer-boundary|upstream-compute|upstream-diagnostic-filters|bevy-issue8|bevy-pbr-functions|bevy-pbr-forward|mgstudio-mesh3d-forward|upstream-dual-source-blending|issue9-type-identity|issue13-nested-alias-global|storage-array-length-ir",
      )
  }
  println(source)
}
