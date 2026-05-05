///|
pub(all) enum WgslDirectiveKind {
  Ifdef
  Ifndef
  If
  Else
  Endif
  DefineImportPath
  Define
  Import
  Enable
  Requires
  Diagnostic
  Other(String)
} derive(Eq, Debug)

///|
pub struct WgslDirective {
  priv kind : WgslDirectiveKind
  priv name : String
  priv tail : String
  priv start : Int
  priv end : Int
  priv name_start : Int
  priv name_end : Int
  priv tail_start : Int
  priv tail_end : Int
} derive(Debug)

///|
pub fn WgslDirective::new(
  kind : WgslDirectiveKind,
  name : String,
  tail : String,
  start : Int,
  end : Int,
  name_start : Int,
  name_end : Int,
  tail_start : Int,
  tail_end : Int,
) -> WgslDirective {
  WgslDirective::{
    kind,
    name,
    tail,
    start,
    end,
    name_start,
    name_end,
    tail_start,
    tail_end,
  }
}

///|
pub fn WgslDirective::kind(self : WgslDirective) -> WgslDirectiveKind {
  self.kind
}

///|
pub fn WgslDirective::name(self : WgslDirective) -> String {
  self.name
}

///|
pub fn WgslDirective::tail(self : WgslDirective) -> String {
  self.tail
}

///|
pub fn WgslDirective::start(self : WgslDirective) -> Int {
  self.start
}

///|
pub fn WgslDirective::end(self : WgslDirective) -> Int {
  self.end
}

///|
pub fn WgslDirective::name_start(self : WgslDirective) -> Int {
  self.name_start
}

///|
pub fn WgslDirective::name_end(self : WgslDirective) -> Int {
  self.name_end
}

///|
pub fn WgslDirective::tail_start(self : WgslDirective) -> Int {
  self.tail_start
}

///|
pub fn WgslDirective::tail_end(self : WgslDirective) -> Int {
  self.tail_end
}

///|
pub(all) enum WgslGlobalDeclKind {
  Directive
  Import
  Function
  GlobalVariable
  Const
  Override
  Struct
  TypeAlias
  ConstAssert
  Trivia
  Unknown
} derive(Eq, Debug)

///|
pub struct WgslIdent {
  name : String
  start : Int
  end : Int
} derive(Debug)

///|
pub fn WgslIdent::new(name : String, start : Int, end : Int) -> WgslIdent {
  WgslIdent::{ name, start, end }
}

///|
pub(all) enum WgslExprTokenKind {
  Identifier
  BoolLiteral(Bool)
  UintLiteral(Int)
  IntLiteral(Int)
  FloatLiteral
  Operator(String)
  Punctuation(Int)
  Unknown
} derive(Debug)

///|
pub struct WgslExprToken {
  priv kind : WgslExprTokenKind
  priv text : String
  priv start : Int
  priv end : Int
} derive(Debug)

///|
pub fn WgslExprToken::new(
  kind : WgslExprTokenKind,
  text : String,
  start : Int,
  end : Int,
) -> WgslExprToken {
  WgslExprToken::{ kind, text, start, end }
}

///|
pub fn WgslExprToken::kind(self : WgslExprToken) -> WgslExprTokenKind {
  self.kind
}

///|
pub fn WgslExprToken::text(self : WgslExprToken) -> String {
  self.text
}

///|
pub fn WgslExprToken::start(self : WgslExprToken) -> Int {
  self.start
}

///|
pub fn WgslExprToken::end(self : WgslExprToken) -> Int {
  self.end
}

///|
pub(all) enum WgslExprNodeKind {
  Identifier(WgslIdent)
  Literal(WgslExprToken)
  Token(WgslExprToken)
  Unary(String, WgslExprNode)
  Binary(String, WgslExprNode, WgslExprNode)
  Call(WgslExprNode, Array[WgslExprNode])
  PathAccess(WgslExprNode, WgslIdent)
  Member(WgslExprNode, WgslIdent)
  Index(WgslExprNode, WgslExprNode)
  Group(WgslExprNode)
  Sequence(Array[WgslExprNode])
} derive(Debug)

///|
pub struct WgslExprNode {
  kind : WgslExprNodeKind
  start : Int
  end : Int
} derive(Debug)

///|
pub fn WgslExprNode::new(
  kind : WgslExprNodeKind,
  start : Int,
  end : Int,
) -> WgslExprNode {
  WgslExprNode::{ kind, start, end }
}

///|
pub fn WgslExprNode::kind(self : WgslExprNode) -> WgslExprNodeKind {
  self.kind
}

///|
pub fn WgslExprNode::start(self : WgslExprNode) -> Int {
  self.start
}

///|
pub fn WgslExprNode::end(self : WgslExprNode) -> Int {
  self.end
}

///|
pub struct WgslExprRef {
  priv tokens : Array[WgslExprToken]
  priv identifiers : Array[WgslIdent]
  priv root : WgslExprNode?
  priv start : Int
  priv end : Int
} derive(Debug)

///|
pub fn WgslExprRef::new(
  tokens : Array[WgslExprToken],
  identifiers : Array[WgslIdent],
  root : WgslExprNode?,
  start : Int,
  end : Int,
) -> WgslExprRef {
  WgslExprRef::{ tokens, identifiers, root, start, end }
}

///|
pub fn WgslExprRef::tokens(self : WgslExprRef) -> Array[WgslExprToken] {
  self.tokens.copy()
}

///|
pub fn WgslExprRef::identifiers(self : WgslExprRef) -> Array[WgslIdent] {
  self.identifiers.copy()
}

///|
pub fn WgslExprRef::root(self : WgslExprRef) -> WgslExprNode? {
  self.root
}

///|
pub fn WgslExprRef::start(self : WgslExprRef) -> Int {
  self.start
}

///|
pub fn WgslExprRef::end(self : WgslExprRef) -> Int {
  self.end
}

///|
pub struct WgslAttribute {
  priv name : String
  priv start : Int
  priv end : Int
  priv arguments : String
  priv arguments_ref : WgslExprRef?
} derive(Debug)

///|
pub fn WgslAttribute::new(
  name : String,
  start : Int,
  end : Int,
  arguments : String,
  arguments_ref : WgslExprRef?,
) -> WgslAttribute {
  WgslAttribute::{ name, start, end, arguments, arguments_ref }
}

///|
pub fn WgslAttribute::name(self : WgslAttribute) -> String {
  self.name
}

///|
pub fn WgslAttribute::start(self : WgslAttribute) -> Int {
  self.start
}

///|
pub fn WgslAttribute::end(self : WgslAttribute) -> Int {
  self.end
}

///|
pub fn WgslAttribute::arguments(self : WgslAttribute) -> String {
  self.arguments
}

///|
pub fn WgslAttribute::arguments_ref(self : WgslAttribute) -> WgslExprRef? {
  self.arguments_ref
}

///|
pub struct WgslTypeRef {
  priv name : String
  priv arguments : Array[WgslTypeRef]
  priv start : Int
} derive(Debug)

///|
pub fn WgslTypeRef::new(
  name : String,
  arguments : Array[WgslTypeRef],
  start : Int,
) -> WgslTypeRef {
  WgslTypeRef::{ name, arguments, start }
}

///|
pub fn WgslTypeRef::name(self : WgslTypeRef) -> String {
  self.name
}

///|
pub fn WgslTypeRef::arguments(self : WgslTypeRef) -> Array[WgslTypeRef] {
  self.arguments.copy()
}

///|
pub fn WgslTypeRef::canonical_text(self : WgslTypeRef) -> String {
  if self.arguments.length() == 0 {
    return self.name
  }
  let argument_texts : Array[String] = []
  for argument in self.arguments {
    argument_texts.push(argument.canonical_text())
  }
  let joined_arguments = argument_texts.join(", ")
  "\{self.name}<\{joined_arguments}>"
}

///|
pub fn WgslTypeRef::start(self : WgslTypeRef) -> Int {
  self.start
}

///|
pub struct WgslFunctionArgument {
  priv attributes : Array[WgslAttribute]
  priv name : String
  priv start : Int
  priv end : Int
  priv name_start : Int
  priv name_end : Int
  priv ty_ref : WgslTypeRef?
} derive(Debug)

///|
pub fn WgslFunctionArgument::new(
  attributes : Array[WgslAttribute],
  name : String,
  start : Int,
  end : Int,
  name_start : Int,
  name_end : Int,
  ty_ref : WgslTypeRef?,
) -> WgslFunctionArgument {
  WgslFunctionArgument::{
    attributes,
    name,
    start,
    end,
    name_start,
    name_end,
    ty_ref,
  }
}

///|
pub fn WgslFunctionArgument::attributes(
  self : WgslFunctionArgument,
) -> Array[WgslAttribute] {
  self.attributes.copy()
}

///|
pub fn WgslFunctionArgument::name(self : WgslFunctionArgument) -> String {
  self.name
}

///|
pub fn WgslFunctionArgument::start(self : WgslFunctionArgument) -> Int {
  self.start
}

///|
pub fn WgslFunctionArgument::end(self : WgslFunctionArgument) -> Int {
  self.end
}

///|
pub fn WgslFunctionArgument::name_start(self : WgslFunctionArgument) -> Int {
  self.name_start
}

///|
pub fn WgslFunctionArgument::name_end(self : WgslFunctionArgument) -> Int {
  self.name_end
}

///|
pub fn WgslFunctionArgument::ty_ref(
  self : WgslFunctionArgument,
) -> WgslTypeRef? {
  self.ty_ref
}

///|
pub struct WgslFunctionResult {
  priv attributes : Array[WgslAttribute]
  priv start : Int
  priv end : Int
  priv ty : String
  priv ty_ref : WgslTypeRef?
} derive(Debug)

///|
pub fn WgslFunctionResult::new(
  attributes : Array[WgslAttribute],
  start : Int,
  end : Int,
  ty : String,
  ty_ref : WgslTypeRef?,
) -> WgslFunctionResult {
  WgslFunctionResult::{ attributes, start, end, ty, ty_ref }
}

///|
pub fn WgslFunctionResult::attributes(
  self : WgslFunctionResult,
) -> Array[WgslAttribute] {
  self.attributes.copy()
}

///|
pub fn WgslFunctionResult::start(self : WgslFunctionResult) -> Int {
  self.start
}

///|
pub fn WgslFunctionResult::end(self : WgslFunctionResult) -> Int {
  self.end
}

///|
pub fn WgslFunctionResult::ty(self : WgslFunctionResult) -> String {
  self.ty
}

///|
pub fn WgslFunctionResult::ty_ref(self : WgslFunctionResult) -> WgslTypeRef? {
  self.ty_ref
}

///|
pub(all) enum WgslStatementKind {
  Empty
  LocalDeclaration
  Return
  If
  For
  While
  Loop
  Switch
  Break
  Continue
  Discard
  ConstAssert
  Compound
  Expression
} derive(Eq, Debug)

///|
pub struct WgslLocalDeclaration {
  priv kind : String
  priv name : WgslIdent
  priv template_list : Array[String]
  priv ty : String?
  priv ty_ref : WgslTypeRef?
  priv initializer_ref : WgslExprRef?
} derive(Debug)

///|
pub fn WgslLocalDeclaration::new(
  kind : String,
  name : WgslIdent,
  template_list : Array[String],
  ty : String?,
  ty_ref : WgslTypeRef?,
  initializer_ref : WgslExprRef?,
) -> WgslLocalDeclaration {
  WgslLocalDeclaration::{
    kind,
    name,
    template_list,
    ty,
    ty_ref,
    initializer_ref,
  }
}

///|
pub fn WgslLocalDeclaration::kind(self : WgslLocalDeclaration) -> String {
  self.kind
}

///|
pub fn WgslLocalDeclaration::name(self : WgslLocalDeclaration) -> WgslIdent {
  self.name
}

///|
pub fn WgslLocalDeclaration::template_list(
  self : WgslLocalDeclaration,
) -> Array[String] {
  self.template_list.copy()
}

///|
pub fn WgslLocalDeclaration::ty(self : WgslLocalDeclaration) -> String? {
  self.ty
}

///|
pub fn WgslLocalDeclaration::ty_ref(
  self : WgslLocalDeclaration,
) -> WgslTypeRef? {
  self.ty_ref
}

///|
pub fn WgslLocalDeclaration::initializer_ref(
  self : WgslLocalDeclaration,
) -> WgslExprRef? {
  self.initializer_ref
}

///|
pub(all) enum WgslStatementExpressionRole {
  Condition
  ReturnValue
  ForHeader
  SwitchSelector
  CaseSelector
  BreakIf
  ConstAssertValue
  ExpressionValue
} derive(Eq, Debug)

///|
pub struct WgslStatementExpression {
  priv role : WgslStatementExpressionRole
  priv expression : WgslExprRef
} derive(Debug)

///|
pub fn WgslStatementExpression::new(
  role : WgslStatementExpressionRole,
  expression : WgslExprRef,
) -> WgslStatementExpression {
  WgslStatementExpression::{ role, expression }
}

///|
pub fn WgslStatementExpression::role(
  self : WgslStatementExpression,
) -> WgslStatementExpressionRole {
  self.role
}

///|
pub fn WgslStatementExpression::expression(
  self : WgslStatementExpression,
) -> WgslExprRef {
  self.expression
}

///|
pub(all) enum WgslStatementPayload {
  Empty
  LocalDeclaration(Array[WgslLocalDeclaration])
  Return(WgslExprRef?)
  If(WgslExprRef?)
  For(Array[WgslStatementExpression])
  While(WgslExprRef?)
  Loop
  Switch(WgslExprRef?)
  Break(WgslExprRef?)
  Continue
  Discard
  ConstAssert(WgslExprRef?)
  Compound
  Case(WgslExprRef?)
  DefaultCase
  Expression(WgslExprRef?)
} derive(Debug)

///|
pub struct WgslStatement {
  priv kind : WgslStatementKind
  priv payload : WgslStatementPayload
  priv text : String
  priv blocks : Array[WgslBlock]
  priv local_bindings : Array[WgslLocalDeclaration]
  priv exported_local_bindings : Array[WgslLocalDeclaration]
  priv expression_refs : Array[WgslExprRef]
  priv expressions : Array[WgslStatementExpression]
} derive(Debug)

///|
pub fn WgslStatement::new(
  kind : WgslStatementKind,
  payload : WgslStatementPayload,
  text : String,
  blocks : Array[WgslBlock],
  local_bindings : Array[WgslLocalDeclaration],
  exported_local_bindings : Array[WgslLocalDeclaration],
  expression_refs : Array[WgslExprRef],
  expressions : Array[WgslStatementExpression],
) -> WgslStatement {
  WgslStatement::{
    kind,
    payload,
    text,
    blocks,
    local_bindings,
    exported_local_bindings,
    expression_refs,
    expressions,
  }
}

///|
pub fn WgslStatement::kind(self : WgslStatement) -> WgslStatementKind {
  self.kind
}

///|
pub fn WgslStatement::payload(self : WgslStatement) -> WgslStatementPayload {
  self.payload
}

///|
pub fn WgslStatement::text(self : WgslStatement) -> String {
  self.text
}

///|
pub fn WgslStatement::blocks(self : WgslStatement) -> Array[WgslBlock] {
  self.blocks.copy()
}

///|
pub fn WgslStatement::local_bindings(
  self : WgslStatement,
) -> Array[WgslLocalDeclaration] {
  self.local_bindings.copy()
}

///|
pub fn WgslStatement::exported_local_bindings(
  self : WgslStatement,
) -> Array[WgslLocalDeclaration] {
  self.exported_local_bindings.copy()
}

///|
pub fn WgslStatement::expression_refs(
  self : WgslStatement,
) -> Array[WgslExprRef] {
  self.expression_refs.copy()
}

///|
pub fn WgslStatement::expressions(
  self : WgslStatement,
) -> Array[WgslStatementExpression] {
  self.expressions.copy()
}

///|
pub struct WgslBlock {
  priv start : Int
  priv end : Int
  priv statements : Array[WgslStatement]
} derive(Debug)

///|
pub fn WgslBlock::new(
  start : Int,
  end : Int,
  statements : Array[WgslStatement],
) -> WgslBlock {
  WgslBlock::{ start, end, statements }
}

///|
pub fn WgslBlock::start(self : WgslBlock) -> Int {
  self.start
}

///|
pub fn WgslBlock::end(self : WgslBlock) -> Int {
  self.end
}

///|
pub fn WgslBlock::statements(self : WgslBlock) -> Array[WgslStatement] {
  self.statements.copy()
}

///|
pub struct WgslFunction {
  priv attributes : Array[WgslAttribute]
  priv qualifier : String
  priv qualifier_start : Int?
  priv qualifier_end : Int?
  priv fn_start : Int
  priv fn_end : Int
  priv name : WgslIdent
  priv arguments : Array[WgslFunctionArgument]
  priv result : WgslFunctionResult?
  priv body : WgslBlock
} derive(Debug)

///|
pub fn WgslFunction::new(
  attributes : Array[WgslAttribute],
  qualifier : String,
  qualifier_start : Int?,
  qualifier_end : Int?,
  fn_start : Int,
  fn_end : Int,
  name : WgslIdent,
  arguments : Array[WgslFunctionArgument],
  result : WgslFunctionResult?,
  body : WgslBlock,
) -> WgslFunction {
  WgslFunction::{
    attributes,
    qualifier,
    qualifier_start,
    qualifier_end,
    fn_start,
    fn_end,
    name,
    arguments,
    result,
    body,
  }
}

///|
pub fn WgslFunction::attributes(self : WgslFunction) -> Array[WgslAttribute] {
  self.attributes.copy()
}

///|
pub fn WgslFunction::qualifier(self : WgslFunction) -> String {
  self.qualifier
}

///|
pub fn WgslFunction::qualifier_start(self : WgslFunction) -> Int? {
  self.qualifier_start
}

///|
pub fn WgslFunction::qualifier_end(self : WgslFunction) -> Int? {
  self.qualifier_end
}

///|
pub fn WgslFunction::fn_start(self : WgslFunction) -> Int {
  self.fn_start
}

///|
pub fn WgslFunction::fn_end(self : WgslFunction) -> Int {
  self.fn_end
}

///|
pub fn WgslFunction::name(self : WgslFunction) -> WgslIdent {
  self.name
}

///|
pub fn WgslFunction::arguments(
  self : WgslFunction,
) -> Array[WgslFunctionArgument] {
  self.arguments.copy()
}

///|
pub fn WgslFunction::result(self : WgslFunction) -> WgslFunctionResult? {
  self.result
}

///|
pub fn WgslFunction::body(self : WgslFunction) -> WgslBlock {
  self.body
}

///|
pub struct WgslStructMember {
  priv attributes : Array[WgslAttribute]
  priv name : String
  priv start : Int
  priv end : Int
  priv name_start : Int
  priv name_end : Int
  priv ty : String
  priv ty_ref : WgslTypeRef?
} derive(Debug)

///|
pub fn WgslStructMember::new(
  attributes : Array[WgslAttribute],
  name : String,
  start : Int,
  end : Int,
  name_start : Int,
  name_end : Int,
  ty : String,
  ty_ref : WgslTypeRef?,
) -> WgslStructMember {
  WgslStructMember::{
    attributes,
    name,
    start,
    end,
    name_start,
    name_end,
    ty,
    ty_ref,
  }
}

///|
pub fn WgslStructMember::attributes(
  self : WgslStructMember,
) -> Array[WgslAttribute] {
  self.attributes.copy()
}

///|
pub fn WgslStructMember::name(self : WgslStructMember) -> String {
  self.name
}

///|
pub fn WgslStructMember::start(self : WgslStructMember) -> Int {
  self.start
}

///|
pub fn WgslStructMember::end(self : WgslStructMember) -> Int {
  self.end
}

///|
pub fn WgslStructMember::name_start(self : WgslStructMember) -> Int {
  self.name_start
}

///|
pub fn WgslStructMember::name_end(self : WgslStructMember) -> Int {
  self.name_end
}

///|
pub fn WgslStructMember::ty(self : WgslStructMember) -> String {
  self.ty
}

///|
pub fn WgslStructMember::ty_ref(self : WgslStructMember) -> WgslTypeRef? {
  self.ty_ref
}

///|
pub struct WgslStruct {
  priv attributes : Array[WgslAttribute]
  priv name : WgslIdent
  priv members : Array[WgslStructMember]
} derive(Debug)

///|
pub fn WgslStruct::new(
  attributes : Array[WgslAttribute],
  name : WgslIdent,
  members : Array[WgslStructMember],
) -> WgslStruct {
  WgslStruct::{ attributes, name, members }
}

///|
pub fn WgslStruct::attributes(self : WgslStruct) -> Array[WgslAttribute] {
  self.attributes.copy()
}

///|
pub fn WgslStruct::name(self : WgslStruct) -> WgslIdent {
  self.name
}

///|
pub fn WgslStruct::members(self : WgslStruct) -> Array[WgslStructMember] {
  self.members.copy()
}

///|
pub struct WgslGlobalVariable {
  priv attributes : Array[WgslAttribute]
  priv name : WgslIdent
  priv template_list : Array[String]
  priv ty : String?
  priv ty_ref : WgslTypeRef?
  priv initializer : String?
  priv initializer_ref : WgslExprRef?
} derive(Debug)

///|
pub fn WgslGlobalVariable::new(
  attributes : Array[WgslAttribute],
  name : WgslIdent,
  template_list : Array[String],
  ty : String?,
  ty_ref : WgslTypeRef?,
  initializer : String?,
  initializer_ref : WgslExprRef?,
) -> WgslGlobalVariable {
  WgslGlobalVariable::{
    attributes,
    name,
    template_list,
    ty,
    ty_ref,
    initializer,
    initializer_ref,
  }
}

///|
pub fn WgslGlobalVariable::attributes(
  self : WgslGlobalVariable,
) -> Array[WgslAttribute] {
  self.attributes.copy()
}

///|
pub fn WgslGlobalVariable::name(self : WgslGlobalVariable) -> WgslIdent {
  self.name
}

///|
pub fn WgslGlobalVariable::template_list(
  self : WgslGlobalVariable,
) -> Array[String] {
  self.template_list.copy()
}

///|
pub fn WgslGlobalVariable::ty(self : WgslGlobalVariable) -> String? {
  self.ty
}

///|
pub fn WgslGlobalVariable::ty_ref(self : WgslGlobalVariable) -> WgslTypeRef? {
  self.ty_ref
}

///|
pub fn WgslGlobalVariable::initializer(self : WgslGlobalVariable) -> String? {
  self.initializer
}

///|
pub fn WgslGlobalVariable::initializer_ref(
  self : WgslGlobalVariable,
) -> WgslExprRef? {
  self.initializer_ref
}

///|
pub struct WgslConst {
  priv name : WgslIdent
  priv ty : String?
  priv ty_ref : WgslTypeRef?
  priv initializer : String?
  priv initializer_ref : WgslExprRef?
} derive(Debug)

///|
pub fn WgslConst::new(
  name : WgslIdent,
  ty : String?,
  ty_ref : WgslTypeRef?,
  initializer : String?,
  initializer_ref : WgslExprRef?,
) -> WgslConst {
  WgslConst::{ name, ty, ty_ref, initializer, initializer_ref }
}

///|
pub fn WgslConst::name(self : WgslConst) -> WgslIdent {
  self.name
}

///|
pub fn WgslConst::ty(self : WgslConst) -> String? {
  self.ty
}

///|
pub fn WgslConst::ty_ref(self : WgslConst) -> WgslTypeRef? {
  self.ty_ref
}

///|
pub fn WgslConst::initializer(self : WgslConst) -> String? {
  self.initializer
}

///|
pub fn WgslConst::initializer_ref(self : WgslConst) -> WgslExprRef? {
  self.initializer_ref
}

///|
pub struct WgslOverride {
  priv attributes : Array[WgslAttribute]
  priv name : WgslIdent
  priv ty : String?
  priv ty_ref : WgslTypeRef?
  priv initializer : String?
  priv initializer_ref : WgslExprRef?
} derive(Debug)

///|
pub fn WgslOverride::new(
  attributes : Array[WgslAttribute],
  name : WgslIdent,
  ty : String?,
  ty_ref : WgslTypeRef?,
  initializer : String?,
  initializer_ref : WgslExprRef?,
) -> WgslOverride {
  WgslOverride::{ attributes, name, ty, ty_ref, initializer, initializer_ref }
}

///|
pub fn WgslOverride::attributes(self : WgslOverride) -> Array[WgslAttribute] {
  self.attributes.copy()
}

///|
pub fn WgslOverride::name(self : WgslOverride) -> WgslIdent {
  self.name
}

///|
pub fn WgslOverride::ty(self : WgslOverride) -> String? {
  self.ty
}

///|
pub fn WgslOverride::ty_ref(self : WgslOverride) -> WgslTypeRef? {
  self.ty_ref
}

///|
pub fn WgslOverride::initializer(self : WgslOverride) -> String? {
  self.initializer
}

///|
pub fn WgslOverride::initializer_ref(self : WgslOverride) -> WgslExprRef? {
  self.initializer_ref
}

///|
pub struct WgslTypeAlias {
  priv name : WgslIdent
  priv ty : String
  priv ty_ref : WgslTypeRef?
} derive(Debug)

///|
pub fn WgslTypeAlias::new(
  name : WgslIdent,
  ty : String,
  ty_ref : WgslTypeRef?,
) -> WgslTypeAlias {
  WgslTypeAlias::{ name, ty, ty_ref }
}

///|
pub fn WgslTypeAlias::name(self : WgslTypeAlias) -> WgslIdent {
  self.name
}

///|
pub fn WgslTypeAlias::ty(self : WgslTypeAlias) -> String {
  self.ty
}

///|
pub fn WgslTypeAlias::ty_ref(self : WgslTypeAlias) -> WgslTypeRef? {
  self.ty_ref
}

///|
pub(all) enum WgslGlobalDeclData {
  Directive(WgslDirective)
  Import(WgslDirective)
  Function(WgslFunction)
  GlobalVariable(WgslGlobalVariable)
  Const(WgslConst)
  Override(WgslOverride)
  Struct(WgslStruct)
  TypeAlias(WgslTypeAlias)
  ConstAssert(WgslExprRef)
  Raw
} derive(Debug)

///|
pub struct WgslGlobalDecl {
  priv kind : WgslGlobalDeclKind
  priv data : WgslGlobalDeclData
  priv name : String
  priv text : String
  priv start : Int
} derive(Debug)

///|
pub fn WgslGlobalDecl::new(
  kind : WgslGlobalDeclKind,
  data : WgslGlobalDeclData,
  name : String,
  text : String,
  start : Int,
) -> WgslGlobalDecl {
  WgslGlobalDecl::{ kind, data, name, text, start }
}

///|
pub fn WgslGlobalDecl::kind(self : WgslGlobalDecl) -> WgslGlobalDeclKind {
  self.kind
}

///|
pub fn WgslGlobalDecl::data(self : WgslGlobalDecl) -> WgslGlobalDeclData {
  self.data
}

///|
pub fn WgslGlobalDecl::name(self : WgslGlobalDecl) -> String {
  self.name
}

///|
pub fn WgslGlobalDecl::text(self : WgslGlobalDecl) -> String {
  self.text
}

///|
pub fn WgslGlobalDecl::start(self : WgslGlobalDecl) -> Int {
  self.start
}

///|
pub struct WgslTranslationUnit {
  priv declarations : Array[WgslGlobalDecl]
} derive(Debug)

///|
pub fn WgslTranslationUnit::new(
  declarations : Array[WgslGlobalDecl],
) -> WgslTranslationUnit {
  WgslTranslationUnit::{ declarations, }
}

///|
pub fn WgslTranslationUnit::declarations(
  self : WgslTranslationUnit,
) -> Array[WgslGlobalDecl] {
  self.declarations.copy()
}
