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
  ty : Handle?,
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
        None =>
          if self.binding_type_uses_implicit_flat_interpolation(ty) {
            out.write_string("@interpolate(flat) ")
          }
      }
    }
    None => ()
  }
}

///|
fn WgslIrEmitter::binding_type_uses_implicit_flat_interpolation(
  self : WgslIrEmitter,
  ty : Handle?,
) -> Bool {
  if !self.options.emit_implicit_flat_interpolation() {
    return false
  }
  guard ty is Some(ty_handle) else { return false }
  match self.type_component_scalar(ty_handle) {
    Some({ kind: Sint | Uint, .. }) => true
    _ => false
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
    F32(value) => wgsl_ir_emit_f32_literal(value)
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
      if self.options.preserve_abstract_float_literals() {
        wgsl_ir_emit_abstract_float_literal_text("\{value}")
      } else {
        wgsl_ir_emit_f32_literal(Float::from_double(value))
      }
  }
}

///|
fn wgsl_ir_emit_f32_literal(value : Float) -> String {
  if wgsl_ir_f32_is_negative_zero(value) {
    return "-0f"
  }
  wgsl_ir_emit_concrete_float_literal_text(
    wgsl_ir_shortest_f32_literal_text(value),
  )
}

///|
fn wgsl_ir_f32_is_negative_zero(value : Float) -> Bool {
  value == Float::from_int(0) && value.reinterpret_as_int() < 0
}

///|
fn wgsl_ir_shortest_f32_literal_text(value : Float) -> String {
  let original = "\{value}"
  if original.contains("e") || original.contains("E") {
    return original
  }
  guard original.contains(".") else { return original }
  for precision in 0..<13 {
    match wgsl_ir_round_fixed_decimal_text(original, precision) {
      Some(candidate) =>
        if wgsl_ir_f32_literal_round_trips(value, candidate) {
          return candidate
        }
      None => ()
    }
  }
  original
}

///|
fn wgsl_ir_f32_literal_round_trips(value : Float, text : String) -> Bool {
  let parsed : Double = @strconv.from_str(text) catch { _ => return false }
  Float::from_double(parsed) == value
}

///|
fn wgsl_ir_round_fixed_decimal_text(text : String, precision : Int) -> String? {
  let dot = wgsl_ir_find_ascii_char(text, 46)
  guard dot >= 0 else { return None }
  let negative = text.has_prefix("-")
  let body_start = if negative { 1 } else { 0 }
  let int_part = text[body_start:dot].to_owned()
  let frac_part = text[dot + 1:text.length()].to_owned()
  if int_part.length() + precision > 18 {
    return None
  }
  let integer = match wgsl_ir_parse_unsigned_decimal_int64(int_part) {
    Some(value) => value
    None => return None
  }
  let scale = wgsl_ir_pow10_int64(precision)
  let frac = match wgsl_ir_parse_fraction_prefix_int64(frac_part, precision) {
    Some(value) => value
    None => return None
  }
  let next_digit = if precision < frac_part.length() {
    let code = frac_part.code_unit_at(precision).to_int()
    if code < 48 || code > 57 {
      return None
    }
    code - 48
  } else {
    0
  }
  let carry = if next_digit >= 5 {
    Int64::from_int(1)
  } else {
    Int64::from_int(0)
  }
  let scaled = integer * scale + frac + carry
  let abs_text = wgsl_ir_scaled_fixed_decimal_text(scaled, precision)
  if negative && scaled != Int64::from_int(0) {
    Some("-\{abs_text}")
  } else {
    Some(abs_text)
  }
}

///|
fn wgsl_ir_find_ascii_char(text : String, code : Int) -> Int {
  for index in 0..<text.length() {
    if text.code_unit_at(index).to_int() == code {
      return index
    }
  }
  -1
}

///|
fn wgsl_ir_parse_unsigned_decimal_int64(text : String) -> Int64? {
  if text.length() == 0 {
    return Some(Int64::from_int(0))
  }
  let mut value : Int64 = 0
  for index in 0..<text.length() {
    let code = text.code_unit_at(index).to_int()
    if code < 48 || code > 57 {
      return None
    }
    value = value * 10 + Int64::from_int(code - 48)
  }
  Some(value)
}

///|
fn wgsl_ir_parse_fraction_prefix_int64(
  text : String,
  precision : Int,
) -> Int64? {
  let mut value : Int64 = 0
  for index in 0..<precision {
    value = value * 10
    if index < text.length() {
      let code = text.code_unit_at(index).to_int()
      if code < 48 || code > 57 {
        return None
      }
      value = value + Int64::from_int(code - 48)
    }
  }
  Some(value)
}

///|
fn wgsl_ir_pow10_int64(power : Int) -> Int64 {
  let mut value : Int64 = 1
  for _ in 0..<power {
    value = value * 10
  }
  value
}

///|
fn wgsl_ir_scaled_fixed_decimal_text(value : Int64, precision : Int) -> String {
  if precision == 0 {
    return "\{value}"
  }
  let mut digits = "\{value}"
  while digits.length() <= precision {
    digits = "0\{digits}"
  }
  let split = digits.length() - precision
  "\{digits[0:split]}.\{digits[split:digits.length()]}"
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
