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
fn register_export_test_shaders() -> Unit {
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
fn register_ambiguous_export_test_shaders() -> Unit {
  @moon_wgsl.clear_registered_wgsl_source_registry()
  @moon_wgsl.register_wgsl_source_files([
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
test "naga_oil: export_wgsl emits a single tree-shaken WGSL file with source map" {
  register_export_test_shaders()
  let value_defines = @moon_wgsl.default_wgsl_value_defines()
  let modules = @moon_wgsl.copy_registered_wgsl_import_module_paths()
  let output = @moon_wgsl.Composer::default().export_wgsl(
    "",
    "shaders/effects/main.wgsl",
    export_test_empty_defines(),
    value_defines,
    modules,
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
  @moon_wgsl.clear_registered_wgsl_source_registry()
}

///|
test "naga_oil: export_wgsl reports missing tree-shake roots as diagnostics" {
  register_export_test_shaders()
  let value_defines = @moon_wgsl.default_wgsl_value_defines()
  let modules = @moon_wgsl.copy_registered_wgsl_import_module_paths()
  let output = @moon_wgsl.Composer::default().export_wgsl(
    "",
    "shaders/effects/main.wgsl",
    export_test_empty_defines(),
    value_defines,
    modules,
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
  @moon_wgsl.clear_registered_wgsl_source_registry()
}

///|
test "naga_oil: source catalog exposes ambiguous source-map candidates" {
  register_ambiguous_export_test_shaders()
  let value_defines = @moon_wgsl.default_wgsl_value_defines()
  let modules = @moon_wgsl.copy_registered_wgsl_import_module_paths()
  let catalog = @moon_wgsl.build_registered_wgsl_source_catalog(
    export_test_empty_defines(),
    value_defines,
  )
  let output = @moon_wgsl.Composer::default().export_wgsl(
    "",
    "shaders/effects/ambiguous.wgsl",
    export_test_empty_defines(),
    value_defines,
    modules,
    { root_items: ["shade"] },
  ) catch {
    err => abort("expected export success: \{err.message()}")
  }
  debug_inspect(catalog.length(), content="3")
  debug_inspect(output.source_catalog.length(), content="3")
  debug_inspect(output.source_map.length(), content="1")
  debug_inspect(output.diagnostics.length(), content="1")
  debug_inspect(
    output.diagnostics[0].message,
    content="\"source map entry is ambiguous for declaration\"",
  )
  debug_inspect(
    output.diagnostics[0].symbol_name,
    content="Some(\"identical_helper\")",
  )

  let helper_paths : Array[String] = []
  for entry in output.source_catalog {
    if entry.symbol_name == "identical_helper" {
      helper_paths.push(entry.rel_path)
    }
  }
  helper_paths.sort()
  debug_inspect(
    helper_paths.join(","),
    content="\"shaders/shared/a.wgsl,shaders/shared/b.wgsl\"",
  )
  @moon_wgsl.clear_registered_wgsl_source_registry()
}

///|
test "naga_oil: export_wgsl_with_redirects rewrites dependencies before tree-shaking" {
  register_redirect_export_test_shaders()
  let value_defines = @moon_wgsl.default_wgsl_value_defines()
  let modules = @moon_wgsl.copy_registered_wgsl_import_module_paths()
  let output = @moon_wgsl.Composer::default().export_wgsl_with_redirects(
    "",
    "shaders/effects/redirect.wgsl",
    export_test_empty_defines(),
    value_defines,
    modules,
    { root_items: ["shade"] },
    [{ from_name: "build_shadow", to_name: "build_color" }],
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
  @moon_wgsl.clear_registered_wgsl_source_registry()
}
