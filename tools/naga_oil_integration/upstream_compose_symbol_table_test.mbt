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
test "github issue 12: transitive tonemapping type identity is reused" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "view.wgsl",
    "#define_import_path bevy_render::view\n" +
    "struct ColorGrading { exposure: f32 }\n" +
    "struct View { color_grading: ColorGrading }\n",
  )
  composer.register_source(
    "mesh_view_bindings.wgsl",
    "#define_import_path bevy_pbr::mesh_view_bindings\n" +
    "#import bevy_render::view::View\n" +
    "@group(0) @binding(0) var<uniform> view: View;\n",
  )
  composer.register_source(
    "tonemapping.wgsl",
    "#define_import_path bevy_core_pipeline::tonemapping\n" +
    "#import bevy_render::view::ColorGrading\n" +
    "fn tone_mapping(in: vec4<f32>, in_color_grading: ColorGrading) -> vec4<f32> {\n" +
    "  return in;\n" +
    "}\n",
  )
  composer.register_source(
    "pbr_functions.wgsl",
    "#define_import_path bevy_pbr::pbr_functions\n" +
    "#import bevy_pbr::mesh_view_bindings as view_bindings\n" +
    "#import bevy_core_pipeline::tonemapping::tone_mapping\n" +
    "fn post_light(output_color: vec4<f32>) -> vec4<f32> {\n" +
    "  return tone_mapping(output_color, view_bindings::view.color_grading);\n" +
    "}\n",
  )
  composer.register_source(
    "pbr.wgsl",
    "#import bevy_pbr::pbr_functions as pbr_functions\n" +
    "fn root(color: vec4<f32>) -> vec4<f32> {\n" +
    "  return pbr_functions::post_light(color);\n" +
    "}\n",
  )
  let source = composer.compose_wgsl(
    "pbr.wgsl",
    upstream_parity_compose_options(upstream_parity_empty_defines()),
  ) catch {
    err => abort("expected issue 12 compose success: \{err.message()}")
  }
  let color_grading_is_consistent = source.contains(
    "in_color_grading: ColorGradingX_naga_oil_mod_X",
  )
  let color_grading_decl_is_visible = source.contains(
    "struct ColorGradingX_naga_oil_mod_X",
  )
  debug_inspect(color_grading_is_consistent, content="true")
  debug_inspect(color_grading_decl_is_visible, content="true")
  debug_inspect(
    source.contains("in_color_grading: ColorGrading)"),
    content="false",
  )
}

///|
test "composer symbol table: parent alias does not expose transitive imports" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "dep.wgsl",
    "#define_import_path app::dep\n" + "fn helper() -> u32 { return 1u; }\n",
  )
  composer.register_source(
    "consumer.wgsl",
    "#define_import_path app::consumer\n" +
    "#import app::dep::helper\n" +
    "fn call_helper() -> u32 { return helper(); }\n",
  )
  composer.register_source(
    "root.wgsl",
    "#import app::dep as dep_alias\n" +
    "#import app::consumer as consumer_alias\n" +
    "fn entry() -> u32 {\n" +
    "  return dep_alias::helper() + consumer_alias::call_helper();\n" +
    "}\n",
  )
  let source = composer.compose_wgsl(
    "root.wgsl",
    upstream_parity_compose_options(upstream_parity_empty_defines()),
  ) catch {
    err =>
      abort(
        "expected transitive alias-surface compose success: \{err.message()}",
      )
  }
  debug_inspect(source.contains("consumer_alias__helper"), content="false")
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(source.contains("return helper();"), content="false")
}

///|
test "composer symbol table: direct item emit creates local unqualified binding" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "dep.wgsl",
    "#define_import_path app::dep\n" + "fn helper() -> u32 { return 1u; }\n",
  )
  composer.register_source(
    "consumer.wgsl",
    "#define_import_path app::consumer\n" +
    "#import app::dep::helper\n" +
    "fn call_helper() -> u32 { return helper(); }\n",
  )
  composer.register_source(
    "root.wgsl",
    "#import app::consumer as consumer_alias\n" +
    "fn entry() -> u32 { return consumer_alias::call_helper(); }\n",
  )
  let source = composer.compose_wgsl(
    "root.wgsl",
    upstream_parity_compose_options(upstream_parity_empty_defines()),
  ) catch {
    err =>
      abort("expected direct item binding compose success: \{err.message()}")
  }
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(source.contains("return helper();"), content="false")
}

///|
test "github issue 6: transitive nested module alias rewrites imported binding types" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "view.wgsl",
    "#define_import_path bevy_render::view\n" + "struct View { value: u32 }\n",
  )
  composer.register_source(
    "mesh_view_bindings.wgsl",
    "#define_import_path bevy_pbr::mesh_view_bindings\n" +
    "#import bevy_render::view::View\n" +
    "@group(0) @binding(0) var<uniform> view: View;\n",
  )
  composer.register_source(
    "clustered_forward.wgsl",
    "#define_import_path bevy_pbr::clustered_forward\n" +
    "#import bevy_pbr::mesh_view_bindings as bindings\n" +
    "fn read_cluster_view() -> u32 {\n" +
    "  return bindings::view.value;\n" +
    "}\n",
  )
  composer.register_source(
    "pbr_functions.wgsl",
    "#define_import_path bevy_pbr::pbr_functions\n" +
    "#import bevy_pbr::{\n" +
    "  mesh_view_bindings as view_bindings,\n" +
    "  clustered_forward as clustering,\n" +
    "}\n" +
    "fn read_pbr_view() -> u32 {\n" +
    "  return view_bindings::view.value + clustering::read_cluster_view();\n" +
    "}\n",
  )
  composer.register_source(
    "root.wgsl",
    "#import bevy_pbr::pbr_functions as pbr_functions\n" +
    "fn read_view() -> u32 {\n" +
    "  return pbr_functions::read_pbr_view();\n" +
    "}\n",
  )
  let source = composer.compose_wgsl(
    "root.wgsl",
    upstream_parity_compose_options(upstream_parity_empty_defines()),
  ) catch {
    err =>
      abort(
        "expected issue 6 transitive nested alias compose success: \{err.message()}",
      )
  }
  debug_inspect(source.contains(": View;"), content="false")
  debug_inspect(
    source.contains(
      "var<uniform> pbr_functions__clustering__bindings__view: pbr_functions__view_bindings__View",
    ),
    content="false",
  )
  debug_inspect(
    source.contains("pbr_functions__clustering__bindings__view"),
    content="false",
  )
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(
    upstream_parity_count_occurrences(source, "viewX_naga_oil_mod_X") > 0,
    content="true",
  )
}

///|
test "github issue 6: root local defines are stripped from final composed WGSL" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "root_define.wgsl",
    "#define_import_path demo::root_define\n" +
    "#define TONEMAPPING_PASS\n" +
    "#ifdef TONEMAPPING_PASS\n" +
    "const enabled: u32 = 1u;\n" +
    "#endif\n",
  )
  let source = composer.compose_wgsl(
    "root_define.wgsl",
    upstream_parity_compose_options(upstream_parity_empty_defines()),
  ) catch {
    err => abort("expected root-local define compose success: \{err.message()}")
  }
  debug_inspect(source.contains("#define"), content="false")
  debug_inspect(source.contains("TONEMAPPING_PASS"), content="false")
  debug_inspect(source.contains("const enabled: u32 = 1u;"), content="true")
}

///|
test "composer symbol table: partial import keeps alias-qualified type dependency live" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "types.wgsl",
    "#define_import_path app::types\n" + "struct LightProbes { value: u32 }\n",
  )
  composer.register_source(
    "bindings.wgsl",
    "#define_import_path app::bindings\n" +
    "#import app::types as types\n" +
    "@group(0) @binding(0) var<uniform> light_probes: types::LightProbes;\n",
  )
  composer.register_source(
    "consumer.wgsl",
    "#define_import_path app::consumer\n" +
    "#import app::bindings::light_probes\n" +
    "fn read_light_probes() -> u32 {\n" +
    "  return light_probes.value;\n" +
    "}\n",
  )
  let source = composer.compose_wgsl(
    "consumer.wgsl",
    upstream_parity_empty_compose_options(),
  ) catch {
    err =>
      abort(
        "expected alias-qualified type dependency compose success: \{err.message()}",
      )
  }
  debug_inspect(source.contains("types::LightProbes"), content="false")
  debug_inspect(
    source.contains("struct LightProbesX_naga_oil_mod_X"),
    content="true",
  )
  debug_inspect(
    source.contains("var<uniform> light_probesX_naga_oil_mod_X"),
    content="true",
  )
}

///|
test "composer symbol table: nested full-module alias keeps transitive alias type dependency live" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "types.wgsl",
    "#define_import_path app::types\n" + "struct LightProbes { value: u32 }\n",
  )
  composer.register_source(
    "bindings.wgsl",
    "#define_import_path app::bindings\n" +
    "#import app::types as types\n" +
    "@group(0) @binding(0) var<uniform> light_probes: types::LightProbes;\n",
  )
  composer.register_source(
    "clustered.wgsl",
    "#define_import_path app::clustered\n" +
    "#import app::bindings\n" +
    "fn read_clustered() -> u32 {\n" +
    "  return bindings::light_probes.value;\n" +
    "}\n",
  )
  composer.register_source(
    "root.wgsl",
    "#import app::clustered as clustered\n" +
    "fn read_root() -> u32 {\n" +
    "  return clustered::read_clustered();\n" +
    "}\n",
  )
  let source = composer.compose_wgsl(
    "root.wgsl",
    upstream_parity_empty_compose_options(),
  ) catch {
    err =>
      abort(
        "expected nested alias type dependency compose success: \{err.message()}",
      )
  }
  debug_inspect(source.contains("types::LightProbes"), content="false")
  debug_inspect(source.contains("bindings::light_probes"), content="false")
  debug_inspect(source.contains("clustered::read_clustered"), content="false")
  debug_inspect(
    source.contains("struct LightProbesX_naga_oil_mod_X"),
    content="true",
  )
}

///|
test "composer symbol table: partial import keeps alias-qualified function dependency live" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "helpers.wgsl",
    "#define_import_path app::helpers\n" +
    "fn pack_value(v: u32) -> u32 {\n" +
    "  return v + 1u;\n" +
    "}\n",
  )
  composer.register_source(
    "functions.wgsl",
    "#define_import_path app::functions\n" +
    "#import app::helpers as helpers\n" +
    "fn deferred_output(v: u32) -> u32 {\n" +
    "  return helpers::pack_value(v);\n" +
    "}\n",
  )
  composer.register_source(
    "root.wgsl",
    "#define_import_path app::root\n" +
    "#import app::functions::deferred_output\n" +
    "fn fragment() -> u32 {\n" +
    "  return deferred_output(3u);\n" +
    "}\n",
  )
  let source = composer.compose_wgsl(
    "root.wgsl",
    upstream_parity_empty_compose_options(),
  ) catch {
    err =>
      abort(
        "expected alias-qualified function dependency compose success: \{err.message()}",
      )
  }
  debug_inspect(source.contains("helpers::pack_value"), content="false")
  debug_inspect(
    source.contains("fn pack_valueX_naga_oil_mod_X"),
    content="true",
  )
  debug_inspect(
    source.contains("fn deferred_outputX_naga_oil_mod_X"),
    content="true",
  )
}

///|
test "composer symbol table: grouped partial import keeps alias-qualified function dependency live" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "helpers.wgsl",
    "#define_import_path app::helpers\n" +
    "fn pack_value(v: u32) -> u32 {\n" +
    "  return v + 1u;\n" +
    "}\n",
  )
  composer.register_source(
    "extra.wgsl",
    "#define_import_path app::extra\n" + "const EXTRA: u32 = 1u;\n",
  )
  composer.register_source(
    "functions.wgsl",
    "#define_import_path app::functions\n" +
    "#import app::{helpers as helpers, extra::EXTRA}\n" +
    "fn deferred_output(v: u32) -> u32 {\n" +
    "  return helpers::pack_value(v) + EXTRA;\n" +
    "}\n",
  )
  composer.register_source(
    "root.wgsl",
    "#define_import_path app::root\n" +
    "#import app::functions::deferred_output\n" +
    "fn fragment() -> u32 {\n" +
    "  return deferred_output(3u);\n" +
    "}\n",
  )
  let source = composer.compose_wgsl(
    "root.wgsl",
    upstream_parity_empty_compose_options(),
  ) catch {
    err =>
      abort(
        "expected grouped alias-qualified function dependency compose success: \{err.message()}",
      )
  }
  debug_inspect(source.contains("helpers::pack_value"), content="false")
  debug_inspect(
    source.contains("fn pack_valueX_naga_oil_mod_X"),
    content="true",
  )
  debug_inspect(source.contains("const EXTRAX_naga_oil_mod_X"), content="true")
}

///|
test "composer symbol table: partial import keeps nested alias-qualified function dependency live" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "helpers.wgsl",
    "#define_import_path app::helpers\n" +
    "fn pack_value(v: u32) -> u32 {\n" +
    "  return v + 1u;\n" +
    "}\n",
  )
  composer.register_source(
    "functions.wgsl",
    "#define_import_path app::functions\n" +
    "#import app::helpers as helpers\n" +
    "fn build_value(v: u32) -> u32 {\n" +
    "  return helpers::pack_value(v);\n" +
    "}\n" +
    "fn deferred_output(v: u32) -> u32 {\n" +
    "  return build_value(v);\n" +
    "}\n",
  )
  composer.register_source(
    "root.wgsl",
    "#define_import_path app::root\n" +
    "#import app::functions::deferred_output\n" +
    "fn fragment() -> u32 {\n" +
    "  return deferred_output(3u);\n" +
    "}\n",
  )
  let source = composer.compose_wgsl(
    "root.wgsl",
    upstream_parity_empty_compose_options(),
  ) catch {
    err =>
      abort(
        "expected nested alias-qualified function dependency compose success: \{err.message()}",
      )
  }
  debug_inspect(source.contains("helpers::pack_value"), content="false")
  debug_inspect(
    source.contains("fn pack_valueX_naga_oil_mod_X"),
    content="true",
  )
  debug_inspect(
    source.contains("fn build_valueX_naga_oil_mod_X"),
    content="true",
  )
}

///|
test "composer symbol table: partial import keeps trailing-underscore alias dependency live" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "helpers.wgsl",
    "#define_import_path app::helpers\n" +
    "fn pack_value_(v: u32) -> u32 {\n" +
    "  return v + 1u;\n" +
    "}\n",
  )
  composer.register_source(
    "functions.wgsl",
    "#define_import_path app::functions\n" +
    "#import app::helpers as helpers\n" +
    "fn build_value(v: u32) -> u32 {\n" +
    "  return helpers::pack_value_(v);\n" +
    "}\n" +
    "fn deferred_output(v: u32) -> u32 {\n" +
    "  return build_value(v);\n" +
    "}\n",
  )
  composer.register_source(
    "root.wgsl",
    "#define_import_path app::root\n" +
    "#import app::functions::deferred_output\n" +
    "fn fragment() -> u32 {\n" +
    "  return deferred_output(3u);\n" +
    "}\n",
  )
  let source = composer.compose_wgsl(
    "root.wgsl",
    upstream_parity_empty_compose_options(),
  ) catch {
    err =>
      abort(
        "expected trailing-underscore alias dependency compose success: \{err.message()}",
      )
  }
  debug_inspect(source.contains("helpers::pack_value_"), content="false")
  debug_inspect(
    source.contains("fn pack_value_X_naga_oil_mod_X"),
    content="true",
  )
}

///|
test "composer symbol table: grouped long-path alias keeps trailing-underscore dependency live" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "deferred_types.wgsl",
    "#define_import_path app::pbr_deferred_types\n" +
    "fn pack_unorm4x8_(v: vec4<f32>) -> u32 {\n" +
    "  return u32(v.x);\n" +
    "}\n",
  )
  composer.register_source(
    "pbr_types.wgsl",
    "#define_import_path app::pbr_types\n" +
    "struct PbrInput { value: vec4<f32> }\n",
  )
  composer.register_source(
    "functions.wgsl",
    "#define_import_path app::pbr_deferred_functions\n" +
    "#import app:: {pbr_types::PbrInput, pbr_deferred_types as deferred_types, }\n" +
    "fn deferred_gbuffer_from_pbr_input(in: PbrInput) -> u32 {\n" +
    "  return deferred_types::pack_unorm4x8_(in.value);\n" +
    "}\n" +
    "fn deferred_output(in: PbrInput) -> u32 {\n" +
    "  return deferred_gbuffer_from_pbr_input(in);\n" +
    "}\n",
  )
  composer.register_source(
    "root.wgsl",
    "#define_import_path app::root\n" +
    "#import app::pbr_deferred_functions::deferred_output\n" +
    "fn fragment(in: PbrInput) -> u32 {\n" +
    "  return deferred_output(in);\n" +
    "}\n",
  )
  let source = composer.compose_wgsl(
    "root.wgsl",
    upstream_parity_empty_compose_options(),
  ) catch {
    err =>
      abort(
        "expected grouped long-path alias dependency compose success: \{err.message()}",
      )
  }
  debug_inspect(
    source.contains("deferred_types::pack_unorm4x8_"),
    content="false",
  )
  debug_inspect(
    source.contains("fn pack_unorm4x8_X_naga_oil_mod_X"),
    content="true",
  )
}

///|
test "composer symbol table: local global shadows same-name unqualified import binding" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "imported.wgsl",
    "#define_import_path app::imported\n" +
    "struct ImportedGlobals { value: u32 }\n" +
    "@group(0) @binding(0) var<uniform> globals: ImportedGlobals;\n" +
    "fn read_imported() -> u32 {\n" +
    "  return globals.value;\n" +
    "}\n",
  )
  composer.register_source(
    "root.wgsl",
    "#define_import_path app::root\n" +
    "#import app::imported::read_imported\n" +
    "struct LocalGlobals { time: u32 }\n" +
    "@group(0) @binding(1) var<uniform> globals: LocalGlobals;\n" +
    "fn fragment() -> u32 {\n" +
    "  return globals.time + read_imported();\n" +
    "}\n",
  )
  let source = composer.compose_wgsl(
    "root.wgsl",
    upstream_parity_empty_compose_options(),
  ) catch {
    err =>
      abort("expected local global shadowing compose success: \{err.message()}")
  }
  debug_inspect(source.contains("globals.time"), content="true")
  debug_inspect(source.contains("globalsX_naga_oil_mod_X"), content="true")
}

///|
test "composer symbol table: default module alias rewrites qualified function reference" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "irradiance_volume.wgsl",
    "#define_import_path app::irradiance_volume\n" +
    "fn irradiance_volume_light(v: u32) -> u32 {\n" +
    "  return v + 1u;\n" +
    "}\n",
  )
  composer.register_source(
    "root.wgsl",
    "#define_import_path app::root\n" +
    "#import app::irradiance_volume\n" +
    "fn fragment() -> u32 {\n" +
    "  return irradiance_volume::irradiance_volume_light(3u);\n" +
    "}\n",
  )
  let source = composer.compose_wgsl(
    "root.wgsl",
    upstream_parity_empty_compose_options(),
  ) catch {
    err =>
      abort(
        "expected default module alias qualified function compose success: \{err.message()}",
      )
  }
  debug_inspect(
    source.contains("irradiance_volume::irradiance_volume_light"),
    content="false",
  )
  debug_inspect(
    source.contains("fn irradiance_volume_lightX_naga_oil_mod_X"),
    content="true",
  )
}

///|
test "composer symbol table: alias partial module keeps alias-qualified global type dependency live" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "types.wgsl",
    "#define_import_path app::types\n" + "struct Lights { value: u32 }\n",
  )
  composer.register_source(
    "bindings.wgsl",
    "#define_import_path app::bindings\n" +
    "#import app::types as types\n" +
    "@group(0) @binding(0) var<uniform> lights: types::Lights;\n",
  )
  composer.register_source(
    "clustered.wgsl",
    "#define_import_path app::clustered\n" +
    "#import app::bindings as bindings\n" +
    "fn read_lights() -> u32 {\n" +
    "  return bindings::lights.value;\n" +
    "}\n",
  )
  composer.register_source(
    "root.wgsl",
    "#define_import_path app::root\n" +
    "#import app::clustered\n" +
    "fn fragment() -> u32 {\n" +
    "  return clustered::read_lights();\n" +
    "}\n",
  )
  let source = composer.compose_wgsl(
    "root.wgsl",
    upstream_parity_empty_compose_options(),
  ) catch {
    err =>
      abort(
        "expected alias partial module type dependency compose success: \{err.message()}",
      )
  }
  debug_inspect(source.contains("types::Lights"), content="false")
  debug_inspect(source.contains("bindings::lights"), content="false")
  debug_inspect(source.contains("clustered::read_lights"), content="false")
  debug_inspect(
    source.contains("struct LightsX_naga_oil_mod_X"),
    content="true",
  )
}

///|
test "composer symbol table: direct default import and nested alias share typed dependencies" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "types.wgsl",
    "#define_import_path app::types\n" + "struct Lights { value: u32 }\n",
  )
  composer.register_source(
    "bindings.wgsl",
    "#define_import_path app::bindings\n" +
    "#import app::types as types\n" +
    "@group(0) @binding(0) var<uniform> lights: types::Lights;\n",
  )
  composer.register_source(
    "clustered.wgsl",
    "#define_import_path app::clustered\n" +
    "#import app::bindings as bindings\n" +
    "fn read_lights() -> u32 {\n" +
    "  return bindings::lights.value;\n" +
    "}\n",
  )
  composer.register_source(
    "root.wgsl",
    "#define_import_path app::root\n" +
    "#import app::bindings\n" +
    "#import app::clustered\n" +
    "fn fragment() -> u32 {\n" +
    "  return bindings::lights.value + clustered::read_lights();\n" +
    "}\n",
  )
  let source = composer.compose_wgsl(
    "root.wgsl",
    upstream_parity_empty_compose_options(),
  ) catch {
    err =>
      abort(
        "expected direct and nested alias dependency compose success: \{err.message()}",
      )
  }
  debug_inspect(source.contains("types::Lights"), content="false")
  debug_inspect(source.contains("bindings::lights"), content="false")
  debug_inspect(source.contains("clustered::read_lights"), content="false")
  debug_inspect(
    source.contains("struct LightsX_naga_oil_mod_X"),
    content="true",
  )
}

///|
test "composer symbol table: transitive default alias keeps sibling alias type dependencies" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "types.wgsl",
    "#define_import_path app::types\n" +
    "struct Lights { value: u32 }\n" +
    "struct LightProbes { value: u32 }\n",
  )
  composer.register_source(
    "bindings.wgsl",
    "#define_import_path app::bindings\n" +
    "#import app::types as types\n" +
    "@group(0) @binding(0) var<uniform> lights: types::Lights;\n" +
    "@group(0) @binding(1) var<uniform> light_probes: types::LightProbes;\n",
  )
  composer.register_source(
    "clustered.wgsl",
    "#define_import_path app::clustered\n" +
    "#import app::bindings as bindings\n" +
    "struct Ranges { first: u32 }\n" +
    "fn read_lights() -> u32 {\n" +
    "  return bindings::lights.value;\n" +
    "}\n",
  )
  composer.register_source(
    "irradiance.wgsl",
    "#define_import_path app::irradiance\n" +
    "#import app::clustered\n" +
    "#import app::clustered::Ranges\n" +
    "#import app::bindings::light_probes\n" +
    "fn irradiance_volume_light(ranges: ptr<function, Ranges>) -> u32 {\n" +
    "  return clustered::read_lights() + light_probes.value + (*ranges).first;\n" +
    "}\n",
  )
  composer.register_source(
    "root.wgsl",
    "#define_import_path app::root\n" +
    "#import app::irradiance\n" +
    "fn fragment() -> u32 {\n" +
    "  var ranges: Ranges;\n" +
    "  return irradiance::irradiance_volume_light(&ranges);\n" +
    "}\n",
  )
  let source = composer.compose_wgsl(
    "root.wgsl",
    upstream_parity_empty_compose_options(),
  ) catch {
    err =>
      abort(
        "expected transitive default alias sibling dependency compose success: \{err.message()}",
      )
  }
  debug_inspect(source.contains("types::Lights"), content="false")
  debug_inspect(source.contains("types::LightProbes"), content="false")
  debug_inspect(source.contains("clustered::read_lights"), content="false")
  debug_inspect(
    source.contains("irradiance::irradiance_volume_light"),
    content="false",
  )
  debug_inspect(
    source.contains("struct LightsX_naga_oil_mod_X"),
    content="true",
  )
  debug_inspect(
    source.contains("struct LightProbesX_naga_oil_mod_X"),
    content="true",
  )
}

///|
test "composer symbol table: unqualified item import rewrites item sharing module leaf name" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "irradiance_volume.wgsl",
    "#define_import_path app::irradiance_volume\n" +
    "fn irradiance_volume(v: u32) -> u32 {\n" +
    "  return v + 1u;\n" +
    "}\n",
  )
  composer.register_source(
    "root.wgsl",
    "#define_import_path app::root\n" +
    "#import app::irradiance_volume::irradiance_volume\n" +
    "fn fragment() -> u32 {\n" +
    "  return irradiance_volume(1u);\n" +
    "}\n",
  )
  let source = composer.compose_wgsl(
    "root.wgsl",
    upstream_parity_empty_compose_options(),
  ) catch {
    err =>
      abort("expected same-leaf item import compose success: \{err.message()}")
  }
  debug_inspect(source.contains("return irradiance_volume("), content="false")
  debug_inspect(
    source.contains("fn irradiance_volumeX_naga_oil_mod_X"),
    content="true",
  )
}

///|
test "composer symbol table: imported module may use unqualified item sharing its own module alias" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "bindings.wgsl",
    "#define_import_path app::bindings\n" +
    "const irradiance_volume: u32 = 7u;\n",
  )
  composer.register_source(
    "irradiance_volume.wgsl",
    "#define_import_path app::irradiance_volume\n" +
    "#import app::bindings::irradiance_volume\n" +
    "fn irradiance_volume_light() -> u32 {\n" +
    "  return irradiance_volume;\n" +
    "}\n",
  )
  composer.register_source(
    "root.wgsl",
    "#define_import_path app::root\n" +
    "#import app::irradiance_volume\n" +
    "fn fragment() -> u32 {\n" +
    "  return irradiance_volume::irradiance_volume_light();\n" +
    "}\n",
  )
  let source = composer.compose_wgsl(
    "root.wgsl",
    upstream_parity_empty_compose_options(),
  ) catch {
    err =>
      abort(
        "expected module-local same-alias unqualified item compose success: \{err.message()}",
      )
  }
  debug_inspect(source.contains("return irradiance_volume;"), content="false")
  debug_inspect(
    source.contains("const irradiance_volumeX_naga_oil_mod_X"),
    content="true",
  )
}

///|
test "composer symbol table: imported module rewrites unqualified resource sharing module alias" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "bindings.wgsl",
    "#define_import_path app::bindings\n" +
    "@group(0) @binding(0) var irradiance_volume: texture_3d<f32>;\n" +
    "@group(0) @binding(1) var irradiance_volume_sampler: sampler;\n",
  )
  composer.register_source(
    "irradiance_volume.wgsl",
    "#define_import_path app::irradiance_volume\n" +
    "#import app::bindings::{irradiance_volume, irradiance_volume_sampler}\n" +
    "fn irradiance_volume_light() -> vec4<f32> {\n" +
    "  return textureSampleLevel(irradiance_volume, irradiance_volume_sampler, vec3<f32>(0.5), 0.0);\n" +
    "}\n",
  )
  composer.register_source(
    "root.wgsl",
    "#define_import_path app::root\n" +
    "#import app::irradiance_volume\n" +
    "fn fragment() -> vec4<f32> {\n" +
    "  return irradiance_volume::irradiance_volume_light();\n" +
    "}\n",
  )
  let source = composer.compose_wgsl(
    "root.wgsl",
    upstream_parity_empty_compose_options(),
  ) catch {
    err =>
      abort("expected same-alias resource compose success: \{err.message()}")
  }
  debug_inspect(
    source.contains("textureSampleLevel(irradiance_volume,"),
    content="false",
  )
  debug_inspect(
    source.contains("var irradiance_volumeX_naga_oil_mod_X"),
    content="true",
  )
}
