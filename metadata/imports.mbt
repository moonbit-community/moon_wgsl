///|
using @common {
  type DiagnosticDirective,
  type EnableDirective,
  type ImportDefWithOffset,
  type ImportDefinition,
  type PreprocessorMetaData,
  type RequiresDirective,
  type ShaderDefValue,
  type WgslDirectives,
  type WgslImportTarget,
}

///|
using @ast {type WgslDirectiveKind}

///|
using @lex {
  type WgslToken,
  wgsl_token_brace_balance,
  replace_comments,
  source_lines,
  split_last_identifier,
  tokenize,
  trim_trailing_semicolons,
  wgsl_regex_word_text,
  wgsl_regex_word_width,
}

///|
using @parser {
  type ParseImportsError,
  parse_wgsl_import_targets,
  wgsl_directive_prefix_tail,
  wgsl_directive_tail,
}
