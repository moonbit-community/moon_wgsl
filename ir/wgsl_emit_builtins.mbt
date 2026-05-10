///|
fn WgslIrEmitter::unary_operator(
  self : WgslIrEmitter,
  op : UnaryOperator,
) -> String {
  ignore(self)
  match op {
    Negate => "-"
    LogicalNot => "!"
    BitwiseNot => "~"
  }
}

///|
fn WgslIrEmitter::binary_operator(
  self : WgslIrEmitter,
  op : BinaryOperator,
) -> String {
  ignore(self)
  match op {
    Add => "+"
    Subtract => "-"
    Multiply => "*"
    Divide => "/"
    Modulo => "%"
    Equal => "=="
    NotEqual => "!="
    Less => "<"
    LessEqual => "<="
    Greater => ">"
    GreaterEqual => ">="
    And => "&"
    ExclusiveOr => "^"
    InclusiveOr => "|"
    LogicalAnd => "&&"
    LogicalOr => "||"
    ShiftLeft => "<<"
    ShiftRight => ">>"
  }
}

///|
fn WgslIrEmitter::math_function_name(
  self : WgslIrEmitter,
  math_function : MathFunction,
) -> String raise WgslIrEmitError {
  ignore(self)
  match math_function {
    Abs => "abs"
    Min => "min"
    Max => "max"
    Clamp => "clamp"
    Saturate => "saturate"
    Cos => "cos"
    Cosh => "cosh"
    Sin => "sin"
    Sinh => "sinh"
    Tan => "tan"
    Tanh => "tanh"
    Acos => "acos"
    Acosh => "acosh"
    Asin => "asin"
    Asinh => "asinh"
    Atan => "atan"
    Atanh => "atanh"
    Atan2 => "atan2"
    Radians => "radians"
    Degrees => "degrees"
    Ceil => "ceil"
    Floor => "floor"
    Round => "round"
    Fract => "fract"
    Trunc => "trunc"
    Modf => "modf"
    Frexp => "frexp"
    Ldexp => "ldexp"
    Exp => "exp"
    Exp2 => "exp2"
    Log => "log"
    Log2 => "log2"
    Pow => "pow"
    Dot => "dot"
    Dot4I8Packed => "dot4I8Packed"
    Dot4U8Packed => "dot4U8Packed"
    Cross => "cross"
    Distance => "distance"
    Length => "length"
    Normalize => "normalize"
    FaceForward => "faceForward"
    Reflect => "reflect"
    Refract => "refract"
    Sign => "sign"
    Fma => "fma"
    Mix => "mix"
    Step => "step"
    SmoothStep => "smoothstep"
    Sqrt => "sqrt"
    InverseSqrt => "inverseSqrt"
    Inverse => "inverse"
    Transpose => "transpose"
    Determinant => "determinant"
    QuantizeToF16 => "quantizeToF16"
    CountTrailingZeros => "countTrailingZeros"
    CountLeadingZeros => "countLeadingZeros"
    CountOneBits => "countOneBits"
    ReverseBits => "reverseBits"
    ExtractBits => "extractBits"
    InsertBits => "insertBits"
    FirstTrailingBit => "firstTrailingBit"
    FirstLeadingBit => "firstLeadingBit"
    Pack4x8snorm => "pack4x8snorm"
    Pack4x8unorm => "pack4x8unorm"
    Pack2x16snorm => "pack2x16snorm"
    Pack2x16unorm => "pack2x16unorm"
    Pack2x16float => "pack2x16float"
    Pack4xI8 => "pack4xI8"
    Pack4xU8 => "pack4xU8"
    Pack4xI8Clamp => "pack4xI8Clamp"
    Pack4xU8Clamp => "pack4xU8Clamp"
    Unpack4x8snorm => "unpack4x8snorm"
    Unpack4x8unorm => "unpack4x8unorm"
    Unpack2x16snorm => "unpack2x16snorm"
    Unpack2x16unorm => "unpack2x16unorm"
    Unpack2x16float => "unpack2x16float"
    Unpack4xI8 => "unpack4xI8"
    Unpack4xU8 => "unpack4xU8"
    _ => raise WgslIrEmitError::Unsupported("math function")
  }
}

///|
fn wgsl_ir_derivative_function_name(
  axis : DerivativeAxis,
  control : DerivativeControl,
) -> String {
  match (axis, control) {
    (X, DerivativeControl::None) => "dpdx"
    (X, Coarse) => "dpdxCoarse"
    (X, Fine) => "dpdxFine"
    (Y, DerivativeControl::None) => "dpdy"
    (Y, Coarse) => "dpdyCoarse"
    (Y, Fine) => "dpdyFine"
    (Width, DerivativeControl::None) => "fwidth"
    (Width, Coarse) => "fwidthCoarse"
    (Width, Fine) => "fwidthFine"
  }
}

///|
fn WgslIrEmitter::relational_function_name(
  self : WgslIrEmitter,
  relational_function : RelationalFunction,
) -> String {
  ignore(self)
  match relational_function {
    All => "all"
    Any => "any"
    IsNan => "isNan"
    IsInf => "isInf"
  }
}

///|
fn WgslIrEmitter::atomic_function_name(
  self : WgslIrEmitter,
  atomic_function : AtomicFunction,
) -> String {
  ignore(self)
  match atomic_function {
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
fn WgslIrEmitter::texture_atomic_function_name(
  self : WgslIrEmitter,
  atomic_function : AtomicFunction,
) -> String raise WgslIrEmitError {
  ignore(self)
  match atomic_function {
    Add => "textureAtomicAdd"
    And => "textureAtomicAnd"
    Max => "textureAtomicMax"
    Min => "textureAtomicMin"
    InclusiveOr => "textureAtomicOr"
    ExclusiveOr => "textureAtomicXor"
    _ =>
      raise WgslIrEmitError::Unsupported("unsupported texture atomic function")
  }
}

///|
fn WgslIrEmitter::storage_format_name(
  self : WgslIrEmitter,
  format : StorageFormat,
) -> String {
  ignore(self)
  match format {
    R8Unorm => "r8unorm"
    R8Snorm => "r8snorm"
    R8Uint => "r8uint"
    R8Sint => "r8sint"
    R16Uint => "r16uint"
    R16Sint => "r16sint"
    R16Float => "r16float"
    Rg8Unorm => "rg8unorm"
    Rg8Snorm => "rg8snorm"
    Rg8Uint => "rg8uint"
    Rg8Sint => "rg8sint"
    R32Uint => "r32uint"
    R32Sint => "r32sint"
    R32Float => "r32float"
    Rg16Uint => "rg16uint"
    Rg16Sint => "rg16sint"
    Rg16Float => "rg16float"
    Rgba8Unorm => "rgba8unorm"
    Rgba8Snorm => "rgba8snorm"
    Rgba8Uint => "rgba8uint"
    Rgba8Sint => "rgba8sint"
    Bgra8Unorm => "bgra8unorm"
    Rgb10a2Uint => "rgb10a2uint"
    Rgb10a2Unorm => "rgb10a2unorm"
    Rg11b10Ufloat => "rg11b10ufloat"
    R64Uint => "r64uint"
    Rg32Uint => "rg32uint"
    Rg32Sint => "rg32sint"
    Rg32Float => "rg32float"
    Rgba16Uint => "rgba16uint"
    Rgba16Sint => "rgba16sint"
    Rgba16Float => "rgba16float"
    Rgba32Uint => "rgba32uint"
    Rgba32Sint => "rgba32sint"
    Rgba32Float => "rgba32float"
    R16Unorm => "r16unorm"
    R16Snorm => "r16snorm"
    Rg16Unorm => "rg16unorm"
    Rg16Snorm => "rg16snorm"
    Rgba16Unorm => "rgba16unorm"
    Rgba16Snorm => "rgba16snorm"
  }
}

///|
fn wgsl_ir_emit_storage_format_scalar(format : StorageFormat) -> Scalar {
  match format {
    R64Uint => Scalar::Scalar(Uint, 8)
    R8Uint
    | R16Uint
    | R32Uint
    | Rg8Uint
    | Rg16Uint
    | Rgba8Uint
    | Rgb10a2Uint
    | Rg32Uint
    | Rgba16Uint
    | Rgba32Uint => Scalar::Scalar(Uint, 4)
    R8Sint
    | R16Sint
    | R32Sint
    | Rg8Sint
    | Rg16Sint
    | Rgba8Sint
    | Rg32Sint
    | Rgba16Sint
    | Rgba32Sint => Scalar::Scalar(Sint, 4)
    _ => Scalar::Scalar(Float, 4)
  }
}

///|
fn wgsl_ir_swizzle_component(index : Int) -> String raise WgslIrEmitError {
  match index {
    0 => "x"
    1 => "y"
    2 => "z"
    3 => "w"
    _ => raise WgslIrEmitError::Unsupported("access index \{index}")
  }
}

///|
fn wgsl_ir_gather_component_index(component : SwizzleComponent) -> Int {
  match component {
    X => 0
    Y => 1
    Z => 2
    W => 3
  }
}

///|
fn wgsl_ir_swizzle_component_name(component : SwizzleComponent) -> String {
  match component {
    X => "x"
    Y => "y"
    Z => "z"
    W => "w"
  }
}

///|
fn wgsl_ir_indent(count : Int) -> String {
  let out = StringBuilder::new()
  for _ in 0..<count {
    out.write_string("    ")
  }
  out.to_string()
}
