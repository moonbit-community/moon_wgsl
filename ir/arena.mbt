///|
pub(all) struct TypeArena {
  items : Array[Type]
} derive(Eq, Debug)

///|
pub fn TypeArena::new() -> TypeArena {
  TypeArena::{ items: [] }
}

///|
pub fn TypeArena::append(self : TypeArena, item : Type) -> Handle {
  let handle = Handle::new(self.items.length())
  self.items.push(item)
  handle
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
pub fn ConstantArena::new() -> ConstantArena {
  ConstantArena::{ items: [] }
}

///|
pub fn ConstantArena::append(self : ConstantArena, item : Constant) -> Handle {
  let handle = Handle::new(self.items.length())
  self.items.push(item)
  handle
}

///|
pub(all) struct OverrideArena {
  items : Array[Override]
} derive(Eq, Debug)

///|
pub fn OverrideArena::new() -> OverrideArena {
  OverrideArena::{ items: [] }
}

///|
pub fn OverrideArena::append(self : OverrideArena, item : Override) -> Handle {
  let handle = Handle::new(self.items.length())
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
pub fn GlobalVariableArena::new() -> GlobalVariableArena {
  GlobalVariableArena::{ items: [] }
}

///|
pub fn GlobalVariableArena::append(
  self : GlobalVariableArena,
  item : GlobalVariable,
) -> Handle {
  let handle = Handle::new(self.items.length())
  self.items.push(item)
  handle
}

///|
pub(all) struct LocalVariableArena {
  items : Array[LocalVariable]
} derive(Eq, Debug)

///|
pub fn LocalVariableArena::new() -> LocalVariableArena {
  LocalVariableArena::{ items: [] }
}

///|
pub fn LocalVariableArena::append(
  self : LocalVariableArena,
  item : LocalVariable,
) -> Handle {
  let handle = Handle::new(self.items.length())
  self.items.push(item)
  handle
}

///|
pub(all) struct ExpressionArena {
  items : Array[Expression]
} derive(Eq, Debug)

///|
pub fn ExpressionArena::new() -> ExpressionArena {
  ExpressionArena::{ items: [] }
}

///|
pub fn ExpressionArena::append(
  self : ExpressionArena,
  item : Expression,
) -> Handle {
  let handle = Handle::new(self.items.length())
  self.items.push(item)
  handle
}

///|
pub(all) struct FunctionArena {
  items : Array[Function]
} derive(Eq, Debug)

///|
pub fn FunctionArena::new() -> FunctionArena {
  FunctionArena::{ items: [] }
}

///|
pub fn FunctionArena::append(self : FunctionArena, item : Function) -> Handle {
  let handle = Handle::new(self.items.length())
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
pub fn DiagnosticFilterArena::new() -> DiagnosticFilterArena {
  DiagnosticFilterArena::{ items: [] }
}

///|
pub fn DiagnosticFilterArena::append(
  self : DiagnosticFilterArena,
  item : DiagnosticFilterNode,
) -> Handle {
  let handle = Handle::new(self.items.length())
  self.items.push(item)
  handle
}
