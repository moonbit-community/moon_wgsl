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
test "naga_oil: import target parser preserves grouped module aliases" {
  let targets : Array[@moon_wgsl.WgslImportTarget] = []
  @moon_wgsl.collect_wgsl_import_targets(
    "bevy_pbr::{\n  mesh_view_bindings as view_bindings,\n  view_transformations,\n}",
    "", targets,
  )
  debug_inspect(targets.length(), content="2")
  debug_inspect(targets[0].raw_path, content="\"bevy_pbr::mesh_view_bindings\"")
  debug_inspect(targets[0].alias_name, content="\"view_bindings\"")
  debug_inspect(
    targets[1].raw_path,
    content="\"bevy_pbr::view_transformations\"",
  )
  debug_inspect(targets[1].alias_name, content="\"\"")
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

///|
test "naga_oil: bulk source registration resolves relative quoted file paths" {
  @moon_wgsl.clear_registered_wgsl_source_registry()
  @moon_wgsl.register_wgsl_source_files([
    {
      rel_path: "shaders/shared/common.wgsl",
      source: "#define_import_path demo::shared\nstruct SharedValue {\n  tint: vec4<f32>,\n}\n",
    },
    {
      rel_path: "shaders/effects/main.wgsl",
      source: "#import \"../shared/common.wgsl\" SharedValue\nfn shade(value: SharedValue) -> vec4<f32> {\n  return value.tint;\n}\n",
    },
  ])
  debug_inspect(
    @moon_wgsl.resolve_wgsl_import_file_path(
      "shaders/effects/main.wgsl", "\"../shared/common.wgsl\"",
    ),
    content="Some(\"shaders/shared/common.wgsl\")",
  )
  debug_inspect(
    @moon_wgsl.resolve_wgsl_import_file_path(
      "shaders/effects/main.wgsl", "../shared/common.wgsl",
    ),
    content="Some(\"shaders/shared/common.wgsl\")",
  )
  @moon_wgsl.clear_registered_wgsl_source_registry()
}

///|
test "naga_oil: registry analysis reports duplicate module paths in one batch" {
  @moon_wgsl.clear_registered_wgsl_source_registry()
  let diagnostics = @moon_wgsl.analyze_wgsl_source_files_for_registry([
    {
      rel_path: "shaders/demo/a.wgsl",
      source: "#define_import_path demo::dup\nfn a() -> f32 { return 1.0; }\n",
    },
    {
      rel_path: "shaders/demo/b.wgsl",
      source: "#define_import_path demo::dup\nfn b() -> f32 { return 2.0; }\n",
    },
  ])
  debug_inspect(diagnostics.length(), content="1")
  debug_inspect(diagnostics[0].severity, content="Error")
  debug_inspect(diagnostics[0].symbol_name, content="Some(\"demo::dup\")")
  debug_inspect(
    diagnostics[0].message,
    content="\"multiple WGSL source files define the same #define_import_path in one batch\"",
  )
  @moon_wgsl.clear_registered_wgsl_source_registry()
}

///|
test "naga_oil: checked bulk registration blocks normalized rel-path conflicts" {
  @moon_wgsl.clear_registered_wgsl_source_registry()
  let diagnostics = @moon_wgsl.register_wgsl_source_files_checked([
    {
      rel_path: "shaders/demo/./shared.wgsl",
      source: "#define_import_path demo::shared_a\nfn a() -> f32 { return 1.0; }\n",
    },
    {
      rel_path: "shaders/demo/shared.wgsl",
      source: "#define_import_path demo::shared_b\nfn b() -> f32 { return 2.0; }\n",
    },
  ])
  debug_inspect(diagnostics.length(), content="1")
  debug_inspect(diagnostics[0].severity, content="Error")
  debug_inspect(
    diagnostics[0].rel_path,
    content="Some(\"shaders/demo/shared.wgsl\")",
  )
  debug_inspect(
    diagnostics[0].message,
    content="\"multiple WGSL source files normalize to the same rel_path with different contents\"",
  )
  debug_inspect(
    @moon_wgsl.registered_wgsl_source("shaders/demo/shared.wgsl"),
    content="None",
  )
  @moon_wgsl.clear_registered_wgsl_source_registry()
}

///|
test "naga_oil: scan_wgsl_source_files reads a WGSL tree via moonbitlang/x/fs" {
  let files = @moon_wgsl.scan_wgsl_source_files("testdata/wgsl_scan", {
    recursive: true,
    extensions: [".wgsl"],
    exclude_prefixes: ["ignored"],
  }) catch {
    _ => abort("expected WGSL source scan success")
  }
  let rel_paths : Array[String] = []
  for file in files {
    rel_paths.push(file.rel_path)
  }
  rel_paths.sort()
  debug_inspect(
    rel_paths.join(","),
    content="\"effects/main.wgsl,shared/common.wgsl\"",
  )
}

///|
test "naga_oil: scan_wgsl_source_files_checked reports duplicate module paths" {
  let (files, diagnostics) = @moon_wgsl.scan_wgsl_source_files_checked(
    "testdata/wgsl_scan_dups",
    @moon_wgsl.WgslSourceScanOptions::default(),
  ) catch {
    _ => abort("expected checked WGSL source scan success")
  }
  debug_inspect(files.length(), content="2")
  debug_inspect(diagnostics.length(), content="1")
  debug_inspect(diagnostics[0].severity, content="Error")
  debug_inspect(diagnostics[0].symbol_name, content="Some(\"demo::dup\")")
}
