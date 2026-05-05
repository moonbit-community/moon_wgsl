///|
pub fn apply_wgsl_template_consts(
  source : String,
  value_defines : @hashmap.HashMap[String, Int],
) -> String {
  let mut out = ""
  let mut copy_start = 0
  for reference in parse_wgsl_template_const_references(source, value_defines) {
    if value_defines.get(reference.name()) is Some(value) {
      out = out + source[copy_start:reference.start()].to_owned()
      out = out + value.to_string()
      copy_start = reference.end()
    }
  }
  if copy_start < source.length() {
    out = out + source[copy_start:source.length()].to_owned()
  }
  out
}

///|
pub fn apply_wgsl_ifdefs_strict(
  source : String,
  shader_defs : @hashmap.HashMap[String, ShaderDefValue],
) -> String raise PreprocessError {
  let mut out = ""
  let scope = Scope::new()
  let import_state = WgslImportSubstitutionState::default()
  for item in parse_wgsl_directive_scan_items(source) {
    let offset = item.start()
    match item.kind() {
      WgslDirectiveScanItemKind::GlslVersion(version) =>
        if version != "440" && version != "450" {
          raise PreprocessError::GlslInvalidVersion(offset)
        }
      WgslDirectiveScanItemKind::Directive(directive) => {
        let (is_scope, _) = preprocess_check_scope_directive(
          shader_defs,
          directive,
          item.requires_tail_space(),
          Some(scope),
          offset,
        )
        if !is_scope && scope.active() {
          out = out +
            preprocess_emit_scanned_item(
              KeepTrivia,
              item,
              shader_defs,
              import_state,
              [],
            )
        }
      }
      WgslDirectiveScanItemKind::Source =>
        if scope.active() {
          out = out +
            preprocess_emit_scanned_item(
              KeepTrivia,
              item,
              shader_defs,
              import_state,
              [],
            )
        }
    }
  }
  scope.finish(utf8_byte_length(source))
  out
}
