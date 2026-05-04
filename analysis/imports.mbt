///|
using @ast {
  type WgslAttribute,
  type WgslBlock,
  type WgslDirectiveKind,
  type WgslExprRef,
  type WgslExprToken,
  type WgslGlobalDeclData,
  type WgslGlobalDeclKind,
  type WgslIdent,
  type WgslLocalDeclaration,
  type WgslStatement,
  type WgslStatementKind,
  type WgslTypeRef,
  collect_wgsl_decl_global_declared_identifier_nodes,
  collect_wgsl_decl_identifier_nodes,
  collect_wgsl_function_body_identifier_nodes,
}

///|
using @parser {
  type WgslParseError,
  parse_wgsl_translation_unit,
  parse_wgsl_translation_unit_strict,
}

///|
using @ast {type WgslTranslationUnit}

///|
using @common {type WgslSymbolRedirect}
