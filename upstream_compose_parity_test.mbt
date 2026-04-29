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
fn upstream_parity_empty_defines() -> @hashmap.HashMap[String, Bool] {
  @hashmap.HashMap::new()
}

///|
fn upstream_parity_bool_defines(
  names : Array[String],
) -> @hashmap.HashMap[String, Bool] {
  let defines : @hashmap.HashMap[String, Bool] = @hashmap.HashMap::new()
  for name in names {
    defines.set(name, true)
  }
  defines
}

///|
fn upstream_parity_compose_options(
  defines : @hashmap.HashMap[String, Bool],
) -> @moon_wgsl.WgslComposeOptions {
  {
    assets_base: "",
    defines,
    value_defines: @moon_wgsl.default_wgsl_value_defines(),
    redirects: [],
    additional_imports: [],
    preserve_imported_entry_points: true,
  }
}

///|
fn upstream_parity_composer(case_name : String) -> @moon_wgsl.Composer {
  @moon_wgsl.clear_registered_wgsl_source_registry()
  let composer = @moon_wgsl.Composer::default()
  composer.clear_registered_wgsl_source_registry()
  composer.register_wgsl_source_tree(
    "testdata/upstream_compose/\{case_name}",
    @moon_wgsl.WgslSourceScanOptions::default(),
  ) catch {
    _ => abort("expected upstream fixture registration success")
  }
  composer
}

///|
fn upstream_mirror_composer(case_name : String) -> @moon_wgsl.Composer {
  @moon_wgsl.clear_registered_wgsl_source_registry()
  let composer = @moon_wgsl.Composer::default()
  composer.clear_registered_wgsl_source_registry()
  composer.register_wgsl_source_tree(
    "testdata/naga_oil_upstream/compose_tests/\{case_name}",
    @moon_wgsl.WgslSourceScanOptions::default(),
  ) catch {
    _ => abort("expected upstream mirror fixture registration success")
  }
  composer
}

///|
fn upstream_mirror_compose_case(
  case_name : String,
  rel_path : String,
  defines : @hashmap.HashMap[String, Bool],
) -> String {
  upstream_mirror_composer(case_name).compose_wgsl(
    rel_path,
    upstream_parity_compose_options(defines),
  ) catch {
    err =>
      abort(
        "expected upstream mirror compose success for \{case_name}/\{rel_path}: \{err.message()}",
      )
  }
}

///|
fn upstream_parity_compose_case(
  case_name : String,
  rel_path : String,
  defines : @hashmap.HashMap[String, Bool],
) -> String {
  upstream_parity_composer(case_name).compose_wgsl(
    rel_path,
    upstream_parity_compose_options(defines),
  ) catch {
    err =>
      abort(
        "expected upstream compose success for \{case_name}/\{rel_path}: \{err.message()}",
      )
  }
}

///|
fn upstream_parity_export_case(
  case_name : String,
  rel_path : String,
  root_items : Array[String],
  defines : @hashmap.HashMap[String, Bool],
) -> @moon_wgsl.WgslExportOutput {
  upstream_parity_composer(case_name).export_wgsl_with_options(
    rel_path,
    upstream_parity_compose_options(defines),
    { root_items, },
  ) catch {
    err =>
      abort(
        "expected upstream export success for \{case_name}/\{rel_path}: \{err.message()}",
      )
  }
}

///|
fn upstream_parity_count_occurrences(text : String, pattern : String) -> Int {
  if pattern == "" {
    return 0
  }
  let mut parts = 0
  for _ in text.split(pattern) {
    parts = parts + 1
  }
  if parts == 0 {
    0
  } else {
    parts - 1
  }
}

///|
test "naga_oil upstream: simple compose exports imported function body" {
  let output = upstream_parity_export_case(
    "simple",
    "top.wgsl",
    ["main"],
    upstream_parity_empty_defines(),
  )
  debug_inspect(output.source.contains("fn Inc__hello"), content="true")
  debug_inspect(output.source.contains("fn main"), content="true")
  debug_inspect(output.source.contains("Inc::"), content="false")
  debug_inspect(output.source.contains("#import"), content="false")
}

///|
test "naga_oil upstream: big shaderdefs keep deep active branches" {
  let define_names : Array[String] = []
  for i in 1..<68 {
    define_names.push("a\{i}")
  }
  let source = upstream_parity_compose_case(
    "big_shaderdefs",
    "top.wgsl",
    upstream_parity_bool_defines(define_names),
  )
  debug_inspect(source.contains("x = 1.0;"), content="true")
  debug_inspect(source.contains("mod::f"), content="false")
}

///|
test "naga_oil upstream: item import export keeps only used declarations" {
  let output = upstream_parity_export_case(
    "item_import",
    "top.wgsl",
    ["main", "other"],
    upstream_parity_empty_defines(),
  )
  debug_inspect(output.source.contains("const X"), content="true")
  debug_inspect(output.source.contains("const Y"), content="true")
  debug_inspect(output.source.contains("fn double"), content="true")
  debug_inspect(output.source.contains("const Z"), content="false")
  debug_inspect(output.source.contains("fn triple"), content="false")
  debug_inspect(output.source.contains("var something"), content="false")
}

///|
test "naga_oil upstream: conditional import selects module a when shader def is enabled" {
  let source = upstream_parity_compose_case(
    "conditional_import",
    "top.wgsl",
    upstream_parity_bool_defines(["USE_A"]),
  )
  debug_inspect(source.contains("const C: u32 = 1u;"), content="true")
  debug_inspect(source.contains("const C: u32 = 2u;"), content="false")
}

///|
test "naga_oil upstream: conditional import selects module b when shader def is disabled" {
  let source = upstream_parity_compose_case(
    "conditional_import",
    "top.wgsl",
    upstream_parity_empty_defines(),
  )
  debug_inspect(source.contains("const C: u32 = 2u;"), content="true")
  debug_inspect(source.contains("const C: u32 = 1u;"), content="false")
}

///|
test "naga_oil upstream: missing conditional import reports a compose failure" {
  let composer = upstream_parity_composer("conditional_import_fail")
  let mut message = ""
  ignore(
    composer.compose_wgsl(
      "top.wgsl",
      upstream_parity_compose_options(upstream_parity_empty_defines()),
    ),
  ) catch {
    err => message = err.message()
  }
  debug_inspect(
    message.contains("failed to resolve shader import"),
    content="true",
  )
  debug_inspect(message.contains("b"), content="true")
}

///|
test "naga_oil upstream: nested missing conditional import reports a compose failure" {
  let composer = upstream_parity_composer("conditional_import_fail")
  let mut message = ""
  ignore(
    composer.compose_wgsl(
      "top_nested.wgsl",
      upstream_parity_compose_options(upstream_parity_empty_defines()),
    ),
  ) catch {
    err => message = err.message()
  }
  debug_inspect(
    message.contains("failed to resolve shader import"),
    content="true",
  )
  debug_inspect(message.contains("b"), content="true")
}

///|
test "naga_oil upstream: missing import in shader source reports a compose failure" {
  let composer = upstream_mirror_composer("error_test")
  let mut message = ""
  ignore(
    composer.compose_wgsl(
      "include.wgsl",
      upstream_parity_compose_options(upstream_parity_empty_defines()),
    ),
  ) catch {
    err => message = err.message()
  }
  debug_inspect(
    message.contains("failed to resolve shader import"),
    content="true",
  )
  debug_inspect(message.contains("missing"), content="true")
}

///|
test "naga_oil upstream: import in declaration keeps imported const dependency" {
  let source = upstream_parity_compose_case(
    "const_in_decl",
    "top.wgsl",
    upstream_parity_empty_defines(),
  )
  debug_inspect(
    source.contains("const bind__consts__X: u32 = 1u;"),
    content="true",
  )
  debug_inspect(
    source.contains("var<private> bind__arr: array<u32, bind__consts__X>;"),
    content="true",
  )
  debug_inspect(source.contains("bind::arr"), content="false")
}

///|
test "naga_oil upstream: quoted import alias does not clobber local identifiers" {
  let source = upstream_parity_compose_case(
    "quoted_dup",
    "top.wgsl",
    upstream_parity_empty_defines(),
  )
  debug_inspect(source.contains("fn foo__foo() -> f32"), content="true")
  debug_inspect(source.contains("fn myfunc(foo: u32) -> f32"), content="true")
  debug_inspect(source.contains("foo::foo"), content="false")
}

///|
test "naga_oil upstream: shared global imports are flattened without namespace prefixes" {
  let source = upstream_parity_compose_case(
    "use_shared_global",
    "top.wgsl",
    upstream_parity_empty_defines(),
  )
  debug_inspect(
    source.contains("var<private> mod__a: f32 = 0.0;"),
    content="true",
  )
  debug_inspect(source.contains("mod::a"), content="false")
  debug_inspect(source.contains("mod__a += 1.0;"), content="true")
}

///|
test "naga_oil upstream: problematic texture sample expressions survive composition" {
  let source = upstream_parity_compose_case(
    "problematic_expressions",
    "top.wgsl",
    upstream_parity_empty_defines(),
  )
  debug_inspect(
    source.contains("textureSample(mod__image, mod__s, vec2<f32>(0.0)).r"),
    content="true",
  )
  debug_inspect(
    source.contains(
      "textureSample(mod__image, mod__s, vec2<f32>(0.0), vec2<i32>(1, 1)).r",
    ),
    content="true",
  )
  debug_inspect(source.contains("mod::f"), content="false")
}

///|
test "naga_oil upstream: atomic builtins survive module composition" {
  let source = upstream_parity_compose_case(
    "atomics",
    "top.wgsl",
    upstream_parity_empty_defines(),
  )
  debug_inspect(source.contains("atomicCompareExchangeWeak"), content="true")
  debug_inspect(source.contains("atomicExchange"), content="true")
  debug_inspect(source.contains("test_module::entry_point"), content="false")
}

///|
test "naga_oil upstream: effective defs drive imported declaration values" {
  let output = upstream_parity_export_case(
    "effective_defs",
    "top.wgsl",
    ["entry_point"],
    upstream_parity_bool_defines(["DEF_ONE", "DEF_THREE"]),
  )
  debug_inspect(output.source.contains("const a: u32 = 1u;"), content="true")
  debug_inspect(output.source.contains("const b: u32 = 0u;"), content="true")
  debug_inspect(output.source.contains("const c: u32 = 4u;"), content="true")
}

///|
test "naga_oil upstream: item sub-point export keeps imported struct and helper fn" {
  let output = upstream_parity_export_case(
    "item_sub_point",
    "top.wgsl",
    ["main"],
    upstream_parity_empty_defines(),
  )
  debug_inspect(output.source.contains("struct Frag"), content="true")
  debug_inspect(output.source.contains("fn fragment"), content="true")
  debug_inspect(output.source.contains("fragment(f)"), content="true")
}

///|
test "naga_oil upstream: duplicate struct imports are renamed per alias scope" {
  let output = upstream_parity_export_case(
    "dup_struct_import",
    "top.wgsl",
    ["main"],
    upstream_parity_empty_defines(),
  )
  debug_inspect(
    upstream_parity_count_occurrences(
      output.source,
      "struct a__struct__MyStruct",
    ),
    content="1",
  )
  debug_inspect(
    upstream_parity_count_occurrences(
      output.source,
      "struct b__struct__MyStruct",
    ),
    content="1",
  )
  debug_inspect(
    output.source.contains("fn a__a() -> a__struct__MyStruct"),
    content="true",
  )
  debug_inspect(
    output.source.contains("fn b__b() -> b__struct__MyStruct"),
    content="true",
  )
}

///|
test "naga_oil upstream: duplicate module imports are renamed per alias scope" {
  let output = upstream_parity_export_case(
    "dup_import",
    "top.wgsl",
    ["main"],
    upstream_parity_empty_defines(),
  )
  debug_inspect(output.source.contains("const a__consts__PI"), content="true")
  debug_inspect(output.source.contains("const b__consts__PI"), content="true")
  debug_inspect(output.source.contains("fn a__f"), content="true")
  debug_inspect(output.source.contains("fn b__f"), content="true")
  debug_inspect(output.source.contains("a::f"), content="false")
  debug_inspect(output.source.contains("b::f"), content="false")
}

///|
test "naga_oil upstream: namespace-style module refs synthesize source-level imports" {
  let output = upstream_parity_export_case(
    "rusty_imports",
    "top.wgsl",
    ["entry_point"],
    upstream_parity_empty_defines(),
  )
  debug_inspect(output.source.contains("fn a_x__square"), content="true")
  debug_inspect(
    output.source.contains("fn partial_path_c__triple"),
    content="true",
  )
  debug_inspect(output.source.contains("const full_path__C"), content="true")
  debug_inspect(
    output.source.contains(
      "return a_x__square(partial_path_c__triple(full_path__C));",
    ),
    content="true",
  )
  debug_inspect(output.source.contains("a::x::"), content="false")
  debug_inspect(output.source.contains("partial_path::"), content="false")
  debug_inspect(output.source.contains("full_path::"), content="false")
}

///|
test "naga_oil upstream: entrypoint imports are renamed instead of shadowing locals" {
  let output = upstream_parity_export_case(
    "call_entrypoint",
    "top.wgsl",
    ["fragment"],
    upstream_parity_empty_defines(),
  )
  debug_inspect(output.source.contains("fn Inc__fragment"), content="true")
  debug_inspect(
    upstream_parity_count_occurrences(output.source, "fn fragment("),
    content="1",
  )
  debug_inspect(
    output.source.contains("return Inc__fragment(frag_coord);"),
    content="true",
  )
}

///|
test "naga_oil upstream: diagnostic filters are preserved in exported WGSL" {
  let output = upstream_parity_export_case(
    "diagnostic_filters",
    "top.wgsl",
    ["main"],
    upstream_parity_empty_defines(),
  )
  debug_inspect(
    output.source.contains("diagnostic(warning, derivative_uniformity);"),
    content="true",
  )
  debug_inspect(
    output.source.contains("fn filters__diagnostic_test"),
    content="true",
  )
}

///|
test "naga_oil upstream: dual source blending enable directive round-trips" {
  let output = upstream_parity_export_case(
    "dual_source_blending",
    "blending.wgsl",
    ["fragment"],
    upstream_parity_empty_defines(),
  )
  debug_inspect(
    output.source.contains("enable dual_source_blending;"),
    content="true",
  )
  debug_inspect(output.source.contains("@blend_src(1)"), content="true")
}

///|
test "naga_oil upstream: modf result member access survives composition" {
  let source = upstream_parity_compose_case(
    "modf",
    "top.wgsl",
    upstream_parity_empty_defines(),
  )
  debug_inspect(source.contains("let fw = modf(x);"), content="true")
  debug_inspect(source.contains("let f = fw.fract;"), content="true")
  debug_inspect(source.contains("let w = fw.whole;"), content="true")
}

///|
test "naga_oil upstream: additional imports are applied only to the root compose request" {
  let composer = upstream_parity_composer("add_imports")
  let source = composer.compose_wgsl("top.wgsl", {
    assets_base: "",
    defines: upstream_parity_empty_defines(),
    value_defines: @moon_wgsl.default_wgsl_value_defines(),
    redirects: [],
    additional_imports: [{ import_path: "plugin", items: [] }],
    preserve_imported_entry_points: true,
  }) catch {
    err => abort("expected additional-import compose success: \{err.message()}")
  }
  debug_inspect(source.contains("fn plugin__external_scale"), content="true")
  debug_inspect(source.contains("fn entry_point"), content="true")
  debug_inspect(source.contains("plugin__external_scale()"), content="true")
  debug_inspect(source.contains("#import plugin"), content="false")
}

///|
test "naga_oil upstream: additional imports participate in single-file export" {
  let composer = upstream_parity_composer("add_imports")
  let output = composer.export_wgsl_with_options(
    "top.wgsl",
    {
      assets_base: "",
      defines: upstream_parity_empty_defines(),
      value_defines: @moon_wgsl.default_wgsl_value_defines(),
      redirects: [],
      additional_imports: [{ import_path: "plugin", items: [] }],
      preserve_imported_entry_points: true,
    },
    { root_items: ["entry_point"] },
  ) catch {
    err => abort("expected additional-import export success: \{err.message()}")
  }
  debug_inspect(
    output.source.contains("fn plugin__external_scale"),
    content="true",
  )
  debug_inspect(output.source.contains("fn entry_point"), content="true")
  debug_inspect(output.source.contains("fn unused_external"), content="false")
}

///|
test "naga_oil upstream: virtual function override replaces imported body" {
  let source = upstream_mirror_compose_case(
    "overrides",
    "top.wgsl",
    upstream_parity_empty_defines(),
  )
  debug_inspect(source.contains("virtual fn"), content="false")
  debug_inspect(source.contains("override fn"), content="false")
  debug_inspect(
    source.contains("fn mod__inner(arg: f32) -> f32"),
    content="true",
  )
  debug_inspect(source.contains("return arg * 3.0;"), content="true")
  debug_inspect(source.contains("return arg * 2.0;"), content="false")
  debug_inspect(source.contains("return mod__inner(1.0);"), content="true")
  debug_inspect(source.contains("return mod__outer();"), content="true")
}

///|
test "naga_oil upstream: transitive virtual override replaces imported body" {
  let source = upstream_mirror_compose_case(
    "overrides",
    "top_with_middle.wgsl",
    upstream_parity_empty_defines(),
  )
  debug_inspect(source.contains("virtual fn"), content="false")
  debug_inspect(source.contains("override fn"), content="false")
  debug_inspect(
    source.contains("fn mod__inner(arg: f32) -> f32"),
    content="true",
  )
  debug_inspect(source.contains("return arg * 3.0;"), content="true")
  debug_inspect(source.contains("return arg * 2.0;"), content="false")
  debug_inspect(source.contains("return mod__inner(1.0);"), content="true")
  debug_inspect(source.contains("return mod__outer();"), content="true")
}

///|
test "naga_oil upstream: additional import plugin overrides virtual function" {
  let composer = upstream_mirror_composer("add_imports")
  let options = upstream_parity_compose_options(upstream_parity_empty_defines())
  options.additional_imports.push(@moon_wgsl.ImportDefinition::{
    import_path: "plugin",
    items: [],
  })
  let source = composer.compose_wgsl("top.wgsl", options) catch {
    err =>
      abort(
        "expected additional-import override compose success: \{err.message()}",
      )
  }
  debug_inspect(source.contains("virtual fn"), content="false")
  debug_inspect(source.contains("override fn"), content="false")
  debug_inspect(
    source.contains("fn overridable__func() -> f32"),
    content="true",
  )
  debug_inspect(
    source.contains("fn overridable__func__virtual_base() -> f32"),
    content="true",
  )
  debug_inspect(
    source.contains("return overridable__func__virtual_base() + 1.0;"),
    content="true",
  )
  debug_inspect(source.contains("return 1.0;"), content="true")
  debug_inspect(source.contains("return overridable__func();"), content="true")
}

///|
test "naga_oil upstream: invalid override reports non-virtual target" {
  let composer = upstream_mirror_composer("overrides")
  let mut message = ""
  ignore(
    composer.compose_wgsl(
      "top_invalid.wgsl",
      upstream_parity_compose_options(upstream_parity_empty_defines()),
    ),
  ) catch {
    err => message = err.message()
  }
  debug_inspect(message.contains("override is invalid"), content="true")
  debug_inspect(message.contains("mod::outer"), content="true")
}

///|
test "naga_oil upstream: compute shader smoke preserves imported entry dependency" {
  let output = upstream_parity_export_case(
    "compute_test",
    "compute_test.wgsl",
    ["run_test"],
    upstream_parity_empty_defines(),
  )
  debug_inspect(output.source.contains("@compute"), content="true")
  debug_inspect(output.source.contains("fn run_test"), content="true")
  debug_inspect(
    output.source.contains("fn test_module__entry_point"),
    content="true",
  )
  debug_inspect(
    output.source.contains("test_module__entry_point()"),
    content="true",
  )
}

///|
test "naga_oil upstream: source-level sanitizer handles invalid imported identifiers" {
  let source = upstream_mirror_compose_case(
    "invalid_identifiers",
    "top_valid.wgsl",
    upstream_parity_empty_defines(),
  )
  debug_inspect(source.contains("fn fns__bad("), content="true")
  debug_inspect(source.contains("fn fns__bad_("), content="false")
  debug_inspect(source.contains("in_wgsl: f32"), content="true")
  debug_inspect(source.contains("globals__bad: f32"), content="true")
  debug_inspect(source.contains("globals__bad_: f32"), content="false")
  debug_inspect(source.contains("struct structs__Isbad {"), content="true")
  debug_inspect(source.contains("struct structs__Isbad_ {"), content="false")
}

///|
test "naga_oil upstream: invalid struct member identifier reports compose failure" {
  let composer = upstream_mirror_composer("invalid_identifiers")
  let mut message = ""
  ignore(
    composer.compose_wgsl(
      "top_invalid.wgsl",
      upstream_parity_compose_options(upstream_parity_empty_defines()),
    ),
  ) catch {
    err => message = err.message()
  }
  debug_inspect(
    message.contains("invalid WGSL struct member identifier"),
    content="true",
  )
  debug_inspect(message.contains("bad_"), content="true")
}

///|
test "naga_oil upstream: raycast WGSL source graph composes" {
  let source = upstream_mirror_compose_case(
    "raycast",
    "top.wgsl",
    upstream_parity_empty_defines(),
  )
  debug_inspect(source.contains("enable wgpu_ray_query;"), content="true")
  debug_inspect(
    source.contains("var test_module__tlas: acceleration_structure;"),
    content="true",
  )
  debug_inspect(source.contains("var rq: ray_query;"), content="true")
  debug_inspect(source.contains("fn test_module__ray_func"), content="true")
  debug_inspect(
    source.contains("let ray = test_module__ray_func();"),
    content="true",
  )
}

///|
test "github issue 2: Bevy pbr_types alias const references are all rewritten" {
  let composer = @moon_wgsl.Composer::default()
  let pbr_types_source = "#define_import_path bevy_pbr::pbr_types\n" +
    "struct StandardMaterial {\n" +
    "  flags: u32,\n" +
    "}\n" +
    "struct PbrInput {\n" +
    "  material: StandardMaterial,\n" +
    "}\n" +
    "const STANDARD_MATERIAL_FLAGS_ALPHA_MODE_RESERVED_BITS: u32          = 7u << 29u; // (0b111u << 29u)\n" +
    "const STANDARD_MATERIAL_FLAGS_ALPHA_MODE_OPAQUE: u32                 = 0u << 29u;\n" +
    "const STANDARD_MATERIAL_FLAGS_ALPHA_MODE_MASK: u32                   = 1u << 29u;\n" +
    "const STANDARD_MATERIAL_FLAGS_ALPHA_MODE_ALPHA_TO_COVERAGE: u32      = 6u << 29u;\n"
  composer.register_wgsl_source("pbr_types.wgsl", pbr_types_source)
  let pbr_functions_source = "#define_import_path bevy_pbr::pbr_functions\n" +
    "#import bevy_pbr::pbr_types as pbr_types\n" +
    "fn alpha_discard(material: pbr_types::StandardMaterial, output_color: vec4<f32>) -> vec4<f32> {\n" +
    "  var color = output_color;\n" +
    "  let alpha_mode = material.flags & pbr_types::STANDARD_MATERIAL_FLAGS_ALPHA_MODE_RESERVED_BITS;\n" +
    "  if alpha_mode == pbr_types::STANDARD_MATERIAL_FLAGS_ALPHA_MODE_OPAQUE {\n" +
    "    color.a = 1.0;\n" +
    "  }\n" +
    "#ifdef MAY_DISCARD\n" +
    "  else if alpha_mode == pbr_types::STANDARD_MATERIAL_FLAGS_ALPHA_MODE_MASK ||\n" +
    "      alpha_mode == pbr_types::STANDARD_MATERIAL_FLAGS_ALPHA_MODE_ALPHA_TO_COVERAGE {\n" +
    "    color.a = 0.5;\n" +
    "  }\n" +
    "#endif\n" +
    "  return color;\n" +
    "}\n" +
    "fn fragment(material: pbr_types::StandardMaterial) -> vec4<f32> {\n" +
    "  return alpha_discard(material, vec4<f32>(0.0));\n" +
    "}\n"
  composer.register_wgsl_source("pbr_functions.wgsl", pbr_functions_source)
  let pbr_fragment_source = "#define_import_path bevy_pbr::pbr_fragment\n" +
    "#import bevy_pbr::{ pbr_functions, pbr_types }\n" +
    "fn fragment() -> vec4<f32> {\n" +
    "  var input: pbr_types::PbrInput;\n" +
    "  return pbr_functions::alpha_discard(input.material, vec4<f32>(0.0));\n" +
    "}\n"
  composer.register_wgsl_source("pbr_fragment.wgsl", pbr_fragment_source)
  let root_source = "#import bevy_pbr::pbr_fragment as pbr\n" +
    "fn fragment() -> vec4<f32> {\n" +
    "  return pbr::fragment();\n" +
    "}\n"
  composer.register_wgsl_source("root.wgsl", root_source)
  let source = composer.compose_wgsl(
    "root.wgsl",
    upstream_parity_compose_options(
      upstream_parity_bool_defines(["MAY_DISCARD"]),
    ),
  ) catch {
    err => abort("expected issue 2 repro compose success: \{err.message()}")
  }
  debug_inspect(
    source.contains("pbr_types__STANDARD_MATERIAL_FLAGS_ALPHA_MODE_OPAQUE"),
    content="true",
  )
  debug_inspect(
    source.contains("pbr_types::STANDARD_MATERIAL_FLAGS_ALPHA_MODE_OPAQUE"),
    content="false",
  )
}

///|
test "github issue 5: colliding lowered declarations from separate imports are deduped" {
  let composer = @moon_wgsl.Composer::default()
  composer.register_wgsl_source(
    "pbr_types_a.wgsl",
    "#define_import_path bevy_pbr::pbr_types_a\n" +
    "struct StandardMaterial {\n" +
    "  flags: u32,\n" +
    "}\n",
  )
  composer.register_wgsl_source(
    "pbr_types_b.wgsl",
    "#define_import_path bevy_pbr::pbr_types_b\n" +
    "struct StandardMaterial {\n" +
    "  flags: u32,\n" +
    "}\n",
  )
  composer.register_wgsl_source(
    "entry.wgsl",
    "#import bevy_pbr::pbr_types_a as pbr_types\n" +
    "#import bevy_pbr::pbr_types_b as pbr_types\n" +
    "fn fragment(material: pbr_types::StandardMaterial) -> u32 {\n" +
    "  return material.flags;\n" +
    "}\n",
  )
  let source = composer.compose_wgsl(
    "entry.wgsl",
    upstream_parity_compose_options(upstream_parity_empty_defines()),
  ) catch {
    err =>
      abort(
        "expected issue 5 colliding declaration compose success: \{err.message()}",
      )
  }
  debug_inspect(
    upstream_parity_count_occurrences(
      source, "struct pbr_types__StandardMaterial",
    ),
    content="1",
  )
}

///|
test "github issue 5: item-imported function keeps its imported mesh binding" {
  let composer = @moon_wgsl.Composer::default()
  composer.register_wgsl_source(
    "mesh_types.wgsl",
    "#define_import_path bevy_pbr::mesh_types\n" +
    "struct Mesh {\n" +
    "  flags: u32,\n" +
    "}\n",
  )
  composer.register_wgsl_source(
    "mesh_bindings.wgsl",
    "#define_import_path bevy_pbr::mesh_bindings\n" +
    "#import bevy_pbr::mesh_types::Mesh\n" +
    "#ifndef MESHLET_MESH_MATERIAL_PASS\n" +
    "@group(2) @binding(0) var<storage> mesh: array<Mesh>;\n" +
    "#endif\n",
  )
  composer.register_wgsl_source(
    "mesh_functions.wgsl",
    "#define_import_path bevy_pbr::mesh_functions\n" +
    "#import bevy_pbr::mesh_bindings as mesh_bindings\n" +
    "fn mesh_flags(instance_index: u32) -> u32 {\n" +
    "  return mesh_bindings::mesh[instance_index].flags;\n" +
    "}\n",
  )
  composer.register_wgsl_source(
    "pbr_types.wgsl",
    "#define_import_path bevy_pbr::pbr_types\n" +
    "struct PbrInput {\n" +
    "  flags: u32,\n" +
    "}\n",
  )
  composer.register_wgsl_source(
    "forward_io.wgsl",
    "#define_import_path bevy_pbr::forward_io\n" +
    "struct VertexOutput {\n" +
    "  instance_index: u32,\n" +
    "}\n",
  )
  composer.register_wgsl_source(
    "pbr_fragment.wgsl",
    "#define_import_path bevy_pbr::pbr_fragment\n" +
    "#import bevy_pbr::{\n" +
    "  mesh_bindings::mesh,\n" +
    "  pbr_types,\n" +
    "  forward_io::VertexOutput,\n" +
    "}\n" +
    "fn pbr_input_from_standard_material(in: VertexOutput) -> pbr_types::PbrInput {\n" +
    "  var pbr_input: pbr_types::PbrInput;\n" +
    "  pbr_input.flags = mesh[in.instance_index].flags;\n" +
    "  return pbr_input;\n" +
    "}\n",
  )
  composer.register_wgsl_source(
    "pbr.wgsl",
    "#define_import_path bevy_pbr::pbr\n" +
    "#import bevy_pbr::{\n" +
    "  pbr_fragment::pbr_input_from_standard_material,\n" +
    "  forward_io::VertexOutput,\n" +
    "}\n" +
    "@fragment\n" +
    "fn fragment(vertex_output: VertexOutput) -> @location(0) vec4<f32> {\n" +
    "  let pbr_input = pbr_input_from_standard_material(vertex_output);\n" +
    "  return vec4<f32>(f32(pbr_input.flags));\n" +
    "}\n",
  )
  composer.register_wgsl_source(
    "mesh.wgsl",
    "#define_import_path bevy_pbr::mesh\n" +
    "#import bevy_pbr::{\n" +
    "  mesh_functions,\n" +
    "  forward_io::VertexOutput,\n" +
    "}\n" +
    "@vertex\n" +
    "fn vertex() -> VertexOutput {\n" +
    "  var out: VertexOutput;\n" +
    "  out.instance_index = mesh_functions::mesh_flags(0u);\n" +
    "  return out;\n" +
    "}\n" +
    "@fragment\n" +
    "fn debug_fragment(mesh: VertexOutput) -> @location(0) vec4<f32> {\n" +
    "  return vec4<f32>(f32(mesh.instance_index));\n" +
    "}\n",
  )
  composer.register_wgsl_source(
    "entry.wgsl", "#import bevy_pbr::{ mesh::vertex, pbr::fragment }\n",
  )
  let source = composer.compose_wgsl(
    "entry.wgsl",
    upstream_parity_compose_options(upstream_parity_empty_defines()),
  ) catch {
    err =>
      abort(
        "expected issue 5 imported mesh binding compose success: \{err.message()}",
      )
  }
  debug_inspect(
    source.contains("var<storage> mesh: array<Mesh>;"),
    content="false",
  )
  debug_inspect(
    source.contains("mesh_functions__mesh_bindings__mesh"),
    content="true",
  )
  debug_inspect(
    source.contains("struct mesh_functions__mesh_bindings__Mesh"),
    content="true",
  )
  debug_inspect(
    source.contains("= mesh[in_wgsl.instance_index].flags"),
    content="false",
  )
  debug_inspect(
    source.contains(
      "mesh_functions__mesh_bindings__mesh[in_wgsl.instance_index].flags",
    ),
    content="true",
  )
}

///|
test "github issue 3: item-imported entry points are emitted even when unused by source" {
  let composer = @moon_wgsl.Composer::default()
  composer.register_wgsl_source(
    "mesh.wgsl",
    "#define_import_path demo::mesh\n" +
    "@vertex\n" +
    "fn vertex() -> vec4<f32> {\n" +
    "  return vec4<f32>(0.0);\n" +
    "}\n",
  )
  composer.register_wgsl_source(
    "pbr.wgsl",
    "#define_import_path demo::pbr\n" +
    "@fragment\n" +
    "fn fragment() -> vec4<f32> {\n" +
    "  return vec4<f32>(1.0);\n" +
    "}\n",
  )
  composer.register_wgsl_source(
    "entry.wgsl", "#import demo::{ mesh::vertex, pbr::fragment }\n",
  )
  let source = composer.compose_wgsl(
    "entry.wgsl",
    upstream_parity_compose_options(upstream_parity_empty_defines()),
  ) catch {
    err => abort("expected issue 3 entry compose success: \{err.message()}")
  }
  debug_inspect(source.contains("@vertex\nfn vertex"), content="true")
  debug_inspect(source.contains("@fragment\nfn fragment"), content="true")
}

///|
test "github issue 3: explicit import-only entry modules keep vertex function dependencies" {
  let composer = @moon_wgsl.Composer::default()
  composer.register_wgsl_source(
    "mesh.wgsl",
    "#define_import_path demo::mesh\n" +
    "struct Vertex { position: vec3<f32> }\n" +
    "struct VertexOutput { position: vec4<f32> }\n" +
    "fn vertex(vertex_no_morph: Vertex) -> VertexOutput {\n" +
    "  var out: VertexOutput;\n" +
    "  out.position = vec4<f32>(vertex_no_morph.position, 1.0);\n" +
    "  return out;\n" +
    "}\n",
  )
  composer.register_wgsl_source("entry.wgsl", "#import demo::mesh::vertex\n")
  let source = composer.compose_wgsl(
    "entry.wgsl",
    upstream_parity_compose_options(upstream_parity_empty_defines()),
  ) catch {
    err =>
      abort(
        "expected issue 3 import-only vertex compose success: \{err.message()}",
      )
  }
  debug_inspect(source.contains("struct Vertex"), content="true")
  debug_inspect(source.contains("struct VertexOutput"), content="true")
  debug_inspect(
    source.contains("fn vertex(vertex_no_morph: Vertex) -> VertexOutput"),
    content="true",
  )
}

///|
test "github issue 3: mixed full-module and item imports do not re-emit duplicate declarations" {
  let composer = @moon_wgsl.Composer::default()
  composer.register_wgsl_source(
    "types.wgsl",
    "#define_import_path demo::types\n" +
    "struct StandardMaterial { value: f32 }\n",
  )
  composer.register_wgsl_source(
    "bindings.wgsl",
    "#define_import_path demo::bindings\n" +
    "#import demo::types::StandardMaterial\n" +
    "@group(3) @binding(0) var<uniform> material: StandardMaterial;\n",
  )
  composer.register_wgsl_source(
    "fragment.wgsl",
    "#define_import_path demo::fragment\n" +
    "#import demo::{ types, bindings }\n" +
    "fn use_material() -> types::StandardMaterial {\n" +
    "  return bindings::material;\n" +
    "}\n",
  )
  composer.register_wgsl_source(
    "root.wgsl",
    "#import demo::fragment as fragment\n" +
    "fn fragment_entry() {\n" +
    "  fragment::use_material();\n" +
    "}\n",
  )
  let source = composer.compose_wgsl(
    "root.wgsl",
    upstream_parity_compose_options(upstream_parity_empty_defines()),
  ) catch {
    err => abort("expected issue 3 mixed compose success: \{err.message()}")
  }
  debug_inspect(
    upstream_parity_count_occurrences(
      source, "struct fragment__types__StandardMaterial",
    ),
    content="1",
  )
  debug_inspect(
    source.contains("fragment__bindings__StandardMaterial"),
    content="false",
  )
  debug_inspect(
    source.contains(
      "fragment__bindings__material: fragment__types__StandardMaterial",
    ),
    content="true",
  )
}

///|
test "github issue 3: nested alias imports rewrite variable declaration types" {
  let composer = @moon_wgsl.Composer::default()
  composer.register_wgsl_source(
    "mesh_view_types.wgsl",
    "#define_import_path bevy_pbr::mesh_view_types\n" +
    "struct Lights { value: u32 }\n",
  )
  composer.register_wgsl_source(
    "view.wgsl",
    "#define_import_path bevy_render::view\n" + "struct View { value: u32 }\n",
  )
  composer.register_wgsl_source(
    "globals.wgsl",
    "#define_import_path bevy_render::globals\n" +
    "struct Globals { value: u32 }\n",
  )
  composer.register_wgsl_source(
    "mesh_view_bindings.wgsl",
    "#define_import_path bevy_pbr::mesh_view_bindings\n" +
    "#import bevy_pbr::mesh_view_types as types\n" +
    "#import bevy_render::{ view::View, globals::Globals }\n" +
    "@group(0) @binding(0) var<uniform> view: View;\n" +
    "@group(0) @binding(1) var<uniform> globals: Globals;\n" +
    "@group(0) @binding(2) var<uniform> lights: types::Lights;\n",
  )
  composer.register_wgsl_source(
    "root.wgsl",
    "#import bevy_pbr::mesh_view_bindings as mesh_view_bindings\n" +
    "fn read_view() -> u32 {\n" +
    "  return mesh_view_bindings::view.value + mesh_view_bindings::globals.value + mesh_view_bindings::lights.value;\n" +
    "}\n",
  )
  let source = composer.compose_wgsl(
    "root.wgsl",
    upstream_parity_compose_options(upstream_parity_empty_defines()),
  ) catch {
    err =>
      abort("expected issue 3 nested alias compose success: \{err.message()}")
  }
  debug_inspect(source.contains(": View"), content="false")
  debug_inspect(source.contains(": Globals"), content="false")
  debug_inspect(source.contains("types::Lights"), content="false")
  debug_inspect(
    source.contains(
      "var<uniform> mesh_view_bindings__view: mesh_view_bindings__View",
    ),
    content="true",
  )
  debug_inspect(
    source.contains(
      "var<uniform> mesh_view_bindings__globals: mesh_view_bindings__Globals",
    ),
    content="true",
  )
  debug_inspect(
    source.contains(
      "var<uniform> mesh_view_bindings__lights: mesh_view_bindings__types__Lights",
    ),
    content="true",
  )
}

///|
test "github issue 4: nested module alias rewrites global binding member access" {
  let composer = @moon_wgsl.Composer::default()
  composer.register_wgsl_source(
    "view.wgsl",
    "#define_import_path bevy_render::view\n" +
    "struct View {\n" +
    "  world_from_view: mat4x4<f32>,\n" +
    "}\n",
  )
  composer.register_wgsl_source(
    "mesh_view_bindings.wgsl",
    "#define_import_path bevy_pbr::mesh_view_bindings\n" +
    "#import bevy_render::view::View\n" +
    "@group(0) @binding(0) var<uniform> view: View;\n",
  )
  composer.register_wgsl_source(
    "view_transformations.wgsl",
    "#define_import_path bevy_pbr::view_transformations\n" +
    "#import bevy_pbr::mesh_view_bindings as view_bindings\n" +
    "#import bevy_pbr::prepass_bindings\n" +
    "fn view_to_world(view_pos: vec3<f32>) -> vec3<f32> {\n" +
    "  let world_pos = view_bindings::view.world_from_view * vec4(view_pos, 1.0);\n" +
    "  return world_pos.xyz;\n" +
    "}\n" +
    "fn world_to_prev_view(world_pos: vec3<f32>) -> vec3<f32> {\n" +
    "  let view_pos = prepass_bindings::previous_view_uniforms.view_from_world * vec4(world_pos, 1.0);\n" +
    "  return view_pos.xyz;\n" +
    "}\n",
  )
  composer.register_wgsl_source(
    "prepass_bindings.wgsl",
    "#define_import_path bevy_pbr::prepass_bindings\n" +
    "struct PreviousViewUniforms { view_from_world: mat4x4<f32> }\n" +
    "@group(0) @binding(30) var<uniform> previous_view_uniforms: PreviousViewUniforms;\n",
  )
  composer.register_wgsl_source(
    "pbr_functions.wgsl",
    "#define_import_path bevy_pbr::pbr_functions\n" +
    "#import bevy_pbr::{\n" +
    "  mesh_view_bindings as view_bindings,\n" +
    "  view_transformations,\n" +
    "}\n" +
    "fn apply_transform(view_pos: vec3<f32>) -> vec3<f32> {\n" +
    "  return (view_bindings::view.world_from_view * vec4(view_pos, 1.0)).xyz + view_transformations::view_to_world(view_pos);\n" +
    "}\n",
  )
  composer.register_wgsl_source(
    "root.wgsl",
    "#import bevy_pbr::pbr_functions as pbr_functions\n" +
    "fn read_world(view_pos: vec3<f32>) -> vec3<f32> {\n" +
    "  return pbr_functions::apply_transform(view_pos);\n" +
    "}\n",
  )
  let output = composer.export_wgsl_with_options(
    "root.wgsl",
    upstream_parity_compose_options(upstream_parity_empty_defines()),
    { root_items: ["read_world"] },
  ) catch {
    err =>
      abort("expected issue 4 nested alias compose success: \{err.message()}")
  }
  let source = output.source
  debug_inspect(source.contains("view_bindings::view"), content="false")
  debug_inspect(
    source.contains("pbr_functions__view_bindings__view.world_from_view"),
    content="true",
  )
  debug_inspect(
    source.contains("var<uniform> view_bindings__view: View"),
    content="false",
  )
  debug_inspect(
    source.contains(
      "var<uniform> pbr_functions__view_bindings__view: pbr_functions__view_bindings__View",
    ),
    content="true",
  )
}
