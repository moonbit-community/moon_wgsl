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
    WgslSourceOriginEntry("PIX_naga_oil_mod_X", "maths.wgsl", "PI", 0, 0),
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
test "item slice import request builder keeps explicit nested items" {
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
    session,
    defs,
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(requests.length(), content="1")
  debug_inspect(
    requests[0].requested_items.join(","),
    content="\"PI_2,FRAC_PI_3,helper\"",
  )
}

///|
test "composer keeps explicit nested import declarations from selected item modules" {
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
  debug_inspect(emitted.contains("PI_2X_naga_oil_mod"), content="true")
  debug_inspect(emitted.contains("FRAC_PI_3X_naga_oil_mod"), content="true")
  debug_inspect(emitted.contains("fn helperX_naga_oil_mod"), content="true")
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
  debug_inspect(emitted.contains("ViewX_naga_oil_mod"), content="true")
  debug_inspect(emitted.contains("GlobalsX_naga_oil_mod"), content="true")
  debug_inspect(emitted.contains("test::view::View"), content="false")
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
  debug_inspect(emitted.contains("PI_2"), content="false")
}
