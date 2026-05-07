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
using @ir {type WgslIrSymbolIdentity}

///|
using @lex {
  type WgslToken,
  split_last_identifier,
  tokenize,
  tokenize_wgsl,
  replace_comments,
  utf8_byte_length,
}

///|
using @ast {type WgslTranslationUnit}

///|
using @common {
  type ImportDefWithOffset,
  type ImportDefinition,
  type WgslImportTarget,
  type WgslSymbolRedirect,
}

///|
using @import_syntax {
  type ParseImportsError,
  parse_wgsl_import_spec_is_empty_or_final_semicolon,
  parse_wgsl_import_targets,
}
