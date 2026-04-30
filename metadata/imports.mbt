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
using @ast {type WgslDirective, type WgslDirectiveKind, type WgslGlobalDeclData}

///|
using @lex {
  type WgslToken,
  naga_oil_raw_import_brace_balance_next,
  replace_comments_naga_oil,
  source_lines,
  split_last_identifier,
  tokenize,
  trim_trailing_semicolons,
  utf8_byte_length,
  wgsl_regex_skip_whitespace,
  wgsl_regex_trim_whitespace,
  wgsl_regex_whitespace_code_point,
  wgsl_regex_whitespace_width,
  wgsl_regex_word_width,
}

///|
using @parser {
  type ParseImportsError,
  type WgslSourceDirectiveItemKind,
  parse_wgsl_directive_line_at,
  parse_wgsl_import_targets,
  parse_wgsl_shader_def_references,
  parse_wgsl_source_directive_items,
  parse_wgsl_translation_unit,
}
