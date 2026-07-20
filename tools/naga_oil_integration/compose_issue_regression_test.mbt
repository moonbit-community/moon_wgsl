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
test "github issue 2: Bevy pbr_types alias const references are all rewritten" {
  let composer = @compose.Composer::default()
  let pbr_types_source = "#define_import_path bevy_pbr::pbr_types\n" +
    "struct StandardMaterial {\n" +
    "  flags: u32,\n" +
    "}\n" +
    "struct PbrInput {\n" +
    "  material: StandardMaterial,\n" +
    "}\n" +
    "const STANDARD_MATERIAL_FLAGS_ALPHA_MODE_RESERVED_BITS: u32          = 7u << 29u; // (0b111u << 29u)\n" +
    "const STANDARD_MATERIAL_FLAGS_ALPHA_MODE_OPAQUE: u32                 = 0u << 29u;\n" +
    "const STANDARD_MATERIAL_FLAGS_ALPHA_MODE_MASK: u32                   = 1u << 29u;\n" +
    "const STANDARD_MATERIAL_FLAGS_ALPHA_MODE_ALPHA_TO_COVERAGE: u32      = 6u << 29u;\n"
  composer.register_source("pbr_types.wgsl", pbr_types_source)
  let pbr_functions_source = "#define_import_path bevy_pbr::pbr_functions\n" +
    "#import bevy_pbr::pbr_types as pbr_types\n" +
    "fn alpha_discard(material: pbr_types::StandardMaterial, output_color: vec4<f32>) -> vec4<f32> {\n" +
    "  var color = output_color;\n" +
    "  let alpha_mode = material.flags & pbr_types::STANDARD_MATERIAL_FLAGS_ALPHA_MODE_RESERVED_BITS;\n" +
    "  if alpha_mode == pbr_types::STANDARD_MATERIAL_FLAGS_ALPHA_MODE_OPAQUE {\n" +
    "    color.a = 1.0;\n" +
    "  }\n" +
    "#ifdef MAY_DISCARD\n" +
    "  else if alpha_mode == pbr_types::STANDARD_MATERIAL_FLAGS_ALPHA_MODE_MASK ||\n" +
    "      alpha_mode == pbr_types::STANDARD_MATERIAL_FLAGS_ALPHA_MODE_ALPHA_TO_COVERAGE {\n" +
    "    color.a = 0.5;\n" +
    "  }\n" +
    "#endif\n" +
    "  return color;\n" +
    "}\n" +
    "fn fragment(material: pbr_types::StandardMaterial) -> vec4<f32> {\n" +
    "  return alpha_discard(material, vec4<f32>(0.0));\n" +
    "}\n"
  composer.register_source("pbr_functions.wgsl", pbr_functions_source)
  let pbr_fragment_source = "#define_import_path bevy_pbr::pbr_fragment\n" +
    "#import bevy_pbr::{ pbr_functions, pbr_types }\n" +
    "fn fragment() -> vec4<f32> {\n" +
    "  var input: pbr_types::PbrInput;\n" +
    "  return pbr_functions::alpha_discard(input.material, vec4<f32>(0.0));\n" +
    "}\n"
  composer.register_source("pbr_fragment.wgsl", pbr_fragment_source)
  let root_source = "#import bevy_pbr::pbr_fragment as pbr\n" +
    "fn fragment() -> vec4<f32> {\n" +
    "  return pbr::fragment();\n" +
    "}\n"
  composer.register_source("root.wgsl", root_source)
  let source = composer.compose_wgsl(
    "root.wgsl",
    compose_regression_options(compose_regression_bool_defines(["MAY_DISCARD"])),
  ) catch {
    err => abort("expected issue 2 repro compose success: \{err.message()}")
  }
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(
    source.contains("pbr_types::STANDARD_MATERIAL_FLAGS_ALPHA_MODE_OPAQUE"),
    content="false",
  )
}

///|
test "github issue 5: colliding lowered declarations from separate imports are deduped" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "pbr_types_a.wgsl",
    "#define_import_path bevy_pbr::pbr_types_a\n" +
    "struct StandardMaterial {\n" +
    "  flags: u32,\n" +
    "}\n",
  )
  composer.register_source(
    "pbr_types_b.wgsl",
    "#define_import_path bevy_pbr::pbr_types_b\n" +
    "struct StandardMaterial {\n" +
    "  flags: u32,\n" +
    "}\n",
  )
  composer.register_source(
    "entry.wgsl",
    "#import bevy_pbr::pbr_types_a as pbr_types\n" +
    "#import bevy_pbr::pbr_types_b as pbr_types\n" +
    "fn fragment(material: pbr_types::StandardMaterial) -> u32 {\n" +
    "  return material.flags;\n" +
    "}\n",
  )
  ignore(
    composer.compose_wgsl(
      "entry.wgsl",
      compose_regression_options(compose_regression_empty_defines()),
    ),
  ) catch {
    err => {
      debug_inspect(
        err.message().contains("ambiguous shader import binding"),
        content="true",
      )
      debug_inspect(
        err.message().contains("pbr_types::StandardMaterial"),
        content="true",
      )
      return
    }
  }
  abort("expected colliding same-alias imports to report ambiguity")
}

///|
test "github issue 6: Bevy F0_ struct member composes without identifier-policy rejection" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "f0_member.wgsl",
    "struct LightingInput {\n" + "  F0_: vec3<f32>,\n" + "}\n",
  )
  let source = composer.compose_wgsl(
    "f0_member.wgsl",
    compose_regression_options(compose_regression_empty_defines()),
  ) catch {
    err => abort("expected F0_ member compose success: \{err.message()}")
  }
  debug_inspect(source.contains("F0_: vec3<f32>"), content="true")
}

///|
test "naga_oil regression: item-imported functions do not force imported mesh bindings" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "mesh_types.wgsl",
    "#define_import_path bevy_pbr::mesh_types\n" +
    "struct Mesh {\n" +
    "  flags: u32,\n" +
    "}\n",
  )
  composer.register_source(
    "mesh_bindings.wgsl",
    "#define_import_path bevy_pbr::mesh_bindings\n" +
    "#import bevy_pbr::mesh_types::Mesh\n" +
    "#ifndef MESHLET_MESH_MATERIAL_PASS\n" +
    "@group(2) @binding(0) var<storage> mesh: array<Mesh>;\n" +
    "#endif\n",
  )
  composer.register_source(
    "mesh_functions.wgsl",
    "#define_import_path bevy_pbr::mesh_functions\n" +
    "#import bevy_pbr::mesh_bindings as mesh_bindings\n" +
    "fn mesh_flags(instance_index: u32) -> u32 {\n" +
    "  return mesh_bindings::mesh[instance_index].flags;\n" +
    "}\n",
  )
  composer.register_source(
    "pbr_types.wgsl",
    "#define_import_path bevy_pbr::pbr_types\n" +
    "struct PbrInput {\n" +
    "  flags: u32,\n" +
    "}\n",
  )
  composer.register_source(
    "forward_io.wgsl",
    "#define_import_path bevy_pbr::forward_io\n" +
    "struct VertexOutput {\n" +
    "  instance_index: u32,\n" +
    "}\n",
  )
  composer.register_source(
    "pbr_fragment.wgsl",
    "#define_import_path bevy_pbr::pbr_fragment\n" +
    "#import bevy_pbr::{\n" +
    "  mesh_bindings::mesh,\n" +
    "  pbr_types,\n" +
    "  forward_io::VertexOutput,\n" +
    "}\n" +
    "fn pbr_input_from_standard_material(in: VertexOutput) -> pbr_types::PbrInput {\n" +
    "  var pbr_input: pbr_types::PbrInput;\n" +
    "  pbr_input.flags = mesh[in.instance_index].flags;\n" +
    "  return pbr_input;\n" +
    "}\n",
  )
  composer.register_source(
    "pbr.wgsl",
    "#define_import_path bevy_pbr::pbr\n" +
    "#import bevy_pbr::{\n" +
    "  pbr_fragment::pbr_input_from_standard_material,\n" +
    "  forward_io::VertexOutput,\n" +
    "}\n" +
    "@fragment\n" +
    "fn fragment(vertex_output: VertexOutput) -> @location(0) vec4<f32> {\n" +
    "  let pbr_input = pbr_input_from_standard_material(vertex_output);\n" +
    "  return vec4<f32>(f32(pbr_input.flags));\n" +
    "}\n",
  )
  composer.register_source(
    "mesh.wgsl",
    "#define_import_path bevy_pbr::mesh\n" +
    "#import bevy_pbr::{\n" +
    "  mesh_functions,\n" +
    "  forward_io::VertexOutput,\n" +
    "}\n" +
    "@vertex\n" +
    "fn vertex() -> VertexOutput {\n" +
    "  var out: VertexOutput;\n" +
    "  out.instance_index = mesh_functions::mesh_flags(0u);\n" +
    "  return out;\n" +
    "}\n" +
    "@fragment\n" +
    "fn debug_fragment(mesh: VertexOutput) -> @location(0) vec4<f32> {\n" +
    "  return vec4<f32>(f32(mesh.instance_index));\n" +
    "}\n",
  )
  composer.register_source(
    "entry.wgsl",
    (
      #|#import bevy_pbr::{ mesh::vertex, pbr::fragment }
      #|
    ),
  )
  let source = composer.compose_wgsl(
    "entry.wgsl",
    compose_regression_options(compose_regression_empty_defines()),
  ) catch {
    err =>
      abort("expected item-imported function compose success: \{err.message()}")
  }
  debug_inspect(source.trim().length(), content="0")
}

///|
test "naga_oil regression: item-imported entry points are dropped when unused by source" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "mesh.wgsl",
    "#define_import_path demo::mesh\n" +
    "@vertex\n" +
    "fn vertex() -> vec4<f32> {\n" +
    "  return vec4<f32>(0.0);\n" +
    "}\n",
  )
  composer.register_source(
    "pbr.wgsl",
    "#define_import_path demo::pbr\n" +
    "@fragment\n" +
    "fn fragment() -> vec4<f32> {\n" +
    "  return vec4<f32>(1.0);\n" +
    "}\n",
  )
  composer.register_source(
    "entry.wgsl",
    (
      #|#import demo::{ mesh::vertex, pbr::fragment }
      #|
    ),
  )
  let source = composer.compose_wgsl(
    "entry.wgsl",
    compose_regression_options(compose_regression_empty_defines()),
  ) catch {
    err => abort("expected issue 3 entry compose success: \{err.message()}")
  }
  debug_inspect(source.trim().length(), content="0")
}

///|
test "naga_oil regression: direct item imports require exact AST reference paths" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "unused.wgsl",
    "#define_import_path demo::unused\n" + "fn Item() -> u32 { return 1u; }\n",
  )
  composer.register_source(
    "other.wgsl",
    "#define_import_path demo::other\n" + "fn Item() -> u32 { return 2u; }\n",
  )
  composer.register_source(
    "root.wgsl",
    "#import demo::unused::Item\n" +
    "#import demo::other as other\n" +
    "fn entry() -> u32 { return other::Item(); }\n",
  )
  let source = composer.compose_wgsl(
    "root.wgsl",
    compose_regression_options(compose_regression_empty_defines()),
  ) catch {
    err =>
      abort("expected exact reference path compose success: \{err.message()}")
  }
  debug_inspect(source.contains("return 1u"), content="false")
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
}

///|
test "naga_oil regression: explicit import-only entry modules do not force dependencies" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "mesh.wgsl",
    "#define_import_path demo::mesh\n" +
    "struct Vertex { position: vec3<f32> }\n" +
    "struct VertexOutput { position: vec4<f32> }\n" +
    "fn vertex(vertex_no_morph: Vertex) -> VertexOutput {\n" +
    "  var out: VertexOutput;\n" +
    "  out.position = vec4<f32>(vertex_no_morph.position, 1.0);\n" +
    "  return out;\n" +
    "}\n",
  )
  composer.register_source(
    "entry.wgsl",
    (
      #|#import demo::mesh::vertex
      #|
    ),
  )
  let source = composer.compose_wgsl(
    "entry.wgsl",
    compose_regression_options(compose_regression_empty_defines()),
  ) catch {
    err =>
      abort("expected import-only vertex compose success: \{err.message()}")
  }
  debug_inspect(source.trim().length(), content="0")
}

///|
test "github issue 3: mixed full-module and item imports do not re-emit duplicate declarations" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "types.wgsl",
    "#define_import_path demo::types\n" +
    "struct StandardMaterial { value: f32 }\n",
  )
  composer.register_source(
    "bindings.wgsl",
    "#define_import_path demo::bindings\n" +
    "#import demo::types::StandardMaterial\n" +
    "@group(3) @binding(0) var<uniform> material: StandardMaterial;\n",
  )
  composer.register_source(
    "fragment.wgsl",
    "#define_import_path demo::fragment\n" +
    "#import demo::{ types, bindings }\n" +
    "fn use_material() -> types::StandardMaterial {\n" +
    "  return bindings::material;\n" +
    "}\n",
  )
  composer.register_source(
    "root.wgsl",
    "#import demo::fragment as fragment\n" +
    "fn fragment_entry() {\n" +
    "  fragment::use_material();\n" +
    "}\n",
  )
  let source = composer.compose_wgsl(
    "root.wgsl",
    compose_regression_options(compose_regression_empty_defines()),
  ) catch {
    err => abort("expected issue 3 mixed compose success: \{err.message()}")
  }
  debug_inspect(
    compose_regression_count_occurrences(
      source, "struct StandardMaterialX_naga_oil_mod_X",
    ),
    content="1",
  )
  debug_inspect(source.contains("bindings__StandardMaterial"), content="false")
  debug_inspect(
    source.contains("materialX_naga_oil_mod_X") &&
    source.contains(": StandardMaterialX_naga_oil_mod_X"),
    content="true",
  )
}

///|
test "github issue 3: nested alias imports rewrite variable declaration types" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "mesh_view_types.wgsl",
    "#define_import_path bevy_pbr::mesh_view_types\n" +
    "struct Lights { value: u32 }\n",
  )
  composer.register_source(
    "view.wgsl",
    "#define_import_path bevy_render::view\n" + "struct View { value: u32 }\n",
  )
  composer.register_source(
    "globals.wgsl",
    "#define_import_path bevy_render::globals\n" +
    "struct Globals { value: u32 }\n",
  )
  composer.register_source(
    "mesh_view_bindings.wgsl",
    "#define_import_path bevy_pbr::mesh_view_bindings\n" +
    "#import bevy_pbr::mesh_view_types as types\n" +
    "#import bevy_render::{ view::View, globals::Globals }\n" +
    "@group(0) @binding(0) var<uniform> view: View;\n" +
    "@group(0) @binding(1) var<uniform> globals: Globals;\n" +
    "@group(0) @binding(2) var<uniform> lights: types::Lights;\n",
  )
  composer.register_source(
    "root.wgsl",
    "#import bevy_pbr::mesh_view_bindings as mesh_view_bindings\n" +
    "fn read_view() -> u32 {\n" +
    "  return mesh_view_bindings::view.value + mesh_view_bindings::globals.value + mesh_view_bindings::lights.value;\n" +
    "}\n",
  )
  let source = composer.compose_wgsl(
    "root.wgsl",
    compose_regression_options(compose_regression_empty_defines()),
  ) catch {
    err =>
      abort("expected issue 3 nested alias compose success: \{err.message()}")
  }
  debug_inspect(source.contains(": View;"), content="false")
  debug_inspect(source.contains(": Globals;"), content="false")
  debug_inspect(source.contains("types::Lights"), content="false")
  debug_inspect(
    source.contains("var<uniform> viewX_naga_oil_mod_X") &&
    source.contains(": ViewX_naga_oil_mod_X"),
    content="true",
  )
  debug_inspect(
    source.contains("var<uniform> globalsX_naga_oil_mod_X") &&
    source.contains(": GlobalsX_naga_oil_mod_X"),
    content="true",
  )
  debug_inspect(
    source.contains("var<uniform> lightsX_naga_oil_mod_X") &&
    source.contains(": LightsX_naga_oil_mod_X"),
    content="true",
  )
}

///|
test "github issue 4: nested module alias rewrites global binding member access" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "view.wgsl",
    "#define_import_path bevy_render::view\n" +
    "struct View {\n" +
    "  world_from_view: mat4x4<f32>,\n" +
    "}\n",
  )
  composer.register_source(
    "mesh_view_bindings.wgsl",
    "#define_import_path bevy_pbr::mesh_view_bindings\n" +
    "#import bevy_render::view::View\n" +
    "@group(0) @binding(0) var<uniform> view: View;\n",
  )
  composer.register_source(
    "view_transformations.wgsl",
    "#define_import_path bevy_pbr::view_transformations\n" +
    "#import bevy_pbr::mesh_view_bindings as view_bindings\n" +
    "#import bevy_pbr::prepass_bindings\n" +
    "fn view_to_world(view_pos: vec3<f32>) -> vec3<f32> {\n" +
    "  let world_pos = view_bindings::view.world_from_view * vec4(view_pos, 1.0);\n" +
    "  return world_pos.xyz;\n" +
    "}\n" +
    "fn world_to_prev_view(world_pos: vec3<f32>) -> vec3<f32> {\n" +
    "  let view_pos = prepass_bindings::previous_view_uniforms.view_from_world * vec4(world_pos, 1.0);\n" +
    "  return view_pos.xyz;\n" +
    "}\n",
  )
  composer.register_source(
    "prepass_bindings.wgsl",
    "#define_import_path bevy_pbr::prepass_bindings\n" +
    "struct PreviousViewUniforms { view_from_world: mat4x4<f32> }\n" +
    "@group(0) @binding(30) var<uniform> previous_view_uniforms: PreviousViewUniforms;\n",
  )
  composer.register_source(
    "pbr_functions.wgsl",
    "#define_import_path bevy_pbr::pbr_functions\n" +
    "#import bevy_pbr::{\n" +
    "  mesh_view_bindings as view_bindings,\n" +
    "  view_transformations,\n" +
    "}\n" +
    "fn apply_transform(view_pos: vec3<f32>) -> vec3<f32> {\n" +
    "  return (view_bindings::view.world_from_view * vec4(view_pos, 1.0)).xyz + view_transformations::view_to_world(view_pos);\n" +
    "}\n",
  )
  composer.register_source(
    "root.wgsl",
    "#import bevy_pbr::pbr_functions as pbr_functions\n" +
    "fn read_world(view_pos: vec3<f32>) -> vec3<f32> {\n" +
    "  return pbr_functions::apply_transform(view_pos);\n" +
    "}\n",
  )
  let output = @export.export_wgsl_with_options(
    composer,
    "root.wgsl",
    compose_regression_options(compose_regression_empty_defines()),
    { root_items: ["read_world"] },
  ) catch {
    err =>
      abort("expected issue 4 nested alias compose success: \{err.message()}")
  }
  let source = output.source
  debug_inspect(source.contains("view_bindings::view"), content="false")
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(
    source.contains("var<uniform> view_bindings__view: View"),
    content="false",
  )
  debug_inspect(
    source.contains("var<uniform> viewX_naga_oil_mod_X") &&
    source.contains(": ViewX_naga_oil_mod_X"),
    content="true",
  )
}

///|
test "github issue 8: Bevy module alias keeps clustered_lights binding live" {
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
    "fn entry() -> u32 {\n" +
    "  return lighting::read_clustered_light();\n" +
    "}\n",
  )
  let source = composer.compose_wgsl(
    "root.wgsl",
    compose_regression_options(compose_regression_empty_defines()),
  ) catch {
    err =>
      abort(
        "expected issue 8 clustered_lights compose success: \{err.message()}",
      )
  }
  debug_inspect(
    source.contains("view_bindings::clustered_lights"),
    content="false",
  )
  debug_inspect(
    source.contains("var<storage> clustered_lightsX_naga_oil_mod_X") &&
    source.contains(": ClusteredLightsX_naga_oil_mod_X"),
    content="true",
  )
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
}

///|
test "github issue 9: item imported struct preserves canonical type identity" {
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
  let source = composer.compose_wgsl(
    "pbr.wgsl",
    compose_regression_options(compose_regression_empty_defines()),
  ) catch {
    err => abort("expected issue 9 compose success: \{err.message()}")
  }
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(source.contains("struct PbrInput {"), content="false")
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(source.contains("ptr<function, PbrInput>"), content="false")
}

///|
