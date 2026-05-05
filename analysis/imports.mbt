///|
using @ast {
  type WgslAttribute,
  type WgslBlock,
  type WgslDirectiveKind,
  type WgslExprRef,
  type WgslExprToken,
  type WgslFunction,
  type WgslFunctionQualifier,
  type WgslGlobalDecl,
  type WgslGlobalDeclData,
  type WgslGlobalDeclKind,
  type WgslIdent,
  type WgslLocalDeclaration,
  type WgslLocalDeclarationKind,
  type WgslStatement,
  type WgslStatementKind,
  type WgslTypeRef,
  collect_wgsl_decl_global_declared_identifier_nodes,
  collect_wgsl_decl_identifier_nodes,
  collect_wgsl_function_body_identifier_nodes,
  wgsl_decl_data_name,
}

///|
using @parser {type WgslParseError, parse_wgsl_translation_unit_strict}

///|
using @lex {
  type WgslToken,
  type WgslTokenReplacement,
  emit_wgsl_token_stream_canonical,
  split_last_identifier,
  tokenize_wgsl_absolute_fragment,
}

///|
using @ast {type WgslTranslationUnit}

///|
using @common {type WgslSymbolRedirect}
