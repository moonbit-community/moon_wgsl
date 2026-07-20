///|
pub(all) enum Token {
  IDENT(String)
  MEMBER(StructMemberParseNode)
  STRUCT
  LEFT_BRACE
  RIGHT_BRACE
  SEMI
} derive(Debug)

///|
pub fn Token::kind(self : Token) -> TokenKind {
  match self {
    IDENT(_) => TK_IDENT
    MEMBER(_) => TK_MEMBER
    STRUCT => TK_STRUCT
    LEFT_BRACE => TK_LEFT_BRACE
    RIGHT_BRACE => TK_RIGHT_BRACE
    SEMI => TK_SEMI
  }
}

///|
pub(all) enum TokenKind {
  TK_IDENT
  TK_MEMBER
  TK_STRUCT
  TK_LEFT_BRACE
  TK_RIGHT_BRACE
  TK_SEMI
}

///|
pub impl Show for TokenKind with fn output(self, logger) {
  logger.write_string(
    match self {
      TK_IDENT => "IDENT"
      TK_MEMBER => "MEMBER"
      TK_STRUCT => "\"struct\""
      TK_LEFT_BRACE => "\"{\""
      TK_RIGHT_BRACE => "\"}\""
      TK_SEMI => "\";\""
    },
  )
}

///|
pub impl Debug for TokenKind with fn to_repr(self) {
  match self {
    TK_IDENT => to_repr("IDENT")
    TK_MEMBER => to_repr("MEMBER")
    TK_STRUCT => to_repr("struct")
    TK_LEFT_BRACE => to_repr("{")
    TK_RIGHT_BRACE => to_repr("}")
    TK_SEMI => to_repr(";")
  }
}
