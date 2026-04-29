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
}

///|
using @syntax {
  type DeclaredImportBinding,
  type Token,
  type WgslDirectiveKind,
  import_brace_balance,
  parse_imports,
  replace_comments,
  spaces,
  source_lines,
  substitute_identifiers,
  trim_trailing_semicolons,
  tokenize,
  word_tail,
  wgsl_directive_prefix_tail,
  wgsl_directive_tail,
}
