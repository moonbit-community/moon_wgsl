///|
pub(all) enum WgslDeclHeadKind {
  Function
  GlobalVariable
  Struct
  Const
  Override
  TypeAlias
  ConstAssert
  SourceDirective(WgslDirectiveKind)
  Raw
} derive(Debug)

///|
pub(all) struct WgslDeclHead {
  kind : WgslDeclHeadKind
  attributes : Array[WgslAttribute]
  keyword : WgslIdent?
  qualifier : String
  qualifier_start : Int?
  qualifier_end : Int?
  fn_keyword : WgslIdent?
  consumed : Int
} derive(Debug)

///|
pub fn WgslDeclHead::raw(attributes : Array[WgslAttribute]) -> WgslDeclHead {
  WgslDeclHead::{
    kind: Raw,
    attributes,
    keyword: None,
    qualifier: "",
    qualifier_start: None,
    qualifier_end: None,
    fn_keyword: None,
    consumed: 0,
  }
}
