///|
pub enum ConservativeDepth {
  GreaterEqual
  LessEqual
  Unchanged
} derive(Eq, Debug)

///|
pub enum EarlyDepthTest {
  Force
  Allow(ConservativeDepth)
} derive(Eq, Debug)

///|
pub enum ShaderStage {
  Vertex
  Task
  Mesh
  Fragment
  Compute
  RayGeneration
  Miss
  AnyHit
  ClosestHit
} derive(Eq, Debug)

///|
pub enum AddressSpace {
  Function
  Private
  WorkGroup
  Uniform
  Storage(StorageAccess)
  Handle
  Immediate
  TaskPayload
  RayPayload
  IncomingRayPayload
} derive(Eq, Debug)

///|
pub enum BuiltIn {
  PrimitiveIndex
  Position(Bool)
  ViewIndex
  BaseInstance
  BaseVertex
  ClipDistances
  CullDistance
  InstanceIndex
  PointSize
  VertexIndex
  DrawIndex
  FragDepth
  PointCoord
  FrontFacing
  Barycentric(Bool)
  SampleIndex
  SampleMask
  GlobalInvocationId
  LocalInvocationId
  LocalInvocationIndex
  WorkGroupId
  WorkGroupSize
  NumWorkGroups
  NumSubgroups
  SubgroupId
  SubgroupSize
  SubgroupInvocationId
  MeshTaskSize
  CullPrimitive
  PointIndex
  LineIndices
  TriangleIndices
  VertexCount
  Vertices
  PrimitiveCount
  Primitives
  RayInvocationId
  NumRayInvocations
  InstanceCustomData
  GeometryIndex
  WorldRayOrigin
  WorldRayDirection
  ObjectRayOrigin
  ObjectRayDirection
  RayTmin
  RayTCurrentMax
  ObjectToWorld
  WorldToObject
  HitKind
} derive(Eq, Debug)

///|
pub enum VectorSize {
  Bi
  Tri
  Quad
} derive(Eq, Debug)

///|
pub fn VectorSize::width(self : VectorSize) -> Int {
  match self {
    Bi => 2
    Tri => 3
    Quad => 4
  }
}

///|
pub enum CooperativeSize {
  Eight
  Sixteen
} derive(Eq, Debug)

///|
pub enum ScalarKind {
  Sint
  Uint
  Float
  Bool
  AbstractInt
  AbstractFloat
} derive(Eq, Debug)

///|
pub enum CooperativeRole {
  A
  B
  C
} derive(Eq, Debug)

///|
pub(all) struct Scalar {
  kind : ScalarKind
  width : Int
} derive(Eq, Debug)

///|
pub fn Scalar::new(kind : ScalarKind, width : Int) -> Scalar {
  Scalar::{ kind, width }
}

///|
pub enum ArraySize {
  Constant(Int)
  Pending(Handle)
  Dynamic
} derive(Eq, Debug)

///|
pub enum Interpolation {
  Perspective
  Linear
  Flat
  PerVertex
} derive(Eq, Debug)

///|
pub enum Sampling {
  Center
  Centroid
  Sample
  First
  Either
} derive(Eq, Debug)

///|
pub enum ImageDimension {
  D1
  D2
  D3
  Cube
} derive(Eq, Debug)

///|
pub enum StorageFormat {
  R8Unorm
  R8Snorm
  R8Uint
  R8Sint
  R16Uint
  R16Sint
  R16Float
  Rg8Unorm
  Rg8Snorm
  Rg8Uint
  Rg8Sint
  R32Uint
  R32Sint
  R32Float
  Rg16Uint
  Rg16Sint
  Rg16Float
  Rgba8Unorm
  Rgba8Snorm
  Rgba8Uint
  Rgba8Sint
  Bgra8Unorm
  Rgb10a2Uint
  Rgb10a2Unorm
  Rg11b10Ufloat
  R64Uint
  Rg32Uint
  Rg32Sint
  Rg32Float
  Rgba16Uint
  Rgba16Sint
  Rgba16Float
  Rgba32Uint
  Rgba32Sint
  Rgba32Float
  R16Unorm
  R16Snorm
  Rg16Unorm
  Rg16Snorm
  Rgba16Unorm
  Rgba16Snorm
} derive(Eq, Debug)

///|
pub enum ImageClass {
  Sampled(ScalarKind, Bool)
  Depth(Bool)
  External
  Storage(StorageFormat, StorageAccess)
} derive(Eq, Debug)

///|
pub enum Binding {
  BuiltIn(BuiltIn)
  Location(Int, Interpolation?, Sampling?, Int?, Bool)
} derive(Eq, Debug)

///|
pub(all) struct StructMember {
  name : String?
  ty : Handle
  binding : Binding?
  offset : Int
} derive(Eq, Debug)

///|
pub(all) struct Type {
  name : String?
  inner : TypeInner
} derive(Eq, Debug)

///|
pub enum TypeInner {
  Scalar(Scalar)
  Vector(VectorSize, Scalar)
  Matrix(VectorSize, VectorSize, Scalar)
  CooperativeMatrix(CooperativeSize, CooperativeSize, Scalar, CooperativeRole)
  Atomic(Scalar)
  Pointer(Handle, AddressSpace)
  ValuePointer(VectorSize?, Scalar, AddressSpace)
  Array(Handle, ArraySize, Int)
  Struct(Array[StructMember], Int)
  Image(ImageDimension, Bool, ImageClass)
  Sampler(Bool)
  AccelerationStructure(Bool)
  RayQuery(Bool)
  BindingArray(Handle, ArraySize)
} derive(Eq, Debug)

///|
pub enum PredeclaredType {
  AtomicCompareExchangeWeakResult(Scalar)
  ModfResult(VectorSize?, Scalar)
  FrexpResult(VectorSize?, Scalar)
} derive(Eq, Debug)

///|
pub(all) struct SpecialTypes {
  ray_desc : Handle?
  ray_intersection : Handle?
  ray_vertex_return : Handle?
  external_texture_params : Handle?
  external_texture_transfer_function : Handle?
  predeclared_types : Array[(PredeclaredType, Handle)]
} derive(Eq, Debug)

///|
pub fn SpecialTypes::new() -> SpecialTypes {
  SpecialTypes::{
    ray_desc: None,
    ray_intersection: None,
    ray_vertex_return: None,
    external_texture_params: None,
    external_texture_transfer_function: None,
    predeclared_types: [],
  }
}
