///|
using @ast_analysis {collect_wgsl_decl_identifier_nodes}

///|
using @ast {type WgslIdent}

///|
using @parser {type WgslParseError, parse_wgsl_translation_unit_strict}

///|
using @lex {type WgslToken, split_last_identifier, tokenize, utf8_byte_length}

///|
using @common {type ImportDefWithOffset, type WgslImportTarget}

///|
using @import_syntax {
  type ParseImportsError,
  parse_wgsl_import_spec_is_empty_or_final_semicolon,
  parse_wgsl_import_targets,
}

///|
using @source_rewrite {
  type WgslTokenReplacement,
  emit_wgsl_source_tokens_canonical,
}
