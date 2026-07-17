///|
priv enum WgslRawTopLevelKind {
  Trivia
  Declaration
}

///|
priv struct WgslRawTopLevelItem {
  kind : WgslRawTopLevelKind
  start : Int
  end : Int
}
