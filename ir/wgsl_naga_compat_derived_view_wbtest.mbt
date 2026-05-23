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
    WgslIrImportArenaSymbol(Type, "ImportedType", "ImportedType"),
    WgslIrImportArenaSymbol(Constant, "imported_const", "imported_const"),
    WgslIrImportArenaSymbol(
      GlobalVariable,
      "imported_global",
      "imported_global",
    ),
    WgslIrImportArenaSymbol(Function, "imported_fn", "imported_fn"),
  ]
  let event = WgslIrImportArenaEvent(
    0,
    "root.wgsl",
    "dep.wgsl",
    "dep",
    "",
    symbols,
    WgslIrImportEdgeKind::ItemBinding,
    event_symbols,
  )
  let module_ = parse_wgsl_module_to_ir_with_generated_imports_and_import_arena_events(
    source,
    [],
    [event],
  ) catch {
    error => abort(error.message())
  }
  let planner = WgslIrNagaCompatPlanner::{
    shader_module: module_,
    filter: None,
  }
  let view = planner.derived_module_view()
  debug_inspect(module_.import_arena_events.length(), content="1")
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
  let event = WgslIrImportArenaEvent(
    0,
    "root.wgsl",
    "dep.wgsl",
    "dep",
    "",
    ["imported_global"],
    WgslIrImportEdgeKind::ItemBinding,
    [
      WgslIrImportArenaSymbol(
        GlobalVariable,
        "imported_global",
        "imported_global",
      ),
    ],
  )
  let module_ = parse_wgsl_module_to_ir_with_generated_imports_and_import_arena_events(
    source,
    [],
    [event],
  ) catch {
    error => abort(error.message())
  }
  let planner = WgslIrNagaCompatPlanner::{
    shader_module: module_,
    filter: None,
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
  let event = WgslIrImportArenaEvent(
    0,
    "root.wgsl",
    "dep.wgsl",
    "dep",
    "",
    ["imported_fn"],
    WgslIrImportEdgeKind::ItemBinding,
    [WgslIrImportArenaSymbol(Function, "imported_fn", "imported_fn")],
  )
  let module_ = parse_wgsl_module_to_ir_with_generated_imports_and_import_arena_events(
    source,
    [],
    [event],
  ) catch {
    error => abort(error.message())
  }
  let planner = WgslIrNagaCompatPlanner::{
    shader_module: module_,
    filter: None,
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
  let event = WgslIrImportArenaEvent(
    0,
    "root.wgsl",
    "dep.wgsl",
    "dep",
    "",
    ["selected_a", "selected_b", "late_helper"],
    WgslIrImportEdgeKind::ItemBinding,
    [
      WgslIrImportArenaSymbol(
        Function,
        "selected_a",
        "selected_a",
        source_order_rank=2,
      ),
      WgslIrImportArenaSymbol(
        Function,
        "selected_b",
        "selected_b",
        source_order_rank=3,
      ),
      WgslIrImportArenaSymbol(
        Function,
        "late_helper",
        "late_helper",
        source_order_rank=0,
      ),
    ],
  )
  let module_ = parse_wgsl_module_to_ir_with_generated_imports_and_import_arena_events(
    source,
    [],
    [event],
  ) catch {
    error => abort(error.message())
  }
  let planner = WgslIrNagaCompatPlanner::{
    shader_module: module_,
    filter: None,
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
test "Naga derived module view consumes typed arena symbol records" {
  let source =
    #|struct SharedName {
    #|  value: u32,
    #|}
    #|
    #|fn SharedName() -> u32 {
    #|  return 1u;
    #|}
    #|
  let event = WgslIrImportArenaEvent(
    0,
    "root.wgsl",
    "dep.wgsl",
    "dep",
    "",
    ["SharedName"],
    WgslIrImportEdgeKind::ItemBinding,
    [WgslIrImportArenaSymbol(Function, "SharedName", "SharedName")],
  )
  let recorded_symbols = event.generated_symbols()
  debug_inspect(recorded_symbols[0].kind(), content="Function")
  debug_inspect(
    recorded_symbols[0].source_symbol_name(),
    content="\"SharedName\"",
  )
  debug_inspect(
    recorded_symbols[0].generated_symbol_name(),
    content="\"SharedName\"",
  )
  let module_ = parse_wgsl_module_to_ir_with_generated_imports_and_import_arena_events(
    source,
    [],
    [event],
  ) catch {
    error => abort(error.message())
  }
  let planner = WgslIrNagaCompatPlanner::{
    shader_module: module_,
    filter: None,
  }
  let view = planner.derived_module_view()
  debug_inspect(
    module_.functions.items[view.functions[0]].name,
    content="Some(\"SharedName\")",
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
  let event = WgslIrImportArenaEvent(
    0,
    "root.wgsl",
    "dep.wgsl",
    "dep",
    "",
    ["DirectType", "direct_global", "direct_function"],
    WgslIrImportEdgeKind::ItemBinding,
    [
      WgslIrImportArenaSymbol(Function, "direct_function", "direct_function"),
      WgslIrImportArenaSymbol(Type, "FunctionArgType", "FunctionArgType"),
      WgslIrImportArenaSymbol(Type, "DirectType", "DirectType"),
      WgslIrImportArenaSymbol(Type, "GlobalType", "GlobalType"),
      WgslIrImportArenaSymbol(GlobalVariable, "direct_global", "direct_global"),
    ],
  )
  let module_ = parse_wgsl_module_to_ir_with_generated_imports_and_import_arena_events(
    source,
    [],
    [event],
  ) catch {
    error => abort(error.message())
  }
  let planner = WgslIrNagaCompatPlanner::{
    shader_module: module_,
    filter: None,
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
