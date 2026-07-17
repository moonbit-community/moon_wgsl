///|
using @contract {
  type ImportDefWithOffset,
  type PreprocessOutput,
  type ShaderDefValue,
}

///|
using @import_substitution {type WgslImportSubstitutionState}

///|
using @lex {
  spaces,
  trim_trailing_semicolons,
  utf8_byte_length,
  wgsl_line_break_width,
  wgsl_line_text_end,
}

///|
using @directive {
  type WgslPreprocessorDirective,
  type WgslDirectiveScanItem,
  type WgslShaderDefOperator,
  parse_wgsl_directive_identifier,
  parse_wgsl_directive_scan_items,
  parse_wgsl_shader_def_comparison,
  parse_wgsl_shader_def_references,
  parse_wgsl_template_const_references,
  wgsl_required_space_word_tail,
  wgsl_effective_directive_kind,
  wgsl_effective_directive_tail,
  wgsl_text_starts_with_tokenized_space,
}
