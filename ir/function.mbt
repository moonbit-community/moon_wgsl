///|
pub enum SwitchValue {
  I32(Int)
  U32(UInt)
  Default
} derive(Eq, Debug)

///|
pub(all) struct SwitchCase {
  value : SwitchValue
  body : Block
  fall_through : Bool
} derive(Eq, Debug)

///|
pub enum RayQueryFunction {
  Initialize(Handle, Handle)
  Proceed(Handle)
  GenerateIntersection(Handle)
  ConfirmIntersection
  Terminate
} derive(Eq, Debug)

///|
pub enum RayPipelineFunction {
  TraceRay(Handle, Handle, Handle)
} derive(Eq, Debug)

///|
pub enum Statement {
  Declare(Handle)
  Emit(HandleRange)
  Block(Block)
  If(Handle, Block, Block)
  Switch(Handle, Array[SwitchCase])
  Loop(Block, Block, Handle?)
  Break
  Continue
  Return(Handle?)
  Kill
  ConstAssert(Handle)
  ControlBarrier(Barrier)
  MemoryBarrier(Barrier)
  Store(Handle, Handle)
  ImageStore(Handle, Handle, Handle?, Handle)
  Atomic(Handle, AtomicFunction, Handle, Handle?)
  ImageAtomic(Handle, Handle, Handle?, AtomicFunction, Handle)
  WorkGroupUniformLoad(Handle, Handle)
  Call(Handle, Array[Handle], Handle?)
  RayQuery(Handle, RayQueryFunction)
  RayPipelineFunction(RayPipelineFunction)
  SubgroupBallot(Handle, Handle?)
  SubgroupGather(GatherMode, Handle, Handle)
  SubgroupCollectiveOperation(
    SubgroupOperation,
    CollectiveOperation,
    Handle,
    Handle
  )
  CooperativeStore(Handle, CooperativeData)
} derive(Eq, Debug)

///|
pub(all) struct Block {
  statements : Array[Statement]
} derive(Eq, Debug)

///|
pub fn Block::Block() -> Block {
  Block::{ statements: [] }
}

///|
pub fn Block::push(self : Block, statement : Statement) -> Unit {
  self.statements.push(statement)
}

///|
pub(all) struct FunctionArgument {
  name : String?
  ty : Handle
  binding : Binding?
} derive(Eq, Debug)

///|
pub(all) struct FunctionResult {
  ty : Handle
  binding : Binding?
} derive(Eq, Debug)

///|
pub(all) struct NamedExpression {
  handle : Handle
  name : String
} derive(Eq, Debug)

///|
pub(all) struct Function {
  name : String?
  generated_import : Bool
  arguments : Array[FunctionArgument]
  result : FunctionResult?
  local_variables : LocalVariableArena
  expressions : ExpressionArena
  named_expressions : Array[NamedExpression]
  body : Block
  diagnostic_filter_leaf : Handle?
} derive(Eq, Debug)

///|
pub fn Function::Function(name : String?) -> Function {
  Function::{
    name,
    generated_import: false,
    arguments: [],
    result: None,
    local_variables: LocalVariableArena(),
    expressions: ExpressionArena(),
    named_expressions: [],
    body: Block::Block(),
    diagnostic_filter_leaf: None,
  }
}

///|
pub(all) struct EntryPoint {
  name : String
  stage : ShaderStage
  early_depth_test : EarlyDepthTest?
  workgroup_size : Array[Int]
  workgroup_size_overrides : Array[Handle?]?
  function : Function
  mesh_info : MeshStageInfo?
  task_payload : Handle?
  incoming_ray_payload : Handle?
} derive(Eq, Debug)

///|
pub(all) struct MeshStageInfo {
  topology : MeshOutputTopology
  max_vertices : Int
  max_vertices_override : Handle?
  max_primitives : Int
  max_primitives_override : Handle?
  vertex_output_type : Handle
  primitive_output_type : Handle
  output_variable : Handle
} derive(Eq, Debug)

///|
pub enum MeshOutputTopology {
  Points
  Lines
  Triangles
} derive(Eq, Debug)
