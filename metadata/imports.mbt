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
using @ast {
  type WgslDirective,
  type WgslDirectiveKind,
  type WgslIdent,
  collect_wgsl_decl_identifier_nodes,
}

///|
using @lex {
  type WgslCanonicalTokenEdit,
  type WgslToken,
  emit_wgsl_canonical_tokens_with_edits,
  source_lines,
  split_last_identifier,
  tokenize,
  trim_trailing_semicolons,
  utf8_byte_length,
  wgsl_regex_skip_whitespace,
  wgsl_regex_trim_whitespace,
  wgsl_regex_whitespace_code_point,
  wgsl_regex_whitespace_width,
  wgsl_regex_word_width,
}

///|
using @parser {
  type ParseImportsError,
  type WgslDirectiveScanItem,
  type WgslDirectiveScanItemKind,
  type WgslParseError,
  parse_wgsl_directive_identifier,
  parse_wgsl_directive_scan_items,
  parse_wgsl_import_spec_is_empty_or_final_semicolon,
  parse_wgsl_import_targets,
  parse_wgsl_shader_def_references,
  parse_wgsl_translation_unit_strict,
  wgsl_required_space_word_tail,
  wgsl_effective_directive_kind,
  wgsl_effective_directive_tail,
  wgsl_shader_def_comparison_def,
  wgsl_text_starts_with_tokenized_space,
}
