///|
pub(all) enum Token {
  IDENT(String)
  NUMBER(String)
  TEMPLATE(String)
  TRUE
  FALSE
  LEFT_PAREN
  RIGHT_PAREN
  LEFT_BRACKET
  RIGHT_BRACKET
  DOT
  COMMA
  DOUBLE_COLON
  LESS
  LESS_EQUAL
  SHIFT_LEFT
  GREATER
  GREATER_EQUAL
  SHIFT_RIGHT
  PLUS
  MINUS
  MINUS_MINUS
  STAR
  SLASH
  PERCENT
  BANG
  TILDE
  AMP
  AMP_AMP
  PIPE
  PIPE_PIPE
  CARET
  EQUAL_EQUAL
  BANG_EQUAL
} derive(Debug)

///|
pub fn Token::kind(self : Token) -> TokenKind {
  match self {
    IDENT(_) => TK_IDENT
    NUMBER(_) => TK_NUMBER
    TEMPLATE(_) => TK_TEMPLATE
    TRUE => TK_TRUE
    FALSE => TK_FALSE
    LEFT_PAREN => TK_LEFT_PAREN
    RIGHT_PAREN => TK_RIGHT_PAREN
    LEFT_BRACKET => TK_LEFT_BRACKET
    RIGHT_BRACKET => TK_RIGHT_BRACKET
    DOT => TK_DOT
    COMMA => TK_COMMA
    DOUBLE_COLON => TK_DOUBLE_COLON
    LESS => TK_LESS
    LESS_EQUAL => TK_LESS_EQUAL
    SHIFT_LEFT => TK_SHIFT_LEFT
    GREATER => TK_GREATER
    GREATER_EQUAL => TK_GREATER_EQUAL
    SHIFT_RIGHT => TK_SHIFT_RIGHT
    PLUS => TK_PLUS
    MINUS => TK_MINUS
    MINUS_MINUS => TK_MINUS_MINUS
    STAR => TK_STAR
    SLASH => TK_SLASH
    PERCENT => TK_PERCENT
    BANG => TK_BANG
    TILDE => TK_TILDE
    AMP => TK_AMP
    AMP_AMP => TK_AMP_AMP
    PIPE => TK_PIPE
    PIPE_PIPE => TK_PIPE_PIPE
    CARET => TK_CARET
    EQUAL_EQUAL => TK_EQUAL_EQUAL
    BANG_EQUAL => TK_BANG_EQUAL
  }
}

///|
pub(all) enum TokenKind {
  TK_IDENT
  TK_NUMBER
  TK_TEMPLATE
  TK_TRUE
  TK_FALSE
  TK_LEFT_PAREN
  TK_RIGHT_PAREN
  TK_LEFT_BRACKET
  TK_RIGHT_BRACKET
  TK_DOT
  TK_COMMA
  TK_DOUBLE_COLON
  TK_LESS
  TK_LESS_EQUAL
  TK_SHIFT_LEFT
  TK_GREATER
  TK_GREATER_EQUAL
  TK_SHIFT_RIGHT
  TK_PLUS
  TK_MINUS
  TK_MINUS_MINUS
  TK_STAR
  TK_SLASH
  TK_PERCENT
  TK_BANG
  TK_TILDE
  TK_AMP
  TK_AMP_AMP
  TK_PIPE
  TK_PIPE_PIPE
  TK_CARET
  TK_EQUAL_EQUAL
  TK_BANG_EQUAL
}

///|
pub impl Show for TokenKind with fn output(self, logger) {
  logger.write_string(
    match self {
      TK_IDENT => "IDENT"
      TK_NUMBER => "NUMBER"
      TK_TEMPLATE => "TEMPLATE"
      TK_TRUE => "\"true\""
      TK_FALSE => "\"false\""
      TK_LEFT_PAREN => "\"(\""
      TK_RIGHT_PAREN => "\")\""
      TK_LEFT_BRACKET => "\"[\""
      TK_RIGHT_BRACKET => "\"]\""
      TK_DOT => "\".\""
      TK_COMMA => "\",\""
      TK_DOUBLE_COLON => "\"::\""
      TK_LESS => "\"<\""
      TK_LESS_EQUAL => "\"<=\""
      TK_SHIFT_LEFT => "\"<<\""
      TK_GREATER => "\">\""
      TK_GREATER_EQUAL => "\">=\""
      TK_SHIFT_RIGHT => "\">>\""
      TK_PLUS => "\"+\""
      TK_MINUS => "\"-\""
      TK_MINUS_MINUS => "\"--\""
      TK_STAR => "\"*\""
      TK_SLASH => "\"/\""
      TK_PERCENT => "\"%\""
      TK_BANG => "\"!\""
      TK_TILDE => "\"~\""
      TK_AMP => "\"&\""
      TK_AMP_AMP => "\"&&\""
      TK_PIPE => "\"|\""
      TK_PIPE_PIPE => "\"||\""
      TK_CARET => "\"^\""
      TK_EQUAL_EQUAL => "\"==\""
      TK_BANG_EQUAL => "\"!=\""
    },
  )
}

///|
pub impl Debug for TokenKind with fn to_repr(self) {
  match self {
    TK_IDENT => Repr("IDENT")
    TK_NUMBER => Repr("NUMBER")
    TK_TEMPLATE => Repr("TEMPLATE")
    TK_TRUE => Repr("true")
    TK_FALSE => Repr("false")
    TK_LEFT_PAREN => Repr("(")
    TK_RIGHT_PAREN => Repr(")")
    TK_LEFT_BRACKET => Repr("[")
    TK_RIGHT_BRACKET => Repr("]")
    TK_DOT => Repr(".")
    TK_COMMA => Repr(",")
    TK_DOUBLE_COLON => Repr("::")
    TK_LESS => Repr("<")
    TK_LESS_EQUAL => Repr("<=")
    TK_SHIFT_LEFT => Repr("<<")
    TK_GREATER => Repr(">")
    TK_GREATER_EQUAL => Repr(">=")
    TK_SHIFT_RIGHT => Repr(">>")
    TK_PLUS => Repr("+")
    TK_MINUS => Repr("-")
    TK_MINUS_MINUS => Repr("--")
    TK_STAR => Repr("*")
    TK_SLASH => Repr("/")
    TK_PERCENT => Repr("%")
    TK_BANG => Repr("!")
    TK_TILDE => Repr("~")
    TK_AMP => Repr("&")
    TK_AMP_AMP => Repr("&&")
    TK_PIPE => Repr("|")
    TK_PIPE_PIPE => Repr("||")
    TK_CARET => Repr("^")
    TK_EQUAL_EQUAL => Repr("==")
    TK_BANG_EQUAL => Repr("!=")
  }
}
