///|
pub(all) enum Token {
  STATEMENT(StatementParseNode)
} derive(Debug)

///|
pub fn Token::kind(self : Token) -> TokenKind {
  match self {
    STATEMENT(_) => TK_STATEMENT
  }
}

///|
pub(all) enum TokenKind {
  TK_STATEMENT
}

///|
pub impl Show for TokenKind with fn output(self, logger) {
  logger.write_string(
    match self {
      TK_STATEMENT => "STATEMENT"
    },
  )
}

///|
pub impl Debug for TokenKind with fn to_repr(self) {
  match self {
    TK_STATEMENT => to_repr("STATEMENT")
  }
}
