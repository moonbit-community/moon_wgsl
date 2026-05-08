///|
priv enum WgslRawTopLevelKind {
  Trivia
  Import
  DefineImportPath
  Define
  Directive
  Declaration
}

///|
priv struct WgslRawTopLevelItem {
  kind : WgslRawTopLevelKind
  start : Int
  end : Int
}
