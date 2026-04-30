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
using @parser {
  type Token,
  wgsl_token_brace_balance,
  replace_comments,
  spaces,
  source_lines,
  trim_trailing_semicolons,
  tokenize,
  wgsl_directive_prefix_tail,
  wgsl_directive_tail,
}
