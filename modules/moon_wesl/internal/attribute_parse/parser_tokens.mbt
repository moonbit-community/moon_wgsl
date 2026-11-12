///|
#derive(Debug)
pub(all) enum Token {
  ATTRIBUTE(AttributeParseNode)
}

///|
#deprecated("Use Debug::to_repr instead")
#doc(hidden)
pub extend Token with Debug::{to_repr}

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
#deprecated("Use Show::to_string or Show::output instead")
#doc(hidden)
pub extend TokenKind with Show::{output, to_string}

///|
pub impl Show for TokenKind with fn output(self, logger) {
  Logger::write_string(
    logger,
    match self {
      TK_ATTRIBUTE => "ATTRIBUTE"
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
    TK_ATTRIBUTE => Repr("ATTRIBUTE")
  }
}
