///|
using @contract {type ShaderDefValue}

///|
using @lex {
  raw_import_brace_balance_next,
  replace_comments_preserving_byte_width,
  source_lines,
  spaces,
  tokenize,
  trim_trailing_semicolons,
  utf8_byte_length,
  wgsl_line_break_width,
  wgsl_regex_skip_whitespace,
  wgsl_regex_trim_whitespace,
  wgsl_regex_whitespace_code_point,
  wgsl_regex_word_text,
  wgsl_regex_word_width,
}
