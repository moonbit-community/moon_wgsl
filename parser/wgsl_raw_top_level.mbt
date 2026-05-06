///|
pub(all) enum WgslRawTopLevelKind {
  Trivia
  Import
  DefineImportPath
  Define
  Directive
  Declaration
} derive(Debug)

///|
pub struct WgslRawTopLevelItem {
  kind : WgslRawTopLevelKind
  text : String
  start : Int
  end : Int
} derive(Debug)
