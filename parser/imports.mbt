///|
using @ast {
  type WgslAttribute,
  type WgslBlock,
  type WgslConst,
  type WgslDirective,
  type WgslDirectiveKind,
  type WgslExprNode,
  type WgslExprNodeKind,
  type WgslExprOperator,
  type WgslExprRef,
  type WgslExprToken,
  type WgslExprTokenKind,
  type WgslFunction,
  type WgslFunctionArgument,
  type WgslFunctionQualifier,
  type WgslFunctionResult,
  type WgslGlobalDecl,
  type WgslGlobalDeclData,
  type WgslGlobalDeclKind,
  type WgslGlobalVariable,
  type WgslIdent,
  type WgslLocalDeclaration,
  type WgslLocalDeclarationKind,
  type WgslOverride,
  type WgslStatement,
  type WgslStatementExpression,
  type WgslStatementExpressionRole,
  type WgslStatementKind,
  type WgslStatementPayload,
  type WgslStruct,
  type WgslStructMember,
  type WgslTranslationUnit,
  type WgslTypeAtom,
  type WgslTypeAtomKind,
  type WgslTypeAlias,
  type WgslTypeArgument,
  type WgslTypeRef,
}

///|
using @directive_syntax {
  parse_wgsl_directive_line,
  parse_wgsl_directive_line_at,
}

///|
using @lex {
  type WgslToken,
  replace_comments,
  replace_comments_naga_oil,
  naga_oil_raw_import_brace_balance_next,
  tokenize_wgsl,
  wgsl_blankspace_code_point,
  wgsl_regex_trim_whitespace,
  wgsl_regex_word_text,
  wgsl_trim_blankspace,
}
