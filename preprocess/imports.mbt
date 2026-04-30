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
using @syntax {
  type Token,
  type WgslDirectiveKind,
  import_brace_balance,
  replace_comments,
  spaces,
  source_lines,
  starts_with_text,
  trim_trailing_semicolons,
  tokenize,
  wgsl_directive_prefix_tail,
  wgsl_directive_tail,
}
