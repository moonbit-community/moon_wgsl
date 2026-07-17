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
test "Naga derived module view follows import arena events before root declarations" {
  let source =
    #|struct RootType {
    #|  value: u32,
    #|}
    #|
    #|struct ImportedType {
    #|  value: u32,
    #|}
    #|
    #|const imported_const: u32 = 1u;
    #|var<private> imported_global: u32;
    #|
    #|fn root_fn() -> u32 {
    #|  return imported_fn();
    #|}
    #|
    #|fn imported_fn() -> u32 {
    #|  return imported_const + imported_global;
    #|}
    #|
  let symbols = [
    "ImportedType", "imported_const", "imported_global", "imported_fn",
  ]
  let event_symbols = [
    WgslNagaImportArenaSymbol(Type, "ImportedType", "ImportedType"),
    WgslNagaImportArenaSymbol(Constant, "imported_const", "imported_const"),
    WgslNagaImportArenaSymbol(
      GlobalVariable,
      "imported_global",
      "imported_global",
    ),
    WgslNagaImportArenaSymbol(Function, "imported_fn", "imported_fn"),
  ]
  let event = WgslNagaImportArenaEvent(
    0,
    "root.wgsl",
    "dep.wgsl",
    "dep",
    "",
    symbols,
    ItemBinding,
    event_symbols,
  )
  let (module_, compatibility) = wgsl_naga_test_parse_with_import_graph(
    source,
    [],
    [event],
  ) catch {
    error => abort(error.message())
  }
  let planner = WgslIrWriterPlanner::{
    shader_module: module_,
    filter: None,
    compatibility,
  }
  let view = planner.derived_module_view()
  debug_inspect(compatibility.import_arena_events.length(), content="1")
  debug_inspect(
    module_.types.items[view.types[1]].name,
    content="Some(\"ImportedType\")",
  )
  debug_inspect(
    module_.constants.items[view.constants[0]].name,
    content="Some(\"imported_const\")",
  )
  debug_inspect(
    module_.global_variables.items[view.global_variables[0]].name,
    content="Some(\"imported_global\")",
  )
  debug_inspect(
    module_.functions.items[view.functions[0]].name,
    content="Some(\"imported_fn\")",
  )
}

///|
test "Naga derived module view imports global type dependencies as arena side effects" {
  let source =
    #|struct RootType {
    #|  value: u32,
    #|}
    #|
    #|struct ImportedType {
    #|  value: u32,
    #|}
    #|
    #|var<private> imported_global: ImportedType;
    #|
  let event = WgslNagaImportArenaEvent(
    0,
    "root.wgsl",
    "dep.wgsl",
    "dep",
    "",
    ["imported_global"],
    ItemBinding,
    [
      WgslNagaImportArenaSymbol(
        GlobalVariable,
        "imported_global",
        "imported_global",
      ),
    ],
  )
  let (module_, compatibility) = wgsl_naga_test_parse_with_import_graph(
    source,
    [],
    [event],
  ) catch {
    error => abort(error.message())
  }
  let planner = WgslIrWriterPlanner::{
    shader_module: module_,
    filter: None,
    compatibility,
  }
  let view = planner.derived_module_view()
  debug_inspect(
    module_.types.items[view.types[1]].name,
    content="Some(\"ImportedType\")",
  )
  debug_inspect(
    module_.global_variables.items[view.global_variables[0]].name,
    content="Some(\"imported_global\")",
  )
}

///|
test "Naga derived module view keeps later global types in semantic arena order" {
  let source =
    #|struct FirstType {
    #|  value: u32,
    #|}
    #|
    #|var<private> early_global: LaterType;
    #|
    #|struct MiddleType {
    #|  value: u32,
    #|}
    #|
    #|struct LaterType {
    #|  value: u32,
    #|}
    #|
  let event = WgslNagaImportArenaEvent(
    0,
    "root.wgsl",
    "dep.wgsl",
    "dep",
    "",
    ["early_global"],
    ItemBinding,
    [WgslNagaImportArenaSymbol(GlobalVariable, "early_global", "early_global")],
  )
  let (module_, compatibility) = wgsl_naga_test_parse_with_import_graph(
    source,
    [
      WgslNagaGeneratedImportProvenance(
        "FirstType",
        "dep.wgsl",
        "FirstType",
        ImportedSourceSymbol,
        false,
        composed_source_start=0,
        source_end=10,
      ),
      WgslNagaGeneratedImportProvenance(
        "MiddleType",
        "dep.wgsl",
        "MiddleType",
        ImportedSourceSymbol,
        false,
        composed_source_start=20,
        source_end=30,
      ),
      WgslNagaGeneratedImportProvenance(
        "LaterType",
        "dep.wgsl",
        "LaterType",
        ImportedSourceSymbol,
        false,
        composed_source_start=40,
        source_end=50,
      ),
    ],
    [event],
  ) catch {
    error => abort(error.message())
  }
  let planner = WgslIrWriterPlanner::{
    shader_module: module_,
    filter: None,
    compatibility,
  }
  let view = planner.derived_module_view()
  let names : Array[String] = []
  for index in view.types {
    match module_.types.items[index].name {
      Some("FirstType" | "MiddleType" | "LaterType" as name) => names.push(name)
      _ => ()
    }
  }
  debug_inspect(names.join(","), content="\"FirstType,MiddleType,LaterType\"")
}

///|
test "Naga derived module view imports called functions before imported caller" {
  let source =
    #|fn root_fn() -> u32 {
    #|  return 0u;
    #|}
    #|
    #|fn imported_fn() -> u32 {
    #|  return helper_fn();
    #|}
    #|
    #|fn helper_fn() -> u32 {
    #|  return 1u;
    #|}
    #|
  let event = WgslNagaImportArenaEvent(
    0,
    "root.wgsl",
    "dep.wgsl",
    "dep",
    "",
    ["imported_fn"],
    ItemBinding,
    [WgslNagaImportArenaSymbol(Function, "imported_fn", "imported_fn")],
  )
  let (module_, compatibility) = wgsl_naga_test_parse_with_import_graph(
    source,
    [],
    [event],
  ) catch {
    error => abort(error.message())
  }
  let planner = WgslIrWriterPlanner::{
    shader_module: module_,
    filter: None,
    compatibility,
  }
  let view = planner.derived_module_view()
  debug_inspect(
    module_.functions.items[view.functions[0]].name,
    content="Some(\"helper_fn\")",
  )
  debug_inspect(
    module_.functions.items[view.functions[1]].name,
    content="Some(\"imported_fn\")",
  )
}

///|
test "Naga derived module view sorts imported functions by source arena rank" {
  let source =
    #|fn selected_a() -> u32 {
    #|  return 1u;
    #|}
    #|
    #|fn selected_b() -> u32 {
    #|  return 2u;
    #|}
    #|
    #|fn late_helper() -> u32 {
    #|  return 3u;
    #|}
    #|
  let event = WgslNagaImportArenaEvent(
    0,
    "root.wgsl",
    "dep.wgsl",
    "dep",
    "",
    ["selected_a", "selected_b", "late_helper"],
    ItemBinding,
    [
      WgslNagaImportArenaSymbol(
        Function,
        "selected_a",
        "selected_a",
        source_order_rank=2,
      ),
      WgslNagaImportArenaSymbol(
        Function,
        "selected_b",
        "selected_b",
        source_order_rank=3,
      ),
      WgslNagaImportArenaSymbol(
        Function,
        "late_helper",
        "late_helper",
        source_order_rank=0,
      ),
    ],
  )
  let (module_, compatibility) = wgsl_naga_test_parse_with_import_graph(
    source,
    [],
    [event],
  ) catch {
    error => abort(error.message())
  }
  let planner = WgslIrWriterPlanner::{
    shader_module: module_,
    filter: None,
    compatibility,
  }
  let view = planner.derived_module_view()
  debug_inspect(
    module_.functions.items[view.functions[0]].name,
    content="Some(\"late_helper\")",
  )
  debug_inspect(
    module_.functions.items[view.functions[1]].name,
    content="Some(\"selected_a\")",
  )
  debug_inspect(
    module_.functions.items[view.functions[2]].name,
    content="Some(\"selected_b\")",
  )
}

///|
test "Writer arena uses derived constant import order" {
  let source =
    #|const source_first: u32 = 1u;
    #|const callee_dependency: u32 = 2u;
    #|
    #|fn imported_callee() -> u32 {
    #|  return callee_dependency;
    #|}
    #|
    #|fn selected() -> u32 {
    #|  return imported_callee() + source_first;
    #|}
    #|
  let event = WgslNagaImportArenaEvent(
    0,
    "root.wgsl",
    "dep.wgsl",
    "dep",
    "",
    ["selected"],
    ItemBinding,
    [WgslNagaImportArenaSymbol(Function, "selected", "selected")],
  )
  let (module_, compatibility) = wgsl_naga_test_parse_with_import_graph(
    source,
    [],
    [event],
  ) catch {
    error => abort(error.message())
  }
  let planner = WgslIrWriterPlanner::{
    shader_module: module_,
    filter: None,
    compatibility,
  }
  let arena = planner.writer_arena()
  let names : Array[String] = []
  for slot in arena.constants {
    match slot.item.name {
      Some(name) => names.push(name)
      None => ()
    }
  }
  debug_inspect(names.join(","), content="\"callee_dependency,source_first\"")
}

///|
test "Writer arena does not root unused full-module generated constants" {
  let source =
    #|const DEP: u32 = 1u;
    #|const USED: u32 = DEP;
    #|const UNUSED: u32 = 2u;
    #|
    #|fn selected() -> u32 {
    #|  return USED;
    #|}
    #|
  let event = WgslNagaImportArenaEvent(
    0,
    "root.wgsl",
    "dep.wgsl",
    "dep",
    "",
    [],
    FullModule,
    [
      WgslNagaImportArenaSymbol(Constant, "DEP", "DEP"),
      WgslNagaImportArenaSymbol(Constant, "USED", "USED"),
      WgslNagaImportArenaSymbol(Constant, "UNUSED", "UNUSED"),
      WgslNagaImportArenaSymbol(Function, "selected", "selected"),
    ],
  )
  let (module_, compatibility) = wgsl_naga_test_parse_with_import_graph(
    source,
    [
      WgslNagaGeneratedImportProvenance(
        "DEP",
        "dep.wgsl",
        "DEP",
        ImportedSourceSymbol,
        false,
      ),
      WgslNagaGeneratedImportProvenance(
        "USED",
        "dep.wgsl",
        "USED",
        ImportedSourceSymbol,
        false,
      ),
      WgslNagaGeneratedImportProvenance(
        "UNUSED",
        "dep.wgsl",
        "UNUSED",
        ImportedSourceSymbol,
        false,
      ),
      WgslNagaGeneratedImportProvenance(
        "selected",
        "dep.wgsl",
        "selected",
        ImportedSourceSymbol,
        false,
      ),
    ],
    [event],
  ) catch {
    error => abort(error.message())
  }
  let planner = WgslIrWriterPlanner::{
    shader_module: module_,
    filter: None,
    compatibility,
  }
  let arena = planner.writer_arena()
  let names : Array[String] = []
  for slot in arena.constants {
    match slot.item.name {
      Some(name) => names.push(name)
      None => ()
    }
  }
  debug_inspect(names.join(","), content="\"USED,DEP\"")
}

///|
test "Writer arena imports entry point generated constant dependencies" {
  let source =
    #|const ENTRY_FLAG: u32 = 1u;
    #|const UNUSED_FLAG: u32 = 2u;
    #|
    #|@compute @workgroup_size(1)
    #|fn main() {
    #|  if ENTRY_FLAG != 0u {
    #|    return;
    #|  }
    #|}
    #|
  let event = WgslNagaImportArenaEvent(
    0,
    "root.wgsl",
    "dep.wgsl",
    "dep",
    "",
    [],
    FullModule,
    [
      WgslNagaImportArenaSymbol(Constant, "ENTRY_FLAG", "ENTRY_FLAG"),
      WgslNagaImportArenaSymbol(Constant, "UNUSED_FLAG", "UNUSED_FLAG"),
    ],
  )
  let (module_, compatibility) = wgsl_naga_test_parse_with_import_graph(
    source,
    [
      WgslNagaGeneratedImportProvenance(
        "ENTRY_FLAG",
        "dep.wgsl",
        "ENTRY_FLAG",
        ImportedSourceSymbol,
        false,
      ),
      WgslNagaGeneratedImportProvenance(
        "UNUSED_FLAG",
        "dep.wgsl",
        "UNUSED_FLAG",
        ImportedSourceSymbol,
        false,
      ),
    ],
    [event],
  ) catch {
    error => abort(error.message())
  }
  let planner = WgslIrWriterPlanner::{
    shader_module: module_,
    filter: None,
    compatibility,
  }
  let arena = planner.writer_arena()
  let names : Array[String] = []
  for slot in arena.constants {
    match slot.item.name {
      Some(name) => names.push(name)
      None => ()
    }
  }
  debug_inspect(names.join(","), content="\"ENTRY_FLAG\"")
}

///|
test "Writer arena uses derived nested function-call order" {
  let source =
    #|fn parent_callee(value: u32) -> u32 {
    #|  return value;
    #|}
    #|
    #|fn argument_callee() -> u32 {
    #|  return 1u;
    #|}
    #|
    #|fn selected() -> u32 {
    #|  return parent_callee(argument_callee());
    #|}
    #|
  let event = WgslNagaImportArenaEvent(
    0,
    "root.wgsl",
    "dep.wgsl",
    "dep",
    "",
    ["selected"],
    ItemBinding,
    [WgslNagaImportArenaSymbol(Function, "selected", "selected")],
  )
  let (module_, compatibility) = wgsl_naga_test_parse_with_import_graph(
    source,
    [],
    [event],
  ) catch {
    error => abort(error.message())
  }
  let planner = WgslIrWriterPlanner::{
    shader_module: module_,
    filter: None,
    compatibility,
  }
  let arena = planner.writer_arena()
  let names : Array[String] = []
  for slot in arena.functions {
    match slot.item.name {
      Some(name) => names.push(name)
      None => ()
    }
  }
  debug_inspect(
    names.join(","),
    content="\"argument_callee,parent_callee,selected\"",
  )
}

///|
test "Naga derived module view consumes typed arena symbol records" {
  let source =
    #|struct SharedName {
    #|  value: u32,
    #|}
    #|
    #|fn shared_name() -> u32 {
    #|  return 1u;
    #|}
    #|
  let event = WgslNagaImportArenaEvent(
    0,
    "root.wgsl",
    "dep.wgsl",
    "dep",
    "",
    ["shared_name"],
    ItemBinding,
    [WgslNagaImportArenaSymbol(Function, "shared_name", "shared_name")],
  )
  let recorded_symbols = event.generated_symbols()
  debug_inspect(recorded_symbols[0].kind(), content="Function")
  debug_inspect(
    recorded_symbols[0].source_symbol_name(),
    content="\"shared_name\"",
  )
  debug_inspect(
    recorded_symbols[0].generated_symbol_name(),
    content="\"shared_name\"",
  )
  let (module_, compatibility) = wgsl_naga_test_parse_with_import_graph(
    source,
    [],
    [event],
  ) catch {
    error => abort(error.message())
  }
  let planner = WgslIrWriterPlanner::{
    shader_module: module_,
    filter: None,
    compatibility,
  }
  let view = planner.derived_module_view()
  debug_inspect(
    module_.functions.items[view.functions[0]].name,
    content="Some(\"shared_name\")",
  )
}

///|
test "Naga derived module view filters selected items through category loops" {
  let source =
    #|struct FunctionArgType {
    #|  value: u32,
    #|}
    #|
    #|struct DirectType {
    #|  value: u32,
    #|}
    #|
    #|struct GlobalType {
    #|  value: u32,
    #|}
    #|
    #|var<private> direct_global: GlobalType;
    #|
    #|fn direct_function(value: FunctionArgType) -> u32 {
    #|  return value.value;
    #|}
    #|
  let event = WgslNagaImportArenaEvent(
    0,
    "root.wgsl",
    "dep.wgsl",
    "dep",
    "",
    ["DirectType", "direct_global", "direct_function"],
    ItemBinding,
    [
      WgslNagaImportArenaSymbol(Function, "direct_function", "direct_function"),
      WgslNagaImportArenaSymbol(Type, "FunctionArgType", "FunctionArgType"),
      WgslNagaImportArenaSymbol(Type, "DirectType", "DirectType"),
      WgslNagaImportArenaSymbol(Type, "GlobalType", "GlobalType"),
      WgslNagaImportArenaSymbol(
        GlobalVariable,
        "direct_global",
        "direct_global",
      ),
    ],
  )
  let (module_, compatibility) = wgsl_naga_test_parse_with_import_graph(
    source,
    [],
    [event],
  ) catch {
    error => abort(error.message())
  }
  let planner = WgslIrWriterPlanner::{
    shader_module: module_,
    filter: None,
    compatibility,
  }
  let view = planner.derived_module_view()
  debug_inspect(
    module_.types.items[view.types[1]].name,
    content="Some(\"DirectType\")",
  )
  debug_inspect(
    module_.types.items[view.types[2]].name,
    content="Some(\"GlobalType\")",
  )
  debug_inspect(
    module_.types.items[view.types[3]].name,
    content="Some(\"FunctionArgType\")",
  )
  debug_inspect(
    module_.global_variables.items[view.global_variables[0]].name,
    content="Some(\"direct_global\")",
  )
  debug_inspect(
    module_.functions.items[view.functions[0]].name,
    content="Some(\"direct_function\")",
  )
}
