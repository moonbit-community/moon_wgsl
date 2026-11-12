///|
#derive(Eq, Debug)
pub(all) enum WgslDirectiveKind {
  Enable
  Requires
  Diagnostic
}

///|
#derive(Debug)
pub struct WgslDirectiveTail {
  priv text : String
  priv start : Int32
  priv end : Int32
  priv has_required_separator : Bool
}

///|
pub fn WgslDirectiveTail::WgslDirectiveTail(
  text : String,
  start : Int32,
  end : Int32,
  has_required_separator : Bool,
) -> WgslDirectiveTail {
  { text, start, end, has_required_separator, }
}

///|
fn WgslDirectiveTail::text(self : WgslDirectiveTail) -> String {
  self.text
}

///|
fn WgslDirectiveTail::has_text(self : WgslDirectiveTail) -> Bool {
  self.text != ""
}

///|
fn WgslDirectiveTail::has_required_separator(self : WgslDirectiveTail) -> Bool {
  self.has_required_separator
}

///|
fn WgslDirectiveTail::start(self : WgslDirectiveTail) -> Int32 {
  self.start
}

///|
fn WgslDirectiveTail::end(self : WgslDirectiveTail) -> Int32 {
  self.end
}

///|
#derive(Debug)
pub struct WgslDirective {
  priv kind : WgslDirectiveKind
  priv name : WgslIdent
  priv tail : WgslDirectiveTail
  priv start : Int32
  priv end : Int32
}

///|
pub fn WgslDirective::WgslDirective(
  kind : WgslDirectiveKind,
  name : WgslIdent,
  tail : WgslDirectiveTail,
  start : Int32,
  end : Int32,
) -> WgslDirective {
  { kind, name, tail, start, end, }
}

///|
pub fn WgslDirective::kind(self : WgslDirective) -> WgslDirectiveKind {
  self.kind
}

///|
pub fn WgslDirective::name(self : WgslDirective) -> WgslIdent {
  self.name
}

///|
pub fn WgslDirective::tail(self : WgslDirective) -> String {
  self.tail.text()
}

///|
pub fn WgslDirective::has_tail(self : WgslDirective) -> Bool {
  self.tail.has_text()
}

///|
pub fn WgslDirective::has_required_tail_separator(self : WgslDirective) -> Bool {
  self.tail.has_required_separator()
}

///|
pub fn WgslDirective::start(self : WgslDirective) -> Int32 {
  self.start
}

///|
pub fn WgslDirective::end(self : WgslDirective) -> Int32 {
  self.end
}

///|
pub fn WgslDirective::tail_start(self : WgslDirective) -> Int32 {
  self.tail.start()
}

///|
pub fn WgslDirective::tail_end(self : WgslDirective) -> Int32 {
  self.tail.end()
}

///|
#derive(Eq, Debug)
pub(all) enum WgslGlobalDeclKind {
  Directive
  Function
  GlobalVariable
  Const
  Override
  Struct
  TypeAlias
  ConstAssert
  Trivia
  Unknown
}

///|
#derive(Debug)
pub struct WgslIdent {
  priv name : String
  priv start : Int32
  priv end : Int32
}

///|
pub fn WgslIdent::WgslIdent(
  name : String,
  start : Int32,
  end : Int32,
) -> WgslIdent {
  { name, start, end, }
}

///|
pub fn WgslIdent::name(self : WgslIdent) -> String {
  self.name
}

///|
pub fn WgslIdent::start(self : WgslIdent) -> Int32 {
  self.start
}

///|
pub fn WgslIdent::end(self : WgslIdent) -> Int32 {
  self.end
}

///|
#derive(Eq, Debug)
pub(all) enum WgslExprOperator {
  LogicalOr
  LogicalAnd
  BitOr
  BitXor
  BitAnd
  Equal
  NotEqual
  Less
  Greater
  LessEqual
  GreaterEqual
  ShiftLeft
  ShiftRight
  Add
  Subtract
  Multiply
  Divide
  Modulo
  Not
  Complement
  Unknown(String)
}

///|
pub fn WgslExprOperator::from_text(text : String) -> WgslExprOperator {
  match text {
    "||" => LogicalOr
    "&&" => LogicalAnd
    "|" => BitOr
    "^" => BitXor
    "&" => BitAnd
    "==" => Equal
    "!=" => NotEqual
    "<" => Less
    ">" => Greater
    "<=" => LessEqual
    ">=" => GreaterEqual
    "<<" => ShiftLeft
    ">>" => ShiftRight
    "+" => Add
    "-" => Subtract
    "*" => Multiply
    "/" => Divide
    "%" => Modulo
    "!" => Not
    "~" => Complement
    _ => Unknown(text)
  }
}

///|
pub fn WgslExprOperator::text(self : WgslExprOperator) -> String {
  match self {
    LogicalOr => "||"
    LogicalAnd => "&&"
    BitOr => "|"
    BitXor => "^"
    BitAnd => "&"
    Equal => "=="
    NotEqual => "!="
    Less => "<"
    Greater => ">"
    LessEqual => "<="
    GreaterEqual => ">="
    ShiftLeft => "<<"
    ShiftRight => ">>"
    Add => "+"
    Subtract => "-"
    Multiply => "*"
    Divide => "/"
    Modulo => "%"
    Not => "!"
    Complement => "~"
    Unknown(text) => text
  }
}

///|
pub fn WgslExprOperator::binary_precedence(self : WgslExprOperator) -> Int32 {
  match self {
    LogicalOr => 1
    LogicalAnd => 2
    BitOr => 3
    BitXor => 4
    BitAnd => 5
    Equal | NotEqual => 6
    Less | Greater | LessEqual | GreaterEqual => 7
    ShiftLeft | ShiftRight => 8
    Add | Subtract => 9
    Multiply | Divide | Modulo => 10
    Not | Complement | Unknown(_) => -1
  }
}

///|
#derive(Debug)
pub(all) enum WgslExprTokenKind {
  Identifier
  BoolLiteral(Bool)
  NumericLiteral(WgslNumericLiteral)
  Operator(WgslExprOperator)
  Punctuation(Int32)
  Unknown
}

///|
#derive(Eq, Debug)
pub(all) enum WgslNumericLiteralBase {
  Decimal
  Hexadecimal
}

///|
#derive(Eq, Debug)
pub(all) enum WgslNumericLiteralSuffix {
  NoSuffix
  I32Suffix
  U32Suffix
  F32Suffix
  F16Suffix
}

///|
#derive(Eq, Debug)
pub(all) enum WgslNumericLiteralCategory {
  AbstractIntLiteral
  I32Literal
  U32Literal
  AbstractFloatLiteral
  F32Literal
  F16Literal
  InvalidNumericLiteral
}

///|
#derive(Eq, Debug)
pub(all) struct WgslNumericLiteral {
  raw_text : String
  base : WgslNumericLiteralBase
  suffix : WgslNumericLiteralSuffix
  category : WgslNumericLiteralCategory
}

///|
#derive(Debug)
pub struct WgslExprToken {
  priv kind : WgslExprTokenKind
  priv text : String
  priv start : Int32
  priv end : Int32
}

///|
pub fn WgslExprToken::WgslExprToken(
  kind : WgslExprTokenKind,
  text : String,
  start : Int32,
  end : Int32,
) -> WgslExprToken {
  { kind, text, start, end, }
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
pub fn WgslExprToken::start(self : WgslExprToken) -> Int32 {
  self.start
}

///|
pub fn WgslExprToken::end(self : WgslExprToken) -> Int32 {
  self.end
}

///|
pub fn WgslExprToken::numeric_literal(
  self : WgslExprToken,
) -> WgslNumericLiteral? {
  match self.kind {
    NumericLiteral(literal) => Some(literal)
    _ => None
  }
}

///|
#derive(Debug)
pub(all) enum WgslExprNodeKind {
  Identifier(WgslIdent)
  Literal(WgslExprToken)
  ShaderDefTemplate(String)
  Unary(WgslExprOperator, WgslExprNode)
  PostfixUpdate(String, WgslExprNode)
  Assignment(String, WgslExprNode, WgslExprNode)
  Binary(WgslExprOperator, WgslExprNode, WgslExprNode)
  Call(WgslExprNode, Array[WgslExprNode])
  Template(WgslExprNode, Array[WgslTypeArgument])
  PathAccess(WgslExprNode, WgslIdent)
  Member(WgslExprNode, WgslIdent)
  Index(WgslExprNode, WgslExprNode)
  Group(WgslExprNode)
  Sequence(Array[WgslExprNode])
}

///|
#derive(Debug)
pub struct WgslExprNode {
  priv kind : WgslExprNodeKind
  priv start : Int32
  priv end : Int32
}

///|
pub fn WgslExprNode::WgslExprNode(
  kind : WgslExprNodeKind,
  start : Int32,
  end : Int32,
) -> WgslExprNode {
  { kind, start, end, }
}

///|
pub fn WgslExprNode::kind(self : WgslExprNode) -> WgslExprNodeKind {
  self.kind
}

///|
pub fn WgslExprNode::start(self : WgslExprNode) -> Int32 {
  self.start
}

///|
pub fn WgslExprNode::end(self : WgslExprNode) -> Int32 {
  self.end
}

///|
#derive(Debug)
pub struct WgslExprRef {
  priv tokens : Array[WgslExprToken]
  priv identifiers : Array[WgslIdent]
  priv root : WgslExprNode?
  priv start : Int32
  priv end : Int32
}

///|
pub fn WgslExprRef::WgslExprRef(
  tokens : Array[WgslExprToken],
  identifiers : Array[WgslIdent],
  root : WgslExprNode?,
  start : Int32,
  end : Int32,
) -> WgslExprRef {
  { tokens, identifiers, root, start, end, }
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
pub fn WgslExprRef::start(self : WgslExprRef) -> Int32 {
  self.start
}

///|
pub fn WgslExprRef::end(self : WgslExprRef) -> Int32 {
  self.end
}

///|
#derive(Debug)
pub struct WgslAttribute {
  priv name : WgslIdent
  priv start : Int32
  priv end : Int32
  priv arguments_ref : WgslExprRef?
}

///|
pub fn WgslAttribute::WgslAttribute(
  name : WgslIdent,
  start : Int32,
  end : Int32,
  arguments_ref : WgslExprRef?,
) -> WgslAttribute {
  { name, start, end, arguments_ref, }
}

///|
pub fn WgslAttribute::name(self : WgslAttribute) -> WgslIdent {
  self.name
}

///|
pub fn WgslAttribute::start(self : WgslAttribute) -> Int32 {
  self.start
}

///|
pub fn WgslAttribute::end(self : WgslAttribute) -> Int32 {
  self.end
}

///|
pub fn WgslAttribute::arguments_ref(self : WgslAttribute) -> WgslExprRef? {
  self.arguments_ref
}

///|
#derive(Eq, Debug)
pub(all) enum WgslTypeAtomKind {
  Identifier
  Numeric
  Unknown
}

///|
#derive(Debug)
pub struct WgslTypeAtom {
  priv kind : WgslTypeAtomKind
  priv text : String
  priv start : Int32
  priv end : Int32
}

///|
#derive(Debug)
pub(all) enum WgslTypeArgument {
  Type(WgslTypeRef)
  Expression(WgslExprRef)
}

///|
pub fn WgslTypeAtom::WgslTypeAtom(
  kind : WgslTypeAtomKind,
  text : String,
  start : Int32,
  end : Int32,
) -> WgslTypeAtom {
  { kind, text, start, end, }
}

///|
pub fn WgslTypeAtom::kind(self : WgslTypeAtom) -> WgslTypeAtomKind {
  self.kind
}

///|
fn WgslTypeAtom::text(self : WgslTypeAtom) -> String {
  self.text
}

///|
pub fn WgslTypeAtom::start(self : WgslTypeAtom) -> Int32 {
  self.start
}

///|
pub fn WgslTypeAtom::end(self : WgslTypeAtom) -> Int32 {
  self.end
}

///|
pub fn WgslTypeAtom::identifier(self : WgslTypeAtom) -> WgslIdent? {
  match self.kind {
    Identifier => Some(WgslIdent(self.text, self.start, self.end))
    Numeric | Unknown => None
  }
}

///|
#derive(Debug)
pub struct WgslTypeRef {
  priv atom : WgslTypeAtom
  priv arguments : Array[WgslTypeRef]
  priv template_arguments : Array[WgslTypeArgument]
  priv start : Int32
  priv end : Int32
}

///|
pub fn WgslTypeRef::WgslTypeRef(
  atom : WgslTypeAtom,
  arguments : Array[WgslTypeRef],
  start : Int32,
  end : Int32,
) -> WgslTypeRef {
  let template_arguments : Array[WgslTypeArgument] = []
  for argument in arguments {
    template_arguments.push(Type(argument))
  }
  { atom, arguments, template_arguments, start, end, }
}

///|
pub fn WgslTypeRef::new_with_template_arguments(
  atom : WgslTypeAtom,
  template_arguments : Array[WgslTypeArgument],
  start : Int32,
  end : Int32,
) -> WgslTypeRef {
  let arguments : Array[WgslTypeRef] = []
  for argument in template_arguments {
    match argument {
      Type(ty) => arguments.push(ty)
      Expression(_) => ()
    }
  }
  { atom, arguments, template_arguments, start, end, }
}

///|
pub fn WgslTypeRef::atom(self : WgslTypeRef) -> WgslTypeAtom {
  self.atom
}

///|
pub fn WgslTypeRef::name(self : WgslTypeRef) -> String {
  self.atom.text()
}

///|
pub fn WgslTypeRef::arguments(self : WgslTypeRef) -> Array[WgslTypeRef] {
  self.arguments.copy()
}

///|
pub fn WgslTypeRef::template_arguments(
  self : WgslTypeRef,
) -> Array[WgslTypeArgument] {
  self.template_arguments.copy()
}

///|
fn wgsl_type_argument_canonical_text(argument : WgslTypeArgument) -> String {
  match argument {
    Type(ty) => ty.canonical_text()
    Expression(expr) => {
      let parts : Array[String] = []
      for token in expr.tokens() {
        parts.push(token.text())
      }
      parts.join(" ")
    }
  }
}

///|
pub fn WgslTypeRef::canonical_text(self : WgslTypeRef) -> String {
  if self.template_arguments.length() == 0 {
    return self.name()
  }
  let argument_texts : Array[String] = []
  for argument in self.template_arguments {
    argument_texts.push(wgsl_type_argument_canonical_text(argument))
  }
  let joined_arguments = argument_texts.join(", ")
  "\{self.name()}<\{joined_arguments}>"
}

///|
pub fn WgslTypeRef::start(self : WgslTypeRef) -> Int32 {
  self.start
}

///|
pub fn WgslTypeRef::end(self : WgslTypeRef) -> Int32 {
  self.end
}

///|
#derive(Debug)
pub struct WgslFunctionArgument {
  priv attributes : Array[WgslAttribute]
  priv name : WgslIdent
  priv start : Int32
  priv end : Int32
  priv ty_ref : WgslTypeRef?
}

///|
pub fn WgslFunctionArgument::WgslFunctionArgument(
  attributes : Array[WgslAttribute],
  name : WgslIdent,
  start : Int32,
  end : Int32,
  ty_ref : WgslTypeRef?,
) -> WgslFunctionArgument {
  { attributes, name, start, end, ty_ref, }
}

///|
pub fn WgslFunctionArgument::attributes(
  self : WgslFunctionArgument,
) -> Array[WgslAttribute] {
  self.attributes.copy()
}

///|
pub fn WgslFunctionArgument::name(self : WgslFunctionArgument) -> WgslIdent {
  self.name
}

///|
pub fn WgslFunctionArgument::start(self : WgslFunctionArgument) -> Int32 {
  self.start
}

///|
pub fn WgslFunctionArgument::end(self : WgslFunctionArgument) -> Int32 {
  self.end
}

///|
pub fn WgslFunctionArgument::ty_ref(
  self : WgslFunctionArgument,
) -> WgslTypeRef? {
  self.ty_ref
}

///|
#derive(Debug)
pub struct WgslFunctionResult {
  priv attributes : Array[WgslAttribute]
  priv start : Int32
  priv end : Int32
  priv ty_ref : WgslTypeRef?
}

///|
pub fn WgslFunctionResult::WgslFunctionResult(
  attributes : Array[WgslAttribute],
  start : Int32,
  end : Int32,
  ty_ref : WgslTypeRef?,
) -> WgslFunctionResult {
  { attributes, start, end, ty_ref, }
}

///|
pub fn WgslFunctionResult::attributes(
  self : WgslFunctionResult,
) -> Array[WgslAttribute] {
  self.attributes.copy()
}

///|
pub fn WgslFunctionResult::start(self : WgslFunctionResult) -> Int32 {
  self.start
}

///|
pub fn WgslFunctionResult::end(self : WgslFunctionResult) -> Int32 {
  self.end
}

///|
pub fn WgslFunctionResult::ty_ref(self : WgslFunctionResult) -> WgslTypeRef? {
  self.ty_ref
}

///|
#derive(Eq, Debug)
pub(all) enum WgslStatementKind {
  Empty
  LocalDeclaration
  Return
  If
  For
  While
  Loop
  Continuing
  Switch
  Case
  DefaultCase
  Break
  Continue
  Discard
  ConstAssert
  Compound
  Assignment
  Increment
  Decrement
  FunctionCall
  Expression
}

///|
#derive(Eq, Debug)
pub(all) enum WgslLocalDeclarationKind {
  Var
  Let
  Const
}

///|
#derive(Debug)
pub struct WgslLocalDeclaration {
  priv kind : WgslLocalDeclarationKind
  priv name : WgslIdent
  priv template_list : Array[WgslTypeRef]
  priv ty_ref : WgslTypeRef?
  priv initializer_ref : WgslExprRef?
}

///|
pub fn WgslLocalDeclaration::WgslLocalDeclaration(
  kind : WgslLocalDeclarationKind,
  name : WgslIdent,
  template_list : Array[WgslTypeRef],
  ty_ref : WgslTypeRef?,
  initializer_ref : WgslExprRef?,
) -> WgslLocalDeclaration {
  { kind, name, template_list, ty_ref, initializer_ref, }
}

///|
pub fn WgslLocalDeclaration::kind(
  self : WgslLocalDeclaration,
) -> WgslLocalDeclarationKind {
  self.kind
}

///|
pub fn WgslLocalDeclaration::name(self : WgslLocalDeclaration) -> WgslIdent {
  self.name
}

///|
pub fn WgslLocalDeclaration::template_list(
  self : WgslLocalDeclaration,
) -> Array[WgslTypeRef] {
  self.template_list.copy()
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
#derive(Eq, Debug)
pub(all) enum WgslStatementExpressionRole {
  Condition
  ReturnValue
  ForHeader
  ForInitializer
  ForCondition
  ForUpdate
  SwitchSelector
  CaseSelector
  BreakIf
  ConstAssertValue
  AssignmentLhs
  AssignmentRhs
  UpdateTarget
  FunctionCallValue
  ExpressionValue
}

///|
#derive(Debug)
pub struct WgslStatementExpression {
  priv role : WgslStatementExpressionRole
  priv expression : WgslExprRef
}

///|
pub fn WgslStatementExpression::WgslStatementExpression(
  role : WgslStatementExpressionRole,
  expression : WgslExprRef,
) -> WgslStatementExpression {
  { role, expression, }
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
#derive(Debug)
pub(all) enum WgslCaseSelector {
  DefaultSelector
  ExpressionSelector(WgslExprRef)
}

///|
pub fn WgslCaseSelector::expression(self : WgslCaseSelector) -> WgslExprRef? {
  match self {
    DefaultSelector => None
    ExpressionSelector(expr) => Some(expr)
  }
}

///|
#derive(Debug)
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
  Case(Array[WgslCaseSelector])
  DefaultCase
  Assignment(String, WgslExprRef?, WgslExprRef?)
  Increment(WgslExprRef?)
  Decrement(WgslExprRef?)
  FunctionCall(WgslExprRef?)
  Expression(WgslExprRef?)
}

///|
#derive(Debug)
pub struct WgslStatement {
  priv kind : WgslStatementKind
  priv attributes : Array[WgslAttribute]
  priv payload : WgslStatementPayload
  priv blocks : Array[WgslBlock]
  priv local_bindings : Array[WgslLocalDeclaration]
  priv exported_local_bindings : Array[WgslLocalDeclaration]
  priv expression_refs : Array[WgslExprRef]
  priv expressions : Array[WgslStatementExpression]
  priv invalid_expression : Bool
}

///|
pub fn WgslStatement::WgslStatement(
  kind : WgslStatementKind,
  attributes : Array[WgslAttribute],
  payload : WgslStatementPayload,
  blocks : Array[WgslBlock],
  local_bindings : Array[WgslLocalDeclaration],
  exported_local_bindings : Array[WgslLocalDeclaration],
  expression_refs : Array[WgslExprRef],
  expressions : Array[WgslStatementExpression],
  invalid_expression : Bool,
) -> WgslStatement {
  {
    kind,
    attributes,
    payload,
    blocks,
    local_bindings,
    exported_local_bindings,
    expression_refs,
    expressions,
    invalid_expression,
  }
}

///|
pub fn WgslStatement::kind(self : WgslStatement) -> WgslStatementKind {
  self.kind
}

///|
pub fn WgslStatement::attributes(self : WgslStatement) -> Array[WgslAttribute] {
  self.attributes.copy()
}

///|
pub fn WgslStatement::payload(self : WgslStatement) -> WgslStatementPayload {
  self.payload
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
pub fn WgslStatement::has_invalid_expression(self : WgslStatement) -> Bool {
  self.invalid_expression
}

///|
#derive(Debug)
pub struct WgslBlock {
  priv start : Int32
  priv end : Int32
  priv statements : Array[WgslStatement]
}

///|
pub fn WgslBlock::WgslBlock(
  start : Int32,
  end : Int32,
  statements : Array[WgslStatement],
) -> WgslBlock {
  { start, end, statements, }
}

///|
pub fn WgslBlock::start(self : WgslBlock) -> Int32 {
  self.start
}

///|
pub fn WgslBlock::end(self : WgslBlock) -> Int32 {
  self.end
}

///|
pub fn WgslBlock::statements(self : WgslBlock) -> Array[WgslStatement] {
  self.statements.copy()
}

///|
#derive(Eq, Debug)
pub(all) enum WgslFunctionQualifier {
  Virtual
  Override
}

///|
#derive(Debug)
pub struct WgslFunction {
  priv attributes : Array[WgslAttribute]
  priv qualifier : WgslFunctionQualifier?
  priv qualifier_start : Int32?
  priv qualifier_end : Int32?
  priv fn_start : Int32
  priv fn_end : Int32
  priv name : WgslIdent
  priv arguments : Array[WgslFunctionArgument]
  priv result : WgslFunctionResult?
  priv body_attributes : Array[WgslAttribute]
  priv body : WgslBlock
}

///|
pub fn WgslFunction::WgslFunction(
  attributes : Array[WgslAttribute],
  qualifier : WgslFunctionQualifier?,
  qualifier_start : Int32?,
  qualifier_end : Int32?,
  fn_start : Int32,
  fn_end : Int32,
  name : WgslIdent,
  arguments : Array[WgslFunctionArgument],
  result : WgslFunctionResult?,
  body_attributes : Array[WgslAttribute],
  body : WgslBlock,
) -> WgslFunction {
  {
    attributes,
    qualifier,
    qualifier_start,
    qualifier_end,
    fn_start,
    fn_end,
    name,
    arguments,
    result,
    body_attributes,
    body,
  }
}

///|
pub fn WgslFunction::attributes(self : WgslFunction) -> Array[WgslAttribute] {
  self.attributes.copy()
}

///|
pub fn WgslFunction::qualifier(self : WgslFunction) -> WgslFunctionQualifier? {
  self.qualifier
}

///|
pub fn WgslFunction::qualifier_start(self : WgslFunction) -> Int32? {
  self.qualifier_start
}

///|
pub fn WgslFunction::qualifier_end(self : WgslFunction) -> Int32? {
  self.qualifier_end
}

///|
pub fn WgslFunction::fn_start(self : WgslFunction) -> Int32 {
  self.fn_start
}

///|
pub fn WgslFunction::fn_end(self : WgslFunction) -> Int32 {
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
pub fn WgslFunction::body_attributes(
  self : WgslFunction,
) -> Array[WgslAttribute] {
  self.body_attributes.copy()
}

///|
pub fn WgslFunction::body(self : WgslFunction) -> WgslBlock {
  self.body
}

///|
#derive(Debug)
pub struct WgslStructMember {
  priv attributes : Array[WgslAttribute]
  priv name : WgslIdent
  priv start : Int32
  priv end : Int32
  priv ty_ref : WgslTypeRef?
}

///|
pub fn WgslStructMember::WgslStructMember(
  attributes : Array[WgslAttribute],
  name : WgslIdent,
  start : Int32,
  end : Int32,
  ty_ref : WgslTypeRef?,
) -> WgslStructMember {
  { attributes, name, start, end, ty_ref, }
}

///|
pub fn WgslStructMember::attributes(
  self : WgslStructMember,
) -> Array[WgslAttribute] {
  self.attributes.copy()
}

///|
pub fn WgslStructMember::name(self : WgslStructMember) -> WgslIdent {
  self.name
}

///|
pub fn WgslStructMember::start(self : WgslStructMember) -> Int32 {
  self.start
}

///|
pub fn WgslStructMember::end(self : WgslStructMember) -> Int32 {
  self.end
}

///|
pub fn WgslStructMember::ty_ref(self : WgslStructMember) -> WgslTypeRef? {
  self.ty_ref
}

///|
#derive(Debug)
pub struct WgslStruct {
  priv attributes : Array[WgslAttribute]
  priv name : WgslIdent
  priv members : Array[WgslStructMember]
}

///|
pub fn WgslStruct::WgslStruct(
  attributes : Array[WgslAttribute],
  name : WgslIdent,
  members : Array[WgslStructMember],
) -> WgslStruct {
  { attributes, name, members, }
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
#derive(Debug)
pub struct WgslGlobalVariable {
  priv attributes : Array[WgslAttribute]
  priv name : WgslIdent
  priv template_list : Array[WgslTypeRef]
  priv ty_ref : WgslTypeRef?
  priv initializer_ref : WgslExprRef?
}

///|
pub fn WgslGlobalVariable::WgslGlobalVariable(
  attributes : Array[WgslAttribute],
  name : WgslIdent,
  template_list : Array[WgslTypeRef],
  ty_ref : WgslTypeRef?,
  initializer_ref : WgslExprRef?,
) -> WgslGlobalVariable {
  { attributes, name, template_list, ty_ref, initializer_ref, }
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
) -> Array[WgslTypeRef] {
  self.template_list.copy()
}

///|
pub fn WgslGlobalVariable::ty_ref(self : WgslGlobalVariable) -> WgslTypeRef? {
  self.ty_ref
}

///|
pub fn WgslGlobalVariable::initializer_ref(
  self : WgslGlobalVariable,
) -> WgslExprRef? {
  self.initializer_ref
}

///|
#derive(Debug)
pub struct WgslConst {
  priv name : WgslIdent
  priv ty_ref : WgslTypeRef?
  priv initializer_ref : WgslExprRef?
}

///|
pub fn WgslConst::WgslConst(
  name : WgslIdent,
  ty_ref : WgslTypeRef?,
  initializer_ref : WgslExprRef?,
) -> WgslConst {
  { name, ty_ref, initializer_ref, }
}

///|
pub fn WgslConst::name(self : WgslConst) -> WgslIdent {
  self.name
}

///|
pub fn WgslConst::ty_ref(self : WgslConst) -> WgslTypeRef? {
  self.ty_ref
}

///|
pub fn WgslConst::initializer_ref(self : WgslConst) -> WgslExprRef? {
  self.initializer_ref
}

///|
#derive(Debug)
pub struct WgslOverride {
  priv attributes : Array[WgslAttribute]
  priv name : WgslIdent
  priv ty_ref : WgslTypeRef?
  priv initializer_ref : WgslExprRef?
}

///|
pub fn WgslOverride::WgslOverride(
  attributes : Array[WgslAttribute],
  name : WgslIdent,
  ty_ref : WgslTypeRef?,
  initializer_ref : WgslExprRef?,
) -> WgslOverride {
  { attributes, name, ty_ref, initializer_ref, }
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
pub fn WgslOverride::ty_ref(self : WgslOverride) -> WgslTypeRef? {
  self.ty_ref
}

///|
pub fn WgslOverride::initializer_ref(self : WgslOverride) -> WgslExprRef? {
  self.initializer_ref
}

///|
#derive(Debug)
pub struct WgslTypeAlias {
  priv name : WgslIdent
  priv ty_ref : WgslTypeRef?
}

///|
pub fn WgslTypeAlias::WgslTypeAlias(
  name : WgslIdent,
  ty_ref : WgslTypeRef?,
) -> WgslTypeAlias {
  { name, ty_ref, }
}

///|
pub fn WgslTypeAlias::name(self : WgslTypeAlias) -> WgslIdent {
  self.name
}

///|
pub fn WgslTypeAlias::ty_ref(self : WgslTypeAlias) -> WgslTypeRef? {
  self.ty_ref
}

///|
#derive(Debug)
pub(all) enum WgslGlobalDeclData {
  Directive(WgslDirective)
  Function(WgslFunction)
  GlobalVariable(WgslGlobalVariable)
  Const(WgslConst)
  Override(WgslOverride)
  Struct(WgslStruct)
  TypeAlias(WgslTypeAlias)
  ConstAssert(WgslExprRef)
  Raw
}

///|
#derive(Debug)
pub struct WgslGlobalDecl {
  priv kind : WgslGlobalDeclKind
  priv data : WgslGlobalDeclData
  priv start : Int32
  priv end : Int32
}

///|
pub fn WgslGlobalDecl::WgslGlobalDecl(
  kind : WgslGlobalDeclKind,
  data : WgslGlobalDeclData,
  start : Int32,
  end : Int32,
) -> WgslGlobalDecl {
  { kind, data, start, end, }
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
fn wgsl_decl_data_name(data : WgslGlobalDeclData) -> String {
  match data {
    Function(function) => function.name().name()
    GlobalVariable(global) => global.name().name()
    Const(value) => value.name().name()
    Override(value) => value.name().name()
    Struct(value) => value.name().name()
    TypeAlias(value) => value.name().name()
    Directive(_) | ConstAssert(_) | Raw => ""
  }
}

///|
pub fn WgslGlobalDecl::name(self : WgslGlobalDecl) -> String {
  wgsl_decl_data_name(self.data)
}

///|
pub fn WgslGlobalDecl::start(self : WgslGlobalDecl) -> Int32 {
  self.start
}

///|
pub fn WgslGlobalDecl::end(self : WgslGlobalDecl) -> Int32 {
  self.end
}

///|
#derive(Debug)
pub struct WgslTranslationUnit {
  priv declarations : Array[WgslGlobalDecl]
}

///|
pub fn WgslTranslationUnit::WgslTranslationUnit(
  declarations : Array[WgslGlobalDecl],
) -> WgslTranslationUnit {
  { declarations, }
}

///|
pub fn WgslTranslationUnit::declarations(
  self : WgslTranslationUnit,
) -> Array[WgslGlobalDecl] {
  self.declarations.copy()
}

///|
pub extend WgslAttribute with Debug::{to_repr}

///|
pub extend WgslBlock with Debug::{to_repr}

///|
pub extend WgslCaseSelector with Debug::{to_repr}

///|
pub extend WgslConst with Debug::{to_repr}

///|
pub extend WgslDirective with Debug::{to_repr}

///|
pub extend WgslDirectiveKind with Debug::{to_repr}

///|
pub extend WgslDirectiveKind with Eq::{not_equal, equal}

///|
pub extend WgslDirectiveTail with Debug::{to_repr}

///|
pub extend WgslExprNode with Debug::{to_repr}

///|
pub extend WgslExprNodeKind with Debug::{to_repr}

///|
pub extend WgslExprOperator with Debug::{to_repr}

///|
pub extend WgslExprOperator with Eq::{not_equal, equal}

///|
pub extend WgslExprRef with Debug::{to_repr}

///|
pub extend WgslExprToken with Debug::{to_repr}

///|
pub extend WgslExprTokenKind with Debug::{to_repr}

///|
pub extend WgslFunction with Debug::{to_repr}

///|
pub extend WgslFunctionArgument with Debug::{to_repr}

///|
pub extend WgslFunctionQualifier with Debug::{to_repr}

///|
pub extend WgslFunctionQualifier with Eq::{not_equal, equal}

///|
pub extend WgslFunctionResult with Debug::{to_repr}

///|
pub extend WgslGlobalDecl with Debug::{to_repr}

///|
pub extend WgslGlobalDeclData with Debug::{to_repr}

///|
pub extend WgslGlobalDeclKind with Debug::{to_repr}

///|
pub extend WgslGlobalDeclKind with Eq::{not_equal, equal}

///|
pub extend WgslGlobalVariable with Debug::{to_repr}

///|
pub extend WgslIdent with Debug::{to_repr}

///|
pub extend WgslLocalDeclaration with Debug::{to_repr}

///|
pub extend WgslLocalDeclarationKind with Debug::{to_repr}

///|
pub extend WgslLocalDeclarationKind with Eq::{not_equal, equal}

///|
pub extend WgslNumericLiteral with Debug::{to_repr}

///|
pub extend WgslNumericLiteral with Eq::{not_equal, equal}

///|
pub extend WgslNumericLiteralBase with Debug::{to_repr}

///|
pub extend WgslNumericLiteralBase with Eq::{not_equal, equal}

///|
pub extend WgslNumericLiteralCategory with Debug::{to_repr}

///|
pub extend WgslNumericLiteralCategory with Eq::{not_equal, equal}

///|
pub extend WgslNumericLiteralSuffix with Debug::{to_repr}

///|
pub extend WgslNumericLiteralSuffix with Eq::{not_equal, equal}

///|
pub extend WgslOverride with Debug::{to_repr}

///|
pub extend WgslStatement with Debug::{to_repr}

///|
pub extend WgslStatementExpression with Debug::{to_repr}

///|
pub extend WgslStatementExpressionRole with Debug::{to_repr}

///|
pub extend WgslStatementExpressionRole with Eq::{not_equal, equal}

///|
pub extend WgslStatementKind with Debug::{to_repr}

///|
pub extend WgslStatementKind with Eq::{not_equal, equal}

///|
pub extend WgslStatementPayload with Debug::{to_repr}

///|
pub extend WgslStruct with Debug::{to_repr}

///|
pub extend WgslStructMember with Debug::{to_repr}

///|
pub extend WgslTranslationUnit with Debug::{to_repr}

///|
pub extend WgslTypeAlias with Debug::{to_repr}

///|
pub extend WgslTypeArgument with Debug::{to_repr}

///|
pub extend WgslTypeAtom with Debug::{to_repr}

///|
pub extend WgslTypeAtomKind with Debug::{to_repr}

///|
pub extend WgslTypeAtomKind with Eq::{not_equal, equal}

///|
pub extend WgslTypeRef with Debug::{to_repr}
