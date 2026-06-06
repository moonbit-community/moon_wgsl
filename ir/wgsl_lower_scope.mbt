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
  normalized : WgslIrLazyLocalConstantExpression?
}

///|
priv struct WgslIrLazyLocalConstantExpression {
  expression : Expression
  origin : ExpressionOrigin
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
priv enum WgslIrLocalValueSource {
  LocalLet
  LocalConst
} derive(Eq)

///|
priv struct WgslIrLocalValueCell {
  mut value : WgslIrLocalValue
  source : WgslIrLocalValueSource
}

///|
fn wgsl_ir_local_let_value_cell(
  value : WgslIrLocalValue,
) -> WgslIrLocalValueCell {
  { value, source: LocalLet }
}

///|
fn wgsl_ir_local_const_value_cell(
  value : WgslIrLocalValue,
) -> WgslIrLocalValueCell {
  { value, source: LocalConst }
}

///|
priv struct WgslIrPendingGlobalPointerExpressions {
  handles : Array[Handle]
  mut index : Int
}

///|
priv struct WgslIrFunctionScope {
  arguments : Map[String, Int]
  argument_expressions : Map[String, Handle]
  locals : Map[String, Handle]
  predeclared_source_locals : Map[String, Handle]
  source_local_const_initializer_expressions : Map[String, Handle]
  runtime_source_local_const_initializer_expressions : Map[String, Handle]
  local_constants : Map[String, WgslIrLocalValueCell]
  local_pointer_expressions : Map[String, Handle]
  argument_pointer_expressions : Map[String, Handle]
  global_pointer_expressions : Map[String, Handle]
  pending_global_pointer_expressions : Map[
    String,
    WgslIrPendingGlobalPointerExpressions,
  ]
  mut source_let_initializer_preserve_depth : Int
  mut compound_assignment_rhs_depth : Int
  mut pending_compound_assignment_rhs_local_root : String?
  loop_depth : Int
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
  {
    arguments: Map([]),
    argument_expressions: Map([]),
    locals: Map([]),
    predeclared_source_locals: Map([]),
    source_local_const_initializer_expressions: Map([]),
    runtime_source_local_const_initializer_expressions: Map([]),
    local_constants: Map([]),
    local_pointer_expressions: Map([]),
    argument_pointer_expressions: Map([]),
    global_pointer_expressions: Map([]),
    pending_global_pointer_expressions: Map([]),
    source_let_initializer_preserve_depth: 0,
    compound_assignment_rhs_depth: 0,
    pending_compound_assignment_rhs_local_root: None,
    loop_depth: 0,
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
fn wgsl_ir_local_declaration_key(
  local_decl : @ast.WgslLocalDeclaration,
) -> String {
  let name = local_decl.name()
  "\{name.start()}:\{name.end()}:\{name.name()}"
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
  {
    arguments: wgsl_ir_copy_string_int_map(self.arguments),
    argument_expressions: self.argument_expressions,
    locals: wgsl_ir_copy_string_handle_map(self.locals),
    predeclared_source_locals: self.predeclared_source_locals,
    source_local_const_initializer_expressions: self.source_local_const_initializer_expressions,
    runtime_source_local_const_initializer_expressions: self.runtime_source_local_const_initializer_expressions,
    local_constants: wgsl_ir_copy_string_local_constant_map(
      self.local_constants,
    ),
    local_pointer_expressions: wgsl_ir_copy_string_handle_map(
      self.local_pointer_expressions,
    ),
    argument_pointer_expressions: self.argument_pointer_expressions,
    global_pointer_expressions: self.global_pointer_expressions,
    pending_global_pointer_expressions: self.pending_global_pointer_expressions,
    source_let_initializer_preserve_depth: self.source_let_initializer_preserve_depth,
    compound_assignment_rhs_depth: self.compound_assignment_rhs_depth,
    pending_compound_assignment_rhs_local_root: self.pending_compound_assignment_rhs_local_root,
    loop_depth: self.loop_depth,
    visible_rel_path: self.visible_rel_path,
    generated_import_local_spelling: self.generated_import_local_spelling,
  }
}

///|
fn WgslIrFunctionScope::loop_child(
  self : WgslIrFunctionScope,
) -> WgslIrFunctionScope {
  let child = self.child()
  { ..child, loop_depth: self.loop_depth + 1 }
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
      let handle = function.expressions.append(FunctionArgument(index))
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
      let handle = match
        wgsl_ir_find_local_pointer_expression(function, local_handle) {
        Some(existing) => existing
        None => function.expressions.append(LocalVariable(local_handle))
      }
      self.local_pointer_expressions.set(name, handle)
      handle
    }
  }
}

///|
fn WgslIrFunctionScope::predeclare_local_pointer_expression(
  self : WgslIrFunctionScope,
  name : String,
  local_handle : Handle,
  function : Function,
) -> Handle {
  let handle = function.expressions.append(LocalVariable(local_handle))
  self.local_pointer_expressions.set(name, handle)
  handle
}

///|
fn wgsl_ir_find_local_pointer_expression(
  function : Function,
  local_handle : Handle,
) -> Handle? {
  for index, expression in function.expressions.items {
    if expression == LocalVariable(local_handle) {
      return Some(Handle(index))
    }
  }
  None
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
        let handle = function.expressions.append(GlobalVariable(global_handle))
        self.global_pointer_expressions.set(name, handle)
        return handle
      }
    }
  }
  function.expressions.append(GlobalVariable(global_handle))
}

///|
fn WgslIrFunctionScope::predeclare_global_pointer_expression(
  self : WgslIrFunctionScope,
  name : String,
  global_handle : Handle,
  function : Function,
) -> Handle {
  let handle = function.expressions.append(GlobalVariable(global_handle))
  match self.pending_global_pointer_expressions.get(name) {
    Some(queue) => queue.handles.push(handle)
    None =>
      self.pending_global_pointer_expressions.set(name, {
        handles: [handle],
        index: 0,
      })
  }
  handle
}

///|
fn WgslIrFunctionScope::consume_pending_global_pointer_expression(
  self : WgslIrFunctionScope,
  name : String,
) -> Handle? {
  match self.pending_global_pointer_expressions.get(name) {
    Some(queue) =>
      if queue.index < queue.handles.length() {
        let handle = queue.handles[queue.index]
        queue.index += 1
        if queue.index == queue.handles.length() {
          ignore(self.pending_global_pointer_expressions.remove(name))
        }
        Some(handle)
      } else {
        ignore(self.pending_global_pointer_expressions.remove(name))
        None
      }
    None => None
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
