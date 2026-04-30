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
fn export_test_empty_defines() -> @hashmap.HashMap[String, Bool] {
  @hashmap.HashMap::new()
}

///|
fn export_test_global_registry_composer() -> @compose.Composer {
  @compose.Composer::from_registered_wgsl_source_registry()
}

///|
fn export_test_compose_options(
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
fn register_export_test_shaders() -> Unit {
  @resolver.clear_registered_wgsl_source_registry()
  @resolver.register_wgsl_source_files([
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
fn register_ambiguous_export_test_shaders() -> Unit {
  @resolver.clear_registered_wgsl_source_registry()
  @resolver.register_wgsl_source_files([
    {
      rel_path: "shaders/shared/a.wgsl",
      source: "fn identical_helper() -> f32 {\n  return 1.0;\n}\n",
    },
    {
      rel_path: "shaders/shared/b.wgsl",
      source: "fn identical_helper() -> f32 {\n  return 1.0;\n}\n",
    },
    {
      rel_path: "shaders/effects/ambiguous.wgsl",
      source: "#import \"../shared/a.wgsl\" identical_helper\nfn shade() -> f32 {\n  return identical_helper();\n}\n",
    },
  ])
}

///|
fn register_redirect_export_test_shaders() -> Unit {
  @resolver.clear_registered_wgsl_source_registry()
  @resolver.register_wgsl_source_files([
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
fn register_analysis_alignment_export_test_shaders() -> Unit {
  @resolver.clear_registered_wgsl_source_registry()
  @resolver.register_wgsl_source_files([
    {
      rel_path: "shaders/shared/aligned.wgsl",
      source: "struct SharedParams {\n  value: f32,\n}\n@group(0) @binding(0) var<uniform> shared_params: SharedParams;\nfn read_shared() -> f32 {\n  return shared_params.value;\n}\nfn unused_helper() -> f32 {\n  return 0.0;\n}\n",
    },
    {
      rel_path: "shaders/effects/aligned.wgsl",
      source: "#import \"../shared/aligned.wgsl\" read_shared\nfn shade() -> f32 {\n  return read_shared();\n}\n",
    },
  ])
}

///|
fn register_invalid_struct_member_export_test_shaders() -> Unit {
  @resolver.clear_registered_wgsl_source_registry()
  @resolver.register_wgsl_source_files([
    {
      rel_path: "shaders/shared/invalid_member.wgsl",
      source: "struct BadOutput {\n  bad_: vec3<f32>,\n}\nfn build_bad() -> BadOutput {\n  var out: BadOutput;\n  return out;\n}\n",
    },
    {
      rel_path: "shaders/effects/invalid_member.wgsl",
      source: "#import \"../shared/invalid_member.wgsl\" BadOutput, build_bad\nfn main() -> BadOutput {\n  return build_bad();\n}\n",
    },
  ])
}

///|
test "naga_oil: export_wgsl emits a single tree-shaken WGSL file with source map" {
  register_export_test_shaders()
  let output = @export.export_wgsl_with_options(
    export_test_global_registry_composer(),
    "shaders/effects/main.wgsl",
    export_test_compose_options(export_test_empty_defines(), []),
    { root_items: ["shade"] },
  ) catch {
    err => abort("expected export success: \{err.message()}")
  }
  debug_inspect(output.source.contains("struct SharedParams"), content="true")
  debug_inspect(output.source.contains("struct SharedVertex"), content="true")
  debug_inspect(output.source.contains("fn build_color"), content="true")
  debug_inspect(output.source.contains("fn shade"), content="true")
  debug_inspect(output.source.contains("unused_helper"), content="false")
  debug_inspect(output.source.contains("#import"), content="false")
  debug_inspect(output.source_catalog.length(), content="5")
  debug_inspect(output.source_map.length(), content="4")
  debug_inspect(output.diagnostics.length(), content="0")

  let mapped_paths : Array[String] = []
  for entry in output.source_map {
    mapped_paths.push(entry.rel_path)
  }
  mapped_paths.sort()
  debug_inspect(
    mapped_paths.join(","),
    content="\"shaders/effects/main.wgsl,shaders/shared/common.wgsl,shaders/shared/common.wgsl,shaders/shared/common.wgsl\"",
  )
  @resolver.clear_registered_wgsl_source_registry()
}

///|
test "naga_oil: export rejects invalid struct member identifiers before emission" {
  register_invalid_struct_member_export_test_shaders()
  let mut message = ""
  ignore(
    @export.export_wgsl_with_options(
      export_test_global_registry_composer(),
      "shaders/effects/invalid_member.wgsl",
      export_test_compose_options(export_test_empty_defines(), []),
      { root_items: ["main"] },
    ),
  ) catch {
    err => message = err.message()
  }
  debug_inspect(
    message.contains("requires naga writeback substitution"),
    content="true",
  )
  debug_inspect(message.contains("bad_"), content="true")
  @resolver.clear_registered_wgsl_source_registry()
}

///|
test "naga_oil: compose item extraction and export tree-shaking share dependency analysis" {
  register_analysis_alignment_export_test_shaders()
  let composer = export_test_global_registry_composer()
  let composed = composer.compose_wgsl(
    "shaders/effects/aligned.wgsl",
    export_test_compose_options(export_test_empty_defines(), []),
  ) catch {
    err => abort("expected aligned compose success: \{err.message()}")
  }
  let output = @export.export_wgsl_with_options(
    composer,
    "shaders/effects/aligned.wgsl",
    export_test_compose_options(export_test_empty_defines(), []),
    { root_items: ["shade"] },
  ) catch {
    err => abort("expected aligned export success: \{err.message()}")
  }
  debug_inspect(composed.contains("struct SharedParams"), content="true")
  debug_inspect(composed.contains("var<uniform> shared_params"), content="true")
  debug_inspect(composed.contains("fn read_shared"), content="true")
  debug_inspect(composed.contains("unused_helper"), content="false")
  debug_inspect(output.source.contains("struct SharedParams"), content="true")
  debug_inspect(
    output.source.contains("var<uniform> shared_params"),
    content="true",
  )
  debug_inspect(output.source.contains("fn read_shared"), content="true")
  debug_inspect(output.source.contains("unused_helper"), content="false")
  debug_inspect(output.diagnostics.length(), content="0")
  @resolver.clear_registered_wgsl_source_registry()
}

///|
test "naga_oil: export_wgsl_with_options uses composer-owned session config" {
  @resolver.clear_registered_wgsl_source_registry()
  let composer = @compose.Composer::default()
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
  let output = @export.export_wgsl_with_options(
    composer,
    "shaders/effects/main.wgsl",
    {
      defines: export_test_empty_defines(),
      value_defines: @common.default_wgsl_value_defines(),
      redirects: [],
      additional_imports: [],
    },
    { root_items: ["shade"] },
  ) catch {
    err => abort("expected config-based export success: \{err.message()}")
  }
  debug_inspect(output.source.contains("fn shade"), content="true")
  debug_inspect(output.source.contains("fn build_color"), content="true")
  debug_inspect(output.source_map.length(), content="4")
  debug_inspect(output.diagnostics.length(), content="0")
  debug_inspect(
    @resolver.registered_wgsl_source("shaders/effects/main.wgsl"),
    content="None",
  )
}

///|
test "naga_oil: export_wgsl reports missing tree-shake roots as diagnostics" {
  register_export_test_shaders()
  let output = @export.export_wgsl_with_options(
    export_test_global_registry_composer(),
    "shaders/effects/main.wgsl",
    export_test_compose_options(export_test_empty_defines(), []),
    { root_items: ["missing_entry"] },
  ) catch {
    err => abort("expected export success: \{err.message()}")
  }
  debug_inspect(output.diagnostics.length(), content="1")
  debug_inspect(output.diagnostics[0].severity, content="Warn")
  debug_inspect(
    output.diagnostics[0].symbol_name,
    content="Some(\"missing_entry\")",
  )
  debug_inspect(output.source.contains("unused_helper"), content="false")
  debug_inspect(output.source.contains("fn build_color"), content="true")
  @resolver.clear_registered_wgsl_source_registry()
}

///|
test "naga_oil: export source catalog is scoped to the current dependency closure" {
  register_ambiguous_export_test_shaders()
  let value_defines = @common.default_wgsl_value_defines()
  let catalog = @export.build_registered_wgsl_source_catalog(
    export_test_empty_defines(),
    value_defines,
  )
  let output = @export.export_wgsl_with_options(
    export_test_global_registry_composer(),
    "shaders/effects/ambiguous.wgsl",
    export_test_compose_options(export_test_empty_defines(), []),
    { root_items: ["shade"] },
  ) catch {
    err => abort("expected export success: \{err.message()}")
  }
  debug_inspect(catalog.length(), content="3")
  debug_inspect(output.source_catalog.length(), content="2")
  debug_inspect(output.source_map.length(), content="2")
  debug_inspect(output.diagnostics.length(), content="0")

  let helper_paths : Array[String] = []
  for entry in output.source_catalog {
    if entry.symbol_name == "identical_helper" {
      helper_paths.push(entry.rel_path)
    }
  }
  helper_paths.sort()
  debug_inspect(helper_paths.join(","), content="\"shaders/shared/a.wgsl\"")
  @resolver.clear_registered_wgsl_source_registry()
}

///|
test "naga_oil: export_wgsl_with_redirects rewrites dependencies before tree-shaking" {
  register_redirect_export_test_shaders()
  let output = @export.export_wgsl_with_options(
    export_test_global_registry_composer(),
    "shaders/effects/redirect.wgsl",
    export_test_compose_options(export_test_empty_defines(), [
      { from_name: "build_shadow", to_name: "build_color" },
    ]),
    { root_items: ["shade"] },
  ) catch {
    err => abort("expected redirect-aware export success: \{err.message()}")
  }
  debug_inspect(output.source.contains("fn build_color"), content="true")
  debug_inspect(output.source.contains("fn build_shadow"), content="false")
  debug_inspect(
    output.source.contains("return build_color(vertex);"),
    content="true",
  )
  debug_inspect(
    output.source.contains("return build_shadow(vertex);"),
    content="false",
  )
  debug_inspect(output.source_catalog.length(), content="5")
  debug_inspect(output.source_map.length(), content="4")
  debug_inspect(output.diagnostics.length(), content="0")
  @resolver.clear_registered_wgsl_source_registry()
}

///|
test "naga_oil: export warns when a source-level redirect never matches" {
  register_redirect_export_test_shaders()
  let output = @export.export_wgsl_with_options(
    export_test_global_registry_composer(),
    "shaders/effects/redirect.wgsl",
    export_test_compose_options(export_test_empty_defines(), [
      { from_name: "missing_shadow", to_name: "build_color" },
    ]),
    { root_items: ["shade"] },
  ) catch {
    err =>
      abort("expected redirect diagnostic export success: \{err.message()}")
  }
  debug_inspect(output.diagnostics.length(), content="1")
  debug_inspect(output.diagnostics[0].severity, content="Warn")
  debug_inspect(
    output.diagnostics[0].message,
    content="\"symbol redirect did not match any source identifier\"",
  )
  debug_inspect(
    output.diagnostics[0].symbol_name,
    content="Some(\"missing_shadow\")",
  )
  @resolver.clear_registered_wgsl_source_registry()
}
