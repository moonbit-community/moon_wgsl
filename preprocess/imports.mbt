///|
using @common {
  type ImportDefWithOffset,
  type PreprocessOutput,
  type ShaderDefValue,
  type WgslDirectives,
}

///|
using @metadata {
  type DeclaredImportBinding,
  extract_wgsl_directives,
  parse_imports,
  substitute_identifiers,
}

///|
using @ast {type WgslDirectiveKind}

///|
using @lex {
  type WgslToken,
  naga_oil_raw_import_brace_balance_next,
  replace_comments_naga_oil,
  spaces,
  source_lines,
  trim_trailing_semicolons,
  tokenize,
  utf8_byte_length,
  wgsl_regex_skip_whitespace,
  wgsl_regex_trim_whitespace,
  wgsl_regex_whitespace_code_point,
  wgsl_regex_word_text,
  wgsl_regex_word_width,
}

///|
using @parser {wgsl_directive_prefix_tail}
