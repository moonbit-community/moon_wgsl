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
fn top_level_item_text(source : String, item : WgslRawTopLevelItem) -> String {
  source[item.start:item.end].to_owned()
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
  debug_inspect(
    top_level_item_text(source, items[2]).contains("globals::Globals"),
    content="true",
  )
  debug_inspect(
    top_level_kind_snapshot(items[3].kind),
    content="\"Declaration\"",
  )
  debug_inspect(
    top_level_item_text(source, items[3]).contains("var<uniform> view"),
    content="true",
  )
  debug_inspect(
    top_level_item_text(source, items[4]).contains("struct Output"),
    content="true",
  )
  debug_inspect(
    top_level_item_text(source, items[5]).contains("fn fragment"),
    content="true",
  )
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
  debug_inspect(
    top_level_item_text(source, items[0]).contains("struct A"),
    content="true",
  )
  debug_inspect(
    top_level_item_text(source, items[1]).contains("fn b"),
    content="true",
  )
}

///|
test "top-level AST ignores quoted braces while finding boundaries" {
  let source = "const A = \"{\";\n" +
    "const B: u32 = 1u;\n" +
    "#import demo::{\n" +
    "  thing::Value,\n" +
    "}\n"
  let items = parse_wgsl_top_level_items(source)
  debug_inspect(items.length(), content="3")
  debug_inspect(
    top_level_item_text(source, items[0]).contains("const A"),
    content="true",
  )
  debug_inspect(
    top_level_item_text(source, items[1]).contains("const B"),
    content="true",
  )
  debug_inspect(top_level_kind_snapshot(items[2].kind), content="\"Import\"")
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
  debug_inspect(
    top_level_item_text(source, items[0]).contains("leading import note"),
    content="true",
  )
  debug_inspect(
    top_level_item_text(source, items[2]).contains("trailing note"),
    content="true",
  )
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
  debug_inspect(
    top_level_item_text(source, items[0]).contains("fn fragment"),
    content="true",
  )
  debug_inspect(
    top_level_item_text(source, items[1]).contains("var<uniform> view"),
    content="true",
  )
  debug_inspect(
    top_level_item_text(source, items[2]).contains("override exposure"),
    content="true",
  )
}

///|
test "top-level AST splits adjacent declarations by token boundaries" {
  let source = "const A: u32 = 1u; const B: u32 = 2u;\n" +
    "fn make() -> u32 { return A; } const C: u32 = B;\n" +
    "struct S { value: u32, }; const D: u32 = C;\n"
  let items = parse_wgsl_top_level_items(source)
  debug_inspect(items.length(), content="6")
  debug_inspect(
    top_level_item_text(source, items[0]).contains("const A"),
    content="true",
  )
  debug_inspect(
    top_level_item_text(source, items[1]).contains("const B"),
    content="true",
  )
  debug_inspect(
    top_level_item_text(source, items[2]).contains("fn make"),
    content="true",
  )
  debug_inspect(
    top_level_item_text(source, items[3]).contains("const C"),
    content="true",
  )
  debug_inspect(
    top_level_item_text(source, items[4]).contains("struct S"),
    content="true",
  )
  debug_inspect(
    top_level_item_text(source, items[5]).contains("const D"),
    content="true",
  )
  debug_inspect(
    items.map(fn(item) { top_level_kind_snapshot(item.kind) }),
    content=(
      #|[
      #|  "Declaration",
      #|  "Declaration",
      #|  "Declaration",
      #|  "Declaration",
      #|  "Declaration",
      #|  "Declaration",
      #|]
    ),
  )
}

///|
test "top-level AST does not treat hash interpolation braces as block boundaries" {
  let source = "@group(#{MATERIAL_BIND_GROUP}) @binding(0) " +
    "var<uniform> mesh: array<Mesh, #{PER_OBJECT_BUFFER_BATCH_SIZE}u>;\n" +
    "const NEXT: u32 = 1u;\n"
  let items = parse_wgsl_top_level_items(source)
  debug_inspect(items.length(), content="2")
  debug_inspect(
    top_level_item_text(source, items[0]).contains("var<uniform> mesh"),
    content="true",
  )
  debug_inspect(
    top_level_item_text(source, items[1]).contains("const NEXT"),
    content="true",
  )
}

///|
test "top-level AST does not treat attribute arguments as declarations" {
  let source = "@diagnostic(off, fn) struct Output {\n" +
    "  value: u32,\n" +
    "}\n"
  let items = parse_wgsl_top_level_items(source)
  debug_inspect(items.length(), content="1")
  debug_inspect(
    top_level_item_text(source, items[0]).contains("struct Output"),
    content="true",
  )
}
