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
    TK_IDENT => to_repr("IDENT")
    TK_VAR_TEMPLATE => to_repr("VAR_TEMPLATE")
    TK_TYPE_TEXT => to_repr("TYPE_TEXT")
    TK_INIT_TEXT => to_repr("INIT_TEXT")
    TK_ALIAS => to_repr("alias")
    TK_CONST => to_repr("const")
    TK_OVERRIDE => to_repr("override")
    TK_LET => to_repr("let")
    TK_VAR => to_repr("var")
    TK_COLON => to_repr(":")
    TK_EQ => to_repr("=")
    TK_SEMI => to_repr(";")
  }
}
