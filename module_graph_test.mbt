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
test "naga_oil: import target parser preserves nested group and alias shapes" {
  let targets : Array[@moon_wgsl.WgslImportTarget] = []
  @moon_wgsl.collect_wgsl_import_targets(
    "bevy_render::{view::View, globals::Globals, maths as maths}", "", targets,
  )
  debug_inspect(targets.length(), content="3")
  debug_inspect(targets[0].raw_path, content="\"bevy_render::view::View\"")
  debug_inspect(targets[0].alias_name, content="\"\"")
  debug_inspect(
    targets[1].raw_path,
    content="\"bevy_render::globals::Globals\"",
  )
  debug_inspect(targets[2].raw_path, content="\"bevy_render::maths\"")
  debug_inspect(targets[2].alias_name, content="\"maths\"")
}

///|
test "naga_oil: registered source registry tracks define_import_path" {
  @moon_wgsl.clear_registered_wgsl_source_registry()
  @moon_wgsl.register_wgsl_source(
    "shaders/demo/module.wgsl", "#define_import_path demo::module\nfn shade() -> f32 { return 1.0; }\n",
  )
  debug_inspect(
    @moon_wgsl.registered_wgsl_source("shaders/demo/module.wgsl"),
    content="Some(\"#define_import_path demo::module\\nfn shade() -> f32 { return 1.0; }\\n\")",
  )
  let modules = @moon_wgsl.build_wgsl_import_module_paths("")
  debug_inspect(
    modules.get("demo::module"),
    content="Some(\"shaders/demo/module.wgsl\")",
  )
  @moon_wgsl.clear_registered_wgsl_source_registry()
}

///|
test "naga_oil: resolve import module prefers registered map entries" {
  @moon_wgsl.clear_registered_wgsl_source_registry()
  @moon_wgsl.register_wgsl_source(
    "sprite_render/render/sprite_view_bindings.wgsl", "#define_import_path bevy_sprite_render::render::sprite_view_bindings\nfn shade() -> f32 { return 1.0; }\n",
  )
  let modules = @moon_wgsl.build_wgsl_import_module_paths("")
  let resolved = @moon_wgsl.resolve_wgsl_import_module(
    "", "bevy_sprite_render::render::sprite_view_bindings::View", modules,
  )
  debug_inspect(
    resolved,
    content="Some(\n  {\n    module_path: \"bevy_sprite_render::render::sprite_view_bindings\",\n    rel_path: \"sprite_render/render/sprite_view_bindings.wgsl\",\n  },\n)",
  )
  @moon_wgsl.clear_registered_wgsl_source_registry()
}
