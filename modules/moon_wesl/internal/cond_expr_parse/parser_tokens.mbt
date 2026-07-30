///|
pub(all) enum Token {
  IDENT(String)
  TRUE
  FALSE
  BANG
  AMP_AMP
  PIPE_PIPE
  LEFT_PAREN
  RIGHT_PAREN
} derive(Debug)

///|
pub fn Token::kind(self : Token) -> TokenKind {
  match self {
    IDENT(_) => TK_IDENT
    TRUE => TK_TRUE
    FALSE => TK_FALSE
    BANG => TK_BANG
    AMP_AMP => TK_AMP_AMP
    PIPE_PIPE => TK_PIPE_PIPE
    LEFT_PAREN => TK_LEFT_PAREN
    RIGHT_PAREN => TK_RIGHT_PAREN
  }
}

///|
pub(all) enum TokenKind {
  TK_IDENT
  TK_TRUE
  TK_FALSE
  TK_BANG
  TK_AMP_AMP
  TK_PIPE_PIPE
  TK_LEFT_PAREN
  TK_RIGHT_PAREN
}

///|
pub impl Show for TokenKind with fn output(self, logger) {
  logger.write_string(
    match self {
      TK_IDENT => "IDENT"
      TK_TRUE => "\"true\""
      TK_FALSE => "\"false\""
      TK_BANG => "\"!\""
      TK_AMP_AMP => "\"&&\""
      TK_PIPE_PIPE => "\"||\""
      TK_LEFT_PAREN => "\"(\""
      TK_RIGHT_PAREN => "\")\""
    },
  )
}

///|
pub impl Debug for TokenKind with fn to_repr(self) {
  match self {
    TK_IDENT => Repr("IDENT")
    TK_TRUE => Repr("true")
    TK_FALSE => Repr("false")
    TK_BANG => Repr("!")
    TK_AMP_AMP => Repr("&&")
    TK_PIPE_PIPE => Repr("||")
    TK_LEFT_PAREN => Repr("(")
    TK_RIGHT_PAREN => Repr(")")
  }
}
