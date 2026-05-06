///|
pub enum Literal {
  F64(Double)
  F32(Float)
  F16Bits(Int)
  U16(Int)
  I16(Int)
  U32(UInt)
  I32(Int)
  U64(UInt64)
  I64(Int64)
  Bool(Bool)
  AbstractInt(Int64)
  AbstractFloat(Double)
} derive(Eq, Debug)

///|
pub(all) struct Override {
  name : String?
  id : Int?
  ty : Handle
  init : Handle?
} derive(Eq, Debug)

///|
pub(all) struct Constant {
  name : String?
  ty : Handle
  init : Handle
} derive(Eq, Debug)

///|
pub(all) struct ResourceBinding {
  group : Int
  binding : Int
} derive(Eq, Debug)

///|
pub(all) struct GlobalVariable {
  name : String?
  space : AddressSpace
  binding : ResourceBinding?
  ty : Handle
  init : Handle?
  memory_decorations : MemoryDecorations
} derive(Eq, Debug)

///|
pub enum LocalVariableKind {
  Var
  Let
  Const
} derive(Eq, Debug)

///|
pub(all) struct LocalVariable {
  name : String?
  kind : LocalVariableKind
  ty : Handle
  init : Handle?
} derive(Eq, Debug)

///|
pub enum UnaryOperator {
  Negate
  LogicalNot
  BitwiseNot
} derive(Eq, Debug)

///|
pub enum BinaryOperator {
  Add
  Subtract
  Multiply
  Divide
  Modulo
  Equal
  NotEqual
  Less
  LessEqual
  Greater
  GreaterEqual
  And
  ExclusiveOr
  InclusiveOr
  LogicalAnd
  LogicalOr
  ShiftLeft
  ShiftRight
} derive(Eq, Debug)

///|
pub enum AtomicFunction {
  Load
  Store
  Add
  Subtract
  And
  ExclusiveOr
  InclusiveOr
  Min
  Max
  Exchange
  CompareExchangeWeak
} derive(Eq, Debug)

///|
pub enum DerivativeControl {
  Coarse
  Fine
  None
} derive(Eq, Debug)

///|
pub enum DerivativeAxis {
  X
  Y
  Width
} derive(Eq, Debug)

///|
pub enum RelationalFunction {
  All
  Any
  IsNan
  IsInf
} derive(Eq, Debug)

///|
pub enum MathFunction {
  Abs
  Min
  Max
  Clamp
  Saturate
  Cos
  Cosh
  Sin
  Sinh
  Tan
  Tanh
  Acos
  Asin
  Atan
  Atan2
  Asinh
  Acosh
  Atanh
  Radians
  Degrees
  Ceil
  Floor
  Round
  Fract
  Trunc
  Modf
  Frexp
  Ldexp
  Exp
  Exp2
  Log
  Log2
  Pow
  Dot
  Dot4I8Packed
  Dot4U8Packed
  Outer
  Cross
  Distance
  Length
  Normalize
  FaceForward
  Reflect
  Refract
  Sign
  Fma
  Mix
  Step
  SmoothStep
  Sqrt
  InverseSqrt
  Inverse
  Transpose
  Determinant
  QuantizeToF16
  CountTrailingZeros
  CountLeadingZeros
  CountOneBits
  ReverseBits
  ExtractBits
  InsertBits
  FirstTrailingBit
  FirstLeadingBit
  Pack4x8snorm
  Pack4x8unorm
  Pack2x16snorm
  Pack2x16unorm
  Pack2x16float
  Pack4xI8
  Pack4xU8
  Pack4xI8Clamp
  Pack4xU8Clamp
  Unpack4x8snorm
  Unpack4x8unorm
  Unpack2x16snorm
  Unpack2x16unorm
  Unpack2x16float
  Unpack4xI8
  Unpack4xU8
} derive(Eq, Debug)

///|
pub enum SampleLevel {
  Auto
  Zero
  Exact(Handle)
  Bias(Handle)
  Gradient(Handle, Handle)
} derive(Eq, Debug)

///|
pub enum ImageQuery {
  Size(Handle?)
  NumLevels
  NumLayers
  NumSamples
} derive(Eq, Debug)

///|
pub enum SwizzleComponent {
  X
  Y
  Z
  W
} derive(Eq, Debug)

///|
pub enum Direction {
  X
  Y
  Diagonal
} derive(Eq, Debug)

///|
pub enum GatherMode {
  BroadcastFirst
  Broadcast(Handle)
  Shuffle(Handle)
  ShuffleDown(Handle)
  ShuffleUp(Handle)
  ShuffleXor(Handle)
  QuadBroadcast(Handle)
  QuadSwap(Direction)
} derive(Eq, Debug)

///|
pub enum SubgroupOperation {
  All
  Any
  Add
  Mul
  Min
  Max
  And
  Or
  Xor
} derive(Eq, Debug)

///|
pub enum CollectiveOperation {
  Reduce
  InclusiveScan
  ExclusiveScan
} derive(Eq, Debug)

///|
pub(all) struct CooperativeData {
  pointer : Handle
  stride : Handle
  row_major : Bool
} derive(Eq, Debug)

///|
pub enum Expression {
  Literal(Literal)
  Constant(Handle)
  Override(Handle)
  ZeroValue(Handle)
  Compose(Handle, Array[Handle])
  Access(Handle, Handle)
  AccessIndex(Handle, Int)
  Splat(VectorSize, Handle)
  Swizzle(VectorSize, Handle, Array[SwizzleComponent])
  FunctionArgument(Int)
  GlobalVariable(Handle)
  LocalVariable(Handle)
  Load(Handle)
  AddressOf(Handle, Handle)
  AtomicCall(AtomicFunction, Array[Handle])
  ImageSample(
    Handle,
    Handle,
    SwizzleComponent?,
    Handle,
    Handle?,
    Handle?,
    SampleLevel,
    Handle?,
    Bool
  )
  ImageLoad(Handle, Handle, Handle?, Handle?, Handle?)
  ImageQuery(Handle, ImageQuery)
  Unary(UnaryOperator, Handle)
  Binary(BinaryOperator, Handle, Handle)
  FunctionCall(Handle, Array[Handle])
  Select(Handle, Handle, Handle)
  Bitcast(Handle, Handle)
  Derivative(DerivativeAxis, DerivativeControl, Handle)
  Relational(RelationalFunction, Handle)
  Math(MathFunction, Handle, Handle?, Handle?, Handle?)
  As(Handle, ScalarKind, Int?)
  CallResult(Handle)
  AtomicResult(Handle, Bool)
  WorkGroupUniformLoadResult(Handle)
  ArrayLength(Handle)
  RayQueryVertexPositions(Handle, Bool)
  RayQueryProceedResult
  RayQueryGetIntersection(Handle, Bool)
  SubgroupBallotResult
  SubgroupOperationResult(Handle)
  CooperativeLoad(
    CooperativeSize,
    CooperativeSize,
    CooperativeRole,
    CooperativeData
  )
  CooperativeMultiplyAdd(Handle, Handle, Handle)
} derive(Eq, Debug)
