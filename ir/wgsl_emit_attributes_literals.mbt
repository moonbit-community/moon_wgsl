///|
fn WgslIrEmitter::stage_attribute(
  self : WgslIrEmitter,
  stage : ShaderStage,
) -> String raise WgslIrEmitError {
  ignore(self)
  match stage {
    Vertex => "@vertex"
    Task => "@task"
    Fragment => "@fragment"
    Compute => "@compute"
    _ => raise WgslIrEmitError::Unsupported("shader stage")
  }
}

///|
fn WgslIrEmitter::emit_binding_attribute_prefix(
  self : WgslIrEmitter,
  out : StringBuilder,
  binding : Binding?,
) -> Unit raise WgslIrEmitError {
  match binding {
    Some(BuiltIn(builtin)) =>
      out.write_string("@builtin(\{self.builtin_name(builtin)}) ")
    Some(Location(location, interpolation, sampling, blend_src, per_primitive)) => {
      if per_primitive {
        out.write_string("@per_primitive ")
      }
      out.write_string("@location(\{location}) ")
      match blend_src {
        Some(value) => out.write_string("@blend_src(\{value}) ")
        None => ()
      }
      match interpolation {
        Some(value) => {
          out.write_string("@interpolate(\{self.interpolation_name(value)}")
          match sampling {
            Some(sampling_value) =>
              out.write_string(", \{self.sampling_name(sampling_value)}")
            None => ()
          }
          out.write_string(") ")
        }
        None => ()
      }
    }
    None => ()
  }
}

///|
fn WgslIrEmitter::builtin_name(
  self : WgslIrEmitter,
  builtin : BuiltIn,
) -> String raise WgslIrEmitError {
  ignore(self)
  match builtin {
    Position(_) => "position"
    ViewIndex => "view_index"
    ClipDistances => "clip_distances"
    PrimitiveIndex => "primitive_index"
    VertexIndex => "vertex_index"
    InstanceIndex => "instance_index"
    FrontFacing => "front_facing"
    Barycentric(true) => "barycentric"
    Barycentric(false) => "barycentric_no_perspective"
    FragDepth => "frag_depth"
    SampleIndex => "sample_index"
    SampleMask => "sample_mask"
    GlobalInvocationId => "global_invocation_id"
    LocalInvocationId => "local_invocation_id"
    LocalInvocationIndex => "local_invocation_index"
    WorkGroupId => "workgroup_id"
    NumWorkGroups => "num_workgroups"
    NumSubgroups => "num_subgroups"
    SubgroupId => "subgroup_id"
    SubgroupSize => "subgroup_size"
    SubgroupInvocationId => "subgroup_invocation_id"
    MeshTaskSize => "mesh_task_size"
    CullPrimitive => "cull_primitive"
    PointIndex => "point_index"
    LineIndices => "line_indices"
    TriangleIndices => "triangle_indices"
    VertexCount => "vertex_count"
    Vertices => "vertices"
    PrimitiveCount => "primitive_count"
    Primitives => "primitives"
    _ => raise WgslIrEmitError::Unsupported("builtin")
  }
}

///|
fn WgslIrEmitter::interpolation_name(
  self : WgslIrEmitter,
  interpolation : Interpolation,
) -> String {
  ignore(self)
  match interpolation {
    Perspective => "perspective"
    Linear => "linear"
    Flat => "flat"
    PerVertex => "per_vertex"
  }
}

///|
fn WgslIrEmitter::sampling_name(
  self : WgslIrEmitter,
  sampling : Sampling,
) -> String {
  ignore(self)
  match sampling {
    Center => "center"
    Centroid => "centroid"
    Sample => "sample"
    First => "first"
    Either => "either"
  }
}

///|
fn WgslIrEmitter::literal(self : WgslIrEmitter, literal : Literal) -> String {
  match literal {
    F64(value) => wgsl_ir_emit_abstract_float_literal_text("\{value}")
    F32(value) => wgsl_ir_emit_concrete_float_literal_text("\{value}")
    F16(value) => wgsl_ir_emit_f16_literal_text("\{value}")
    U16(value) => "\{value}u"
    I16(value) => "\{value}"
    U32(value) => "\{value}u"
    I32(value) => "\{value}i"
    U64(value) => "\{value}u"
    I64(value) => "\{value}"
    Bool(value) => if value { "true" } else { "false" }
    AbstractInt(value) => "\{value}"
    AbstractFloat(value) =>
      if self.options.preserve_abstract_float_literals {
        wgsl_ir_emit_abstract_float_literal_text("\{value}")
      } else {
        wgsl_ir_emit_concrete_float_literal_text("\{value}")
      }
  }
}

///|
fn wgsl_ir_emit_normalized_float_literal_text(text : String) -> String {
  if text.contains(".") || text.contains("e") || text.contains("E") {
    text
  } else {
    "\{text}.0"
  }
}

///|
fn wgsl_ir_emit_concrete_float_literal_text(text : String) -> String {
  let normalized = wgsl_ir_emit_normalized_float_literal_text(text)
  if normalized.has_suffix(".0") {
    "\{normalized[0:normalized.length() - 2]}f"
  } else {
    "\{normalized}f"
  }
}

///|
fn wgsl_ir_emit_f16_literal_text(text : String) -> String {
  let normalized = wgsl_ir_emit_normalized_float_literal_text(text)
  if normalized.has_suffix(".0") {
    "\{normalized[0:normalized.length() - 2]}h"
  } else {
    "\{normalized}h"
  }
}

///|
fn wgsl_ir_emit_abstract_float_literal_text(text : String) -> String {
  wgsl_ir_emit_normalized_float_literal_text(text)
}
