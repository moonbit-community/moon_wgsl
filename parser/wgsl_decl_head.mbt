///|
priv enum WgslDeclHeadKind {
  Function
  GlobalVariable
  Struct
  Const
  Override
  TypeAlias
  ConstAssert
  SourceDirective
  Raw
}

///|
priv struct WgslDeclHead {
  kind : WgslDeclHeadKind
  attributes : Array[WgslAttribute]
  keyword : WgslIdent?
  qualifier : WgslFunctionQualifier?
  qualifier_start : Int?
  qualifier_end : Int?
  fn_keyword : WgslIdent?
  consumed : Int
}

///|
fn WgslDeclHead::raw(attributes : Array[WgslAttribute]) -> WgslDeclHead {
  WgslDeclHead::{
    kind: Raw,
    attributes,
    keyword: None,
    qualifier: None,
    qualifier_start: None,
    qualifier_end: None,
    fn_keyword: None,
    consumed: 0,
  }
}
