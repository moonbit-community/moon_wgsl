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
  type WgslStatement,
  type WgslStatementKind,
  type WgslTypeRef,
  collect_wgsl_decl_global_declared_identifier_nodes,
  collect_wgsl_decl_identifier_nodes,
}

///|
using @parser {parse_wgsl_translation_unit}

///|
using @common {type WgslSymbolRedirect}
