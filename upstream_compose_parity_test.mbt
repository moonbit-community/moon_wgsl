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
  @hashmap.HashMap([])
}

///|
fn upstream_parity_bool_defines(
  names : Array[String],
) -> @hashmap.HashMap[String, Bool] {
  let defines : @hashmap.HashMap[String, Bool] = @hashmap.HashMap([])
  for name in names {
    defines.set(name, true)
  }
  defines
}

///|
fn upstream_parity_shader_def_values(
  names : Array[String],
) -> @hashmap.HashMap[String, @common.ShaderDefValue] {
  let defines : @hashmap.HashMap[String, @common.ShaderDefValue] = @hashmap.HashMap([],
  )
  for name in names {
    defines.set(name, @common.ShaderDefValue::Bool(true))
  }
  defines
}

///|
fn upstream_parity_compose_options(
  defines : @hashmap.HashMap[String, Bool],
) -> @common.WgslComposeOptions {
  {
    defines,
    value_defines: @common.default_wgsl_value_defines(),
    redirects: [],
    additional_imports: [],
  }
}

///|
fn upstream_parity_empty_compose_options() -> @common.WgslComposeOptions {
  upstream_parity_compose_options(upstream_parity_empty_defines())
}

///|
fn upstream_parity_composer(case_name : String) -> @compose.Composer {
  let composer = @compose.Composer::default()
  composer.clear_sources()
  composer.register_source_tree(
    "testdata/upstream_compose/\{case_name}",
    @common.WgslSourceScanOptions::default(),
  ) catch {
    _ => abort("expected upstream fixture registration success")
  }
  composer
}

///|
fn upstream_parity_descriptor_effective_defs_source(
  shader_defs : @hashmap.HashMap[String, @common.ShaderDefValue],
) -> String {
  let composer = @compose.Composer::default()
  composer.clear_sources()
  ignore(
    composer.add_composable_module({
      source: "#define_import_path mod\n" +
      "#ifdef DEF_ONE\n" +
      "const a: u32 = 1u;\n" +
      "#else\n" +
      "const a: u32 = 0u;\n" +
      "#endif\n" +
      "#ifndef DEF_TWO\n" +
      "const b: u32 = 0u;\n" +
      "#else\n" +
      "const b: u32 = 2u;\n" +
      "#endif\n" +
      "#if DEF_THREE == true\n" +
      "const c: u32 = 4u;\n" +
      "#else\n" +
      "const c: u32 = 0u;\n" +
      "#endif\n",
      file_path: "mod.wgsl",
      as_name: None,
      additional_imports: [],
      shader_defs: @hashmap.HashMap([]),
    }),
  ) catch {
    err => abort("expected mod registration success: \{err.message()}")
  }
  ignore(
    composer.add_composable_module({
      source: "#define_import_path test_module\n" +
      "#import mod a, b, c\n" +
      "fn entry_point() -> f32 {\n" +
      "  return f32(a + b + c);\n" +
      "}\n",
      file_path: "top.wgsl",
      as_name: None,
      additional_imports: [],
      shader_defs,
    }),
  ) catch {
    err => abort("expected test_module registration success: \{err.message()}")
  }
  composer.register_source(
    "compute_test.wgsl",
    "#import test_module::entry_point\n" +
    "@compute @workgroup_size(1)\n" +
    "fn run_test() {\n" +
    "  let value = entry_point();\n" +
    "}\n",
  )
  composer.compose_wgsl(
    "compute_test.wgsl",
    upstream_parity_empty_compose_options(),
  ) catch {
    err =>
      abort(
        "expected descriptor effective-def compose success: \{err.message()}",
      )
  }
}

///|
fn upstream_parity_check_effective_defs_sum(
  shader_defs : @hashmap.HashMap[String, @common.ShaderDefValue],
  expected_a : String,
  expected_b : String,
  expected_c : String,
) -> Unit {
  let source = upstream_parity_descriptor_effective_defs_source(shader_defs)
  if !source.contains("= \{expected_a};") {
    abort("expected a to resolve to \{expected_a}")
  }
  if !source.contains("= \{expected_b};") {
    abort("expected b to resolve to \{expected_b}")
  }
  if !source.contains("= \{expected_c};") {
    abort("expected c to resolve to \{expected_c}")
  }
}

///|
fn upstream_parity_check_effective_defs_sum_with_true_defs(
  names : Array[String],
  expected_a : String,
  expected_b : String,
  expected_c : String,
) -> Unit {
  upstream_parity_check_effective_defs_sum(
    upstream_parity_shader_def_values(names),
    expected_a,
    expected_b,
    expected_c,
  )
}

///|
fn upstream_parity_check_effective_defs_sum_with_false_three(
  names : Array[String],
  expected_a : String,
  expected_b : String,
) -> Unit {
  let shader_defs = upstream_parity_shader_def_values(names)
  shader_defs.set("DEF_THREE", @common.ShaderDefValue::Bool(false))
  upstream_parity_check_effective_defs_sum(
    shader_defs, expected_a, expected_b, "0u",
  )
}

///|
fn upstream_mirror_composer(case_name : String) -> @compose.Composer {
  let composer = @compose.Composer::default()
  composer.clear_sources()
  composer.register_source_tree(
    "testdata/naga_oil_upstream/compose_tests/\{case_name}",
    @common.WgslSourceScanOptions::default(),
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
) -> @common.WgslExportOutput {
  @export.export_wgsl_with_options(
    upstream_parity_composer(case_name),
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
  debug_inspect(output.source.contains("X_naga_oil_mod_X"), content="true")
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
  debug_inspect(source.contains("x = 1f;"), content="true")
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
  debug_inspect(source.contains("= 1u;"), content="true")
  debug_inspect(source.contains("const C: u32 = 2u;"), content="false")
}

///|
test "naga_oil upstream: conditional import selects module b when shader def is disabled" {
  let source = upstream_parity_compose_case(
    "conditional_import",
    "top.wgsl",
    upstream_parity_empty_defines(),
  )
  debug_inspect(source.contains("= 2u;"), content="true")
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
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(source.contains("bind::arr"), content="false")
}

///|
test "naga_oil upstream: quoted import alias does not clobber local identifiers" {
  let source = upstream_parity_compose_case(
    "quoted_dup",
    "top.wgsl",
    upstream_parity_empty_defines(),
  )
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
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
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(source.contains("mod::a"), content="false")
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
}

///|
test "naga_oil upstream: problematic texture sample expressions survive composition" {
  let source = upstream_parity_compose_case(
    "problematic_expressions",
    "top.wgsl",
    upstream_parity_empty_defines(),
  )
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(source.contains("vec2<i32>(1i, 1i)"), content="true")
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
  debug_inspect(
    source.contains("let _e26: u32 = y;\n    let _e28: u32 = atomicExchange"),
    content="true",
  )
  debug_inspect(source.contains("let _e35: u32 = y;"), content="true")
  debug_inspect(source.contains("return f32(_e38);"), content="true")
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
  debug_inspect(output.source.contains("aX_naga_oil_mod_X"), content="true")
  debug_inspect(output.source.contains(": u32 = 1u;"), content="true")
  debug_inspect(output.source.contains("bX_naga_oil_mod_X"), content="true")
  debug_inspect(output.source.contains(": u32 = 0u;"), content="true")
  debug_inspect(output.source.contains("cX_naga_oil_mod_X"), content="true")
  debug_inspect(output.source.contains(": u32 = 4u;"), content="true")
}

///|
test "naga_oil upstream: bool false shader def is still defined for ifdef" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "bool_false.wgsl",
    "#ifdef FLAG\n" +
    "const ifdef_value: u32 = 1u;\n" +
    "#else\n" +
    "const ifdef_value: u32 = 0u;\n" +
    "#endif\n" +
    "#if FLAG == true\n" +
    "const if_value: u32 = 1u;\n" +
    "#else\n" +
    "const if_value: u32 = 0u;\n" +
    "#endif\n",
  )
  let defines = upstream_parity_empty_defines()
  defines.set("FLAG", false)
  let source = composer.compose_wgsl(
    "bool_false.wgsl",
    upstream_parity_compose_options(defines),
  ) catch {
    err => abort("expected bool-false compose success: \{err.message()}")
  }
  debug_inspect(source.contains("const ifdef_value: u32 = 1u;"), content="true")
  debug_inspect(source.contains("const if_value: u32 = 0u;"), content="true")
}

///|
test "naga_oil upstream: descriptor effective defs cover all imported branches" {
  upstream_parity_check_effective_defs_sum_with_false_three([], "0u", "0u")
  upstream_parity_check_effective_defs_sum_with_false_three(
    ["DEF_ONE"],
    "1u",
    "0u",
  )
  upstream_parity_check_effective_defs_sum_with_false_three(
    ["DEF_TWO"],
    "0u",
    "2u",
  )
  upstream_parity_check_effective_defs_sum_with_false_three(
    ["DEF_ONE", "DEF_TWO"],
    "1u",
    "2u",
  )
  upstream_parity_check_effective_defs_sum_with_true_defs(
    ["DEF_THREE"],
    "0u",
    "0u",
    "4u",
  )
  upstream_parity_check_effective_defs_sum_with_true_defs(
    ["DEF_ONE", "DEF_THREE"],
    "1u",
    "0u",
    "4u",
  )
  upstream_parity_check_effective_defs_sum_with_true_defs(
    ["DEF_TWO", "DEF_THREE"],
    "0u",
    "2u",
    "4u",
  )
  upstream_parity_check_effective_defs_sum_with_true_defs(
    ["DEF_ONE", "DEF_TWO", "DEF_THREE"],
    "1u",
    "2u",
    "4u",
  )
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
  debug_inspect(
    output.source.contains("fragmentX_naga_oil_mod_X"),
    content="true",
  )
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
      "struct MyStructX_naga_oil_mod_X",
    ),
    content="1",
  )
  debug_inspect(
    upstream_parity_count_occurrences(output.source, "fn bX_naga_oil_mod_X"),
    content="1",
  )
  debug_inspect(output.source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(output.source.contains("X_naga_oil_mod_X"), content="true")
}

///|
test "naga_oil upstream: duplicate module imports are renamed per alias scope" {
  let output = upstream_parity_export_case(
    "dup_import",
    "top.wgsl",
    ["main"],
    upstream_parity_empty_defines(),
  )
  debug_inspect(output.source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(output.source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(output.source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(output.source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(output.source.contains("a::f"), content="false")
  debug_inspect(output.source.contains("b::f"), content="false")
}

///|
test "naga_oil upstream: namespace-style module refs resolve through AST import graph" {
  let output = upstream_parity_export_case(
    "rusty_imports",
    "top.wgsl",
    ["entry_point"],
    upstream_parity_empty_defines(),
  )
  debug_inspect(output.source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(output.source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(output.source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(
    output.source.contains("squareX_naga_oil_mod_X"),
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
  debug_inspect(output.source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(
    upstream_parity_count_occurrences(output.source, "fn fragment("),
    content="1",
  )
  debug_inspect(
    output.source.contains("non_epX_naga_oil_mod_X"),
    content="false",
  )
  debug_inspect(
    output.source.contains("frag_coord_1: vec4<f32>"),
    content="true",
  )
  debug_inspect(output.source.contains("X_naga_oil_mod_X"), content="true")
}

///|
test "naga_oil upstream: diagnostic filters bind ambient globals" {
  let source = upstream_parity_composer("diagnostic_filters").compose_wgsl(
    "top.wgsl",
    upstream_parity_empty_compose_options(),
  ) catch {
    err => abort("expected diagnostic-filter compose success: \{err.message()}")
  }
  debug_inspect(
    source.contains("diagnostic(warning, derivative_uniformity);"),
    content="true",
  )
  debug_inspect(source.contains("fn diagnostic_test"), content="true")
  debug_inspect(
    source.contains("diagnostic_testX_naga_oil_mod_XMZUWY5DFOJZQX()"),
    content="true",
  )
  debug_inspect(source.contains("textureSample(tex, s"), content="true")
  debug_inspect(source.contains("ro_buffer[0]"), content="true")
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
test "naga_oil upstream: multiline dual source blending members skip identifier validation" {
  let source = @compose.Composer::default().compose_wgsl_source(
    "enable dual_source_blending;\nstruct FragmentOutput {\n  @location(0)\n  @blend_src(0)\n  source0_: vec4<f32>,\n  @location(0)\n  @blend_src(1)\n  source1_: vec4<f32>,\n}\n@fragment\nfn fragment() -> FragmentOutput {\n  return FragmentOutput(vec4<f32>(), vec4<f32>());\n}\n",
    @common.WgslComposeOptions::default(),
  ) catch {
    err =>
      abort("expected multiline blend_src compose success: \{err.message()}")
  }
  debug_inspect(source.contains("source0_"), content="true")
  debug_inspect(source.contains("source1_"), content="true")
}

///|
test "naga_oil upstream: modf result member access survives composition" {
  let source = upstream_parity_compose_case(
    "modf",
    "top.wgsl",
    upstream_parity_empty_defines(),
  )
  debug_inspect(source.contains("modf(x);"), content="true")
  debug_inspect(source.contains(".fract"), content="true")
  debug_inspect(source.contains(".whole"), content="true")
}

///|
test "naga_oil upstream: additional imports are applied only to the root compose request" {
  let composer = upstream_parity_composer("add_imports")
  let source = composer.compose_wgsl("top.wgsl", {
    defines: upstream_parity_empty_defines(),
    value_defines: @common.default_wgsl_value_defines(),
    redirects: [],
    additional_imports: [{ import_path: "plugin", items: [] }],
  }) catch {
    err => abort("expected additional-import compose success: \{err.message()}")
  }
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(source.contains("fn entry_point"), content="true")
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(source.contains("#import plugin"), content="false")
}

///|
test "naga_oil upstream: additional imports participate in single-file export" {
  let composer = upstream_parity_composer("add_imports")
  let output = @export.export_wgsl_with_options(
    composer,
    "top.wgsl",
    {
      defines: upstream_parity_empty_defines(),
      value_defines: @common.default_wgsl_value_defines(),
      redirects: [],
      additional_imports: [{ import_path: "plugin", items: [] }],
    },
    { root_items: ["entry_point"] },
  ) catch {
    err => abort("expected additional-import export success: \{err.message()}")
  }
  debug_inspect(output.source.contains("X_naga_oil_mod_X"), content="true")
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
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(source.contains("(arg * 3f)"), content="true")
  debug_inspect(source.contains("(arg_1 * 2f)"), content="true")
  debug_inspect(source.contains("X_naga_oil_vrt_X"), content="true")
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
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
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(source.contains("(arg * 3f)"), content="true")
  debug_inspect(source.contains("(arg_1 * 2f)"), content="true")
  debug_inspect(source.contains("X_naga_oil_vrt_X"), content="true")
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
}

///|
test "naga_oil upstream: additional import plugin overrides virtual function" {
  let composer = upstream_mirror_composer("add_imports")
  let options = upstream_parity_compose_options(upstream_parity_empty_defines())
  options.additional_imports.push(@common.ImportDefinition::{
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
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(source.contains("return 1f;"), content="true")
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
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
  debug_inspect(message.contains("outerX_naga_oil_mod_X"), content="true")
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
  debug_inspect(output.source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(output.source.contains("X_naga_oil_mod_X"), content="true")
}

///|
test "naga_oil upstream: AST identifier policy handles invalid imported identifiers" {
  let source = upstream_mirror_compose_case(
    "invalid_identifiers",
    "top_valid.wgsl",
    upstream_parity_empty_defines(),
  )
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(source.contains("fn fns__bad_("), content="false")
  debug_inspect(source.contains("in: f32"), content="true")
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(source.contains("globals__bad_: f32"), content="false")
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
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
    message.contains("requires AST identifier normalization"),
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
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(source.contains("var rq: ray_query;"), content="true")
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
}

///|
test "github issue 2: Bevy pbr_types alias const references are all rewritten" {
  let composer = @compose.Composer::default()
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
  composer.register_source("pbr_types.wgsl", pbr_types_source)
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
  composer.register_source("pbr_functions.wgsl", pbr_functions_source)
  let pbr_fragment_source = "#define_import_path bevy_pbr::pbr_fragment\n" +
    "#import bevy_pbr::{ pbr_functions, pbr_types }\n" +
    "fn fragment() -> vec4<f32> {\n" +
    "  var input: pbr_types::PbrInput;\n" +
    "  return pbr_functions::alpha_discard(input.material, vec4<f32>(0.0));\n" +
    "}\n"
  composer.register_source("pbr_fragment.wgsl", pbr_fragment_source)
  let root_source = "#import bevy_pbr::pbr_fragment as pbr\n" +
    "fn fragment() -> vec4<f32> {\n" +
    "  return pbr::fragment();\n" +
    "}\n"
  composer.register_source("root.wgsl", root_source)
  let source = composer.compose_wgsl(
    "root.wgsl",
    upstream_parity_compose_options(
      upstream_parity_bool_defines(["MAY_DISCARD"]),
    ),
  ) catch {
    err => abort("expected issue 2 repro compose success: \{err.message()}")
  }
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(
    source.contains("pbr_types::STANDARD_MATERIAL_FLAGS_ALPHA_MODE_OPAQUE"),
    content="false",
  )
}

///|
test "github issue 5: colliding lowered declarations from separate imports are deduped" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "pbr_types_a.wgsl",
    "#define_import_path bevy_pbr::pbr_types_a\n" +
    "struct StandardMaterial {\n" +
    "  flags: u32,\n" +
    "}\n",
  )
  composer.register_source(
    "pbr_types_b.wgsl",
    "#define_import_path bevy_pbr::pbr_types_b\n" +
    "struct StandardMaterial {\n" +
    "  flags: u32,\n" +
    "}\n",
  )
  composer.register_source(
    "entry.wgsl",
    "#import bevy_pbr::pbr_types_a as pbr_types\n" +
    "#import bevy_pbr::pbr_types_b as pbr_types\n" +
    "fn fragment(material: pbr_types::StandardMaterial) -> u32 {\n" +
    "  return material.flags;\n" +
    "}\n",
  )
  ignore(
    composer.compose_wgsl(
      "entry.wgsl",
      upstream_parity_compose_options(upstream_parity_empty_defines()),
    ),
  ) catch {
    err => {
      debug_inspect(
        err.message().contains("ambiguous shader import binding"),
        content="true",
      )
      debug_inspect(
        err.message().contains("pbr_types::StandardMaterial"),
        content="true",
      )
      return
    }
  }
  abort("expected colliding same-alias imports to report ambiguity")
}

///|
test "github issue 6: Bevy F0_ struct member composes without identifier-policy rejection" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "f0_member.wgsl",
    "struct LightingInput {\n" + "  F0_: vec3<f32>,\n" + "}\n",
  )
  let source = composer.compose_wgsl(
    "f0_member.wgsl",
    upstream_parity_compose_options(upstream_parity_empty_defines()),
  ) catch {
    err => abort("expected F0_ member compose success: \{err.message()}")
  }
  debug_inspect(source.contains("F0_: vec3<f32>"), content="true")
}

///|
test "naga_oil parity: item-imported functions do not force imported mesh bindings" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "mesh_types.wgsl",
    "#define_import_path bevy_pbr::mesh_types\n" +
    "struct Mesh {\n" +
    "  flags: u32,\n" +
    "}\n",
  )
  composer.register_source(
    "mesh_bindings.wgsl",
    "#define_import_path bevy_pbr::mesh_bindings\n" +
    "#import bevy_pbr::mesh_types::Mesh\n" +
    "#ifndef MESHLET_MESH_MATERIAL_PASS\n" +
    "@group(2) @binding(0) var<storage> mesh: array<Mesh>;\n" +
    "#endif\n",
  )
  composer.register_source(
    "mesh_functions.wgsl",
    "#define_import_path bevy_pbr::mesh_functions\n" +
    "#import bevy_pbr::mesh_bindings as mesh_bindings\n" +
    "fn mesh_flags(instance_index: u32) -> u32 {\n" +
    "  return mesh_bindings::mesh[instance_index].flags;\n" +
    "}\n",
  )
  composer.register_source(
    "pbr_types.wgsl",
    "#define_import_path bevy_pbr::pbr_types\n" +
    "struct PbrInput {\n" +
    "  flags: u32,\n" +
    "}\n",
  )
  composer.register_source(
    "forward_io.wgsl",
    "#define_import_path bevy_pbr::forward_io\n" +
    "struct VertexOutput {\n" +
    "  instance_index: u32,\n" +
    "}\n",
  )
  composer.register_source(
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
  composer.register_source(
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
  composer.register_source(
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
  composer.register_source(
    "entry.wgsl", "#import bevy_pbr::{ mesh::vertex, pbr::fragment }\n",
  )
  let source = composer.compose_wgsl(
    "entry.wgsl",
    upstream_parity_compose_options(upstream_parity_empty_defines()),
  ) catch {
    err =>
      abort("expected item-imported function compose success: \{err.message()}")
  }
  debug_inspect(source.trim().length(), content="0")
}

///|
test "naga_oil parity: item-imported entry points are dropped when unused by source" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "mesh.wgsl",
    "#define_import_path demo::mesh\n" +
    "@vertex\n" +
    "fn vertex() -> vec4<f32> {\n" +
    "  return vec4<f32>(0.0);\n" +
    "}\n",
  )
  composer.register_source(
    "pbr.wgsl",
    "#define_import_path demo::pbr\n" +
    "@fragment\n" +
    "fn fragment() -> vec4<f32> {\n" +
    "  return vec4<f32>(1.0);\n" +
    "}\n",
  )
  composer.register_source(
    "entry.wgsl", "#import demo::{ mesh::vertex, pbr::fragment }\n",
  )
  let source = composer.compose_wgsl(
    "entry.wgsl",
    upstream_parity_compose_options(upstream_parity_empty_defines()),
  ) catch {
    err => abort("expected issue 3 entry compose success: \{err.message()}")
  }
  debug_inspect(source.trim().length(), content="0")
}

///|
test "naga_oil parity: direct item imports require exact AST reference paths" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "unused.wgsl",
    "#define_import_path demo::unused\n" + "fn Item() -> u32 { return 1u; }\n",
  )
  composer.register_source(
    "other.wgsl",
    "#define_import_path demo::other\n" + "fn Item() -> u32 { return 2u; }\n",
  )
  composer.register_source(
    "root.wgsl",
    "#import demo::unused::Item\n" +
    "#import demo::other as other\n" +
    "fn entry() -> u32 { return other::Item(); }\n",
  )
  let source = composer.compose_wgsl(
    "root.wgsl",
    upstream_parity_compose_options(upstream_parity_empty_defines()),
  ) catch {
    err =>
      abort("expected exact reference path compose success: \{err.message()}")
  }
  debug_inspect(source.contains("return 1u"), content="false")
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
}

///|
test "naga_oil parity: explicit import-only entry modules do not force dependencies" {
  let composer = @compose.Composer::default()
  composer.register_source(
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
  composer.register_source("entry.wgsl", "#import demo::mesh::vertex\n")
  let source = composer.compose_wgsl(
    "entry.wgsl",
    upstream_parity_compose_options(upstream_parity_empty_defines()),
  ) catch {
    err =>
      abort("expected import-only vertex compose success: \{err.message()}")
  }
  debug_inspect(source.trim().length(), content="0")
}

///|
test "github issue 3: mixed full-module and item imports do not re-emit duplicate declarations" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "types.wgsl",
    "#define_import_path demo::types\n" +
    "struct StandardMaterial { value: f32 }\n",
  )
  composer.register_source(
    "bindings.wgsl",
    "#define_import_path demo::bindings\n" +
    "#import demo::types::StandardMaterial\n" +
    "@group(3) @binding(0) var<uniform> material: StandardMaterial;\n",
  )
  composer.register_source(
    "fragment.wgsl",
    "#define_import_path demo::fragment\n" +
    "#import demo::{ types, bindings }\n" +
    "fn use_material() -> types::StandardMaterial {\n" +
    "  return bindings::material;\n" +
    "}\n",
  )
  composer.register_source(
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
      source, "struct StandardMaterialX_naga_oil_mod_X",
    ),
    content="1",
  )
  debug_inspect(source.contains("bindings__StandardMaterial"), content="false")
  debug_inspect(
    source.contains("materialX_naga_oil_mod_X") &&
    source.contains(": StandardMaterialX_naga_oil_mod_X"),
    content="true",
  )
}

///|
test "github issue 3: nested alias imports rewrite variable declaration types" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "mesh_view_types.wgsl",
    "#define_import_path bevy_pbr::mesh_view_types\n" +
    "struct Lights { value: u32 }\n",
  )
  composer.register_source(
    "view.wgsl",
    "#define_import_path bevy_render::view\n" + "struct View { value: u32 }\n",
  )
  composer.register_source(
    "globals.wgsl",
    "#define_import_path bevy_render::globals\n" +
    "struct Globals { value: u32 }\n",
  )
  composer.register_source(
    "mesh_view_bindings.wgsl",
    "#define_import_path bevy_pbr::mesh_view_bindings\n" +
    "#import bevy_pbr::mesh_view_types as types\n" +
    "#import bevy_render::{ view::View, globals::Globals }\n" +
    "@group(0) @binding(0) var<uniform> view: View;\n" +
    "@group(0) @binding(1) var<uniform> globals: Globals;\n" +
    "@group(0) @binding(2) var<uniform> lights: types::Lights;\n",
  )
  composer.register_source(
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
  debug_inspect(source.contains(": View;"), content="false")
  debug_inspect(source.contains(": Globals;"), content="false")
  debug_inspect(source.contains("types::Lights"), content="false")
  debug_inspect(
    source.contains("var<uniform> viewX_naga_oil_mod_X") &&
    source.contains(": ViewX_naga_oil_mod_X"),
    content="true",
  )
  debug_inspect(
    source.contains("var<uniform> globalsX_naga_oil_mod_X") &&
    source.contains(": GlobalsX_naga_oil_mod_X"),
    content="true",
  )
  debug_inspect(
    source.contains("var<uniform> lightsX_naga_oil_mod_X") &&
    source.contains(": LightsX_naga_oil_mod_X"),
    content="true",
  )
}

///|
test "github issue 4: nested module alias rewrites global binding member access" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "view.wgsl",
    "#define_import_path bevy_render::view\n" +
    "struct View {\n" +
    "  world_from_view: mat4x4<f32>,\n" +
    "}\n",
  )
  composer.register_source(
    "mesh_view_bindings.wgsl",
    "#define_import_path bevy_pbr::mesh_view_bindings\n" +
    "#import bevy_render::view::View\n" +
    "@group(0) @binding(0) var<uniform> view: View;\n",
  )
  composer.register_source(
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
  composer.register_source(
    "prepass_bindings.wgsl",
    "#define_import_path bevy_pbr::prepass_bindings\n" +
    "struct PreviousViewUniforms { view_from_world: mat4x4<f32> }\n" +
    "@group(0) @binding(30) var<uniform> previous_view_uniforms: PreviousViewUniforms;\n",
  )
  composer.register_source(
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
  composer.register_source(
    "root.wgsl",
    "#import bevy_pbr::pbr_functions as pbr_functions\n" +
    "fn read_world(view_pos: vec3<f32>) -> vec3<f32> {\n" +
    "  return pbr_functions::apply_transform(view_pos);\n" +
    "}\n",
  )
  let output = @export.export_wgsl_with_options(
    composer,
    "root.wgsl",
    upstream_parity_compose_options(upstream_parity_empty_defines()),
    { root_items: ["read_world"] },
  ) catch {
    err =>
      abort("expected issue 4 nested alias compose success: \{err.message()}")
  }
  let source = output.source
  debug_inspect(source.contains("view_bindings::view"), content="false")
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(
    source.contains("var<uniform> view_bindings__view: View"),
    content="false",
  )
  debug_inspect(
    source.contains("var<uniform> viewX_naga_oil_mod_X") &&
    source.contains(": ViewX_naga_oil_mod_X"),
    content="true",
  )
}

///|
test "github issue 8: Bevy module alias keeps clustered_lights binding live" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "mesh_view_bindings.wgsl",
    "#define_import_path bevy_pbr::mesh_view_bindings\n" +
    "struct ClusteredLights { value: u32 }\n" +
    "@group(0) @binding(0) var<storage, read> clustered_lights: ClusteredLights;\n",
  )
  composer.register_source(
    "pbr_lighting.wgsl",
    "#define_import_path bevy_pbr::pbr_lighting\n" +
    "#import bevy_pbr::mesh_view_bindings as view_bindings\n" +
    "fn read_clustered_light() -> u32 {\n" +
    "  return view_bindings::clustered_lights.value;\n" +
    "}\n",
  )
  composer.register_source(
    "root.wgsl",
    "#import bevy_pbr::pbr_lighting as lighting\n" +
    "fn entry() -> u32 {\n" +
    "  return lighting::read_clustered_light();\n" +
    "}\n",
  )
  let source = composer.compose_wgsl(
    "root.wgsl",
    upstream_parity_compose_options(upstream_parity_empty_defines()),
  ) catch {
    err =>
      abort(
        "expected issue 8 clustered_lights compose success: \{err.message()}",
      )
  }
  debug_inspect(
    source.contains("view_bindings::clustered_lights"),
    content="false",
  )
  debug_inspect(
    source.contains("var<storage, read> clustered_lightsX_naga_oil_mod_X") &&
    source.contains(": ClusteredLightsX_naga_oil_mod_X"),
    content="true",
  )
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
}

///|
test "github issue 9: item imported struct preserves canonical type identity" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "pbr_types.wgsl",
    "#define_import_path bevy_pbr::pbr_types\n" +
    "struct PbrInput { value: u32 }\n" +
    "fn pbr_input_new() -> PbrInput {\n" +
    "  var input: PbrInput;\n" +
    "  input.value = 1u;\n" +
    "  return input;\n" +
    "}\n",
  )
  composer.register_source(
    "pbr_fragment.wgsl",
    "#define_import_path bevy_pbr::pbr_fragment\n" +
    "#import bevy_pbr::pbr_types as pbr_types\n" +
    "fn pbr_input_from_standard_material() -> pbr_types::PbrInput {\n" +
    "  return pbr_types::pbr_input_new();\n" +
    "}\n",
  )
  composer.register_source(
    "clustered.wgsl",
    "#define_import_path bevy_pbr::decal::clustered\n" +
    "#import bevy_pbr::pbr_types::PbrInput\n" +
    "fn apply_decals(pbr_input: ptr<function, PbrInput>) {\n" +
    "  (*pbr_input).value = (*pbr_input).value + 1u;\n" +
    "}\n",
  )
  composer.register_source(
    "pbr.wgsl",
    "#import bevy_pbr::{\n" +
    "  pbr_types,\n" +
    "  pbr_fragment::pbr_input_from_standard_material,\n" +
    "  decal::clustered::apply_decals,\n" +
    "}\n" +
    "@fragment\n" +
    "fn fragment() -> @location(0) u32 {\n" +
    "  var pbr_input = pbr_input_from_standard_material();\n" +
    "  apply_decals(&pbr_input);\n" +
    "  return pbr_input.value;\n" +
    "}\n",
  )
  let source = composer.compose_wgsl(
    "pbr.wgsl",
    upstream_parity_compose_options(upstream_parity_empty_defines()),
  ) catch {
    err => abort("expected issue 9 compose success: \{err.message()}")
  }
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(source.contains("struct PbrInput {"), content="false")
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(source.contains("ptr<function, PbrInput>"), content="false")
}

///|
test "github issue 12: transitive tonemapping type identity is reused" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "view.wgsl",
    "#define_import_path bevy_render::view\n" +
    "struct ColorGrading { exposure: f32 }\n" +
    "struct View { color_grading: ColorGrading }\n",
  )
  composer.register_source(
    "mesh_view_bindings.wgsl",
    "#define_import_path bevy_pbr::mesh_view_bindings\n" +
    "#import bevy_render::view::View\n" +
    "@group(0) @binding(0) var<uniform> view: View;\n",
  )
  composer.register_source(
    "tonemapping.wgsl",
    "#define_import_path bevy_core_pipeline::tonemapping\n" +
    "#import bevy_render::view::ColorGrading\n" +
    "fn tone_mapping(in: vec4<f32>, in_color_grading: ColorGrading) -> vec4<f32> {\n" +
    "  return in;\n" +
    "}\n",
  )
  composer.register_source(
    "pbr_functions.wgsl",
    "#define_import_path bevy_pbr::pbr_functions\n" +
    "#import bevy_pbr::mesh_view_bindings as view_bindings\n" +
    "#import bevy_core_pipeline::tonemapping::tone_mapping\n" +
    "fn post_light(output_color: vec4<f32>) -> vec4<f32> {\n" +
    "  return tone_mapping(output_color, view_bindings::view.color_grading);\n" +
    "}\n",
  )
  composer.register_source(
    "pbr.wgsl",
    "#import bevy_pbr::pbr_functions as pbr_functions\n" +
    "fn root(color: vec4<f32>) -> vec4<f32> {\n" +
    "  return pbr_functions::post_light(color);\n" +
    "}\n",
  )
  let source = composer.compose_wgsl(
    "pbr.wgsl",
    upstream_parity_compose_options(upstream_parity_empty_defines()),
  ) catch {
    err => abort("expected issue 12 compose success: \{err.message()}")
  }
  let color_grading_is_consistent = source.contains(
    "in_color_grading: ColorGradingX_naga_oil_mod_X",
  )
  let color_grading_decl_is_visible = source.contains(
    "struct ColorGradingX_naga_oil_mod_X",
  )
  debug_inspect(color_grading_is_consistent, content="true")
  debug_inspect(color_grading_decl_is_visible, content="true")
  debug_inspect(
    source.contains("in_color_grading: ColorGrading)"),
    content="false",
  )
}

///|
test "composer symbol table: parent alias does not expose transitive imports" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "dep.wgsl",
    "#define_import_path app::dep\n" + "fn helper() -> u32 { return 1u; }\n",
  )
  composer.register_source(
    "consumer.wgsl",
    "#define_import_path app::consumer\n" +
    "#import app::dep::helper\n" +
    "fn call_helper() -> u32 { return helper(); }\n",
  )
  composer.register_source(
    "root.wgsl",
    "#import app::dep as dep_alias\n" +
    "#import app::consumer as consumer_alias\n" +
    "fn entry() -> u32 {\n" +
    "  return dep_alias::helper() + consumer_alias::call_helper();\n" +
    "}\n",
  )
  let source = composer.compose_wgsl(
    "root.wgsl",
    upstream_parity_compose_options(upstream_parity_empty_defines()),
  ) catch {
    err =>
      abort(
        "expected transitive alias-surface compose success: \{err.message()}",
      )
  }
  debug_inspect(source.contains("consumer_alias__helper"), content="false")
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(source.contains("return helper();"), content="false")
}

///|
test "composer symbol table: direct item emit creates local unqualified binding" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "dep.wgsl",
    "#define_import_path app::dep\n" + "fn helper() -> u32 { return 1u; }\n",
  )
  composer.register_source(
    "consumer.wgsl",
    "#define_import_path app::consumer\n" +
    "#import app::dep::helper\n" +
    "fn call_helper() -> u32 { return helper(); }\n",
  )
  composer.register_source(
    "root.wgsl",
    "#import app::consumer as consumer_alias\n" +
    "fn entry() -> u32 { return consumer_alias::call_helper(); }\n",
  )
  let source = composer.compose_wgsl(
    "root.wgsl",
    upstream_parity_compose_options(upstream_parity_empty_defines()),
  ) catch {
    err =>
      abort("expected direct item binding compose success: \{err.message()}")
  }
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(source.contains("return helper();"), content="false")
}

///|
test "github issue 6: transitive nested module alias rewrites imported binding types" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "view.wgsl",
    "#define_import_path bevy_render::view\n" + "struct View { value: u32 }\n",
  )
  composer.register_source(
    "mesh_view_bindings.wgsl",
    "#define_import_path bevy_pbr::mesh_view_bindings\n" +
    "#import bevy_render::view::View\n" +
    "@group(0) @binding(0) var<uniform> view: View;\n",
  )
  composer.register_source(
    "clustered_forward.wgsl",
    "#define_import_path bevy_pbr::clustered_forward\n" +
    "#import bevy_pbr::mesh_view_bindings as bindings\n" +
    "fn read_cluster_view() -> u32 {\n" +
    "  return bindings::view.value;\n" +
    "}\n",
  )
  composer.register_source(
    "pbr_functions.wgsl",
    "#define_import_path bevy_pbr::pbr_functions\n" +
    "#import bevy_pbr::{\n" +
    "  mesh_view_bindings as view_bindings,\n" +
    "  clustered_forward as clustering,\n" +
    "}\n" +
    "fn read_pbr_view() -> u32 {\n" +
    "  return view_bindings::view.value + clustering::read_cluster_view();\n" +
    "}\n",
  )
  composer.register_source(
    "root.wgsl",
    "#import bevy_pbr::pbr_functions as pbr_functions\n" +
    "fn read_view() -> u32 {\n" +
    "  return pbr_functions::read_pbr_view();\n" +
    "}\n",
  )
  let source = composer.compose_wgsl(
    "root.wgsl",
    upstream_parity_compose_options(upstream_parity_empty_defines()),
  ) catch {
    err =>
      abort(
        "expected issue 6 transitive nested alias compose success: \{err.message()}",
      )
  }
  debug_inspect(source.contains(": View;"), content="false")
  debug_inspect(
    source.contains(
      "var<uniform> pbr_functions__clustering__bindings__view: pbr_functions__view_bindings__View",
    ),
    content="false",
  )
  debug_inspect(
    source.contains("pbr_functions__clustering__bindings__view"),
    content="false",
  )
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(
    upstream_parity_count_occurrences(source, "viewX_naga_oil_mod_X") > 0,
    content="true",
  )
}

///|
test "github issue 6: root local defines are stripped from final composed WGSL" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "root_define.wgsl",
    "#define_import_path demo::root_define\n" +
    "#define TONEMAPPING_PASS\n" +
    "#ifdef TONEMAPPING_PASS\n" +
    "const enabled: u32 = 1u;\n" +
    "#endif\n",
  )
  let source = composer.compose_wgsl(
    "root_define.wgsl",
    upstream_parity_compose_options(upstream_parity_empty_defines()),
  ) catch {
    err => abort("expected root-local define compose success: \{err.message()}")
  }
  debug_inspect(source.contains("#define"), content="false")
  debug_inspect(source.contains("TONEMAPPING_PASS"), content="false")
  debug_inspect(source.contains("const enabled: u32 = 1u;"), content="true")
}
