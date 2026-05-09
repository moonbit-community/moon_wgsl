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
fn WgslIrLowerer::type_layout(
  self : WgslIrLowerer,
  handle : Handle,
) -> WgslIrLayout raise WgslIrLowerError {
  match self.shader_module.types.get(handle) {
    Some(ty) =>
      match ty.inner {
        Scalar(scalar) | Atomic(scalar) =>
          WgslIrLayout::{ align: scalar.width, size: scalar.width }
        Vector(size, scalar) => {
          let width = size.width()
          let raw = width * scalar.width
          WgslIrLayout::{
            align: if width == 3 {
              4 * scalar.width
            } else {
              raw
            },
            size: raw,
          }
        }
        Matrix(columns, rows, scalar) => {
          let column_align = if rows.width() == 3 {
            4 * scalar.width
          } else {
            rows.width() * scalar.width
          }
          let column_size = wgsl_ir_align_to(
            rows.width() * scalar.width,
            column_align,
          )
          WgslIrLayout::{
            align: column_align,
            size: column_size * columns.width(),
          }
        }
        Array(base, size, stride) => {
          let base_layout = self.type_layout(base)
          WgslIrLayout::{
            align: base_layout.align,
            size: self.array_size_layout_count(size) * stride,
          }
        }
        Struct(members, span) | PredeclaredStruct(members, span) => {
          let mut align = 1
          for struct_member in members {
            let member_layout = self.type_layout(struct_member.ty)
            if member_layout.align > align {
              align = member_layout.align
            }
          }
          WgslIrLayout::{ align, size: span }
        }
        Pointer(_, _) | ValuePointer(_, _, _) =>
          WgslIrLayout::{ align: 1, size: 4 }
        Image(_, _, _)
        | Sampler(_)
        | AccelerationStructure(_)
        | RayQuery(_)
        | BindingArray(_, _) => WgslIrLayout::{ align: 1, size: 0 }
        CooperativeMatrix(columns, rows, scalar, _) =>
          WgslIrLayout::{
            align: scalar.width,
            size: wgsl_ir_cooperative_size_width(columns) *
            wgsl_ir_cooperative_size_width(rows) *
            scalar.width,
          }
      }
    None => raise WgslIrLowerError::UnsupportedType("invalid type handle")
  }
}

///|
fn WgslIrLowerer::array_size_layout_count(
  self : WgslIrLowerer,
  size : ArraySize,
) -> Int raise WgslIrLowerError {
  match size {
    Constant(value) => value
    Dynamic => 1
    Pending(handle) =>
      self.eval_global_integer_expression(handle).to_non_negative_int()
  }
}

///|
fn WgslIrLowerer::refresh_dependent_type_layouts(
  self : WgslIrLowerer,
) -> Unit raise WgslIrLowerError {
  for _ in 0..<self.shader_module.types.items.length() {
    let mut changed = false
    for index in 0..<self.shader_module.types.items.length() {
      let ty = self.shader_module.types.items[index]
      match ty.inner {
        Array(element, size, stride) => {
          let layout = self.type_layout(element)
          let refreshed_stride = wgsl_ir_align_to(layout.size, layout.align)
          if refreshed_stride != stride {
            self.shader_module.types.set(Handle::Handle(index), Type::{
              name: ty.name,
              inner: TypeInner::Array(element, size, refreshed_stride),
            })
            changed = true
          }
        }
        _ => ()
      }
    }
    if !changed {
      return
    }
  }
}

///|
fn wgsl_ir_struct_member_size(
  attributes : Array[@ast.WgslAttribute],
  layout : WgslIrLayout,
) -> Int raise WgslIrLowerError {
  match wgsl_ir_attribute_named(attributes, "size") {
    Some(attribute) =>
      match wgsl_ir_attribute_int_value(attribute) {
        Some(size) =>
          if size < layout.size {
            raise WgslIrLowerError::UnsupportedType(
              "@size is smaller than member type size",
            )
          } else {
            size
          }
        None =>
          raise WgslIrLowerError::UnsupportedType(
            "@size must be an integer literal",
          )
      }
    None => layout.size
  }
}

///|
fn wgsl_ir_struct_member_align(
  attributes : Array[@ast.WgslAttribute],
  layout : WgslIrLayout,
) -> Int raise WgslIrLowerError {
  match wgsl_ir_attribute_named(attributes, "align") {
    Some(attribute) =>
      match wgsl_ir_attribute_int_value(attribute) {
        Some(align) =>
          if !wgsl_ir_is_power_of_two(align) {
            raise WgslIrLowerError::UnsupportedType(
              "@align must be a positive power of two",
            )
          } else if align < layout.align {
            raise WgslIrLowerError::UnsupportedType(
              "@align is smaller than member type alignment",
            )
          } else {
            align
          }
        None =>
          raise WgslIrLowerError::UnsupportedType(
            "@align must be an integer literal",
          )
      }
    None => layout.align
  }
}

///|
fn wgsl_ir_is_power_of_two(value : Int) -> Bool {
  value > 0 && (value & (value - 1)) == 0
}

///|
fn wgsl_ir_cooperative_size_width(size : CooperativeSize) -> Int {
  match size {
    Eight => 8
    Sixteen => 16
  }
}

///|
fn WgslIrLowerer::lower_type_name_with_expression_arguments(
  self : WgslIrLowerer,
  name : String,
  arguments : Array[@ast.WgslExprNode],
) -> Handle raise WgslIrLowerError {
  match self.type_cache.get(name) {
    Some(handle) => handle
    None =>
      match wgsl_ir_builtin_vector_alias(name) {
        Some(inner) => self.intern_type(name, inner)
        None =>
          match wgsl_ir_builtin_matrix_alias(name) {
            Some(inner) => self.intern_type(name, inner)
            None =>
              match arguments {
                [] => raise WgslIrLowerError::UnsupportedType(name)
                _ => raise WgslIrLowerError::UnsupportedType(name)
              }
          }
      }
  }
}
