///|
pub(all) enum ConservativeDepth {
  GreaterEqual
  LessEqual
  Unchanged
} derive(Eq, Debug)

///|
pub(all) enum EarlyDepthTest {
  Force
  Allow(ConservativeDepth)
} derive(Eq, Debug)

///|
pub(all) enum ShaderStage {
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
pub(all) enum AddressSpace {
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
pub(all) enum BuiltIn {
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
pub(all) enum VectorSize {
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
pub(all) enum CooperativeSize {
  Eight
  Sixteen
} derive(Eq, Debug)

///|
pub(all) enum ScalarKind {
  Sint
  Uint
  Float
  Bool
  AbstractInt
  AbstractFloat
} derive(Eq, Debug)

///|
pub(all) enum CooperativeRole {
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
pub fn Scalar::Scalar(kind : ScalarKind, width : Int) -> Scalar {
  { kind, width, }
}

///|
pub(all) enum ArraySize {
  Constant(Int)
  Pending(Handle)
  Dynamic
} derive(Eq, Debug)

///|
pub(all) enum Interpolation {
  Perspective
  Linear
  Flat
  PerVertex
} derive(Eq, Debug)

///|
pub(all) enum Sampling {
  Center
  Centroid
  Sample
  First
  Either
} derive(Eq, Debug)

///|
pub(all) enum ImageDimension {
  D1
  D2
  D3
  Cube
} derive(Eq, Debug)

///|
pub(all) enum StorageFormat {
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
pub(all) enum ImageClass {
  Sampled(ScalarKind, Bool)
  Depth(Bool)
  External
  Storage(StorageFormat, StorageAccess)
} derive(Eq, Debug)

///|
pub(all) enum Binding {
  BuiltIn(BuiltIn)
  Location(Int, Interpolation?, Sampling?, Int?, Bool)
} derive(Eq, Debug)

///|
pub(all) struct StructMember {
  name : String?
  ty : Handle
  binding : Binding?
  offset : Int
  size : Int?
  align : Int?
} derive(Eq, Debug)

///|
pub(all) struct Type {
  name : String?
  inner : TypeInner
} derive(Eq, Debug)

///|
pub(all) enum TypeInner {
  Scalar(Scalar)
  Vector(VectorSize, Scalar)
  Matrix(VectorSize, VectorSize, Scalar)
  CooperativeMatrix(CooperativeSize, CooperativeSize, Scalar, CooperativeRole)
  Atomic(Scalar)
  Pointer(Handle, AddressSpace)
  ValuePointer(VectorSize?, Scalar, AddressSpace)
  Array(Handle, ArraySize, Int)
  Struct(Array[StructMember], Int)
  PredeclaredStruct(Array[StructMember], Int)
  Image(ImageDimension, Bool, ImageClass)
  Sampler(Bool)
  AccelerationStructure(Bool)
  RayQuery(Bool)
  BindingArray(Handle, ArraySize)
} derive(Eq, Debug)

///|
pub(all) enum PredeclaredType {
  AtomicCompareExchangeWeakResult(Scalar)
  ModfResult(VectorSize?, Scalar)
  FrexpResult(VectorSize?, Scalar)
} derive(Eq, Debug)

///|
pub(all) struct SpecialTypes {
  ray_desc : Handle?
  ray_intersection : Handle?
  mut ray_vertex_return : Handle?
  external_texture_params : Handle?
  external_texture_transfer_function : Handle?
  predeclared_types : Array[(PredeclaredType, Handle)]
} derive(Eq, Debug)

///|
pub fn SpecialTypes::SpecialTypes() -> SpecialTypes {
  {
    ray_desc: None,
    ray_intersection: None,
    ray_vertex_return: None,
    external_texture_params: None,
    external_texture_transfer_function: None,
    predeclared_types: [],
  }
}

///|
pub extend AddressSpace with Debug::{to_repr}

///|
pub extend AddressSpace with Eq::{not_equal, equal}

///|
pub extend ArraySize with Debug::{to_repr}

///|
pub extend ArraySize with Eq::{not_equal, equal}

///|
pub extend Binding with Debug::{to_repr}

///|
pub extend Binding with Eq::{not_equal, equal}

///|
pub extend BuiltIn with Debug::{to_repr}

///|
pub extend BuiltIn with Eq::{not_equal, equal}

///|
pub extend ConservativeDepth with Debug::{to_repr}

///|
pub extend ConservativeDepth with Eq::{not_equal, equal}

///|
pub extend CooperativeRole with Debug::{to_repr}

///|
pub extend CooperativeRole with Eq::{not_equal, equal}

///|
pub extend CooperativeSize with Debug::{to_repr}

///|
pub extend CooperativeSize with Eq::{not_equal, equal}

///|
pub extend EarlyDepthTest with Debug::{to_repr}

///|
pub extend EarlyDepthTest with Eq::{not_equal, equal}

///|
pub extend ImageClass with Debug::{to_repr}

///|
pub extend ImageClass with Eq::{not_equal, equal}

///|
pub extend ImageDimension with Debug::{to_repr}

///|
pub extend ImageDimension with Eq::{not_equal, equal}

///|
pub extend Interpolation with Debug::{to_repr}

///|
pub extend Interpolation with Eq::{not_equal, equal}

///|
pub extend PredeclaredType with Debug::{to_repr}

///|
pub extend PredeclaredType with Eq::{not_equal, equal}

///|
pub extend Sampling with Debug::{to_repr}

///|
pub extend Sampling with Eq::{not_equal, equal}

///|
pub extend Scalar with Debug::{to_repr}

///|
pub extend Scalar with Eq::{not_equal, equal}

///|
pub extend ScalarKind with Debug::{to_repr}

///|
pub extend ScalarKind with Eq::{not_equal, equal}

///|
pub extend ShaderStage with Debug::{to_repr}

///|
pub extend ShaderStage with Eq::{not_equal, equal}

///|
pub extend SpecialTypes with Debug::{to_repr}

///|
pub extend SpecialTypes with Eq::{not_equal, equal}

///|
pub extend StorageFormat with Debug::{to_repr}

///|
pub extend StorageFormat with Eq::{not_equal, equal}

///|
pub extend StructMember with Debug::{to_repr}

///|
pub extend StructMember with Eq::{not_equal, equal}

///|
pub extend Type with Debug::{to_repr}

///|
pub extend Type with Eq::{not_equal, equal}

///|
pub extend TypeInner with Debug::{to_repr}

///|
pub extend TypeInner with Eq::{not_equal, equal}

///|
pub extend VectorSize with Debug::{to_repr}

///|
pub extend VectorSize with Eq::{not_equal, equal}
