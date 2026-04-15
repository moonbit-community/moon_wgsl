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
test "naga_oil: composer preprocess supports multiline grouped imports" {
  register_grouped_import_test_shaders()
  let value_defines = @moon_wgsl.default_wgsl_value_defines()
  let visited : @hashmap.HashMap[String, Bool] = @hashmap.HashMap::new()
  let modules = @moon_wgsl.copy_registered_wgsl_import_module_paths()
  let preprocessed = @moon_wgsl.Composer::default().preprocess_wgsl_source(
    "assets",
    "#import bevy_render::{\n  color_operations::{hsv_to_rgb, rgb_to_hsv},\n  maths::{PI_2, powsafe},\n}\nfn demo(color: vec3<f32>) -> vec3<f32> {\n  let h = rgb_to_hsv(color);\n  return hsv_to_rgb(vec3<f32>(h.x + PI_2, h.y, powsafe(h.z, 1.0)));\n}\n",
    empty_bool_defines(),
    value_defines,
    visited,
    modules,
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
  let value_defines = @moon_wgsl.default_wgsl_value_defines()
  let visited : @hashmap.HashMap[String, Bool] = @hashmap.HashMap::new()
  let modules = @moon_wgsl.copy_registered_wgsl_import_module_paths()
  let preprocessed = @moon_wgsl.Composer::default().preprocess_wgsl_source(
    "assets",
    "#import bevy_render::maths as maths\nfn demo() -> f32 {\n  return maths::PI_2;\n}\n",
    empty_bool_defines(),
    value_defines,
    visited,
    modules,
  ) catch {
    err => abort("expected composer preprocess success: \{err.message()}")
  }
  debug_inspect(preprocessed.contains("return PI_2;"), content="true")
  debug_inspect(preprocessed.contains("maths::PI_2"), content="false")
  @moon_wgsl.clear_registered_wgsl_source_registry()
}

///|
test "naga_oil: composer item imports keep dependent view declarations" {
  register_item_import_test_shaders()
  let value_defines = @moon_wgsl.default_wgsl_value_defines()
  let modules = @moon_wgsl.copy_registered_wgsl_import_module_paths()

  let sprite_visited : @hashmap.HashMap[String, Bool] = @hashmap.HashMap::new()
  let sprite_preprocessed = @moon_wgsl.Composer::default().load_wgsl_preprocessed(
    "",
    "sprite_render/render/sprite_view_bindings.wgsl",
    empty_bool_defines(),
    value_defines,
    sprite_visited,
    modules,
  ) catch {
    err =>
      abort("expected sprite composer preprocess success: \{err.message()}")
  }
  debug_inspect(
    sprite_preprocessed.contains("struct ColorGrading"),
    content="true",
  )
  debug_inspect(sprite_preprocessed.contains("struct View"), content="true")

  let mesh2d_visited : @hashmap.HashMap[String, Bool] = @hashmap.HashMap::new()
  let mesh2d_preprocessed = @moon_wgsl.Composer::default().load_wgsl_preprocessed(
    "",
    "sprite_render/mesh2d/mesh2d_view_bindings.wgsl",
    empty_bool_defines(),
    value_defines,
    mesh2d_visited,
    modules,
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
  let value_defines = @moon_wgsl.default_wgsl_value_defines()
  let visited : @hashmap.HashMap[String, Bool] = @hashmap.HashMap::new()
  let modules = @moon_wgsl.copy_registered_wgsl_import_module_paths()
  let preprocessed = @moon_wgsl.Composer::default().load_wgsl_preprocessed(
    "assets", "pbr/render/mesh_preprocess.wgsl", defines, value_defines, visited,
    modules,
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
  let value_defines = @moon_wgsl.default_wgsl_value_defines()
  let visited : @hashmap.HashMap[String, Bool] = @hashmap.HashMap::new()
  let modules = @moon_wgsl.copy_registered_wgsl_import_module_paths()
  let preprocessed = @moon_wgsl.Composer::default().load_wgsl_preprocessed(
    "",
    "sprite_render/mesh2d/mesh2d.wgsl",
    empty_bool_defines(),
    value_defines,
    visited,
    modules,
  ) catch {
    err =>
      abort("expected registered-source preprocess success: \{err.message()}")
  }
  debug_inspect(preprocessed.contains("const PI_2"), content="true")
  debug_inspect(preprocessed.contains("return twice_pi();"), content="true")
  debug_inspect(preprocessed.contains("mesh_functions::"), content="false")
  @moon_wgsl.clear_registered_wgsl_source_registry()
}

///|
test "naga_oil: composer preprocess resolves relative quoted file imports" {
  register_relative_file_import_test_shaders()
  let value_defines = @moon_wgsl.default_wgsl_value_defines()
  let visited : @hashmap.HashMap[String, Bool] = @hashmap.HashMap::new()
  let modules = @moon_wgsl.copy_registered_wgsl_import_module_paths()
  let preprocessed = @moon_wgsl.Composer::default().load_wgsl_preprocessed(
    "",
    "shaders/effects/main.wgsl",
    empty_bool_defines(),
    value_defines,
    visited,
    modules,
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
