///|
priv struct WgslIrFunctionScope {
  arguments : @hashmap.HashMap[String, Int]
  locals : @hashmap.HashMap[String, Handle]
  local_constants : @hashmap.HashMap[String, Handle]
  local_inline_lets : @hashmap.HashMap[String, Handle]
  local_pointer_expressions : @hashmap.HashMap[String, Handle]
  argument_pointer_expressions : @hashmap.HashMap[String, Handle]
  global_pointer_expressions : @hashmap.HashMap[String, Handle]
  hidden_temporary_name_indices : @hashset.HashSet[Int]
  mut allow_local_inline_lets : Bool
  mut temporary_index : Int
}

///|
priv struct WgslIrExprTokenParser {
  tokens : Array[@ast.WgslExprToken]
  mut index : Int
  mut failed : Bool
}

///|
fn WgslIrFunctionScope::WgslIrFunctionScope() -> WgslIrFunctionScope {
  WgslIrFunctionScope::{
    arguments: @hashmap.HashMap([]),
    locals: @hashmap.HashMap([]),
    local_constants: @hashmap.HashMap([]),
    local_inline_lets: @hashmap.HashMap([]),
    local_pointer_expressions: @hashmap.HashMap([]),
    argument_pointer_expressions: @hashmap.HashMap([]),
    global_pointer_expressions: @hashmap.HashMap([]),
    hidden_temporary_name_indices: @hashset.HashSet([]),
    allow_local_inline_lets: true,
    temporary_index: 0,
  }
}

///|
fn wgsl_ir_copy_string_int_map(
  source : @hashmap.HashMap[String, Int],
) -> @hashmap.HashMap[String, Int] {
  let copied : @hashmap.HashMap[String, Int] = @hashmap.HashMap([])
  for entry in source.iter() {
    let (key, value) = entry
    copied.set(key, value)
  }
  copied
}

///|
fn wgsl_ir_copy_string_handle_map(
  source : @hashmap.HashMap[String, Handle],
) -> @hashmap.HashMap[String, Handle] {
  let copied : @hashmap.HashMap[String, Handle] = @hashmap.HashMap([])
  for entry in source.iter() {
    let (key, value) = entry
    copied.set(key, value)
  }
  copied
}

///|
fn wgsl_ir_copy_int_set(
  source : @hashset.HashSet[Int],
) -> @hashset.HashSet[Int] {
  let copied : @hashset.HashSet[Int] = @hashset.HashSet([])
  for value in source.iter() {
    copied.add(value)
  }
  copied
}

///|
fn WgslIrFunctionScope::child(
  self : WgslIrFunctionScope,
) -> WgslIrFunctionScope {
  WgslIrFunctionScope::{
    arguments: wgsl_ir_copy_string_int_map(self.arguments),
    locals: wgsl_ir_copy_string_handle_map(self.locals),
    local_constants: wgsl_ir_copy_string_handle_map(self.local_constants),
    local_inline_lets: wgsl_ir_copy_string_handle_map(self.local_inline_lets),
    local_pointer_expressions: wgsl_ir_copy_string_handle_map(
      self.local_pointer_expressions,
    ),
    argument_pointer_expressions: wgsl_ir_copy_string_handle_map(
      self.argument_pointer_expressions,
    ),
    global_pointer_expressions: wgsl_ir_copy_string_handle_map(
      self.global_pointer_expressions,
    ),
    hidden_temporary_name_indices: wgsl_ir_copy_int_set(
      self.hidden_temporary_name_indices,
    ),
    allow_local_inline_lets: self.allow_local_inline_lets,
    temporary_index: self.temporary_index,
  }
}

///|
fn WgslIrFunctionScope::sync_child_counters(
  self : WgslIrFunctionScope,
  child : WgslIrFunctionScope,
) -> Unit {
  if child.temporary_index > self.temporary_index {
    self.temporary_index = child.temporary_index
  }
}

///|
fn WgslIrFunctionScope::local_pointer_expression(
  self : WgslIrFunctionScope,
  name : String,
  local_handle : Handle,
  function : Function,
) -> Handle {
  match self.local_pointer_expressions.get(name) {
    Some(handle) => handle
    None => {
      let handle = function.expressions.append(
        Expression::LocalVariable(local_handle),
      )
      self.local_pointer_expressions.set(name, handle)
      handle
    }
  }
}

///|
fn WgslIrFunctionScope::global_pointer_expression(
  self : WgslIrFunctionScope,
  name : String,
  global_handle : Handle,
  function : Function,
) -> Handle {
  match self.global_pointer_expressions.get(name) {
    Some(handle) => handle
    None => {
      let handle = function.expressions.append(
        Expression::GlobalVariable(global_handle),
      )
      self.global_pointer_expressions.set(name, handle)
      handle
    }
  }
}

///|
fn WgslIrFunctionScope::argument_pointer_expression(
  self : WgslIrFunctionScope,
  name : String,
  argument_index : Int,
  function : Function,
) -> Handle {
  match self.argument_pointer_expressions.get(name) {
    Some(handle) => handle
    None => {
      let handle = function.expressions.append(
        Expression::FunctionArgument(argument_index),
      )
      self.argument_pointer_expressions.set(name, handle)
      handle
    }
  }
}

///|
fn WgslIrFunctionScope::next_temporary_name(
  self : WgslIrFunctionScope,
) -> String {
  let name = "_e\{self.temporary_index}"
  self.temporary_index = self.temporary_index + 1
  name
}

///|
fn WgslIrFunctionScope::hide_temporary_name_indices(
  self : WgslIrFunctionScope,
  start : Int,
  end : Int,
) -> Unit {
  for index in start..<end {
    self.hidden_temporary_name_indices.add(index)
  }
}

///|
fn WgslIrFunctionScope::is_direct_local_inline_let_value(
  self : WgslIrFunctionScope,
  handle : Handle,
) -> Bool {
  for entry in self.local_inline_lets.iter() {
    let (_, value) = entry
    if value == handle {
      return true
    }
  }
  false
}
