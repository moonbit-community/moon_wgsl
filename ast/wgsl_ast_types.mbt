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
pub fn WgslDirective::new(
  kind : WgslDirectiveKind,
  name : String,
  tail : String,
  text : String,
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
    text,
    start,
    end,
    name_start,
    name_end,
    tail_start,
    tail_end,
  }
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
  Punctuation(Int)
  Unknown
} derive(Debug)

///|
pub struct WgslExprToken {
  kind : WgslExprTokenKind
  text : String
  start : Int
  end : Int
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
pub struct WgslExprRef {
  text : String
  tokens : Array[WgslExprToken]
  identifiers : Array[WgslIdent]
  start : Int
  end : Int
} derive(Debug)

///|
pub fn WgslExprRef::new(
  text : String,
  tokens : Array[WgslExprToken],
  identifiers : Array[WgslIdent],
  start : Int,
  end : Int,
) -> WgslExprRef {
  WgslExprRef::{ text, tokens, identifiers, start, end }
}

///|
pub struct WgslAttribute {
  name : String
  start : Int
  end : Int
  name_start : Int
  name_end : Int
  arguments : String
  arguments_ref : WgslExprRef?
} derive(Debug)

///|
pub fn WgslAttribute::new(
  name : String,
  start : Int,
  end : Int,
  name_start : Int,
  name_end : Int,
  arguments : String,
  arguments_ref : WgslExprRef?,
) -> WgslAttribute {
  WgslAttribute::{
    name,
    start,
    end,
    name_start,
    name_end,
    arguments,
    arguments_ref,
  }
}

///|
pub struct WgslTypeRef {
  name : String
  arguments : Array[WgslTypeRef]
  text : String
  start : Int
  end : Int
} derive(Debug)

///|
pub fn WgslTypeRef::new(
  name : String,
  arguments : Array[WgslTypeRef],
  text : String,
  start : Int,
  end : Int,
) -> WgslTypeRef {
  WgslTypeRef::{ name, arguments, text, start, end }
}

///|
pub struct WgslFunctionArgument {
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
pub fn WgslFunctionArgument::new(
  attributes : Array[WgslAttribute],
  name : String,
  start : Int,
  end : Int,
  name_start : Int,
  name_end : Int,
  ty : String,
  ty_ref : WgslTypeRef?,
) -> WgslFunctionArgument {
  WgslFunctionArgument::{
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
pub struct WgslFunctionResult {
  attributes : Array[WgslAttribute]
  start : Int
  end : Int
  ty : String
  ty_ref : WgslTypeRef?
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
  kind : String
  name : WgslIdent
  template_list : Array[String]
  ty : String?
  ty_ref : WgslTypeRef?
  initializer : String?
  initializer_ref : WgslExprRef?
} derive(Debug)

///|
pub fn WgslLocalDeclaration::new(
  kind : String,
  name : WgslIdent,
  template_list : Array[String],
  ty : String?,
  ty_ref : WgslTypeRef?,
  initializer : String?,
  initializer_ref : WgslExprRef?,
) -> WgslLocalDeclaration {
  WgslLocalDeclaration::{
    kind,
    name,
    template_list,
    ty,
    ty_ref,
    initializer,
    initializer_ref,
  }
}

///|
pub struct WgslStatement {
  kind : WgslStatementKind
  text : String
  start : Int
  end : Int
  blocks : Array[WgslBlock]
  local_bindings : Array[WgslLocalDeclaration]
  local_declarations : Array[WgslIdent]
  exported_locals : Array[WgslIdent]
  identifiers : Array[WgslIdent]
} derive(Debug)

///|
pub fn WgslStatement::new(
  kind : WgslStatementKind,
  text : String,
  start : Int,
  end : Int,
  blocks : Array[WgslBlock],
  local_bindings : Array[WgslLocalDeclaration],
  local_declarations : Array[WgslIdent],
  exported_locals : Array[WgslIdent],
  identifiers : Array[WgslIdent],
) -> WgslStatement {
  WgslStatement::{
    kind,
    text,
    start,
    end,
    blocks,
    local_bindings,
    local_declarations,
    exported_locals,
    identifiers,
  }
}

///|
pub struct WgslBlock {
  start : Int
  end : Int
  statements : Array[WgslStatement]
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
pub struct WgslFunction {
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
pub struct WgslStructMember {
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
pub struct WgslStruct {
  attributes : Array[WgslAttribute]
  name : WgslIdent
  members : Array[WgslStructMember]
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
pub struct WgslGlobalVariable {
  attributes : Array[WgslAttribute]
  name : WgslIdent
  template_list : Array[String]
  ty : String?
  ty_ref : WgslTypeRef?
  initializer : String?
  initializer_ref : WgslExprRef?
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
pub struct WgslConst {
  name : WgslIdent
  ty : String?
  ty_ref : WgslTypeRef?
  initializer : String?
  initializer_ref : WgslExprRef?
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
pub struct WgslOverride {
  attributes : Array[WgslAttribute]
  name : WgslIdent
  ty : String?
  ty_ref : WgslTypeRef?
  initializer : String?
  initializer_ref : WgslExprRef?
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
pub struct WgslTypeAlias {
  name : WgslIdent
  ty : String
  ty_ref : WgslTypeRef?
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
  kind : WgslGlobalDeclKind
  data : WgslGlobalDeclData
  name : String
  text : String
  start : Int
  end : Int
} derive(Debug)

///|
pub fn WgslGlobalDecl::new(
  kind : WgslGlobalDeclKind,
  data : WgslGlobalDeclData,
  name : String,
  text : String,
  start : Int,
  end : Int,
) -> WgslGlobalDecl {
  WgslGlobalDecl::{ kind, data, name, text, start, end }
}

///|
pub struct WgslTranslationUnit {
  declarations : Array[WgslGlobalDecl]
} derive(Debug)

///|
pub fn WgslTranslationUnit::new(
  declarations : Array[WgslGlobalDecl],
) -> WgslTranslationUnit {
  WgslTranslationUnit::{ declarations, }
}
