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
fn empty_bool_defines() -> @hashmap.HashMap[String, Bool] {
  @hashmap.HashMap([])
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
  defines : @hashmap.HashMap[String, Bool],
  redirects : Array[@common.WgslSymbolRedirect],
) -> @common.WgslComposeOptions {
  {
    defines,
    value_defines: @common.default_wgsl_value_defines(),
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
  files : Array[@common.WgslSourceFile],
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
    "render/color_operations.wgsl", "#define_import_path bevy_render::color_operations\nfn rgb_to_hsv(color: vec3<f32>) -> vec3<f32> {\n  return color;\n}\nfn hsv_to_rgb(color: vec3<f32>) -> vec3<f32> {\n  return color;\n}\n",
  )
  register_composer_test_shader_source(
    "render/maths.wgsl", "#define_import_path bevy_render::maths\nconst PI_2: f32 = 6.28318f;\nfn powsafe(value: f32, power: f32) -> f32 {\n  return value * power;\n}\n",
  )
}

///|
fn register_item_import_test_shaders() -> Unit {
  clear_composer_test_registry()
  register_composer_test_shader_source(
    "render/view/view.wgsl", "#define_import_path bevy_render::view\nstruct View {\n  exposure: f32,\n}\nstruct ColorGrading {\n  view: View,\n}\n",
  )
  register_composer_test_shader_source(
    "sprite_render/render/sprite_view_bindings.wgsl", "#define_import_path bevy_sprite::sprite_view_bindings\n#import bevy_render::view::ColorGrading\nstruct SpriteViewBindings {\n  grading: ColorGrading,\n}\n",
  )
  register_composer_test_shader_source(
    "sprite_render/mesh2d/mesh2d_view_bindings.wgsl", "#define_import_path bevy_sprite::mesh2d_view_bindings\n#import bevy_render::view::ColorGrading\nstruct Mesh2dViewBindings {\n  grading: ColorGrading,\n}\n",
  )
}

///|
fn register_mesh_preprocess_branch_test_shaders() -> Unit {
  clear_composer_test_registry()
  register_composer_test_shader_source(
    "render/view/view.wgsl", "#define_import_path bevy_render::view\nstruct View {\n  exposure: f32,\n}\n",
  )
  register_composer_test_shader_source(
    "pbr/render/mesh_preprocess.wgsl", "#define_import_path bevy_pbr::mesh_preprocess\n#ifdef WRITE_INDIRECT_PARAMETERS_METADATA\n#ifdef INDIRECT\n#ifdef FRUSTUM_CULLING\n#import bevy_render::view::View\n@group(0) @binding(0) var<uniform> view: View;\n#else\n#import bevy_render::previous_view::PreviousView\n@group(0) @binding(2) var<uniform> previous_view_uniforms: PreviousView;\n#endif\n#endif\n#endif\n",
  )
}

///|
fn register_relative_file_import_test_shaders() -> Unit {
  clear_composer_test_registry()
  register_composer_test_shader_files([
    {
      rel_path: "shaders/shared/common.wgsl",
      source: "struct SharedParams {\n  tint: vec4<f32>,\n}\nstruct SharedVertex {\n  params: SharedParams,\n}\nfn build_color(vertex: SharedVertex) -> vec4<f32> {\n  return vertex.params.tint;\n}\nfn unused_helper() -> f32 {\n  return 0.0;\n}\n",
    },
    {
      rel_path: "shaders/effects/main.wgsl",
      source: "#import \"../shared/common.wgsl\" SharedVertex, build_color\nfn shade(vertex: SharedVertex) -> vec4<f32> {\n  return build_color(vertex);\n}\n",
    },
  ])
}

///|
fn register_redirect_test_shaders() -> Unit {
  clear_composer_test_registry()
  register_composer_test_shader_files([
    {
      rel_path: "shaders/shared/common.wgsl",
      source: "struct SharedParams {\n  tint: vec4<f32>,\n}\nstruct SharedVertex {\n  params: SharedParams,\n}\nfn build_color(vertex: SharedVertex) -> vec4<f32> {\n  return vertex.params.tint;\n}\nfn build_shadow(vertex: SharedVertex) -> vec4<f32> {\n  return vec4<f32>(0.0, 0.0, 0.0, 1.0);\n}\n",
    },
    {
      rel_path: "shaders/effects/redirect.wgsl",
      source: "#import \"../shared/common.wgsl\" SharedVertex, build_color, build_shadow\nfn shade(vertex: SharedVertex) -> vec4<f32> {\n  return build_shadow(vertex);\n}\n",
    },
  ])
}

///|
fn register_cycle_test_shaders() -> Unit {
  clear_composer_test_registry()
  register_composer_test_shader_source(
    "shaders/cycle/a.wgsl", "#define_import_path demo::a\n#import demo::b::b_value\nfn a_value() -> f32 {\n  return b_value();\n}\n",
  )
  register_composer_test_shader_source(
    "shaders/cycle/b.wgsl", "#define_import_path demo::b\n#import demo::a::a_value\nfn b_value() -> f32 {\n  return a_value();\n}\n",
  )
}

///|
test "naga_oil: composer preprocess supports multiline grouped imports" {
  register_grouped_import_test_shaders()
  let preprocessed = composer_test_composer().compose_wgsl_source(
    "#import bevy_render::{\n  color_operations::{hsv_to_rgb, rgb_to_hsv},\n  maths::{PI_2, powsafe},\n}\nfn demo(color: vec3<f32>) -> vec3<f32> {\n  let h = rgb_to_hsv(color);\n  return hsv_to_rgb(vec3<f32>(h.x + PI_2, h.y, powsafe(h.z, 1.0)));\n}\n",
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
test "naga_oil: composer directives use Rust regex Unicode whitespace" {
  clear_composer_test_registry()
  register_composer_test_shader_source(
    "shared/inc.wgsl", "#define_import_path demo::inc\nfn inc() -> f32 {\n  return 1f;\n}\n",
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
    "shared/inc.wgsl", "#define_import_path demo::inc\nfn inc() -> f32 {\n  return 1f;\n}\n",
  )
  let preprocessed = composer_test_composer().compose_wgsl_source(
    "/* stripped prefix */#import demo::inc::inc\nfn demo() -> f32 {\n  return inc();\n}\n",
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
    "#import bevy_render::maths as maths\nfn demo() -> f32 {\n  return maths::PI_2;\n}\n",
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
    "#import bevy_render::maths as maths\n// return maths::PI_2;\nfn demo() -> f32 {\n  return 1f;\n}\n",
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
    "// unresolved::path should stay a comment\nfn demo() -> f32 {\n  return 1f;\n}\n",
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
  let defines : @hashmap.HashMap[String, Bool] = @hashmap.HashMap([])
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
    "render/maths.wgsl", "#define_import_path bevy_render::maths\nconst PI_2: f32 = 6.28318f;\n",
  )
  register_composer_test_shader_source(
    "sprite_render/mesh2d/mesh2d_functions.wgsl", "#define_import_path bevy_sprite::mesh2d_functions\n#import bevy_render::maths::PI_2\nfn twice_pi() -> f32 {\n  return PI_2;\n}\n",
  )
  register_composer_test_shader_source(
    "sprite_render/mesh2d/mesh2d.wgsl", "#import bevy_sprite::mesh2d_functions as mesh_functions\nfn demo() -> f32 {\n  return mesh_functions::twice_pi();\n}\n",
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
    "shaders/demo/global.wgsl", "#define_import_path demo::global\nfn global_value() -> f32 {\n  return 1f;\n}\n",
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
    "shaders/demo/snap_a.wgsl", "#define_import_path demo::snap_a\nfn snap_a() -> f32 {\n  return 1f;\n}\n",
  )
  let composer = composer_test_composer()
  clear_composer_test_registry()
  register_composer_test_shader_source(
    "shaders/demo/snap_b.wgsl", "#define_import_path demo::snap_b\nfn snap_b() -> f32 {\n  return 2f;\n}\n",
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
      source: "struct SharedParams {\n  tint: vec4<f32>,\n}\nstruct SharedVertex {\n  params: SharedParams,\n}\nfn build_color(vertex: SharedVertex) -> vec4<f32> {\n  return vertex.params.tint;\n}\n",
    },
    {
      rel_path: "shaders/effects/main.wgsl",
      source: "#import \"../shared/common.wgsl\" SharedVertex, build_color\nfn shade(vertex: SharedVertex) -> vec4<f32> {\n  return build_color(vertex);\n}\n",
    },
  ])
  let preprocessed = composer.compose_wgsl("shaders/effects/main.wgsl", {
    defines: empty_bool_defines(),
    value_defines: @common.default_wgsl_value_defines(),
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
  let value_defines = @common.default_wgsl_value_defines()
  value_defines.set("CUSTOM_LIMIT", @common.ShaderDefValue::Int(42))
  let preprocessed = @compose.Composer::default().compose_wgsl_source(
    "// 😀 before a braced template const\nconst A: u32 = #{CUSTOM_LIMIT}u;\n// 😃 before a bare template const\nconst B: u32 = #CUSTOM_LIMITu;\n",
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
  let value_defines = @common.default_wgsl_value_defines()
  value_defines.set("LARGE_COUNT", @common.ShaderDefValue::UInt(3221225472U))
  let preprocessed = @compose.Composer::default().compose_wgsl_source(
    "const A: u32 = #LARGE_COUNTu;\nconst B: u32 = #{LARGE_COUNT}u;\n",
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
test "naga_oil: add_composable_module feeds the composer compose path" {
  clear_composer_test_registry()
  let composer = @compose.Composer::default()
  composer.clear_sources()
  ignore(
    composer.add_composable_module({
      source: "#define_import_path demo::maths\nconst PI_2: f32 = 6.28318f;\n",
      file_path: "shaders/demo/maths.wgsl",
      as_name: None,
      additional_imports: [],
      shader_defs: @hashmap.HashMap([]),
    }),
  ) catch {
    err => abort("expected maths module registration success: \{err.message()}")
  }
  ignore(
    composer.add_composable_module({
      source: "#define_import_path demo::main\n#import demo::maths::PI_2\nfn demo() -> f32 {\n  return PI_2;\n}\n",
      file_path: "shaders/demo/main.wgsl",
      as_name: None,
      additional_imports: [],
      shader_defs: @hashmap.HashMap([]),
    }),
  ) catch {
    err => abort("expected main module registration success: \{err.message()}")
  }
  let preprocessed = composer.compose_wgsl("shaders/demo/main.wgsl", {
    defines: empty_bool_defines(),
    value_defines: @common.default_wgsl_value_defines(),
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
      source: "# define_import_path demo::maths\nconst PI_2: f32 = 6.28318f;\n",
      file_path: "shaders/demo/maths.wgsl",
      as_name: None,
      additional_imports: [],
      shader_defs: @hashmap.HashMap([]),
    }),
  ) catch {
    err => abort("expected maths module registration success: \{err.message()}")
  }
  ignore(
    composer.add_composable_module({
      source: "# define_import_path demo::main\n# import demo::maths::PI_2\nfn demo() -> f32 {\n  return PI_2;\n}\n",
      file_path: "shaders/demo/main.wgsl",
      as_name: None,
      additional_imports: [],
      shader_defs: @hashmap.HashMap([]),
    }),
  ) catch {
    err => abort("expected main module registration success: \{err.message()}")
  }
  let preprocessed = composer.compose_wgsl("shaders/demo/main.wgsl", {
    defines: empty_bool_defines(),
    value_defines: @common.default_wgsl_value_defines(),
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
    "#define\n#import\n#define_import_path\nfn shade() {}\n",
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
      "#import @\nfn shade() {}\n",
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
    "#import ;\nfn shade() {}\n",
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
      source: "#define_import_path plugin\nfn external_scale() -> f32 {\n  return 2f;\n}\n",
      file_path: "shaders/demo/plugin.wgsl",
      as_name: None,
      additional_imports: [],
      shader_defs: @hashmap.HashMap([]),
    }),
  ) catch {
    err =>
      abort("expected plugin module registration success: \{err.message()}")
  }
  ignore(
    composer.add_composable_module({
      source: "#define_import_path demo::main\nfn demo() -> f32 {\n  return plugin::external_scale();\n}\n",
      file_path: "shaders/demo/main.wgsl",
      as_name: None,
      additional_imports: [{ import_path: "plugin", items: [] }],
      shader_defs: @hashmap.HashMap([]),
    }),
  ) catch {
    err => abort("expected main module registration success: \{err.message()}")
  }
  let preprocessed = composer.compose_wgsl("shaders/demo/main.wgsl", {
    defines: empty_bool_defines(),
    value_defines: @common.default_wgsl_value_defines(),
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
test "naga_oil: composer can register a WGSL source tree from moonbitlang/x/fs" {
  clear_composer_test_registry()
  let composer = @compose.Composer::default()
  composer.clear_sources()
  composer.register_source_tree(
    "testdata/wgsl_scan",
    @common.WgslSourceScanOptions::default(),
  ) catch {
    _ => abort("expected WGSL source tree registration success")
  }
  let preprocessed = composer.compose_wgsl("effects/main.wgsl", {
    defines: empty_bool_defines(),
    value_defines: @common.default_wgsl_value_defines(),
    redirects: [],
    additional_imports: [],
  }) catch {
    err =>
      abort("expected source-tree-backed preprocess success: \{err.message()}")
  }
  debug_inspect(
    composer.registered_source("effects/main.wgsl") is Some(_),
    content="true",
  )
  debug_inspect(preprocessed.contains("struct SharedValue"), content="true")
  debug_inspect(preprocessed.contains("fn build_color"), content="true")
  debug_inspect(preprocessed.contains("fn shade"), content="true")
}

///|
test "naga_oil: checked source-tree registration preserves existing registry conflicts" {
  clear_composer_test_registry()
  let composer = @compose.Composer::default()
  composer.clear_sources()
  composer.register_source(
    "shared/common.wgsl", "#define_import_path demo::shared\nfn shared_value() -> f32 {\n  return 1f;\n}\n",
  )
  let diagnostics = composer.register_source_tree_checked(
    "testdata/wgsl_scan_conflict",
    @common.WgslSourceScanOptions::default(),
  ) catch {
    _ => abort("expected checked WGSL source tree registration success")
  }
  debug_inspect(diagnostics.length(), content="1")
  debug_inspect(diagnostics[0].severity, content="Error")
  debug_inspect(diagnostics[0].rel_path, content="Some(\"shared/common.wgsl\")")
  debug_inspect(
    composer.registered_source("shared/common.wgsl"),
    content="Some(\"#define_import_path demo::shared\\nfn shared_value() -> f32 {\\n  return 1f;\\n}\\n\")",
  )
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
  debug_inspect(
    preprocessed.contains("build_color") && preprocessed.contains("(vertex);"),
    content="true",
  )
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
    "mod.wgsl", "#define_import_path mod\nvirtual fn inner() -> f32 {\n  return 1f;\n}\n",
  )
  composer.register_source(
    "top.wgsl", "#import mod\noverride fn mod::inner() -> f32 {\n  let mod__inner = 2f;\n  return mod__inner;\n}\nfn top() -> f32 {\n  return mod::inner();\n}\n",
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
    "mod.wgsl", "#define_import_path mod\nvirtual fn inner() -> f32 {\n  return 1f;\n}\n",
  )
  composer.register_source(
    "top.wgsl", "#import mod\noverride fn mod::inner() -> f32 {\n  let value = mod::inner();\n  let mod__inner = 2f;\n  return value + mod__inner;\n}\nfn top() -> f32 {\n  return mod::inner();\n}\n",
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
    "mod.wgsl", "#define_import_path mod\nvirtual fn inner() -> f32 {\n  return 1f;\n}\nfn outer() -> f32 {\n  return inner();\n}\n",
  )
  composer.register_source(
    "middle.wgsl", "#define_import_path middle\n#import mod\noverride fn mod::inner() -> f32 {\n  return 2f;\n}\n",
  )
  composer.register_source(
    "top.wgsl", "#import middle\n#import mod\nfn top() -> f32 {\n  return mod::outer();\n}\n",
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
  let source = "// 中文注释会让旧 starts_with_text 切到非法边界\n#ifdef ENABLED\nconst enabled_value: u32 = 1u;\n#endif\nfn main() -> u32 {\n  return 0u;\n}\n"
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
    "missing_if.wgsl", "#if TEXTURE == 3\nconst active: u32 = 1u;\n#endif\n",
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
    "invalid_uint_if.wgsl", "#if COUNT == 1u\nconst active: u32 = 1u;\n#endif\n",
  )
  let options = composer_test_compose_options(empty_bool_defines(), [])
  options.value_defines.set("COUNT", @common.ShaderDefValue::Int(1))
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
    "bad_operator_if.wgsl", "#if TEXTURE !! true\nconst active: u32 = 1u;\n#endif\n",
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
  composer.register_source("too_many.wgsl", "#endif\n")
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
    "not_enough.wgsl", "#ifdef ENABLED\nconst a: u32 = 1u;\n",
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
  composer.register_source("else_without.wgsl", "#else\nconst a: u32 = 1u;\n")
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
  let source = "#define NOW_DEFINED\n#define MODE 2\n#ifdef NOW_DEFINED\nconst enabled: u32 = #MODE;\n#endif\n#if MODE == 2\nconst selected: u32 = #MODE;\n#else\nconst selected: u32 = 0u;\n#endif\n"
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
test "naga_oil: source catalog uses per-module strict shader defs" {
  let composer = @compose.Composer::default()
  composer.clear_sources()
  let module_defs : @hashmap.HashMap[String, @common.ShaderDefValue] = @hashmap.HashMap([],
  )
  module_defs.set("MODULE_FLAG", @common.ShaderDefValue::Bool(false))
  ignore(
    composer.add_composable_module({
      source: "#define_import_path catalog::module\n#ifdef MODULE_FLAG\nfn from_if() -> f32 {\n  return 1f;\n}\n#else\nfn from_else() -> f32 {\n  return 2f;\n}\n#endif\n",
      file_path: "shaders/catalog/module.wgsl",
      as_name: None,
      additional_imports: [],
      shader_defs: module_defs,
    }),
  ) catch {
    err => abort("expected module registration success: \{err.message()}")
  }
  composer.register_source(
    "shaders/catalog/root.wgsl", "#import catalog::module::from_if\nfn shade() -> f32 {\n  return from_if();\n}\n",
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
      source: "#define_import_path bad::module\n#define LOCAL_FLAG\nfn value() -> f32 {\n  return 1f;\n}\n",
      file_path: "shaders/bad/module.wgsl",
      as_name: None,
      additional_imports: [],
      shader_defs: @hashmap.HashMap([]),
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
      "diagnostic(note, derivative_uniformity);\nfn shade() {}\n",
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
      "#version 430\nfn shade() -> f32 { return 1f; }\n",
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
    "#version 450\nfn shade() -> f32 { return 1f; }\n",
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
    "shaders/version/module.wgsl", "#define_import_path version::module\n#version 430\nfn value() -> f32 { return 1f; }\n",
  )
  composer.register_source(
    "shaders/version/root.wgsl", "#import version::module::value\nfn shade() -> f32 { return value(); }\n",
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
    "shaders/version/module.wgsl", "#define_import_path version::module\n#version 450\nfn value() -> f32 { return 1f; }\n",
  )
  composer.register_source(
    "shaders/version/root.wgsl", "#import version::module::value\nfn shade() -> f32 { return value(); }\n",
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
