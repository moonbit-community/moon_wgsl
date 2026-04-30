///|
pub(all) enum WgslRawTopLevelKind {
  Trivia
  Import
  DefineImportPath
  Define
  Directive
  Declaration
} derive(Eq, Debug)

///|
pub(all) struct WgslRawTopLevelItem {
  kind : WgslRawTopLevelKind
  name : String
  text : String
  start : Int
  end : Int
} derive(Debug)
