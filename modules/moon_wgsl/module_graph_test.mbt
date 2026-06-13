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
  let targets : Array[@common.WgslImportTarget] = []
  @resolver.collect_wgsl_import_targets(
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
  let targets : Array[@common.WgslImportTarget] = []
  @resolver.collect_wgsl_import_targets(
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
  let registry = @resolver.WgslSourceRegistry::default()
  ignore(
    registry.register_source(
      "shaders/demo/module.wgsl",
      (
        #|#define_import_path demo::module
        #|fn shade() -> f32 { return 1f; }
        #|
      ),
      None,
    ),
  )
  debug_inspect(
    registry.registered_source("shaders/demo/module.wgsl"),
    content="Some(\"#define_import_path demo::module\\nfn shade() -> f32 { return 1f; }\\n\")",
  )
  let modules = registry.copy_import_module_paths()
  debug_inspect(
    modules.get("demo::module"),
    content="Some(\"shaders/demo/module.wgsl\")",
  )
}

///|
test "registry source replacement removes stale module path entries" {
  let registry = @resolver.WgslSourceRegistry::default()
  ignore(
    registry.register_source(
      "shaders/demo/module.wgsl",
      (
        #|#define_import_path demo::old
        #|fn old() {}
        #|
      ),
      None,
    ),
  )
  ignore(
    registry.register_source(
      "shaders/demo/module.wgsl",
      (
        #|#define_import_path demo::new
        #|fn new() {}
        #|
      ),
      None,
    ),
  )
  let modules = registry.copy_import_module_paths()
  debug_inspect(modules.get("demo::old"), content="None")
  debug_inspect(
    modules.get("demo::new"),
    content="Some(\"shaders/demo/module.wgsl\")",
  )
  let resolved_old = @resolver.resolve_wgsl_import_module_in_registry(
    registry, "demo::old::old", modules,
  )
  debug_inspect(resolved_old, content="None")
}

///|
test "naga_oil: resolve import module prefers registered map entries" {
  let registry = @resolver.WgslSourceRegistry::default()
  ignore(
    registry.register_source(
      "sprite_render/render/sprite_view_bindings.wgsl",
      (
        #|#define_import_path bevy_sprite_render::render::sprite_view_bindings
        #|fn shade() -> f32 { return 1f; }
        #|
      ),
      None,
    ),
  )
  let modules = registry.copy_import_module_paths()
  let resolved = @resolver.resolve_wgsl_import_module_in_registry(
    registry, "bevy_sprite_render::render::sprite_view_bindings::View", modules,
  )
  debug_inspect(
    resolved,
    content="Some(\n  {\n    module_path: \"bevy_sprite_render::render::sprite_view_bindings\",\n    rel_path: \"sprite_render/render/sprite_view_bindings.wgsl\",\n  },\n)",
  )
}

///|
test "naga_oil: bulk source registration resolves relative quoted file paths" {
  let registry = @resolver.WgslSourceRegistry::default()
  registry.register_source_files([
    {
      rel_path: "shaders/shared/common.wgsl",
      source: (
        #|#define_import_path demo::shared
        #|struct SharedValue {
        #|  tint: vec4<f32>,
        #|}
        #|
      ),
    },
    {
      rel_path: "shaders/effects/main.wgsl",
      source: (
        #|#import "../shared/common.wgsl" SharedValue
        #|fn shade(value: SharedValue) -> vec4<f32> {
        #|  return value.tint;
        #|}
        #|
      ),
    },
  ])
  debug_inspect(
    @resolver.resolve_wgsl_import_file_path_from_registry(
      registry, "shaders/effects/main.wgsl", "\"../shared/common.wgsl\"",
    ),
    content="Some(\"shaders/shared/common.wgsl\")",
  )
  debug_inspect(
    @resolver.resolve_wgsl_import_file_path_from_registry(
      registry, "shaders/effects/main.wgsl", "../shared/common.wgsl",
    ),
    content="Some(\"shaders/shared/common.wgsl\")",
  )
}

///|
test "naga_oil: registry analysis allows duplicate module path candidates" {
  let registry = @resolver.WgslSourceRegistry::default()
  let files : Array[@common.WgslSourceFile] = [
    {
      rel_path: "shaders/demo/a.wgsl",
      source: (
        #|#define_import_path demo::dup
        #|fn a() -> f32 { return 1f; }
        #|
      ),
    },
    {
      rel_path: "shaders/demo/b.wgsl",
      source: (
        #|#define_import_path demo::dup
        #|fn b() -> f32 { return 2f; }
        #|
      ),
    },
  ]
  let diagnostics = registry.analyze_source_files(files)
  debug_inspect(diagnostics.length(), content="0")
  registry.register_source_files(files)
  let candidates = registry.candidate_rel_paths_for_module_path("demo::dup")
  debug_inspect(candidates.length(), content="2")
  debug_inspect(candidates[0], content="\"shaders/demo/a.wgsl\"")
  debug_inspect(candidates[1], content="\"shaders/demo/b.wgsl\"")
}

///|
test "naga_oil: checked bulk registration blocks normalized rel-path conflicts" {
  let registry = @resolver.WgslSourceRegistry::default()
  let diagnostics : Array[@common.WgslDiagnostic] = []
  registry.register_source_files_checked(
    [
      {
        rel_path: "shaders/demo/./shared.wgsl",
        source: (
          #|#define_import_path demo::shared_a
          #|fn a() -> f32 { return 1f; }
          #|
        ),
      },
      {
        rel_path: "shaders/demo/shared.wgsl",
        source: (
          #|#define_import_path demo::shared_b
          #|fn b() -> f32 { return 2f; }
          #|
        ),
      },
    ],
    diagnostics,
  )
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
    registry.registered_source("shaders/demo/shared.wgsl"),
    content="None",
  )
}

///|
test "naga_oil: scan_wgsl_source_files reads a WGSL tree via moonbitlang/x/fs" {
  let files = @resolver.scan_wgsl_source_files(
    moon_wgsl_testdata_path("wgsl_scan"),
    { recursive: true, extensions: [".wgsl"], exclude_prefixes: ["ignored"] },
  ) catch {
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
test "naga_oil: source tree registry infers module names from WGSL file paths" {
  let composer = @compose.Composer::default()
  composer.clear_sources()
  composer.register_source_files([
    {
      rel_path: "plugin.wgsl",
      source: (
        #|fn plugin_value() -> f32 {
        #|  return 2f;
        #|}
        #|
      ),
    },
    {
      rel_path: "root.wgsl",
      source: (
        #|#import plugin
        #|fn main() -> f32 {
        #|  return plugin::plugin_value();
        #|}
        #|
      ),
    },
  ])
  let source = composer.compose_wgsl(
    "root.wgsl",
    @common.WgslComposeOptions::default(),
  ) catch {
    err =>
      abort("expected path-inferred module compose success: \{err.message()}")
  }
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
}

///|
test "naga_oil: scan_wgsl_source_files_checked allows duplicate module candidates" {
  let (files, diagnostics) = @resolver.scan_wgsl_source_files_checked(
    moon_wgsl_testdata_path("wgsl_scan_dups"),
    @common.WgslSourceScanOptions::default(),
  ) catch {
    _ => abort("expected checked WGSL source scan success")
  }
  debug_inspect(files.length(), content="2")
  debug_inspect(diagnostics.length(), content="0")
}
