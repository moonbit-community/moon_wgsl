///|
pub(all) struct WgslSpan {
  start : Int
  end : Int
} derive(Eq, Debug)

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
pub(all) struct WgslDirective {
  kind : WgslDirectiveKind
  name : String
  tail : String
  text : String
  start : Int
  end : Int
  name_start : Int
  name_end : Int
  tail_start : Int
  tail_end : Int
} derive(Debug)

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
pub(all) struct WgslIdent {
  name : String
  start : Int
  end : Int
} derive(Debug)

///|
pub(all) struct WgslExprRef {
  text : String
  identifiers : Array[WgslIdent]
  start : Int
  end : Int
} derive(Debug)

///|
pub(all) struct WgslAttribute {
  name : String
  start : Int
  end : Int
  name_start : Int
  name_end : Int
  arguments : String
  arguments_ref : WgslExprRef?
} derive(Debug)

///|
pub(all) struct WgslTypeRef {
  name : String
  arguments : Array[WgslTypeRef]
  text : String
  start : Int
  end : Int
} derive(Debug)

///|
pub(all) struct WgslFunctionArgument {
  attributes : Array[WgslAttribute]
  name : String
  start : Int
  end : Int
  name_start : Int
  name_end : Int
  ty : String
  ty_ref : WgslTypeRef?
} derive(Debug)

///|
pub(all) struct WgslFunctionResult {
  attributes : Array[WgslAttribute]
  start : Int
  end : Int
  ty : String
  ty_ref : WgslTypeRef?
} derive(Debug)

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
pub(all) struct WgslStatement {
  kind : WgslStatementKind
  text : String
  start : Int
  end : Int
  local_declarations : Array[WgslIdent]
  exported_locals : Array[WgslIdent]
  identifiers : Array[WgslIdent]
} derive(Debug)

///|
pub(all) struct WgslBlock {
  start : Int
  end : Int
  statements : Array[WgslStatement]
} derive(Debug)

///|
pub(all) struct WgslFunction {
  attributes : Array[WgslAttribute]
  qualifier : String
  qualifier_start : Int?
  qualifier_end : Int?
  fn_start : Int
  fn_end : Int
  name : WgslIdent
  arguments : Array[WgslFunctionArgument]
  result : WgslFunctionResult?
  body : WgslBlock
} derive(Debug)

///|
pub(all) struct WgslStructMember {
  attributes : Array[WgslAttribute]
  name : String
  start : Int
  end : Int
  name_start : Int
  name_end : Int
  ty : String
  ty_ref : WgslTypeRef?
} derive(Debug)

///|
pub(all) struct WgslStruct {
  attributes : Array[WgslAttribute]
  name : WgslIdent
  members : Array[WgslStructMember]
} derive(Debug)

///|
pub(all) struct WgslGlobalVariable {
  attributes : Array[WgslAttribute]
  name : WgslIdent
  template_list : Array[String]
  ty : String?
  ty_ref : WgslTypeRef?
  initializer : String?
  initializer_ref : WgslExprRef?
} derive(Debug)

///|
pub(all) struct WgslConst {
  name : WgslIdent
  ty : String?
  ty_ref : WgslTypeRef?
  initializer : String?
  initializer_ref : WgslExprRef?
} derive(Debug)

///|
pub(all) struct WgslOverride {
  attributes : Array[WgslAttribute]
  name : WgslIdent
  ty : String?
  ty_ref : WgslTypeRef?
  initializer : String?
  initializer_ref : WgslExprRef?
} derive(Debug)

///|
pub(all) struct WgslTypeAlias {
  name : WgslIdent
  ty : String
  ty_ref : WgslTypeRef?
} derive(Debug)

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
pub(all) struct WgslGlobalDecl {
  kind : WgslGlobalDeclKind
  data : WgslGlobalDeclData
  name : String
  text : String
  start : Int
  end : Int
} derive(Debug)

///|
pub(all) struct WgslTranslationUnit {
  declarations : Array[WgslGlobalDecl]
} derive(Debug)
