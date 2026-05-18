///|
priv struct WgslIrFunctionScope {
  arguments : Map[String, Int]
  argument_expressions : Map[String, Handle]
  locals : Map[String, Handle]
  local_constants : Map[String, Handle]
  local_pointer_expressions : Map[String, Handle]
  argument_pointer_expressions : Map[String, Handle]
  global_pointer_expressions : Map[String, Handle]
  hidden_temporary_name_indices : @set.Set[Int]
  mut projected_temporary_name_offset : Int
  mut allow_generated_import_local_spelling : Bool
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
    arguments: Map([]),
    argument_expressions: Map([]),
    locals: Map([]),
    local_constants: Map([]),
    local_pointer_expressions: Map([]),
    argument_pointer_expressions: Map([]),
    global_pointer_expressions: Map([]),
    hidden_temporary_name_indices: @set.Set([]),
    projected_temporary_name_offset: 0,
    allow_generated_import_local_spelling: true,
  }
}

///|
fn wgsl_ir_copy_string_int_map(source : Map[String, Int]) -> Map[String, Int] {
  let copied : Map[String, Int] = Map([])
  for entry in source.iter() {
    let (key, value) = entry
    copied.set(key, value)
  }
  copied
}

///|
fn wgsl_ir_copy_string_handle_map(
  source : Map[String, Handle],
) -> Map[String, Handle] {
  let copied : Map[String, Handle] = Map([])
  for entry in source.iter() {
    let (key, value) = entry
    copied.set(key, value)
  }
  copied
}

///|
fn wgsl_ir_copy_int_set(source : @set.Set[Int]) -> @set.Set[Int] {
  let copied : @set.Set[Int] = @set.Set([])
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
    argument_expressions: wgsl_ir_copy_string_handle_map(
      self.argument_expressions,
    ),
    locals: wgsl_ir_copy_string_handle_map(self.locals),
    local_constants: wgsl_ir_copy_string_handle_map(self.local_constants),
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
    projected_temporary_name_offset: self.projected_temporary_name_offset,
    allow_generated_import_local_spelling: self.allow_generated_import_local_spelling,
  }
}

///|
fn WgslIrFunctionScope::sync_child_counters(
  self : WgslIrFunctionScope,
  child : WgslIrFunctionScope,
) -> Unit {
  if child.projected_temporary_name_offset >
    self.projected_temporary_name_offset {
    self.projected_temporary_name_offset = child.projected_temporary_name_offset
  }
}

///|
fn WgslIrFunctionScope::argument_expression(
  self : WgslIrFunctionScope,
  name : String,
  index : Int,
  function : Function,
) -> Handle {
  match self.argument_expressions.get(name) {
    Some(handle) => handle
    None => {
      let handle = function.expressions.append(
        Expression::FunctionArgument(index),
      )
      self.argument_expressions.set(name, handle)
      handle
    }
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
      let handle = self.argument_expression(name, argument_index, function)
      self.argument_pointer_expressions.set(name, handle)
      handle
    }
  }
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
fn WgslIrFunctionScope::record_projected_temporary_expression(
  self : WgslIrFunctionScope,
  slots : Int,
) -> Unit {
  self.projected_temporary_name_offset += slots
}

///|
