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
test "WGSL AST lowers declarations, bindings, and entry point metadata into IR" {
  let source =
    #|struct VertexIn {
    #|  @location(0) value: f32,
    #|}
    #|
    #|@group(0) @binding(1)
    #|var<uniform> scale: f32;
    #|
    #|const COUNT: u32 = 4u;
    #|@id(3) override ENABLED: bool = true;
    #|
    #|@compute @workgroup_size(2, 3, 4)
    #|fn main(@builtin(global_invocation_id) id: vec3u) {
    #|  var local_value: u32 = COUNT + 1u;
    #|  local_value = local_value + 1u;
    #|  return;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  debug_inspect(module_.global_variables.items.length(), content="1")
  debug_inspect(module_.constants.items.length(), content="1")
  debug_inspect(module_.overrides.items.length(), content="1")
  debug_inspect(module_.entry_points.length(), content="1")
  debug_inspect(module_.entry_points[0].workgroup_size, content="[2, 3, 4]")
  debug_inspect(
    module_.entry_points[0].function.arguments[0].binding,
    content="Some(BuiltIn(GlobalInvocationId))",
  )
  debug_inspect(
    module_.entry_points[0].function.local_variables.items.length(),
    content="1",
  )
  debug_inspect(
    module_.entry_points[0].function.body.statements.length(),
    content="2",
  )
}

///|
test "WGSL AST lowerer uses stable function handles for calls" {
  let source =
    #|fn helper(x: u32) -> u32 {
    #|  return x + 1u;
    #|}
    #|
    #|@compute
    #|fn main() {
    #|  helper(1u);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  debug_inspect(module_.functions.items.length(), content="1")
  debug_inspect(module_.entry_points.length(), content="1")
  debug_inspect(
    module_.entry_points[0].function.body.statements.length(),
    content="1",
  )
  match module_.entry_points[0].function.body.statements[0] {
    Call(handle, arguments, _) => {
      debug_inspect(handle.index(), content="0")
      debug_inspect(arguments.length(), content="1")
    }
    _ => abort("expected call statement")
  }
}

///|
test "WGSL AST lowerer rejects unresolved expression identifiers" {
  let source =
    #|@compute
    #|fn main() {
    #|  let value: u32 = missing_name;
    #|}
  let result = try {
    ignore(parse_wgsl_module_to_ir(source))
    "ok"
  } catch {
    error => error.message()
  }
  debug_inspect(
    result,
    content="\"unknown WGSL identifier in IR lowering: missing_name\"",
  )
}
