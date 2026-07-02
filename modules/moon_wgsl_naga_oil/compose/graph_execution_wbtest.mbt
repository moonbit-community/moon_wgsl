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
test "composer uses naga_oil module decoration for planned imported names" {
  debug_inspect(wgsl_naga_oil_base32_nopad("inc"), content="\"NFXGG\"")
  debug_inspect(wgsl_naga_oil_base32_nopad("mod"), content="\"NVXWI\"")
  debug_inspect(
    wgsl_naga_oil_decorated_final_name("inc", "hello"),
    content="\"helloX_naga_oil_mod_XNFXGGX\"",
  )
}

///|
test "composer preserves quoted file import path identity for final names" {
  let composer = Composer::default()
  let imported_source =
    #|const COLOR_MULTIPLIER: vec4<f32> = vec4<f32>(1.0);
    #|
  let root_source =
    #|#import "shaders/custom_material_import.wgsl"::COLOR_MULTIPLIER
    #|
    #|fn fragment() -> vec4<f32> {
    #|  return COLOR_MULTIPLIER;
    #|}
    #|
  composer.register_source(
    "assets/shaders/custom_material_import.wgsl", imported_source,
  )
  composer.register_source("assets/shaders/custom_material.wgsl", root_source)
  let emitted = composer.compose_wgsl_before_ir(
    "assets/shaders/custom_material.wgsl",
    WgslComposeOptions::default(),
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains(
      "COLOR_MULTIPLIERX_naga_oil_mod_XEJZWQYLEMVZHGL3DOVZXI33NL5WWC5DFOJUWC3C7NFWXA33SOQXHOZ3TNQRAX",
    ),
    content="true",
  )
}

///|
test "compose graph execution plans reachability before emission" {
  let composer = Composer::default()
  let dep_source =
    #|#define_import_path dep
    #|fn dep_fn() -> u32 {
    #|  return 1u;
    #|}
    #|
  composer.register_source("dep.wgsl", dep_source)
  let session = composer.new_wgsl_compose_session(WgslComposeOptions::default())
  session.symbols.source_origins.push(
    WgslSourceOriginEntry(
      "PIX_naga_oil_mod_X",
      "maths.wgsl",
      "PI",
      Constant,
      0,
      0,
    ),
  )
  let source =
    #|#import dep::dep_fn
    #|fn root() -> u32 {
    #|  return dep_fn();
    #|}
    #|
  WgslImportGraphBuilder(composer, session).complete_execution(
    "root.wgsl",
    source,
    None,
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(session.graph_execution_complete, content="true")
  debug_inspect(session.link_graph.import_edge_count(), content="1")
  debug_inspect(session.link_graph.import_arena_event_count(), content="0")
  debug_inspect(
    session.link_graph.contains_reachable_symbol(
      WgslIrSymbolIdentity("dep.wgsl", "dep_fn"),
    ),
    content="true",
  )
  debug_inspect(
    session.symbols.emitted_final_names.canonical_entry_count(),
    content="0",
  )
  let output = WgslComposeEmitter(composer, session).emit_source_with_path(
    "root.wgsl",
    source,
    None,
    WgslComposeBindingSet(),
    true,
    true,
    [],
    false,
    true,
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(output.contains("fn dep_fn"), content="true")
  debug_inspect(
    session.symbols.emitted_final_names.canonical_get(
      WgslIrSymbolIdentity("dep.wgsl", "dep_fn"),
    )
    is Some(_),
    content="true",
  )
  debug_inspect(session.link_graph.import_arena_event_count(), content="1")
  debug_inspect(session.symbols.import_arena_events.length(), content="1")
  let arena_events = session.link_graph.import_arena_events()
  debug_inspect(arena_events[0].target_rel_path(), content="\"dep.wgsl\"")
  debug_inspect(arena_events[0].generated_symbol_names().length(), content="1")
  let provenance = session.symbols.generated_import_provenance("root.wgsl")
  let mut dep_index = -1
  for i in 0..<provenance.length() {
    if provenance[i].source_symbol_name == "dep_fn" {
      dep_index = i
    }
  }
  debug_inspect(dep_index >= 0, content="true")
  debug_inspect(provenance[dep_index].import_sequence >= 0, content="true")
  debug_inspect(provenance[dep_index].source_start >= 0, content="true")
}

///|
test "composer exposes IR-backed compose output" {
  let composer = Composer::default()
  let inc_source =
    #|#define_import_path ir_corpus::inc
    #|
    #|fn helper(value: u32) -> u32 {
    #|  return value + 1u;
    #|}
    #|
  composer.register_source("inc.wgsl", inc_source)
  let top_source =
    #|#import ir_corpus::inc::helper
    #|
    #|@group(0) @binding(0)
    #|var<storage, read_write> buffer: u32;
    #|
    #|@compute @workgroup_size(1, 1, 1)
    #|fn main() {
    #|  var result: u32 = helper(1u);
    #|  result = min(result, 9u);
    #|  buffer = result;
    #|}
    #|
  composer.register_source("top.wgsl", top_source)
  let emitted = composer.compose_wgsl("top.wgsl", WgslComposeOptions::default()) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("#import"), content="false")
  debug_inspect(emitted.contains("fn helper"), content="true")
  debug_inspect(emitted.contains("@compute @workgroup_size"), content="true")
}

///|
test "composer selects duplicate import-path candidate by active requested symbols" {
  let composer = Composer::default()
  let real_source =
    #|#define_import_path test::candidate
    #|
    #|#ifdef USE_REAL
    #|fn helper() -> u32 {
    #|  return 7u;
    #|}
    #|#endif
    #|
  let dummy_source =
    #|#define_import_path test::candidate
    #|
    #|// intentionally empty fallback candidate
    #|
  composer.register_source("real.wgsl", real_source)
  composer.register_source("dummy.wgsl", dummy_source)
  let root_source =
    #|#import test::candidate::helper
    #|
    #|fn main() -> u32 {
    #|  return helper();
    #|}
    #|
  composer.register_source("root.wgsl", root_source)
  let options = WgslComposeOptions::default()
  options.defines.set("USE_REAL", true)
  let emitted = composer.compose_wgsl("root.wgsl", options) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("fn helper"), content="true")
  debug_inspect(emitted.contains("return 7u"), content="true")
}

///|
test "composer resolves transitive partial-import constants before IR" {
  let composer = Composer::default()
  let maths_source =
    #|#define_import_path test::maths
    #|
    #|const PI_2: f32 = 6.28318;
    #|
  composer.register_source("maths.wgsl", maths_source)
  let color_source =
    #|#define_import_path test::color
    #|#import test::maths::{PI_2}
    #|
    #|fn oklch_to_linear_rgb(c: vec3<f32>) -> vec3<f32> {
    #|  let hue = c.z * PI_2;
    #|  return vec3(hue, c.x, c.y);
    #|}
    #|
  composer.register_source("color.wgsl", color_source)
  let root_source =
    #|#import test::color::{
    #|  oklch_to_linear_rgb,
    #|}
    #|
    #|@fragment
    #|fn fragment() -> @location(0) vec4<f32> {
    #|  return vec4(oklch_to_linear_rgb(vec3(1.0, 0.5, 0.25)), 1.0);
    #|}
    #|
  composer.register_source("root.wgsl", root_source)
  let emitted = composer.compose_wgsl_before_ir(
    "root.wgsl",
    WgslComposeOptions::default(),
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("PI_2 "), content="false")
  debug_inspect(emitted.contains("oklch_to_linear_rgb"), content="true")
}

///|
test "item extraction keeps import directives for selected module slices" {
  let color_source =
    #|#define_import_path test::color
    #|#import test::maths::{PI_2,FRAC_PI_3}
    #|
    #|fn convert_to_linear_rgba(color: vec4<f32>) -> vec4<f32> {
    #|  return color;
    #|}
    #|
  let extracted = extract_wgsl_module_item_origins_strict(color_source, [
    "convert_to_linear_rgba",
  ]) catch {
    error => abort(error.message())
  }
  debug_inspect(extracted.source().contains("#import"), content="true")
  debug_inspect(extracted.source().contains("PI_2"), content="true")
  debug_inspect(extracted.source().contains("FRAC_PI_3"), content="true")
}

///|
test "item slice import request builder prunes unreferenced explicit nested items" {
  let composer = Composer::default()
  let maths_source =
    #|#define_import_path test::maths
    #|const PI: f32 = 3.14159;
    #|const PI_2: f32 = 6.28318;
    #|const FRAC_PI_3: f32 = 1.04719;
    #|fn helper() -> f32 {
    #|  return PI_2;
    #|}
    #|
  composer.register_source("maths.wgsl", maths_source)
  let color_source =
    #|#define_import_path test::color
    #|#import test::maths::{PI_2,FRAC_PI_3,helper}
    #|
    #|fn convert_to_linear_rgba(color: vec4<f32>) -> vec4<f32> {
    #|  return color;
    #|}
    #|
  composer.register_source("color.wgsl", color_source)
  let session = composer.new_wgsl_compose_session(WgslComposeOptions::default())
  let defs = composer.active_compose_defs_for_rel_path(
    "color.wgsl",
    session,
    None,
  )
  let extracted = extract_wgsl_module_item_origins_strict(color_source, [
    "convert_to_linear_rgba",
  ]) catch {
    error => abort(error.message())
  }
  let requests = composer.build_wgsl_import_requests_from_emitted_item_slice(
    "color.wgsl",
    extracted.source(),
    color_source,
    Some(extracted),
    session,
    defs,
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(requests.length(), content="0")
}

///|
test "composer prunes unreferenced nested import declarations from selected item modules" {
  let composer = Composer::default()
  let maths_source =
    #|#define_import_path test::maths
    #|const PI: f32 = 3.14159;
    #|const PI_2: f32 = 6.28318;
    #|const FRAC_PI_3: f32 = 1.04719;
    #|fn helper() -> f32 {
    #|  return PI_2;
    #|}
    #|
  composer.register_source("maths.wgsl", maths_source)
  let color_source =
    #|#define_import_path test::color
    #|#import test::maths::{PI_2,FRAC_PI_3,helper}
    #|
    #|fn convert_to_linear_rgba(color: vec4<f32>) -> vec4<f32> {
    #|  return color;
    #|}
    #|
  composer.register_source("color.wgsl", color_source)
  let root_source =
    #|#import test::color::convert_to_linear_rgba
    #|#import test::maths::PI
    #|
    #|const TAU: f32 = 2.0 * PI;
    #|
    #|@fragment
    #|fn fragment() -> @location(0) vec4<f32> {
    #|  return convert_to_linear_rgba(vec4(1.0));
    #|}
    #|
  composer.register_source("root.wgsl", root_source)
  let emitted = composer.compose_wgsl(
    "root.wgsl",
    WgslComposeOptions::default(),
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("PI_2X_naga_oil_mod"), content="false")
  debug_inspect(emitted.contains("FRAC_PI_3X_naga_oil_mod"), content="false")
  debug_inspect(emitted.contains("fn helperX_naga_oil_mod"), content="false")
}

///|
test "composer does not promote nested function imports with their own import graph" {
  let composer = Composer::default()
  let bindings_source =
    #|#define_import_path test::bindings
    #|
    #|struct Resource {
    #|  value: u32,
    #|}
    #|
    #|@group(0) @binding(0)
    #|var<uniform> resource: Resource;
    #|
  let helpers_source =
    #|#define_import_path test::helpers
    #|#import test::bindings::resource
    #|
    #|fn helper() -> u32 {
    #|  return 1u;
    #|}
    #|
  let selected_source =
    #|#define_import_path test::selected
    #|#import test::helpers::helper
    #|
    #|fn selected() -> u32 {
    #|  return 2u;
    #|}
    #|
  let root_source =
    #|#import test::selected::selected
    #|
    #|fn main() -> u32 {
    #|  return selected();
    #|}
    #|
  composer.register_source("bindings.wgsl", bindings_source)
  composer.register_source("helpers.wgsl", helpers_source)
  composer.register_source("selected.wgsl", selected_source)
  composer.register_source("root.wgsl", root_source)
  let emitted = composer.compose_wgsl_before_ir(
    "root.wgsl",
    WgslComposeOptions::default(),
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("fn helperX_naga_oil_mod"), content="false")
  debug_inspect(emitted.contains("@group(0) @binding(0)"), content="false")
}

///|
test "composer preserves selected item module-level imports before live conflicts" {
  let composer = Composer::default()
  let view_source =
    #|#define_import_path test::view
    #|
    #|struct View {
    #|  exposure: f32,
    #|}
    #|
  let globals_source =
    #|#define_import_path test::globals
    #|
    #|struct Globals {
    #|  time: f32,
    #|}
    #|
  let bindings_source =
    #|#define_import_path test::bindings
    #|#import test::{view::View, globals::Globals}
    #|
    #|@group(0) @binding(0)
    #|var<uniform> globals: Globals;
    #|
  let root_source =
    #|#import test::bindings::globals
    #|
    #|fn main() -> f32 {
    #|  return globals.time;
    #|}
    #|
  composer.register_source("view.wgsl", view_source)
  composer.register_source("globals.wgsl", globals_source)
  composer.register_source("bindings.wgsl", bindings_source)
  composer.register_source("root.wgsl", root_source)
  let emitted = composer.compose_wgsl_before_ir(
    "root.wgsl",
    WgslComposeOptions::default(),
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("ViewX_naga_oil_mod"), content="false")
  debug_inspect(emitted.contains("GlobalsX_naga_oil_mod"), content="true")
  debug_inspect(emitted.contains("test::view::View"), content="false")
}

///|
test "composer preserves selected item full-module import side effects" {
  let composer = Composer::default()
  let prepass_source =
    #|#define_import_path test::prepass
    #|
    #|struct PreviousViewUniforms {
    #|  value: f32,
    #|}
    #|
    #|@group(0) @binding(2)
    #|var<uniform> previous_view_uniforms: PreviousViewUniforms;
    #|
  let transforms_source =
    #|#define_import_path test::transforms
    #|#import test::prepass
    #|
    #|fn position_world_to_clip(value: vec3<f32>) -> vec4<f32> {
    #|  return vec4(value, 1.0);
    #|}
    #|
    #|fn previous_world_to_clip(value: vec3<f32>) -> vec4<f32> {
    #|  return vec4(value, prepass::previous_view_uniforms.value);
    #|}
    #|
  let root_source =
    #|#import test::transforms::position_world_to_clip
    #|
    #|@fragment
    #|fn fragment() -> @location(0) vec4<f32> {
    #|  return position_world_to_clip(vec3(1.0));
    #|}
    #|
  let extracted = extract_wgsl_module_item_origins_strict(transforms_source, [
    "position_world_to_clip",
  ]) catch {
    error => abort(error.message())
  }
  debug_inspect(
    extracted.source().contains("#import test::prepass"),
    content="true",
  )
  composer.register_source("prepass.wgsl", prepass_source)
  composer.register_source("transforms.wgsl", transforms_source)
  composer.register_source("root.wgsl", root_source)
  let emitted = composer.compose_wgsl_before_ir(
    "root.wgsl",
    WgslComposeOptions::default(),
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("PreviousViewUniformsX_naga_oil_mod"),
    content="true",
  )
  debug_inspect(
    emitted.contains("previous_view_uniformsX_naga_oil_mod"),
    content="true",
  )
}

///|
fn compose_test_before(text : String, left : String, right : String) -> Bool {
  let parts : Array[StringView] = text.split(left).collect()
  if parts.length() < 2 {
    return false
  }
  parts[1].contains(right)
}

///|
test "composer emits full-module selected item dependencies before module body" {
  let composer = Composer::default()
  let transforms_source =
    #|#define_import_path test::transforms
    #|
    #|fn position_world_to_clip(value: vec3<f32>) -> vec4<f32> {
    #|  return vec4(value, 1.0);
    #|}
    #|
  let mesh_functions_source =
    #|#define_import_path test::mesh_functions
    #|#import test::{
    #|  transforms::position_world_to_clip
    #|}
    #|
    #|fn get_world_from_local(instance_index: u32) -> mat4x4<f32> {
    #|  return mat4x4<f32>();
    #|}
    #|
    #|fn mesh_position_local_to_world(world_from_local: mat4x4<f32>, vertex_position: vec4<f32>) -> vec4<f32> {
    #|  return world_from_local * vertex_position;
    #|}
    #|
    #|fn mesh_position_local_to_clip(world_from_local: mat4x4<f32>, vertex_position: vec4<f32>) -> vec4<f32> {
    #|  let world_position = mesh_position_local_to_world(world_from_local, vertex_position);
    #|  return position_world_to_clip(world_position.xyz);
    #|}
    #|
  let root_source =
    #|#import test::{mesh_functions, transforms::position_world_to_clip}
    #|
    #|@vertex
    #|fn vertex(@builtin(instance_index) instance_index: u32) -> @builtin(position) vec4<f32> {
    #|  let world_from_local = mesh_functions::get_world_from_local(instance_index);
    #|  let world_position = mesh_functions::mesh_position_local_to_world(world_from_local, vec4(1.0));
    #|  return position_world_to_clip(world_position.xyz);
    #|}
    #|
  composer.register_source("transforms.wgsl", transforms_source)
  composer.register_source("mesh_functions.wgsl", mesh_functions_source)
  composer.register_source("root.wgsl", root_source)
  let emitted = composer.compose_wgsl_before_ir(
    "root.wgsl",
    WgslComposeOptions::default(),
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(
    compose_test_before(
      emitted, "fn position_world_to_clipX_naga_oil_mod", "fn get_world_from_localX_naga_oil_mod",
    ),
    content="true",
  )
}

///|
test "alias selected import reuses already emitted sibling item" {
  let composer = Composer::default()
  composer.clear_sources()
  let dep_source =
    #|#define_import_path test::dep
    #|
    #|fn needed() -> u32 {
    #|  return 1u;
    #|}
    #|
    #|fn other() -> u32 {
    #|  return 2u;
    #|}
    #|
  let selected_source =
    #|#define_import_path test::selected
    #|#import test::dep
    #|
    #|fn selected() -> u32 {
    #|  return dep::needed();
    #|}
    #|
  let root_source =
    #|#import test::{
    #|  dep::needed,
    #|  selected::selected,
    #|  dep::other,
    #|}
    #|
    #|fn main() -> u32 {
    #|  return selected() + other();
    #|}
    #|
  composer.register_source("dep.wgsl", dep_source)
  composer.register_source("selected.wgsl", selected_source)
  composer.register_source("root.wgsl", root_source)
  let emitted = composer.compose_wgsl_before_ir(
    "root.wgsl",
    WgslComposeOptions::default(),
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.split("fn neededX_naga_oil_mod").collect().length(),
    content="2",
  )
  debug_inspect(emitted.contains("fn selectedX_naga_oil_mod"), content="true")
}

///|
test "composer does not retain unused selected-slice helper full-module imports" {
  let composer = Composer::default()
  let helper_source =
    #|#define_import_path test::helper
    #|
    #|fn helper() -> u32 {
    #|  return missing_resource;
    #|}
    #|
  let selected_source =
    #|#define_import_path test::selected
    #|#import test::helper
    #|
    #|fn selected() -> u32 {
    #|  return 1u;
    #|}
    #|
  let root_source =
    #|#import test::selected::selected
    #|
    #|fn main() -> u32 {
    #|  return selected();
    #|}
    #|
  composer.register_source("helper.wgsl", helper_source)
  composer.register_source("selected.wgsl", selected_source)
  composer.register_source("root.wgsl", root_source)
  let emitted = composer.compose_wgsl_before_ir(
    "root.wgsl",
    WgslComposeOptions::default(),
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("fn helperX_naga_oil_mod"), content="false")
  debug_inspect(emitted.contains("missing_resource"), content="false")
}

///|
test "composer preserves unreferenced full-module import after referenced alias import" {
  let composer = Composer::default()
  let base_source =
    #|#define_import_path test
    #|
  let view_source =
    #|#define_import_path test::view
    #|
    #|struct View {
    #|  value: f32,
    #|}
    #|
    #|@group(0) @binding(0)
    #|var<uniform> view: View;
    #|
  let prepass_source =
    #|#define_import_path test::prepass
    #|
    #|struct PreviousViewUniforms {
    #|  value: f32,
    #|}
    #|
    #|@group(0) @binding(2)
    #|var<uniform> previous_view_uniforms: PreviousViewUniforms;
    #|
  let transforms_source =
    #|#define_import_path test::transforms
    #|#import test::view as view_bindings
    #|#import test::prepass
    #|
    #|fn position_world_to_clip(value: vec3<f32>) -> vec4<f32> {
    #|  return vec4(value, view_bindings::view.value);
    #|}
    #|
    #|fn previous_world_to_clip(value: vec3<f32>) -> vec4<f32> {
    #|  return vec4(value, prepass::previous_view_uniforms.value);
    #|}
    #|
  let root_source =
    #|#import test::transforms::position_world_to_clip
    #|
    #|@fragment
    #|fn fragment() -> @location(0) vec4<f32> {
    #|  return position_world_to_clip(vec3(1.0));
    #|}
    #|
  composer.register_source("base.wgsl", base_source)
  composer.register_source("view.wgsl", view_source)
  composer.register_source("prepass.wgsl", prepass_source)
  composer.register_source("transforms.wgsl", transforms_source)
  composer.register_source("root.wgsl", root_source)
  let emitted = composer.compose_wgsl_before_ir(
    "root.wgsl",
    WgslComposeOptions::default(),
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("ViewX_naga_oil_mod"), content="true")
  debug_inspect(
    emitted.contains("PreviousViewUniformsX_naga_oil_mod"),
    content="true",
  )
  debug_inspect(
    emitted.contains("previous_view_uniformsX_naga_oil_mod"),
    content="true",
  )
}

///|
test "composer scans full selected item module for alias type dependencies" {
  let composer = Composer::default()
  let types_source =
    #|#define_import_path test::types
    #|
    #|struct Direct {
    #|  time: f32,
    #|}
    #|
    #|struct UsedBySibling {
    #|  value: u32,
    #|}
    #|
  let bindings_source =
    #|#define_import_path test::bindings
    #|#import test::types as types
    #|
    #|@group(0) @binding(0)
    #|var<uniform> globals: types::Direct;
    #|
    #|@group(0) @binding(1)
    #|var<uniform> sibling: types::UsedBySibling;
    #|
  let root_source =
    #|#import test::bindings::globals
    #|
    #|fn main() -> f32 {
    #|  return globals.time;
    #|}
    #|
  composer.register_source("types.wgsl", types_source)
  composer.register_source("bindings.wgsl", bindings_source)
  composer.register_source("root.wgsl", root_source)
  let emitted = composer.compose_wgsl_before_ir(
    "root.wgsl",
    WgslComposeOptions::default(),
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("DirectX_naga_oil_mod"), content="true")
  debug_inspect(emitted.contains("UsedBySiblingX_naga_oil_mod"), content="true")
  debug_inspect(emitted.contains("siblingX_naga_oil_mod"), content="false")
}

///|
test "composer retains full-module unqualified type dependencies" {
  let composer = Composer::default()
  let config_source =
    #|#define_import_path config
    #|
    #|struct Config {
    #|  width: u32,
    #|}
    #|
    #|const UNUSED_CONFIG_VALUE = 1u;
    #|
  let root_source =
    #|#import config
    #|
    #|@group(0) @binding(0)
    #|var<uniform> config: Config;
    #|
    #|@compute @workgroup_size(1)
    #|fn main() {
    #|  let width = config.width;
    #|}
    #|
  composer.register_source("config.wgsl", config_source)
  composer.register_source("root.wgsl", root_source)
  let emitted = composer.compose_wgsl_before_ir(
    "root.wgsl",
    WgslComposeOptions::default(),
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("struct ConfigX_naga_oil_mod"), content="true")
  debug_inspect(
    emitted.contains("var<uniform> config: ConfigX_naga_oil_mod"),
    content="true",
  )
  debug_inspect(emitted.contains("UNUSED_CONFIG_VALUE"), content="true")
}

///|
test "composer exposes sibling full-module constants to imported function bodies" {
  let composer = Composer::default()
  let drawtag_source =
    #|#define_import_path drawtag
    #|
    #|const DRAWTAG_NOP = 0u;
    #|
  let util_source =
    #|#define_import_path util
    #|
    #|fn read_draw_tag_from_scene(ix: u32) -> u32 {
    #|  if ix == 0u {
    #|    return DRAWTAG_NOP;
    #|  }
    #|  return ix;
    #|}
    #|
  let root_source =
    #|#import drawtag
    #|#import util
    #|
    #|fn main() -> u32 {
    #|  return read_draw_tag_from_scene(1u);
    #|}
    #|
  composer.register_source("drawtag.wgsl", drawtag_source)
  composer.register_source("util.wgsl", util_source)
  composer.register_source("root.wgsl", root_source)
  let emitted = composer.compose_wgsl_before_ir(
    "root.wgsl",
    WgslComposeOptions::default(),
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("DRAWTAG_NOPX_naga_oil_mod"), content="true")
  debug_inspect(
    emitted.contains("return DRAWTAG_NOPX_naga_oil_mod"),
    content="true",
  )
}

///|
test "composer prunes inactive qualified module constants from final output" {
  let composer = Composer::default()
  composer.clear_sources()
  let root_source =
    #|#import test::{
    #|  funcs::use_config,
    #|  types,
    #|}
    #|
    #|fn main() -> u32 {
    #|  return use_config();
    #|}
    #|
  let types_source =
    #|#define_import_path test::types
    #|
    #|struct Config {
    #|  value: u32,
    #|}
    #|
    #|const STANDARD_MATERIAL_FLAGS_DISABLED: u32 = 1u;
    #|
  let funcs_source =
    #|#define_import_path test::funcs
    #|#import test::types as types
    #|
    #|fn use_config() -> u32 {
    #|  var config: types::Config;
    #|#ifdef DISABLED_FEATURE
    #|  config.value = types::STANDARD_MATERIAL_FLAGS_DISABLED;
    #|#endif
    #|  return config.value;
    #|}
    #|
  composer.register_source("root.wgsl", root_source)
  composer.register_source("types.wgsl", types_source)
  composer.register_source("funcs.wgsl", funcs_source)
  let emitted = composer.compose_wgsl_before_ir(
    "root.wgsl",
    WgslComposeOptions::default(),
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("const STANDARD_MATERIAL_FLAGS_DISABLEDX_naga_oil_mod"),
    content="false",
  )
  debug_inspect(
    emitted.contains("types::STANDARD_MATERIAL_FLAGS_DISABLED"),
    content="false",
  )
}

///|
test "composer rewrites imported module-local alias type references" {
  let composer = Composer::default()
  let types_source =
    #|#define_import_path test::types
    #|
    #|struct Lights {
    #|  value: u32,
    #|}
    #|
  let bindings_source =
    #|#define_import_path test::bindings
    #|#import test::types as types
    #|
    #|@group(0) @binding(0)
    #|var<uniform> lights: types::Lights;
    #|
  let root_source =
    #|#import test::bindings::{lights}
    #|
    #|fn main() -> u32 {
    #|  return lights.value;
    #|}
    #|
  composer.register_source("types.wgsl", types_source)
  composer.register_source("bindings.wgsl", bindings_source)
  composer.register_source("root.wgsl", root_source)
  let emitted = composer.compose_wgsl(
    "root.wgsl",
    WgslComposeOptions::default(),
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("types::Lights"), content="false")
  debug_inspect(emitted.contains("LightsX_naga_oil_mod"), content="true")
}

///|
test "composer preserves cached module-local alias bindings per importer" {
  let composer = Composer::default()
  let types_source =
    #|#define_import_path test::types
    #|
    #|struct Lights {
    #|  value: u32,
    #|}
    #|
  let a_source =
    #|#define_import_path test::a
    #|#import test::types as types
    #|
    #|@group(0) @binding(0)
    #|var<uniform> a_lights: types::Lights;
    #|
  let b_source =
    #|#define_import_path test::b
    #|#import test::types as types
    #|
    #|@group(0) @binding(1)
    #|var<uniform> b_lights: types::Lights;
    #|
  let root_source =
    #|#import test::{a::a_lights, b::b_lights}
    #|
    #|fn main() -> u32 {
    #|  return a_lights.value + b_lights.value;
    #|}
    #|
  composer.register_source("types.wgsl", types_source)
  composer.register_source("a.wgsl", a_source)
  composer.register_source("b.wgsl", b_source)
  composer.register_source("root.wgsl", root_source)
  let emitted = composer.compose_wgsl(
    "root.wgsl",
    WgslComposeOptions::default(),
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("types::Lights"), content="false")
  debug_inspect(emitted.contains("a_lights"), content="true")
  debug_inspect(emitted.contains("b_lights"), content="true")
}

///|
test "composer creates alias bindings when canonical module was cached first" {
  let composer = Composer::default()
  let types_source =
    #|#define_import_path test::types
    #|
    #|struct Lights {
    #|  value: u32,
    #|}
    #|
  let bindings_source =
    #|#define_import_path test::bindings
    #|#import test::types as types
    #|
    #|@group(0) @binding(0)
    #|var<uniform> lights: types::Lights;
    #|
  let root_source =
    #|#import test::{
    #|  types,
    #|  bindings::lights,
    #|}
    #|
    #|fn main() -> u32 {
    #|  return lights.value;
    #|}
    #|
  composer.register_source("types.wgsl", types_source)
  composer.register_source("bindings.wgsl", bindings_source)
  composer.register_source("root.wgsl", root_source)
  let emitted = composer.compose_wgsl(
    "root.wgsl",
    WgslComposeOptions::default(),
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("types::Lights"), content="false")
}

///|
test "composer graph planned item supersets cover cached execution subsets" {
  let composer = Composer::default()
  let types_source =
    #|#define_import_path test::types
    #|
    #|struct Atmosphere {
    #|  value: u32,
    #|}
    #|
    #|struct AtmosphereSettings {
    #|  value: u32,
    #|}
    #|
    #|struct AtmosphereTransforms {
    #|  value: u32,
    #|}
    #|
  let view_source =
    #|#define_import_path test::view
    #|
    #|struct View {
    #|  exposure: f32,
    #|}
    #|
  let bindings_source =
    #|#define_import_path test::bindings
    #|#import test::view::View
    #|#import test::types::{Atmosphere, AtmosphereSettings, AtmosphereTransforms}
    #|
    #|@group(0) @binding(0)
    #|var<uniform> settings: AtmosphereSettings;
    #|
    #|@group(0) @binding(1)
    #|var<uniform> view: View;
    #|
  let root_source =
    #|#import test::types::AtmosphereSettings
    #|#import test::bindings::{settings, view}
    #|
    #|fn main() -> f32 {
    #|  return f32(settings.value) + view.exposure;
    #|}
    #|
  composer.register_source("types.wgsl", types_source)
  composer.register_source("view.wgsl", view_source)
  composer.register_source("bindings.wgsl", bindings_source)
  composer.register_source("root.wgsl", root_source)
  let emitted = composer.compose_wgsl(
    "root.wgsl",
    WgslComposeOptions::default(),
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("types::AtmosphereSettings"), content="false")
  debug_inspect(
    emitted.contains("AtmosphereSettingsX_naga_oil_mod"),
    content="true",
  )
}

///|
test "composer orders imports across directives by source references" {
  let composer = Composer::default()
  let late_source =
    #|#define_import_path test::late
    #|
    #|struct Late {
    #|  value: u32,
    #|}
    #|
  let early_source =
    #|#define_import_path test::early
    #|
    #|struct Early {
    #|  value: u32,
    #|}
    #|
  let bindings_source =
    #|#define_import_path test::bindings
    #|#import test::late::Late
    #|#import test::early::Early
    #|
    #|@group(0) @binding(0)
    #|var<uniform> early: Early;
    #|@group(0) @binding(1)
    #|var<uniform> late: Late;
    #|
  let root_source =
    #|#import test::bindings::{early, late}
    #|
    #|fn main() -> u32 {
    #|  return early.value + late.value;
    #|}
    #|
  composer.register_source("late.wgsl", late_source)
  composer.register_source("early.wgsl", early_source)
  composer.register_source("bindings.wgsl", bindings_source)
  composer.register_source("root.wgsl", root_source)
  let emitted = composer.compose_wgsl_before_ir(
    "root.wgsl",
    WgslComposeOptions::default(),
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("struct Early"), content="true")
  debug_inspect(emitted.contains("struct Late"), content="true")
  debug_inspect(
    emitted.split("struct Early").collect()[0].contains("struct Late"),
    content="false",
  )
}

///|
test "composer orders direct item imports by root global type references" {
  let composer = Composer::default()
  let view_source =
    #|#define_import_path test::view
    #|
    #|struct ColorGrading {
    #|  value: f32,
    #|}
    #|
    #|struct View {
    #|  color_grading: ColorGrading,
    #|}
    #|
  let oit_source =
    #|#define_import_path test::mesh_view_types
    #|
    #|struct OitFragmentNode {
    #|  next: u32,
    #|}
    #|
  let root_source =
    #|#import test::view::View
    #|#import test::mesh_view_types::OitFragmentNode
    #|
    #|@group(0) @binding(0)
    #|var<uniform> view: View;
    #|@group(0) @binding(1)
    #|var<storage, read> nodes: array<OitFragmentNode>;
    #|
    #|fn main() -> u32 {
    #|  return nodes[0].next + u32(view.color_grading.value);
    #|}
    #|
  composer.register_source("view.wgsl", view_source)
  composer.register_source("mesh_view_types.wgsl", oit_source)
  composer.register_source("root.wgsl", root_source)
  let emitted = composer.compose_wgsl_before_ir(
    "root.wgsl",
    WgslComposeOptions::default(),
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(
    compose_test_before(
      emitted, "struct ColorGradingX_naga_oil_mod", "struct OitFragmentNodeX_naga_oil_mod",
    ),
    content="true",
  )
  debug_inspect(
    compose_test_before(
      emitted, "struct ViewX_naga_oil_mod", "struct OitFragmentNodeX_naga_oil_mod",
    ),
    content="true",
  )
}

///|
test "composer emits implicit qualified imports before source without import directives" {
  let composer = Composer::default()
  let view_source =
    #|#define_import_path test::view
    #|
    #|struct View {
    #|  value: f32,
    #|}
    #|
  let root_source =
    #|@group(0) @binding(0)
    #|var<uniform> view: test::view::View;
    #|
    #|fn main() -> f32 {
    #|  return view.value;
    #|}
    #|
  composer.register_source("view.wgsl", view_source)
  composer.register_source("root.wgsl", root_source)
  let emitted = composer.compose_wgsl_before_ir(
    "root.wgsl",
    WgslComposeOptions::default(),
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(
    compose_test_before(
      emitted, "struct ViewX_naga_oil_mod", "@group(0) @binding(0)",
    ),
    content="true",
  )
  debug_inspect(emitted.contains("test::view::View"), content="false")
}

///|
test "import request declared-dependency ordering is applied in place" {
  let composer = Composer::default()
  let types_source =
    #|#define_import_path test::types
    #|
    #|struct View {
    #|  value: u32,
    #|}
    #|
  let bindings_source =
    #|#define_import_path test::bindings
    #|#import test::types
    #|
    #|@group(0) @binding(0)
    #|var<uniform> view: test::types::View;
    #|
  composer.register_source("types.wgsl", types_source)
  composer.register_source("bindings.wgsl", bindings_source)
  let session = composer.new_wgsl_compose_session(WgslComposeOptions::default())
  let defs = composer.active_compose_defs_for_rel_path(
    "root.wgsl",
    session,
    None,
  )
  let requests = [
    WgslImportRequest::{
      module_path: "test::bindings",
      rel_path: "bindings.wgsl",
      import_full_module: true,
      keep_requested_items: false,
      requested_items: [],
      declared_items: [],
      alias_name: "",
    },
    {
      module_path: "test::types",
      rel_path: "types.wgsl",
      import_full_module: true,
      keep_requested_items: false,
      requested_items: [],
      declared_items: [],
      alias_name: "types",
    },
  ]
  let ordered = composer.order_wgsl_import_requests_by_declared_dependencies(
    requests, session, defs,
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(ordered[0].rel_path, content="\"types.wgsl\"")
  debug_inspect(requests[0].rel_path, content="\"types.wgsl\"")
  debug_inspect(ordered[1].rel_path, content="\"bindings.wgsl\"")
}

///|
test "composer does not import a missing item shadowed by a local declaration" {
  let composer = Composer::default()
  let maths_source =
    #|#define_import_path test::maths
    #|
    #|const PI_2: f32 = 6.28318;
    #|
  composer.register_source("maths.wgsl", maths_source)
  let color_source =
    #|#define_import_path test::color
    #|#import test::maths::{PI_2}
    #|
    #|fn unrelated_color_path(c: vec3<f32>) -> vec3<f32> {
    #|  let hue = c.z * PI_2;
    #|  return vec3(hue, c.x, c.y);
    #|}
    #|
  composer.register_source("color.wgsl", color_source)
  let root_source =
    #|#import test::color::{
    #|  convert_to_linear_rgba,
    #|}
    #|
    #|fn convert_to_linear_rgba(color: vec4<f32>) -> vec4<f32> {
    #|  return color;
    #|}
    #|
    #|@fragment
    #|fn fragment() -> @location(0) vec4<f32> {
    #|  return convert_to_linear_rgba(vec4(1.0));
    #|}
    #|
  composer.register_source("root.wgsl", root_source)
  let emitted = composer.compose_wgsl(
    "root.wgsl",
    WgslComposeOptions::default(),
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("unrelated_color_path"), content="false")
  debug_inspect(emitted.contains("PI_2X_naga_oil_mod"), content="true")
  debug_inspect(
    emitted.contains("fn convert_to_linear_rgbaX_naga_oil_mod"),
    content="true",
  )
  debug_inspect(
    emitted.contains("= convert_to_linear_rgbaX_naga_oil_mod"),
    content="true",
  )
}

///|
test "composer decorates local declaration that satisfies missing explicit import item" {
  let composer = Composer::default()
  let color_source =
    #|#define_import_path test::color
    #|
    #|fn other(color: vec4<f32>) -> vec4<f32> {
    #|  return color;
    #|}
    #|
  composer.register_source("color.wgsl", color_source)
  let root_source =
    #|#import test::color::convert_to_linear_rgba
    #|
    #|fn convert_to_linear_rgba(color: vec4<f32>) -> vec4<f32> {
    #|  return color;
    #|}
    #|
    #|@fragment
    #|fn fragment(color: vec4<f32>) -> @location(0) vec4<f32> {
    #|  return convert_to_linear_rgba(color);
    #|}
    #|
  composer.register_source("root.wgsl", root_source)
  let emitted = composer.compose_wgsl(
    "root.wgsl",
    WgslComposeOptions::default(),
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("fn convert_to_linear_rgbaX_naga_oil_mod"),
    content="true",
  )
  debug_inspect(
    emitted.contains("= convert_to_linear_rgbaX_naga_oil_mod"),
    content="true",
  )
}

///|
test "direct leaf imports reserve root-visible naga-oil local spelling" {
  let composer = Composer::default()
  composer.clear_sources()
  let root_source =
    #|#import test::bindings::mesh
    #|
    #|struct Out {
    #|  color: f32,
    #|}
    #|
    #|fn read_mesh() -> f32 {
    #|  return mesh.value;
    #|}
    #|
    #|@fragment
    #|fn fragment(mesh: Out) -> @location(0) f32 {
    #|  return 1.0;
    #|}
    #|
  composer.register_source("root.wgsl", root_source)
  let bindings_source =
    #|#define_import_path test::bindings
    #|struct Mesh {
    #|  value: f32,
    #|}
    #|var<private> mesh: Mesh;
    #|
  composer.register_source("bindings.wgsl", bindings_source)
  let emitted = composer.compose_wgsl_for_naga_oil_writer_parity(
    "root.wgsl",
    WgslComposeOptions::default(),
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("var<private> meshX_naga_oil_mod"),
    content="true",
  )
  debug_inspect(
    emitted.contains(
      "var<private> meshX_naga_oil_mod_XORSXG5B2HJRGS3TENFXGO4YX_1",
    ),
    content="true",
  )
  debug_inspect(emitted.contains("fn fragment(mesh: Out"), content="false")
}

///|
test "nested leaf imports feed naga-oil local spelling in imported module" {
  let composer = Composer::default()
  composer.clear_sources()
  let root_source =
    #|#import test::functions::read_global
    #|
    #|@fragment
    #|fn fragment() -> @location(0) f32 {
    #|  return read_global();
    #|}
    #|
  composer.register_source("root.wgsl", root_source)
  let functions_source =
    #|#define_import_path test::functions
    #|#import test::bindings::mesh
    #|
    #|fn read_mesh(mesh: f32) -> f32 {
    #|  return mesh;
    #|}
    #|
    #|fn read_global() -> f32 {
    #|  return read_mesh(mesh);
    #|}
    #|
  composer.register_source("functions.wgsl", functions_source)
  let bindings_source =
    #|#define_import_path test::bindings
    #|var<private> mesh: f32;
    #|
  composer.register_source("bindings.wgsl", bindings_source)
  let emitted = composer.compose_wgsl_for_naga_oil_writer_parity(
    "root.wgsl",
    WgslComposeOptions::default(),
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains(
      "var<private> meshX_naga_oil_mod_XORSXG5B2HJRGS3TENFXGO4YX_1",
    ),
    content="true",
  )
  debug_inspect(
    emitted.contains(
      "fn read_meshX_naga_oil_mod_XORSXG5B2HJTHK3TDORUW63TTX(meshX_naga_oil_mod_XORSXG5B2HJRGS3TENFXGO4YX: f32",
    ),
    content="true",
  )
}

///|
test "generated import local spelling stays scoped to visible module" {
  let composer = Composer::default()
  composer.clear_sources()
  let root_source =
    #|#import test::functions::read_global
    #|#import test::lighting::sample
    #|
    #|@fragment
    #|fn fragment() -> @location(0) f32 {
    #|  return read_global() + sample(1.0);
    #|}
    #|
  composer.register_source("root.wgsl", root_source)
  let functions_source =
    #|#define_import_path test::functions
    #|#import test::bindings::view
    #|
    #|fn read_view(view: f32) -> f32 {
    #|  return view;
    #|}
    #|
    #|fn read_global() -> f32 {
    #|  return read_view(view);
    #|}
    #|
  composer.register_source("functions.wgsl", functions_source)
  let lighting_source =
    #|#define_import_path test::lighting
    #|
    #|fn sample(view: f32) -> f32 {
    #|  return view;
    #|}
    #|
  composer.register_source("lighting.wgsl", lighting_source)
  let bindings_source =
    #|#define_import_path test::bindings
    #|var<private> view: f32;
    #|
  composer.register_source("bindings.wgsl", bindings_source)
  let emitted = composer.compose_wgsl_for_naga_oil_writer_parity(
    "root.wgsl",
    WgslComposeOptions::default(),
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains(
      "fn read_viewX_naga_oil_mod_XORSXG5B2HJTHK3TDORUW63TTX(viewX_naga_oil_mod_XORSXG5B2HJRGS3TENFXGO4YX: f32",
    ),
    content="true",
  )
  debug_inspect(
    emitted.contains("fn sampleX_naga_oil_mod") &&
    emitted.contains("(view: f32) -> f32"),
    content="true",
  )
}

///|
test "selected dependency modules retain alias-qualified resource side effects" {
  let composer = Composer::default()
  composer.clear_sources()
  let bindings_source =
    #|#define_import_path test::bindings
    #|
    #|struct Lights {
    #|  value: f32,
    #|}
    #|
    #|struct ClusteredLights {
    #|  value: f32,
    #|}
    #|
    #|@group(0) @binding(1)
    #|var<uniform> lights: Lights;
    #|
    #|@group(0) @binding(8)
    #|var<storage> clustered_lights: ClusteredLights;
    #|
  let lighting_source =
    #|#define_import_path test::lighting
    #|#import test::bindings as view_bindings
    #|
    #|fn selected() -> f32 {
    #|  return view_bindings::lights.value;
    #|}
    #|
    #|fn unselected_side_effect_reference() -> f32 {
    #|  return view_bindings::clustered_lights.value;
    #|}
    #|
  let root_source =
    #|#import test::lighting::selected
    #|
    #|fn main() -> f32 {
    #|  return selected();
    #|}
    #|
  composer.register_source("bindings.wgsl", bindings_source)
  composer.register_source("lighting.wgsl", lighting_source)
  composer.register_source("root.wgsl", root_source)
  let emitted = composer.compose_wgsl_before_ir(
    "root.wgsl",
    WgslComposeOptions::default(),
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("var<uniform> lightsX_naga_oil_mod"),
    content="true",
  )
  debug_inspect(
    emitted.contains("var<storage> clustered_lightsX_naga_oil_mod"),
    content="true",
  )
  debug_inspect(
    emitted.contains("fn unselected_side_effect_referenceX_naga_oil_mod"),
    content="false",
  )
}

///|
test "alias-qualified resource side effects follow naga-oil writer retention before runtime validation" {
  let composer = Composer::default()
  composer.clear_sources()
  let bindings_source =
    #|#define_import_path collision::bindings
    #|
    #|struct Lights {
    #|  value: f32,
    #|}
    #|
    #|struct ClusteredLights {
    #|  value: f32,
    #|}
    #|
    #|@group(0) @binding(1)
    #|var<uniform> lights: Lights;
    #|
    #|@group(0) @binding(8)
    #|var<storage> clustered_lights: ClusteredLights;
    #|
  let lighting_source =
    #|#define_import_path collision::lighting
    #|#import collision::bindings as view_bindings
    #|
    #|fn selected() -> f32 {
    #|  return view_bindings::lights.value;
    #|}
    #|
    #|fn unselected_side_effect_reference() -> f32 {
    #|  return view_bindings::clustered_lights.value;
    #|}
    #|
  let root_source =
    #|#import collision::lighting::selected
    #|
    #|struct LocalClusteredLights {
    #|  value: f32,
    #|}
    #|
    #|@group(0) @binding(8)
    #|var<storage> local_clustered_lights: LocalClusteredLights;
    #|
    #|fn main() -> f32 {
    #|  return selected() + local_clustered_lights.value;
    #|}
    #|
  composer.register_source("collision_bindings.wgsl", bindings_source)
  composer.register_source("collision_lighting.wgsl", lighting_source)
  composer.register_source("collision_root.wgsl", root_source)
  let emitted = composer.compose_wgsl_before_ir(
    "collision_root.wgsl",
    WgslComposeOptions::default(),
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("var<uniform> lightsX_naga_oil_mod"),
    content="true",
  )
  debug_inspect(
    emitted.contains("var<storage> clustered_lightsX_naga_oil_mod"),
    content="true",
  )
  debug_inspect(
    emitted.contains("var<storage> local_clustered_lights"),
    content="true",
  )
}

///|
test "selected dependency modules retain alias-qualified const side effects" {
  let composer = Composer::default()
  composer.clear_sources()
  let constants_source =
    #|#define_import_path sidefx::constants
    #|
    #|const USED: u32 = 1u;
    #|const SIDE_EFFECT: u32 = 2u;
    #|
  let helpers_source =
    #|#define_import_path sidefx::helpers
    #|#import sidefx::constants as constants
    #|
    #|fn selected() -> u32 {
    #|  return constants::USED;
    #|}
    #|
    #|fn unselected() -> u32 {
    #|  return constants::SIDE_EFFECT;
    #|}
    #|
  let root_source =
    #|#import sidefx::helpers as helpers
    #|
    #|fn main() -> u32 {
    #|  return helpers::selected();
    #|}
    #|
  composer.register_source("sidefx_constants.wgsl", constants_source)
  composer.register_source("sidefx_helpers.wgsl", helpers_source)
  composer.register_source("sidefx_root.wgsl", root_source)
  let emitted = composer.compose_wgsl_before_ir(
    "sidefx_root.wgsl",
    WgslComposeOptions::default(),
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("USEDX_naga_oil_mod"), content="true")
  debug_inspect(emitted.contains("SIDE_EFFECTX_naga_oil_mod"), content="true")
  debug_inspect(
    emitted.contains("fn unselectedX_naga_oil_mod"),
    content="false",
  )
}
