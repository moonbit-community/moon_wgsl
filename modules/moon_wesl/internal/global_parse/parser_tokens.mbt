///|
pub(all) enum Token {
  IDENT(String)
  VAR_TEMPLATE(String)
  ATTRIBUTE
  FN
  STRUCT
  ALIAS
  CONST
  OVERRIDE
  LET
  VAR
  CONST_ASSERT
  ENABLE
  REQUIRES
  DIAGNOSTIC
  OTHER
} derive(Debug)

///|
pub fn Token::kind(self : Token) -> TokenKind {
  match self {
    IDENT(_) => TK_IDENT
    VAR_TEMPLATE(_) => TK_VAR_TEMPLATE
    ATTRIBUTE => TK_ATTRIBUTE
    FN => TK_FN
    STRUCT => TK_STRUCT
    ALIAS => TK_ALIAS
    CONST => TK_CONST
    OVERRIDE => TK_OVERRIDE
    LET => TK_LET
    VAR => TK_VAR
    CONST_ASSERT => TK_CONST_ASSERT
    ENABLE => TK_ENABLE
    REQUIRES => TK_REQUIRES
    DIAGNOSTIC => TK_DIAGNOSTIC
    OTHER => TK_OTHER
  }
}

///|
pub(all) enum TokenKind {
  TK_IDENT
  TK_VAR_TEMPLATE
  TK_ATTRIBUTE
  TK_FN
  TK_STRUCT
  TK_ALIAS
  TK_CONST
  TK_OVERRIDE
  TK_LET
  TK_VAR
  TK_CONST_ASSERT
  TK_ENABLE
  TK_REQUIRES
  TK_DIAGNOSTIC
  TK_OTHER
}

///|
pub impl Show for TokenKind with fn output(self, logger) {
  logger.write_string(
    match self {
      TK_IDENT => "IDENT"
      TK_VAR_TEMPLATE => "VAR_TEMPLATE"
      TK_ATTRIBUTE => "ATTRIBUTE"
      TK_FN => "\"fn\""
      TK_STRUCT => "\"struct\""
      TK_ALIAS => "\"alias\""
      TK_CONST => "\"const\""
      TK_OVERRIDE => "\"override\""
      TK_LET => "\"let\""
      TK_VAR => "\"var\""
      TK_CONST_ASSERT => "\"const_assert\""
      TK_ENABLE => "\"enable\""
      TK_REQUIRES => "\"requires\""
      TK_DIAGNOSTIC => "\"diagnostic\""
      TK_OTHER => "OTHER"
    },
  )
}

///|
pub impl Debug for TokenKind with fn to_repr(self) {
  match self {
    TK_IDENT => to_repr("IDENT")
    TK_VAR_TEMPLATE => to_repr("VAR_TEMPLATE")
    TK_ATTRIBUTE => to_repr("ATTRIBUTE")
    TK_FN => to_repr("fn")
    TK_STRUCT => to_repr("struct")
    TK_ALIAS => to_repr("alias")
    TK_CONST => to_repr("const")
    TK_OVERRIDE => to_repr("override")
    TK_LET => to_repr("let")
    TK_VAR => to_repr("var")
    TK_CONST_ASSERT => to_repr("const_assert")
    TK_ENABLE => to_repr("enable")
    TK_REQUIRES => to_repr("requires")
    TK_DIAGNOSTIC => to_repr("diagnostic")
    TK_OTHER => to_repr("OTHER")
  }
}
