///|
#derive(Eq, Debug)
pub(all) struct TypeArena {
  items : Array[Type]
}

///|
pub fn TypeArena::TypeArena() -> TypeArena {
  { items: [], }
}

///|
pub fn TypeArena::append(self : TypeArena, item : Type) -> Handle {
  let handle = Handle::Handle(self.items.length())
  self.items.push(item)
  handle
}

///|
pub fn TypeArena::set(self : TypeArena, handle : Handle, item : Type) -> Unit {
  self.items[handle.index()] = item
}

///|
pub fn TypeArena::get(self : TypeArena, handle : Handle) -> Type? {
  self.items.get(handle.index())
}

///|
#derive(Eq, Debug)
pub(all) struct ConstantArena {
  items : Array[Constant]
}

///|
pub fn ConstantArena::ConstantArena() -> ConstantArena {
  { items: [], }
}

///|
pub fn ConstantArena::append(self : ConstantArena, item : Constant) -> Handle {
  let handle = Handle::Handle(self.items.length())
  self.items.push(item)
  handle
}

///|
fn constant_arena_set(
  arena : ConstantArena,
  handle : Handle,
  item : Constant,
) -> Unit {
  arena.items[handle.index()] = item
}

///|
#derive(Eq, Debug)
pub(all) struct OverrideArena {
  items : Array[Override]
}

///|
pub fn OverrideArena::OverrideArena() -> OverrideArena {
  { items: [], }
}

///|
pub fn OverrideArena::append(self : OverrideArena, item : Override) -> Handle {
  let handle = Handle::Handle(self.items.length())
  self.items.push(item)
  handle
}

///|
pub fn OverrideArena::set(
  self : OverrideArena,
  handle : Handle,
  item : Override,
) -> Unit {
  self.items[handle.index()] = item
}

///|
#derive(Eq, Debug)
pub(all) struct GlobalVariableArena {
  items : Array[GlobalVariable]
}

///|
pub fn GlobalVariableArena::GlobalVariableArena() -> GlobalVariableArena {
  { items: [], }
}

///|
pub fn GlobalVariableArena::append(
  self : GlobalVariableArena,
  item : GlobalVariable,
) -> Handle {
  let handle = Handle::Handle(self.items.length())
  self.items.push(item)
  handle
}

///|
pub fn GlobalVariableArena::set(
  self : GlobalVariableArena,
  handle : Handle,
  item : GlobalVariable,
) -> Unit {
  self.items[handle.index()] = item
}

///|
#derive(Eq, Debug)
pub(all) struct LocalVariableArena {
  items : Array[LocalVariable]
}

///|
pub fn LocalVariableArena::LocalVariableArena() -> LocalVariableArena {
  { items: [], }
}

///|
pub fn LocalVariableArena::append(
  self : LocalVariableArena,
  item : LocalVariable,
) -> Handle {
  let handle = Handle::Handle(self.items.length())
  self.items.push(item)
  handle
}

///|
fn LocalVariableArena::set(
  self : LocalVariableArena,
  handle : Handle,
  item : LocalVariable,
) -> Unit {
  self.items[handle.index()] = item
}

///|
#derive(Eq, Debug)
pub(all) enum ExpressionOrigin {
  SourceExpression
  FoldedLocalConstant
  RetainedSourceLetExpression
  SourceLocalConstInitializer
}

///|
#derive(Eq, Debug)
pub(all) struct ExpressionArena {
  items : Array[Expression]
  origins : Array[ExpressionOrigin]
}

///|
pub fn ExpressionArena::ExpressionArena() -> ExpressionArena {
  { items: [], origins: [], }
}

///|
pub fn ExpressionArena::append(
  self : ExpressionArena,
  item : Expression,
) -> Handle {
  self.append_with_origin(item, SourceExpression)
}

///|
fn ExpressionArena::append_with_origin(
  self : ExpressionArena,
  item : Expression,
  origin : ExpressionOrigin,
) -> Handle {
  let handle = Handle::Handle(self.items.length())
  self.items.push(item)
  self.origins.push(origin)
  handle
}

///|
fn ExpressionArena::set(
  self : ExpressionArena,
  handle : Handle,
  item : Expression,
) -> Unit {
  self.items[handle.index()] = item
}

///|
fn ExpressionArena::set_origin(
  self : ExpressionArena,
  handle : Handle,
  origin : ExpressionOrigin,
) -> Unit {
  self.origins[handle.index()] = origin
}

///|
pub fn ExpressionArena::origin(
  self : ExpressionArena,
  handle : Handle,
) -> ExpressionOrigin? {
  self.origins.get(handle.index())
}

///|
fn ExpressionArena::truncate(self : ExpressionArena, length : Int32) -> Unit {
  while self.items.length() > length {
    ignore(self.items.pop())
  }
  while self.origins.length() > length {
    ignore(self.origins.pop())
  }
}

///|
#derive(Eq, Debug)
pub(all) struct FunctionArena {
  items : Array[Function]
}

///|
pub fn FunctionArena::FunctionArena() -> FunctionArena {
  { items: [], }
}

///|
pub fn FunctionArena::append(self : FunctionArena, item : Function) -> Handle {
  let handle = Handle::Handle(self.items.length())
  self.items.push(item)
  handle
}

///|
pub fn FunctionArena::set(
  self : FunctionArena,
  handle : Handle,
  item : Function,
) -> Unit {
  self.items[handle.index()] = item
}

///|
#derive(Eq, Debug)
pub(all) struct DiagnosticFilterArena {
  items : Array[DiagnosticFilterNode]
}

///|
pub fn DiagnosticFilterArena::DiagnosticFilterArena() -> DiagnosticFilterArena {
  { items: [], }
}

///|
pub fn DiagnosticFilterArena::append(
  self : DiagnosticFilterArena,
  item : DiagnosticFilterNode,
) -> Handle {
  let handle = Handle::Handle(self.items.length())
  self.items.push(item)
  handle
}

///|
pub extend ConstantArena with Debug::{to_repr}

///|
pub extend ConstantArena with Eq::{not_equal, equal}

///|
pub extend DiagnosticFilterArena with Debug::{to_repr}

///|
pub extend DiagnosticFilterArena with Eq::{not_equal, equal}

///|
pub extend ExpressionArena with Debug::{to_repr}

///|
pub extend ExpressionArena with Eq::{not_equal, equal}

///|
pub extend ExpressionOrigin with Debug::{to_repr}

///|
pub extend ExpressionOrigin with Eq::{not_equal, equal}

///|
pub extend FunctionArena with Debug::{to_repr}

///|
pub extend FunctionArena with Eq::{not_equal, equal}

///|
pub extend GlobalVariableArena with Debug::{to_repr}

///|
pub extend GlobalVariableArena with Eq::{not_equal, equal}

///|
pub extend LocalVariableArena with Debug::{to_repr}

///|
pub extend LocalVariableArena with Eq::{not_equal, equal}

///|
pub extend OverrideArena with Debug::{to_repr}

///|
pub extend OverrideArena with Eq::{not_equal, equal}

///|
pub extend TypeArena with Debug::{to_repr}

///|
pub extend TypeArena with Eq::{not_equal, equal}
