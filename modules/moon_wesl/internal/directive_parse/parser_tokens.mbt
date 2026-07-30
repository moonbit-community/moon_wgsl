///|
pub(all) enum Token {
  ITEM(String)
  ENABLE
  REQUIRES
  DIAGNOSTIC
  LEFT_PAREN
  RIGHT_PAREN
  COMMA
  SEMI
} derive(Debug)

///|
pub fn Token::kind(self : Token) -> TokenKind {
  match self {
    ITEM(_) => TK_ITEM
    ENABLE => TK_ENABLE
    REQUIRES => TK_REQUIRES
    DIAGNOSTIC => TK_DIAGNOSTIC
    LEFT_PAREN => TK_LEFT_PAREN
    RIGHT_PAREN => TK_RIGHT_PAREN
    COMMA => TK_COMMA
    SEMI => TK_SEMI
  }
}

///|
pub(all) enum TokenKind {
  TK_ITEM
  TK_ENABLE
  TK_REQUIRES
  TK_DIAGNOSTIC
  TK_LEFT_PAREN
  TK_RIGHT_PAREN
  TK_COMMA
  TK_SEMI
}

///|
pub impl Show for TokenKind with fn output(self, logger) {
  logger.write_string(
    match self {
      TK_ITEM => "ITEM"
      TK_ENABLE => "\"enable\""
      TK_REQUIRES => "\"requires\""
      TK_DIAGNOSTIC => "\"diagnostic\""
      TK_LEFT_PAREN => "\"(\""
      TK_RIGHT_PAREN => "\")\""
      TK_COMMA => "\",\""
      TK_SEMI => "\";\""
    },
  )
}

///|
pub impl Debug for TokenKind with fn to_repr(self) {
  match self {
    TK_ITEM => Repr("ITEM")
    TK_ENABLE => Repr("enable")
    TK_REQUIRES => Repr("requires")
    TK_DIAGNOSTIC => Repr("diagnostic")
    TK_LEFT_PAREN => Repr("(")
    TK_RIGHT_PAREN => Repr(")")
    TK_COMMA => Repr(",")
    TK_SEMI => Repr(";")
  }
}
