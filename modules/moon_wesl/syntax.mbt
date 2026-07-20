// Copyright 2026 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
pub(all) struct SyntaxSpan {
  start_line : Int
  end_line : Int
} derive(Eq, Debug)

///|
fn SyntaxSpan::context(self : SyntaxSpan, path : ModulePath) -> String {
  if self.start_line == self.end_line {
    "\{path.to_string()}:\{self.start_line}"
  } else {
    "\{path.to_string()}:\{self.start_line}-\{self.end_line}"
  }
}

///|
fn SyntaxSpan::symbol_context(
  self : SyntaxSpan,
  path : ModulePath,
  name : String,
) -> String {
  "\{name} (\{self.context(path)})"
}

///|
pub(all) enum CondExpression {
  Literal(Bool)
  Feature(String)
  Not(CondExpression)
  And(CondExpression, CondExpression)
  Or(CondExpression, CondExpression)
} derive(Eq, Debug)

///|
pub(all) struct Attribute {
  name : String
  arguments : String?
  argument_exprs : Array[Expression]
  condition_expr : CondExpression?
  span : SyntaxSpan
} derive(Eq, Debug)

///|
fn Attribute::matches(self : Attribute, target : String) -> Bool {
  self.name == target
}

///|
fn Attribute::arguments_text(self : Attribute) -> String? {
  self.arguments
}

///|
fn Attribute::syntax_span(self : Attribute) -> SyntaxSpan {
  self.span
}

///|
fn syntax_has_attribute(attributes : Array[Attribute], target : String) -> Bool {
  for attribute in attributes {
    ignore(attribute.arguments_text())
    ignore(attribute.syntax_span())
    if attribute.matches(target) {
      return true
    }
  }
  false
}

///|
pub(all) struct ImportNode {
  path_segments : Array[String]
  rename : String?
  children : Array[ImportNode]
} derive(Eq, Debug)

///|
fn ImportNode::is_leaf(self : ImportNode) -> Bool {
  self.children.is_empty()
}

///|
pub(all) struct ImportedName {
  export_module_path : ModulePath?
  export_name : String?
  namespace_path : ModulePath
  local_name : String
} derive(Eq, Debug)

///|
fn syntax_concat_segments(
  left : Array[String],
  right : Array[String],
) -> Array[String] {
  let merged : Array[String] = []
  for segment in left {
    merged.push(segment)
  }
  for segment in right {
    merged.push(segment)
  }
  merged
}

///|
fn syntax_resolve_import_module_path(
  current_path : ModulePath,
  module_path_text : String,
) -> ModulePath raise WeslCompileError {
  let raw_module_path = parse_module_path(module_path_text.trim().to_owned()) catch {
    err => raise WeslCompileError::Parse(err.message())
  }
  match raw_module_path.origin {
    Package(name) if raw_module_path.components.is_empty() =>
      return ModulePath::new(Absolute, [name])
    _ => ()
  }
  current_path.join_path(raw_module_path)
}

///|
fn syntax_flatten_import_node(
  current_path : ModulePath,
  context : String,
  prefix : Array[String],
  node : ImportNode,
  items : Array[ImportedName],
) -> Unit raise WeslCompileError {
  let full_path = syntax_concat_segments(prefix, node.path_segments)
  if node.is_leaf() {
    if full_path.length() == 0 {
      raise WeslCompileError::Parse(
        "import path must include a module or item (\{context})",
      )
    }
    let namespace_path = syntax_resolve_import_module_path(
      current_path,
      full_path.join("::"),
    ) catch {
      Parse(reason) => raise WeslCompileError::Parse("\{reason} (\{context})")
      err => raise err
    }
    if namespace_path.components.length() == 0 {
      raise WeslCompileError::Parse(
        "import path must include a module name (\{context})",
      )
    }
    if full_path.length() == 1 {
      items.push(ImportedName::{
        export_module_path: None,
        export_name: None,
        namespace_path,
        local_name: node.rename.unwrap_or(full_path[0]),
      })
      return
    }
    let item_name = full_path[full_path.length() - 1]
    let export_module_path = syntax_resolve_import_module_path(
      current_path,
      full_path[:full_path.length() - 1].join("::"),
    ) catch {
      Parse(reason) => raise WeslCompileError::Parse("\{reason} (\{context})")
      err => raise err
    }
    items.push(ImportedName::{
      export_module_path: Some(export_module_path),
      export_name: Some(item_name),
      namespace_path,
      local_name: node.rename.unwrap_or(item_name),
    })
    return
  }
  for child in node.children {
    syntax_flatten_import_node(current_path, context, full_path, child, items)
  }
}

///|
pub(all) struct ImportStatement {
  span : SyntaxSpan
  attributes : Array[Attribute]
  entries : Array[ImportNode]
  source : String
} derive(Eq, Debug)

///|
fn ImportStatement::is_public(self : ImportStatement) -> Bool {
  syntax_has_attribute(self.attributes, "publish")
}

///|
pub fn ImportStatement::source_text(self : ImportStatement) -> String {
  self.source
}

///|
fn ImportStatement::flatten_items(
  self : ImportStatement,
  current_path : ModulePath,
) -> Array[ImportedName] raise WeslCompileError {
  let items : Array[ImportedName] = []
  let context = self.span.context(current_path)
  for entry in self.entries {
    syntax_flatten_import_node(current_path, context, [], entry, items)
  }
  items
}

///|
pub(all) struct FunctionParameter {
  name : String
  type_text : String
  type_expr : TypeExpression
  attributes : Array[Attribute]
} derive(Eq, Debug)

///|
pub(all) enum TypeTemplateArgument {
  Type(TypeExpression)
  Literal(String)
} derive(Eq, Debug)

///|
pub(all) struct TypeExpression {
  path : Array[String]
  ident : String
  template_text : String?
  template_args : Array[TypeTemplateArgument]
} derive(Eq, Debug)

///|
pub(all) enum UnaryOperator {
  Negation
  LogicalNegation
  BitwiseComplement
  Indirection
  AddressOf
} derive(Eq, Debug)

///|
pub(all) enum BinaryOperator {
  ShortCircuitOr
  ShortCircuitAnd
  BitwiseOr
  BitwiseXor
  BitwiseAnd
  Equality
  Inequality
  LessThan
  LessThanEqual
  GreaterThan
  GreaterThanEqual
  ShiftLeft
  ShiftRight
  Addition
  Subtraction
  Multiplication
  Division
  Remainder
} derive(Eq, Debug)

///|
pub(all) struct FunctionCallExpression {
  callee : TypeExpression
  arguments : Array[Expression]
} derive(Eq, Debug)

///|
pub(all) enum Expression {
  Literal(String)
  Bool(Bool)
  TypeOrIdentifier(TypeExpression)
  Parenthesized(Expression)
  NamedComponent(Expression, String)
  Indexing(Expression, Expression)
  Unary(UnaryOperator, Expression)
  Binary(BinaryOperator, Expression, Expression)
  FunctionCall(FunctionCallExpression)
} derive(Eq, Debug)

///|
pub(all) enum StatementKind {
  Empty
  Block
  Return
  Discard
  If
  Switch
  Loop
  For
  While
  Continuing
  Break
  Continue
  BreakIf
  ConstAssert
  Const
  Let
  Var
  Assignment
  CompoundAssignment
  Increment
  Decrement
  Call
  Other
} derive(Eq, Debug)

///|
pub(all) enum StatementDeclarationKind {
  Const
  Let
  Var
} derive(Eq, Debug)

///|
pub(all) enum AssignmentOperator {
  Equal
  PlusEqual
  MinusEqual
  TimesEqual
  DivisionEqual
  ModuloEqual
  AndEqual
  OrEqual
  XorEqual
  ShiftLeftAssign
  ShiftRightAssign
} derive(Eq, Debug)

///|
pub(all) struct AssignmentStatement {
  operator : AssignmentOperator
  lhs : Expression
  rhs : Expression
} derive(Eq, Debug)

///|
pub(all) struct BlockStatement {
  body : FunctionBody
} derive(Eq, Debug)

///|
pub(all) struct IfStatement {
  condition : Expression
  body : FunctionBody
  else_body : FunctionBody?
} derive(Eq, Debug)

///|
pub(all) struct LoopStatement {
  body : FunctionBody
} derive(Eq, Debug)

///|
pub(all) struct WhileStatement {
  condition : Expression
  body : FunctionBody
} derive(Eq, Debug)

///|
pub(all) struct ContinuingStatement {
  body : FunctionBody
} derive(Eq, Debug)

///|
pub(all) enum ForInitializer {
  Declaration(StatementDeclaration)
  Assignment(AssignmentStatement)
  Expression(Expression)
} derive(Eq, Debug)

///|
pub(all) enum ForUpdate {
  Assignment(AssignmentStatement)
  Increment(Expression)
  Decrement(Expression)
  Expression(Expression)
} derive(Eq, Debug)

///|
pub(all) struct ForStatement {
  initializer : ForInitializer?
  condition : Expression?
  update : ForUpdate?
  body : FunctionBody
} derive(Eq, Debug)

///|
pub(all) struct SwitchCase {
  selectors : Array[Expression]
  is_default : Bool
  body : FunctionBody
  attributes : Array[Attribute]
} derive(Eq, Debug)

///|
pub(all) struct SwitchStatement {
  selector : Expression
  cases : Array[SwitchCase]
} derive(Eq, Debug)

///|
pub(all) enum ControlStatement {
  Block(BlockStatement)
  If(IfStatement)
  Switch(SwitchStatement)
  Loop(LoopStatement)
  For(ForStatement)
  While(WhileStatement)
  Continuing(ContinuingStatement)
} derive(Eq, Debug)

///|
pub(all) struct StatementDeclaration {
  kind : StatementDeclarationKind
  name : String?
  template_arguments : String?
  type_text : String?
  type_expr : TypeExpression?
  initializer : String?
  initializer_expr : Expression?
} derive(Eq, Debug)

///|
pub(all) struct Statement {
  kind : StatementKind
  source : String
  expression : Expression?
  declaration : StatementDeclaration?
  assignment : AssignmentStatement?
  update_expression : Expression?
  control : ControlStatement?
  attributes : Array[Attribute]
} derive(Eq, Debug)

///|
pub(all) struct FunctionBody {
  statements : Array[Statement]
} derive(Eq, Debug)

///|
pub(all) struct FunctionDeclaration {
  name : String
  generic_parameters : String?
  parameters : Array[FunctionParameter]
  return_type : String?
  return_type_expr : TypeExpression?
  return_attributes : Array[Attribute]
  body : FunctionBody
} derive(Eq, Debug)

///|
pub(all) struct StructMember {
  name : String
  type_text : String
  type_expr : TypeExpression
  attributes : Array[Attribute]
} derive(Eq, Debug)

///|
pub(all) struct StructDeclaration {
  name : String
  members : Array[StructMember]
} derive(Eq, Debug)

///|
pub(all) struct AliasDeclaration {
  name : String
  target : String?
  target_type : TypeExpression?
} derive(Eq, Debug)

///|
pub(all) struct ConstDeclaration {
  name : String
  type_text : String?
  type_expr : TypeExpression?
  initializer : String?
  initializer_expr : Expression?
} derive(Eq, Debug)

///|
pub(all) struct OverrideDeclaration {
  name : String
  type_text : String?
  type_expr : TypeExpression?
  initializer : String?
  initializer_expr : Expression?
} derive(Eq, Debug)

///|
pub(all) struct LetDeclaration {
  name : String
  type_text : String?
  type_expr : TypeExpression?
  initializer : String?
  initializer_expr : Expression?
} derive(Eq, Debug)

///|
pub(all) struct VarDeclaration {
  name : String?
  template_arguments : String?
  type_text : String?
  type_expr : TypeExpression?
  initializer : String?
  initializer_expr : Expression?
} derive(Eq, Debug)

///|
pub(all) struct EnableDirectiveDeclaration {
  names : Array[String]
} derive(Eq, Debug)

///|
pub(all) struct RequiresDirectiveDeclaration {
  names : Array[String]
} derive(Eq, Debug)

///|
pub(all) struct DiagnosticDirectiveDeclaration {
  arguments : Array[String]
  severity : String?
  rule_name : String?
} derive(Eq, Debug)

///|
pub(all) struct ConstAssertDeclaration {
  assertion : String
  assertion_expr : Expression
} derive(Eq, Debug)

///|
fn VarDeclaration::ident(self : VarDeclaration) -> String? {
  self.name
}

///|
fn VarDeclaration::template_args(self : VarDeclaration) -> String? {
  self.template_arguments
}

///|
pub(all) enum GlobalDeclarationHeader {
  Function(FunctionDeclaration)
  Struct(StructDeclaration)
  Alias(AliasDeclaration)
  Const(ConstDeclaration)
  Override(OverrideDeclaration)
  Let(LetDeclaration)
  Var(VarDeclaration)
  ConstAssert(ConstAssertDeclaration)
  EnableDirective(EnableDirectiveDeclaration)
  RequiresDirective(RequiresDirectiveDeclaration)
  DiagnosticDirective(DiagnosticDirectiveDeclaration)
  Other
} derive(Eq, Debug)

///|
pub(all) struct GlobalDeclaration {
  header : GlobalDeclarationHeader
  attributes : Array[Attribute]
  source : String
  span : SyntaxSpan
} derive(Eq, Debug)

///|
fn GlobalDeclaration::ident(self : GlobalDeclaration) -> String? {
  match self.header {
    Function(header) => Some(header.name)
    Struct(header) => Some(header.name)
    Alias(header) => Some(header.name)
    Const(header) => Some(header.name)
    Override(header) => Some(header.name)
    Let(header) => Some(header.name)
    Var(header) => {
      ignore(header.template_args())
      header.ident()
    }
    ConstAssert(_) => None
    EnableDirective(_) => None
    RequiresDirective(_) => None
    DiagnosticDirective(_) => None
    Other => None
  }
}

///|
fn GlobalDeclaration::is_entrypoint(self : GlobalDeclaration) -> Bool {
  match self.header {
    Function(_) =>
      syntax_has_attribute(self.attributes, "fragment") ||
      syntax_has_attribute(self.attributes, "vertex") ||
      syntax_has_attribute(self.attributes, "compute")
    _ => false
  }
}

///|
fn GlobalDeclaration::is_const_assert(self : GlobalDeclaration) -> Bool {
  self.header is GlobalDeclarationHeader::ConstAssert(_)
}

///|
pub(all) struct TranslationUnit {
  imports : Array[ImportStatement]
  global_declarations : Array[GlobalDeclaration]
} derive(Eq, Debug)

///|
pub fn TranslationUnit::default() -> TranslationUnit {
  TranslationUnit::{ imports: [], global_declarations: [] }
}

///|
pub fn TranslationUnit::to_string(self : TranslationUnit) -> String {
  let parts : Array[String] = []
  for statement in self.imports {
    parts.push(statement.source_text())
  }
  for declaration in self.global_declarations {
    parts.push(declaration.source)
  }
  parts.join("\n\n")
}
