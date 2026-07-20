///|
pub(all) enum Token {
  ITEM(TopLevelItemSpan)
} derive(Debug)

///|
pub fn Token::kind(self : Token) -> TokenKind {
  match self {
    ITEM(_) => TK_ITEM
  }
}

///|
pub(all) enum TokenKind {
  TK_ITEM
}

///|
pub impl Show for TokenKind with fn output(self, logger) {
  logger.write_string(
    match self {
      TK_ITEM => "ITEM"
    },
  )
}

///|
pub impl Debug for TokenKind with fn to_repr(self) {
  match self {
    TK_ITEM => to_repr("ITEM")
  }
}
