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
fn wgsl_ir_builtin_scalar_alias(name : String) -> TypeInner? {
  match name {
    "bool" => Some(TypeInner::Scalar(Scalar::Scalar(Bool, 1)))
    "i32" => Some(TypeInner::Scalar(Scalar::Scalar(Sint, 4)))
    "u32" => Some(TypeInner::Scalar(Scalar::Scalar(Uint, 4)))
    "f32" => Some(TypeInner::Scalar(Scalar::Scalar(Float, 4)))
    "f16" => Some(TypeInner::Scalar(Scalar::Scalar(Float, 2)))
    _ => None
  }
}

///|
fn wgsl_ir_builtin_vector_alias(name : String) -> TypeInner? {
  match name {
    "vec2f" => Some(TypeInner::Vector(Bi, Scalar::Scalar(Float, 4)))
    "vec3f" => Some(TypeInner::Vector(Tri, Scalar::Scalar(Float, 4)))
    "vec4f" => Some(TypeInner::Vector(Quad, Scalar::Scalar(Float, 4)))
    "vec2h" => Some(TypeInner::Vector(Bi, Scalar::Scalar(Float, 2)))
    "vec3h" => Some(TypeInner::Vector(Tri, Scalar::Scalar(Float, 2)))
    "vec4h" => Some(TypeInner::Vector(Quad, Scalar::Scalar(Float, 2)))
    "vec2i" => Some(TypeInner::Vector(Bi, Scalar::Scalar(Sint, 4)))
    "vec3i" => Some(TypeInner::Vector(Tri, Scalar::Scalar(Sint, 4)))
    "vec4i" => Some(TypeInner::Vector(Quad, Scalar::Scalar(Sint, 4)))
    "vec2u" => Some(TypeInner::Vector(Bi, Scalar::Scalar(Uint, 4)))
    "vec3u" => Some(TypeInner::Vector(Tri, Scalar::Scalar(Uint, 4)))
    "vec4u" => Some(TypeInner::Vector(Quad, Scalar::Scalar(Uint, 4)))
    _ => None
  }
}

///|
fn wgsl_ir_builtin_matrix_alias(name : String) -> TypeInner? {
  match name {
    "mat2x2f" => Some(TypeInner::Matrix(Bi, Bi, Scalar::Scalar(Float, 4)))
    "mat2x3f" => Some(TypeInner::Matrix(Bi, Tri, Scalar::Scalar(Float, 4)))
    "mat2x4f" => Some(TypeInner::Matrix(Bi, Quad, Scalar::Scalar(Float, 4)))
    "mat3x2f" => Some(TypeInner::Matrix(Tri, Bi, Scalar::Scalar(Float, 4)))
    "mat3x3f" => Some(TypeInner::Matrix(Tri, Tri, Scalar::Scalar(Float, 4)))
    "mat3x4f" => Some(TypeInner::Matrix(Tri, Quad, Scalar::Scalar(Float, 4)))
    "mat4x2f" => Some(TypeInner::Matrix(Quad, Bi, Scalar::Scalar(Float, 4)))
    "mat4x3f" => Some(TypeInner::Matrix(Quad, Tri, Scalar::Scalar(Float, 4)))
    "mat4x4f" => Some(TypeInner::Matrix(Quad, Quad, Scalar::Scalar(Float, 4)))
    "mat2x2h" => Some(TypeInner::Matrix(Bi, Bi, Scalar::Scalar(Float, 2)))
    "mat2x3h" => Some(TypeInner::Matrix(Bi, Tri, Scalar::Scalar(Float, 2)))
    "mat2x4h" => Some(TypeInner::Matrix(Bi, Quad, Scalar::Scalar(Float, 2)))
    "mat3x2h" => Some(TypeInner::Matrix(Tri, Bi, Scalar::Scalar(Float, 2)))
    "mat3x3h" => Some(TypeInner::Matrix(Tri, Tri, Scalar::Scalar(Float, 2)))
    "mat3x4h" => Some(TypeInner::Matrix(Tri, Quad, Scalar::Scalar(Float, 2)))
    "mat4x2h" => Some(TypeInner::Matrix(Quad, Bi, Scalar::Scalar(Float, 2)))
    "mat4x3h" => Some(TypeInner::Matrix(Quad, Tri, Scalar::Scalar(Float, 2)))
    "mat4x4h" => Some(TypeInner::Matrix(Quad, Quad, Scalar::Scalar(Float, 2)))
    _ => None
  }
}

///|
fn wgsl_ir_math_function_from_name(name : String) -> MathFunction? {
  match name {
    "abs" => Some(Abs)
    "min" => Some(Min)
    "max" => Some(Max)
    "clamp" => Some(Clamp)
    "saturate" => Some(Saturate)
    "cos" => Some(Cos)
    "cosh" => Some(Cosh)
    "sin" => Some(Sin)
    "sinh" => Some(Sinh)
    "tan" => Some(Tan)
    "tanh" => Some(Tanh)
    "acos" => Some(Acos)
    "acosh" => Some(Acosh)
    "asin" => Some(Asin)
    "asinh" => Some(Asinh)
    "atan" => Some(Atan)
    "atanh" => Some(Atanh)
    "atan2" => Some(Atan2)
    "radians" => Some(Radians)
    "degrees" => Some(Degrees)
    "ceil" => Some(Ceil)
    "floor" => Some(Floor)
    "round" => Some(Round)
    "fract" => Some(Fract)
    "trunc" => Some(Trunc)
    "modf" => Some(Modf)
    "frexp" => Some(Frexp)
    "ldexp" => Some(Ldexp)
    "exp" => Some(Exp)
    "exp2" => Some(Exp2)
    "log" => Some(Log)
    "log2" => Some(Log2)
    "pow" => Some(Pow)
    "dot" => Some(Dot)
    "dot4I8Packed" => Some(Dot4I8Packed)
    "dot4U8Packed" => Some(Dot4U8Packed)
    "cross" => Some(Cross)
    "distance" => Some(Distance)
    "length" => Some(Length)
    "normalize" => Some(Normalize)
    "faceForward" => Some(FaceForward)
    "reflect" => Some(Reflect)
    "refract" => Some(Refract)
    "sign" => Some(Sign)
    "fma" => Some(Fma)
    "mix" => Some(Mix)
    "step" => Some(Step)
    "smoothstep" => Some(SmoothStep)
    "sqrt" => Some(Sqrt)
    "inverseSqrt" => Some(InverseSqrt)
    "inverse" => Some(Inverse)
    "transpose" => Some(Transpose)
    "determinant" => Some(Determinant)
    "quantizeToF16" => Some(QuantizeToF16)
    "countTrailingZeros" => Some(CountTrailingZeros)
    "countLeadingZeros" => Some(CountLeadingZeros)
    "countOneBits" => Some(CountOneBits)
    "reverseBits" => Some(ReverseBits)
    "extractBits" => Some(ExtractBits)
    "insertBits" => Some(InsertBits)
    "firstTrailingBit" => Some(FirstTrailingBit)
    "firstLeadingBit" => Some(FirstLeadingBit)
    "pack4x8snorm" => Some(Pack4x8snorm)
    "pack4x8unorm" => Some(Pack4x8unorm)
    "pack2x16snorm" => Some(Pack2x16snorm)
    "pack2x16unorm" => Some(Pack2x16unorm)
    "pack2x16float" => Some(Pack2x16float)
    "pack4xI8" => Some(Pack4xI8)
    "pack4xU8" => Some(Pack4xU8)
    "pack4xI8Clamp" => Some(Pack4xI8Clamp)
    "pack4xU8Clamp" => Some(Pack4xU8Clamp)
    "unpack4x8snorm" => Some(Unpack4x8snorm)
    "unpack4x8unorm" => Some(Unpack4x8unorm)
    "unpack2x16snorm" => Some(Unpack2x16snorm)
    "unpack2x16unorm" => Some(Unpack2x16unorm)
    "unpack2x16float" => Some(Unpack2x16float)
    "unpack4xI8" => Some(Unpack4xI8)
    "unpack4xU8" => Some(Unpack4xU8)
    _ => None
  }
}

///|
fn wgsl_ir_derivative_function_from_name(
  name : String,
) -> (DerivativeAxis, DerivativeControl)? {
  match name {
    "dpdx" => Some((X, DerivativeControl::None))
    "dpdxCoarse" => Some((X, Coarse))
    "dpdxFine" => Some((X, Fine))
    "dpdy" => Some((Y, DerivativeControl::None))
    "dpdyCoarse" => Some((Y, Coarse))
    "dpdyFine" => Some((Y, Fine))
    "fwidth" => Some((Width, DerivativeControl::None))
    "fwidthCoarse" => Some((Width, Coarse))
    "fwidthFine" => Some((Width, Fine))
    _ => None
  }
}

///|
fn wgsl_ir_relational_function_from_name(name : String) -> RelationalFunction? {
  match name {
    "all" => Some(All)
    "any" => Some(Any)
    "isNan" => Some(IsNan)
    "isInf" => Some(IsInf)
    _ => None
  }
}

///|
fn wgsl_ir_relational_function_name(
  relational_function : RelationalFunction,
) -> String {
  match relational_function {
    All => "all"
    Any => "any"
    IsNan => "isNan"
    IsInf => "isInf"
  }
}

///|
fn wgsl_ir_atomic_function_from_name(name : String) -> AtomicFunction? {
  match name {
    "atomicLoad" => Some(Load)
    "atomicStore" => Some(Store)
    "atomicAdd" => Some(Add)
    "atomicSub" => Some(Subtract)
    "atomicMax" => Some(Max)
    "atomicMin" => Some(Min)
    "atomicAnd" => Some(And)
    "atomicOr" => Some(InclusiveOr)
    "atomicXor" => Some(ExclusiveOr)
    "atomicExchange" => Some(Exchange)
    "atomicCompareExchangeWeak" => Some(CompareExchangeWeak)
    _ => None
  }
}

///|
fn wgsl_ir_atomic_function_name(function : AtomicFunction) -> String {
  match function {
    Load => "atomicLoad"
    Store => "atomicStore"
    Add => "atomicAdd"
    Subtract => "atomicSub"
    Max => "atomicMax"
    Min => "atomicMin"
    And => "atomicAnd"
    InclusiveOr => "atomicOr"
    ExclusiveOr => "atomicXor"
    Exchange => "atomicExchange"
    CompareExchangeWeak => "atomicCompareExchangeWeak"
  }
}

///|
fn wgsl_ir_align_to(value : Int, align : Int) -> Int {
  if align <= 1 {
    value
  } else {
    let rem = value % align
    if rem == 0 {
      value
    } else {
      value + align - rem
    }
  }
}

///|
fn wgsl_ir_vector_size_from_name(name : String) -> VectorSize {
  match name {
    "vec2" => Bi
    "vec3" => Tri
    _ => Quad
  }
}

///|
fn wgsl_ir_matrix_size_from_name(name : String) -> (VectorSize, VectorSize) {
  match name {
    "mat2x2" => (Bi, Bi)
    "mat2x3" => (Bi, Tri)
    "mat2x4" => (Bi, Quad)
    "mat3x2" => (Tri, Bi)
    "mat3x3" => (Tri, Tri)
    "mat3x4" => (Tri, Quad)
    "mat4x2" => (Quad, Bi)
    "mat4x3" => (Quad, Tri)
    _ => (Quad, Quad)
  }
}
