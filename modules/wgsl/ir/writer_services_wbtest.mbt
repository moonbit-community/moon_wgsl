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
test "writer reachability follows entry point function dependencies" {
  let module_ = Module()
  let helper = Function::Function(Some("helper"))
  helper.body.push(Return(None))
  let helper_handle = module_.append_function(helper)
  let main = Function::Function(Some("main"))
  main.body.push(Call(helper_handle, [], None))
  module_.append_entry_point({
    name: "main",
    source_start: -1,
    stage: Compute,
    early_depth_test: None,
    workgroup_size: [1, 1, 1],
    workgroup_size_overrides: None,
    function: main,
    mesh_info: None,
    task_payload: None,
    incoming_ray_payload: None,
  })
  let reachable = build_wgsl_ir_reachability(module_, ["main"])
  assert_true(reachable.contains_function(helper_handle.index()))
  assert_true(reachable.contains_entry_point(0))
}

///|
test "writer type inference derives literal types from semantic IR" {
  let module_ = Module()
  let u32_type = module_.append_type({
    name: Some("u32"),
    inner: Scalar(Scalar(Uint, 4)),
  })
  let function = Function::Function(Some("value"))
  let literal = function.expressions.append(Literal(U32(7)))
  let inferred = WgslIrTypeInference::from_module(module_).expression_type(
    Some(function),
    literal,
  )
  assert_eq(inferred, Some(u32_type))
}

///|
test "writer type spelling accepts names and byte choices from its adapter" {
  let module_ = Module()
  let named = module_.append_type({
    name: Some("SourceName"),
    inner: Struct([], 0),
  })
  let spelling = WgslIrTypeSpelling::new(
    module_,
    fn(handle) { if handle == named { Some("FinalName") } else { None } },
    fn(_) { None },
    true,
    ", ",
  )
  let type_name = spelling.type_name(named) catch {
    error => abort(error.message())
  }
  assert_eq(type_name, "FinalName")
  assert_eq(spelling.scalar_name(Scalar(Float, 4)), "f32")
  assert_eq(spelling.address_space_template(WorkGroup), "<workgroup>")
}
