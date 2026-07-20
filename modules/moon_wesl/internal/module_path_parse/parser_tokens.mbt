///|
pub(all) enum Token {
  SEGMENT(String)
  PACKAGE
  SELF
  SUPER
  DOUBLE_COLON
} derive(Debug)

///|
pub fn Token::kind(self : Token) -> TokenKind {
  match self {
    SEGMENT(_) => TK_SEGMENT
    PACKAGE => TK_PACKAGE
    SELF => TK_SELF
    SUPER => TK_SUPER
    DOUBLE_COLON => TK_DOUBLE_COLON
  }
}

///|
pub(all) enum TokenKind {
  TK_SEGMENT
  TK_PACKAGE
  TK_SELF
  TK_SUPER
  TK_DOUBLE_COLON
}

///|
pub impl Show for TokenKind with fn output(self, logger) {
  logger.write_string(
    match self {
      TK_SEGMENT => "SEGMENT"
      TK_PACKAGE => "\"package\""
      TK_SELF => "\"self\""
      TK_SUPER => "\"super\""
      TK_DOUBLE_COLON => "\"::\""
    },
  )
}

///|
pub impl Debug for TokenKind with fn to_repr(self) {
  match self {
    TK_SEGMENT => to_repr("SEGMENT")
    TK_PACKAGE => to_repr("package")
    TK_SELF => to_repr("self")
    TK_SUPER => to_repr("super")
    TK_DOUBLE_COLON => to_repr("::")
  }
}
