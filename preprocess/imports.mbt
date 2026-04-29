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
  hash_directive_tail,
  import_brace_balance,
  parse_imports,
  replace_comments,
  spaces,
  source_lines,
  starts_with_text,
  substitute_identifiers,
  trim_trailing_semicolons,
  word_tail,
}
