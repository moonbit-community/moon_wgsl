///|
using @ast {
  type WgslAttribute,
  type WgslBlock,
  type WgslConst,
  type WgslDeclHead,
  type WgslDirective,
  type WgslDirectiveKind,
  type WgslExprRef,
  type WgslFunction,
  type WgslFunctionArgument,
  type WgslFunctionResult,
  type WgslGlobalDecl,
  type WgslGlobalDeclData,
  type WgslGlobalDeclKind,
  type WgslGlobalVariable,
  type WgslIdent,
  type WgslOverride,
  type WgslRawTopLevelItem,
  type WgslRawTopLevelKind,
  type WgslStatement,
  type WgslStatementKind,
  type WgslStruct,
  type WgslStructMember,
  type WgslTranslationUnit,
  type WgslTypeAlias,
  type WgslTypeRef,
  wgsl_decl_data_name,
}

///|
using @common {type WgslImportTarget}

///|
using @lex {
  type WgslToken,
  replace_comments,
  tokenize,
  wgsl_token_brace_balance,
}
