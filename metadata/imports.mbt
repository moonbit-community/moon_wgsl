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
using @parser {
  type ParseImportsError,
  type Token,
  import_brace_balance,
  parse_wgsl_import_targets,
  replace_comments,
  source_lines,
  split_last_identifier,
  tokenize,
  trim_trailing_semicolons,
  wgsl_directive_prefix_tail,
  wgsl_directive_tail,
}
