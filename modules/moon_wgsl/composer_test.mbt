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
fn empty_bool_defines() -> Map[String, Bool] {
  Map([])
}

///|
let composer_test_registry_ref : @ref.Ref[@compose.Composer] = Ref(
  @compose.Composer::default(),
)

///|
fn clear_composer_test_registry() -> Unit {
  composer_test_registry_ref.val = @compose.Composer::default()
}

///|
fn composer_test_composer() -> @compose.Composer {
  composer_test_registry_ref.val
}

///|
fn composer_test_compose_options(
  defines : Map[String, Bool],
  redirects : Array[@contract.WgslSymbolRedirect],
) -> @contract.WgslComposeOptions {
  {
    defines,
    value_defines: @profile.bevy_wgsl_value_defines(),
    redirects,
    additional_imports: [],
  }
}

///|
fn register_composer_test_shader_source(path : String, source : String) -> Unit {
  composer_test_composer().register_source(path, source)
}

///|
fn register_composer_test_shader_files(
  files : Array[@contract.WgslSourceFile],
) -> Unit {
  composer_test_composer().register_source_files(files)
}

///|
fn registered_composer_test_shader_source(path : String) -> String? {
  composer_test_composer().registered_source(path)
}

///|
fn register_grouped_import_test_shaders() -> Unit {
  clear_composer_test_registry()
  register_composer_test_shader_source(
    "render/color_operations.wgsl",
    (
      #|#define_import_path bevy_render::color_operations
      #|fn rgb_to_hsv(color: vec3<f32>) -> vec3<f32> {
      #|  return color;
      #|}
      #|fn hsv_to_rgb(color: vec3<f32>) -> vec3<f32> {
      #|  return color;
      #|}
      #|
    ),
  )
  register_composer_test_shader_source(
    "render/maths.wgsl",
    (
      #|#define_import_path bevy_render::maths
      #|const PI_2: f32 = 6.28318f;
      #|fn powsafe(value: f32, power: f32) -> f32 {
      #|  return value * power;
      #|}
      #|
    ),
  )
}

///|
fn register_item_import_test_shaders() -> Unit {
  clear_composer_test_registry()
  register_composer_test_shader_source(
    "render/view/view.wgsl",
    (
      #|#define_import_path bevy_render::view
      #|struct View {
      #|  exposure: f32,
      #|}
      #|struct ColorGrading {
      #|  view: View,
      #|}
      #|
    ),
  )
  register_composer_test_shader_source(
    "sprite_render/render/sprite_view_bindings.wgsl",
    (
      #|#define_import_path bevy_sprite::sprite_view_bindings
      #|#import bevy_render::view::ColorGrading
      #|struct SpriteViewBindings {
      #|  grading: ColorGrading,
      #|}
      #|
    ),
  )
  register_composer_test_shader_source(
    "sprite_render/mesh2d/mesh2d_view_bindings.wgsl",
    (
      #|#define_import_path bevy_sprite::mesh2d_view_bindings
      #|#import bevy_render::view::ColorGrading
      #|struct Mesh2dViewBindings {
      #|  grading: ColorGrading,
      #|}
      #|
    ),
  )
}

///|
fn register_mesh_preprocess_branch_test_shaders() -> Unit {
  clear_composer_test_registry()
  register_composer_test_shader_source(
    "render/view/view.wgsl",
    (
      #|#define_import_path bevy_render::view
      #|struct View {
      #|  exposure: f32,
      #|}
      #|
    ),
  )
  register_composer_test_shader_source(
    "pbr/render/mesh_preprocess.wgsl",
    (
      #|#define_import_path bevy_pbr::mesh_preprocess
      #|#ifdef WRITE_INDIRECT_PARAMETERS_METADATA
      #|#ifdef INDIRECT
      #|#ifdef FRUSTUM_CULLING
      #|#import bevy_render::view::View
      #|@group(0) @binding(0) var<uniform> view: View;
      #|#else
      #|#import bevy_render::previous_view::PreviousView
      #|@group(0) @binding(2) var<uniform> previous_view_uniforms: PreviousView;
      #|#endif
      #|#endif
      #|#endif
      #|
    ),
  )
}

///|
fn register_relative_file_import_test_shaders() -> Unit {
  clear_composer_test_registry()
  register_composer_test_shader_files([
    {
      rel_path: "shaders/shared/common.wgsl",
      source: (
        #|struct SharedParams {
        #|  tint: vec4<f32>,
        #|}
        #|struct SharedVertex {
        #|  params: SharedParams,
        #|}
        #|fn build_color(vertex: SharedVertex) -> vec4<f32> {
        #|  return vertex.params.tint;
        #|}
        #|fn unused_helper() -> f32 {
        #|  return 0.0;
        #|}
        #|
      ),
    },
    {
      rel_path: "shaders/effects/main.wgsl",
      source: (
        #|#import "../shared/common.wgsl" SharedVertex, build_color
        #|fn shade(vertex: SharedVertex) -> vec4<f32> {
        #|  return build_color(vertex);
        #|}
        #|
      ),
    },
  ])
}

///|
fn register_redirect_test_shaders() -> Unit {
  clear_composer_test_registry()
  register_composer_test_shader_files([
    {
      rel_path: "shaders/shared/common.wgsl",
      source: (
        #|struct SharedParams {
        #|  tint: vec4<f32>,
        #|}
        #|struct SharedVertex {
        #|  params: SharedParams,
        #|}
        #|fn build_color(vertex: SharedVertex) -> vec4<f32> {
        #|  return vertex.params.tint;
        #|}
        #|fn build_shadow(vertex: SharedVertex) -> vec4<f32> {
        #|  return vec4<f32>(0.0, 0.0, 0.0, 1.0);
        #|}
        #|
      ),
    },
    {
      rel_path: "shaders/effects/redirect.wgsl",
      source: (
        #|#import "../shared/common.wgsl" SharedVertex, build_color, build_shadow
        #|fn shade(vertex: SharedVertex) -> vec4<f32> {
        #|  return build_shadow(vertex);
        #|}
        #|
      ),
    },
  ])
}

///|
fn register_cycle_test_shaders() -> Unit {
  clear_composer_test_registry()
  register_composer_test_shader_source(
    "shaders/cycle/a.wgsl",
    (
      #|#define_import_path demo::a
      #|#import demo::b::b_value
      #|fn a_value() -> f32 {
      #|  return b_value();
      #|}
      #|
    ),
  )
  register_composer_test_shader_source(
    "shaders/cycle/b.wgsl",
    (
      #|#define_import_path demo::b
      #|#import demo::a::a_value
      #|fn b_value() -> f32 {
      #|  return a_value();
      #|}
      #|
    ),
  )
}

///|
fn register_unqualified_import_conflict_test_shaders() -> Unit {
  clear_composer_test_registry()
  register_composer_test_shader_source(
    "shaders/a.wgsl",
    (
      #|#define_import_path demo::a
      #|struct Shared {
      #|  value: u32,
      #|}
      #|
    ),
  )
  register_composer_test_shader_source(
    "shaders/b.wgsl",
    (
      #|#define_import_path demo::b
      #|struct Shared {
      #|  value: u32,
      #|}
      #|
    ),
  )
  register_composer_test_shader_source(
    "shaders/root.wgsl",
    (
      #|#import demo::a::Shared
      #|#import demo::b::Shared
      #|fn entry(value: Shared) -> u32 {
      #|  return value.value;
      #|}
      #|
    ),
  )
}

///|
test "naga_oil: composer preprocess supports multiline grouped imports" {
  register_grouped_import_test_shaders()
  let preprocessed = composer_test_composer().compose_wgsl_source(
    (
      #|#import bevy_render::{
      #|  color_operations::{hsv_to_rgb, rgb_to_hsv},
      #|  maths::{PI_2, powsafe},
      #|}
      #|fn demo(color: vec3<f32>) -> vec3<f32> {
      #|  let h = rgb_to_hsv(color);
      #|  return hsv_to_rgb(vec3<f32>(h.x + PI_2, h.y, powsafe(h.z, 1.0)));
      #|}
      #|
    ),
    composer_test_compose_options(empty_bool_defines(), []),
  ) catch {
    err => abort("expected composer preprocess success: \{err.message()}")
  }
  debug_inspect(preprocessed.contains("fn rgb_to_hsv"), content="true")
  debug_inspect(preprocessed.contains("fn hsv_to_rgb"), content="true")
  debug_inspect(preprocessed.contains("const PI_2"), content="true")
  debug_inspect(preprocessed.contains("bevy_render::"), content="false")
  clear_composer_test_registry()
}

///|
test "naga_oil: composer directives use Unicode whitespace" {
  clear_composer_test_registry()
  register_composer_test_shader_source(
    "shared/inc.wgsl",
    (
      #|#define_import_path demo::inc
      #|fn inc() -> f32 {
      #|  return 1f;
      #|}
      #|
    ),
  )
  let preprocessed = composer_test_composer().compose_wgsl_source(
    "\u{00A0}#import demo::inc::inc\nfn demo() -> f32 {\n  return inc();\n}\n",
    composer_test_compose_options(empty_bool_defines(), []),
  ) catch {
    err =>
      abort(
        "expected Unicode-whitespace import compose success: \{err.message()}",
      )
  }
  debug_inspect(preprocessed.contains("#import"), content="false")
  clear_composer_test_registry()
}

///|
test "naga_oil: composer directives are detected after block comment stripping" {
  clear_composer_test_registry()
  register_composer_test_shader_source(
    "shared/inc.wgsl",
    (
      #|#define_import_path demo::inc
      #|fn inc() -> f32 {
      #|  return 1f;
      #|}
      #|
    ),
  )
  let preprocessed = composer_test_composer().compose_wgsl_source(
    (
      #|/* stripped prefix */#import demo::inc::inc
      #|fn demo() -> f32 {
      #|  return inc();
      #|}
      #|
    ),
    composer_test_compose_options(empty_bool_defines(), []),
  ) catch {
    err =>
      abort(
        "expected comment-stripped import compose success: \{err.message()}",
      )
  }
  debug_inspect(preprocessed.contains("fn inc"), content="true")
  debug_inspect(preprocessed.contains("#import"), content="false")
  debug_inspect(preprocessed.contains("incX_naga_oil_mod_X"), content="true")
  clear_composer_test_registry()
}

///|
test "naga_oil: composer preprocess strips module aliases" {
  register_grouped_import_test_shaders()
  let preprocessed = composer_test_composer().compose_wgsl_source(
    (
      #|#import bevy_render::maths as maths
      #|fn demo() -> f32 {
      #|  return maths::PI_2;
      #|}
      #|
    ),
    composer_test_compose_options(empty_bool_defines(), []),
  ) catch {
    err => abort("expected composer preprocess success: \{err.message()}")
  }
  debug_inspect(preprocessed.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(preprocessed.contains("maths::PI_2"), content="false")
  clear_composer_test_registry()
}

///|
test "naga_oil: commented module alias references do not trigger imports" {
  register_grouped_import_test_shaders()
  let preprocessed = composer_test_composer().compose_wgsl_source(
    (
      #|#import bevy_render::maths as maths
      #|// return maths::PI_2;
      #|fn demo() -> f32 {
      #|  return 1f;
      #|}
      #|
    ),
    composer_test_compose_options(empty_bool_defines(), []),
  ) catch {
    err => abort("expected composer preprocess success: \{err.message()}")
  }
  debug_inspect(preprocessed.contains("const PI_2"), content="false")
  debug_inspect(preprocessed.contains("return 1f;"), content="true")
  clear_composer_test_registry()
}

///|
test "naga_oil: commented namespace paths do not report unresolved imports" {
  let preprocessed = composer_test_composer().compose_wgsl_source(
    (
      #|// unresolved::path should stay a comment
      #|fn demo() -> f32 {
      #|  return 1f;
      #|}
      #|
    ),
    composer_test_compose_options(empty_bool_defines(), []),
  ) catch {
    err =>
      abort("expected commented namespace compose success: \{err.message()}")
  }
  debug_inspect(preprocessed.contains("return 1f;"), content="true")
  clear_composer_test_registry()
}

///|
test "naga_oil: composer item imports keep dependent view declarations" {
  register_item_import_test_shaders()
  let sprite_preprocessed = composer_test_composer().compose_wgsl(
    "sprite_render/render/sprite_view_bindings.wgsl",
    composer_test_compose_options(empty_bool_defines(), []),
  ) catch {
    err =>
      abort("expected sprite composer preprocess success: \{err.message()}")
  }
  debug_inspect(
    sprite_preprocessed.contains("struct ColorGrading"),
    content="true",
  )
  debug_inspect(sprite_preprocessed.contains("struct View"), content="true")

  let mesh2d_preprocessed = composer_test_composer().compose_wgsl(
    "sprite_render/mesh2d/mesh2d_view_bindings.wgsl",
    composer_test_compose_options(empty_bool_defines(), []),
  ) catch {
    err =>
      abort("expected mesh2d composer preprocess success: \{err.message()}")
  }
  debug_inspect(
    mesh2d_preprocessed.contains("struct ColorGrading"),
    content="true",
  )
  debug_inspect(mesh2d_preprocessed.contains("struct View"), content="true")
  clear_composer_test_registry()
}

///|
test "naga_oil: composer drops preprocess previous-view imports outside active branches" {
  register_mesh_preprocess_branch_test_shaders()
  let defines : Map[String, Bool] = Map([])
  defines.set("WRITE_INDIRECT_PARAMETERS_METADATA", true)
  defines.set("INDIRECT", true)
  defines.set("FRUSTUM_CULLING", true)
  let preprocessed = composer_test_composer().compose_wgsl(
    "pbr/render/mesh_preprocess.wgsl",
    composer_test_compose_options(defines, []),
  ) catch {
    err =>
      abort(
        "expected mesh preprocess composer preprocess success: \{err.message()}",
      )
  }
  debug_inspect(preprocessed.contains("view: View"), content="true")
  debug_inspect(
    preprocessed.contains("previous_view_uniforms"),
    content="false",
  )
  debug_inspect(
    preprocessed.contains(
      "@group(0) @binding(2) var<uniform> previous_view_uniforms:",
    ),
    content="false",
  )
  clear_composer_test_registry()
}

///|
test "naga_oil: composer registered sources satisfy strict mesh2d preprocessing" {
  clear_composer_test_registry()
  register_composer_test_shader_source(
    "render/maths.wgsl",
    (
      #|#define_import_path bevy_render::maths
      #|const PI_2: f32 = 6.28318f;
      #|
    ),
  )
  register_composer_test_shader_source(
    "sprite_render/mesh2d/mesh2d_functions.wgsl",
    (
      #|#define_import_path bevy_sprite::mesh2d_functions
      #|#import bevy_render::maths::PI_2
      #|fn twice_pi() -> f32 {
      #|  return PI_2;
      #|}
      #|
    ),
  )
  register_composer_test_shader_source(
    "sprite_render/mesh2d/mesh2d.wgsl",
    (
      #|#import bevy_sprite::mesh2d_functions as mesh_functions
      #|fn demo() -> f32 {
      #|  return mesh_functions::twice_pi();
      #|}
      #|
    ),
  )
  let preprocessed = composer_test_composer().compose_wgsl(
    "sprite_render/mesh2d/mesh2d.wgsl",
    composer_test_compose_options(empty_bool_defines(), []),
  ) catch {
    err =>
      abort("expected registered-source preprocess success: \{err.message()}")
  }
  debug_inspect(preprocessed.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(preprocessed.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(preprocessed.contains("mesh_functions::"), content="false")
  clear_composer_test_registry()
}

///|
test "naga_oil: composer preprocess resolves relative quoted file imports" {
  register_relative_file_import_test_shaders()
  let preprocessed = composer_test_composer().compose_wgsl(
    "shaders/effects/main.wgsl",
    composer_test_compose_options(empty_bool_defines(), []),
  ) catch {
    err =>
      abort(
        "expected relative file import preprocess success: \{err.message()}",
      )
  }
  debug_inspect(preprocessed.contains("struct SharedParams"), content="true")
  debug_inspect(preprocessed.contains("struct SharedVertex"), content="true")
  debug_inspect(preprocessed.contains("fn build_color"), content="true")
  debug_inspect(preprocessed.contains("fn shade"), content="true")
  debug_inspect(preprocessed.contains("#import"), content="false")
  clear_composer_test_registry()
}

///|
test "naga_oil: composer default is isolated from test registry state" {
  clear_composer_test_registry()
  register_composer_test_shader_source(
    "shaders/demo/global.wgsl",
    (
      #|#define_import_path demo::global
      #|fn global_value() -> f32 {
      #|  return 1f;
      #|}
      #|
    ),
  )
  debug_inspect(
    @compose.Composer::default().registered_source("shaders/demo/global.wgsl"),
    content="None",
  )
  debug_inspect(
    composer_test_composer().registered_source("shaders/demo/global.wgsl"),
    content="Some(\"#define_import_path demo::global\\nfn global_value() -> f32 {\\n  return 1f;\\n}\\n\")",
  )
  clear_composer_test_registry()
}

///|
test "naga_oil: composer instances stay isolated from later test registry resets" {
  clear_composer_test_registry()
  register_composer_test_shader_source(
    "shaders/demo/snap_a.wgsl",
    (
      #|#define_import_path demo::snap_a
      #|fn snap_a() -> f32 {
      #|  return 1f;
      #|}
      #|
    ),
  )
  let composer = composer_test_composer()
  clear_composer_test_registry()
  register_composer_test_shader_source(
    "shaders/demo/snap_b.wgsl",
    (
      #|#define_import_path demo::snap_b
      #|fn snap_b() -> f32 {
      #|  return 2f;
      #|}
      #|
    ),
  )
  debug_inspect(
    composer.registered_source("shaders/demo/snap_a.wgsl") is Some(_),
    content="true",
  )
  debug_inspect(
    composer.registered_source("shaders/demo/snap_b.wgsl"),
    content="None",
  )
  let preprocessed = composer.compose_wgsl(
    "shaders/demo/snap_a.wgsl",
    composer_test_compose_options(empty_bool_defines(), []),
  ) catch {
    err => abort("expected snapshot-backed compose success: \{err.message()}")
  }
  debug_inspect(preprocessed.contains("fn snap_a"), content="true")
  debug_inspect(preprocessed.contains("fn snap_b"), content="false")
  clear_composer_test_registry()
}

///|
test "naga_oil: composer local registry can compose without test registry state" {
  clear_composer_test_registry()
  let composer = @compose.Composer::default()
  composer.clear_sources()
  composer.register_source_files([
    {
      rel_path: "shaders/shared/common.wgsl",
      source: (
        #|struct SharedParams {
        #|  tint: vec4<f32>,
        #|}
        #|struct SharedVertex {
        #|  params: SharedParams,
        #|}
        #|fn build_color(vertex: SharedVertex) -> vec4<f32> {
        #|  return vertex.params.tint;
        #|}
        #|
      ),
    },
    {
      rel_path: "shaders/effects/main.wgsl",
      source: (
        #|#import "../shared/common.wgsl" SharedVertex, build_color
        #|fn shade(vertex: SharedVertex) -> vec4<f32> {
        #|  return build_color(vertex);
        #|}
        #|
      ),
    },
  ])
  let preprocessed = composer.compose_wgsl("shaders/effects/main.wgsl", {
    defines: empty_bool_defines(),
    value_defines: @profile.bevy_wgsl_value_defines(),
    redirects: [],
    additional_imports: [],
  }) catch {
    err =>
      abort(
        "expected composer-local registry preprocess success: \{err.message()}",
      )
  }
  debug_inspect(
    registered_composer_test_shader_source("shaders/effects/main.wgsl"),
    content="None",
  )
  debug_inspect(preprocessed.contains("struct SharedVertex"), content="true")
  debug_inspect(preprocessed.contains("fn build_color"), content="true")
  debug_inspect(preprocessed.contains("fn shade"), content="true")
}

///|
test "issue 5: template constants handle non-BMP source text" {
  let value_defines = @profile.bevy_wgsl_value_defines()
  value_defines.set("CUSTOM_LIMIT", Int(42))
  let preprocessed = @compose.Composer::default().compose_wgsl_source(
    (
      #|// 😀 before a braced template const
      #|const A: u32 = #{CUSTOM_LIMIT}u;
      #|// 😃 before a bare template const
      #|const B: u32 = #CUSTOM_LIMITu;
      #|
    ),
    {
      defines: empty_bool_defines(),
      value_defines,
      redirects: [],
      additional_imports: [],
    },
  ) catch {
    err => abort("expected non-BMP template compose success: \{err.message()}")
  }
  debug_inspect(preprocessed.contains("const A: u32 = 42u;"), content="true")
  debug_inspect(preprocessed.contains("const B: u32 = 42u;"), content="true")
}

///|
test "template constants preserve large unsigned shader-def values" {
  let value_defines = @profile.bevy_wgsl_value_defines()
  value_defines.set("LARGE_COUNT", UInt(3221225472U))
  let preprocessed = @compose.Composer::default().compose_wgsl_source(
    (
      #|const A: u32 = #LARGE_COUNTu;
      #|const B: u32 = #{LARGE_COUNT}u;
      #|
    ),
    {
      defines: empty_bool_defines(),
      value_defines,
      redirects: [],
      additional_imports: [],
    },
  ) catch {
    err =>
      abort(
        "expected large unsigned template compose success: \{err.message()}",
      )
  }
  debug_inspect(
    preprocessed.contains("const A: u32 = 3221225472u;"),
    content="true",
  )
  debug_inspect(
    preprocessed.contains("const B: u32 = 3221225472u;"),
    content="true",
  )
  debug_inspect(preprocessed.contains("-1073741824"), content="false")
}

///|
test "template constants support raw double-hash WGSL token placeholders" {
  let value_defines = @profile.bevy_wgsl_value_defines()
  value_defines.set("TEXTURE_FORMAT", Raw("rgba8unorm"))
  let preprocessed = @compose.Composer::default().compose_wgsl_source(
    (
      #|@group(0) @binding(0) var out_tex: texture_storage_2d<##TEXTURE_FORMAT##, write>;
      #|
    ),
    {
      defines: empty_bool_defines(),
      value_defines,
      redirects: [],
      additional_imports: [],
    },
  ) catch {
    err =>
      abort("expected raw template token compose success: \{err.message()}")
  }
  debug_inspect(
    preprocessed.contains("texture_storage_2d<rgba8unorm, write>"),
    content="true",
  )
  debug_inspect(preprocessed.contains("##"), content="false")
}

///|
test "naga_oil: add_composable_module feeds the composer compose path" {
  clear_composer_test_registry()
  let composer = @compose.Composer::default()
  composer.clear_sources()
  ignore(
    composer.add_composable_module({
      source: (
        #|#define_import_path demo::maths
        #|const PI_2: f32 = 6.28318f;
        #|
      ),
      file_path: "shaders/demo/maths.wgsl",
      as_name: None,
      additional_imports: [],
      shader_defs: Map([]),
    }),
  ) catch {
    err => abort("expected maths module registration success: \{err.message()}")
  }
  ignore(
    composer.add_composable_module({
      source: (
        #|#define_import_path demo::main
        #|#import demo::maths::PI_2
        #|fn demo() -> f32 {
        #|  return PI_2;
        #|}
        #|
      ),
      file_path: "shaders/demo/main.wgsl",
      as_name: None,
      additional_imports: [],
      shader_defs: Map([]),
    }),
  ) catch {
    err => abort("expected main module registration success: \{err.message()}")
  }
  let preprocessed = composer.compose_wgsl("shaders/demo/main.wgsl", {
    defines: empty_bool_defines(),
    value_defines: @profile.bevy_wgsl_value_defines(),
    redirects: [],
    additional_imports: [],
  }) catch {
    err =>
      abort(
        "expected composable-module-backed preprocess success: \{err.message()}",
      )
  }
  debug_inspect(preprocessed.contains("const PI_2"), content="true")
  debug_inspect(preprocessed.contains("fn demo"), content="true")
  debug_inspect(preprocessed.contains("PI_2X_naga_oil_mod_X"), content="true")
}

///|
test "naga_oil: composer accepts whitespace after hash import directives" {
  clear_composer_test_registry()
  let composer = @compose.Composer::default()
  composer.clear_sources()
  ignore(
    composer.add_composable_module({
      source: (
        #|# define_import_path demo::maths
        #|const PI_2: f32 = 6.28318f;
        #|
      ),
      file_path: "shaders/demo/maths.wgsl",
      as_name: None,
      additional_imports: [],
      shader_defs: Map([]),
    }),
  ) catch {
    err => abort("expected maths module registration success: \{err.message()}")
  }
  ignore(
    composer.add_composable_module({
      source: (
        #|# define_import_path demo::main
        #|# import demo::maths::PI_2
        #|fn demo() -> f32 {
        #|  return PI_2;
        #|}
        #|
      ),
      file_path: "shaders/demo/main.wgsl",
      as_name: None,
      additional_imports: [],
      shader_defs: Map([]),
    }),
  ) catch {
    err => abort("expected main module registration success: \{err.message()}")
  }
  let preprocessed = composer.compose_wgsl("shaders/demo/main.wgsl", {
    defines: empty_bool_defines(),
    value_defines: @profile.bevy_wgsl_value_defines(),
    redirects: [],
    additional_imports: [],
  }) catch {
    err => abort("expected spaced-directive compose success: \{err.message()}")
  }
  debug_inspect(preprocessed.contains("const PI_2"), content="true")
  debug_inspect(preprocessed.contains("# import"), content="false")
  debug_inspect(preprocessed.contains("PI_2X_naga_oil_mod_X"), content="true")
}

///|
test "naga_oil: composer directive dispatch requires upstream tail whitespace" {
  let output = @compose.Composer::default().compose_wgsl_source(
    (
      #|#define
      #|#import
      #|#define_import_path
      #|fn shade() {}
      #|
    ),
    composer_test_compose_options(empty_bool_defines(), []),
  ) catch {
    err =>
      abort(
        "expected keyword-only compose source preservation: \{err.message()}",
      )
  }
  debug_inspect(output.contains("fn shade"), content="true")
}

///|
test "naga_oil: composer reports invalid active import specs" {
  ignore(
    @compose.Composer::default().compose_wgsl_source(
      (
        #|#import @
        #|fn shade() {}
        #|
      ),
      composer_test_compose_options(empty_bool_defines(), []),
    ),
  ) catch {
    err => {
      debug_inspect(
        err.message(),
        content="\"failed to resolve shader import: unexpected token\"",
      )
      return
    }
  }
  abort("expected invalid import spec compose failure")
}

///|
test "naga_oil: composer accepts empty final-semicolon imports" {
  let output = @compose.Composer::default().compose_wgsl_source(
    (
      #|#import ;
      #|fn shade() {}
      #|
    ),
    composer_test_compose_options(empty_bool_defines(), []),
  ) catch {
    err => abort("expected empty import compose success: \{err.message()}")
  }
  debug_inspect(output.contains("#import"), content="false")
  debug_inspect(output.contains("fn shade"), content="true")
}

///|
test "naga_oil: add_composable_module applies descriptor additional imports" {
  clear_composer_test_registry()
  let composer = @compose.Composer::default()
  composer.clear_sources()
  ignore(
    composer.add_composable_module({
      source: (
        #|#define_import_path plugin
        #|fn external_scale() -> f32 {
        #|  return 2f;
        #|}
        #|
      ),
      file_path: "shaders/demo/plugin.wgsl",
      as_name: None,
      additional_imports: [],
      shader_defs: Map([]),
    }),
  ) catch {
    err =>
      abort("expected plugin module registration success: \{err.message()}")
  }
  ignore(
    composer.add_composable_module({
      source: (
        #|#define_import_path demo::main
        #|fn demo() -> f32 {
        #|  return plugin::external_scale();
        #|}
        #|
      ),
      file_path: "shaders/demo/main.wgsl",
      as_name: None,
      additional_imports: [{ import_path: "plugin", items: [] }],
      shader_defs: Map([]),
    }),
  ) catch {
    err => abort("expected main module registration success: \{err.message()}")
  }
  let preprocessed = composer.compose_wgsl("shaders/demo/main.wgsl", {
    defines: empty_bool_defines(),
    value_defines: @profile.bevy_wgsl_value_defines(),
    redirects: [],
    additional_imports: [],
  }) catch {
    err =>
      abort(
        "expected additional-import-backed preprocess success: \{err.message()}",
      )
  }
  debug_inspect(preprocessed.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(preprocessed.contains("X_naga_oil_mod_X"), content="true")
}

///|
test "naga_oil: composer preprocess can apply AST-scoped symbol redirects" {
  register_redirect_test_shaders()
  let preprocessed = composer_test_composer().compose_wgsl(
    "shaders/effects/redirect.wgsl",
    composer_test_compose_options(empty_bool_defines(), [
      { from_name: "build_shadow", to_name: "build_color" },
    ]),
  ) catch {
    err =>
      abort(
        "expected redirect-aware composer preprocess success: \{err.message()}",
      )
  }
  debug_inspect(preprocessed.contains("build_color"), content="true")
  debug_inspect(
    preprocessed.contains("return build_shadow(vertex);"),
    content="false",
  )
  debug_inspect(preprocessed.contains("fn build_color"), content="true")
  debug_inspect(preprocessed.contains("fn build_shadow"), content="false")
  clear_composer_test_registry()
}

///|
test "naga_oil: aliased module rewrite preserves function parameter locals" {
  clear_composer_test_registry()
  let module_source =
    #|#define_import_path bevy_pbr::mesh
    #|struct VertexInput {
    #|  instance_index: u32,
    #|}
    #|fn read_instance(in: VertexInput) -> u32 {
    #|  return in.instance_index;
    #|}
    #|
  let root_source =
    #|#import bevy_pbr::mesh as mesh
    #|fn use_mesh(input: mesh::VertexInput) -> u32 {
    #|  return mesh::read_instance(input);
    #|}
    #|
  register_composer_test_shader_source("bevy/pbr/mesh.wgsl", module_source)
  register_composer_test_shader_source(
    "root/aliased_parameter.wgsl", root_source,
  )
  let preprocessed = composer_test_composer().compose_wgsl(
    "root/aliased_parameter.wgsl",
    composer_test_compose_options(empty_bool_defines(), []),
  ) catch {
    err =>
      abort(
        "expected aliased module parameter compose success: \{err.message()}",
      )
  }
  debug_inspect(preprocessed.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(
    preprocessed.contains("return in.instance_index;"),
    content="true",
  )
  debug_inspect(
    preprocessed.contains("return in_wgsl.instance_index;"),
    content="false",
  )
  debug_inspect(preprocessed.contains("mesh__in"), content="false")
  clear_composer_test_registry()
}

///|
test "naga_oil: virtual override base detection ignores local shadows" {
  clear_composer_test_registry()
  let composer = composer_test_composer()
  composer.register_source(
    "mod.wgsl",
    (
      #|#define_import_path mod
      #|virtual fn inner() -> f32 {
      #|  return 1f;
      #|}
      #|
    ),
  )
  composer.register_source(
    "top.wgsl",
    (
      #|#import mod
      #|override fn mod::inner() -> f32 {
      #|  let mod__inner = 2f;
      #|  return mod__inner;
      #|}
      #|fn top() -> f32 {
      #|  return mod::inner();
      #|}
      #|
    ),
  )
  let source = composer.compose_wgsl(
    "top.wgsl",
    composer_test_compose_options(empty_bool_defines(), []),
  ) catch {
    err =>
      abort("expected local-shadow virtual override success: \{err.message()}")
  }
  debug_inspect(source.contains("fn mod__inner__virtual_base"), content="false")
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  clear_composer_test_registry()
}

///|
test "naga_oil: virtual override base detection respects statement order" {
  clear_composer_test_registry()
  let composer = composer_test_composer()
  composer.register_source(
    "mod.wgsl",
    (
      #|#define_import_path mod
      #|virtual fn inner() -> f32 {
      #|  return 1f;
      #|}
      #|
    ),
  )
  composer.register_source(
    "top.wgsl",
    (
      #|#import mod
      #|override fn mod::inner() -> f32 {
      #|  let value = mod::inner();
      #|  let mod__inner = 2f;
      #|  return value + mod__inner;
      #|}
      #|fn top() -> f32 {
      #|  return mod::inner();
      #|}
      #|
    ),
  )
  let source = composer.compose_wgsl(
    "top.wgsl",
    composer_test_compose_options(empty_bool_defines(), []),
  ) catch {
    err =>
      abort(
        "expected ordered local-shadow virtual override success: \{err.message()}",
      )
  }
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  clear_composer_test_registry()
}

///|
test "naga_oil: transitive override keeps virtual module side effects" {
  clear_composer_test_registry()
  let composer = composer_test_composer()
  composer.register_source(
    "mod.wgsl",
    (
      #|#define_import_path mod
      #|virtual fn inner() -> f32 {
      #|  return 1f;
      #|}
      #|fn outer() -> f32 {
      #|  return inner();
      #|}
      #|
    ),
  )
  composer.register_source(
    "middle.wgsl",
    (
      #|#define_import_path middle
      #|#import mod
      #|override fn mod::inner() -> f32 {
      #|  return 2f;
      #|}
      #|
    ),
  )
  composer.register_source(
    "top.wgsl",
    (
      #|#import middle
      #|#import mod
      #|fn top() -> f32 {
      #|  return mod::outer();
      #|}
      #|
    ),
  )
  let source = composer.compose_wgsl(
    "top.wgsl",
    composer_test_compose_options(empty_bool_defines(), []),
  ) catch {
    err =>
      abort("expected transitive virtual override success: \{err.message()}")
  }
  debug_inspect(source.contains("virtual fn"), content="false")
  debug_inspect(source.contains("override fn"), content="false")
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(source.contains("return 2f;"), content="true")
  debug_inspect(source.contains("return 1f;"), content="true")
  debug_inspect(source.contains("X_naga_oil_vrt_X"), content="true")
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  clear_composer_test_registry()
}

///|
test "github issue 5: unicode source lines do not abort prefix checks" {
  let source =
    #|// 中文注释会让旧 starts_with_text 切到非法边界
    #|#ifdef ENABLED
    #|const enabled_value: u32 = 1u;
    #|#endif
    #|fn main() -> u32 {
    #|  return 0u;
    #|}
    #|
  let preprocessed = composer_test_composer().compose_wgsl_source(
    source,
    composer_test_compose_options(empty_bool_defines(), []),
  ) catch {
    err => abort("expected unicode-safe compose success: \{err.message()}")
  }
  debug_inspect(preprocessed.contains("fn main"), content="true")
  debug_inspect(preprocessed.contains("enabled_value"), content="false")
}

///|
test "naga_oil: composer reports missing shader def in if comparison" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "missing_if.wgsl",
    (
      #|#if TEXTURE == 3
      #|const active: u32 = 1u;
      #|#endif
      #|
    ),
  )
  ignore(
    composer.compose_wgsl(
      "missing_if.wgsl",
      composer_test_compose_options(empty_bool_defines(), []),
    ),
  ) catch {
    err => {
      debug_inspect(
        err.message().contains("unknown shader def: TEXTURE"),
        content="true",
      )
      return
    }
  }
  abort("expected missing shader-def compose failure")
}

///|
test "naga_oil: composer rejects unsigned-suffix if comparison values" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "invalid_uint_if.wgsl",
    (
      #|#if COUNT == 1u
      #|const active: u32 = 1u;
      #|#endif
      #|
    ),
  )
  let options = composer_test_compose_options(empty_bool_defines(), [])
  options.value_defines.set("COUNT", Int(1))
  ignore(composer.compose_wgsl("invalid_uint_if.wgsl", options)) catch {
    err => {
      debug_inspect(
        err.message().contains("invalid shader def comparison value"),
        content="true",
      )
      debug_inspect(err.message().contains("COUNT"), content="true")
      debug_inspect(err.message().contains("1u"), content="true")
      return
    }
  }
  abort("expected invalid uint-suffix compose failure")
}

///|
test "naga_oil: composer reports unknown shader def operator" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "bad_operator_if.wgsl",
    (
      #|#if TEXTURE !! true
      #|const active: u32 = 1u;
      #|#endif
      #|
    ),
  )
  let defines = empty_bool_defines()
  defines.set("TEXTURE", true)
  ignore(
    composer.compose_wgsl(
      "bad_operator_if.wgsl",
      composer_test_compose_options(defines, []),
    ),
  ) catch {
    err => {
      debug_inspect(
        err.message().contains("unknown shader def operator: !!"),
        content="true",
      )
      return
    }
  }
  abort("expected unknown operator compose failure")
}

///|
test "naga_oil: composer reports malformed shader-def scopes" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "too_many.wgsl",
    (
      #|#endif
      #|
    ),
  )
  ignore(
    composer.compose_wgsl(
      "too_many.wgsl",
      composer_test_compose_options(empty_bool_defines(), []),
    ),
  ) catch {
    err =>
      debug_inspect(err.message().contains("too many #endif"), content="true")
  }
  composer.register_source(
    "not_enough.wgsl",
    (
      #|#ifdef ENABLED
      #|const a: u32 = 1u;
      #|
    ),
  )
  ignore(
    composer.compose_wgsl(
      "not_enough.wgsl",
      composer_test_compose_options(empty_bool_defines(), []),
    ),
  ) catch {
    err => {
      debug_inspect(err.message().contains("not enough #endif"), content="true")
      return
    }
  }
  abort("expected not-enough-endif compose failure")
}

///|
test "naga_oil: composer reports else without condition" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "else_without.wgsl",
    (
      #|#else
      #|const a: u32 = 1u;
      #|
    ),
  )
  ignore(
    composer.compose_wgsl(
      "else_without.wgsl",
      composer_test_compose_options(empty_bool_defines(), []),
    ),
  ) catch {
    err => {
      debug_inspect(
        err.message().contains("#else without condition"),
        content="true",
      )
      return
    }
  }
  abort("expected else-without-condition compose failure")
}

///|
test "naga_oil: composer applies root-local shader defines" {
  let composer = @compose.Composer::default()
  let source =
    #|#define NOW_DEFINED
    #|#define MODE 2
    #|#ifdef NOW_DEFINED
    #|const enabled: u32 = #MODE;
    #|#endif
    #|#if MODE == 2
    #|const selected: u32 = #MODE;
    #|#else
    #|const selected: u32 = 0u;
    #|#endif
    #|
  let preprocessed = composer.compose_wgsl_source(
    source,
    composer_test_compose_options(empty_bool_defines(), []),
  ) catch {
    err => abort("expected root-local define compose success: \{err.message()}")
  }
  debug_inspect(
    preprocessed.contains("const enabled: u32 = 2u;"),
    content="true",
  )
  debug_inspect(
    preprocessed.contains("const selected: u32 = 2u;"),
    content="true",
  )
  debug_inspect(
    preprocessed.contains("const selected: u32 = 0u;"),
    content="false",
  )
}

///|
test "naga_oil: composer reports import cycles explicitly" {
  register_cycle_test_shaders()
  let mut message : String? = None
  ignore(
    composer_test_composer().compose_wgsl(
      "shaders/cycle/a.wgsl",
      composer_test_compose_options(empty_bool_defines(), []),
    ),
  ) catch {
    err => message = Some(err.message())
  }
  debug_inspect(
    message,
    content="Some(\"shader import cycle detected: shaders/cycle/a.wgsl -> shaders/cycle/b.wgsl -> shaders/cycle/a.wgsl\")",
  )
  clear_composer_test_registry()
}

///|
test "naga_oil: composer rejects unqualified import binding ambiguity" {
  register_unqualified_import_conflict_test_shaders()
  let mut message : String? = None
  ignore(
    composer_test_composer().compose_wgsl(
      "shaders/root.wgsl",
      composer_test_compose_options(empty_bool_defines(), []),
    ),
  ) catch {
    err => message = Some(err.message())
  }
  guard message is Some(text) else {
    abort("expected ambiguous unqualified import binding failure")
  }
  debug_inspect(
    text.contains("ambiguous shader import binding"),
    content="true",
  )
  debug_inspect(text.contains("Shared"), content="true")
  debug_inspect(text.contains("shaders/a.wgsl"), content="true")
  debug_inspect(text.contains("shaders/b.wgsl"), content="true")
  clear_composer_test_registry()
}

///|
test "naga_oil: source catalog uses per-module strict shader defs" {
  let composer = @compose.Composer::default()
  composer.clear_sources()
  let module_defs : Map[String, @contract.ShaderDefValue] = Map([])
  module_defs.set("MODULE_FLAG", Bool(false))
  ignore(
    composer.add_composable_module({
      source: (
        #|#define_import_path catalog::module
        #|#ifdef MODULE_FLAG
        #|fn from_if() -> f32 {
        #|  return 1f;
        #|}
        #|#else
        #|fn from_else() -> f32 {
        #|  return 2f;
        #|}
        #|#endif
        #|
      ),
      file_path: "shaders/catalog/module.wgsl",
      as_name: None,
      additional_imports: [],
      shader_defs: module_defs,
    }),
  ) catch {
    err => abort("expected module registration success: \{err.message()}")
  }
  composer.register_source(
    "shaders/catalog/root.wgsl",
    (
      #|#import catalog::module::from_if
      #|fn shade() -> f32 {
      #|  return from_if();
      #|}
      #|
    ),
  )
  let prepared = composer.prepare_wgsl_source(
    "shaders/catalog/root.wgsl",
    composer_test_compose_options(empty_bool_defines(), []),
  ) catch {
    err => abort("expected prepared source success: \{err.message()}")
  }
  debug_inspect(prepared.source.contains("fn from_if"), content="true")
  debug_inspect(prepared.source.contains("fn from_else"), content="false")
  let module_catalog_names : Array[String] = []
  for entry in prepared.source_catalog {
    if entry.rel_path == "shaders/catalog/root.wgsl" {
      module_catalog_names.push(entry.symbol_name)
    }
  }
  module_catalog_names.sort()
  debug_inspect(
    module_catalog_names.join(",").contains("from_ifX_naga_oil_mod_X"),
    content="true",
  )
}

///|
test "naga_oil: composable modules reject local define directives" {
  let composer = @compose.Composer::default()
  ignore(
    composer.add_composable_module({
      source: (
        #|#define_import_path bad::module
        #|#define LOCAL_FLAG
        #|fn value() -> f32 {
        #|  return 1f;
        #|}
        #|
      ),
      file_path: "shaders/bad/module.wgsl",
      as_name: None,
      additional_imports: [],
      shader_defs: Map([]),
    }),
  ) catch {
    err => {
      debug_inspect(
        err.message(),
        content="\"shader module cannot contain #define directives\"",
      )
      return
    }
  }
  abort("expected composable module #define rejection")
}

///|
test "naga_oil: composer reports invalid WGSL directive as directive error" {
  let composer = @compose.Composer::default()
  ignore(
    composer.compose_wgsl_source(
      (
        #|diagnostic(note, derivative_uniformity);
        #|fn shade() {}
        #|
      ),
      composer_test_compose_options(empty_bool_defines(), []),
    ),
  ) catch {
    err => {
      debug_inspect(
        err.message().contains("invalid WGSL directive:"),
        content="true",
      )
      debug_inspect(
        err.message().contains("Invalid severity 'note'"),
        content="true",
      )
      return
    }
  }
  abort("expected invalid WGSL directive compose failure")
}

///|
test "naga_oil: composer reports invalid GLSL version as version error" {
  let composer = @compose.Composer::default()
  ignore(
    composer.compose_wgsl_source(
      (
        #|#version 430
        #|fn shade() -> f32 { return 1f; }
        #|
      ),
      composer_test_compose_options(empty_bool_defines(), []),
    ),
  ) catch {
    err => {
      debug_inspect(
        err.message(),
        content="\"invalid GLSL #version directive\"",
      )
      return
    }
  }
  abort("expected invalid GLSL version compose failure")
}

///|
test "naga_oil: composer strips accepted GLSL version directive" {
  let output = @compose.Composer::default().compose_wgsl_source(
    (
      #|#version 450
      #|fn shade() -> f32 { return 1f; }
      #|
    ),
    composer_test_compose_options(empty_bool_defines(), []),
  ) catch {
    err => abort("expected GLSL version compose success: \{err.message()}")
  }
  debug_inspect(output.contains("#version"), content="false")
  debug_inspect(output.contains("fn shade()"), content="true")
}

///|
test "naga_oil: item imports reject invalid GLSL version before extraction" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "shaders/version/module.wgsl",
    (
      #|#define_import_path version::module
      #|#version 430
      #|fn value() -> f32 { return 1f; }
      #|
    ),
  )
  composer.register_source(
    "shaders/version/root.wgsl",
    (
      #|#import version::module::value
      #|fn shade() -> f32 { return value(); }
      #|
    ),
  )
  ignore(
    composer.compose_wgsl(
      "shaders/version/root.wgsl",
      composer_test_compose_options(empty_bool_defines(), []),
    ),
  ) catch {
    err => {
      debug_inspect(
        err.message(),
        content="\"invalid GLSL #version directive\"",
      )
      return
    }
  }
  abort("expected invalid GLSL version item-import compose failure")
}

///|
test "naga_oil: item imports strip accepted GLSL version before extraction" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "shaders/version/module.wgsl",
    (
      #|#define_import_path version::module
      #|#version 450
      #|fn value() -> f32 { return 1f; }
      #|
    ),
  )
  composer.register_source(
    "shaders/version/root.wgsl",
    (
      #|#import version::module::value
      #|fn shade() -> f32 { return value(); }
      #|
    ),
  )
  let output = composer.compose_wgsl(
    "shaders/version/root.wgsl",
    composer_test_compose_options(empty_bool_defines(), []),
  ) catch {
    err =>
      abort(
        "expected accepted GLSL version item-import success: \{err.message()}",
      )
  }
  debug_inspect(output.contains("#version"), content="false")
  debug_inspect(output.contains("fn valueX_naga_oil_mod_X"), content="true")
}
