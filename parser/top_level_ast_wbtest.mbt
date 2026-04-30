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
fn top_level_kind_snapshot(kind : WgslRawTopLevelKind) -> String {
  match kind {
    Trivia => "Trivia"
    Import => "Import"
    DefineImportPath => "DefineImportPath"
    Define => "Define"
    Directive => "Directive"
    Declaration => "Declaration"
  }
}

///|
test "top-level AST classifies directives imports and declarations" {
  let source = "#define_import_path bevy_pbr::demo\n" +
    "#define TONEMAPPING_PASS\n" +
    "#import bevy_render::{\n" +
    "  view::View,\n" +
    "  globals::Globals,\n" +
    "}\n" +
    "@group(0) @binding(0)\n" +
    "var<uniform> view: View;\n" +
    "struct Output {\n" +
    "  value: vec4<f32>,\n" +
    "}\n" +
    "@fragment\n" +
    "fn fragment() -> Output {\n" +
    "  var out: Output;\n" +
    "  return out;\n" +
    "}\n"
  let items = parse_wgsl_top_level_items(source)
  debug_inspect(items.length(), content="6")
  debug_inspect(
    top_level_kind_snapshot(items[0].kind),
    content="\"DefineImportPath\"",
  )
  debug_inspect(top_level_kind_snapshot(items[1].kind), content="\"Define\"")
  debug_inspect(top_level_kind_snapshot(items[2].kind), content="\"Import\"")
  debug_inspect(items[2].text.contains("globals::Globals"), content="true")
  debug_inspect(
    top_level_kind_snapshot(items[3].kind),
    content="\"Declaration\"",
  )
  debug_inspect(items[3].name, content="\"view\"")
  debug_inspect(items[4].name, content="\"Output\"")
  debug_inspect(items[5].name, content="\"fragment\"")
}

///|
test "top-level AST ignores comments while finding block boundaries" {
  let source = "struct A {\n" +
    "  // comment with }\n" +
    "  value: u32,\n" +
    "}\n" +
    "fn b() -> u32 {\n" +
    "  /* comment with { */\n" +
    "  return 1u;\n" +
    "}\n"
  let items = parse_wgsl_top_level_items(source)
  debug_inspect(items.length(), content="2")
  debug_inspect(items[0].name, content="\"A\"")
  debug_inspect(items[1].name, content="\"b\"")
}

///|
test "top-level AST preserves directive-adjacent trivia" {
  let source = "// leading import note\n" +
    "#import demo::thing\n" +
    "// trailing note\n"
  let items = parse_wgsl_top_level_items(source)
  debug_inspect(items.length(), content="3")
  debug_inspect(top_level_kind_snapshot(items[0].kind), content="\"Trivia\"")
  debug_inspect(top_level_kind_snapshot(items[1].kind), content="\"Import\"")
  debug_inspect(top_level_kind_snapshot(items[2].kind), content="\"Trivia\"")
  debug_inspect(items[0].text.contains("leading import note"), content="true")
  debug_inspect(items[2].text.contains("trailing note"), content="true")
}

///|
test "top-level AST classifies hash conditionals as directives" {
  let source = "#ifdef ENABLED\n" +
    "const A: u32 = 1u;\n" +
    "#else\n" +
    "const A: u32 = 0u;\n" +
    "#endif\n"
  let items = parse_wgsl_top_level_items(source)
  debug_inspect(items.length(), content="5")
  debug_inspect(top_level_kind_snapshot(items[0].kind), content="\"Directive\"")
  debug_inspect(
    top_level_kind_snapshot(items[1].kind),
    content="\"Declaration\"",
  )
  debug_inspect(top_level_kind_snapshot(items[2].kind), content="\"Directive\"")
  debug_inspect(
    top_level_kind_snapshot(items[3].kind),
    content="\"Declaration\"",
  )
  debug_inspect(top_level_kind_snapshot(items[4].kind), content="\"Directive\"")
}

///|
test "top-level AST recognizes same-line attributed declarations" {
  let source = "@fragment fn fragment() -> vec4<f32> {\n" +
    "  return vec4<f32>(1.0);\n" +
    "}\n" +
    "@group(0) @binding(0) var<uniform> view: View;\n" +
    "@id(0) override exposure: f32 = 1.0;\n"
  let items = parse_wgsl_top_level_items(source)
  debug_inspect(items.length(), content="3")
  debug_inspect(
    top_level_kind_snapshot(items[0].kind),
    content="\"Declaration\"",
  )
  debug_inspect(items[0].name, content="\"fragment\"")
  debug_inspect(items[1].name, content="\"view\"")
  debug_inspect(items[2].name, content="\"exposure\"")
}

///|
test "top-level AST does not treat attribute arguments as declarations" {
  let source = "@diagnostic(off, fn) struct Output {\n" +
    "  value: u32,\n" +
    "}\n"
  let items = parse_wgsl_top_level_items(source)
  debug_inspect(items.length(), content="1")
  debug_inspect(items[0].name, content="\"Output\"")
}
