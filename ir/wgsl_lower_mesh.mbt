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
fn WgslIrLowerer::payload_variable_from_attributes(
  self : WgslIrLowerer,
  attributes : Array[@ast.WgslAttribute],
) -> Handle? raise WgslIrLowerError {
  match self.global_variable_from_identifier_attribute(attributes, "payload") {
    Some(handle) => Some(handle)
    None => None
  }
}

///|
fn WgslIrLowerer::mesh_stage_info_from_attributes(
  self : WgslIrLowerer,
  stage : ShaderStage,
  attributes : Array[@ast.WgslAttribute],
) -> MeshStageInfo? raise WgslIrLowerError {
  guard stage == ShaderStage::Mesh else { return None }
  guard self.global_variable_from_identifier_attribute(attributes, "mesh")
    is Some(output_variable) else {
    raise WgslIrLowerError::UnsupportedExpression(
      "mesh entry point requires @mesh output variable",
    )
  }
  Some(self.mesh_stage_info_from_output_variable(output_variable))
}

///|
fn WgslIrLowerer::global_variable_from_identifier_attribute(
  self : WgslIrLowerer,
  attributes : Array[@ast.WgslAttribute],
  attribute_name : String,
) -> Handle? raise WgslIrLowerError {
  guard wgsl_ir_attribute_named(attributes, attribute_name) is Some(attribute) else {
    return None
  }
  guard wgsl_ir_attribute_identifier_value(attribute) is Some(name) else {
    raise WgslIrLowerError::UnsupportedExpression(
      "@\{attribute_name} expects a global variable identifier",
    )
  }
  match self.global_names.get(name) {
    Some(handle) => Some(handle)
    None => raise WgslIrLowerError::UnknownIdentifier(name)
  }
}

///|
fn WgslIrLowerer::mesh_stage_info_from_output_variable(
  self : WgslIrLowerer,
  output_variable : Handle,
) -> MeshStageInfo raise WgslIrLowerError {
  guard self.shader_module.global_variables.items.get(output_variable.index())
    is Some(global) else {
    raise WgslIrLowerError::UnsupportedExpression(
      "invalid mesh output variable",
    )
  }
  guard self.shader_module.types.get(global.ty) is Some(output_type) else {
    raise WgslIrLowerError::UnsupportedExpression(
      "invalid mesh output variable type",
    )
  }
  guard output_type.inner is Struct(members, _) else {
    raise WgslIrLowerError::UnsupportedExpression(
      "mesh output variable must use a struct type",
    )
  }
  guard wgsl_ir_struct_member_with_builtin(members, BuiltIn::Vertices)
    is Some(vertex_member) else {
    raise WgslIrLowerError::UnsupportedExpression(
      "mesh output struct requires @builtin(vertices)",
    )
  }
  guard wgsl_ir_struct_member_with_builtin(members, BuiltIn::Primitives)
    is Some(primitive_member) else {
    raise WgslIrLowerError::UnsupportedExpression(
      "mesh output struct requires @builtin(primitives)",
    )
  }
  let (vertex_output_type, max_vertices, max_vertices_override) = self.mesh_output_array_info(
    vertex_member.ty,
    "vertices",
  )
  let (primitive_output_type, max_primitives, max_primitives_override) = self.mesh_output_array_info(
    primitive_member.ty,
    "primitives",
  )
  MeshStageInfo::{
    topology: self.mesh_primitive_topology(primitive_output_type),
    max_vertices,
    max_vertices_override,
    max_primitives,
    max_primitives_override,
    vertex_output_type,
    primitive_output_type,
    output_variable,
  }
}

///|
fn WgslIrLowerer::mesh_output_array_info(
  self : WgslIrLowerer,
  ty : Handle,
  member_name : String,
) -> (Handle, Int, Handle?) raise WgslIrLowerError {
  guard self.shader_module.types.get(ty) is Some(array_type) else {
    raise WgslIrLowerError::UnsupportedExpression(
      "invalid mesh output \{member_name} type",
    )
  }
  guard array_type.inner is Array(element_type, size, _) else {
    raise WgslIrLowerError::UnsupportedExpression(
      "mesh output \{member_name} must be an array",
    )
  }
  let (count, override_handle) = match size {
    Constant(value) => (value, (None : Handle?))
    Pending(handle) => (1, Some(handle))
    Dynamic =>
      raise WgslIrLowerError::UnsupportedExpression(
        "mesh output \{member_name} array size must be fixed",
      )
  }
  (element_type, count, override_handle)
}

///|
fn WgslIrLowerer::mesh_primitive_topology(
  self : WgslIrLowerer,
  primitive_output_type : Handle,
) -> MeshOutputTopology raise WgslIrLowerError {
  guard self.shader_module.types.get(primitive_output_type)
    is Some(primitive_type) else {
    raise WgslIrLowerError::UnsupportedExpression(
      "invalid mesh primitive output type",
    )
  }
  guard primitive_type.inner is Struct(members, _) else {
    raise WgslIrLowerError::UnsupportedExpression(
      "mesh primitive output type must be a struct",
    )
  }
  for struct_member in members {
    match struct_member.binding {
      Some(BuiltIn(TriangleIndices)) => return MeshOutputTopology::Triangles
      Some(BuiltIn(LineIndices)) => return MeshOutputTopology::Lines
      Some(BuiltIn(PointIndex)) => return MeshOutputTopology::Points
      _ => ()
    }
  }
  raise WgslIrLowerError::UnsupportedExpression(
    "mesh primitive output type requires point, line, or triangle indices",
  )
}

///|
fn wgsl_ir_struct_member_with_builtin(
  members : Array[StructMember],
  builtin : BuiltIn,
) -> StructMember? {
  for struct_member in members {
    match struct_member.binding {
      Some(BuiltIn(value)) if value == builtin => return Some(struct_member)
      _ => ()
    }
  }
  None
}
