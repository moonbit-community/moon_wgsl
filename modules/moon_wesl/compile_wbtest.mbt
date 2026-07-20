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
fn compile_test_module(
  source : String,
) -> TranslationUnit raise WeslCompileError {
  parse_translation_unit(try! parse_module_path("root"), source, true)
}

///|
fn compile_test_named_items(
  names : Array[String],
) -> @hashmap.HashMap[String, Int] {
  let items : @hashmap.HashMap[String, Int] = HashMap([])
  for i in 0..<names.length() {
    items.set(names[i], i)
  }
  items
}

///|
fn compile_test_ast_refs(
  header : GlobalDeclarationHeader,
  names : Array[String],
) -> Array[ModuleItemRef] {
  wesl_collect_ast_item_references(
    header,
    compile_test_named_items(names),
    HashMap([]),
    [],
    try! parse_module_path("root"),
  )
}

///|
fn compile_test_module_item_refs(
  decl : GlobalDeclaration,
  names : Array[String],
) -> Array[ModuleItemRef] {
  wesl_collect_module_item_references(
    {
      name: decl.ident(),
      kind: wesl_item_kind(decl.header),
      header: decl.header,
      attributes: decl.attributes,
      source: decl.source,
      span: decl.span,
      entrypoint: decl.is_entrypoint(),
      is_const_assert: decl.is_const_assert(),
      references: [],
    },
    compile_test_named_items(names),
    HashMap([]),
    [],
    try! parse_module_path("root"),
  )
}

///|
fn compile_test_ast_refs_with_import(
  header : GlobalDeclarationHeader,
  namespace_path : ModulePath,
  local_name : String,
) -> Array[ModuleItemRef] {
  let imports = [
    ImportItem::{
      export_module_path: None,
      export_name: None,
      namespace_path,
      local_name,
      public: false,
      start_line: 1,
      end_line: 1,
    },
  ]
  let import_by_local : @hashmap.HashMap[String, Int] = HashMap([])
  import_by_local.set(local_name, 0)
  wesl_collect_ast_item_references(
    header,
    HashMap([]),
    import_by_local,
    imports,
    try! parse_module_path("root"),
  )
}

///|
test "compile: AST reference collector follows attribute expression refs" {
  let source =
    #|const GROUP_SIZE = 64;
    #|const INPUT_LOCATION = 0;
    #|const OUTPUT_LOCATION = 1;
    #|
    #|@compute
    #|@workgroup_size(GROUP_SIZE)
    #|fn main(@location(INPUT_LOCATION) value: f32) -> @location(OUTPUT_LOCATION) f32 {
    #|  return value;
    #|}
  let unit = compile_test_module(source)
  let refs = compile_test_module_item_refs(unit.global_declarations[3], [
    "GROUP_SIZE", "INPUT_LOCATION", "OUTPUT_LOCATION", "main",
  ])
  inspect(refs.length(), content="3")
  inspect(refs[0] == Local("GROUP_SIZE"), content="true")
  inspect(refs[1] == Local("INPUT_LOCATION"), content="true")
  inspect(refs[2] == Local("OUTPUT_LOCATION"), content="true")
}

///|
test "compile: AST reference collector follows structured expression and type refs" {
  let source =
    #|struct Payload {
    #|  value: f32,
    #|}
    #|
    #|fn make_payload() -> Payload {
    #|  let item: Payload = Payload(1.0);
    #|  return item;
    #|}
  let unit = compile_test_module(source)
  let refs = compile_test_ast_refs(unit.global_declarations[1].header, [
    "Payload", "make_payload",
  ])
  inspect(refs.length(), content="1")
  inspect(refs[0] == Local("Payload"), content="true")
}

///|
test "compile: AST reference collector follows function return type refs" {
  let source =
    #|struct Payload {
    #|  value: f32,
    #|}
    #|
    #|fn make_payload() -> Payload {
    #|  return;
    #|}
  let unit = compile_test_module(source)
  let refs = compile_test_ast_refs(unit.global_declarations[1].header, [
    "Payload", "make_payload",
  ])
  inspect(refs.length(), content="1")
  inspect(refs[0] == Local("Payload"), content="true")
}

///|
test "compile: AST reference collector does not bind parameters inside type list" {
  let source =
    #|struct Payload {
    #|  value: f32,
    #|}
    #|
    #|fn consume(Payload: Payload) {
    #|  let next = Payload;
    #|}
  let unit = compile_test_module(source)
  let refs = compile_test_ast_refs(unit.global_declarations[1].header, [
    "Payload", "consume",
  ])
  inspect(refs.length(), content="1")
  inspect(refs[0] == Local("Payload"), content="true")
}

///|
test "compile: AST reference collector respects local shadowing" {
  let source =
    #|struct Payload {
    #|  value: f32,
    #|}
    #|
    #|fn main() {
    #|  let Payload = 1;
    #|  let next = Payload;
    #|}
  let unit = compile_test_module(source)
  let refs = compile_test_ast_refs(unit.global_declarations[1].header, [
    "Payload", "main",
  ])
  inspect(refs.length(), content="0")
}

///|
test "compile: AST reference collector follows global const_assert refs" {
  let source =
    #|const expected = 1;
    #|const_assert expected == 1;
  let unit = compile_test_module(source)
  let refs = compile_test_ast_refs(unit.global_declarations[1].header, [
    "expected",
  ])
  inspect(refs.length(), content="1")
  inspect(refs[0] == Local("expected"), content="true")
}

///|
test "compile: AST reference collector follows qualified import paths" {
  let source =
    #|fn make_payload() -> util::Payload {
    #|  let item: util::Payload = util::Payload();
    #|  return item;
    #|}
  let unit = compile_test_module(source)
  let refs = compile_test_ast_refs_with_import(
    unit.global_declarations[0].header,
    try! parse_module_path("/pkg/util"),
    "util",
  )
  inspect(refs.length(), content="1")
  inspect(
    refs[0] ==
    Qualified("util::Payload", try! parse_module_path("/pkg/util"), "Payload"),
    content="true",
  )
}

///|
test "compile: sourcemap records loaded imports before failure" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  let util_path = ModulePath::from_path("/shaders/util")
  resolver.add_module(
    root_path, "import super::util::missing;\n@fragment\nfn main() -> f32 {\n  return missing();\n}\n",
  )
  resolver.add_module(util_path, "fn helper() -> f32 {\n  return 1.0;\n}\n")
  let source_map = BasicSourceMap::{
    ..BasicSourceMap::default(),
    root: root_path,
  }

  let result = try
    compile_with_mangler_kind_and_sourcemap(
      root_path,
      resolver,
      Escape,
      CompileOptions::default(),
      true,
      source_map,
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }

  match result {
    Err(MissingDecl(path, item)) => {
      inspect(path.to_string(), content="package::shaders::util")
      inspect(item, content="missing")
      debug_inspect(
        source_map.get_source(root_path),
        content="Some(\"import super::util::missing;\\n@fragment\\nfn main() -> f32 {\\n  return missing();\\n}\\n\")",
      )
      debug_inspect(
        source_map.get_source(util_path),
        content="Some(\"fn helper() -> f32 {\\n  return 1.0;\\n}\\n\")",
      )
      match
        source_map.get_decl(ManglerKind::mangle(Escape, util_path, "helper")) {
        Some((decl_path, decl_name)) => {
          inspect(decl_path.to_string(), content="package::shaders::util")
          inspect(decl_name, content="helper")
        }
        None => fail("expected imported helper declaration mapping")
      }
    }
    _ => fail("expected missing imported declaration")
  }
}
