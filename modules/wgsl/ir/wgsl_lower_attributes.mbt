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
fn wgsl_ir_attribute_named(
  attributes : Array[@ast.WgslAttribute],
  name : String,
) -> @ast.WgslAttribute? {
  for attribute in attributes {
    if attribute.name().name() == name {
      break Some(attribute)
    }
  } nobreak {
    None
  }
}

///|
fn wgsl_ir_attribute_int_value(attribute : @ast.WgslAttribute) -> Int? {
  match attribute.arguments_ref() {
    Some(expr_ref) => wgsl_ir_int_literal_from_expr_ref(expr_ref)
    None => None
  }
}

///|
fn wgsl_ir_attribute_identifier_value(
  attribute : @ast.WgslAttribute,
) -> String? {
  match attribute.arguments_ref() {
    Some(expr_ref) =>
      match expr_ref.root() {
        Some(node) =>
          match node.kind() {
            Identifier(name) => Some(name.name())
            _ => None
          }
        None => None
      }
    None => None
  }
}

///|
fn wgsl_ir_binding_from_attributes(
  attributes : Array[@ast.WgslAttribute],
) -> Binding? raise WgslIrLowerError {
  match wgsl_ir_attribute_named(attributes, "builtin") {
    Some(attribute) =>
      match wgsl_ir_attribute_identifier_value(attribute) {
        Some(name) => Some(BuiltIn(wgsl_ir_builtin_from_name(name)))
        None => None
      }
    None =>
      match wgsl_ir_attribute_named(attributes, "location") {
        Some(attribute) =>
          match wgsl_ir_attribute_int_value(attribute) {
            Some(location) =>
              Some(
                Location(
                  location,
                  wgsl_ir_interpolation_from_attributes(attributes),
                  wgsl_ir_sampling_from_attributes(attributes),
                  wgsl_ir_blend_src_from_attributes(attributes),
                  wgsl_ir_per_primitive_from_attributes(attributes),
                ),
              )
            None => None
          }
        None => None
      }
  }
}

///|
fn wgsl_ir_per_primitive_from_attributes(
  attributes : Array[@ast.WgslAttribute],
) -> Bool {
  match wgsl_ir_attribute_named(attributes, "per_primitive") {
    Some(_) => true
    None => false
  }
}

///|
fn wgsl_ir_blend_src_from_attributes(
  attributes : Array[@ast.WgslAttribute],
) -> Int? {
  match wgsl_ir_attribute_named(attributes, "blend_src") {
    Some(attribute) => wgsl_ir_attribute_int_value(attribute)
    None => None
  }
}

///|
fn wgsl_ir_builtin_from_name(name : String) -> BuiltIn raise WgslIrLowerError {
  match name {
    "position" => Position(false)
    "view_index" => ViewIndex
    "clip_distances" => ClipDistances
    "primitive_index" => PrimitiveIndex
    "vertex_index" => VertexIndex
    "instance_index" => InstanceIndex
    "front_facing" => FrontFacing
    "barycentric" => Barycentric(true)
    "barycentric_no_perspective" => Barycentric(false)
    "frag_depth" => FragDepth
    "sample_index" => SampleIndex
    "sample_mask" => SampleMask
    "global_invocation_id" => GlobalInvocationId
    "local_invocation_id" => LocalInvocationId
    "local_invocation_index" => LocalInvocationIndex
    "workgroup_id" => WorkGroupId
    "num_workgroups" => NumWorkGroups
    "num_subgroups" => NumSubgroups
    "subgroup_id" => SubgroupId
    "subgroup_size" => SubgroupSize
    "subgroup_invocation_id" => SubgroupInvocationId
    "mesh_task_size" => MeshTaskSize
    "cull_primitive" => CullPrimitive
    "point_index" => PointIndex
    "line_indices" => LineIndices
    "triangle_indices" => TriangleIndices
    "vertex_count" => VertexCount
    "vertices" => Vertices
    "primitive_count" => PrimitiveCount
    "primitives" => Primitives
    _ => raise UnsupportedExpression("unknown builtin attribute: \{name}")
  }
}

///|
fn wgsl_ir_interpolation_from_attributes(
  attributes : Array[@ast.WgslAttribute],
) -> Interpolation? {
  match wgsl_ir_attribute_named(attributes, "interpolate") {
    Some(attribute) =>
      match attribute.arguments_ref() {
        Some(expr_ref) =>
          match expr_ref.identifiers() {
            [name, ..] =>
              match name.name() {
                "perspective" => Some(Perspective)
                "linear" => Some(Linear)
                "flat" => Some(Flat)
                "per_vertex" => Some(PerVertex)
                _ => None
              }
            [] => None
          }
        None => None
      }
    None => None
  }
}

///|
fn wgsl_ir_sampling_from_attributes(
  attributes : Array[@ast.WgslAttribute],
) -> Sampling? {
  match wgsl_ir_attribute_named(attributes, "interpolate") {
    Some(attribute) =>
      match attribute.arguments_ref() {
        Some(expr_ref) =>
          match expr_ref.identifiers() {
            [_, sampling, ..] =>
              match sampling.name() {
                "center" => Some(Center)
                "centroid" => Some(Centroid)
                "sample" => Some(Sample)
                "first" => Some(First)
                "either" => Some(Either)
                _ => None
              }
            _ => None
          }
        None => None
      }
    None => None
  }
}

///|
fn wgsl_ir_resource_binding_from_attributes(
  attributes : Array[@ast.WgslAttribute],
) -> ResourceBinding? {
  match wgsl_ir_attribute_named(attributes, "group") {
    Some(group_attribute) =>
      match wgsl_ir_attribute_named(attributes, "binding") {
        Some(binding_attribute) =>
          match
            (
              wgsl_ir_attribute_int_value(group_attribute),
              wgsl_ir_attribute_int_value(binding_attribute),
            ) {
            (Some(group), Some(binding)) => Some({ group, binding })
            _ => None
          }
        None => None
      }
    None => None
  }
}

///|
fn wgsl_ir_address_space_from_template_list(
  template_list : Array[@ast.WgslTypeRef],
) -> AddressSpace raise WgslIrLowerError {
  match template_list {
    [space, .. rest] =>
      match space.name() {
        "storage" =>
          match rest {
            [access, ..] =>
              Storage(wgsl_ir_storage_access_from_name(access.name()))
            [] => Storage(StorageAccess::load())
          }
        other => wgsl_ir_address_space_from_type_name(other)
      }
    [] => Private
  }
}

///|
fn wgsl_ir_address_space_from_type_name(
  name : String,
) -> AddressSpace raise WgslIrLowerError {
  match name {
    "function" => Function
    "private" => Private
    "workgroup" => WorkGroup
    "uniform" => Uniform
    "storage" => Storage(StorageAccess::load())
    "handle" => Handle
    "immediate" => Immediate
    "task_payload" => TaskPayload
    "ray_payload" => RayPayload
    "incoming_ray_payload" => IncomingRayPayload
    _ => raise UnsupportedType("unknown WGSL address space: \{name}")
  }
}

///|
fn wgsl_ir_address_space_key(space : AddressSpace) -> String {
  match space {
    Function => "function"
    Private => "private"
    WorkGroup => "workgroup"
    Uniform => "uniform"
    Storage(access) => "storage,\{wgsl_ir_storage_access_key(access)}"
    Handle => "handle"
    Immediate => "immediate"
    TaskPayload => "task_payload"
    RayPayload => "ray_payload"
    IncomingRayPayload => "incoming_ray_payload"
  }
}

///|
fn wgsl_ir_storage_access_key(access : StorageAccess) -> String {
  if access.contains(StorageAccess::atomic_access()) {
    "atomic"
  } else if access.contains(StorageAccess::load()) &&
    access.contains(StorageAccess::store()) {
    "read_write"
  } else if access.contains(StorageAccess::store()) {
    "write"
  } else {
    "read"
  }
}

///|
fn wgsl_ir_storage_access_from_name(
  name : String,
) -> StorageAccess raise WgslIrLowerError {
  match name {
    "read" => StorageAccess::load()
    "write" => StorageAccess::store()
    "read_write" => StorageAccess::load().union(StorageAccess::store())
    "atomic" => StorageAccess::atomic_access()
    _ => raise UnsupportedType("unknown WGSL storage access: \{name}")
  }
}

///|
fn wgsl_ir_memory_decorations_from_attributes(
  attributes : Array[@ast.WgslAttribute],
) -> MemoryDecorations {
  let mut decorations = MemoryDecorations::empty()
  match wgsl_ir_attribute_named(attributes, "coherent") {
    Some(_) => decorations = decorations.union(MemoryDecorations::coherent())
    None => ()
  }
  match wgsl_ir_attribute_named(attributes, "volatile") {
    Some(_) =>
      decorations = decorations.union(MemoryDecorations::volatile_decoration())
    None => ()
  }
  decorations
}

///|
fn wgsl_ir_id_from_attributes(attributes : Array[@ast.WgslAttribute]) -> Int? {
  match wgsl_ir_attribute_named(attributes, "id") {
    Some(attribute) => wgsl_ir_attribute_int_value(attribute)
    None => None
  }
}

///|
fn wgsl_ir_shader_stage_from_attributes(
  attributes : Array[@ast.WgslAttribute],
) -> ShaderStage? {
  match wgsl_ir_attribute_named(attributes, "vertex") {
    Some(_) => Some(Vertex)
    None =>
      match wgsl_ir_attribute_named(attributes, "fragment") {
        Some(_) => Some(Fragment)
        None =>
          match wgsl_ir_attribute_named(attributes, "compute") {
            Some(_) => Some(Compute)
            None =>
              match wgsl_ir_attribute_named(attributes, "task") {
                Some(_) => Some(Task)
                None =>
                  match wgsl_ir_attribute_named(attributes, "mesh") {
                    Some(_) => Some(Mesh)
                    None => None
                  }
              }
          }
      }
  }
}

///|
fn wgsl_ir_early_depth_test_from_attributes(
  attributes : Array[@ast.WgslAttribute],
) -> EarlyDepthTest? {
  match wgsl_ir_attribute_named(attributes, "early_depth_test") {
    Some(_) => Some(Force)
    None => None
  }
}

///|
fn WgslIrLowerer::workgroup_size_from_attributes(
  self : WgslIrLowerer,
  attributes : Array[@ast.WgslAttribute],
) -> (Array[Int], Array[Handle?]?) raise WgslIrLowerError {
  match wgsl_ir_attribute_named(attributes, "workgroup_size") {
    Some(attribute) =>
      match attribute.arguments_ref() {
        Some(expr_ref) => {
          let nodes = match expr_ref.root() {
            Some(root) => wgsl_ir_flatten_workgroup_size_arguments(root)
            None => []
          }
          let values : Array[Int] = [1, 1, 1]
          let overrides : Array[Handle?] = [None, None, None]
          for i in 0..<3 {
            match nodes.get(i) {
              Some(node) => {
                let (value, override_handle) = self.workgroup_size_dimension_from_node(
                  node,
                )
                values[i] = value
                overrides[i] = override_handle
              }
              None => ()
            }
          }
          if wgsl_ir_optional_handle_array_is_empty(overrides) {
            (values, None)
          } else {
            (values, Some(overrides))
          }
        }
        None => ([1, 1, 1], None)
      }
    None => ([1, 1, 1], None)
  }
}

///|
fn wgsl_ir_flatten_workgroup_size_arguments(
  root : @ast.WgslExprNode,
) -> Array[@ast.WgslExprNode] {
  match root.kind() {
    Sequence(items) => items
    _ => [root]
  }
}

///|
fn WgslIrLowerer::workgroup_size_dimension_from_node(
  self : WgslIrLowerer,
  node : @ast.WgslExprNode,
) -> (Int, Handle?) raise WgslIrLowerError {
  let handle = self.lower_global_expression_node(node)
  let evaluated = Some(self.eval_global_integer_expression(handle)) catch {
    _ => None
  }
  match evaluated {
    Some(value) => (value.to_non_negative_int(), None)
    None =>
      if self.global_expression_references_override(handle) {
        (1, Some(handle))
      } else {
        raise UnsupportedExpression(
          "workgroup_size dimension must be a const or override integer expression",
        )
      }
  }
}
