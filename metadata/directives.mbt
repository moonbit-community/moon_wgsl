///|
priv struct ShaderDefReference {
  name : String
}

///|
fn split_extensions(raw : String) -> Array[String] {
  let extensions : Array[String] = []
  for part in raw.split(",") {
    let extension = wgsl_regex_trim_whitespace(part.to_owned())
    if extension != "" {
      extensions.push(extension)
    }
  }
  extensions
}

///|
fn parse_shader_def_references(line : String) -> Array[ShaderDefReference] {
  let references : Array[ShaderDefReference] = []
  let mut i = 0
  while i < line.length() {
    guard line.code_unit_at(i).to_int() == 35 else {
      i = i + 1
      continue
    }
    let mut j = i + 1
    while j < line.length() &&
          wgsl_regex_whitespace_code_point(line.code_unit_at(j).to_int()) {
      j = j + 1
    }
    guard j < line.length() else {
      i = i + 1
      continue
    }
    if line.code_unit_at(j).to_int() == 123 {
      let body_start = j + 1
      let mut k = body_start
      while k < line.length() && line.code_unit_at(k).to_int() != 125 {
        k = k + 1
      }
      if k < line.length() {
        let name = line[body_start:k].to_owned()
        if wgsl_regex_word_text(name) {
          references.push(ShaderDefReference::{ name, })
        }
        i = k + 1
      } else {
        i = i + 1
      }
    } else {
      let name_start = j
      let mut name_end = j
      while name_end < line.length() {
        let width = wgsl_regex_word_width(line, name_end)
        guard width > 0 else { break }
        name_end = name_end + width
      }
      if name_end > name_start {
        references.push(ShaderDefReference::{
          name: line[name_start:name_end].to_owned(),
        })
        i = name_end
      } else {
        i = i + 1
      }
    }
  }
  references
}

///|
fn collect_effective_def_names(
  line : String,
  effective_defs : @hashset.HashSet[String],
) -> Unit {
  for reference in parse_shader_def_references(line) {
    effective_defs.add(reference.name)
  }
}

///|
fn parse_define_value(raw_value : String) -> ShaderDefValue {
  let value = trim_trailing_semicolons(raw_value)
  if value == "" {
    return ShaderDefValue::Bool(true)
  }
  if value == "true" {
    return ShaderDefValue::Bool(true)
  }
  if value == "false" {
    return ShaderDefValue::Bool(false)
  }
  let parsed_unsigned = @string.parse_uint(value[:], base=10) catch {
    _ => {
      let parsed = @string.parse_int(value[:], base=10) catch {
        _ => return ShaderDefValue::Bool(false)
      }
      return ShaderDefValue::Int(parsed)
    }
  }
  ShaderDefValue::UInt(parsed_unsigned)
}

///|
fn split_define_name_and_value(text : String) -> (String, String) {
  let trimmed = wgsl_regex_trim_whitespace(text)
  if trimmed == "" {
    return ("", "")
  }
  let mut i = 0
  while i < trimmed.length() {
    let width = wgsl_regex_word_width(trimmed, i)
    guard width > 0 else { break }
    i = i + width
  }
  if i == 0 {
    return ("", "")
  }
  let name = trimmed[0:i].to_owned()
  while i < trimmed.length() {
    if wgsl_regex_whitespace_code_point(trimmed.code_unit_at(i).to_int()) {
      i = i + 1
      continue
    }
    break
  }
  let value_start = i
  while i < trimmed.length() {
    let code = trimmed.code_unit_at(i).to_int()
    if code == 45 {
      i = i + 1
      continue
    }
    let width = wgsl_regex_word_width(trimmed, i)
    guard width > 0 else { break }
    i = i + width
  }
  (name, trimmed[value_start:i].to_owned())
}

///|
fn starts_with_tokenized_space(text : String) -> Bool {
  text.length() > 0 &&
  wgsl_regex_whitespace_code_point(text.code_unit_at(0).to_int())
}

///|
fn metadata_has_ascii_keyword_at(
  text : String,
  start : Int,
  keyword : String,
) -> Bool {
  guard start >= 0 && start + keyword.length() <= text.length() else {
    return false
  }
  for i in 0..<keyword.length() {
    if text.code_unit_at(start + i).to_int() != keyword.code_unit_at(i).to_int() {
      return false
    }
  }
  true
}

///|
fn metadata_required_space_word_tail(
  text : String,
  keyword : String,
) -> String? {
  let trimmed = wgsl_regex_trim_whitespace(text)
  guard keyword.length() < trimmed.length() else { return None }
  guard metadata_has_ascii_keyword_at(trimmed, 0, keyword) else { return None }
  let space_pos = keyword.length()
  let code = trimmed.code_unit_at(space_pos).to_int()
  guard wgsl_regex_whitespace_code_point(code) else { return None }
  let tail_start = wgsl_regex_skip_whitespace(trimmed, space_pos)
  Some(
    wgsl_regex_trim_whitespace(trimmed[tail_start:trimmed.length()].to_owned()),
  )
}

///|
fn semicolon_directive_body(line : String, keyword : String) -> String? {
  let trimmed = wgsl_regex_trim_whitespace(line)
  guard trimmed.length() > keyword.length() &&
    metadata_has_ascii_keyword_at(trimmed, 0, keyword) else {
    return None
  }
  let whitespace_start = keyword.length()
  guard wgsl_regex_whitespace_code_point(
    trimmed.code_unit_at(whitespace_start).to_int(),
  ) else {
    return None
  }
  let whitespace_end = wgsl_regex_skip_whitespace(trimmed, whitespace_start)
  let mut semicolon_pos = whitespace_start + 1
  while semicolon_pos < trimmed.length() &&
        trimmed.code_unit_at(semicolon_pos).to_int() != 59 {
    semicolon_pos = semicolon_pos + 1
  }
  guard semicolon_pos < trimmed.length() else { return None }
  if semicolon_pos <= whitespace_end {
    if semicolon_pos - whitespace_start <= 1 {
      return None
    }
    return Some("")
  }
  Some(
    wgsl_regex_trim_whitespace(trimmed[whitespace_end:semicolon_pos].to_owned()),
  )
}

///|
fn parse_diagnostic_directive_body(line : String) -> (String, String)? {
  let trimmed = wgsl_regex_trim_whitespace(line)
  guard trimmed.length() >= "diagnostic".length() &&
    metadata_has_ascii_keyword_at(trimmed, 0, "diagnostic") else {
    return None
  }
  let mut i = "diagnostic".length()
  i = wgsl_regex_skip_whitespace(trimmed, i)
  guard i < trimmed.length() && trimmed.code_unit_at(i).to_int() == 40 else {
    return None
  }
  let severity_raw_start = i + 1
  i = wgsl_regex_skip_whitespace(trimmed, severity_raw_start)
  let severity_start = i
  while i < trimmed.length() && trimmed.code_unit_at(i).to_int() != 44 {
    i = i + 1
  }
  guard i < trimmed.length() else { return None }
  guard i > severity_start || severity_start > severity_raw_start else {
    return None
  }
  let severity = wgsl_regex_trim_whitespace(
    trimmed[severity_start:i].to_owned(),
  )
  let rule_raw_start = i + 1
  i = wgsl_regex_skip_whitespace(trimmed, rule_raw_start)
  let rule_start = i
  while i < trimmed.length() && trimmed.code_unit_at(i).to_int() != 41 {
    i = i + 1
  }
  guard i < trimmed.length() else { return None }
  guard i > rule_start || rule_start > rule_raw_start else { return None }
  let rule = wgsl_regex_trim_whitespace(trimmed[rule_start:i].to_owned())
  i = wgsl_regex_skip_whitespace(trimmed, i + 1)
  guard i < trimmed.length() && trimmed.code_unit_at(i).to_int() == 59 else {
    return None
  }
  Some((severity, rule))
}

///|
fn directive_identifier(text : String) -> String? {
  let trimmed = wgsl_regex_trim_whitespace(trim_trailing_semicolons(text))
  let mut i = 0
  while i < trimmed.length() {
    let width = wgsl_regex_word_width(trimmed, i)
    guard width > 0 else { break }
    i = i + width
  }
  if i == 0 {
    None
  } else {
    Some(trimmed[0:i].to_owned())
  }
}

///|
fn parse_if_operator_expression(
  expression : String,
) -> (String, String, String)? {
  let text = trim_trailing_semicolons(expression)
  let mut i = 0
  while i < text.length() {
    let code = text.code_unit_at(i).to_int()
    if wgsl_regex_whitespace_code_point(code) {
      i = i + 1
      continue
    }
    break
  }
  let def_start = i
  while i < text.length() {
    let width = wgsl_regex_word_width(text, i)
    guard width > 0 else { break }
    i = i + width
  }
  guard i > def_start else { return None }
  let def = text[def_start:i].to_owned()
  while i < text.length() {
    let code = text.code_unit_at(i).to_int()
    if wgsl_regex_whitespace_code_point(code) {
      i = i + 1
      continue
    }
    break
  }
  let operator_start = i
  while i < text.length() {
    let code = text.code_unit_at(i).to_int()
    if code == 61 || code == 33 || code == 60 || code == 62 {
      i = i + 1
      continue
    }
    break
  }
  let operator = text[operator_start:i].to_owned()
  while i < text.length() {
    let code = text.code_unit_at(i).to_int()
    if wgsl_regex_whitespace_code_point(code) {
      i = i + 1
      continue
    }
    break
  }
  let value_start = i
  while i < text.length() {
    let code = text.code_unit_at(i).to_int()
    if code == 45 {
      i = i + 1
      continue
    }
    let width = wgsl_regex_word_width(text, i)
    guard width > 0 else { break }
    i = i + width
  }
  if i == value_start {
    None
  } else {
    let value = text[value_start:i].to_owned()
    Some((def, operator, value))
  }
}

///|
fn if_operator_expression_def(expression : String) -> String? {
  match parse_if_operator_expression(expression) {
    Some((def, _, _)) => Some(def)
    None => None
  }
}

///|
pub fn extract_wgsl_directives(
  source : String,
) -> (String, WgslDirectives) raise MetadataError {
  let directives = WgslDirectives::default()
  let cleaned_lines : Array[String] = []
  let mut in_directive_section = true
  let mut line_index = 0
  for line in source_lines(source) {
    let trimmed = wgsl_regex_trim_whitespace(line)

    if trimmed == "" || trimmed.has_prefix("//") {
      cleaned_lines.push(line)
      line_index = line_index + 1
      continue
    }

    if in_directive_section {
      if semicolon_directive_body(trimmed, "enable") is Some(body) {
        let extensions = split_extensions(body)
        if extensions.is_empty() {
          raise MetadataError::InvalidWgslDirective(
            trimmed, line_index, "No extensions specified",
          )
        }
        cleaned_lines.push("")
        directives.enables.push(EnableDirective::{
          extensions,
          source_location: line_index,
        })
        line_index = line_index + 1
        continue
      }
      if semicolon_directive_body(trimmed, "requires") is Some(body) {
        let extensions = split_extensions(body)
        if extensions.is_empty() {
          raise MetadataError::InvalidWgslDirective(
            trimmed, line_index, "No extensions specified",
          )
        }
        cleaned_lines.push("")
        directives.requires.push(RequiresDirective::{
          extensions,
          source_location: line_index,
        })
        line_index = line_index + 1
        continue
      }
      if parse_diagnostic_directive_body(trimmed) is Some((severity, rule)) {
        if severity != "off" &&
          severity != "info" &&
          severity != "warn" &&
          severity != "error" {
          raise MetadataError::InvalidWgslDirective(
            trimmed,
            line_index,
            "Invalid severity '\{severity}'. Must be one of: off, info, warn, error",
          )
        }
        cleaned_lines.push("")
        directives.diagnostics.push(DiagnosticDirective::{
          severity,
          rule,
          source_location: line_index,
        })
        line_index = line_index + 1
        continue
      }
      if !trimmed.has_prefix("enable") &&
        !trimmed.has_prefix("requires") &&
        !trimmed.has_prefix("diagnostic") {
        in_directive_section = false
      }
    }

    cleaned_lines.push(line)
    line_index = line_index + 1
  }

  let mut cleaned_source = ""
  for i in 0..<cleaned_lines.length() {
    if i > 0 {
      cleaned_source = "\{cleaned_source}\n"
    }
    cleaned_source = cleaned_source + cleaned_lines[i]
  }

  (cleaned_source, directives)
}

///|
