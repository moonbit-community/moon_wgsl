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
  let source =
    #|#import dep::dep_fn
    #|fn root() -> u32 {
    #|  return dep_fn();
    #|}
    #|
  composer.complete_wgsl_compose_graph_execution(
    "root.wgsl",
    source,
    session,
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
  let output = composer.resolve_wgsl_source_with_path(
    "root.wgsl",
    source,
    session,
    None,
    WgslComposeBindingSet(),
    true,
    true,
    [],
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
  let emitted = composer.compose_wgsl(
    "root.wgsl",
    WgslComposeOptions::default(),
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("PI_2 "), content="false")
  debug_inspect(emitted.contains("oklch_to_linear_rgb"), content="true")
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
