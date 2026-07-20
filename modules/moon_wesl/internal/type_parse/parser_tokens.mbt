///|
pub(all) enum Token {
  IDENT(String)
  NUMBER(String)
  DOUBLE_COLON
  LESS
  GREATER
  SHIFT_LEFT
  COMMA
  MINUS
} derive(Debug)

///|
pub fn Token::kind(self : Token) -> TokenKind {
  match self {
    IDENT(_) => TK_IDENT
    NUMBER(_) => TK_NUMBER
    DOUBLE_COLON => TK_DOUBLE_COLON
    LESS => TK_LESS
    GREATER => TK_GREATER
    SHIFT_LEFT => TK_SHIFT_LEFT
    COMMA => TK_COMMA
    MINUS => TK_MINUS
  }
}

///|
pub(all) enum TokenKind {
  TK_IDENT
  TK_NUMBER
  TK_DOUBLE_COLON
  TK_LESS
  TK_GREATER
  TK_SHIFT_LEFT
  TK_COMMA
  TK_MINUS
}

///|
pub impl Show for TokenKind with fn output(self, logger) {
  logger.write_string(
    match self {
      TK_IDENT => "IDENT"
      TK_NUMBER => "NUMBER"
      TK_DOUBLE_COLON => "\"::\""
      TK_LESS => "\"<\""
      TK_GREATER => "\">\""
      TK_SHIFT_LEFT => "\"<<\""
      TK_COMMA => "\",\""
      TK_MINUS => "\"-\""
    },
  )
}

///|
pub impl Debug for TokenKind with fn to_repr(self) {
  match self {
    TK_IDENT => to_repr("IDENT")
    TK_NUMBER => to_repr("NUMBER")
    TK_DOUBLE_COLON => to_repr("::")
    TK_LESS => to_repr("<")
    TK_GREATER => to_repr(">")
    TK_SHIFT_LEFT => to_repr("<<")
    TK_COMMA => to_repr(",")
    TK_MINUS => to_repr("-")
  }
}
