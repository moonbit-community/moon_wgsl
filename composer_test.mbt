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
  @hashmap.HashMap::new()
}

///|
fn global_registry_composer() -> @moon_wgsl.Composer {
  @moon_wgsl.Composer::from_registered_wgsl_source_registry()
}

///|
fn composer_test_compose_options(
  assets_base : String,
  defines : @hashmap.HashMap[String, Bool],
  redirects : Array[@moon_wgsl.WgslSymbolRedirect],
) -> @moon_wgsl.WgslComposeOptions {
  {
    assets_base,
    defines,
    value_defines: @moon_wgsl.default_wgsl_value_defines(),
    redirects,
    additional_imports: [],
  }
}

///|
fn register_composer_test_shader_source(path : String, source : String) -> Unit {
  @moon_wgsl.register_wgsl_source(path, source)
}

///|
fn register_grouped_import_test_shaders() -> Unit {
  @moon_wgsl.clear_registered_wgsl_source_registry()
  register_composer_test_shader_source(
    "render/color_operations.wgsl", "#define_import_path bevy_render::color_operations\nfn rgb_to_hsv(color: vec3<f32>) -> vec3<f32> {\n  return color;\n}\nfn hsv_to_rgb(color: vec3<f32>) -> vec3<f32> {\n  return color;\n}\n",
  )
  register_composer_test_shader_source(
    "render/maths.wgsl", "#define_import_path bevy_render::maths\nconst PI_2: f32 = 6.28318;\nfn powsafe(value: f32, power: f32) -> f32 {\n  return value * power;\n}\n",
  )
}

///|
fn register_item_import_test_shaders() -> Unit {
  @moon_wgsl.clear_registered_wgsl_source_registry()
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
  @moon_wgsl.clear_registered_wgsl_source_registry()
  register_composer_test_shader_source(
    "render/view/view.wgsl", "#define_import_path bevy_render::view\nstruct View {\n  exposure: f32,\n}\n",
  )
  register_composer_test_shader_source(
    "pbr/render/mesh_preprocess.wgsl", "#define_import_path bevy_pbr::mesh_preprocess\n#ifdef WRITE_INDIRECT_PARAMETERS_METADATA\n#ifdef INDIRECT\n#ifdef FRUSTUM_CULLING\n#import bevy_render::view::View\n@group(0) @binding(0) var<uniform> view: View;\n#else\n#import bevy_render::previous_view::PreviousView\n@group(0) @binding(2) var<uniform> previous_view_uniforms: PreviousView;\n#endif\n#endif\n#endif\n",
  )
}

///|
fn register_relative_file_import_test_shaders() -> Unit {
  @moon_wgsl.clear_registered_wgsl_source_registry()
  @moon_wgsl.register_wgsl_source_files([
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
  @moon_wgsl.clear_registered_wgsl_source_registry()
  @moon_wgsl.register_wgsl_source_files([
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
  @moon_wgsl.clear_registered_wgsl_source_registry()
  @moon_wgsl.register_wgsl_source(
    "shaders/cycle/a.wgsl", "#define_import_path demo::a\n#import demo::b::b_value\nfn a_value() -> f32 {\n  return b_value();\n}\n",
  )
  @moon_wgsl.register_wgsl_source(
    "shaders/cycle/b.wgsl", "#define_import_path demo::b\n#import demo::a::a_value\nfn b_value() -> f32 {\n  return a_value();\n}\n",
  )
}

///|
test "naga_oil: composer preprocess supports multiline grouped imports" {
  register_grouped_import_test_shaders()
  let preprocessed = global_registry_composer().compose_wgsl_source(
    "#import bevy_render::{\n  color_operations::{hsv_to_rgb, rgb_to_hsv},\n  maths::{PI_2, powsafe},\n}\nfn demo(color: vec3<f32>) -> vec3<f32> {\n  let h = rgb_to_hsv(color);\n  return hsv_to_rgb(vec3<f32>(h.x + PI_2, h.y, powsafe(h.z, 1.0)));\n}\n",
    composer_test_compose_options("assets", empty_bool_defines(), []),
  ) catch {
    err => abort("expected composer preprocess success: \{err.message()}")
  }
  debug_inspect(preprocessed.contains("fn rgb_to_hsv"), content="true")
  debug_inspect(preprocessed.contains("fn hsv_to_rgb"), content="true")
  debug_inspect(preprocessed.contains("const PI_2"), content="true")
  debug_inspect(preprocessed.contains("bevy_render::"), content="false")
  @moon_wgsl.clear_registered_wgsl_source_registry()
}

///|
test "naga_oil: composer preprocess strips module aliases" {
  register_grouped_import_test_shaders()
  let preprocessed = global_registry_composer().compose_wgsl_source(
    "#import bevy_render::maths as maths\nfn demo() -> f32 {\n  return maths::PI_2;\n}\n",
    composer_test_compose_options("assets", empty_bool_defines(), []),
  ) catch {
    err => abort("expected composer preprocess success: \{err.message()}")
  }
  debug_inspect(preprocessed.contains("return maths__PI_2;"), content="true")
  debug_inspect(preprocessed.contains("maths::PI_2"), content="false")
  @moon_wgsl.clear_registered_wgsl_source_registry()
}

///|
test "naga_oil: composer item imports keep dependent view declarations" {
  register_item_import_test_shaders()
  let sprite_preprocessed = global_registry_composer().compose_wgsl(
    "sprite_render/render/sprite_view_bindings.wgsl",
    composer_test_compose_options("", empty_bool_defines(), []),
  ) catch {
    err =>
      abort("expected sprite composer preprocess success: \{err.message()}")
  }
  debug_inspect(
    sprite_preprocessed.contains("struct ColorGrading"),
    content="true",
  )
  debug_inspect(sprite_preprocessed.contains("struct View"), content="true")

  let mesh2d_preprocessed = global_registry_composer().compose_wgsl(
    "sprite_render/mesh2d/mesh2d_view_bindings.wgsl",
    composer_test_compose_options("", empty_bool_defines(), []),
  ) catch {
    err =>
      abort("expected mesh2d composer preprocess success: \{err.message()}")
  }
  debug_inspect(
    mesh2d_preprocessed.contains("struct ColorGrading"),
    content="true",
  )
  debug_inspect(mesh2d_preprocessed.contains("struct View"), content="true")
  @moon_wgsl.clear_registered_wgsl_source_registry()
}

///|
test "naga_oil: composer drops preprocess previous-view imports outside active branches" {
  register_mesh_preprocess_branch_test_shaders()
  let defines : @hashmap.HashMap[String, Bool] = @hashmap.HashMap::new()
  defines.set("WRITE_INDIRECT_PARAMETERS_METADATA", true)
  defines.set("INDIRECT", true)
  defines.set("FRUSTUM_CULLING", true)
  let preprocessed = global_registry_composer().compose_wgsl(
    "pbr/render/mesh_preprocess.wgsl",
    composer_test_compose_options("assets", defines, []),
  ) catch {
    err =>
      abort(
        "expected mesh preprocess composer preprocess success: \{err.message()}",
      )
  }
  debug_inspect(
    preprocessed.contains("@group(0) @binding(0) var<uniform> view: View;"),
    content="true",
  )
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
  @moon_wgsl.clear_registered_wgsl_source_registry()
}

///|
test "naga_oil: composer registered sources satisfy strict mesh2d preprocessing" {
  @moon_wgsl.clear_registered_wgsl_source_registry()
  @moon_wgsl.register_wgsl_source(
    "render/maths.wgsl", "#define_import_path bevy_render::maths\nconst PI_2: f32 = 6.28318;\n",
  )
  @moon_wgsl.register_wgsl_source(
    "sprite_render/mesh2d/mesh2d_functions.wgsl", "#define_import_path bevy_sprite::mesh2d_functions\n#import bevy_render::maths::PI_2\nfn twice_pi() -> f32 {\n  return PI_2;\n}\n",
  )
  @moon_wgsl.register_wgsl_source(
    "sprite_render/mesh2d/mesh2d.wgsl", "#import bevy_sprite::mesh2d_functions as mesh_functions\nfn demo() -> f32 {\n  return mesh_functions::twice_pi();\n}\n",
  )
  let preprocessed = global_registry_composer().compose_wgsl(
    "sprite_render/mesh2d/mesh2d.wgsl",
    composer_test_compose_options("", empty_bool_defines(), []),
  ) catch {
    err =>
      abort("expected registered-source preprocess success: \{err.message()}")
  }
  debug_inspect(
    preprocessed.contains("const mesh_functions__PI_2"),
    content="true",
  )
  debug_inspect(
    preprocessed.contains("return mesh_functions__twice_pi();"),
    content="true",
  )
  debug_inspect(preprocessed.contains("mesh_functions::"), content="false")
  @moon_wgsl.clear_registered_wgsl_source_registry()
}

///|
test "naga_oil: composer preprocess resolves relative quoted file imports" {
  register_relative_file_import_test_shaders()
  let preprocessed = global_registry_composer().compose_wgsl(
    "shaders/effects/main.wgsl",
    composer_test_compose_options("", empty_bool_defines(), []),
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
  @moon_wgsl.clear_registered_wgsl_source_registry()
}

///|
test "naga_oil: composer default is isolated from the global registry" {
  @moon_wgsl.clear_registered_wgsl_source_registry()
  @moon_wgsl.register_wgsl_source(
    "shaders/demo/global.wgsl", "#define_import_path demo::global\nfn global_value() -> f32 {\n  return 1.0;\n}\n",
  )
  debug_inspect(
    @moon_wgsl.Composer::default().registered_wgsl_source(
      "shaders/demo/global.wgsl",
    ),
    content="None",
  )
  debug_inspect(
    global_registry_composer().registered_wgsl_source(
      "shaders/demo/global.wgsl",
    ),
    content="Some(\"#define_import_path demo::global\\nfn global_value() -> f32 {\\n  return 1.0;\\n}\\n\")",
  )
  @moon_wgsl.clear_registered_wgsl_source_registry()
}

///|
test "naga_oil: composer global-registry snapshots stay isolated from later global mutations" {
  @moon_wgsl.clear_registered_wgsl_source_registry()
  @moon_wgsl.register_wgsl_source(
    "shaders/demo/snap_a.wgsl", "#define_import_path demo::snap_a\nfn snap_a() -> f32 {\n  return 1.0;\n}\n",
  )
  let composer = global_registry_composer()
  @moon_wgsl.clear_registered_wgsl_source_registry()
  @moon_wgsl.register_wgsl_source(
    "shaders/demo/snap_b.wgsl", "#define_import_path demo::snap_b\nfn snap_b() -> f32 {\n  return 2.0;\n}\n",
  )
  debug_inspect(
    composer.registered_wgsl_source("shaders/demo/snap_a.wgsl") is Some(_),
    content="true",
  )
  debug_inspect(
    composer.registered_wgsl_source("shaders/demo/snap_b.wgsl"),
    content="None",
  )
  let preprocessed = composer.compose_wgsl(
    "shaders/demo/snap_a.wgsl",
    composer_test_compose_options("", empty_bool_defines(), []),
  ) catch {
    err => abort("expected snapshot-backed compose success: \{err.message()}")
  }
  debug_inspect(preprocessed.contains("fn snap_a"), content="true")
  debug_inspect(preprocessed.contains("fn snap_b"), content="false")
  @moon_wgsl.clear_registered_wgsl_source_registry()
}

///|
test "naga_oil: composer local registry can compose without global registry state" {
  @moon_wgsl.clear_registered_wgsl_source_registry()
  let composer = @moon_wgsl.Composer::default()
  composer.clear_registered_wgsl_source_registry()
  composer.register_wgsl_source_files([
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
    assets_base: "",
    defines: empty_bool_defines(),
    value_defines: @moon_wgsl.default_wgsl_value_defines(),
    redirects: [],
    additional_imports: [],
  }) catch {
    err =>
      abort(
        "expected composer-local registry preprocess success: \{err.message()}",
      )
  }
  debug_inspect(
    @moon_wgsl.registered_wgsl_source("shaders/effects/main.wgsl"),
    content="None",
  )
  debug_inspect(preprocessed.contains("struct SharedVertex"), content="true")
  debug_inspect(preprocessed.contains("fn build_color"), content="true")
  debug_inspect(preprocessed.contains("fn shade"), content="true")
}

///|
test "naga_oil: add_composable_module feeds the composer compose path" {
  @moon_wgsl.clear_registered_wgsl_source_registry()
  let composer = @moon_wgsl.Composer::default()
  composer.clear_registered_wgsl_source_registry()
  ignore(
    composer.add_composable_module({
      source: "#define_import_path demo::maths\nconst PI_2: f32 = 6.28318;\n",
      file_path: "shaders/demo/maths.wgsl",
      language: @moon_wgsl.ShaderLanguage::Wgsl,
      as_name: None,
      additional_imports: [],
      shader_defs: @hashmap.HashMap::new(),
    }),
  ) catch {
    err => abort("expected maths module registration success: \{err.message()}")
  }
  ignore(
    composer.add_composable_module({
      source: "#define_import_path demo::main\n#import demo::maths::PI_2\nfn demo() -> f32 {\n  return PI_2;\n}\n",
      file_path: "shaders/demo/main.wgsl",
      language: @moon_wgsl.ShaderLanguage::Wgsl,
      as_name: None,
      additional_imports: [],
      shader_defs: @hashmap.HashMap::new(),
    }),
  ) catch {
    err => abort("expected main module registration success: \{err.message()}")
  }
  let preprocessed = composer.compose_wgsl("shaders/demo/main.wgsl", {
    assets_base: "",
    defines: empty_bool_defines(),
    value_defines: @moon_wgsl.default_wgsl_value_defines(),
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
  debug_inspect(preprocessed.contains("return PI_2;"), content="true")
}

///|
test "naga_oil: add_composable_module applies descriptor additional imports" {
  @moon_wgsl.clear_registered_wgsl_source_registry()
  let composer = @moon_wgsl.Composer::default()
  composer.clear_registered_wgsl_source_registry()
  ignore(
    composer.add_composable_module({
      source: "#define_import_path plugin\nfn external_scale() -> f32 {\n  return 2.0;\n}\n",
      file_path: "shaders/demo/plugin.wgsl",
      language: @moon_wgsl.ShaderLanguage::Wgsl,
      as_name: None,
      additional_imports: [],
      shader_defs: @hashmap.HashMap::new(),
    }),
  ) catch {
    err =>
      abort("expected plugin module registration success: \{err.message()}")
  }
  ignore(
    composer.add_composable_module({
      source: "#define_import_path demo::main\nfn demo() -> f32 {\n  return plugin::external_scale();\n}\n",
      file_path: "shaders/demo/main.wgsl",
      language: @moon_wgsl.ShaderLanguage::Wgsl,
      as_name: None,
      additional_imports: [{ import_path: "plugin", items: [] }],
      shader_defs: @hashmap.HashMap::new(),
    }),
  ) catch {
    err => abort("expected main module registration success: \{err.message()}")
  }
  let preprocessed = composer.compose_wgsl("shaders/demo/main.wgsl", {
    assets_base: "",
    defines: empty_bool_defines(),
    value_defines: @moon_wgsl.default_wgsl_value_defines(),
    redirects: [],
    additional_imports: [],
  }) catch {
    err =>
      abort(
        "expected additional-import-backed preprocess success: \{err.message()}",
      )
  }
  debug_inspect(
    preprocessed.contains("fn plugin__external_scale"),
    content="true",
  )
  debug_inspect(
    preprocessed.contains("plugin__external_scale()"),
    content="true",
  )
}

///|
test "naga_oil: composer can register a WGSL source tree from moonbitlang/x/fs" {
  @moon_wgsl.clear_registered_wgsl_source_registry()
  let composer = @moon_wgsl.Composer::default()
  composer.clear_registered_wgsl_source_registry()
  composer.register_wgsl_source_tree(
    "testdata/wgsl_scan",
    @moon_wgsl.WgslSourceScanOptions::default(),
  ) catch {
    _ => abort("expected WGSL source tree registration success")
  }
  let preprocessed = composer.compose_wgsl("effects/main.wgsl", {
    assets_base: "",
    defines: empty_bool_defines(),
    value_defines: @moon_wgsl.default_wgsl_value_defines(),
    redirects: [],
    additional_imports: [],
  }) catch {
    err =>
      abort("expected source-tree-backed preprocess success: \{err.message()}")
  }
  debug_inspect(
    composer.registered_wgsl_source("effects/main.wgsl") is Some(_),
    content="true",
  )
  debug_inspect(preprocessed.contains("struct SharedValue"), content="true")
  debug_inspect(preprocessed.contains("fn build_color"), content="true")
  debug_inspect(preprocessed.contains("fn shade"), content="true")
}

///|
test "naga_oil: checked source-tree registration preserves existing registry conflicts" {
  @moon_wgsl.clear_registered_wgsl_source_registry()
  let composer = @moon_wgsl.Composer::default()
  composer.clear_registered_wgsl_source_registry()
  composer.register_wgsl_source(
    "shared/common.wgsl", "#define_import_path demo::shared\nfn shared_value() -> f32 {\n  return 1.0;\n}\n",
  )
  let diagnostics = composer.register_wgsl_source_tree_checked(
    "testdata/wgsl_scan_conflict",
    @moon_wgsl.WgslSourceScanOptions::default(),
  ) catch {
    _ => abort("expected checked WGSL source tree registration success")
  }
  debug_inspect(diagnostics.length(), content="1")
  debug_inspect(diagnostics[0].severity, content="Error")
  debug_inspect(diagnostics[0].rel_path, content="Some(\"shared/common.wgsl\")")
  debug_inspect(
    composer.registered_wgsl_source("shared/common.wgsl"),
    content="Some(\"#define_import_path demo::shared\\nfn shared_value() -> f32 {\\n  return 1.0;\\n}\\n\")",
  )
}

///|
test "naga_oil: source-level symbol redirects rewrite references but keep declarations" {
  let rewritten = @moon_wgsl.rewrite_wgsl_symbol_redirects(
    "fn shade() -> f32 {\n  return build_shadow();\n}\nfn build_shadow() -> f32 {\n  return 1.0;\n}\n",
    [{ from_name: "build_shadow", to_name: "build_color" }],
  )
  debug_inspect(rewritten.contains("return build_color();"), content="true")
  debug_inspect(rewritten.contains("return build_shadow();"), content="false")
  debug_inspect(rewritten.contains("fn build_shadow()"), content="true")
}

///|
test "naga_oil: composer preprocess can apply source-level symbol redirects" {
  register_redirect_test_shaders()
  let preprocessed = global_registry_composer().compose_wgsl(
    "shaders/effects/redirect.wgsl",
    composer_test_compose_options("", empty_bool_defines(), [
      { from_name: "build_shadow", to_name: "build_color" },
    ]),
  ) catch {
    err =>
      abort(
        "expected redirect-aware composer preprocess success: \{err.message()}",
      )
  }
  debug_inspect(
    preprocessed.contains("return build_color(vertex);"),
    content="true",
  )
  debug_inspect(
    preprocessed.contains("return build_shadow(vertex);"),
    content="false",
  )
  debug_inspect(preprocessed.contains("fn build_color"), content="true")
  debug_inspect(preprocessed.contains("fn build_shadow"), content="false")
  @moon_wgsl.clear_registered_wgsl_source_registry()
}

///|
test "naga_oil: composer reports import cycles explicitly" {
  register_cycle_test_shaders()
  let mut message : String? = None
  ignore(
    global_registry_composer().compose_wgsl(
      "shaders/cycle/a.wgsl",
      composer_test_compose_options("", empty_bool_defines(), []),
    ),
  ) catch {
    err => message = Some(err.message())
  }
  debug_inspect(
    message,
    content="Some(\"shader import cycle detected: shaders/cycle/a.wgsl -> shaders/cycle/b.wgsl -> shaders/cycle/a.wgsl\")",
  )
  @moon_wgsl.clear_registered_wgsl_source_registry()
}
