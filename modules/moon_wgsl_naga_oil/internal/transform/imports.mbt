///|
using @ast {
  type WgslFunction,
  type WgslGlobalDecl,
  type WgslGlobalDeclData,
  type WgslGlobalVariable,
  type WgslIdent,
  type WgslStruct,
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
using @directive {
  mask_naga_oil_directives_for_wgsl,
  parse_wgsl_directive_scan_items,
}

///|

///|

///|
using @lex {type WgslToken, split_last_identifier, utf8_byte_length}

///|
using @ast {type WgslTranslationUnit}

///|
using @contract {
  type WgslComposeSymbolIdentity,
  type WgslReferencePath,
  type WgslSourceOriginKind,
}

///|
using @source_rewrite {
  type WgslTokenReplacement,
  emit_wgsl_token_stream_canonical,
  tokenize_wgsl_absolute_source,
}

///|
using @contract {type ShaderDefValue, type WgslImmediateSpecialization}
