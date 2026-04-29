///|
using @syntax {
  type Token,
  type WgslGlobalDeclData,
  type WgslGlobalDeclKind,
  type WgslDirectiveKind,
  code_unit_to_string,
  parse_wgsl_translation_unit,
  tokenizer_identifier_continue,
  tokenizer_identifier_start,
  tokenize,
}

///|
using @common {type WgslSymbolRedirect}
