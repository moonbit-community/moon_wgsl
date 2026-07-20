///|
pub(all) enum Token {
  IDENT(String)
  GENERICS(String)
  PARAM(FunctionParameterParseNode)
  RETURN_TYPE(String)
  FN
  LEFT_PAREN
  RIGHT_PAREN
  BODY(String)
} derive(Debug)

///|
pub fn Token::kind(self : Token) -> TokenKind {
  match self {
    IDENT(_) => TK_IDENT
    GENERICS(_) => TK_GENERICS
    PARAM(_) => TK_PARAM
    RETURN_TYPE(_) => TK_RETURN_TYPE
    FN => TK_FN
    LEFT_PAREN => TK_LEFT_PAREN
    RIGHT_PAREN => TK_RIGHT_PAREN
    BODY(_) => TK_BODY
  }
}

///|
pub(all) enum TokenKind {
  TK_IDENT
  TK_GENERICS
  TK_PARAM
  TK_RETURN_TYPE
  TK_FN
  TK_LEFT_PAREN
  TK_RIGHT_PAREN
  TK_BODY
}

///|
pub impl Show for TokenKind with fn output(self, logger) {
  logger.write_string(
    match self {
      TK_IDENT => "IDENT"
      TK_GENERICS => "GENERICS"
      TK_PARAM => "PARAM"
      TK_RETURN_TYPE => "RETURN_TYPE"
      TK_FN => "\"fn\""
      TK_LEFT_PAREN => "\"(\""
      TK_RIGHT_PAREN => "\")\""
      TK_BODY => "BODY"
    },
  )
}

///|
pub impl Debug for TokenKind with fn to_repr(self) {
  match self {
    TK_IDENT => to_repr("IDENT")
    TK_GENERICS => to_repr("GENERICS")
    TK_PARAM => to_repr("PARAM")
    TK_RETURN_TYPE => to_repr("RETURN_TYPE")
    TK_FN => to_repr("fn")
    TK_LEFT_PAREN => to_repr("(")
    TK_RIGHT_PAREN => to_repr(")")
    TK_BODY => to_repr("BODY")
  }
}
