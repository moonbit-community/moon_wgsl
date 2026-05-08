///|
pub(all) struct TypeArena {
  items : Array[Type]
} derive(Eq, Debug)

///|
pub fn TypeArena::TypeArena() -> TypeArena {
  TypeArena::{ items: [] }
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
pub(all) struct ConstantArena {
  items : Array[Constant]
} derive(Eq, Debug)

///|
pub fn ConstantArena::ConstantArena() -> ConstantArena {
  ConstantArena::{ items: [] }
}

///|
pub fn ConstantArena::append(self : ConstantArena, item : Constant) -> Handle {
  let handle = Handle::Handle(self.items.length())
  self.items.push(item)
  handle
}

///|
pub(all) struct OverrideArena {
  items : Array[Override]
} derive(Eq, Debug)

///|
pub fn OverrideArena::OverrideArena() -> OverrideArena {
  OverrideArena::{ items: [] }
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
pub(all) struct GlobalVariableArena {
  items : Array[GlobalVariable]
} derive(Eq, Debug)

///|
pub fn GlobalVariableArena::GlobalVariableArena() -> GlobalVariableArena {
  GlobalVariableArena::{ items: [] }
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
pub(all) struct LocalVariableArena {
  items : Array[LocalVariable]
} derive(Eq, Debug)

///|
pub fn LocalVariableArena::LocalVariableArena() -> LocalVariableArena {
  LocalVariableArena::{ items: [] }
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
pub(all) struct ExpressionArena {
  items : Array[Expression]
} derive(Eq, Debug)

///|
pub fn ExpressionArena::ExpressionArena() -> ExpressionArena {
  ExpressionArena::{ items: [] }
}

///|
pub fn ExpressionArena::append(
  self : ExpressionArena,
  item : Expression,
) -> Handle {
  let handle = Handle::Handle(self.items.length())
  self.items.push(item)
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
pub(all) struct FunctionArena {
  items : Array[Function]
} derive(Eq, Debug)

///|
pub fn FunctionArena::FunctionArena() -> FunctionArena {
  FunctionArena::{ items: [] }
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
pub(all) struct DiagnosticFilterArena {
  items : Array[DiagnosticFilterNode]
} derive(Eq, Debug)

///|
pub fn DiagnosticFilterArena::DiagnosticFilterArena() -> DiagnosticFilterArena {
  DiagnosticFilterArena::{ items: [] }
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
