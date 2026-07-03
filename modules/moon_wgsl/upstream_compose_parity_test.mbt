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
fn upstream_parity_empty_defines() -> Map[String, Bool] {
  Map([])
}

///|
fn upstream_parity_bool_defines(names : Array[String]) -> Map[String, Bool] {
  let defines : Map[String, Bool] = Map([])
  for name in names {
    defines.set(name, true)
  }
  defines
}

///|
fn upstream_parity_shader_def_values(
  names : Array[String],
) -> Map[String, @common.ShaderDefValue] {
  let defines : Map[String, @common.ShaderDefValue] = Map([])
  for name in names {
    defines.set(name, Bool(true))
  }
  defines
}

///|
fn upstream_parity_compose_options(
  defines : Map[String, Bool],
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
    moon_wgsl_testdata_path("upstream_compose/\{case_name}"),
    @common.WgslSourceScanOptions::default(),
  ) catch {
    _ => abort("expected upstream fixture registration success")
  }
  composer
}

///|
fn upstream_parity_descriptor_effective_defs_source(
  shader_defs : Map[String, @common.ShaderDefValue],
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
      shader_defs: Map([]),
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
  shader_defs : Map[String, @common.ShaderDefValue],
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
  shader_defs.set("DEF_THREE", Bool(false))
  upstream_parity_check_effective_defs_sum(
    shader_defs, expected_a, expected_b, "0u",
  )
}

///|
fn upstream_mirror_composer(case_name : String) -> @compose.Composer {
  let composer = @compose.Composer::default()
  composer.clear_sources()
  composer.register_source_tree(
    moon_wgsl_testdata_path("naga_oil_upstream/compose_tests/\{case_name}"),
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
  defines : Map[String, Bool],
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
  defines : Map[String, Bool],
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
  defines : Map[String, Bool],
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
    message.contains("required import 'b' not found"),
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
    message.contains("required import 'b' not found"),
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
    message.contains("required import 'missing' not found"),
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
  debug_inspect(source.contains("let _e38: u32 = y;"), content="true")
  debug_inspect(source.contains("return f32(_e38);"), content="true")
  debug_inspect(source.contains("test_module::entry_point"), content="false")
}

///|
test "naga_oil upstream: effective defs drive imported declaration values" {
  let source = upstream_parity_compose_case(
    "effective_defs",
    "top.wgsl",
    upstream_parity_bool_defines(["DEF_ONE", "DEF_THREE"]),
  )
  debug_inspect(source.contains("aX_naga_oil_mod_X"), content="true")
  debug_inspect(source.contains(": u32 = 1u;"), content="true")
  debug_inspect(source.contains("bX_naga_oil_mod_X"), content="true")
  debug_inspect(source.contains(": u32 = 0u;"), content="true")
  debug_inspect(source.contains("cX_naga_oil_mod_X"), content="true")
  debug_inspect(source.contains(": u32 = 4u;"), content="true")
  let output = upstream_parity_export_case(
    "effective_defs",
    "top.wgsl",
    ["entry_point"],
    upstream_parity_bool_defines(["DEF_ONE", "DEF_THREE"]),
  )
  debug_inspect(output.source.contains("return 5f;"), content="true")
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
    output.source.contains("fragmentX_naga_oil_mod_X"),
    content="true",
  )
  debug_inspect(output.source.contains("X_naga_oil_mod_X"), content="true")
}

///|
test "naga_oil writer profile preserves diagnostic directives while binding ambient globals" {
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
test "naga_oil writer profile preserves dual source blending enable directive" {
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
    (
      #|enable dual_source_blending;
      #|struct FragmentOutput {
      #|  @location(0)
      #|  @blend_src(0)
      #|  source0_: vec4<f32>,
      #|  @location(0)
      #|  @blend_src(1)
      #|  source1_: vec4<f32>,
      #|}
      #|@fragment
      #|fn fragment() -> FragmentOutput {
      #|  return FragmentOutput(vec4<f32>(), vec4<f32>());
      #|}
      #|
    ),
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
  debug_inspect(source.contains("(arg_1 * 3f)"), content="true")
  debug_inspect(source.contains("(arg * 2f)"), content="true")
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
  debug_inspect(source.contains("(arg_1 * 3f)"), content="true")
  debug_inspect(source.contains("(arg * 2f)"), content="true")
  debug_inspect(source.contains("X_naga_oil_vrt_X"), content="true")
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
  debug_inspect(source.contains("X_naga_oil_mod_X"), content="true")
}

///|
test "naga_oil upstream: additional import plugin overrides virtual function" {
  let composer = upstream_mirror_composer("add_imports")
  let options = upstream_parity_compose_options(upstream_parity_empty_defines())
  options.additional_imports.push({ import_path: "plugin", items: [] })
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
  debug_inspect(message.contains("`outer` is not virtual"), content="true")
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
  debug_inspect(message.contains("invalid WGSL IR pipeline"), content="true")
  debug_inspect(message.contains("unknown WGSL identifier"), content="true")
}

///|
test "naga_oil writer profile preserves raycast enable directive" {
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
