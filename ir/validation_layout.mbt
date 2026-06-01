///|
fn WgslIrValidator::type_layout(
  self : WgslIrValidator,
  ty : Handle,
) -> WgslIrValidationLayout raise WgslIrValidationError {
  match self.shader_module.types.get(ty) {
    Some(type_) => self.type_inner_layout(type_.inner)
    None => raise WgslIrValidationError::InvalidTypeHandle(ty.index())
  }
}

///|
fn WgslIrValidator::type_inner_layout(
  self : WgslIrValidator,
  inner : TypeInner,
) -> WgslIrValidationLayout raise WgslIrValidationError {
  match inner {
    Scalar(scalar) | Atomic(scalar) =>
      WgslIrValidationLayout::{ align: scalar.width, size: scalar.width }
    Vector(size, scalar) => {
      let lanes = size.width()
      let raw_size = lanes * scalar.width
      WgslIrValidationLayout::{
        align: if lanes == 3 {
          4 * scalar.width
        } else {
          raw_size
        },
        size: raw_size,
      }
    }
    Matrix(columns, rows, scalar) => {
      let row_lanes = rows.width()
      let column_align = if row_lanes == 3 {
        4 * scalar.width
      } else {
        row_lanes * scalar.width
      }
      let column_size = wgsl_ir_validation_align_to(
        row_lanes * scalar.width,
        column_align,
      )
      WgslIrValidationLayout::{
        align: column_align,
        size: column_size * columns.width(),
      }
    }
    Array(base, size, stride) => {
      let count = match size {
        Constant(value) => value
        Dynamic | Pending(_) => 1
      }
      WgslIrValidationLayout::{
        align: self.type_layout(base).align,
        size: count * stride,
      }
    }
    Struct(members, span) | PredeclaredStruct(members, span) => {
      let mut align = 1
      for struct_member in members {
        let member_layout = self.type_layout(struct_member.ty)
        let member_align = match struct_member.align {
          Some(value) => value
          None => member_layout.align
        }
        if member_align > align {
          align = member_align
        }
      }
      WgslIrValidationLayout::{ align, size: span }
    }
    Pointer(_, _) | ValuePointer(_, _, _) =>
      WgslIrValidationLayout::{ align: 1, size: 4 }
    Image(_, _, _)
    | Sampler(_)
    | AccelerationStructure(_)
    | RayQuery(_)
    | BindingArray(_, _) => WgslIrValidationLayout::{ align: 1, size: 0 }
    CooperativeMatrix(columns, rows, scalar, _) =>
      WgslIrValidationLayout::{
        align: scalar.width,
        size: wgsl_ir_validation_cooperative_size_width(columns) *
        wgsl_ir_validation_cooperative_size_width(rows) *
        scalar.width,
      }
  }
}

///|
fn WgslIrValidator::find_type_by_name(
  self : WgslIrValidator,
  name : String,
) -> Handle? {
  for index in 0..<self.shader_module.types.items.length() {
    let ty = self.shader_module.types.items[index]
    if ty.name == Some(name) {
      return Some(Handle::Handle(index))
    }
  }
  None
}

///|
fn WgslIrValidator::find_scalar_type(
  self : WgslIrValidator,
  scalar : Scalar,
) -> Handle? {
  self.find_type_inner(TypeInner::Scalar(scalar))
}

///|
fn WgslIrValidator::vector_type(
  self : WgslIrValidator,
  size : VectorSize,
  scalar : Scalar,
) -> Handle? {
  self.find_type_inner(TypeInner::Vector(size, scalar))
}

///|
fn WgslIrValidator::matrix_type(
  self : WgslIrValidator,
  columns : VectorSize,
  rows : VectorSize,
  scalar : Scalar,
) -> Handle? {
  self.find_type_inner(TypeInner::Matrix(columns, rows, scalar))
}

///|
fn WgslIrValidator::cooperative_matrix_type(
  self : WgslIrValidator,
  columns : CooperativeSize,
  rows : CooperativeSize,
  scalar : Scalar,
  role : CooperativeRole,
) -> Handle? {
  self.find_type_inner(
    TypeInner::CooperativeMatrix(columns, rows, scalar, role),
  )
}

///|
fn WgslIrValidator::find_type_inner(
  self : WgslIrValidator,
  inner : TypeInner,
) -> Handle? {
  for index in 0..<self.shader_module.types.items.length() {
    if self.shader_module.types.items[index].inner == inner {
      return Some(Handle::Handle(index))
    }
  }
  None
}

///|
fn WgslIrValidator::function_display_name(
  self : WgslIrValidator,
  function : Function,
) -> String {
  ignore(self)
  match function.name {
    Some(name) => name
    None => "<anonymous>"
  }
}

///|
fn wgsl_ir_validation_binary_operator_is_comparison(
  op : BinaryOperator,
) -> Bool {
  match op {
    Equal | NotEqual | Less | LessEqual | Greater | GreaterEqual => true
    _ => false
  }
}

///|
fn wgsl_ir_validation_scalar_assignable(
  expected : Scalar,
  actual : Scalar,
) -> Bool {
  if expected == actual {
    return true
  }
  match (expected.kind, actual.kind) {
    (Sint, AbstractInt) | (Uint, AbstractInt) | (Float, AbstractFloat) => true
    (Float, AbstractInt) => true
    (AbstractFloat, AbstractInt) | (AbstractInt, AbstractFloat) => true
    _ => false
  }
}

///|
fn wgsl_ir_validation_storage_format_scalar(format : StorageFormat) -> Scalar {
  match format {
    R64Uint => Scalar::Scalar(Uint, 8)
    R8Uint
    | R16Uint
    | Rg8Uint
    | R32Uint
    | Rg16Uint
    | Rgba8Uint
    | Rgb10a2Uint
    | Rg32Uint
    | Rgba16Uint
    | Rgba32Uint => Scalar::Scalar(Uint, 4)
    R8Sint | R16Sint | Rg8Sint | R32Sint | Rg16Sint | Rgba8Sint | Rgba32Sint =>
      Scalar::Scalar(Sint, 4)
    _ => Scalar::Scalar(Float, 4)
  }
}

///|
fn wgsl_ir_validation_scalar_width_is_valid(
  kind : ScalarKind,
  width : Int,
) -> Bool {
  match kind {
    Bool => width == 1
    Sint | Uint | Float => width == 2 || width == 4 || width == 8
    AbstractInt | AbstractFloat => width == 8
  }
}

///|
fn wgsl_ir_validation_swizzle_index(component : SwizzleComponent) -> Int {
  match component {
    X => 0
    Y => 1
    Z => 2
    W => 3
  }
}

///|
fn wgsl_ir_validation_is_power_of_two(value : Int) -> Bool {
  value > 0 && (value & (value - 1)) == 0
}

///|
fn wgsl_ir_validation_align_to(value : Int, align : Int) -> Int {
  if align <= 1 {
    value
  } else {
    (value + align - 1) / align * align
  }
}

///|
fn wgsl_ir_validation_cooperative_size_width(size : CooperativeSize) -> Int {
  match size {
    Eight => 8
    Sixteen => 16
  }
}
