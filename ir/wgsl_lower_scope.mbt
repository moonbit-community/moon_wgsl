///|

///|
priv enum WgslIrGeneratedImportLocalSpellingMode {
  AllGeneratedImportLocalSpelling
  RootGeneratedImportLocalSpelling
  NoGeneratedImportLocalSpelling
}

///|
priv struct WgslIrLazyLocalConstant {
  expr_ref : @ast.WgslExprRef
  explicit_ty : Handle?
  normalized : Expression?
}

///|
priv enum WgslIrLocalConstantArenaPlacement {
  DeclarationArenaLocalConstant
  UseSiteLazyLocalConstant
}

///|
priv enum WgslIrLocalValue {
  LazyConstant(WgslIrLazyLocalConstant)
  ExpressionAlias(Handle)
}

///|
priv struct WgslIrLocalValueCell {
  mut value : WgslIrLocalValue
}

///|
priv struct WgslIrFunctionScope {
  arguments : Map[String, Int]
  argument_expressions : Map[String, Handle]
  locals : Map[String, Handle]
  local_constants : Map[String, WgslIrLocalValueCell]
  local_pointer_expressions : Map[String, Handle]
  argument_pointer_expressions : Map[String, Handle]
  global_pointer_expressions : Map[String, Handle]
  mut visible_rel_path : String
  mut generated_import_local_spelling : WgslIrGeneratedImportLocalSpellingMode
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
    visible_rel_path: "",
    generated_import_local_spelling: AllGeneratedImportLocalSpelling,
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
fn wgsl_ir_copy_string_local_constant_map(
  source : Map[String, WgslIrLocalValueCell],
) -> Map[String, WgslIrLocalValueCell] {
  let copied : Map[String, WgslIrLocalValueCell] = Map([])
  for entry in source.iter() {
    let (key, value) = entry
    copied.set(key, value)
  }
  copied
}

///|
fn wgsl_ir_snapshot_local_constant_values(
  source : Map[String, WgslIrLocalValueCell],
) -> Map[String, WgslIrLocalValue] {
  let snapshot : Map[String, WgslIrLocalValue] = Map([])
  for entry in source.iter() {
    let (key, cell) = entry
    snapshot.set(key, cell.value)
  }
  snapshot
}

///|
fn wgsl_ir_restore_local_constant_values(
  source : Map[String, WgslIrLocalValueCell],
  snapshot : Map[String, WgslIrLocalValue],
) -> Unit {
  for entry in snapshot.iter() {
    let (key, value) = entry
    match source.get(key) {
      Some(cell) => cell.value = value
      None => ()
    }
  }
}

///|
fn WgslIrFunctionScope::child(
  self : WgslIrFunctionScope,
) -> WgslIrFunctionScope {
  WgslIrFunctionScope::{
    arguments: wgsl_ir_copy_string_int_map(self.arguments),
    argument_expressions: self.argument_expressions,
    locals: wgsl_ir_copy_string_handle_map(self.locals),
    local_constants: wgsl_ir_copy_string_local_constant_map(
      self.local_constants,
    ),
    local_pointer_expressions: wgsl_ir_copy_string_handle_map(
      self.local_pointer_expressions,
    ),
    argument_pointer_expressions: self.argument_pointer_expressions,
    global_pointer_expressions: self.global_pointer_expressions,
    visible_rel_path: self.visible_rel_path,
    generated_import_local_spelling: self.generated_import_local_spelling,
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
  cache : Bool,
) -> Handle {
  if cache {
    match self.global_pointer_expressions.get(name) {
      Some(handle) => return handle
      None => {
        let handle = function.expressions.append(
          Expression::GlobalVariable(global_handle),
        )
        self.global_pointer_expressions.set(name, handle)
        return handle
      }
    }
  }
  function.expressions.append(Expression::GlobalVariable(global_handle))
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
