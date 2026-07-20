///|
pub(all) enum Token {
  IDENT(String)
  AS
  DOUBLE_COLON
  COMMA
  LEFT_BRACE
  RIGHT_BRACE
} derive(Debug)

///|
pub fn Token::kind(self : Token) -> TokenKind {
  match self {
    IDENT(_) => TK_IDENT
    AS => TK_AS
    DOUBLE_COLON => TK_DOUBLE_COLON
    COMMA => TK_COMMA
    LEFT_BRACE => TK_LEFT_BRACE
    RIGHT_BRACE => TK_RIGHT_BRACE
  }
}

///|
pub(all) enum TokenKind {
  TK_IDENT
  TK_AS
  TK_DOUBLE_COLON
  TK_COMMA
  TK_LEFT_BRACE
  TK_RIGHT_BRACE
}

///|
pub impl Show for TokenKind with fn output(self, logger) {
  logger.write_string(
    match self {
      TK_IDENT => "IDENT"
      TK_AS => "\"as\""
      TK_DOUBLE_COLON => "\"::\""
      TK_COMMA => "\",\""
      TK_LEFT_BRACE => "\"{\""
      TK_RIGHT_BRACE => "\"}\""
    },
  )
}

///|
pub impl Debug for TokenKind with fn to_repr(self) {
  match self {
    TK_IDENT => to_repr("IDENT")
    TK_AS => to_repr("as")
    TK_DOUBLE_COLON => to_repr("::")
    TK_COMMA => to_repr(",")
    TK_LEFT_BRACE => to_repr("{")
    TK_RIGHT_BRACE => to_repr("}")
  }
}
