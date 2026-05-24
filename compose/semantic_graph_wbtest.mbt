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
test "semantic alias graph resolves global binding member access" {
  let source =
    #|fn read() -> u32 {
    #|  return view_bindings::clustered_lights.data[0u].value;
    #|}
    #|
  let requested_paths : Array[String] = []
  collect_wgsl_semantic_alias_requested_paths(
    source, "view_bindings", requested_paths,
  ) catch {
    _ => abort("expected semantic alias collection to parse valid WGSL")
  }
  debug_inspect(requested_paths.join(","), content="\"clustered_lights\"")
}

///|
test "semantic import alias prefix policy sanitizes aliases" {
  debug_inspect(
    wgsl_semantic_import_alias_prefix("demo::math"),
    content="\"demo_math\"",
  )
  debug_inspect(
    wgsl_semantic_import_alias_prefix("\"quoted path\""),
    content="\"import\"",
  )
  debug_inspect(
    wgsl_semantic_import_alias_prefix("bad-name::Item"),
    content="\"bad_name_Item\"",
  )
}

///|
test "semantic reference matcher includes address-of alias member access" {
  let source =
    #|fn point_light(light_id: u32) -> u32 {
    #|  let light = &view_bindings::clustered_lights.data[light_id];
    #|  return (*light).flags;
    #|}
    #|
  debug_inspect(
    wgsl_semantic_source_contains_reference_path(
      source, "view_bindings::clustered_lights",
    ) catch {
      _ => abort("expected semantic matcher to parse valid WGSL")
    },
    content="true",
  )
}

///|
test "semantic alias graph resolves nested module alias paths" {
  let source =
    #|fn read() -> u32 {
    #|  return pbr::bindings::view.value;
    #|}
    #|
  let requested_paths : Array[String] = []
  collect_wgsl_semantic_alias_requested_paths(source, "pbr", requested_paths) catch {
    _ => abort("expected semantic alias collection to parse valid WGSL")
  }
  debug_inspect(requested_paths.join(","), content="\"bindings::view\"")
}

///|
test "semantic reference matcher distinguishes qualified suffixes" {
  let source =
    #|fn entry() -> u32 {
    #|  return other::Item();
    #|}
    #|
  debug_inspect(
    wgsl_semantic_source_contains_reference_path(source, "Item") catch {
      _ => abort("expected semantic matcher to parse valid WGSL")
    },
    content="false",
  )
  debug_inspect(
    wgsl_semantic_source_contains_reference_path(source, "other::Item") catch {
      _ => abort("expected semantic matcher to parse valid WGSL")
    },
    content="true",
  )
}

///|
test "semantic reference matcher keeps same-name global declaration references" {
  let source =
    #|fn convert_to_linear_rgba(color: vec4<f32>) -> vec4<f32> {
    #|  return color;
    #|}
    #|fn shade(color: vec4<f32>) -> vec4<f32> {
    #|  return convert_to_linear_rgba(color);
    #|}
    #|
  debug_inspect(
    wgsl_semantic_source_contains_reference_path(
      source, "convert_to_linear_rgba",
    ) catch {
      _ => abort("expected semantic matcher to parse valid WGSL")
    },
    content="true",
  )
}

///|
test "semantic reference matcher ignores struct member names" {
  let source =
    #|fn entry(input: Input) -> f32 {
    #|  return lighting::spot_light(input.value).x + input.member;
    #|}
    #|
  debug_inspect(
    wgsl_semantic_source_contains_reference_path(source, "lighting::spot_light") catch {
      _ => abort("expected semantic matcher to parse valid WGSL")
    },
    content="true",
  )
  debug_inspect(
    wgsl_semantic_source_contains_reference_path(source, "member") catch {
      _ => abort("expected semantic matcher to parse valid WGSL")
    },
    content="false",
  )
}

///|
test "semantic import target plan resolves alias-qualified binding item" {
  let registry = WgslSourceRegistry::default()
  ignore(
    registry.register_source(
      "mesh_view_bindings.wgsl",
      "#define_import_path bevy_pbr::mesh_view_bindings\n" +
      "var<storage, read> clustered_lights: u32;\n",
      None,
    ),
  )
  let targets = [
    WgslImportTarget::{
      raw_path: "bevy_pbr::mesh_view_bindings",
      alias_name: "view_bindings",
    },
  ]
  let plans = build_wgsl_semantic_import_target_plans(
    "fn read() -> u32 { return view_bindings::clustered_lights; }\n",
    "root.wgsl",
    targets,
    registry,
    registry.copy_import_module_paths(),
  ) catch {
    _ => abort("expected semantic import target planning to parse valid WGSL")
  }
  debug_inspect(plans.unresolved_targets.length(), content="0")
  debug_inspect(plans.plans.length(), content="1")
  debug_inspect(
    plans.plans[0].requested_items.join(","),
    content="\"clustered_lights\"",
  )
}

///|
test "semantic import target plan expands nested module aliases" {
  let registry = WgslSourceRegistry::default()
  ignore(
    registry.register_source("pbr.wgsl", "#define_import_path bevy_pbr\n", None),
  )
  ignore(
    registry.register_source(
      "bindings.wgsl",
      "#define_import_path bevy_pbr::bindings\n" +
      "struct View { value: u32 }\n" +
      "var<uniform> view: View;\n",
      None,
    ),
  )
  let targets = [WgslImportTarget::{ raw_path: "bevy_pbr", alias_name: "pbr" }]
  let plans = build_wgsl_semantic_import_target_plans(
    "fn read() -> u32 { return pbr::bindings::view.value; }\n",
    "root.wgsl",
    targets,
    registry,
    registry.copy_import_module_paths(),
  ) catch {
    _ => abort("expected semantic import target planning to parse valid WGSL")
  }
  debug_inspect(plans.unresolved_targets.length(), content="0")
  debug_inspect(plans.plans.length(), content="1")
  debug_inspect(plans.plans[0].module_alias, content="\"pbr::bindings\"")
  debug_inspect(plans.plans[0].requested_items.join(","), content="\"view\"")
}

///|
test "semantic import target plan prefers exact nested module over base item split" {
  let registry = WgslSourceRegistry::default()
  ignore(
    registry.register_source("pbr.wgsl", "#define_import_path bevy_pbr\n", None),
  )
  ignore(
    registry.register_source(
      "prepass_bindings.wgsl",
      "#define_import_path bevy_pbr::prepass_bindings\n" +
      "struct PreviousViewUniforms { value: f32 }\n" +
      "var<uniform> previous_view_uniforms: PreviousViewUniforms;\n",
      None,
    ),
  )
  let targets = [
    WgslImportTarget::{ raw_path: "bevy_pbr::prepass_bindings", alias_name: "" },
  ]
  let plans = build_wgsl_semantic_import_target_plans(
    "",
    "root.wgsl",
    targets,
    registry,
    registry.copy_import_module_paths(),
  ) catch {
    _ => abort("expected semantic import target planning to parse valid WGSL")
  }
  debug_inspect(plans.unresolved_targets.length(), content="0")
  debug_inspect(plans.plans.length(), content="1")
  debug_inspect(
    plans.plans[0].resolved_module.module_path(),
    content="\"bevy_pbr::prepass_bindings\"",
  )
  debug_inspect(plans.plans[0].import_full_module, content="true")
  debug_inspect(plans.plans[0].requested_items.length(), content="0")
}

///|
test "semantic import target plan splits nested item import when source uses leaf" {
  let registry = WgslSourceRegistry::default()
  ignore(
    registry.register_source(
      "mesh_bindings.wgsl",
      "#define_import_path bevy_pbr::mesh_bindings\n" +
      "var<uniform> mesh: u32;\n",
      None,
    ),
  )
  let targets = [
    WgslImportTarget::{
      raw_path: "bevy_pbr::mesh_bindings::mesh",
      alias_name: "",
    },
  ]
  let plans = build_wgsl_semantic_import_target_plans(
    "fn read() -> u32 { return mesh; }\n",
    "root.wgsl",
    targets,
    registry,
    registry.copy_import_module_paths(),
  ) catch {
    _ => abort("expected semantic import target planning to parse valid WGSL")
  }
  debug_inspect(plans.unresolved_targets.length(), content="0")
  debug_inspect(plans.plans.length(), content="1")
  debug_inspect(
    plans.plans[0].resolved_module.module_path(),
    content="\"bevy_pbr::mesh_bindings\"",
  )
  debug_inspect(plans.plans[0].import_full_module, content="false")
  debug_inspect(plans.plans[0].requested_items.join(","), content="\"mesh\"")
}

///|
test "semantic import target plans follow first AST reference order" {
  let registry = WgslSourceRegistry::default()
  ignore(
    registry.register_source(
      "late.wgsl",
      "#define_import_path test::late\n",
      None,
    ),
  )
  ignore(
    registry.register_source(
      "early.wgsl",
      "#define_import_path test::early\n",
      None,
    ),
  )
  let targets = [
    WgslImportTarget::{ raw_path: "test::late::late_value", alias_name: "" },
    WgslImportTarget::{ raw_path: "test::early::EarlyType", alias_name: "" },
  ]
  let source =
    #|#import test::{late::late_value, early::EarlyType}
    #|
    #|fn read(input: EarlyType) -> u32 {
    #|  return late_value + input.value;
    #|}
    #|
  let plans = build_wgsl_semantic_import_target_plans(
    source,
    "root.wgsl",
    targets,
    registry,
    registry.copy_import_module_paths(),
  ) catch {
    _ => abort("expected semantic import target planning to parse valid WGSL")
  }
  debug_inspect(plans.plans.length(), content="2")
  debug_inspect(
    plans.plans[0].resolved_module.rel_path(),
    content="\"early.wgsl\"",
  )
  debug_inspect(
    plans.plans[0].requested_items.join(","),
    content="\"EarlyType\"",
  )
  debug_inspect(
    plans.plans[1].resolved_module.rel_path(),
    content="\"late.wgsl\"",
  )
  debug_inspect(
    plans.plans[1].requested_items.join(","),
    content="\"late_value\"",
  )
}

///|
test "semantic import target plans follow naga-oil substitution use order" {
  let registry = WgslSourceRegistry::default()
  ignore(
    registry.register_source(
      "forward.wgsl",
      "#define_import_path test::forward\n",
      None,
    ),
  )
  ignore(
    registry.register_source(
      "bindings.wgsl",
      "#define_import_path test::bindings\n",
      None,
    ),
  )
  let targets = [
    WgslImportTarget::{
      raw_path: "test::forward::VertexOutput",
      alias_name: "",
    },
    WgslImportTarget::{ raw_path: "test::bindings::material", alias_name: "" },
  ]
  let source =
    #|#import test::forward::VertexOutput
    #|#import test::bindings::material
    #|
    #|struct RootData {
    #|  material: u32,
    #|}
    #|
    #|fn read(input: VertexOutput) -> u32 {
    #|  return material.value + input.value;
    #|}
    #|
  let plans = build_wgsl_semantic_import_target_plans(
    source,
    "root.wgsl",
    targets,
    registry,
    registry.copy_import_module_paths(),
  ) catch {
    _ => abort("expected semantic import target planning to parse valid WGSL")
  }
  debug_inspect(plans.plans.length(), content="2")
  debug_inspect(
    plans.plans[0].resolved_module.rel_path(),
    content="\"bindings.wgsl\"",
  )
  debug_inspect(
    plans.plans[0].requested_items.join(","),
    content="\"material\"",
  )
  debug_inspect(
    plans.plans[1].resolved_module.rel_path(),
    content="\"forward.wgsl\"",
  )
}
