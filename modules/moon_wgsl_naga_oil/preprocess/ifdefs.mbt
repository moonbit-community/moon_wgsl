///|
fn wgsl_template_const_skip_whitespace(source : String, start : Int) -> Int {
  let mut index = start
  while index < source.length() {
    match source.code_unit_at(index).to_int() {
      9 | 10 | 11 | 12 | 13 | 32 => index = index + 1
      _ => break
    }
  }
  index
}

///|
fn wgsl_template_const_source_has_prefix_at(
  source : String,
  start : Int,
  prefix : String,
) -> Bool {
  guard prefix != "" && start + prefix.length() <= source.length() else {
    return false
  }
  for i in 0..<prefix.length() {
    if source.code_unit_at(start + i).to_int() !=
      prefix.code_unit_at(i).to_int() {
      return false
    }
  }
  true
}

///|
fn wgsl_source_may_contain_template_const_reference(
  source : String,
  value_defines : Map[String, ShaderDefValue],
) -> Bool {
  if !source.contains("#") {
    return false
  }
  let mut has_value_define = false
  for _ in value_defines.iter() {
    has_value_define = true
    break
  }
  if !has_value_define {
    return false
  }
  let mut index = 0
  while index < source.length() {
    guard source.code_unit_at(index).to_int() == 35 else {
      index = index + 1
      continue
    }
    let body_start = wgsl_template_const_skip_whitespace(source, index + 1)
    guard body_start < source.length() else {
      index = index + 1
      continue
    }
    match source.code_unit_at(body_start).to_int() {
      35 | 123 => return true
      _ => ()
    }
    for entry in value_defines.iter() {
      let (name, _) = entry
      if wgsl_template_const_source_has_prefix_at(source, body_start, name) {
        return true
      }
    }
    index = index + 1
  }
  false
}

///|
fn wgsl_source_needs_ifdef_directive_scan(source : String) -> Bool {
  if !source.contains("#") {
    return false
  }
  let mut index = 0
  while index < source.length() {
    guard source.code_unit_at(index).to_int() == 35 else {
      index = index + 1
      continue
    }
    let body_start = wgsl_template_const_skip_whitespace(source, index + 1)
    if wgsl_template_const_source_has_prefix_at(source, body_start, "if") ||
      wgsl_template_const_source_has_prefix_at(source, body_start, "ifdef") ||
      wgsl_template_const_source_has_prefix_at(source, body_start, "ifndef") ||
      wgsl_template_const_source_has_prefix_at(source, body_start, "else") ||
      wgsl_template_const_source_has_prefix_at(source, body_start, "endif") ||
      wgsl_template_const_source_has_prefix_at(source, body_start, "version") {
      return true
    }
    index = index + 1
  }
  false
}

///|
pub fn apply_wgsl_template_consts(
  source : String,
  value_defines : Map[String, ShaderDefValue],
) -> String {
  if !wgsl_source_may_contain_template_const_reference(source, value_defines) {
    return source
  }
  let out = StringBuilder::new()
  let mut copy_start = 0
  for reference in parse_wgsl_template_const_references(source, value_defines) {
    if value_defines.get(reference.name()) is Some(value) {
      out.write_string(source[copy_start:reference.start()].to_owned())
      out.write_string(value.value_as_string())
      copy_start = reference.end()
    }
  }
  if copy_start < source.length() {
    out.write_string(source[copy_start:source.length()].to_owned())
  }
  out.to_string()
}

///|
pub fn apply_wgsl_ifdefs_strict(
  source : String,
  shader_defs : Map[String, ShaderDefValue],
) -> String raise PreprocessError {
  if !wgsl_source_needs_ifdef_directive_scan(source) {
    return source
  }
  let out = StringBuilder::new()
  let scope = Scope()
  let import_state = WgslImportSubstitutionState::default()
  for item in parse_wgsl_directive_scan_items(source) {
    let offset = item.start()
    match item.kind() {
      GlslVersion(version) =>
        if version != "440" && version != "450" {
          raise GlslInvalidVersion(offset)
        }
      Directive(directive) => {
        let (is_scope, _) = preprocess_check_scope_directive(
          shader_defs,
          directive,
          Some(scope),
          offset,
        )
        if !is_scope && scope.active() {
          out.write_string(
            preprocess_emit_scanned_item(
              KeepTrivia,
              item,
              shader_defs,
              import_state,
              [],
            ),
          )
        }
      }
      Source =>
        if scope.active() {
          out.write_string(
            preprocess_emit_scanned_item(
              KeepTrivia,
              item,
              shader_defs,
              import_state,
              [],
            ),
          )
        }
    }
  }
  scope.finish(utf8_byte_length(source))
  out.to_string()
}
