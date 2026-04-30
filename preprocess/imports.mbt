///|
using @common {
  type DiagnosticDirective,
  type EnableDirective,
  type ImportDefWithOffset,
  type ImportDefinition,
  type PreprocessOutput,
  type PreprocessorMetaData,
  type RequiresDirective,
  type ShaderDefValue,
  type WgslDirectives,
  type WgslImportTarget,
}

///|
using @syntax {
  type ParseImportsError,
  type Token,
  type WgslDirectiveKind,
  import_brace_balance,
  parse_wgsl_import_targets,
  replace_comments,
  spaces,
  source_lines,
  starts_with_text,
  split_last_identifier,
  trim_trailing_semicolons,
  tokenize,
  word_tail,
  wgsl_directive_prefix_tail,
  wgsl_directive_tail,
}
