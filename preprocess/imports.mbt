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
using @ast {type WgslDirective, type WgslDirectiveKind}

///|
using @lex {
  naga_oil_raw_import_brace_balance_next,
  replace_comments_naga_oil,
  spaces,
  source_lines,
  trim_trailing_semicolons,
  utf8_byte_length,
}

///|
using @parser {
  parse_glsl_version_directive,
  parse_wgsl_directive_identifier,
  parse_wgsl_directive_line_at,
  parse_wgsl_shader_def_references,
  parse_wgsl_shader_def_comparison,
  parse_wgsl_template_const_references,
  wgsl_required_space_word_tail,
  wgsl_directive_line_required_tail_space,
  wgsl_effective_directive_kind,
  wgsl_effective_directive_tail,
  wgsl_text_starts_with_tokenized_space,
}
