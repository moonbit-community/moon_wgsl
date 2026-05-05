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
fn validation_empty_defines() -> @hashmap.HashMap[String, Bool] {
  @hashmap.HashMap::new()
}

///|
fn validation_bool_defines(
  names : Array[String],
) -> @hashmap.HashMap[String, Bool] {
  let defines : @hashmap.HashMap[String, Bool] = @hashmap.HashMap::new()
  for name in names {
    defines.set(name, true)
  }
  defines
}

///|
fn validation_compose_options(
  defines : @hashmap.HashMap[String, Bool],
) -> @common.WgslComposeOptions {
  {
    defines,
    value_defines: @common.default_wgsl_value_defines(),
    redirects: [],
    additional_imports: [],
  }
}

///|
fn validation_bevy_value_defines() -> @hashmap.HashMap[String, Int] {
  let value_defines = @common.default_wgsl_value_defines()
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
  @analysis.emit_wgsl_text_with_token_rewrites(
    (
      #|fn prepare_world_normal(world_normal: vec3<f32>) -> vec3<f32> {
      #|  var output: vec3<f32> = world_normal;
      #|  if (output.x >= 1.0) {
      #|    return output;
      #|  }
      #|  return world_normal;
      #|}
      #|
    ),
    [],
    0,
  )
}

///|
fn validation_upstream_compute_source() -> String {
  let composer = @compose.Composer::default()
  composer.clear_sources()
  composer.register_source_tree(
    "testdata/upstream_compose/compute_test",
    @common.WgslSourceScanOptions::default(),
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
  composer.compose_wgsl(
    "root.wgsl",
    validation_compose_options(validation_empty_defines()),
  ) catch {
    err => abort("expected issue 8 compose success: \{err.message()}")
  }
}

///|
fn validation_bevy_pbr_functions_source() -> String {
  let composer = @compose.Composer::default()
  composer.clear_sources()
  composer.register_source_tree(
    "testdata/bevy_wgsl",
    @common.WgslSourceScanOptions::default(),
  ) catch {
    _ => abort("expected Bevy fixture registration success")
  }
  composer.compose_wgsl("bevy_pbr/src/render/pbr_functions.wgsl", {
    defines: validation_bool_defines(validation_bevy_forward_defines()),
    value_defines: validation_bevy_value_defines(),
    redirects: [],
    additional_imports: [],
  }) catch {
    err =>
      abort("expected Bevy PBR functions compose success: \{err.message()}")
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
  composer.compose_wgsl(
    "pbr.wgsl",
    validation_compose_options(validation_empty_defines()),
  ) catch {
    err => abort("expected issue 9 compose success: \{err.message()}")
  }
}

///|
fn validation_case_arg() -> String {
  let args = @env.args()
  if args.length() == 0 {
    abort(
      "usage: moon run tools/wgsl_validation_cases -- writer-boundary|upstream-compute|bevy-issue8|bevy-pbr-functions|issue9-type-identity",
    )
  }
  args[args.length() - 1]
}

///|
fn main {
  let source = match validation_case_arg() {
    "writer-boundary" => validation_writer_boundary_source()
    "upstream-compute" => validation_upstream_compute_source()
    "bevy-issue8" => validation_bevy_issue8_source()
    "bevy-pbr-functions" => validation_bevy_pbr_functions_source()
    "issue9-type-identity" => validation_issue9_type_identity_source()
    _ =>
      abort(
        "usage: moon run tools/wgsl_validation_cases -- writer-boundary|upstream-compute|bevy-issue8|bevy-pbr-functions|issue9-type-identity",
      )
  }
  println(source)
}
