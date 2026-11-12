///|
#derive(Debug)
pub(all) enum Token {
  IDENT(String)
  GENERICS(String)
  PARAM(FunctionParameterParseNode)
  RETURN_TYPE(String)
  FN
  LEFT_PAREN
  RIGHT_PAREN
  BODY(String)
}

///|
#deprecated("Use Debug::to_repr instead")
#doc(hidden)
pub extend Token with Debug::{to_repr}

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
#deprecated("Use Show::to_string or Show::output instead")
#doc(hidden)
pub extend TokenKind with Show::{output, to_string}

///|
pub impl Show for TokenKind with fn output(self, logger) {
  Logger::write_string(
    logger,
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
#deprecated("Use Debug::to_repr instead")
#doc(hidden)
pub extend TokenKind with Debug::{to_repr}

///|
pub impl Debug for TokenKind with fn to_repr(self) {
  match self {
    TK_IDENT => Repr("IDENT")
    TK_GENERICS => Repr("GENERICS")
    TK_PARAM => Repr("PARAM")
    TK_RETURN_TYPE => Repr("RETURN_TYPE")
    TK_FN => Repr("fn")
    TK_LEFT_PAREN => Repr("(")
    TK_RIGHT_PAREN => Repr(")")
    TK_BODY => Repr("BODY")
  }
}
