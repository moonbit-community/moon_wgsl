///|
using @syntax {
  type Token,
  type WgslAttribute,
  type WgslGlobalDeclData,
  type WgslGlobalDeclKind,
  type WgslTypeRef,
  type WgslDirectiveKind,
  code_unit_to_string,
  parse_wgsl_translation_unit,
  split_last_identifier,
  tokenizer_identifier_continue,
  tokenizer_identifier_start,
  tokenize,
}

///|
using @common {type WgslSymbolRedirect}
