///|
pub(all) enum Token {
  ATTRIBUTE(AttributeParseNode)
} derive(Debug)

///|
pub fn Token::kind(self : Token) -> TokenKind {
  match self {
    ATTRIBUTE(_) => TK_ATTRIBUTE
  }
}

///|
pub(all) enum TokenKind {
  TK_ATTRIBUTE
}

///|
pub impl Show for TokenKind with fn output(self, logger) {
  logger.write_string(
    match self {
      TK_ATTRIBUTE => "ATTRIBUTE"
    },
  )
}

///|
pub impl Debug for TokenKind with fn to_repr(self) {
  match self {
    TK_ATTRIBUTE => to_repr("ATTRIBUTE")
  }
}
