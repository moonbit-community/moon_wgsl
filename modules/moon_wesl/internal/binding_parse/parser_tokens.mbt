///|
pub(all) enum Token {
  IDENT(String)
  VAR_TEMPLATE(String)
  TYPE_TEXT(String)
  INIT_TEXT(String)
  ALIAS
  CONST
  OVERRIDE
  LET
  VAR
  COLON
  EQ
  SEMI
} derive(Debug)

///|
pub fn Token::kind(self : Token) -> TokenKind {
  match self {
    IDENT(_) => TK_IDENT
    VAR_TEMPLATE(_) => TK_VAR_TEMPLATE
    TYPE_TEXT(_) => TK_TYPE_TEXT
    INIT_TEXT(_) => TK_INIT_TEXT
    ALIAS => TK_ALIAS
    CONST => TK_CONST
    OVERRIDE => TK_OVERRIDE
    LET => TK_LET
    VAR => TK_VAR
    COLON => TK_COLON
    EQ => TK_EQ
    SEMI => TK_SEMI
  }
}

///|
pub(all) enum TokenKind {
  TK_IDENT
  TK_VAR_TEMPLATE
  TK_TYPE_TEXT
  TK_INIT_TEXT
  TK_ALIAS
  TK_CONST
  TK_OVERRIDE
  TK_LET
  TK_VAR
  TK_COLON
  TK_EQ
  TK_SEMI
}

///|
pub impl Show for TokenKind with fn output(self, logger) {
  logger.write_string(
    match self {
      TK_IDENT => "IDENT"
      TK_VAR_TEMPLATE => "VAR_TEMPLATE"
      TK_TYPE_TEXT => "TYPE_TEXT"
      TK_INIT_TEXT => "INIT_TEXT"
      TK_ALIAS => "\"alias\""
      TK_CONST => "\"const\""
      TK_OVERRIDE => "\"override\""
      TK_LET => "\"let\""
      TK_VAR => "\"var\""
      TK_COLON => "\":\""
      TK_EQ => "\"=\""
      TK_SEMI => "\";\""
    },
  )
}

///|
pub impl Debug for TokenKind with fn to_repr(self) {
  match self {
    TK_IDENT => Repr("IDENT")
    TK_VAR_TEMPLATE => Repr("VAR_TEMPLATE")
    TK_TYPE_TEXT => Repr("TYPE_TEXT")
    TK_INIT_TEXT => Repr("INIT_TEXT")
    TK_ALIAS => Repr("alias")
    TK_CONST => Repr("const")
    TK_OVERRIDE => Repr("override")
    TK_LET => Repr("let")
    TK_VAR => Repr("var")
    TK_COLON => Repr(":")
    TK_EQ => Repr("=")
    TK_SEMI => Repr(";")
  }
}
