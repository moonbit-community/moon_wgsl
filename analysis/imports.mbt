///|
using @syntax {
  type Token,
  type WgslGlobalDeclKind,
  code_unit_to_string,
  parse_wgsl_translation_unit,
  replace_comments,
  tokenizer_identifier_continue,
  tokenizer_identifier_start,
  tokenize,
}

///|
using @common {type WgslSymbolRedirect}
