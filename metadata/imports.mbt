///|
using @common {
  type DiagnosticDirective,
  type EnableDirective,
  type ImportDefWithOffset,
  type PreprocessorMetaData,
  type RequiresDirective,
  type ShaderDefValue,
  type WgslDirectives,
}

///|
using @ast {type WgslDirective, type WgslDirectiveKind}

///|
using @lex {
  source_lines,
  trim_trailing_semicolons,
  wgsl_regex_skip_whitespace,
  wgsl_regex_trim_whitespace,
  wgsl_regex_whitespace_code_point,
  wgsl_regex_whitespace_width,
  wgsl_regex_word_width,
}

///|
using @parser {
  type WgslDirectiveScanItem,
  type WgslDirectiveScanItemKind,
  parse_wgsl_directive_scan_items,
}

///|
using @directive {
  parse_wgsl_directive_identifier,
  parse_wgsl_shader_def_comparison,
  parse_wgsl_shader_def_references,
  wgsl_required_space_word_tail,
  wgsl_effective_directive_kind,
  wgsl_effective_directive_tail,
  wgsl_text_starts_with_tokenized_space,
}

///|
using @transform {type WgslImportSubstitutionState}
