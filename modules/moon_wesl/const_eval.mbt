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
pub(all) struct EvalResult {
  value : String
  buffer : Bytes?
} derive(Eq, Debug)

///|
pub fn EvalResult::to_string(self : EvalResult) -> String {
  self.value
}

///|
pub fn EvalResult::to_buffer(self : EvalResult) -> Bytes? {
  self.buffer
}

///|
pub(all) enum UserInputValue {
  Bool(Bool)
  I32(Int)
  U32(Int)
  F32(Double)
  I32Vector(Array[Int])
  U32Vector(Array[Int])
  F32Vector(Array[Double])
} derive(Eq, Debug)

///|
pub(all) struct UserInput {
  location : Int
  value : UserInputValue
} derive(Eq, Debug)

///|
pub(all) struct Inputs {
  vertex_index : Int?
  instance_index : Int?
  position : Array[Double]?
  front_facing : Bool?
  sample_index : Int?
  sample_mask : Int?
  local_invocation_id : Array[Int]?
  local_invocation_index : Int?
  global_invocation_id : Array[Int]?
  workgroup_id : Array[Int]?
  num_workgroups : Array[Int]?
  subgroup_invocation_id : Int?
  subgroup_size : Int?
  subgroup_id : Int?
  num_subgroups : Int?
  primitive_index : Int?
  view_index : Int?
  user_defined : Array[UserInput]
} derive(Eq, Debug)

///|
pub fn Inputs::new_zero_initialized() -> Inputs {
  Inputs::{
    vertex_index: Some(0),
    instance_index: Some(0),
    position: Some([0.0, 0.0, 0.0, 0.0]),
    front_facing: Some(true),
    sample_index: Some(0),
    sample_mask: Some(0),
    local_invocation_id: Some([0, 0, 0]),
    local_invocation_index: Some(0),
    global_invocation_id: Some([0, 0, 0]),
    workgroup_id: Some([0, 0, 0]),
    num_workgroups: Some([1, 1, 1]),
    subgroup_invocation_id: Some(0),
    subgroup_size: Some(4),
    subgroup_id: Some(0),
    num_subgroups: Some(1),
    primitive_index: Some(0),
    view_index: Some(0),
    user_defined: [],
  }
}

///|
pub(all) struct ResourceBinding {
  group : Int
  binding : Int
  kind : String
  data : Bytes
} derive(Eq, Debug)

///|
pub(all) struct OverrideValue {
  name : String
  value : String
} derive(Eq, Debug)

///|
pub(all) struct ExecResult {
  value : String?
  buffer : Bytes?
  resources : Array[ResourceBinding]
} derive(Eq, Debug)

///|
pub fn ExecResult::return_value(self : ExecResult) -> String? {
  self.value
}

///|
pub fn ExecResult::to_buffer(self : ExecResult) -> Bytes? {
  self.buffer
}

///|
pub fn ExecResult::resource(
  self : ExecResult,
  group : Int,
  binding : Int,
) -> ResourceBinding? {
  for resource in self.resources {
    if resource.group == group && resource.binding == binding {
      return Some(resource)
    }
  }
  None
}

///|
pub fn ExecResult::to_string(self : ExecResult) -> String {
  match self.value {
    Some(value) => "return: \{value}"
    None => "return: void"
  }
}

///|
priv struct ConstEvalEntryExec {
  value : ConstEvalValue?
  ctx : ConstEvalContext
}

///|
fn eval_const_function_value(
  source : String,
  target_expr : String,
) -> ConstEvalValue raise WeslCompileError {
  let tokens = const_eval_lex(source)
  let parser = ConstEvalParser::new(tokens)
  let function = parser.parse_function()
  let ctx = ConstEvalContext::new()
  let args : Array[ConstEvalValue] = []
  for
    arg in const_eval_validate_target(
      target_expr.trim().to_owned(),
      function.name,
    ) {
    args.push(const_eval_eval_expr(arg, ctx))
  }
  const_eval_execute_function_value(function, args, ctx.new_call_scope())
}

///|
fn const_eval_parse_expression_value(
  source : String,
  ctx : ConstEvalContext,
) -> ConstEvalValue raise WeslCompileError {
  let tokens = const_eval_lex(source)
  let parser = ConstEvalParser::new(tokens)
  let expr = parser.parse_expression()
  if !parser.view().is_empty() {
    raise WeslCompileError::Validation(
      "unexpected trailing const-eval expression tokens",
    )
  }
  const_eval_eval_expr(expr, ctx)
}

///|
fn eval_const_expression_value(
  source : String,
) -> ConstEvalValue raise WeslCompileError {
  const_eval_parse_expression_value(source, ConstEvalContext::new())
}

///|
fn const_eval_parse_type_source(
  source : String,
) -> ConstEvalType raise WeslCompileError {
  let tokens = const_eval_lex(source)
  let parser = ConstEvalParser::new(tokens)
  let type_ = parser.parse_type()
  if !parser.view().is_empty() {
    raise WeslCompileError::Validation(
      "unexpected trailing const-eval type tokens",
    )
  }
  type_
}

///|
fn const_eval_struct_declaration(
  unit : TranslationUnit,
  name : String,
) -> StructDeclaration? {
  for declaration in unit.global_declarations {
    match declaration.header {
      Struct(struct_) => if struct_.name == name { return Some(struct_) }
      _ => ()
    }
  }
  None
}

///|
fn const_eval_type_source_with_unit(
  unit : TranslationUnit,
  source : String,
) -> ConstEvalType raise WeslCompileError {
  let type_ = const_eval_parse_type_source(source)
  match type_ {
    ConstEvalType::Struct(name) =>
      match const_eval_struct_declaration(unit, name) {
        Some(_) => type_
        None => raise WeslCompileError::Validation("unknown type `\{name}`")
      }
    _ => type_
  }
}

///|
fn const_eval_function_from_source(
  source : String,
) -> ConstEvalFunction raise WeslCompileError {
  let tokens = const_eval_lex(source)
  let parser = ConstEvalParser::new(tokens)
  parser.parse_function()
}

///|
fn const_eval_context_from_translation_unit(
  unit : TranslationUnit,
) -> ConstEvalContext raise WeslCompileError {
  const_eval_context_from_translation_unit_with_exec_inputs(unit, [], [])
}

///|
fn const_eval_override_value(
  overrides : Array[OverrideValue],
  name : String,
) -> String? {
  let mut value : String? = None
  for override_ in overrides {
    if override_.name == name {
      value = Some(override_.value)
    }
  }
  value
}

///|
fn const_eval_attr_i32(attr : Attribute) -> Int? raise WeslCompileError {
  match attr.arguments {
    Some(text) =>
      match const_eval_parse_expression_value(text, ConstEvalContext::new()) {
        AbstractInt(value) | I32(value) | U32(value) =>
          if value >= 0L && value <= 2147483647L {
            Some(value.to_int())
          } else {
            raise WeslCompileError::Validation(
              "resource attribute `\{attr.name}` is out of range",
            )
          }
        value =>
          raise WeslCompileError::Validation(
            "resource attribute `\{attr.name}` must evaluate to an integer, got \{const_eval_render_value(value)}",
          )
      }
    None => None
  }
}

///|
fn const_eval_named_attr_i32(
  attributes : Array[Attribute],
  name : String,
) -> Int? raise WeslCompileError {
  let mut value : Int? = None
  for attribute in attributes {
    if attribute.name == name {
      value = const_eval_attr_i32(attribute)
    }
  }
  value
}

///|
fn const_eval_group_binding(
  attributes : Array[Attribute],
) -> (Int, Int)? raise WeslCompileError {
  let mut group : Int? = None
  let mut binding : Int? = None
  for attr in attributes {
    if attr.name == "group" {
      group = const_eval_attr_i32(attr)
    } else if attr.name == "binding" {
      binding = const_eval_attr_i32(attr)
    }
  }
  match (group, binding) {
    (Some(group), Some(binding)) => Some((group, binding))
    _ => None
  }
}

///|
fn const_eval_round_up(align : Int, offset : Int) -> Int {
  if align <= 1 {
    offset
  } else {
    (offset + align - 1) / align * align
  }
}

///|
fn const_eval_member_attr_or_layout(
  attributes : Array[Attribute],
  name : String,
  fallback : Int,
) -> Int? raise WeslCompileError {
  match const_eval_named_attr_i32(attributes, name) {
    Some(value) => Some(value)
    None => Some(fallback)
  }
}

///|
fn const_eval_type_align(
  unit : TranslationUnit,
  type_ : ConstEvalType,
) -> Int? raise WeslCompileError {
  match type_ {
    Bool | I32 | U32 | F32 => Some(4)
    Vector(width, element) =>
      match const_eval_type_align(unit, element) {
        Some(_) =>
          match width {
            2 => Some(8)
            3 | 4 => Some(16)
            _ => None
          }
        None => None
      }
    Matrix(_, rows, element) =>
      const_eval_type_align(unit, ConstEvalType::Vector(rows, element))
    Array(element, _) => const_eval_type_align(unit, element)
    ConstEvalType::Struct(name) =>
      match const_eval_struct_declaration(unit, name) {
        Some(struct_) => {
          let mut align = 1
          for field_decl in struct_.members {
            let member_align = match const_eval_member_align(unit, field_decl) {
              Some(value) => value
              None => return None
            }
            if member_align > align {
              align = member_align
            }
          }
          Some(align)
        }
        None => None
      }
    _ => None
  }
}

///|
fn const_eval_type_size(
  unit : TranslationUnit,
  type_ : ConstEvalType,
) -> Int? raise WeslCompileError {
  match type_ {
    Bool | I32 | U32 | F32 => Some(4)
    Vector(width, element) =>
      match const_eval_type_size(unit, element) {
        Some(element_size) => Some(width * element_size)
        None => None
      }
    Matrix(columns, rows, element) => {
      let column_type = ConstEvalType::Vector(rows, element)
      let column_stride = match const_eval_type_stride(unit, column_type) {
        Some(value) => value
        None => return None
      }
      Some(columns * column_stride)
    }
    Array(element, Some(count)) => {
      let stride = match const_eval_type_stride(unit, element) {
        Some(value) => value
        None => return None
      }
      Some(count * stride)
    }
    Array(_, None) => None
    ConstEvalType::Struct(name) =>
      match const_eval_struct_declaration(unit, name) {
        Some(struct_) => {
          let align = match const_eval_type_align(unit, type_) {
            Some(value) => value
            None => return None
          }
          let mut offset = 0
          for field_decl in struct_.members {
            let member_align = match const_eval_member_align(unit, field_decl) {
              Some(value) => value
              None => return None
            }
            let member_size = match const_eval_member_size(unit, field_decl) {
              Some(value) => value
              None => return None
            }
            offset = const_eval_round_up(member_align, offset)
            offset = offset + member_size
          }
          Some(const_eval_round_up(align, offset))
        }
        None => None
      }
    _ => None
  }
}

///|
fn const_eval_type_stride(
  unit : TranslationUnit,
  type_ : ConstEvalType,
) -> Int? raise WeslCompileError {
  let align = match const_eval_type_align(unit, type_) {
    Some(value) => value
    None => return None
  }
  let size = match const_eval_type_size(unit, type_) {
    Some(value) => value
    None => return None
  }
  Some(const_eval_round_up(align, size))
}

///|
fn const_eval_type_min_size(
  unit : TranslationUnit,
  type_ : ConstEvalType,
) -> Int? raise WeslCompileError {
  match type_ {
    Array(element, None) => const_eval_type_stride(unit, element)
    _ => const_eval_type_size(unit, type_)
  }
}

///|
fn const_eval_member_align(
  unit : TranslationUnit,
  field_decl : StructMember,
) -> Int? raise WeslCompileError {
  let type_ = const_eval_type_source_with_unit(unit, field_decl.type_text)
  let fallback = match const_eval_type_align(unit, type_) {
    Some(value) => value
    None => return None
  }
  const_eval_member_attr_or_layout(field_decl.attributes, "align", fallback)
}

///|
fn const_eval_member_size(
  unit : TranslationUnit,
  field_decl : StructMember,
) -> Int? raise WeslCompileError {
  let type_ = const_eval_type_source_with_unit(unit, field_decl.type_text)
  let fallback = match const_eval_type_min_size(unit, type_) {
    Some(value) => value
    None => return None
  }
  const_eval_member_attr_or_layout(field_decl.attributes, "size", fallback)
}

///|
fn const_eval_struct_field(
  fields : Array[(String, ConstEvalValue)],
  name : String,
) -> ConstEvalValue? {
  for field in fields {
    let (field_name, value) = field
    if field_name == name {
      return Some(value)
    }
  }
  None
}

///|
fn const_eval_resource_value(
  resources : Array[ResourceBinding],
  group : Int,
  binding : Int,
) -> ResourceBinding? {
  let mut value : ResourceBinding? = None
  for resource in resources {
    if resource.group == group && resource.binding == binding {
      value = Some(resource)
    }
  }
  value
}

///|
fn const_eval_resource_declaration(
  unit : TranslationUnit,
  group : Int,
  binding : Int,
) -> (String, String)? raise WeslCompileError {
  for declaration in unit.global_declarations {
    match declaration.header {
      Var(var_) =>
        match
          (
            var_.name,
            var_.type_text,
            const_eval_group_binding(declaration.attributes),
          ) {
          (Some(name), Some(type_source), Some((decl_group, decl_binding))) =>
            if decl_group == group && decl_binding == binding {
              return Some((name, type_source))
            }
          _ => ()
        }
      _ => ()
    }
  }
  None
}

///|
fn const_eval_le_u32_at(bytes : Bytes, offset : Int) -> Int64? {
  if offset < 0 {
    return None
  }
  if bytes.length() < 4 {
    None
  } else if offset + 4 > bytes.length() {
    None
  } else {
    let b0 = bytes[offset].to_int64()
    let b1 = bytes[offset + 1].to_int64()
    let b2 = bytes[offset + 2].to_int64()
    let b3 = bytes[offset + 3].to_int64()
    Some(b0 | (b1 << 8) | (b2 << 16) | (b3 << 24))
  }
}

///|
fn const_eval_scalar_value_from_buffer_at(
  ty : ConstEvalType,
  data : Bytes,
  offset : Int,
) -> ConstEvalValue? {
  match ty {
    I32 => {
      let unsigned = match const_eval_le_u32_at(data, offset) {
        Some(value) => value
        None => return None
      }
      let signed = if unsigned >= 2147483648L {
        unsigned - 4294967296L
      } else {
        unsigned
      }
      Some(ConstEvalValue::I32(signed))
    }
    U32 => {
      let value = match const_eval_le_u32_at(data, offset) {
        Some(value) => value
        None => return None
      }
      Some(ConstEvalValue::U32(value))
    }
    F32 => {
      let bits = match const_eval_le_u32_at(data, offset) {
        Some(value) => value.to_int()
        None => return None
      }
      Some(ConstEvalValue::F32(Float::reinterpret_from_int(bits)))
    }
    _ => None
  }
}

///|
fn const_eval_value_from_buffer_type(
  unit : TranslationUnit,
  type_ : ConstEvalType,
  data : Bytes,
  offset : Int,
) -> ConstEvalValue? raise WeslCompileError {
  match type_ {
    Vector(width, element) => {
      let values : Array[ConstEvalValue] = []
      let element_size = match const_eval_type_size(unit, element) {
        Some(value) => value
        None => return None
      }
      for index in 0..<width {
        match
          const_eval_value_from_buffer_type(
            unit,
            element,
            data,
            offset + index * element_size,
          ) {
          Some(value) => values.push(value)
          None => return None
        }
      }
      Some(ConstEvalValue::Vector(width, element, values))
    }
    Matrix(columns, rows, element) => {
      let column_type = ConstEvalType::Vector(rows, element)
      let column_size = match const_eval_type_size(unit, column_type) {
        Some(value) => value
        None => return None
      }
      let column_stride = match const_eval_type_stride(unit, column_type) {
        Some(value) => value
        None => return None
      }
      let values : Array[ConstEvalValue] = []
      for index in 0..<columns {
        match
          const_eval_value_from_buffer_type(
            unit,
            column_type,
            data,
            offset + index * column_stride,
          ) {
          Some(value) => values.push(value)
          None => return None
        }
      }
      ignore(column_size)
      Some(ConstEvalValue::Matrix(columns, rows, element, values))
    }
    Array(element, count) => {
      let element_size = match const_eval_type_size(unit, element) {
        Some(value) => value
        None => return None
      }
      let stride = match const_eval_type_stride(unit, element) {
        Some(value) => value
        None => return None
      }
      let element_count = match count {
        Some(value) => value
        None => {
          let remaining = data.length() - offset
          if remaining < stride {
            return None
          }
          remaining / stride
        }
      }
      if element_count <= 0 {
        return None
      }
      let values : Array[ConstEvalValue] = []
      for index in 0..<element_count {
        let element_offset = offset + index * stride
        if element_offset + element_size > data.length() {
          return None
        }
        match
          const_eval_value_from_buffer_type(unit, element, data, element_offset) {
          Some(value) => values.push(value)
          None => return None
        }
      }
      Some(ConstEvalValue::Array(element, count, values))
    }
    ConstEvalType::Struct(name) =>
      match const_eval_struct_declaration(unit, name) {
        Some(struct_) => {
          let fields : Array[(String, ConstEvalValue)] = []
          let mut cursor = offset
          for field_decl in struct_.members {
            let member_type = const_eval_type_source_with_unit(
              unit,
              field_decl.type_text,
            )
            let member_align = match const_eval_member_align(unit, field_decl) {
              Some(value) => value
              None => return None
            }
            cursor = const_eval_round_up(member_align, cursor)
            if member_type is Array(_, None) {
              match
                const_eval_value_from_buffer_type(
                  unit, member_type, data, cursor,
                ) {
                Some(value) => fields.push((field_decl.name, value))
                None => return None
              }
              cursor = data.length()
            } else {
              let member_size = match const_eval_member_size(unit, field_decl) {
                Some(value) => value
                None => return None
              }
              match
                const_eval_value_from_buffer_type(
                  unit, member_type, data, cursor,
                ) {
                Some(value) => fields.push((field_decl.name, value))
                None => return None
              }
              cursor = cursor + member_size
            }
          }
          Some(ConstEvalValue::Struct(name, fields))
        }
        None => None
      }
    scalar => const_eval_scalar_value_from_buffer_at(scalar, data, offset)
  }
}

///|
fn const_eval_value_from_buffer_with_unit(
  unit : TranslationUnit,
  ty : String,
  data : Bytes,
) -> ConstEvalValue? raise WeslCompileError {
  const_eval_value_from_buffer_type(
    unit,
    const_eval_type_source_with_unit(unit, ty),
    data,
    0,
  )
}

///|
fn const_eval_context_from_translation_unit_with_exec_inputs(
  unit : TranslationUnit,
  resources : Array[ResourceBinding],
  overrides : Array[OverrideValue],
) -> ConstEvalContext raise WeslCompileError {
  let ctx = ConstEvalContext::new()
  for declaration in unit.global_declarations {
    match declaration.header {
      Function(function_) =>
        if syntax_has_attribute(declaration.attributes, "const") {
          ctx.functions.set(
            function_.name,
            const_eval_function_from_source(declaration.source),
          )
        }
      _ => ()
    }
  }
  for declaration in unit.global_declarations {
    match declaration.header {
      Var(var_) =>
        match
          (
            var_.name,
            var_.type_text,
            const_eval_group_binding(declaration.attributes),
          ) {
          (Some(name), Some(type_source), Some((group, binding))) =>
            match const_eval_resource_value(resources, group, binding) {
              Some(resource) =>
                match
                  const_eval_value_from_buffer_with_unit(
                    unit,
                    type_source,
                    resource.data,
                  ) {
                  Some(value) => ctx.bindings.set(name, value)
                  None =>
                    raise WeslCompileError::Validation(
                      "resource binding group=\{group} binding=\{binding} is incompatible with `\{type_source}`",
                    )
                }
              None => ()
            }
          _ => ()
        }
      Const(const_) =>
        match const_.initializer {
          Some(initializer) => {
            let value = const_eval_parse_expression_value(initializer, ctx)
            let stored = match const_.type_text {
              Some(type_source) =>
                const_eval_convert_to_type(
                  value,
                  const_eval_parse_type_source(type_source),
                  const_.name,
                )
              None => value
            }
            ctx.bindings.set(const_.name, stored)
          }
          None => ()
        }
      _ => ()
    }
  }
  for declaration in unit.global_declarations {
    match declaration.header {
      Override(override_) => {
        let source = match
          const_eval_override_value(overrides, override_.name) {
          Some(value) => Some(value)
          None => override_.initializer
        }
        match source {
          Some(initializer) => {
            let value = const_eval_parse_expression_value(initializer, ctx)
            let stored = match override_.type_text {
              Some(type_source) =>
                const_eval_convert_to_type(
                  value,
                  const_eval_parse_type_source(type_source),
                  override_.name,
                )
              None => value
            }
            ctx.bindings.set(override_.name, stored)
          }
          None =>
            raise WeslCompileError::Validation(
              "uninitialized override `\{override_.name}`",
            )
        }
      }
      _ => ()
    }
  }
  ctx
}

///|
fn const_eval_from_translation_unit_value(
  unit : TranslationUnit,
  target_expr : String,
) -> ConstEvalValue raise WeslCompileError {
  let ctx = const_eval_context_from_translation_unit(unit)
  const_eval_parse_expression_value(target_expr, ctx)
}

///|
fn const_eval_first_four_bytes(bytes : Bytes) -> Bytes {
  let array = bytes.to_array()
  Bytes::from_array([array[0], array[1], array[2], array[3]])
}

///|
fn const_eval_i32_buffer(number : Int64) -> Bytes {
  const_eval_first_four_bytes(number.reinterpret_as_uint64().to_le_bytes())
}

///|
fn const_eval_u32_buffer(number : Int64) -> Bytes {
  const_eval_first_four_bytes(number.reinterpret_as_uint64().to_le_bytes())
}

///|
fn const_eval_value_to_buffer(value : ConstEvalValue) -> Bytes? {
  match value {
    I32(number) => Some(const_eval_i32_buffer(number))
    U32(number) => Some(const_eval_u32_buffer(number))
    F32(number) => Some(number.to_le_bytes())
    Vector(_, _, elements) => {
      let bytes : Array[Byte] = []
      for element in elements {
        match const_eval_value_to_buffer(element) {
          Some(element_bytes) =>
            for byte in element_bytes.to_array() {
              bytes.push(byte)
            }
          None => return None
        }
      }
      Some(Bytes::from_array(bytes))
    }
    _ => None
  }
}

///|
fn const_eval_value_to_buffer_with_unit(
  unit : TranslationUnit,
  value : ConstEvalValue,
) -> Bytes? raise WeslCompileError {
  match value {
    I32(_) | U32(_) | F32(_) => const_eval_value_to_buffer(value)
    Vector(_, _, elements) => {
      let bytes : Array[Byte] = []
      for element in elements {
        match const_eval_value_to_buffer_with_unit(unit, element) {
          Some(element_bytes) =>
            for byte in element_bytes.to_array() {
              bytes.push(byte)
            }
          None => return None
        }
      }
      Some(Bytes::from_array(bytes))
    }
    Matrix(_, rows, element, columns) => {
      let column_type = ConstEvalType::Vector(rows, element)
      let column_size = match const_eval_type_size(unit, column_type) {
        Some(value) => value
        None => return None
      }
      let column_stride = match const_eval_type_stride(unit, column_type) {
        Some(value) => value
        None => return None
      }
      let bytes : Array[Byte] = []
      for column in columns {
        let column_bytes = match
          const_eval_value_to_buffer_with_unit(unit, column) {
          Some(value) => value
          None => return None
        }
        for byte in column_bytes.to_array() {
          bytes.push(byte)
        }
        for _ in column_size..<column_stride {
          bytes.push(b'\x00')
        }
      }
      Some(Bytes::from_array(bytes))
    }
    Array(element, count, elements) => {
      match count {
        Some(expected) => if expected != elements.length() { return None }
        None => ()
      }
      let element_size = match const_eval_type_size(unit, element) {
        Some(value) => value
        None => return None
      }
      let stride = match const_eval_type_stride(unit, element) {
        Some(value) => value
        None => return None
      }
      let bytes : Array[Byte] = []
      for element_value in elements {
        let element_bytes = match
          const_eval_value_to_buffer_with_unit(unit, element_value) {
          Some(value) => value
          None => return None
        }
        for byte in element_bytes.to_array() {
          bytes.push(byte)
        }
        for _ in element_size..<stride {
          bytes.push(b'\x00')
        }
      }
      Some(Bytes::from_array(bytes))
    }
    ConstEvalValue::Struct(name, fields) =>
      match const_eval_struct_declaration(unit, name) {
        Some(struct_) => {
          let bytes : Array[Byte] = []
          for field_decl in struct_.members {
            let field = match const_eval_struct_field(fields, field_decl.name) {
              Some(value) => value
              None => return None
            }
            let align = match const_eval_member_align(unit, field_decl) {
              Some(value) => value
              None => return None
            }
            let field_offset = const_eval_round_up(align, bytes.length())
            for _ in bytes.length()..<field_offset {
              bytes.push(b'\x00')
            }
            let field_bytes = match
              const_eval_value_to_buffer_with_unit(unit, field) {
              Some(value) => value
              None => return None
            }
            for byte in field_bytes.to_array() {
              bytes.push(byte)
            }
            let size = match field {
              Array(element, None, elements) => {
                let stride = match const_eval_type_stride(unit, element) {
                  Some(value) => value
                  None => return None
                }
                stride * elements.length()
              }
              _ =>
                match const_eval_member_size(unit, field_decl) {
                  Some(value) => value
                  None => return None
                }
            }
            for _ in field_bytes.length()..<size {
              bytes.push(b'\x00')
            }
          }
          Some(Bytes::from_array(bytes))
        }
        None => None
      }
    _ => None
  }
}

///|
fn const_eval_result(value : ConstEvalValue) -> EvalResult {
  EvalResult::{
    value: const_eval_render_value(value),
    buffer: const_eval_value_to_buffer(value),
  }
}

///|
fn const_eval_result_with_unit(
  unit : TranslationUnit,
  value : ConstEvalValue,
) -> EvalResult raise WeslCompileError {
  EvalResult::{
    value: const_eval_render_value(value),
    buffer: const_eval_value_to_buffer_with_unit(unit, value),
  }
}

///|
fn const_eval_attribute_identifier(attr : Attribute) -> String? {
  match attr.arguments {
    Some(text) => {
      let trimmed = text.trim()
      if trimmed.length() >= 2 &&
        trimmed[:1].to_owned() == "\"" &&
        trimmed[trimmed.length() - 1:trimmed.length()].to_owned() == "\"" {
        Some(trimmed[1:trimmed.length() - 1].to_owned())
      } else {
        Some(trimmed.to_owned())
      }
    }
    None => None
  }
}

///|
fn const_eval_parameter_builtin(parameter : FunctionParameter) -> String? {
  for attr in parameter.attributes {
    if attr.name == "builtin" {
      return const_eval_attribute_identifier(attr)
    }
  }
  None
}

///|
fn const_eval_parameter_location(
  parameter : FunctionParameter,
) -> Int? raise WeslCompileError {
  const_eval_named_attr_i32(parameter.attributes, "location")
}

///|
fn const_eval_int_input_value(
  number : Int,
  type_ : ConstEvalType,
  context : String,
) -> ConstEvalValue raise WeslCompileError {
  match type_ {
    I32 => ConstEvalValue::I32(number.to_int64())
    U32 => {
      if number < 0 {
        raise WeslCompileError::Validation(
          "negative builtin input for u32 parameter `\{context}`",
        )
      }
      ConstEvalValue::U32(number.to_int64())
    }
    F32 => ConstEvalValue::F32(Float::from_double(number.to_double()))
    AbstractInt => ConstEvalValue::AbstractInt(number.to_int64())
    _ =>
      raise WeslCompileError::Validation(
        "builtin input `\{context}` is incompatible with `\{type_.label()}`",
      )
  }
}

///|
fn const_eval_double_input_value(
  number : Double,
  type_ : ConstEvalType,
  context : String,
) -> ConstEvalValue raise WeslCompileError {
  match type_ {
    F32 => ConstEvalValue::F32(Float::from_double(number))
    AbstractFloat => ConstEvalValue::AbstractFloat(number, true)
    _ =>
      raise WeslCompileError::Validation(
        "builtin input `\{context}` is incompatible with `\{type_.label()}`",
      )
  }
}

///|
fn const_eval_int_vector_input_value(
  values : Array[Int],
  type_ : ConstEvalType,
  context : String,
) -> ConstEvalValue raise WeslCompileError {
  match type_ {
    Vector(width, element) => {
      if values.length() < width {
        raise WeslCompileError::Validation(
          "builtin input `\{context}` does not provide \{width} components",
        )
      }
      let elements : Array[ConstEvalValue] = []
      for index in 0..<width {
        elements.push(
          const_eval_int_input_value(values[index], element, context),
        )
      }
      ConstEvalValue::Vector(width, element, elements)
    }
    _ =>
      raise WeslCompileError::Validation(
        "builtin input `\{context}` is incompatible with `\{type_.label()}`",
      )
  }
}

///|
fn const_eval_double_vector_input_value(
  values : Array[Double],
  type_ : ConstEvalType,
  context : String,
) -> ConstEvalValue raise WeslCompileError {
  match type_ {
    Vector(width, element) => {
      if values.length() < width {
        raise WeslCompileError::Validation(
          "builtin input `\{context}` does not provide \{width} components",
        )
      }
      let elements : Array[ConstEvalValue] = []
      for index in 0..<width {
        elements.push(
          const_eval_double_input_value(values[index], element, context),
        )
      }
      ConstEvalValue::Vector(width, element, elements)
    }
    _ =>
      raise WeslCompileError::Validation(
        "builtin input `\{context}` is incompatible with `\{type_.label()}`",
      )
  }
}

///|
fn const_eval_user_input_value(
  input : UserInputValue,
  type_ : ConstEvalType,
  context : String,
) -> ConstEvalValue raise WeslCompileError {
  match input {
    Bool(value) =>
      match type_ {
        Bool => ConstEvalValue::Bool(value)
        _ =>
          raise WeslCompileError::Validation(
            "user input `\{context}` is incompatible with `\{type_.label()}`",
          )
      }
    I32(value) => const_eval_int_input_value(value, type_, context)
    U32(value) => const_eval_int_input_value(value, type_, context)
    F32(value) => const_eval_double_input_value(value, type_, context)
    I32Vector(values) =>
      const_eval_int_vector_input_value(values, type_, context)
    U32Vector(values) =>
      const_eval_int_vector_input_value(values, type_, context)
    F32Vector(values) =>
      const_eval_double_vector_input_value(values, type_, context)
  }
}

///|
fn const_eval_user_defined_input(
  inputs : Inputs,
  location : Int,
) -> UserInputValue? {
  let mut value : UserInputValue? = None
  for input in inputs.user_defined {
    if input.location == location {
      value = Some(input.value)
    }
  }
  value
}

///|
fn const_eval_location_input_value(
  inputs : Inputs,
  location : Int,
  type_ : ConstEvalType,
) -> ConstEvalValue raise WeslCompileError {
  let input = match const_eval_user_defined_input(inputs, location) {
    Some(value) => value
    None =>
      raise WeslCompileError::Validation(
        "missing user-defined input at location \{location}",
      )
  }
  const_eval_user_input_value(input, type_, "location \{location}")
}

///|
fn const_eval_struct_member_input_value(
  unit : TranslationUnit,
  inputs : Inputs,
  field : StructMember,
) -> ConstEvalValue raise WeslCompileError {
  let type_ = const_eval_type_source_with_unit(unit, field.type_text)
  let builtin = {
    let mut value : String? = None
    for attr in field.attributes {
      if attr.name == "builtin" {
        value = const_eval_attribute_identifier(attr)
      }
    }
    value
  }
  match builtin {
    Some(name) => const_eval_builtin_input_value(inputs, name, type_)
    None =>
      match const_eval_named_attr_i32(field.attributes, "location") {
        Some(location) =>
          const_eval_location_input_value(inputs, location, type_)
        None =>
          raise WeslCompileError::Validation(
            "entrypoint struct member `\{field.name}` is missing a supported @builtin or @location attribute",
          )
      }
  }
}

///|
fn const_eval_struct_entrypoint_input_value(
  unit : TranslationUnit,
  inputs : Inputs,
  type_ : ConstEvalType,
) -> ConstEvalValue? raise WeslCompileError {
  match type_ {
    Struct(name) =>
      match const_eval_struct_declaration(unit, name) {
        Some(struct_) => {
          let fields : Array[(String, ConstEvalValue)] = []
          for field in struct_.members {
            fields.push(
              (
                field.name,
                const_eval_struct_member_input_value(unit, inputs, field),
              ),
            )
          }
          Some(ConstEvalValue::Struct(name, fields))
        }
        None => None
      }
    _ => None
  }
}

///|
fn[A] const_eval_required_input(
  value : A?,
  name : String,
) -> A raise WeslCompileError {
  match value {
    Some(value) => value
    None =>
      raise WeslCompileError::Validation("missing builtin input `\{name}`")
  }
}

///|
fn const_eval_builtin_input_value(
  inputs : Inputs,
  builtin : String,
  type_ : ConstEvalType,
) -> ConstEvalValue raise WeslCompileError {
  match builtin {
    "vertex_index" =>
      const_eval_int_input_value(
        const_eval_required_input(inputs.vertex_index, builtin),
        type_,
        builtin,
      )
    "instance_index" =>
      const_eval_int_input_value(
        const_eval_required_input(inputs.instance_index, builtin),
        type_,
        builtin,
      )
    "position" =>
      const_eval_double_vector_input_value(
        const_eval_required_input(inputs.position, builtin),
        type_,
        builtin,
      )
    "front_facing" =>
      match type_ {
        Bool =>
          ConstEvalValue::Bool(
            const_eval_required_input(inputs.front_facing, builtin),
          )
        _ =>
          raise WeslCompileError::Validation(
            "builtin input `front_facing` is incompatible with `\{type_.label()}`",
          )
      }
    "sample_index" =>
      const_eval_int_input_value(
        const_eval_required_input(inputs.sample_index, builtin),
        type_,
        builtin,
      )
    "sample_mask" =>
      const_eval_int_input_value(
        const_eval_required_input(inputs.sample_mask, builtin),
        type_,
        builtin,
      )
    "local_invocation_id" =>
      const_eval_int_vector_input_value(
        const_eval_required_input(inputs.local_invocation_id, builtin),
        type_,
        builtin,
      )
    "local_invocation_index" =>
      const_eval_int_input_value(
        const_eval_required_input(inputs.local_invocation_index, builtin),
        type_,
        builtin,
      )
    "global_invocation_id" =>
      const_eval_int_vector_input_value(
        const_eval_required_input(inputs.global_invocation_id, builtin),
        type_,
        builtin,
      )
    "workgroup_id" =>
      const_eval_int_vector_input_value(
        const_eval_required_input(inputs.workgroup_id, builtin),
        type_,
        builtin,
      )
    "num_workgroups" =>
      const_eval_int_vector_input_value(
        const_eval_required_input(inputs.num_workgroups, builtin),
        type_,
        builtin,
      )
    "subgroup_invocation_id" =>
      const_eval_int_input_value(
        const_eval_required_input(inputs.subgroup_invocation_id, builtin),
        type_,
        builtin,
      )
    "subgroup_size" =>
      const_eval_int_input_value(
        const_eval_required_input(inputs.subgroup_size, builtin),
        type_,
        builtin,
      )
    "subgroup_id" =>
      const_eval_int_input_value(
        const_eval_required_input(inputs.subgroup_id, builtin),
        type_,
        builtin,
      )
    "num_subgroups" =>
      const_eval_int_input_value(
        const_eval_required_input(inputs.num_subgroups, builtin),
        type_,
        builtin,
      )
    "primitive_index" =>
      const_eval_int_input_value(
        const_eval_required_input(inputs.primitive_index, builtin),
        type_,
        builtin,
      )
    "view_index" =>
      const_eval_int_input_value(
        const_eval_required_input(inputs.view_index, builtin),
        type_,
        builtin,
      )
    _ =>
      raise WeslCompileError::Validation(
        "unsupported builtin input `\{builtin}`",
      )
  }
}

///|
fn const_eval_exec_entrypoint_args(
  unit : TranslationUnit,
  function_ : FunctionDeclaration,
  inputs : Inputs,
) -> Array[ConstEvalValue] raise WeslCompileError {
  let args : Array[ConstEvalValue] = []
  for parameter in function_.parameters {
    let type_ = const_eval_type_source_with_unit(unit, parameter.type_text)
    match const_eval_parameter_builtin(parameter) {
      Some(builtin) =>
        args.push(const_eval_builtin_input_value(inputs, builtin, type_))
      None =>
        match const_eval_parameter_location(parameter) {
          Some(location) =>
            args.push(const_eval_location_input_value(inputs, location, type_))
          None =>
            match
              const_eval_struct_entrypoint_input_value(unit, inputs, type_) {
              Some(value) => args.push(value)
              None =>
                raise WeslCompileError::Validation(
                  "entrypoint parameter `\{parameter.name}` is missing a supported @builtin or @location attribute",
                )
            }
        }
    }
  }
  args
}

///|
fn const_eval_function_source_from_declaration(
  function_ : FunctionDeclaration,
) -> String {
  let params : Array[String] = []
  for parameter in function_.parameters {
    params.push("\{parameter.name}: \{parameter.type_text}")
  }
  let joined_params = params.join(", ")
  let return_type = match function_.return_type {
    Some(type_) => type_
    None => "void"
  }
  let parts : Array[String] = [
    "@const fn \{function_.name}(\{joined_params}) -> \{return_type} {",
  ]
  for statement in function_.body.statements {
    parts.push(statement.source)
  }
  parts.push("}")
  parts.join("\n")
}

///|
fn const_eval_exec_entrypoint(
  unit : TranslationUnit,
  entrypoint : String,
  inputs : Inputs,
  resources : Array[ResourceBinding],
  overrides : Array[OverrideValue],
) -> ConstEvalEntryExec raise WeslCompileError {
  for declaration in unit.global_declarations {
    match declaration.header {
      Function(function_) =>
        if function_.name == entrypoint {
          let ctx = const_eval_context_from_translation_unit_with_exec_inputs(
            unit, resources, overrides,
          )
          match function_.return_type {
            None | Some("void") => {
              let source = const_eval_function_source_from_declaration(
                function_,
              )
              let function_value = const_eval_function_from_source(source)
              let args = const_eval_exec_entrypoint_args(
                unit, function_, inputs,
              )
              return ConstEvalEntryExec::{
                value: const_eval_execute_function(function_value, args, ctx),
                ctx,
              }
            }
            Some(_) => {
              let source = const_eval_function_source_from_declaration(
                function_,
              )
              let function_value = const_eval_function_from_source(source)
              let args = const_eval_exec_entrypoint_args(
                unit, function_, inputs,
              )
              return ConstEvalEntryExec::{
                value: Some(
                  const_eval_execute_function_value(function_value, args, ctx),
                ),
                ctx,
              }
            }
          }
        }
      _ => ()
    }
  }
  raise WeslCompileError::Validation("unknown function `\{entrypoint}`")
}

///|
fn const_eval_resources_from_exec_context(
  unit : TranslationUnit,
  resources : Array[ResourceBinding],
  ctx : ConstEvalContext,
) -> Array[ResourceBinding] raise WeslCompileError {
  let updated : Array[ResourceBinding] = []
  for resource in resources {
    if resource.kind.contains("storage") {
      match
        const_eval_resource_declaration(unit, resource.group, resource.binding) {
        Some((name, _type_source)) =>
          match ctx.bindings.get(name) {
            Some(value) =>
              match const_eval_value_to_buffer_with_unit(unit, value) {
                Some(data) =>
                  updated.push(ResourceBinding::{
                    group: resource.group,
                    binding: resource.binding,
                    kind: resource.kind,
                    data,
                  })
                None =>
                  raise WeslCompileError::Validation(
                    "resource binding group=\{resource.group} binding=\{resource.binding} cannot be written back",
                  )
              }
            None => updated.push(resource)
          }
        None => updated.push(resource)
      }
    } else {
      updated.push(resource)
    }
  }
  updated
}

///|
pub fn eval_const(
  source : String,
  target_expr : String,
) -> EvalResult raise WeslCompileError {
  const_eval_result(eval_const_function_value(source, target_expr))
}

///|
pub fn eval_str(source : String) -> EvalResult raise WeslCompileError {
  const_eval_result(eval_const_expression_value(source))
}

///|
pub fn CompileResult::eval(
  self : CompileResult,
  source : String,
) -> EvalResult raise WeslCompileError {
  const_eval_result_with_unit(
    self.syntax,
    const_eval_from_translation_unit_value(self.syntax, source),
  )
}

///|
pub fn CompileResult::exec(
  self : CompileResult,
  entrypoint : String,
  inputs : Inputs,
  resources : Array[ResourceBinding],
  overrides : Array[OverrideValue],
) -> ExecResult raise WeslCompileError {
  let inst = const_eval_exec_entrypoint(
    self.syntax,
    entrypoint,
    inputs,
    resources,
    overrides,
  )
  let value = match inst.value {
    Some(value) => Some(const_eval_render_value(value))
    None => None
  }
  let buffer = match inst.value {
    Some(value) => const_eval_value_to_buffer_with_unit(self.syntax, value)
    None => None
  }
  ExecResult::{
    value,
    buffer,
    resources: const_eval_resources_from_exec_context(
      self.syntax,
      resources,
      inst.ctx,
    ),
  }
}
