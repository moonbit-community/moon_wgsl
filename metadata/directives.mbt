///|
priv struct ShaderDefReference {
  name : String
}

///|
fn split_extensions(raw : String) -> Array[String] {
  let extensions : Array[String] = []
  for part in raw.split(",") {
    let extension = part.trim().to_owned()
    if extension != "" {
      extensions.push(extension)
    }
  }
  extensions
}

///|
fn shader_def_name_token_text(token : WgslToken) -> String? {
  match token {
    WgslToken::Identifier(text, _) => Some(text)
    WgslToken::Other(code, _) if metadata_shader_def_name_code_unit(code) =>
      Some(wgsl_metadata_code_unit_to_string(code))
    _ => None
  }
}

///|
fn shader_def_value_token_text(token : WgslToken) -> String? {
  match token {
    WgslToken::Identifier(text, _) => Some(text)
    WgslToken::Other(45, _) => Some(wgsl_metadata_token_text(token))
    WgslToken::Other(code, _) if metadata_shader_def_name_code_unit(code) =>
      Some(wgsl_metadata_code_unit_to_string(code))
    _ => None
  }
}

///|
fn token_end(token : WgslToken) -> Int {
  token.pos() + wgsl_metadata_token_text(token).length()
}

///|
fn parse_shader_def_references(line : String) -> Array[ShaderDefReference] {
  let references : Array[ShaderDefReference] = []
  let tokens = tokenize(line, true)
  let mut i = 0
  while i < tokens.length() {
    guard tokens[i] is WgslToken::Other(35, _) else {
      i = i + 1
      continue
    }
    let mut j = i + 1
    while j < tokens.length() {
      match tokens[j] {
        WgslToken::Whitespace(_, _) => j = j + 1
        WgslToken::Other(code, _) if metadata_regex_whitespace_code_unit(code) =>
          j = j + 1
        _ => break
      }
    }
    guard j < tokens.length() else {
      i = i + 1
      continue
    }
    match tokens[j] {
      WgslToken::Other(123, _) => {
        let body_start = token_end(tokens[j])
        let mut k = j + 1
        while k < tokens.length() {
          match tokens[k] {
            WgslToken::Other(125, _) => break
            _ => k = k + 1
          }
        }
        if k < tokens.length() {
          let body_end = tokens[k].pos()
          let mut name_end = body_start
          while name_end < body_end &&
                metadata_shader_def_name_code_unit(
                  line.code_unit_at(name_end).to_int(),
                ) {
            name_end = name_end + 1
          }
          let name = line[body_start:name_end].to_owned()
          if name != "" && name_end == body_end {
            references.push(ShaderDefReference::{ name, })
          }
          i = k + 1
        } else {
          i = i + 1
        }
      }
      _ => {
        let mut name = ""
        while j < tokens.length() {
          match shader_def_name_token_text(tokens[j]) {
            Some(text) => {
              name = name + text
              j = j + 1
            }
            None => break
          }
        }
        if name != "" {
          references.push(ShaderDefReference::{ name, })
          i = j
        } else {
          i = i + 1
        }
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
  let trimmed = metadata_trim_regex_whitespace(text)
  if trimmed == "" {
    return ("", "")
  }
  let tokens = tokenize(trimmed, true)
  let mut i = 0
  let mut name = ""
  while i < tokens.length() {
    match shader_def_name_token_text(tokens[i]) {
      Some(text) => {
        name = name + text
        i = i + 1
      }
      None => break
    }
  }
  if name == "" {
    return ("", "")
  }
  while i < tokens.length() {
    match tokens[i] {
      WgslToken::Whitespace(_, _) => i = i + 1
      WgslToken::Other(code, _) if metadata_regex_whitespace_code_unit(code) =>
        i = i + 1
      _ => break
    }
  }
  let mut value = ""
  while i < tokens.length() {
    match shader_def_value_token_text(tokens[i]) {
      Some(text) => value = value + text
      None => break
    }
    i = i + 1
  }
  (name, value)
}

///|
fn starts_with_tokenized_space(text : String) -> Bool {
  text.length() > 0 &&
  metadata_regex_whitespace_code_unit(text.code_unit_at(0).to_int())
}

///|
fn metadata_required_space_directive_tail(
  line : String,
  keyword : String,
) -> String? {
  let trimmed = metadata_trim_regex_whitespace(line)
  guard trimmed.length() > 0 && trimmed.code_unit_at(0).to_int() == 35 else {
    return None
  }
  let start = metadata_skip_regex_whitespace(trimmed, 1)
  guard start + keyword.length() < trimmed.length() else { return None }
  guard trimmed[start:start + keyword.length()].to_owned() == keyword else {
    return None
  }
  let space_pos = start + keyword.length()
  let code = trimmed.code_unit_at(space_pos).to_int()
  guard metadata_regex_whitespace_code_unit(code) else { return None }
  let tail_start = metadata_skip_regex_whitespace(trimmed, space_pos)
  Some(
    metadata_trim_regex_whitespace(
      trimmed[tail_start:trimmed.length()].to_owned(),
    ),
  )
}

///|
fn metadata_required_space_word_tail(
  text : String,
  keyword : String,
) -> String? {
  let trimmed = metadata_trim_regex_whitespace(text)
  guard keyword.length() < trimmed.length() else { return None }
  guard trimmed[0:keyword.length()].to_owned() == keyword else { return None }
  let space_pos = keyword.length()
  let code = trimmed.code_unit_at(space_pos).to_int()
  guard metadata_regex_whitespace_code_unit(code) else { return None }
  let tail_start = metadata_skip_regex_whitespace(trimmed, space_pos)
  Some(
    metadata_trim_regex_whitespace(
      trimmed[tail_start:trimmed.length()].to_owned(),
    ),
  )
}

///|
fn semicolon_directive_body(line : String, keyword : String) -> String? {
  let trimmed = metadata_trim_regex_whitespace(line)
  guard trimmed.length() > keyword.length() &&
    trimmed[0:keyword.length()].to_owned() == keyword else {
    return None
  }
  let whitespace_start = keyword.length()
  guard metadata_regex_whitespace_code_unit(
    trimmed.code_unit_at(whitespace_start).to_int(),
  ) else {
    return None
  }
  let whitespace_end = metadata_skip_regex_whitespace(trimmed, whitespace_start)
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
    metadata_trim_regex_whitespace(
      trimmed[whitespace_end:semicolon_pos].to_owned(),
    ),
  )
}

///|
fn parse_diagnostic_directive_body(line : String) -> (String, String)? {
  let trimmed = metadata_trim_regex_whitespace(line)
  guard trimmed.length() >= "diagnostic".length() &&
    trimmed[0:"diagnostic".length()].to_owned() == "diagnostic" else {
    return None
  }
  let mut i = "diagnostic".length()
  i = metadata_skip_regex_whitespace(trimmed, i)
  guard i < trimmed.length() && trimmed.code_unit_at(i).to_int() == 40 else {
    return None
  }
  i = metadata_skip_regex_whitespace(trimmed, i + 1)
  let severity_start = i
  while i < trimmed.length() && trimmed.code_unit_at(i).to_int() != 44 {
    i = i + 1
  }
  guard i > severity_start && i < trimmed.length() else { return None }
  let severity = metadata_trim_regex_whitespace(
    trimmed[severity_start:i].to_owned(),
  )
  i = metadata_skip_regex_whitespace(trimmed, i + 1)
  let rule_start = i
  while i < trimmed.length() && trimmed.code_unit_at(i).to_int() != 41 {
    i = i + 1
  }
  guard i > rule_start && i < trimmed.length() else { return None }
  let rule = metadata_trim_regex_whitespace(trimmed[rule_start:i].to_owned())
  i = metadata_skip_regex_whitespace(trimmed, i + 1)
  guard i < trimmed.length() && trimmed.code_unit_at(i).to_int() == 59 else {
    return None
  }
  Some((severity, rule))
}

///|
fn directive_identifier(text : String) -> String? {
  let trimmed = metadata_trim_regex_whitespace(trim_trailing_semicolons(text))
  let mut i = 0
  while i < trimmed.length() {
    let code = trimmed.code_unit_at(i).to_int()
    if metadata_shader_def_name_code_unit(code) {
      i = i + 1
      continue
    }
    break
  }
  if i == 0 {
    None
  } else {
    Some(trimmed[0:i].to_owned())
  }
}

///|
fn metadata_shader_def_name_code_unit(code : Int) -> Bool {
  code == 124 ||
  code == 95 ||
  code > 127 ||
  (code >= 48 && code <= 57) ||
  (code >= 65 && code <= 90) ||
  (code >= 97 && code <= 122)
}

///|
fn metadata_regex_whitespace_code_unit(code : Int) -> Bool {
  code == 9 ||
  code == 10 ||
  code == 11 ||
  code == 12 ||
  code == 13 ||
  code == 32
}

///|
fn metadata_skip_regex_whitespace(text : String, start : Int) -> Int {
  let mut i = start
  while i < text.length() {
    let code = text.code_unit_at(i).to_int()
    if metadata_regex_whitespace_code_unit(code) {
      i = i + 1
      continue
    }
    break
  }
  i
}

///|
fn metadata_trim_regex_whitespace(text : String) -> String {
  let start = metadata_skip_regex_whitespace(text, 0)
  let mut end = text.length()
  while end > start {
    let code = text.code_unit_at(end - 1).to_int()
    if metadata_regex_whitespace_code_unit(code) {
      end = end - 1
      continue
    }
    break
  }
  text[start:end].to_owned()
}

///|
fn parse_if_operator_expression(
  expression : String,
) -> (String, String, String)? {
  let text = trim_trailing_semicolons(expression)
  let mut i = 0
  while i < text.length() {
    let code = text.code_unit_at(i).to_int()
    if metadata_regex_whitespace_code_unit(code) {
      i = i + 1
      continue
    }
    break
  }
  let def_start = i
  while i < text.length() {
    let code = text.code_unit_at(i).to_int()
    if metadata_shader_def_name_code_unit(code) {
      i = i + 1
      continue
    }
    break
  }
  guard i > def_start else { return None }
  let def = text[def_start:i].to_owned()
  while i < text.length() {
    let code = text.code_unit_at(i).to_int()
    if metadata_regex_whitespace_code_unit(code) {
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
    if metadata_regex_whitespace_code_unit(code) {
      i = i + 1
      continue
    }
    break
  }
  let value_start = i
  while i < text.length() {
    let code = text.code_unit_at(i).to_int()
    if code == 45 || metadata_shader_def_name_code_unit(code) {
      i = i + 1
      continue
    }
    break
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
fn metadata_scope_def(line : String) -> (Bool, String?) {
  if metadata_required_space_directive_tail(line, "ifdef") is Some(rest) &&
    directive_identifier(rest) is Some(name) {
    return (true, Some(name))
  }
  if metadata_required_space_directive_tail(line, "ifndef") is Some(rest) &&
    directive_identifier(rest) is Some(name) {
    return (true, Some(name))
  }
  if wgsl_directive_prefix_tail(line, WgslDirectiveKind::Else)
    is Some(else_tail) {
    let else_tail_has_space = starts_with_tokenized_space(else_tail)
    if else_tail_has_space &&
      metadata_required_space_word_tail(else_tail, "ifdef") is Some(rest) &&
      directive_identifier(rest) is Some(name) {
      return (true, Some(name))
    }
    if else_tail_has_space &&
      metadata_required_space_word_tail(else_tail, "ifndef") is Some(rest) &&
      directive_identifier(rest) is Some(name) {
      return (true, Some(name))
    }
    if else_tail_has_space &&
      metadata_required_space_word_tail(else_tail, "if") is Some(expr) &&
      if_operator_expression_def(expr) is Some(def) {
      return (true, Some(def))
    }
  }
  if metadata_required_space_directive_tail(line, "if") is Some(expr) &&
    if_operator_expression_def(expr) is Some(def) {
    return (true, Some(def))
  }
  if wgsl_directive_prefix_tail(line, WgslDirectiveKind::Else) is Some(_) {
    return (true, None)
  }
  if wgsl_directive_prefix_tail(line, WgslDirectiveKind::Endif) is Some(_) {
    return (true, None)
  }
  (false, None)
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
    let trimmed = metadata_trim_regex_whitespace(line)

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
