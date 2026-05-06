///|
pub(all) struct Module {
  directives : Array[String]
  types : TypeArena
  special_types : SpecialTypes
  constants : ConstantArena
  overrides : OverrideArena
  global_variables : GlobalVariableArena
  global_expressions : ExpressionArena
  functions : FunctionArena
  entry_points : Array[EntryPoint]
  diagnostic_filters : DiagnosticFilterArena
  diagnostic_filter_leaf : Handle?
  doc_comments : DocComments?
} derive(Eq, Debug)

///|
pub fn Module::new() -> Module {
  Module::{
    directives: [],
    types: TypeArena::new(),
    special_types: SpecialTypes::new(),
    constants: ConstantArena::new(),
    overrides: OverrideArena::new(),
    global_variables: GlobalVariableArena::new(),
    global_expressions: ExpressionArena::new(),
    functions: FunctionArena::new(),
    entry_points: [],
    diagnostic_filters: DiagnosticFilterArena::new(),
    diagnostic_filter_leaf: None,
    doc_comments: None,
  }
}

///|
pub fn Module::append_directive(self : Module, directive : String) -> Unit {
  for existing in self.directives {
    if existing == directive {
      return
    }
  }
  self.directives.push(directive)
}

///|
pub fn Module::append_type(self : Module, ty : Type) -> Handle {
  self.types.append(ty)
}

///|
pub fn Module::append_global_expression(
  self : Module,
  expression : Expression,
) -> Handle {
  self.global_expressions.append(expression)
}

///|
pub fn Module::append_constant(self : Module, constant : Constant) -> Handle {
  self.constants.append(constant)
}

///|
pub fn Module::append_override(self : Module, override_ : Override) -> Handle {
  self.overrides.append(override_)
}

///|
pub fn Module::set_override(
  self : Module,
  handle : Handle,
  override_ : Override,
) -> Unit {
  self.overrides.set(handle, override_)
}

///|
pub fn Module::append_global_variable(
  self : Module,
  global : GlobalVariable,
) -> Handle {
  self.global_variables.append(global)
}

///|
pub fn Module::append_function(self : Module, function : Function) -> Handle {
  self.functions.append(function)
}

///|
pub fn Module::set_function(
  self : Module,
  handle : Handle,
  function : Function,
) -> Unit {
  self.functions.set(handle, function)
}

///|
pub fn Module::append_entry_point(
  self : Module,
  entry_point : EntryPoint,
) -> Unit {
  self.entry_points.push(entry_point)
}
