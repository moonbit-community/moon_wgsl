///|
using @syntax {
  type Token,
  type WgslTopLevelKind,
  code_unit_to_string,
  parse_wgsl_top_level_items,
  replace_comments,
  tokenizer_identifier_continue,
  tokenizer_identifier_start,
  tokenize,
}

///|
using @common {type WgslSymbolRedirect}
