///|
using @ast {
  type WgslFunction,
  type WgslGlobalDecl,
  type WgslGlobalDeclData,
  type WgslIdent,
}

///|
using @ast_analysis {
  collect_wgsl_decl_global_declared_identifier_nodes,
  collect_wgsl_decl_identifier_nodes,
  collect_wgsl_function_body_identifier_nodes,
  wgsl_decl_data_name,
}

///|
using @parser {type WgslParseError, parse_wgsl_translation_unit_strict}

///|

///|
using @ir {type WgslIrSymbolIdentity}

///|
using @lex {type WgslToken, split_last_identifier}

///|
using @ast {type WgslTranslationUnit}

///|
using @common {type WgslReferencePath, type WgslSourceOriginKind}

///|
using @source_rewrite {
  type WgslTokenReplacement,
  emit_wgsl_token_stream_canonical,
  tokenize_wgsl_absolute_source,
}
