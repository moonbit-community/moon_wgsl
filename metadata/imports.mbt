///|
using @common {
  type ImportDefWithOffset,
  type PreprocessorMetaData,
  type ShaderDefValue,
  type WgslDirectives,
}

///|
using @ast {type WgslDirective, type WgslDirectiveKind}

///|
using @lex {
  trim_trailing_semicolons,
  wgsl_line_text_end,
  wgsl_regex_trim_whitespace,
  wgsl_regex_whitespace_code_point,
  wgsl_regex_whitespace_width,
  wgsl_regex_word_width,
}

///|
using @directive {
  type WgslDirectiveScanItem,
  type WgslDirectiveScanItemKind,
  type WgslSourceDirectiveItemKind,
  parse_wgsl_directive_identifier,
  parse_wgsl_directive_scan_items,
  parse_wgsl_shader_def_comparison,
  parse_wgsl_shader_def_references,
  parse_wgsl_source_directive_items,
  wgsl_required_space_word_tail,
  wgsl_effective_directive_kind,
  wgsl_effective_directive_tail,
  wgsl_text_starts_with_tokenized_space,
}

///|
using @import_substitution {type WgslImportSubstitutionState}
