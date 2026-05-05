///|
priv enum WgslRawTopLevelKind {
  Trivia
  Import
  DefineImportPath
  Define
  Directive
  Declaration
} derive(Debug)

///|
priv struct WgslRawTopLevelItem {
  kind : WgslRawTopLevelKind
  text : String
  start : Int
  end : Int
} derive(Debug)
