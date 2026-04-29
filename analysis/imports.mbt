///|
using @syntax {
  type Token,
  type WgslGlobalDeclData,
  type WgslGlobalDeclKind,
  type WgslIdent,
  type WgslDirectiveKind,
  code_unit_to_string,
  collect_wgsl_decl_identifier_nodes,
  parse_wgsl_translation_unit,
  split_last_identifier,
  tokenizer_identifier_continue,
  tokenizer_identifier_start,
  tokenize,
}

///|
using @common {type WgslSymbolRedirect}
