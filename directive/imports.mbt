///|
using @ast {
  type WgslDirective,
  type WgslDirectiveKind,
  type WgslDirectiveTail,
  type WgslIdent,
}

///|
using @lex {
  naga_oil_raw_import_brace_balance_next,
  replace_comments_naga_oil,
  source_lines,
  tokenize,
  trim_trailing_semicolons,
  utf8_byte_length,
  wgsl_regex_skip_whitespace,
  wgsl_regex_trim_whitespace,
  wgsl_regex_whitespace_code_point,
  wgsl_regex_word_text,
  wgsl_regex_word_width,
}
