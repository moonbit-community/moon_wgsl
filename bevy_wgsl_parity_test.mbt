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
fn bevy_parity_defines(names : Array[String]) -> Map[String, Bool] {
  let defines : Map[String, Bool] = Map([])
  for name in names {
    defines.set(name, true)
  }
  defines
}

///|
fn bevy_parity_value_defines() -> Map[String, @common.ShaderDefValue] {
  let value_defines = @common.default_wgsl_value_defines()
  value_defines.remove("PER_OBJECT_BUFFER_BATCH_SIZE")
  value_defines
}

///|
fn bevy_prepared_catalog_entry_text(
  prepared : @common.PreparedWgslSource,
  entry : @common.WgslSourceCatalogEntry,
) -> String {
  for source_file in prepared.source_files {
    if source_file.rel_path == entry.rel_path &&
      entry.source_start >= 0 &&
      entry.source_end >= entry.source_start &&
      entry.source_end <= source_file.source.length() {
      return source_file.source[entry.source_start:entry.source_end].to_owned()
    }
  }
  ""
}

///|
fn bevy_parity_compose(rel_path : String, defines : Array[String]) -> String {
  let composer = @compose.Composer::default()
  composer.clear_sources()
  composer.register_source_tree(
    "testdata/bevy_wgsl",
    @common.WgslSourceScanOptions::default(),
  ) catch {
    _ => abort("expected Bevy fixture registration success")
  }
  composer.compose_wgsl(rel_path, {
    defines: bevy_parity_defines(defines),
    value_defines: bevy_parity_value_defines(),
    redirects: [],
    additional_imports: [],
  }) catch {
    err =>
      abort("expected complete Bevy WGSL compose success: \{err.message()}")
  }
}

///|
fn bevy_parity_forward_defines() -> Array[String] {
  [
    "VERTEX_POSITIONS", "VERTEX_NORMALS", "VERTEX_UVS", "VERTEX_UVS_A", "VERTEX_COLORS",
    "VERTEX_OUTPUT_INSTANCE_INDEX", "MAY_DISCARD",
  ]
}

///|
test "naga_oil parity: import-only Bevy forward root tree-shakes to empty" {
  let source = bevy_parity_compose(
    "mgstudio/render/renderer/mesh3d_bevy_forward.wgsl",
    bevy_parity_forward_defines(),
  )
  debug_inspect(source.trim().length(), content="0")
}

///|
test "naga_oil parity: import-only Bevy prepass root tree-shakes to empty" {
  let source = bevy_parity_compose(
    "mgstudio/render/renderer/mesh3d_bevy_prepass.wgsl",
    bevy_parity_forward_defines() +
    ["PREPASS_FRAGMENT", "NORMAL_PREPASS", "BINDLESS"],
  )
  debug_inspect(source.trim().length(), content="0")
}

///|
test "naga_oil parity: import-only Bevy mesh root tree-shakes to empty" {
  let source = bevy_parity_compose(
    "mgstudio/render/renderer/mesh3d_bevy_mesh_only.wgsl",
    bevy_parity_forward_defines(),
  )
  debug_inspect(source.trim().length(), content="0")
}

///|
test "naga_oil parity: Bevy PBR fragment resolves aliased clustered lights" {
  let source = bevy_parity_compose(
    "bevy_pbr/src/render/pbr.wgsl",
    bevy_parity_forward_defines(),
  )
  debug_inspect(
    source.contains("view_bindings::clustered_lights"),
    content="false",
  )
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(
    source.contains("shadows__view_bindings__view"),
    content="false",
  )
  debug_inspect(source.contains("vec3<f32 >="), content="false")
  debug_inspect(source.contains("var output: vec3<f32>;"), content="true")
  debug_inspect(source.contains("output = world_normal"), content="true")
  debug_inspect(
    source.contains("var output: vec3<f32> = world_normal"),
    content="false",
  )
}

///|
test "naga_oil parity: Bevy PBR functions resolves local view bindings alias" {
  let source = bevy_parity_compose(
    "bevy_pbr/src/render/pbr_functions.wgsl",
    bevy_parity_forward_defines(),
  )
  debug_inspect(
    source.contains("view_bindings::clustered_lights"),
    content="false",
  )
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
}

///|
test "naga_oil parity: Bevy lighting keeps tree-shaken alias const targets live" {
  let composer = @compose.Composer::default()
  composer.clear_sources()
  composer.register_source_tree(
    "testdata/bevy_wgsl",
    @common.WgslSourceScanOptions::default(),
  ) catch {
    _ => abort("expected Bevy fixture registration success")
  }
  composer.register_source(
    "mgstudio/render/renderer/issue8_lighting_repro.wgsl",
    (
      #|#import bevy_pbr::lighting as lighting
      #|fn entry() -> vec3<f32> {
      #|  var input: lighting::LightingInput;
      #|  return lighting::spot_light(0u, &input, true);
      #|}
      #|
    ),
  )
  let source = composer.compose_wgsl(
    "mgstudio/render/renderer/issue8_lighting_repro.wgsl",
    {
      defines: bevy_parity_defines(bevy_parity_forward_defines()),
      value_defines: bevy_parity_value_defines(),
      redirects: [],
      additional_imports: [],
    },
  ) catch {
    err => abort("expected issue 8 lighting compose success: \{err.message()}")
  }
  debug_inspect(
    source.contains("& types__POINT_LIGHT_FLAGS_SPOT_LIGHT_Y_NEGATIVE"),
    content="false",
  )
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(
    source.contains("& POINT_LIGHT_FLAGS_SPOT_LIGHT_Y_NEGATIVE") &&
    source.contains("POINT_LIGHT_FLAGS_SPOT_LIGHT_Y_NEGATIVEX_naga_oil_mod_X"),
    content="true",
  )
  debug_inspect(
    source.contains("view_bindings::clustered_lights"),
    content="false",
  )
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
}

///|
fn issue10_alias_redirect_stress_module(declaration_count : Int) -> String {
  let mut source = "#define_import_path stress::many\n"
  for i in 0..<declaration_count {
    source = source + "const item_\{i}: u32 = \{i}u;\n"
  }
  source
}

///|
fn issue10_alias_redirect_stress_root(import_count : Int) -> String {
  let mut source = ""
  for _ in 0..<import_count {
    source = source + "#import stress::many as many\n"
  }
  source +
  (
    #|fn entry() -> u32 {
    #|  return many::item_0;
    #|}
    #|
  )
}

///|
test "issue 10: cached alias redirect stress compose completes" {
  let composer = @compose.Composer::default()
  composer.clear_sources()
  composer.register_source(
    "stress/many.wgsl",
    issue10_alias_redirect_stress_module(120),
  )
  composer.register_source(
    "stress/root.wgsl",
    issue10_alias_redirect_stress_root(80),
  )
  let source = composer.compose_wgsl("stress/root.wgsl", {
    defines: empty_bool_defines(),
    value_defines: @common.default_wgsl_value_defines(),
    redirects: [],
    additional_imports: [],
  }) catch {
    err =>
      abort("expected issue 10 alias redirect stress success: \{err.message()}")
  }
  debug_inspect(source.contains("many::item_0"), content="false")
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(source.contains("fn entry() -> u32"), content="true")
}

///|
test "issue 10: Bevy PBR forward fragment compose completes" {
  let source = bevy_parity_compose(
    "bevy_pbr/src/render/pbr.wgsl",
    bevy_parity_forward_defines(),
  )
  debug_inspect(source.contains("fn fragment"), content="true")
  debug_inspect(source.contains("view_bindings::"), content="false")
}

///|
test "issue 11: Bevy PBR point-light flag uses emitted symbol name" {
  let source = bevy_parity_compose(
    "bevy_pbr/src/render/pbr.wgsl",
    bevy_parity_forward_defines(),
  )
  debug_inspect(
    source.contains("const types__POINT_LIGHT_FLAGS_SPOT_LIGHT_Y_NEGATIVE"),
    content="false",
  )
  debug_inspect(
    source.contains("& types__POINT_LIGHT_FLAGS_SPOT_LIGHT_Y_NEGATIVE"),
    content="false",
  )
  debug_inspect(
    source.contains("const lighting__POINT_LIGHT_FLAGS_SPOT_LIGHT_Y_NEGATIVE"),
    content="false",
  )
  debug_inspect(
    source.contains(
      "const POINT_LIGHT_FLAGS_SPOT_LIGHT_Y_NEGATIVEX_naga_oil_mod_X",
    ),
    content="true",
  )
  debug_inspect(
    source.contains("& lighting__POINT_LIGHT_FLAGS_SPOT_LIGHT_Y_NEGATIVE"),
    content="false",
  )
  debug_inspect(
    source.contains("& POINT_LIGHT_FLAGS_SPOT_LIGHT_Y_NEGATIVEX_naga_oil_mod_X"),
    content="true",
  )
}

///|
test "issue 13: nested alias global references use emitted symbol identity" {
  let composer = @compose.Composer::default()
  composer.clear_sources()
  composer.register_source(
    "bevy_pbr/src/render/mesh_view_bindings.wgsl",
    (
      #|#define_import_path bevy_pbr::mesh_view_bindings
      #|struct View {
      #|  value: f32,
      #|}
      #|@group(0) @binding(0) var<uniform> view: View;
      #|
    ),
  )
  composer.register_source(
    "bevy_pbr/src/render/shadows.wgsl",
    (
      #|#define_import_path bevy_pbr::shadows
      #|#import bevy_pbr::mesh_view_bindings as view_bindings
      #|fn shadow_value() -> f32 {
      #|  return view_bindings::view.value;
      #|}
      #|
    ),
  )
  composer.register_source(
    "bevy_pbr/src/render/pbr_functions.wgsl",
    (
      #|#define_import_path bevy_pbr::pbr_functions
      #|#import bevy_pbr::{
      #|  mesh_view_bindings as view_bindings,
      #|  shadows,
      #|}
      #|fn pbr_value() -> f32 {
      #|  return view_bindings::view.value + shadows::shadow_value();
      #|}
      #|
    ),
  )
  composer.register_source(
    "bevy_pbr/src/render/pbr.wgsl",
    (
      #|#define_import_path bevy_pbr::pbr
      #|#import bevy_pbr::pbr_functions::pbr_value
      #|fn fragment() -> f32 {
      #|  return pbr_value();
      #|}
      #|
    ),
  )
  let source = composer.compose_wgsl("bevy_pbr/src/render/pbr.wgsl", {
    defines: empty_bool_defines(),
    value_defines: @common.default_wgsl_value_defines(),
    redirects: [],
    additional_imports: [],
  }) catch {
    err =>
      abort("expected issue 13 nested alias compose success: \{err.message()}")
  }
  debug_inspect(source.contains("view_bindings::view"), content="false")
  debug_inspect(
    source.contains("shadows__view_bindings__view"),
    content="false",
  )
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
}

///|
test "naga_oil parity: prepared Bevy catalog resolves alias-qualified bindings" {
  let composer = @compose.Composer::default()
  composer.clear_sources()
  composer.register_source_tree(
    "testdata/bevy_wgsl",
    @common.WgslSourceScanOptions::default(),
  ) catch {
    _ => abort("expected Bevy fixture registration success")
  }
  composer.register_source(
    "mgstudio/render/renderer/issue8_lighting_repro.wgsl",
    (
      #|#import bevy_pbr::lighting as lighting
      #|fn entry() -> vec3<f32> {
      #|  var input: lighting::LightingInput;
      #|  return lighting::spot_light(0u, &input, true);
      #|}
      #|
    ),
  )
  let prepared = composer.prepare_wgsl_source(
    "mgstudio/render/renderer/issue8_lighting_repro.wgsl",
    {
      defines: bevy_parity_defines(bevy_parity_forward_defines()),
      value_defines: bevy_parity_value_defines(),
      redirects: [],
      additional_imports: [],
    },
  ) catch {
    err => abort("expected Bevy prepared source success: \{err.message()}")
  }
  let mut unresolved_entries = 0
  let mut resolved_entries = 0
  let mut unresolved_source_files = 0
  for entry in prepared.source_catalog {
    let entry_text = bevy_prepared_catalog_entry_text(prepared, entry)
    if entry_text.contains("view_bindings::clustered_lights") {
      unresolved_entries = unresolved_entries + 1
    }
    if entry_text.contains("clustered_lightsX_naga_oil_mod_X") {
      resolved_entries = resolved_entries + 1
    }
  }
  for source_file in prepared.source_files {
    if source_file.source.contains("view_bindings::clustered_lights") {
      unresolved_source_files = unresolved_source_files + 1
    }
  }
  debug_inspect(prepared.source_files.length(), content="1")
  debug_inspect(unresolved_source_files, content="0")
  debug_inspect(unresolved_entries, content="0")
  debug_inspect(resolved_entries > 0, content="true")
}
