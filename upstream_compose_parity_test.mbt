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
