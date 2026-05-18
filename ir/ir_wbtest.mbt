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
test "Naga-style shader IR module stores handles into arenas" {
  let shader_module = Module()
  let f32_ty = shader_module.append_type(Type::{
    name: Some("f32"),
    inner: TypeInner::Scalar(Scalar::Scalar(Float, 4)),
  })
  let literal = shader_module.append_global_expression(
    Expression::Literal(Literal::F32(1.0)),
  )
  let constant = shader_module.append_constant(Constant::{
    name: Some("ONE"),
    generated_import: false,
    inline_value: false,
    source_start: -1,
    ty: f32_ty,
    init: literal,
  })
  shader_module.append_const_assert(literal)
  let global_expr = shader_module.append_global_expression(
    Expression::Constant(constant),
  )
  debug_inspect(f32_ty.index(), content="0")
  debug_inspect(literal.index(), content="0")
  debug_inspect(constant.index(), content="0")
  debug_inspect(global_expr.index(), content="1")
  debug_inspect(shader_module.types.items.length(), content="1")
  debug_inspect(shader_module.constants.items.length(), content="1")
  debug_inspect(shader_module.const_asserts.length(), content="1")
  debug_inspect(shader_module.global_expressions.items.length(), content="2")
}

///|
test "Naga-style shader IR represents function statements and entry points" {
  let shader_module = Module()
  let bool_ty = shader_module.append_type(Type::{
    name: Some("bool"),
    inner: TypeInner::Scalar(Scalar::Scalar(Bool, 1)),
  })
  let function = Function::Function(Some("main"))
  let condition = function.expressions.append(
    Expression::Literal(Literal::Bool(true)),
  )
  function.body.push(
    Statement::If(
      condition,
      Block::{ statements: [Statement::Return(None)] },
      Block::Block(),
    ),
  )
  shader_module.append_entry_point(EntryPoint::{
    name: "main",
    source_start: -1,
    stage: Compute,
    early_depth_test: None,
    workgroup_size: [1, 1, 1],
    workgroup_size_overrides: None,
    function,
    mesh_info: None,
    task_payload: None,
    incoming_ray_payload: None,
  })
  debug_inspect(bool_ty.index(), content="0")
  debug_inspect(shader_module.entry_points.length(), content="1")
  debug_inspect(
    shader_module.entry_points[0].function.body.statements.length(),
    content="1",
  )
}
